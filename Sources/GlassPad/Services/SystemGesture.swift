import Foundation

/// Reads/writes the macOS trackpad "4-finger pinch" gesture setting so GlassPad
/// can own that gesture without the system app launcher also appearing.
///
/// The value lives under `TrackpadFourFingerPinchGesture` in the two trackpad
/// preference domains (2 = system default / enabled, 0 = disabled). Writing it
/// takes full effect after the next login; some setups pick it up sooner.
enum SystemGesture {
    // Stored as plain Strings (Sendable); bridged to CFString at the call site.
    private static let key = "TrackpadFourFingerPinchGesture"
    private static let domains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    ]

    static func setSystemPinchEnabled(_ enabled: Bool) {
        let cfKey = key as CFString
        let value = (enabled ? 2 : 0) as CFNumber
        for domain in domains {
            let cfDomain = domain as CFString
            for host in [kCFPreferencesAnyHost, kCFPreferencesCurrentHost] {
                CFPreferencesSetValue(cfKey, value, cfDomain, kCFPreferencesCurrentUser, host)
                CFPreferencesSynchronize(cfDomain, kCFPreferencesCurrentUser, host)
            }
        }
        // Best-effort nudge so it can apply without a re-login; harmless if no
        // observer is listening.
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.apple.MultitouchSupport.SettingsChangedNotification"),
            object: nil, userInfo: nil, deliverImmediately: true
        )
    }
}

/// Whether GlassPad should be summoned by the 4-finger pinch (and thus suppress
/// the system gesture). Persisted in the app's own defaults; on by default since
/// the user opted in.
@MainActor
enum GestureSettings {
    private static let key = "summonWithPinch"
    private static let sensitivityKey = "pinchSensitivity"
    private static let invertKey = "invertPinchDirection"

    static var summonWithPinch: Bool {
        get {
            if UserDefaults.standard.object(forKey: key) == nil { return true }
            return UserDefaults.standard.bool(forKey: key)
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// 0…1 (Light…Firm), default 0.5. Mapped to the monitor's pinch threshold.
    static var pinchSensitivity: Double {
        get {
            guard UserDefaults.standard.object(forKey: sensitivityKey) != nil else { return 0.5 }
            return UserDefaults.standard.double(forKey: sensitivityKey)
        }
        set { UserDefaults.standard.set(min(1, max(0, newValue)), forKey: sensitivityKey) }
    }

    /// Pinch outward to open, inward to close (opposite of the default).
    static var invertPinchDirection: Bool {
        get { UserDefaults.standard.bool(forKey: invertKey) }
        set { UserDefaults.standard.set(newValue, forKey: invertKey) }
    }
}
