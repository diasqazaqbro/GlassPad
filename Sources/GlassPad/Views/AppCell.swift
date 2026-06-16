import SwiftUI

/// A single app tile: icon over a single-line label. Phase 1 is plain (no glass);
/// hover/glass treatment arrives in Phase 2.
struct AppCell: View {
    let app: InstalledApp
    var onLaunch: () -> Void

    @State private var icon: NSImage?

    var body: some View {
        Button(action: onLaunch) {
            VStack(spacing: 8) {
                iconView
                    .frame(width: 96, height: 96)
                Text(app.name)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    .frame(maxWidth: 110)
            }
        }
        .buttonStyle(.plain)
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
