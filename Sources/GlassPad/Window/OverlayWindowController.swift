import AppKit
import SwiftUI

/// Owns the borderless full-screen overlay window and its show/hide animation.
/// The window hosts the SwiftUI `LaunchpadView` via `NSHostingView`.
@MainActor
final class OverlayWindowController {
    private let model: LaunchpadModel
    private var window: KeyableWindow?
    private var keyMonitor: Any?
    private var scrollMonitor: Any?
    private(set) var isVisible = false

    // MARK: - Swipe-to-page state (touched only on the main actor, in the monitor)

    /// Whether a precise (trackpad) gesture is currently in flight (we saw `.began`
    /// and not yet `.ended`/`.cancelled`). Guards against treating a stray
    /// momentum/legacy-wheel event as a fresh gesture.
    private var swipeActive = false
    /// Accumulated page-forward translation (points) for the in-flight swipe, fed
    /// live to `model.updatePaging` so the page stack tracks the finger 1:1.
    private var swipeAccumX: CGFloat = 0
    /// Timestamp of the last `.changed` frame and the last per-frame velocity
    /// (points/sec), used to decide a flick commit on lift.
    private var lastScrollTime: TimeInterval = 0
    private var lastScrollVelocity: CGFloat = 0

    /// Opens Settings (set by AppDelegate) — invoked on ⌘, so Settings is always
    /// reachable from the overlay, independent of the menu-bar icon.
    var onOpenSettings: (() -> Void)?

    /// Bumped on every show() so a deferred launch-dismiss scheduled for an older
    /// summon can't hide a window the user just re-opened.
    private var generation = 0

    init(model: LaunchpadModel) {
        self.model = model
    }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        guard !isVisible else { return }
        generation += 1
        // A previous hide()'s fade-out may still be in flight; drop that window
        // immediately so we never end up with two overlays (its completion handler
        // is guarded by identity and won't touch the new window).
        if let stale = window {
            stale.orderOut(nil)
            window = nil
        }
        let screen = targetScreen()
        let window = makeWindow(on: screen)
        self.window = window

        window.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Metrics.reduceMotion ? 0 : Metrics.overlayFadeIn
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
        installKeyMonitor()
        installScrollMonitor()
        isVisible = true
        captureWallpaperIfEnabled(on: screen, window: window)
    }

    /// When "use wallpaper" is on, grab a blurred snapshot of this screen (minus
    /// our own window) off-main and hand it to the model; otherwise clear it so the
    /// material backdrop shows. Guarded by generation so a stale capture from a
    /// previous summon can't land on a newer one.
    private func captureWallpaperIfEnabled(on screen: NSScreen, window: NSWindow) {
        guard AppSettings.useWallpaper else {
            model.wallpaper = nil
            return
        }
        let gen = generation
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
            .uint32Value ?? CGMainDisplayID()
        let windowID = CGWindowID(window.windowNumber)
        Task { [weak self] in
            let captured = await WallpaperCaptureService.captureBlurred(displayID: displayID, excludingWindowID: windowID)
            guard let self, self.generation == gen, self.isVisible else { return }
            self.model.wallpaper = captured?.image
        }
    }

    /// Close the overlay and open the Settings window (gear button / ⌘,).
    private func openSettingsAndHide() {
        hide()
        onOpenSettings?()
    }

    /// Dismiss after a short beat so a launch pop is visible, but only if this
    /// summon is still the current one (no re-open happened in the meantime).
    private func scheduleLaunchHide() {
        let gen = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + Metrics.launchDismissDelay) { [weak self] in
            guard let self, self.generation == gen, self.isVisible else { return }
            self.hide()
        }
    }

    func hide() {
        guard isVisible, let window else { return }
        isVisible = false
        removeKeyMonitor()
        removeScrollMonitor()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Metrics.reduceMotion ? 0 : Metrics.overlayFadeOut
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // NSAnimationContext invokes completion handlers on the main thread.
            MainActor.assumeIsolated {
                window.orderOut(nil)
                // Only clear the reference if this is still the current window — a
                // re-summon during the fade-out may have installed a new one.
                if self?.window === window { self?.window = nil }
            }
        })
    }

    // MARK: - Window construction

    /// Open on the screen that currently contains the cursor (HIG: appear where
    /// the user is looking), falling back to the main screen.
    private func targetScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private func makeWindow(on screen: NSScreen) -> KeyableWindow {
        let window = KeyableWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false
        window.setFrame(screen.frame, display: true)

        let root = LaunchpadView(
            model: model,
            onDismiss: { [weak self] in self?.scheduleLaunchHide() },
            onOpenSettings: { [weak self] in self?.openSettingsAndHide() }
        )
        let host = NSHostingView(rootView: root)
        host.frame = window.contentLayoutRect
        window.contentView = host

        window.onCancel = { [weak self] in self?.hide() }
        return window
    }

    // MARK: - Keyboard

    /// While visible, intercept navigation keys (arrows, Return, Esc) and route
    /// them to the model. Other keys (letters) fall through to the search field.
    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyDown(event)
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    // MARK: - Trackpad paging (two-finger horizontal swipe)

    /// Capture two-finger horizontal scrolls and turn them into one-page-per-swipe
    /// flips on `model.currentPage`. A *local* `.scrollWheel` monitor is the right
    /// hook because it intercepts every scroll routed to our app before any view
    /// handles it — independent of the responder chain — so a swipe *anywhere* over
    /// the overlay grid is seen, even though SwiftUI's icon cells sit on top in the
    /// hosting view. (A background sibling `NSView` overriding `scrollWheel(with:)`
    /// would not be reliable: it isn't an ancestor of the cells, and the hosting
    /// view's subviews consume scroll, so events wouldn't bubble to it.)
    ///
    /// This monitor fires on the main thread (AppKit event delivery), so all the
    /// swipe state it touches is main-actor-isolated — strict-concurrency clean with
    /// no hops.
    private func installScrollMonitor() {
        removeScrollMonitor()
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            return self.handleScroll(event)
        }
    }

    private func removeScrollMonitor() {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }
        swipeActive = false
        swipeAccumX = 0
        lastScrollVelocity = 0
    }

    /// Drive the custom finger-follow pager from the two-finger trackpad swipe
    /// stream. The page stack tracks the finger 1:1 during the gesture and springs
    /// to the committed page on lift — most native, like real Launchpad.
    ///
    /// Phase machine for precise (trackpad) scrolls:
    ///   .began   → start a swipe (reset accumulator, `model.beginPaging`)
    ///   .changed → accumulate page-forward translation + velocity, `model.updatePaging`
    ///   .ended   → `model.endPaging` commits at most ±1 page by displacement OR velocity
    /// Momentum frames (`.momentumPhase`) are swallowed without effect: a precise
    /// flick has already decided the page on lift, so ignoring momentum is what
    /// guarantees one-page-per-swipe (never coast two, never rest between).
    ///
    /// Returns `nil` to consume a recognized horizontal trackpad swipe (so it never
    /// also scrolls something underneath), or the event to pass it through (a
    /// vertical scroll, a legacy mouse wheel, or anything while a folder is open).
    private func handleScroll(_ event: NSEvent) -> NSEvent? {
        // While a folder is open, paging is suppressed; pass the event through so the
        // open folder's own content can scroll. End any in-flight swipe cleanly.
        guard model.openFolder == nil else {
            if swipeActive { swipeActive = false; model.endPaging(velocity: 0) }
            return event
        }

        // Only precise (trackpad / Magic Mouse) gestures page. A legacy wheel has no
        // momentum phase and no precise deltas — pass it through untouched.
        let hasPhase = event.phase != [] || event.momentumPhase != []
        guard event.hasPreciseScrollingDeltas, hasPhase else { return event }

        // Page-forward convention: positive = drag the stack right (toward the
        // previous page). `scrollingDeltaX` already has the user's natural-scroll
        // setting baked into its sign; `isDirectionInvertedFromDevice` reports when
        // that inversion is active, so we re-flip to one consistent convention where
        // dragging two fingers right always moves the stack right, regardless of the
        // natural-scroll setting.
        let raw = CGFloat(event.scrollingDeltaX)
        let dx = event.isDirectionInvertedFromDevice ? raw : -raw

        // Momentum is the inertial tail after the fingers lift. The decision was made
        // on `.ended`; swallow momentum so it can't add a second page or scroll
        // anything underneath.
        if event.momentumPhase != [] { return nil }

        switch event.phase {
        case .began:
            swipeActive = true
            swipeAccumX = 0
            lastScrollVelocity = 0
            lastScrollTime = event.timestamp
            model.beginPaging()
            return nil

        case .changed:
            // Some gestures omit `.began`; start one lazily so we never drop a swipe.
            if !swipeActive {
                swipeActive = true
                swipeAccumX = 0
                lastScrollVelocity = 0
                lastScrollTime = event.timestamp
                model.beginPaging()
            }
            swipeAccumX += dx
            let now = event.timestamp
            let dt = now - lastScrollTime
            if dt > 0 { lastScrollVelocity = dx / CGFloat(dt) } // points/sec
            lastScrollTime = now
            model.updatePaging(translation: swipeAccumX)
            return nil

        case .ended, .cancelled:
            if swipeActive {
                swipeActive = false
                model.endPaging(velocity: lastScrollVelocity)
            }
            swipeAccumX = 0
            return nil

        default:
            // Phases like `.stationary` / `.mayBegin`: consume if we're mid-gesture
            // (keep ownership of the stream), else pass through.
            return swipeActive ? nil : event
        }
    }

    /// Returns nil to consume the event, or the event to pass it through.
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        // ⌘, opens Settings from anywhere in the overlay — a robust path that
        // doesn't depend on finding the menu-bar icon.
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "," {
            openSettingsAndHide()
            return nil
        }

        // With a folder open, route keys around the modal: Esc ends a rename (or
        // closes the folder), arrows move the rename caret while editing, and Tab
        // never cycles focus through the folder's app buttons.
        if model.openFolder != nil {
            let editingName = (window?.firstResponder as? NSText)?.isFieldEditor == true
            switch event.keyCode {
            case 53: // Esc
                if editingName {
                    // End the rename (it commits via the field's focus-loss
                    // handler) but keep the folder open; a second Esc closes it.
                    window?.makeFirstResponder(nil)
                } else {
                    withAnimation(Metrics.reduceMotion ? nil : Metrics.morph) { model.openFolder = nil }
                }
                return nil
            case 48: // Tab
                return editingName ? event : nil
            case 123...126: // arrows: caret movement while editing, else swallowed
                return editingName ? event : nil
            default:
                return event
            }
        }

        // Cmd+1…9 jumps straight to that page (clamped) — quick, precise paging.
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers,
           chars.count == 1, let digit = Int(chars), (1...9).contains(digit) {
            model.goToPage(digit - 1)
            return nil
        }

        switch event.keyCode {
        case 53: // Esc
            hide()
            return nil
        case 123: model.move(.left);  return nil
        case 124: model.move(.right); return nil
        case 125: model.move(.down);  return nil
        case 126: model.move(.up);    return nil
        case 48: // Tab — arrow-only grid nav; don't let focus cycle through cells.
            return nil
        case 36, 76: // Return / keypad Enter
            if model.activateSelected() { scheduleLaunchHide() }
            return nil
        default:
            return event // letters etc. reach the focused search field
        }
    }
}
