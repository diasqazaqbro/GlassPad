import SwiftUI
import KeyboardShortcuts

/// Small settings surface: rebind the global summon shortcut and toggle
/// launch-at-login.
struct SettingsView: View {
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var summonWithPinch = GestureSettings.summonWithPinch

    var body: some View {
        Form {
            Section("Summon") {
                KeyboardShortcuts.Recorder("Global shortcut:", name: .toggleGlassPad)
                Toggle("Open with 4-finger pinch", isOn: $summonWithPinch)
                    .onChange(of: summonWithPinch) { _, enabled in
                        GestureSettings.summonWithPinch = enabled
                        // When we own the gesture, suppress the system pinch launcher.
                        SystemGesture.setSystemPinchEnabled(!enabled)
                    }
                Text("Pinch inward with four fingers to open, spread to close. Turning this on disables the macOS pinch launcher; a full switch-over may need a logout.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("General") {
                Toggle("Launch GlassPad at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LoginItem.setEnabled(enabled)
                        launchAtLogin = LoginItem.isEnabled // reflect the real state
                    }
                Text("Launch-at-login requires running the bundled GlassPad.app (see Scripts/make-app-bundle.sh).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}
