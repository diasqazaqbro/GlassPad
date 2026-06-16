import SwiftUI

/// The expanded folder panel. It carries the same `glassEffectID` as its source
/// `FolderCell`, so opening/closing morphs the glass between the tile and this
/// panel (the signature "liquid" moment). Tapping outside closes it.
struct FolderOverlay: View {
    let folder: Folder
    let apps: [InstalledApp]
    var namespace: Namespace.ID
    var onClose: () -> Void
    var onLaunch: (InstalledApp) -> Void
    var onRename: (String) -> Void

    @State private var name: String = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(Metrics.folderOverlayDim))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(spacing: 18) {
                TextField("Folder", text: $name)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .frame(maxWidth: 280)
                    .focused($nameFocused)
                    .onSubmit { commitName() }

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(apps) { app in
                        AppCell(app: app) { onLaunch(app) }
                    }
                }
            }
            .padding(34)
            .frame(maxWidth: Metrics.folderOverlayMaxWidth)
            .glassEffect(.regular, in: .rect(cornerRadius: Metrics.folderOverlayCornerRadius))
            .glassEffectID(LaunchpadItem.folderItemID(folder.id), in: namespace)
        }
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
