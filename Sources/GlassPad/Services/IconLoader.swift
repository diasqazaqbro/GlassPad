import AppKit

/// Async icon resolution with an `NSCache` keyed by bundle path. The expensive
/// `NSWorkspace` lookup runs off the main actor; the resulting (immutable)
/// `NSImage` is handed back to the UI.
///
/// `@unchecked Sendable`: `NSCache` is internally thread-safe, and the images we
/// store are fetched once and never mutated afterwards.
final class IconLoader: @unchecked Sendable {
    static let shared = IconLoader()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 2048
    }

    /// Resolve the icon for an app bundle path, caching the result.
    func icon(forPath path: String) async -> NSImage {
        let key = path as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let boxed = await Task.detached(priority: .userInitiated) {
            let icon = NSWorkspace.shared.icon(forFile: path)
            // Set the preferred drawing size once; SwiftUI rasterizes at display size.
            icon.size = NSSize(width: 128, height: 128)
            return SendableImage(icon)
        }.value

        cache.setObject(boxed.image, forKey: key)
        return boxed.image
    }
}

/// Transfers an immutable `NSImage` across actor boundaries. The image is read
/// only after construction, so the unchecked conformance is sound.
private struct SendableImage: @unchecked Sendable {
    let image: NSImage
    init(_ image: NSImage) { self.image = image }
}
