import SwiftUI

/// Bottom-center glass page indicator. Functional chrome → real Liquid Glass.
/// Hidden when there's only a single page.
struct PageDots: View {
    let count: Int
    let current: Int
    var onSelect: (Int) -> Void

    var body: some View {
        if count > 1 {
            HStack(spacing: 10) {
                ForEach(0 ..< count, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(index == current ? 0.95 : 0.4))
                        .frame(width: 7, height: 7)
                        .scaleEffect(index == current ? 1.15 : 1)
                        .contentShape(.rect)
                        .onTapGesture { onSelect(index) }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassEffect(.regular, in: .capsule)
            .animation(Metrics.pop, value: current)
        }
    }
}
