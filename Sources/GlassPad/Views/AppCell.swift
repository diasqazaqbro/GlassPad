import SwiftUI

/// A single app tile: icon over a single-line label. Content layer stays
/// restrained (HIG) — a subtle highlight fades in on hover / keyboard selection
/// rather than glass.
struct AppCell: View {
    let app: InstalledApp
    var isSelected: Bool = false
    var isLaunching: Bool = false
    var iconScale: CGFloat = 1
    var onLaunch: () -> Void

    @State private var icon: NSImage?
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var highlightOpacity: Double {
        if isSelected { return Metrics.selectedHighlightOpacity }
        if hovering { return Metrics.hoverHighlightOpacity }
        return 0
    }

    private var emphasized: Bool { isSelected || hovering }
    private var scale: CGFloat {
        if isLaunching { return Metrics.launchPopScale }
        return emphasized ? Metrics.hoverScale : 1
    }

    var body: some View {
        Button(action: onLaunch) {
            VStack(spacing: 8) {
                iconView
                    .frame(width: Metrics.iconSize * iconScale, height: Metrics.iconSize * iconScale)
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
                    .fill(.white.opacity(highlightOpacity))
            }
            .scaleEffect(scale)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : Metrics.pop, value: scale)
        .accessibilityLabel(app.name)
        .accessibilityHint(L("app.launches", app.name))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
