import Observation
import AppKit

enum MoveDirection { case left, right, up, down }

/// The single source of UI truth. Services produce data, this holds it, SwiftUI
/// reads it. Views never touch a service directly — only through the model.
@MainActor
@Observable
final class LaunchpadModel {
    /// Flat list of every installed app (Phase 1). Folders arrive in Phase 4.
    private(set) var apps: [InstalledApp] = []

    /// Live search query bound to the search pill.
    var query: String = ""

    // Grid geometry, set by the view from the available size.
    private(set) var columns = Metrics.preferredColumns
    private(set) var rows = Metrics.preferredRows

    /// Currently visible page (driven by swipe, dots, and keyboard).
    var currentPage = 0

    /// Keyboard selection, as an index into `filteredApps` (nil = no selection).
    var selectedIndex: Int?

    var pageCapacity: Int { max(1, columns * rows) }

    // MARK: - Derived data

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

    /// `filteredApps` chunked into pages sized to the grid.
    var pages: [[InstalledApp]] {
        let items = filteredApps
        guard !items.isEmpty else { return [[]] }
        let cap = pageCapacity
        return stride(from: 0, to: items.count, by: cap).map {
            Array(items[$0 ..< min($0 + cap, items.count)])
        }
    }

    var pageCount: Int { pages.count }

    var selectedApp: InstalledApp? {
        guard let i = selectedIndex, filteredApps.indices.contains(i) else { return nil }
        return filteredApps[i]
    }

    // MARK: - Loading

    /// Kick off (re)discovery off the main actor; results land back on main.
    func loadApps() {
        Task {
            let discovered = await Task.detached(priority: .userInitiated) {
                AppDiscoveryService.discoverApps()
            }.value
            self.apps = discovered
            self.clampPage()
        }
    }

    // MARK: - Grid geometry

    func setGrid(columns: Int, rows: Int) {
        let c = max(1, columns)
        let r = max(1, rows)
        guard c != self.columns || r != self.rows else { return }
        self.columns = c
        self.rows = r
        clampPage()
    }

    // MARK: - Navigation

    func goToPage(_ page: Int) {
        currentPage = max(0, min(page, pageCount - 1))
    }

    /// Reset paging + selection when the query changes. With an active query we
    /// pre-select the best match so Return launches the top hit (Spotlight-like).
    func handleQueryChange() {
        currentPage = 0
        let searching = !query.trimmingCharacters(in: .whitespaces).isEmpty
        selectedIndex = (searching && !filteredApps.isEmpty) ? 0 : nil
    }

    /// Left/Right walk the filtered list in reading order (pages flip naturally at
    /// boundaries). Up/Down move by a full row, staying within the visible page.
    func move(_ direction: MoveDirection) {
        let items = filteredApps
        guard !items.isEmpty else { return }
        let cap = pageCapacity

        guard let current = selectedIndex, items.indices.contains(current) else {
            // First arrow press selects the first item on the current page.
            selectedIndex = min(currentPage * cap, items.count - 1)
            return
        }

        // If the user swiped away from the selection, re-anchor to the visible page.
        if current / cap != currentPage {
            selectedIndex = min(currentPage * cap, items.count - 1)
            return
        }

        var target = current
        let row = (current % cap) / columns

        switch direction {
        case .left:
            target = max(0, current - 1)
        case .right:
            target = min(items.count - 1, current + 1)
        case .up:
            if row > 0 { target = current - columns }
        case .down:
            let below = current + columns
            if row < rows - 1, below < items.count, below / cap == current / cap {
                target = below
            }
        }

        selectedIndex = target
        currentPage = target / cap
    }

    /// Launch the selected app (or the top result when searching). Returns true
    /// if something was launched, so the caller can dismiss.
    @discardableResult
    func launchSelected() -> Bool {
        let items = filteredApps
        let index = selectedIndex ?? (items.isEmpty ? nil : 0)
        guard let index, items.indices.contains(index) else { return false }
        launch(items[index])
        return true
    }

    func launch(_ app: InstalledApp) {
        LaunchService.launch(app)
    }

    // MARK: - Helpers

    private func clampPage() {
        currentPage = min(max(0, currentPage), max(0, pageCount - 1))
    }
}
