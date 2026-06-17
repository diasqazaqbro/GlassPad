import SwiftUI

/// A folder tile: a glass square holding a mini grid of its app icons, with the
/// folder name below. The glass square carries a `glassEffectID` so it can morph
/// into the expanded `FolderOverlay` panel.
struct FolderCell: View {
    let folder: Folder
    let apps: [InstalledApp]
    var isSelected: Bool
    var isOpen: Bool
    var iconScale: CGFloat = 1
    var namespace: Namespace.ID
    var onOpen: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var emphasized: Bool { isSelected || hovering }
    private var highlightOpacity: Double {
        if isSelected { return Metrics.selectedHighlightOpacity }
        if hovering { return Metrics.hoverHighlightOpacity }
        return 0
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 8) {
                tile
                Text(folder.name)
                    .font(.system(size: Metrics.labelFontSize))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    .frame(maxWidth: Metrics.labelMaxWidth)
            }
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: Metrics.cellCornerRadius, style: .continuous)
                    .fill(.white.opacity(highlightOpacity))
            }
            .scaleEffect(emphasized ? Metrics.hoverScale : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : Metrics.pop, value: emphasized)
        .accessibilityLabel(L("folder.a11yLabel", folder.name))
        .accessibilityHint(L("folder.opensHint"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var tile: some View {
        if isOpen {
            // While expanded, the overlay panel owns the morph id — this tile must
            // not duplicate the glassEffectID, so render an empty placeholder.
            Color.clear.frame(width: Metrics.iconSize * iconScale, height: Metrics.iconSize * iconScale)
        } else {
            miniGrid
                .padding(Metrics.folderTilePadding)
                .frame(width: Metrics.iconSize * iconScale, height: Metrics.iconSize * iconScale)
                .glassEffect(.regular, in: .rect(cornerRadius: Metrics.folderTileCornerRadius))
                .glassEffectID(LaunchpadItem.folderItemID(folder.id), in: namespace)
        }
    }

    private var miniGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
            ForEach(apps.prefix(9)) { app in
                MiniIcon(path: app.id)
            }
        }
    }
}

/// A small icon used inside folder tiles.
private struct MiniIcon: View {
    let path: String
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(.white.opacity(0.12))
            }
        }
        .task(id: path) { icon = await IconLoader.shared.icon(forPath: path) }
    }
}
