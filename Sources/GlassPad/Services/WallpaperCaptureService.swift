import AppKit
import CoreImage
import ScreenCaptureKit

/// Captures the desktop behind the overlay (via ScreenCaptureKit), blurs it, and
/// hands back an image the glass can refract — the real-wallpaper backdrop.
///
/// Everything is best-effort: any failure (permission not granted, capture error)
/// returns nil so the caller falls back to the permission-free material backdrop.
enum WallpaperCaptureService {
    /// A captured image, boxed to cross the actor boundary back to the main actor
    /// (NSImage isn't Sendable, but this one is freshly made and never shared).
    struct Captured: @unchecked Sendable { let image: NSImage }

    private static let blurSigma: Double = 28

    /// Whether the user has already granted Screen Recording permission.
    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    /// Prompt for Screen Recording permission. Returns the current grant state;
    /// macOS may require relaunch before a fresh grant takes effect.
    @discardableResult
    static func requestPermission() -> Bool { CGRequestScreenCaptureAccess() }

    /// Capture + blur the desktop on the display with `displayID`, excluding our
    /// own overlay window so it isn't captured. Off-main; returns nil on failure.
    static func captureBlurred(displayID: CGDirectDisplayID, excludingWindowID: CGWindowID) async -> Captured? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == displayID })
                ?? content.displays.first else { return nil }

            let excluded = content.windows.filter { $0.windowID == excludingWindowID }
            let filter = SCContentFilter(display: display, excludingWindows: excluded)

            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.showsCursor = false
            config.ignoreShadowsDisplay = true

            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            guard let blurred = blur(cgImage) else { return nil }
            return Captured(image: blurred)
        } catch {
            return nil
        }
    }

    private static func blur(_ cgImage: CGImage) -> NSImage? {
        let source = CIImage(cgImage: cgImage)
        let output = source
            .clampedToExtent()
            .applyingGaussianBlur(sigma: blurSigma)
            .cropped(to: source.extent)
        let context = CIContext(options: nil)
        guard let result = context.createCGImage(output, from: source.extent) else { return nil }
        return NSImage(cgImage: result, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
