import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let model = LaunchpadModel()
    private lazy var overlay = OverlayWindowController(model: model)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Background utility: no Dock icon, lives in the menu bar.
        NSApp.setActivationPolicy(.accessory)
        setUpStatusItem()
        model.loadApps()
    }

    // MARK: - Menu-bar item

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "square.grid.3x3.fill",
            accessibilityDescription: "GlassPad"
        )
        item.button?.image?.isTemplate = true
        item.button?.target = self
        item.button?.action = #selector(statusButtonClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            presentMenu()
        } else {
            overlay.toggle()
        }
    }

    /// Right-click shows a transient menu; left-click toggles the overlay.
    private func presentMenu() {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: "Toggle GlassPad", action: #selector(toggleFromMenu), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit GlassPad", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // clear so a plain left-click toggles next time
    }

    @objc private func toggleFromMenu() { overlay.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
}
