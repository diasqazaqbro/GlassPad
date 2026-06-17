import SwiftUI

/// The expanded folder panel (the morph target). It carries the same
/// `glassEffectID` as its source `FolderCell`, so opening/closing morphs the
/// glass between the tile and this panel — the signature "liquid" moment.
///
/// The full-screen dim and click-to-close live in `LaunchpadView` so they cover
/// the whole window; this view is just the centered glass panel.
struct FolderOverlay: View {
    let folder: Folder
    let apps: [InstalledApp]
    /// The id of the item currently launch-popping, so an app launched from inside
    /// the folder shows the same pop animation it gets out on the grid.
    var launchingItemID: String?
    var namespace: Namespace.ID
    var onLaunch: (InstalledApp) -> Void
    var onRename: (String) -> Void

    @State private var name: String = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            TextField("Folder", text: $name)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .tint(.white)
                .frame(maxWidth: 280)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    nameFocused ? Color.white.opacity(0.10) : .clear,
                    in: .rect(cornerRadius: 9, style: .continuous)
                )
                .focused($nameFocused)
                .onSubmit { commitName() }
                .accessibilityLabel("Folder name")

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(apps) { app in
                    AppCell(
                        app: app,
                        isLaunching: launchingItemID == LaunchpadItem.appItemID(app.id)
                    ) { onLaunch(app) }
                }
            }
        }
        .padding(34)
        .frame(maxWidth: Metrics.folderOverlayMaxWidth)
        .glassEffect(.regular, in: .rect(cornerRadius: Metrics.folderOverlayCornerRadius))
        .glassEffectID(LaunchpadItem.folderItemID(folder.id), in: namespace)
        .onAppear { name = folder.name }
        .onChange(of: nameFocused) { _, focused in
            if !focused { commitName() }
        }
    }

    private var columns: [GridItem] {
        let count = min(4, max(2, apps.count))
        return Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: count)
    }

    private func commitName() {
        onRename(name)
    }
}
