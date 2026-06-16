import AppKit
import SwiftUI

/// Owns the borderless full-screen overlay window and its show/hide animation.
/// The window hosts the SwiftUI `LaunchpadView` via `NSHostingView`.
@MainActor
final class OverlayWindowController {
    private var window: KeyableWindow?
    private(set) var isVisible = false

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
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
        isVisible = true
    }

    func hide() {
        guard isVisible, let window else { return }
        isVisible = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
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

        let root = LaunchpadView(onDismiss: { [weak self] in self?.hide() })
        let host = NSHostingView(rootView: root)
        host.frame = window.contentLayoutRect
        window.contentView = host

        window.onCancel = { [weak self] in self?.hide() }
        return window
    }
}
