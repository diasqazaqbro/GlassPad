import SwiftUI
import KeyboardShortcuts

/// Small settings surface: rebind the global summon shortcut and toggle
/// launch-at-login.
struct SettingsView: View {
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section("Summon") {
                KeyboardShortcuts.Recorder("Global shortcut:", name: .toggleGlassPad)
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
