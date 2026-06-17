import SwiftUI
import AppKit
import KeyboardShortcuts

/// Settings surface: a single grouped Form (4 sections) in a standard titled
/// window. Modeless, no Save/Apply — every control commits on `.onChange`.
struct SettingsView: View {
    let model: LaunchpadModel

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var showMenuBarIcon = AppSettings.showMenuBarIcon
    @State private var density = AppSettings.gridDensity
    @State private var backdropDim = AppSettings.backdropDim
    @State private var useWallpaper = AppSettings.useWallpaper
    @State private var summonWithPinch = GestureSettings.summonWithPinch
    @State private var confirmingReset = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch GlassPad at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LoginItem.setEnabled(enabled)
                        launchAtLogin = LoginItem.isEnabled // reflect the real state
                    }

                Toggle("Show icon in menu bar", isOn: $showMenuBarIcon)
                    .onChange(of: showMenuBarIcon) { _, enabled in
                        AppSettings.showMenuBarIcon = enabled
                        (NSApp.delegate as? AppDelegate)?.applyMenuBarIconSetting()
                    }
                footnote("Off → summon only by shortcut or pinch. Relaunch GlassPad to reach Settings again.")

                Button("Reset Layout to Defaults…", role: .destructive) { confirmingReset = true }
                    .confirmationDialog(
                        "Reset Layout to Defaults?",
                        isPresented: $confirmingReset,
                        titleVisibility: .visible
                    ) {
                        Button("Reset", role: .destructive) { model.resetLayout() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Removes all folders and custom ordering. Apps stay installed; the grid returns to alphabetical order.")
                    }
            }

            Section("Appearance") {
                Picker("Grid density", selection: $density) {
                    ForEach(AppSettings.GridDensity.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: density) { _, value in AppSettings.gridDensity = value }

                Slider(value: $backdropDim, in: 0 ... 0.4) {
                    Text("Backdrop dimming")
                } minimumValueLabel: {
                    Image(systemName: "sun.max")
                } maximumValueLabel: {
                    Image(systemName: "moon")
                }
                .onChange(of: backdropDim) { _, value in AppSettings.backdropDim = value }

                Toggle("Use desktop wallpaper as background", isOn: $useWallpaper)
                    .onChange(of: useWallpaper) { _, enabled in
                        AppSettings.useWallpaper = enabled
                        // Trigger the Screen-Recording prompt; capture falls back to
                        // the material backdrop until permission is actually granted.
                        if enabled { WallpaperCaptureService.requestPermission() }
                    }
                footnote("Captures the screen behind GlassPad (asks for Screen-Recording permission — may need a relaunch). Off → frosted glass.")
            }

            Section("Shortcuts") {
                KeyboardShortcuts.Recorder("Summon GlassPad:", name: .toggleGlassPad)
                footnote("Jump to a page with ⌘1–⌘9. In the grid: arrows move, Return opens, Esc closes, type to search.")
            }

            Section("Gestures") {
                Toggle("Open with four-finger pinch", isOn: $summonWithPinch)
                    .onChange(of: summonWithPinch) { _, enabled in
                        GestureSettings.summonWithPinch = enabled
                        SystemGesture.setSystemPinchEnabled(!enabled)
                    }
                footnote("Pinch inward with four fingers to open, spread to close. Turning this on disables the macOS pinch launcher; a full switch-over may need a logout.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
