import SwiftUI

/// Root overlay view: dimmed/blurred backdrop, a glass search pill, a horizontally
/// paged item grid, glass page dots, and the morphing folder overlay.
///
/// ## Glass layering (the paging-smoothness fix)
///
/// The scrolling `PagedGrid` is deliberately **outside** any `GlassEffectContainer`
/// and sits behind the chrome as a plain `ZStack` sibling. During a swipe the grid
/// is therefore not a live glass member: nothing re-samples a backdrop as the icons
/// translate, exactly like the real Launchpad. The functional chrome (search pill,
/// page dots, gear) lives in its own `GlassEffectContainer` whose geometry is static
/// during a swipe, so its glass pass is computed once, not per frame.
///
/// The folder open/close morph (`FolderCell` tile ↔ `FolderOverlay`) needs both
/// `glassEffectID` endpoints inside *one* container. While a folder is open the
/// grid is static, so it is free to co-reside in a container then: a single
/// `GlassEffectContainer` wraps **both** the grid (whose open-folder tile is the
/// morph source, rendered as real glass via `useLiveGlass`) and the `FolderOverlay`
/// panel (the target). When no folder is open the grid is a bare sibling with no
/// container — the swipe-smooth path. The folder's full-screen dim sits above the
/// chrome but below the panel.
struct LaunchpadView: View {
    /// Shared coordinate space anchoring the root ZStack: cell reorder `DragGesture`s
    /// report their cursor here and the floating `DragFloater` is positioned here, so
    /// the two always agree on one frame.
    static let gridSpace = "gridSpace"

    @Bindable var model: LaunchpadModel
    var onDismiss: () -> Void
    var onOpenSettings: () -> Void

    @FocusState private var searchFocused: Bool
    @State private var appeared = false
    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            backdrop

            // The content layer. While no folder is open it is a bare sibling — NOT
            // inside any GlassEffectContainer — so a swipe never recomputes glass
            // behind the moving icons (the smooth path). While a folder IS open the
            // grid is static, so it is wrapped (with the FolderOverlay panel) in one
            // shared container below; in that state its open-folder tile is real glass
            // (`useLiveGlass`) and co-contained with the panel for a clean morph.
            //
            // While searching we swap the paged grid out entirely for the vertical
            // SearchResultsView — the custom pager is then not even in the tree, so it
            // can't be perturbed by the search UI.
            if model.openFolder == nil {
                if model.searching {
                    SearchResultsView(
                        model: model,
                        namespace: glassNamespace,
                        onLaunch: { launchAndDismiss($0) },
                        onOpenFile: { openFileAndDismiss($0) },
                        onSearchWeb: { model.searchWeb(model.query); onDismiss() }
                    )
                } else {
                    grid
                }
            }

            // Functional chrome: its own container, static during a swipe → one
            // glass pass, not per-frame.
            GlassEffectContainer(spacing: Metrics.glassContainerSpacing) {
                ZStack {
                    VStack(spacing: 0) {
                        SearchPill(query: $model.query, isFocused: $searchFocused)
                            .padding(.top, Metrics.searchTopPadding)
                            .padding(.bottom, Metrics.searchBottomPadding)

                        Spacer(minLength: 0)

                        // Page dots are meaningless for the vertical search list.
                        if !model.searching {
                            PageDots(count: model.pageCount, current: model.currentPage) { page in
                                model.goToPage(page)
                            }
                            .frame(height: Metrics.pageDotsAreaHeight)
                        }
                    }

                    if model.openFolder == nil {
                        settingsButton
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(24)
                    }
                }
            }

            if let folder = model.openFolder {
                // Folder-open layer: ONE container holding both the (static) grid and
                // the FolderOverlay panel, so the tile↔panel morph has both
                // glassEffectID endpoints co-contained. Present only while open, so
                // this container is never live during a swipe.
                GlassEffectContainer(spacing: Metrics.glassContainerSpacing) {
                    ZStack {
                        grid

                        // Full-screen dim + click-anywhere-to-close, above the grid.
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

            // The lifted icon during a reorder drag — LAST sibling, so it floats above
            // everything, OUTSIDE the pager's clip and any glass container, and can
            // travel across pages. Gated off while a folder is open (no reorder there).
            if model.draggingItemID != nil, model.openFolder == nil {
                DragFloater(model: model, iconScale: AppSettings.gridDensity.scale)
            }
        }
        .coordinateSpace(.named(Self.gridSpace))
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

    /// The paged grid. Rendered either as a bare sibling (no folder open → swipe-
    /// smooth, no glass container) or inside the folder-open container (folder open →
    /// static, co-contained with the panel for the morph). `useLiveGlass` mirrors
    /// the open state so the open-folder tile is real glass exactly when the morph
    /// needs it.
    private var grid: some View {
        PagedGrid(model: model, namespace: glassNamespace, useLiveGlass: model.openFolder != nil) { app in
            launchAndDismiss(app)
        }
        .padding(.top, Metrics.gridTopInset)
        .padding(.bottom, Metrics.pageDotsAreaHeight)
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

    /// Open a file hit with its default app, then dismiss the overlay.
    private func openFileAndDismiss(_ file: FileResult) {
        model.openFile(file)
        onDismiss()
    }

    /// A glass gear button in the corner — the visible way into Settings (so it
    /// doesn't depend on the menu-bar icon, which the overlay covers, or on ⌘,).
    private var settingsButton: some View {
        Button(action: onOpenSettings) {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 42, height: 42)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("menu.settings"))
    }

    /// The blurred desktop the glass refracts. The material samples the window
    /// backdrop (the live desktop); the black tint dims it.
    private var backdrop: some View {
        ZStack {
            if let wallpaper = model.wallpaper {
                // Already blurred at capture time; the dim sits on top for legibility.
                Image(nsImage: wallpaper)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
            Rectangle().fill(.black.opacity(AppSettings.backdropDim))
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        // Click empty space to dismiss (real Launchpad). When a folder is open its
        // own dim overlay sits above this and handles the tap to close the folder.
        .onTapGesture { if model.openFolder == nil { onDismiss() } }
    }
}
