import SwiftUI

/// Phase 0 placeholder: a dimmed, blurred backdrop over the live desktop with a
/// centered identity card. Esc (handled by the window) or a click dismisses it.
struct LaunchpadView: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 12) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(.white.opacity(0.92))
                Text("GlassPad")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Phase 0 — press Esc or click to dismiss")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
    }

    /// The blurred desktop the glass will later refract. The material samples the
    /// window backdrop (the live desktop), and the black tint dims it.
    private var backdrop: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(.black.opacity(0.22))
        }
        .ignoresSafeArea()
    }
}
