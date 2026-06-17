import SwiftUI
import AppKit
import KeyboardShortcuts

/// Apple-style settings: a System-Settings-style toolbar-tab window (non-glass,
/// standard chrome). Each tab is a grouped Form. Modeless — every control commits
/// on `.onChange`. All labels go through `L(...)`, so flipping the language in the
/// Language tab re-renders every tab live (no relaunch).
struct SettingsView: View {
    let model: LaunchpadModel
    @State private var localization = LocalizationManager.shared
    @State private var selection: Pane? = .general

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $selection) { pane in
                Label(L(pane.titleKey), systemImage: pane.symbol)
                    .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 184, ideal: 196, max: 220)
        } detail: {
            detail(for: selection ?? .general)
                .navigationTitle(L((selection ?? .general).titleKey))
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 560, minHeight: 460)
    }

    @ViewBuilder
    private func detail(for pane: Pane) -> some View {
        switch pane {
        case .general: GeneralTab(model: model)
        case .appearance: AppearanceTab()
        case .shortcuts: ShortcutsTab()
        case .gestures: GesturesTab()
        case .language: LanguageTab()
        }
    }

    /// The settings sections — a sidebar list (System Settings / iOS Settings style).
    enum Pane: String, CaseIterable, Identifiable {
        case general, appearance, shortcuts, gestures, language
        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .general: "tab.general"
            case .appearance: "tab.appearance"
            case .shortcuts: "tab.shortcuts"
            case .gestures: "tab.gestures"
            case .language: "tab.language"
            }
        }

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .appearance: "paintbrush"
            case .shortcuts: "keyboard"
            case .gestures: "hand.draw"
            case .language: "globe"
            }
        }
    }
}

// MARK: - General

private struct GeneralTab: View {
    let model: LaunchpadModel
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var showMenuBarIcon = AppSettings.showMenuBarIcon
    @State private var confirmingReset = false

    var body: some View {
        Form {
            Section {
                Toggle(L("settings.launchAtLogin"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LoginItem.setEnabled(enabled)
                        launchAtLogin = LoginItem.isEnabled
                    }
                Toggle(L("settings.showMenuBarIcon"), isOn: $showMenuBarIcon)
                    .onChange(of: showMenuBarIcon) { _, enabled in
                        AppSettings.showMenuBarIcon = enabled
                        (NSApp.delegate as? AppDelegate)?.applyMenuBarIconSetting()
                    }
                footnote(L("settings.menuBarIconHint"))
            }
            Section {
                Button(L("settings.resetLayout"), role: .destructive) { confirmingReset = true }
                    .confirmationDialog(
                        L("settings.resetLayoutTitle"),
                        isPresented: $confirmingReset,
                        titleVisibility: .visible
                    ) {
                        Button(L("common.reset"), role: .destructive) { model.resetLayout() }
                        Button(L("common.cancel"), role: .cancel) {}
                    } message: {
                        Text(L("settings.resetLayoutMessage"))
                    }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance

private struct AppearanceTab: View {
    @State private var density = AppSettings.gridDensity
    @State private var backdropDim = AppSettings.backdropDim
    @State private var useWallpaper = AppSettings.useWallpaper

    var body: some View {
        Form {
            Section {
                Picker(L("settings.gridDensity.label"), selection: $density) {
                    Text(L("settings.gridDensity.comfortable")).tag(AppSettings.GridDensity.comfortable)
                    Text(L("settings.gridDensity.standard")).tag(AppSettings.GridDensity.standard)
                    Text(L("settings.gridDensity.compact")).tag(AppSettings.GridDensity.compact)
                }
                .pickerStyle(.segmented)
                .onChange(of: density) { _, value in AppSettings.gridDensity = value }

                Slider(value: $backdropDim, in: 0 ... 0.4) {
                    Text(L("settings.backdropDim.label"))
                } minimumValueLabel: {
                    Image(systemName: "sun.max")
                } maximumValueLabel: {
                    Image(systemName: "moon")
                }
                .onChange(of: backdropDim) { _, value in AppSettings.backdropDim = value }
            }
            Section {
                Toggle(L("settings.useWallpaper.label"), isOn: $useWallpaper)
                    .onChange(of: useWallpaper) { _, enabled in
                        AppSettings.useWallpaper = enabled
                        if enabled { WallpaperCaptureService.requestPermission() }
                    }
                footnote(L("settings.useWallpaper.hint"))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcuts

private struct ShortcutsTab: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder(L("settings.shortcuts.summon"), name: .toggleGlassPad)
            }
            Section(L("settings.shortcuts.inside")) {
                KeyCapRow(keys: "⌘1 – ⌘9", label: L("shortcut.jumpPage"))
                KeyCapRow(keys: "↑ ↓ ← →", label: L("shortcut.move"))
                KeyCapRow(keys: "↩", label: L("shortcut.open"))
                KeyCapRow(keys: "⎋", label: L("shortcut.close"))
                KeyCapRow(keys: "⌘,", label: L("shortcut.settings"))
                KeyCapRow(keys: "A–Z", label: L("shortcut.search"))
            }
        }
        .formStyle(.grouped)
    }
}

/// Read-only shortcut legend row: a label with a key-cap glyph on the trailing edge.
private struct KeyCapRow: View {
    let keys: String
    let label: String

    var body: some View {
        LabeledContent(label) {
            Text(keys)
                .font(.system(.callout, design: .rounded).weight(.medium))
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: .rect(cornerRadius: 6))
        }
    }
}

// MARK: - Gestures

private struct GesturesTab: View {
    @State private var summonWithPinch = GestureSettings.summonWithPinch
    @State private var sensitivity = GestureSettings.pinchSensitivity
    @State private var invert = GestureSettings.invertPinchDirection

    var body: some View {
        Form {
            Section {
                Toggle(L("settings.gestures.pinch"), isOn: $summonWithPinch)
                    .onChange(of: summonWithPinch) { _, enabled in
                        GestureSettings.summonWithPinch = enabled
                        SystemGesture.setSystemPinchEnabled(!enabled)
                    }
                footnote(L("settings.gestures.pinch.hint"))
            }
            Section {
                Slider(value: $sensitivity, in: 0 ... 1) {
                    Text(L("settings.gestures.sensitivity"))
                } minimumValueLabel: {
                    Text(L("settings.gestures.sensitivity.light"))
                } maximumValueLabel: {
                    Text(L("settings.gestures.sensitivity.firm"))
                }
                .disabled(!summonWithPinch)
                .onChange(of: sensitivity) { _, value in
                    GestureSettings.pinchSensitivity = value
                    (NSApp.delegate as? AppDelegate)?.applyPinchSensitivity()
                }
                footnote(L("settings.gestures.sensitivity.hint"))

                Toggle(L("settings.gestures.invert"), isOn: $invert)
                    .disabled(!summonWithPinch)
                    .onChange(of: invert) { _, value in GestureSettings.invertPinchDirection = value }
                footnote(L("settings.gestures.invert.hint"))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Language

private struct LanguageTab: View {
    @State private var localization = LocalizationManager.shared

    var body: some View {
        Form {
            Section {
                Picker(L("settings.language.label"), selection: Binding(
                    get: { localization.currentLanguage },
                    set: { localization.setLanguage($0) }
                )) {
                    ForEach(LocalizationManager.Language.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shared

private func footnote(_ text: String) -> some View {
    Text(text)
        .font(.footnote)
        .foregroundStyle(.secondary)
}
