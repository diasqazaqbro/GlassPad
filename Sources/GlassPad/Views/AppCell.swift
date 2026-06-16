import SwiftUI

/// A single app tile: icon over a single-line label. Content layer stays
/// restrained (HIG) — a subtle highlight fades in on hover rather than glass.
struct AppCell: View {
    let app: InstalledApp
    var onLaunch: () -> Void

    @State private var icon: NSImage?
    @State private var hovering = false

    var body: some View {
        Button(action: onLaunch) {
            VStack(spacing: 8) {
                iconView
                    .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                Text(app.name)
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
                    .fill(.white.opacity(hovering ? Metrics.hoverHighlightOpacity : 0))
            }
            .scaleEffect(hovering ? Metrics.hoverScale : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Metrics.pop, value: hovering)
        .task(id: app.id) {
            icon = await IconLoader.shared.icon(forPath: app.id)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.08))
        }
    }
}
