import SwiftUI

/// Root overlay view: dimmed/blurred backdrop, a glass search pill, a horizontally
/// paged item grid, glass page dots, and the morphing folder overlay.
struct LaunchpadView: View {
    @Bindable var model: LaunchpadModel
    var onDismiss: () -> Void

    @FocusState private var searchFocused: Bool
    @State private var appeared = false
    @Namespace private var glassNamespace

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                SearchPill(query: $model.query, isFocused: $searchFocused)
                    .padding(.top, Metrics.searchTopPadding)
                    .padding(.bottom, Metrics.searchBottomPadding)

                // The grid's folder tiles and the expanded folder panel share this
                // container + namespace so the glass can morph between them.
                GlassEffectContainer(spacing: Metrics.glassContainerSpacing) {
                    ZStack {
                        PagedGrid(model: model, namespace: glassNamespace) { app in
                            model.launch(app)
                            onDismiss()
                        }

                        if let folder = model.openFolder {
                            FolderOverlay(
                                folder: folder,
                                apps: model.resolvedApps(in: folder),
                                namespace: glassNamespace,
                                onClose: { withAnimation(Metrics.morph) { model.openFolder = nil } },
                                onLaunch: { app in model.launch(app); onDismiss() },
                                onRename: { name in model.renameFolder(folder, to: name) }
                            )
                        }
                    }
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
