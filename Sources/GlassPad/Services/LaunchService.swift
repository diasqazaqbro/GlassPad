import AppKit

/// Launches apps via `NSWorkspace`, activating them on success.
enum LaunchService {
    static func launch(_ app: InstalledApp) {
        Task {
            do {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                _ = try await NSWorkspace.shared.openApplication(at: app.url, configuration: config)
            } catch {
                NSLog("GlassPad: failed to launch \(app.name): \(error.localizedDescription)")
            }
        }
    }
}
