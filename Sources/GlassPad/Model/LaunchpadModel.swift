import Observation
import AppKit

/// The single source of UI truth. Services produce data, this holds it, SwiftUI
/// reads it. Views never touch a service directly — only through the model.
@MainActor
@Observable
final class LaunchpadModel {
    /// Flat list of every installed app (Phase 1). Paging/folders arrive later.
    private(set) var apps: [InstalledApp] = []

    /// Kick off (re)discovery off the main actor; results land back on main.
    func loadApps() {
        Task {
            let discovered = await Task.detached(priority: .userInitiated) {
                AppDiscoveryService.discoverApps()
            }.value
            self.apps = discovered
        }
    }

    func launch(_ app: InstalledApp) {
        LaunchService.launch(app)
    }
}
