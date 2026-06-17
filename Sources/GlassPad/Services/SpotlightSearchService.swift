import Foundation

/// Live whole-Mac file search via system Spotlight (`NSMetadataQuery`). A single
/// long-lived query is reconfigured per search; results are snapshotted into
/// `Sendable` `FileResult`s on the main actor and handed back through `onResults`.
///
/// Concurrency: the whole service is `@MainActor` (a `@MainActor` class is implicitly
/// `Sendable`, so capturing `self` in the notification blocks is legal). The blocks
/// are delivered on the `.main` operation queue, so `MainActor.assumeIsolated` is
/// sound. `NSMetadataQuery`/`NSMetadataItem` are NOT `Sendable` and never escape this
/// actor — only the `[FileResult]` snapshot crosses out.
///
/// No SwiftUI import and no reference to the model: it produces data, the model owns
/// it (the project's unidirectional rule).
@MainActor
final class SpotlightSearchService {
    /// Delivered on the main actor whenever results change (or clear).
    var onResults: (([FileResult]) -> Void)?

    private let query = NSMetadataQuery()
    private var observers: [NSObjectProtocol] = []

    init() {
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        query.operationQueue = .main

        let center = NotificationCenter.default
        let deliver: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.deliver() }
        }
        // Finish = first full pass; Update = the live index changed. Both re-snapshot.
        observers.append(center.addObserver(forName: .NSMetadataQueryDidFinishGathering,
                                            object: query, queue: .main, using: deliver))
        observers.append(center.addObserver(forName: .NSMetadataQueryDidUpdate,
                                            object: query, queue: .main, using: deliver))
    }

    /// Start (or restart) a search. An empty query stops the live query and clears.
    func search(_ text: String) {
        query.stop()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            onResults?([])
            return
        }
        // Match display or file name; exclude app bundles (apps are listed separately).
        query.predicate = NSPredicate(
            format: "(kMDItemDisplayName CONTAINS[cd] %@ OR kMDItemFSName CONTAINS[cd] %@) AND NOT (kMDItemContentTypeTree == %@ OR kMDItemContentTypeTree == %@)",
            trimmed, trimmed, "com.apple.application", "com.apple.application-bundle"
        )
        // Most-recently-used first — the file you mean is usually the one you touched.
        query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemLastUsedDateKey, ascending: false)]
        query.start()
    }

    /// Stop the live query (on overlay dismiss). Observers stay registered for reuse —
    /// the service lives for the app's lifetime, so there's nothing to leak.
    func stop() {
        query.stop()
    }

    /// Snapshot the current results into `Sendable` `FileResult`s on the main actor.
    /// `NSMetadataItem`s never leave this method.
    private func deliver() {
        query.disableUpdates()
        defer { query.enableUpdates() }

        let count = min(query.resultCount, Metrics.fileResultLimit)
        var out: [FileResult] = []
        out.reserveCapacity(count)
        for i in 0 ..< count {
            guard let item = query.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  !path.isEmpty else { continue }
            let name = (item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String)
                ?? (item.value(forAttribute: NSMetadataItemFSNameKey) as? String)
                ?? (path as NSString).lastPathComponent
            out.append(FileResult(id: path, name: name, url: URL(fileURLWithPath: path)))
        }
        onResults?(out)
    }
}
