import SwiftUI

/// Root overlay view: dimmed/blurred backdrop, a glass search pill, and a fuzzy
/// filtered grid of apps. Fades+scales in on appear; clicking a cell launches
/// and dismisses.
struct LaunchpadView: View {
    @Bindable var model: LaunchpadModel
    var onDismiss: () -> Void

    @FocusState private var searchFocused: Bool
    @State private var appeared = false

    var body: some View {
        ZStack {
            backdrop
            content
        }
        .scaleEffect(appeared ? 1 : Metrics.appearScaleFrom)
        .onAppear {
            withAnimation(Metrics.pop) { appeared = true }
            // Defer one runloop tick so the field is in the hierarchy first.
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    private var content: some View {
        GeometryReader { geo in
            let columnCount = Metrics.columnCount(forWidth: geo.size.width)
            VStack(spacing: 0) {
                SearchPill(query: $model.query, isFocused: $searchFocused)
                    .padding(.top, Metrics.searchTopPadding)
                    .padding(.bottom, Metrics.searchBottomPadding)

                ScrollView {
                    LazyVGrid(columns: columns(columnCount), spacing: Metrics.rowSpacing) {
                        ForEach(model.filteredApps) { app in
                            AppCell(app: app) {
                                model.launch(app)
                                onDismiss()
                            }
                        }
                    }
                    .padding(.horizontal, Metrics.gridHorizontalMargin)
                    .padding(.bottom, Metrics.gridBottomInset)
                }
                .scrollClipDisabled()
            }
        }
    }

    private func columns(_ count: Int) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: Metrics.columnSpacing, alignment: .top),
            count: count
        )
    }

    /// The blurred desktop the glass refracts. The material samples the window
    /// backdrop (the live desktop); the black tint dims it.
    private var backdrop: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(.black.opacity(Metrics.backdropDim))
        }
        .ignoresSafeArea()
    }
}
