import Observation
import SwiftUI
import AppKit

enum MoveDirection { case left, right, up, down }

/// Where a dropped item lands relative to the cell it was dropped on.
enum DropRegion { case before, after, onto }

/// The single source of UI truth. Services produce data, this holds it, SwiftUI
/// reads it. Views never touch a service directly — only through the model.
@MainActor
@Observable
final class LaunchpadModel {
    /// Every installed app, keyed for fast icon/identity lookups.
    private(set) var apps: [InstalledApp] = []
    private var appsByID: [String: InstalledApp] = [:]

    /// The arranged grid: ordered apps + folders. Source of truth for layout.
    private(set) var items: [LaunchpadItem] = []

    /// Live search query bound to the search pill.
    var query: String = ""

    /// The folder currently expanded in the morph overlay (nil = none).
    var openFolder: Folder?

    /// The item id currently "popping" as it launches (for the launch animation).
    var launchingItemID: String?

    /// Keyboard selection tracked by **identity**, so it survives reorders,
    /// folder edits, and live re-scans instead of silently pointing at whatever
    /// app now occupies a stale index.
    var selectedItemID: String?

    /// Cached display list — rebuilt only when query/items/apps change, so
    /// per-cell reads (and the fuzzy filter) don't run on every render.
    private(set) var displayedItems: [LaunchpadItem] = []

    // Grid geometry, set by the view from the available size.
    private(set) var columns = Metrics.preferredColumns
    private(set) var rows = Metrics.preferredRows

    var currentPage = 0

    /// True once the first app scan has completed, so the UI can tell "still
    /// loading" (show nothing) apart from "genuinely no apps" (show empty state).
    private(set) var didLoad = false

    /// Generation token so a slow earlier scan can't overwrite a newer one.
    private var loadGeneration = 0

    var pageCapacity: Int { max(1, columns * rows) }
    var searching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    // MARK: - Derived data

    var pages: [[LaunchpadItem]] {
        guard !displayedItems.isEmpty else { return [[]] }
        let cap = pageCapacity
        return stride(from: 0, to: displayedItems.count, by: cap).map {
            Array(displayedItems[$0 ..< min($0 + cap, displayedItems.count)])
        }
    }

    var pageCount: Int { pages.count }

    /// Position of the keyboard selection in the current display list.
    private var selectedIndex: Int? {
        guard let id = selectedItemID else { return nil }
        return displayedItems.firstIndex { $0.id == id }
    }

    func resolvedApps(in folder: Folder) -> [InstalledApp] {
        folder.appIDs.compactMap { appsByID[$0] }
    }

    /// Apps filtered + ranked by the current query (fuzzy). Searches all apps,
    /// including those inside folders. Computed once per rebuild, not per cell.
    private func computeFilteredApps() -> [InstalledApp] {
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

    private func rebuildDisplayedItems() {
        displayedItems = searching ? computeFilteredApps().map(LaunchpadItem.app) : items
    }

    // MARK: - Loading & reconciliation

    func loadApps() {
        loadGeneration += 1
        let generation = loadGeneration
        Task {
            async let discoveredTask = Task.detached(priority: .userInitiated) {
                AppDiscoveryService.discoverApps()
            }.value
            async let loadTask = Task.detached(priority: .userInitiated) {
                LayoutStore.load()
            }.value
            let (discovered, outcome) = await (discoveredTask, loadTask)

            // A newer load superseded this one — drop our (possibly stale) results.
            guard generation == self.loadGeneration else { return }

            self.apps = discovered
            self.appsByID = Dictionary(discovered.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

            switch outcome {
            case .loaded(let stored):
                self.items = Self.reconcile(discovered: discovered, stored: stored)
                self.rebuildDisplayedItems()
                self.clampPage()
                self.persist() // write back the reconciled layout (prune removed, append new)
            case .missing:
                self.items = Self.reconcile(discovered: discovered, stored: nil)
                self.rebuildDisplayedItems()
                self.clampPage()
                self.persist()
            case .failed:
                // The saved layout couldn't be read — never clobber it. Reconcile
                // against whatever we already have in memory (so a live re-scan
                // still prunes/appends) and do NOT persist over the backed-up file.
                let inMemory = self.items.isEmpty ? nil : Self.makeStoredLayout(from: self.items)
                self.items = Self.reconcile(discovered: discovered, stored: inMemory)
                self.rebuildDisplayedItems()
                self.clampPage()
            }

            self.didLoad = true
        }
    }

    /// Merge the saved layout with what's actually installed: drop removed apps,
    /// dissolve folders that fall below two apps, and append brand-new installs.
    private static func reconcile(discovered: [InstalledApp], stored: StoredLayout?) -> [LaunchpadItem] {
        let byID = Dictionary(discovered.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var used = Set<String>()
        var result: [LaunchpadItem] = []

        if let stored {
            for entry in stored.entries {
                switch entry {
                case .app(let path):
                    if let app = byID[path], used.insert(path).inserted {
                        result.append(.app(app))
                    }
                case .folder(let folder):
                    let present = folder.appIDs.filter { byID[$0] != nil && used.insert($0).inserted }
                    if present.count >= 2 {
                        result.append(.folder(Folder(id: folder.id, name: folder.name, appIDs: present)))
                    } else if let only = present.first, let app = byID[only] {
                        result.append(.app(app)) // dissolve a now-too-small folder
                    }
                }
            }
        }

        for app in discovered where !used.contains(app.id) {
            result.append(.app(app))
        }
        return result
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

    func handleQueryChange() {
        rebuildDisplayedItems()
        currentPage = 0
        selectedItemID = (searching && !displayedItems.isEmpty) ? displayedItems[0].id : nil
    }

    /// Left/Right walk the displayed items in reading order (pages flip naturally).
    /// Up/Down move by a full row, staying within the visible page.
    func move(_ direction: MoveDirection) {
        let all = displayedItems
        guard !all.isEmpty else { return }
        let cap = pageCapacity

        guard let current = selectedIndex, all.indices.contains(current) else {
            selectedItemID = all[min(currentPage * cap, all.count - 1)].id
            return
        }
        if current / cap != currentPage { // user swiped away — re-anchor to visible page
            selectedItemID = all[min(currentPage * cap, all.count - 1)].id
            return
        }

        var target = current
        let row = (current % cap) / columns
        switch direction {
        case .left:  target = max(0, current - 1)
        case .right: target = min(all.count - 1, current + 1)
        case .up:    if row > 0 { target = current - columns }
        case .down:
            let below = current + columns
            if row < rows - 1, below < all.count, below / cap == current / cap { target = below }
        }
        selectedItemID = all[target].id
        currentPage = target / cap
    }

    /// Activate the selection (or the top hit while searching): launch an app, or
    /// open a folder. Returns true if the overlay should dismiss.
    @discardableResult
    func activateSelected() -> Bool {
        let all = displayedItems
        let index = selectedIndex ?? (all.isEmpty ? nil : 0)
        guard let index, all.indices.contains(index) else { return false }
        switch all[index] {
        case .app(let app):
            launch(app)
            return true
        case .folder(let folder):
            withAnimation(Metrics.reduceMotion ? nil : Metrics.morph) { openFolder = folder }
            return false
        }
    }

    func launch(_ app: InstalledApp) {
        withAnimation(Metrics.reduceMotion ? nil : Metrics.pop) {
            launchingItemID = LaunchpadItem.appItemID(app.id)
        }
        LaunchService.launch(app)
    }

    /// Reset transient launcher state so each summon opens clean (no leftover
    /// search query, expanded folder, selection, or page).
    func resetTransientState() {
        launchingItemID = nil
        query = ""
        openFolder = nil
        selectedItemID = nil
        currentPage = 0
        rebuildDisplayedItems()
    }

    // MARK: - Drag & drop (reorder / folders)

    /// Handle a drop of `draggedID` onto the cell for `ontoID`. Center → folder
    /// (or add-to-folder); left/right edges → reorder. Persists on success.
    @discardableResult
    func handleDrop(draggedID: String, ontoID: String, region: DropRegion) -> Bool {
        guard !searching, draggedID != ontoID,
              let from = items.firstIndex(where: { $0.id == draggedID }),
              items.contains(where: { $0.id == ontoID })
        else { return false }

        let dragged = items[from]
        switch region {
        case .before, .after:
            reorder(itemID: draggedID, relativeTo: ontoID, after: region == .after)
        case .onto:
            let target = items.first { $0.id == ontoID }
            if case .app(let targetApp) = target, case .app(let draggedApp) = dragged {
                createFolder(target: targetApp, dragged: draggedApp)
            } else if case .folder(let folder) = target, case .app(let draggedApp) = dragged {
                addApp(draggedApp.id, toFolder: folder.id)
            } else {
                reorder(itemID: draggedID, relativeTo: ontoID, after: false)
            }
        }
        rebuildDisplayedItems()
        persist()
        return true
    }

    func renameFolder(_ folder: Folder, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? folder.name : trimmed
        guard let idx = indexOfFolder(folder.id), case .folder(var f) = items[idx] else { return }
        f.name = name
        items[idx] = .folder(f)
        if openFolder?.id == folder.id { openFolder?.name = name }
        rebuildDisplayedItems()
        persist()
    }

    private func reorder(itemID: String, relativeTo targetID: String, after: Bool) {
        guard let from = items.firstIndex(where: { $0.id == itemID }) else { return }
        let moved = items.remove(at: from)
        guard let targetIdx = items.firstIndex(where: { $0.id == targetID }) else {
            items.insert(moved, at: min(from, items.count))
            return
        }
        let insertAt = max(0, min(after ? targetIdx + 1 : targetIdx, items.count))
        items.insert(moved, at: insertAt)
    }

    private func createFolder(target: InstalledApp, dragged: InstalledApp) {
        let folder = Folder(id: UUID(), name: "Folder", appIDs: [target.id, dragged.id])
        items.removeAll { $0.id == LaunchpadItem.appItemID(dragged.id) }
        if let ti = items.firstIndex(where: { $0.id == LaunchpadItem.appItemID(target.id) }) {
            items[ti] = .folder(folder)
        }
    }

    private func addApp(_ appID: String, toFolder folderID: UUID) {
        items.removeAll { $0.id == LaunchpadItem.appItemID(appID) }
        guard let idx = indexOfFolder(folderID), case .folder(var folder) = items[idx] else { return }
        if !folder.appIDs.contains(appID) { folder.appIDs.append(appID) }
        items[idx] = .folder(folder)
        if openFolder?.id == folderID { openFolder = folder }
    }

    private func indexOfFolder(_ id: UUID) -> Int? {
        items.firstIndex { if case .folder(let f) = $0 { return f.id == id } else { return false } }
    }

    // MARK: - Persistence

    private static func makeStoredLayout(from items: [LaunchpadItem]) -> StoredLayout {
        StoredLayout(version: LayoutStore.currentVersion, entries: items.map { item in
            switch item {
            case .app(let app): return .app(path: app.id)
            case .folder(let folder): return .folder(StoredFolder(id: folder.id, name: folder.name, appIDs: folder.appIDs))
            }
        })
    }

    func persist() {
        // LayoutStore serializes the write on its own queue, in call order.
        LayoutStore.save(Self.makeStoredLayout(from: items))
    }

    private func clampPage() {
        currentPage = min(max(0, currentPage), max(0, pageCount - 1))
    }
}
