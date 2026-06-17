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

    static var summonWithPinch: Bool {
        get {
            if UserDefaults.standard.object(forKey: key) == nil { return true }
            return UserDefaults.standard.bool(forKey: key)
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
