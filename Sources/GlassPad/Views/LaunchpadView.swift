import SwiftUI

/// Root overlay view: dimmed/blurred backdrop, a glass search pill, a horizontally
/// paged item grid, glass page dots, and the morphing folder overlay.
///
/// The whole tree lives in one `GlassEffectContainer` so the grid's folder tiles
/// and the expanded folder panel share a namespace and can morph between each
/// other. The folder's full-screen dim sits above the chrome but below the panel.
struct LaunchpadView: View {
    @Bindable var model: LaunchpadModel
    var onDismiss: () -> Void

    @FocusState private var searchFocused: Bool
    @State private var appeared = false
    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: Metrics.glassContainerSpacing) {
            ZStack {
                backdrop

                VStack(spacing: 0) {
                    SearchPill(query: $model.query, isFocused: $searchFocused)
                        .padding(.top, Metrics.searchTopPadding)
                        .padding(.bottom, Metrics.searchBottomPadding)

                    PagedGrid(model: model, namespace: glassNamespace) { app in
                        launchAndDismiss(app)
                    }

                    PageDots(count: model.pageCount, current: model.currentPage) { page in
                        model.goToPage(page)
                    }
                    .frame(height: Metrics.pageDotsAreaHeight)
                }

                if let folder = model.openFolder {
                    // Full-screen dim + click-anywhere-to-close, above the chrome.
                    Rectangle()
                        .fill(.black.opacity(Metrics.folderOverlayDim))
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { closeFolder() }

                    // The morph target panel, centered over the whole window.
                    FolderOverlay(
                        folder: folder,
                        apps: model.resolvedApps(in: folder),
                        launchingItemID: model.launchingItemID,
                        namespace: glassNamespace,
                        onLaunch: { app in launchAndDismiss(app) },
                        onRename: { name in model.renameFolder(folder, to: name) }
                    )
                }
            }
        }
        .scaleEffect(appeared ? 1 : Metrics.appearScaleFrom)
        .onAppear {
            model.resetTransientState()
            withAnimation(reduceMotion ? nil : Metrics.pop) { appeared = true }
            DispatchQueue.main.async { searchFocused = true }
        }
        .onChange(of: model.query) {
            model.handleQueryChange()
        }
    }

    private func closeFolder() {
        withAnimation(reduceMotion ? nil : Metrics.morph) { model.openFolder = nil }
    }

    /// Pop the icon, then let the controller dismiss after a beat (generation-
    /// guarded there) so the launch animation reads and a fast re-summon is safe.
    private func launchAndDismiss(_ app: InstalledApp) {
        model.launch(app)
        onDismiss()
    }

    /// The blurred desktop the glass refracts. The material samples the window
    /// backdrop (the live desktop); the black tint dims it.
    private var backdrop: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(.black.opacity(Metrics.backdropDim))
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        // Click empty space to dismiss (real Launchpad). When a folder is open its
        // own dim overlay sits above this and handles the tap to close the folder.
        .onTapGesture { if model.openFolder == nil { onDismiss() } }
    }
}
