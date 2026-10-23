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
            SendableImage(Self.rasterized(NSWorkspace.shared.icon(forFile: path)))
        }.value

        cache.setObject(boxed.image, forKey: key)
        return boxed.image
    }

    /// Workspace icons are lazy IconServices images that render on first draw — on
    /// the main thread, mid-animation (the first-open and first-swipe hitch). Draw
    /// once here, off-main, into a plain bitmap the GPU just scales.
    private static func rasterized(_ icon: NSImage) -> NSImage {
        let pointSize = NSSize(width: 128, height: 128)
        let px = 256 // 128 pt @2x covers the largest grid density (112 pt)
        guard let ctx = CGContext(
            data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.displayP3)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            icon.size = pointSize
            return icon
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        icon.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
        NSGraphicsContext.restoreGraphicsState()
        guard let cgImage = ctx.makeImage() else {
            icon.size = pointSize
            return icon
        }
        return NSImage(cgImage: cgImage, size: pointSize)
    }
}

/// Transfers an immutable `NSImage` across actor boundaries. The image is read
/// only after construction, so the unchecked conformance is sound.
private struct SendableImage: @unchecked Sendable {
    let image: NSImage
    init(_ image: NSImage) { self.image = image }
}
