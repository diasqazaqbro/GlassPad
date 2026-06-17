import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let model = LaunchpadModel()
    private lazy var overlay = OverlayWindowController(model: model)
    private lazy var settings = SettingsWindowController(model: model)
    private let watcher = AppDirectoryWatcher()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Background utility: no Dock icon, lives in the menu bar.
        NSApp.setActivationPolicy(.accessory)
        if AppSettings.showMenuBarIcon {
            setUpStatusItem()
        } else {
            // No menu-bar icon → the status menu (the only Settings entry point) is
            // gone, so surface Settings on launch. Relaunching GlassPad is the
            // documented way back in.
            settings.show()
        }
        model.loadApps()
        HotkeyManager.register { [weak self] in self?.overlay.toggle() }
        overlay.onOpenSettings = { [weak self] in self?.settings.show() }

        // Live re-scan when apps are installed/removed.
        watcher.start(paths: AppDiscoveryService.searchPaths.map(\.path)) { [weak self] in
            self?.model.loadApps()
        }

        // 4-finger pinch: inward summons GlassPad, outward dismisses it. When on,
        // the system's own pinch launcher is suppressed so they don't both appear.
        // The monitor runs always (cheap); the setting gates whether it acts.
        SystemGesture.setSystemPinchEnabled(!GestureSettings.summonWithPinch)
        TrackpadPinchMonitor.shared.start(
            onPinchIn: { [weak self] in
                guard GestureSettings.summonWithPinch else { return }
                GestureSettings.invertPinchDirection ? self?.overlay.hide() : self?.overlay.show()
            },
            onPinchOut: { [weak self] in
                guard GestureSettings.summonWithPinch else { return }
                GestureSettings.invertPinchDirection ? self?.overlay.show() : self?.overlay.hide()
            }
        )
        TrackpadPinchMonitor.shared.setSensitivity(GestureSettings.pinchSensitivity)
    }

    /// Push a live pinch-sensitivity change to the monitor (called by Settings).
    func applyPinchSensitivity() {
        TrackpadPinchMonitor.shared.setSensitivity(GestureSettings.pinchSensitivity)
    }

    /// Dismiss the overlay when the app loses focus (the user clicked another app
    /// or screen) — matches real Launchpad, which never lingers in the background.
    func applicationDidResignActive(_ notification: Notification) {
        overlay.hide()
    }

    /// Tear down the FSEvents stream on the main queue before exit, so no callback
    /// can fire against a half-released watcher.
    func applicationWillTerminate(_ notification: Notification) {
        watcher.stop()
        TrackpadPinchMonitor.shared.stop()
    }

    // MARK: - Menu-bar item

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "square.grid.2x2.fill",
            accessibilityDescription: L("statusItem.label")
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
        let toggle = NSMenuItem(title: L("menu.toggle"), action: #selector(toggleFromMenu), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        let settingsItem = NSMenuItem(title: L("menu.settings"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let reset = NSMenuItem(title: L("menu.resetLayout"), action: #selector(resetLayoutFromMenu), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // clear so a plain left-click toggles next time
    }

    @objc private func toggleFromMenu() { overlay.toggle() }
    @objc private func openSettings() { settings.show() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func resetLayoutFromMenu() { confirmAndResetLayout() }

    /// Add/remove the menu-bar item to match the current setting. Called by Settings.
    func applyMenuBarIconSetting() {
        if AppSettings.showMenuBarIcon {
            if statusItem == nil { setUpStatusItem() }
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    /// Destructive — confirm before discarding folders and manual ordering.
    func confirmAndResetLayout() {
        let alert = NSAlert()
        alert.messageText = L("settings.resetLayoutTitle")
        alert.informativeText = L("settings.resetLayoutMessage")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("common.reset"))
        alert.addButton(withTitle: L("common.cancel"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            model.resetLayout()
        }
    }
}
