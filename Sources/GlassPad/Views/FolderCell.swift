import SwiftUI

/// A folder tile: a frosted square holding a mini grid of its app icons, with the
/// folder name below.
///
/// ## Why the tile's glass is conditional (the paging-smoothness fix)
///
/// At rest in the scrolling grid the tile is a cheap **static** `.ultraThinMaterial`
/// fill — it is *not* a live `.glassEffect`, so when the grid translates during a
/// swipe there is no per-frame backdrop sample/refraction to recompute. This is
/// the per-tile cost that used to jank the swipe (the grid carried live glass
/// behind the moving icons; real Launchpad has none).
///
/// `useLiveGlass` is flipped on by `LaunchpadView` only while a folder is open
/// (`model.openFolder != nil`) — i.e. when the grid is static, never mid-swipe.
/// In that state the tile becomes a *real* `.glassEffect` carrying the morph
/// `glassEffectID`, so the open/close "liquid" morph into `FolderOverlay` still
/// reads from a genuine glass shape (a `.ultraThinMaterial` fill could not be a
/// morph source). Both endpoints live in the same small `GlassEffectContainer`
/// that `LaunchpadView` wraps around the folder-open layer, satisfying the
/// matched-geometry morph's same-container requirement.
struct FolderCell: View {
    let folder: Folder
    let apps: [InstalledApp]
    var isSelected: Bool
    var isOpen: Bool
    var iconScale: CGFloat = 1
    var namespace: Namespace.ID
    /// True only while *some* folder is open (the grid is static) — see type doc.
    var useLiveGlass: Bool = false
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
        } else if useLiveGlass {
            // A folder is open (grid is static): be a real glass shape carrying the
            // morph id, so the open/close morph reads from genuine glass and both
            // endpoints share LaunchpadView's folder-layer GlassEffectContainer.
            miniGrid
                .padding(Metrics.folderTilePadding)
                .frame(width: Metrics.iconSize * iconScale, height: Metrics.iconSize * iconScale)
                .glassEffect(.regular, in: .rect(cornerRadius: Metrics.folderTileCornerRadius))
                .glassEffectID(LaunchpadItem.folderItemID(folder.id), in: namespace)
        } else {
            // Resting / scrolling: cheap static frosted fill — no live glass, so a
            // swipe recomputes nothing here. Visually near-identical at rest.
            miniGrid
                .padding(Metrics.folderTilePadding)
                .frame(width: Metrics.iconSize * iconScale, height: Metrics.iconSize * iconScale)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: Metrics.folderTileCornerRadius))
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
