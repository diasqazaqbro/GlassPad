import ServiceManagement

/// Launch-at-login via `SMAppService`. Requires a real, signed `.app` bundle
/// (see Scripts/make-app-bundle.sh); from a bare SwiftPM binary `register()`
/// throws, which we swallow so the app still runs.
@MainActor
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("GlassPad: login-item toggle failed: \(error.localizedDescription)")
        }
    }
}
