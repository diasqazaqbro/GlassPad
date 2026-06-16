import AppKit
import SwiftUI

/// Owns the borderless full-screen overlay window and its show/hide animation.
/// The window hosts the SwiftUI `LaunchpadView` via `NSHostingView`.
@MainActor
final class OverlayWindowController {
    private let model: LaunchpadModel
    private var window: KeyableWindow?
    private var keyMonitor: Any?
    private(set) var isVisible = false

    init(model: LaunchpadModel) {
        self.model = model
    }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        guard !isVisible else { return }
        let screen = targetScreen()
        let window = makeWindow(on: screen)
        self.window = window

        window.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Metrics.overlayFadeIn
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
        installKeyMonitor()
        isVisible = true
    }

    func hide() {
        guard isVisible, let window else { return }
        isVisible = false
        removeKeyMonitor()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Metrics.overlayFadeOut
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // NSAnimationContext invokes completion handlers on the main thread.
            MainActor.assumeIsolated {
                window.orderOut(nil)
                self?.window = nil
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

        let root = LaunchpadView(model: model, onDismiss: { [weak self] in self?.hide() })
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

    /// Returns nil to consume the event, or the event to pass it through.
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 53: // Esc
            hide()
            return nil
        case 123: model.move(.left);  return nil
        case 124: model.move(.right); return nil
        case 125: model.move(.down);  return nil
        case 126: model.move(.up);    return nil
        case 36, 76: // Return / keypad Enter
            if model.launchSelected() { hide() }
            return nil
        default:
            return event // letters etc. reach the focused search field
        }
    }
}
