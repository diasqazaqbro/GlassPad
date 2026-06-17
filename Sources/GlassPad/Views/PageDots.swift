import SwiftUI

/// Bottom-center glass page indicator. Functional chrome → real Liquid Glass.
/// Hidden when there's only a single page.
struct PageDots: View {
    let count: Int
    let current: Int
    var onSelect: (Int) -> Void

    @State private var hovered: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if count > 1 {
            HStack(spacing: 10) {
                ForEach(0 ..< count, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(opacity(index)))
                        .frame(width: 7, height: 7)
                        .scaleEffect(scale(index))
                        .contentShape(.rect)
                        .onHover { hovered = $0 ? index : (hovered == index ? nil : hovered) }
                        .onTapGesture { onSelect(index) }
                        .accessibilityLabel(L("page.label", index + 1))
                        .accessibilityHint(L("page.hint", index + 1))
                        .accessibilityAddTraits(index == current ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassEffect(.regular, in: .capsule)
            .animation(reduceMotion ? nil : Metrics.pop, value: current)
            .animation(reduceMotion ? nil : Metrics.pop, value: hovered)
        }
    }

    private func opacity(_ index: Int) -> Double {
        if index == current { return 0.95 }
        return hovered == index ? 0.7 : 0.4
    }

    private func scale(_ index: Int) -> CGFloat {
        if hovered == index { return 1.35 }
        return index == current ? 1.15 : 1
    }
}
