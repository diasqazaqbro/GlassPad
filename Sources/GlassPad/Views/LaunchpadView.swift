import SwiftUI

/// Root overlay view: dimmed/blurred backdrop, a glass search pill, a horizontally
/// paged app grid, and glass page dots. Fades+scales in on appear.
struct LaunchpadView: View {
    @Bindable var model: LaunchpadModel
    var onDismiss: () -> Void

    @FocusState private var searchFocused: Bool
    @State private var appeared = false

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 0) {
                SearchPill(query: $model.query, isFocused: $searchFocused)
                    .padding(.top, Metrics.searchTopPadding)
                    .padding(.bottom, Metrics.searchBottomPadding)

                PagedGrid(model: model) { app in
                    model.launch(app)
                    onDismiss()
                }

                PageDots(count: model.pageCount, current: model.currentPage) { page in
                    model.goToPage(page)
                }
                .frame(height: Metrics.pageDotsAreaHeight)
            }
        }
        .scaleEffect(appeared ? 1 : Metrics.appearScaleFrom)
        .onAppear {
            withAnimation(Metrics.pop) { appeared = true }
            // Defer one runloop tick so the field is in the hierarchy first.
            DispatchQueue.main.async { searchFocused = true }
        }
        .onChange(of: model.query) {
            model.handleQueryChange()
        }
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
