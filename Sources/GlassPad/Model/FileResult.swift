import Foundation

/// A Spotlight file hit shown in the Files section of search results. Kept entirely
/// separate from `LaunchpadItem` — a file is NOT a launcher slot and must never reach
/// the saved layout, so it is deliberately *not* expressible as a `LaunchpadItem`.
///
/// Like `InstalledApp`, the icon is NOT stored here — `IconLoader` resolves it on
/// demand from the path, keeping this `Sendable`/`Hashable` and cheap to pass around.
struct FileResult: Identifiable, Hashable, Sendable {
    /// Absolute path on disk — stable, unique, doubles as identity.
    let id: String
    let name: String
    let url: URL

    var path: String { id }

    /// Namespaced id for keyboard selection, so a file's selection id can never
    /// collide with an app's (`app:`) or folder's (`folder:`) item id.
    static func selectionID(_ path: String) -> String { "file:" + path }

    /// Inverse of `selectionID` — nil if `id` isn't a file selection id.
    static func path(fromSelectionID id: String) -> String? {
        id.hasPrefix("file:") ? String(id.dropFirst("file:".count)) : nil
    }
}
