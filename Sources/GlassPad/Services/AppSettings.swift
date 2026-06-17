import Foundation
import CoreGraphics

/// Typed, persisted user preferences. Same shape as `GestureSettings`: a thin
/// `UserDefaults` wrapper read at summon time. Because the overlay is rebuilt on
/// every `show()` (and is never on screen at the same time as the Settings
/// window), reading these at summon is enough — no `@Observable` plumbing needed.
@MainActor
enum AppSettings {
    /// Icon-grid density preset. Biases cell/icon size so the auto-derived column
    /// and row counts pack more or fewer items, without exposing raw row/col knobs.
    enum GridDensity: String, CaseIterable, Identifiable {
        case comfortable, standard, compact
        var id: String { rawValue }
        var label: String {
            switch self {
            case .comfortable: "Comfortable"
            case .standard: "Standard"
            case .compact: "Compact"
            }
        }
        /// Multiplier applied to cell width and icon size.
        var scale: CGFloat {
            switch self {
            case .comfortable: 1.12
            case .standard: 1.0
            case .compact: 0.86
            }
        }
    }

    private enum Key {
        static let showMenuBarIcon = "showMenuBarIcon"
        static let gridDensity = "gridDensity"
        static let backdropDim = "backdropDim"
        static let useWallpaper = "useWallpaper"
        static let languagePreference = "languagePreference"
    }

    /// Selected UI language code ("en"/"ru"), or nil to follow the system.
    static var languagePreference: String? {
        get { defaults.string(forKey: Key.languagePreference) }
        set { defaults.set(newValue, forKey: Key.languagePreference) }
    }

    static var showMenuBarIcon: Bool {
        get { object(Key.showMenuBarIcon) == nil ? true : defaults.bool(forKey: Key.showMenuBarIcon) }
        set { defaults.set(newValue, forKey: Key.showMenuBarIcon) }
    }

    static var gridDensity: GridDensity {
        get { GridDensity(rawValue: defaults.string(forKey: Key.gridDensity) ?? "") ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: Key.gridDensity) }
    }

    /// Darkness of the tint over the desktop behind the overlay. Clamped so glass
    /// legibility never breaks.
    static var backdropDim: Double {
        get { object(Key.backdropDim) == nil ? Metrics.backdropDim : defaults.double(forKey: Key.backdropDim) }
        set { defaults.set(min(0.4, max(0, newValue)), forKey: Key.backdropDim) }
    }

    /// Use the live (blurred) desktop as the backdrop via ScreenCaptureKit instead
    /// of the permission-free `.ultraThinMaterial` fallback. Default off.
    static var useWallpaper: Bool {
        get { defaults.bool(forKey: Key.useWallpaper) }
        set { defaults.set(newValue, forKey: Key.useWallpaper) }
    }

    private static var defaults: UserDefaults { .standard }
    private static func object(_ key: String) -> Any? { defaults.object(forKey: key) }
}
