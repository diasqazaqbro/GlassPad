import SwiftUI

/// Horizontally paged grid of launcher items (apps + folders).
///
/// ## Why this pager is buttery, stable, and coexists with drag-to-reorder
///
/// Paging is a **custom offset/transform pager**, not a `ScrollView`. Every
/// `ScrollView` strategy (`.paging`, a custom `ScrollTargetBehavior`,
/// `.viewAligned(.alwaysByOne)`) lagged because each one runs scroll *physics* and
/// re-evaluates layout per frame as the content offset changes. This pager instead
/// lays out an **eager** `HStack` of full-width pages once and slides the whole
/// stack with a single `.offset(x:)`. A page flip is then a pure GPU layer
/// transform of already-rendered layers — exactly the native-Launchpad path.
///
///  1. **BUTTERY.** A swipe mutates one `CGFloat` (`model.dragTranslation`) and the
///     view applies it as `.offset(x:)`. No scroll re-layout, no per-frame page
///     re-slice (`model.pages` is O(1) stored), no Liquid Glass resample (this grid
///     renders *outside* any `GlassEffectContainer`, see `LaunchpadView`). The GPU
///     just composites ready pages — 60fps with zero stutter.
///
///  2. **DRIVEN BY SCROLL-WHEEL, COEXISTS WITH REORDER.** The swipe is captured by an
///     `NSEvent .scrollWheel` *local monitor* in `OverlayWindowController` — a
///     two-finger trackpad event stream. A local monitor sits **above** the
///     responder chain: it intercepts every scroll routed to the overlay *before*
///     any view hit-test, so it sees the swipe regardless of which SwiftUI cell is
///     under the cursor (a *background sibling* `NSView` would NOT — scroll is
///     routed by hit-test to the cell under the cursor and walks that cell's
///     ancestors, never sideways to a sibling). Drag-to-reorder is a **one-finger
///     left-mouse `DragGesture`** on each `ItemCell` (see below). A two-finger
///     precise-scroll stream and a one-finger click-drag are physically disjoint
///     NSEvent streams, so the pager and the cell reorder can never contend for one
///     gesture — and `handleScroll` additionally suppresses paging while a reorder
///     drag is live, so an edge-flip and a stray swipe can't both write `currentPage`.
///
///  3. **ONE PAGE PER SWIPE.** The monitor accumulates `scrollingDeltaX` while the
///     gesture is live and, on lift, commits to **at most ±1 page** by displacement
///     or velocity (`model.endPaging`). Momentum frames are swallowed, so a flick
///     never coasts two pages and never rests between pages.
///
///  4. **LIVE FINGER-FOLLOW.** While the gesture is live the stack tracks the finger
///     in real time (`model.dragTranslation`) and rubber-bands past the first/last
///     page; on release it springs to the committed page. Most native feel.
///     Reduce-motion drops the live track + spring and jumps instantly.
///
///  5. **SYNCS `model.currentPage`.** The resting offset is `-currentPage *
///     pageWidth`, so page dots, arrows (`model.move`), and `Cmd+1…9`
///     (`model.goToPage`) all animate the offset simply by changing `currentPage`.
///     Swipe commits flow the *same* way: the monitor sets `currentPage` and zeroes
///     `dragTranslation`, the view springs to the resting page. One source of truth,
///     one direction (`currentPage → offset`), no ping-pong bridge.
struct PagedGrid: View {
    @Bindable var model: LaunchpadModel
    var namespace: Namespace.ID
    /// Forwarded to `FolderCell`: render folder tiles as real glass (for the morph)
    /// only while a folder is open — i.e. when the grid is static, never mid-swipe.
    var useLiveGlass: Bool = false
    var onLaunch: (InstalledApp) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let scale = AppSettings.gridDensity.scale
            let cols = Metrics.columnCount(forWidth: geo.size.width, scale: scale)
            let rows = Metrics.rowCount(forHeight: geo.size.height, scale: scale)
            let pageWidth = geo.size.width

            // The resting offset for the current page, plus the live swipe
            // translation the scroll monitor publishes. While the gesture is live,
            // `dragTranslation` follows the finger; on release the monitor zeroes it
            // and (maybe) advances `currentPage`, so the rest position springs to the
            // new page. One `.offset(x:)` for the whole eager stack.
            let restOffset = -CGFloat(model.currentPage) * pageWidth
            let liveOffset = restOffset + model.dragTranslation

            // EAGER HStack (not Lazy): every page + its cells are built up front, so a
            // swipe never realizes a page's ~35 cells mid-flip — that just-in-time
            // realization was the original scroll hitch. The page count is small and
            // bounded; the one-time build at appear is cheap (icons load async,
            // cached) and off-screen pages are clipped, so eager realization adds no
            // per-frame draw cost. A flip just composites ready layers.
            HStack(spacing: 0) {
                ForEach(model.pages.indices, id: \.self) { index in
                    PageView(
                        items: model.pages[index],
                        model: model,
                        namespace: namespace,
                        iconScale: scale,
                        useLiveGlass: useLiveGlass,
                        onLaunch: onLaunch
                    )
                    .frame(width: pageWidth)
                }
            }
            // Anchor the stack's leading edge to the container's leading edge, then
            // slide it. (`.leading` keeps page 0 at x=0 so `-page * width` is exact.)
            .frame(width: pageWidth, alignment: .leading)
            .offset(x: liveOffset)
            // Animate ONLY the resting page change (commit / dots / keyboard). The
            // live finger-follow updates `dragTranslation` while `isPaging` is true,
            // and we suppress the spring then so the stack tracks the finger 1:1
            // without a spring lagging behind. The commit zeroes `dragTranslation`
            // and clears `isPaging`, re-enabling the spring to the resting page.
            .animation(reduceMotion || model.isPaging ? nil : Metrics.pageSpring,
                       value: model.currentPage)
            .animation(reduceMotion || model.isPaging ? nil : Metrics.pageSpring,
                       value: model.dragTranslation)
            // Clip off-screen pages so neighbors never draw outside the container.
            .frame(width: pageWidth, height: geo.size.height, alignment: .leading)
            .clipped()
            .overlay {
                // Search results live in their own SearchResultsView (LaunchpadView
                // swaps this whole grid out while searching), so here we only need the
                // at-rest "no apps installed" empty state.
                if !model.searching && model.didLoad && model.displayedItems.isEmpty {
                    NoAppsView()
                }
            }
            // Publish the page width so the scroll monitor (in the controller) can do
            // its commit-fraction + rubber-band math in real units.
            .onAppear {
                model.setGrid(columns: cols, rows: rows)
                model.pageWidth = pageWidth
            }
            .onChange(of: pageWidth) { _, w in model.pageWidth = w }
            .onChange(of: cols) { model.setGrid(columns: cols, rows: rows) }
            .onChange(of: rows) { model.setGrid(columns: cols, rows: rows) }
        }
    }
}

/// A single page laid out by **computed slot position** (a `ZStack` of cells each at
/// its `.position`), NOT nested VStack/HStack rows.
///
/// ## Why position-based, and why it's still swipe-safe
///
/// Nested rows cannot animate a *cross-row* move during reorder: a cell that moves
/// from the end of one row to the start of the next is removed from one `HStack` and
/// inserted into a different `ForEach` subtree — SwiftUI crossfades/pops it instead of
/// sliding. With one `ForEach` of stable identities each driven by `.position(x:y:)`,
/// a slot change interpolates x AND y together along a straight line — the real
/// Launchpad glide. The layout is eager (every cell built once) and flat, so the
/// outer `.offset` page-flip still composites a ready layer at 60fps.
///
/// The reflow spring is keyed on `model.reorderRevision` (bumped only when a live drag
/// changes the insertion index), so it can NEVER fire on a page swipe (which changes
/// `currentPage`, not the revision).
private struct PageView: View {
    let items: [LaunchpadItem]
    @Bindable var model: LaunchpadModel
    var namespace: Namespace.ID
    var iconScale: CGFloat
    var useLiveGlass: Bool
    var onLaunch: (InstalledApp) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let cols = max(1, model.columns)
            let margin = Metrics.gridHorizontalMargin
            // Equal-share column pitch — cells used to be `.frame(maxWidth:.infinity)`
            // inside a margin, so each column's share is (usable − gaps)/cols.
            let cellW = (geo.size.width - margin * 2 - CGFloat(cols - 1) * Metrics.columnSpacing) / CGFloat(cols)
            let pitchX = cellW + Metrics.columnSpacing
            let rowPitch = (Metrics.cellHeight + Metrics.rowSpacing) * iconScale

            ZStack(alignment: .topLeading) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let col = index % cols
                    let row = index / cols
                    ItemCell(item: item, model: model, namespace: namespace,
                             iconScale: iconScale, useLiveGlass: useLiveGlass, onLaunch: onLaunch)
                        .frame(width: cellW, height: rowPitch)
                        .position(x: margin + CGFloat(col) * pitchX + cellW / 2,
                                  y: rowPitch * (CGFloat(row) + 0.5))
                        // The lifted item is invisible in-grid (its gap) — the floating
                        // DragFloater in LaunchpadView shows the real icon at the cursor.
                        .opacity(model.draggingItemID == item.id ? 0 : 1)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            // Animate slot changes ONLY when a live drag bumps the revision — never on
            // currentPage (that's the outer offset spring) and never on plain reloads.
            .animation(reduceMotion ? nil : Metrics.reorderSpring, value: model.reorderRevision)
        }
    }
}

/// Wraps an app/folder cell with **live-reflow** drag-to-reorder.
///
/// The reorder gesture is a one-finger left-mouse `DragGesture` reported in the shared
/// `"gridSpace"` coordinate space. It coexists with everything because:
///   • Paging is a two-finger `.scrollWheel` stream (a disjoint NSEvent stream owned by
///     `OverlayWindowController`) — it can never contend with a click-drag.
///   • A quick tap stays under the gesture's `minimumDistance`, so the inner `Button`
///     still launches; only a deliberate drag (≥ threshold) lifts the cell.
/// On the first qualifying move it calls `beginReorder`; subsequent moves reflow live;
/// release commits (or merges into a folder). A glowing overlay marks a merge target.
private struct ItemCell: View {
    let item: LaunchpadItem
    @Bindable var model: LaunchpadModel
    var namespace: Namespace.ID
    var iconScale: CGFloat
    var useLiveGlass: Bool
    var onLaunch: (InstalledApp) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .overlay {
                if model.folderTargetID == item.id {
                    RoundedRectangle(cornerRadius: Metrics.cellCornerRadius, style: .continuous)
                        .fill(.white.opacity(Metrics.folderTargetHighlightOpacity))
                        .allowsHitTesting(false)
                }
            }
            .gesture(reorderGesture)
    }

    private var reorderGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named(LaunchpadView.gridSpace))
            .onChanged { value in
                if model.draggingItemID == nil {
                    model.beginReorder(id: item.id, at: value.location)
                }
                model.updateReorder(cursor: value.location)
            }
            .onEnded { _ in model.endReorder() }
    }

    @ViewBuilder
    private var content: some View {
        switch item {
        case .app(let app):
            AppCell(
                app: app,
                isSelected: model.selectedItemID == item.id,
                isLaunching: model.launchingItemID == item.id,
                iconScale: iconScale
            ) { onLaunch(app) }
        case .folder(let folder):
            FolderCell(
                folder: folder,
                apps: model.resolvedApps(in: folder),
                isSelected: model.selectedItemID == item.id,
                isOpen: model.openFolder?.id == folder.id,
                iconScale: iconScale,
                namespace: namespace,
                useLiveGlass: useLiveGlass
            ) {
                withAnimation(reduceMotion ? nil : Metrics.morph) { model.openFolder = folder }
            }
        }
    }
}

/// The lifted icon that floats under the cursor during a reorder drag. Lives as a bare
/// sibling in `LaunchpadView`'s root ZStack — OUTSIDE the pager's `.clipped()` and any
/// `GlassEffectContainer` — so it can travel across pages without being clipped and
/// never forces a glass resample. Reads `dragCursor` itself so the rest of the overlay
/// doesn't re-evaluate on every pointer frame.
struct DragFloater: View {
    @Bindable var model: LaunchpadModel
    var iconScale: CGFloat
    @State private var icon: NSImage?

    var body: some View {
        Group {
            switch model.draggingItem {
            case .app:
                if let icon {
                    Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.12))
                }
            case .folder:
                Image(systemName: "folder.fill")
                    .resizable().scaledToFit()
                    .foregroundStyle(.white.opacity(0.95))
            case .none:
                EmptyView()
            }
        }
        .frame(width: Metrics.iconSize * iconScale, height: Metrics.iconSize * iconScale)
        .scaleEffect(Metrics.dragLiftScale)
        .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
        .position(model.dragCursor)
        .allowsHitTesting(false)
        .task(id: iconPath) {
            if let iconPath { icon = await IconLoader.shared.icon(forPath: iconPath) }
        }
    }

    private var iconPath: String? {
        if case .app(let app) = model.draggingItem { return app.id }
        return nil
    }
}

/// Shown when a search matches nothing (shared with `SearchResultsView`).
struct EmptyResultsView: View {
    let query: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.white.opacity(0.6))
            Text(L("results.empty", query))
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
    }
}

/// Shown after a scan finds no installed apps at all (distinct from a search miss).
private struct NoAppsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.white.opacity(0.6))
            Text(L("apps.empty"))
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
    }
}
