import Foundation
import Observation

/// Drives the in-app UI language (RU ⇄ EN) with NO relaunch.
///
/// SwiftUI's `Text("key")` / `NSLocalizedString` resolve against a bundle chosen
/// at load time, so they can't live-switch. Instead we hold the selected
/// language plus its `.lproj` sub-bundle and look strings up explicitly. Because
/// `currentLanguage` is `@Observable`, any SwiftUI view that reads `string(...)`
/// in its body re-renders the instant the language changes (the read is
/// observation-tracked). AppKit surfaces (menu, alert, status item) are built
/// fresh each time, so they read the current language on construction.
@MainActor @Observable
final class LocalizationManager {
    enum Language: String, CaseIterable, Identifiable {
        case english = "en"
        case russian = "ru"
        var id: String { rawValue }
        var displayName: String { self == .english ? "English" : "Русский" }
    }

    static let shared = LocalizationManager()

    private(set) var currentLanguage: Language
    // Resolved once at init and never changes — no need to observe it (and marking
    // it ignored avoids an @Observable init-ordering error).
    @ObservationIgnored private var bundles: [Language: Bundle] = [:]

    private init() {
        // Resolve each .lproj sub-bundle out of the SwiftPM resource bundle.
        for lang in Language.allCases {
            if let path = Bundle.module.path(forResource: lang.rawValue, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                bundles[lang] = bundle
            }
        }
        assert(bundles[.english] != nil && bundles[.russian] != nil,
               "GlassPad: localization bundles missing — check Package.swift resources / .lproj layout")

        if let saved = AppSettings.languagePreference, let lang = Language(rawValue: saved) {
            currentLanguage = lang
        } else {
            let system = Locale.preferredLanguages.first ?? "en"
            currentLanguage = system.hasPrefix("ru") ? .russian : .english
        }
    }

    func setLanguage(_ language: Language) {
        guard language != currentLanguage else { return }
        currentLanguage = language                 // @Observable → live re-render
        AppSettings.languagePreference = language.rawValue
    }

    func string(_ key: String) -> String {
        if let bundle = bundles[currentLanguage] {
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key { return value }
        }
        return bundles[.english]?.localizedString(forKey: key, value: key, table: nil) ?? key
    }
}

/// Current-language string. Reading this inside a SwiftUI `body` makes the view
/// re-render when the language changes (the access is observation-tracked).
@MainActor
func L(_ key: String) -> String {
    LocalizationManager.shared.string(key)
}

/// Formatted variant for keys with `%@` / `%d` placeholders.
@MainActor
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: LocalizationManager.shared.string(key), arguments: args)
}
