import Foundation

/// A single installed application. Icons are intentionally NOT stored here — the
/// model stays cheap, `Hashable`, and `Sendable`; `IconLoader` resolves the
/// `NSImage` on demand and caches it.
struct InstalledApp: Identifiable, Hashable, Sendable {
    /// Bundle path on disk — stable and unique, so it doubles as the identity.
    let id: String
    let name: String
    let url: URL
    let bundleID: String?
}
