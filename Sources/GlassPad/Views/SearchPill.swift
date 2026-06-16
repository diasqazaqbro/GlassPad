import SwiftUI

/// Top-center glass search capsule. This is *functional chrome*, so it gets real
/// Liquid Glass (`.glassEffect`). Auto-focused by the parent on appear.
struct SearchPill: View {
    @Binding var query: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Metrics.searchFontSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: Metrics.searchFontSize))
                .foregroundStyle(.white)
                .tint(.white)
                .focused($isFocused)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Metrics.searchFontSize))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .frame(width: Metrics.searchPillWidth, height: Metrics.searchPillHeight)
        .glassEffect(.regular.interactive(), in: .capsule)
        .animation(Metrics.pop, value: query.isEmpty)
    }
}
