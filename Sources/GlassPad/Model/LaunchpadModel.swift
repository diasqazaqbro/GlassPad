import Observation
import AppKit

/// The single source of UI truth. Services produce data, this holds it, SwiftUI
/// reads it. Views never touch a service directly — only through the model.
@MainActor
@Observable
final class LaunchpadModel {
    /// Flat list of every installed app (Phase 1). Paging/folders arrive later.
    private(set) var apps: [InstalledApp] = []

    /// Live search query bound to the search pill.
    var query: String = ""

    /// Apps filtered + ranked by the current query (instant, fuzzy). Empty query
    /// shows everything in the default alphabetical order.
    var filteredApps: [InstalledApp] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return apps }
        return apps
            .compactMap { app -> (app: InstalledApp, score: Int)? in
                guard let s = FuzzyMatcher.score(query: trimmed, candidate: app.name) else { return nil }
                return (app, s)
            }
            .sorted {
                $0.score != $1.score
                    ? $0.score > $1.score
                    : $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending
            }
            .map(\.app)
    }

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
