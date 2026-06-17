import AppKit
import SwiftUI

/// Hosts the SwiftUI `SettingsView` in a standard titled window. An accessory app
/// can still present and key a normal window after activating.
@MainActor
final class SettingsWindowController {
    private let model: LaunchpadModel
    private var window: NSWindow?

    init(model: LaunchpadModel) {
        self.model = model
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = L("window.settingsTitle")
            window.isReleasedWhenClosed = false
            window.center()
            let host = NSHostingView(rootView: SettingsView(model: model))
            window.contentView = host
            // Fixed size: a TabView's fittingSize collapses to the smallest tab,
            // so we size the window ourselves.
            window.setContentSize(NSSize(width: 520, height: 460))
            window.contentMinSize = NSSize(width: 520, height: 360)
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
