import AppKit
import SwiftUI

/// Hosts the SwiftUI `SettingsView` in a standard titled window. An accessory app
/// can still present and key a normal window after activating.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 220),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "GlassPad Settings"
            window.isReleasedWhenClosed = false
            window.center()
            let host = NSHostingView(rootView: SettingsView())
            window.contentView = host
            window.setContentSize(host.fittingSize)
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
