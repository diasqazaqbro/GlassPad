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
///  2. **DRIVEN BY SCROLL-WHEEL, NOT A DRAGGESTURE.** The swipe is captured by an
///     `NSEvent .scrollWheel` *local monitor* in `OverlayWindowController` — a
///     two-finger trackpad event stream. A local monitor sits **above** the
///     responder chain: it intercepts every scroll routed to the overlay *before*
///     any view hit-test, so it sees the swipe regardless of which SwiftUI cell is
///     under the cursor (a *background sibling* `NSView` would NOT — scroll is
///     routed by hit-test to the cell under the cursor and walks that cell's
///     ancestors, never sideways to a sibling; and a *front* catcher that returned
///     `hitTest → nil` would remove itself from scroll routing too). It is
///     deliberately **not** a SwiftUI `DragGesture` (a one-finger drag), which would
///     fight the per-cell `.draggable`. Trackpad scroll and click-drag are disjoint
///     NSEvent streams, so the pager and the cell reorder can never contend for one
///     gesture. The `.draggable`/`.dropDestination` on `ItemCell` are untouched.
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
                if model.searching && model.displayedItems.isEmpty {
                    EmptyResultsView(query: model.query)
                } else if !model.searching && model.didLoad && model.displayedItems.isEmpty {
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

/// A single page: a grid of `model.columns` columns, top-aligned and centered.
private struct PageView: View {
    let items: [LaunchpadItem]
    @Bindable var model: LaunchpadModel
    var namespace: Namespace.ID
    var iconScale: CGFloat
    var useLiveGlass: Bool
    var onLaunch: (InstalledApp) -> Void

    var body: some View {
        // Eager rows (VStack/HStack), NOT LazyVGrid: a lazy grid defers realizing
        // its cells until they enter the viewport, which re-introduces a per-page
        // hitch even with an eager outer HStack. Explicit rows are built immediately,
        // so a flip composites a ready page.
        let columnCount = max(1, model.columns)
        let rows = stride(from: 0, to: items.count, by: columnCount).map {
            Array(items[$0 ..< min($0 + columnCount, items.count)])
        }
        return VStack(spacing: Metrics.rowSpacing) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: Metrics.columnSpacing) {
                    ForEach(rows[r]) { item in
                        ItemCell(item: item, model: model, namespace: namespace,
                                 iconScale: iconScale, useLiveGlass: useLiveGlass, onLaunch: onLaunch)
                            .frame(maxWidth: .infinity)
                    }
                    // Keep a short last row left-aligned (cells stay column-width).
                    if rows[r].count < columnCount {
                        ForEach(0 ..< (columnCount - rows[r].count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.gridHorizontalMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// Wraps an app/folder cell with drag-and-drop. Dropping onto a cell's center
/// makes/extends a folder; dropping near the left/right edge reorders.
///
/// Drag-to-reorder coexists with the pager because paging is driven by a
/// **scroll-wheel** (two-finger trackpad) event stream captured in
/// `OverlayWindowController`, while a cell lift is a **one-finger click-drag**
/// surfaced here as `.draggable`. The two are disjoint NSEvent streams, so there is
/// no container gesture to swallow a cell's drag and nothing for the cell to fight.
private struct ItemCell: View {
    let item: LaunchpadItem
    @Bindable var model: LaunchpadModel
    var namespace: Namespace.ID
    var iconScale: CGFloat
    var useLiveGlass: Bool
    var onLaunch: (InstalledApp) -> Void

    @State private var width: CGFloat = Metrics.cellWidth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .background(widthReader)
            .draggable(item.id) { dragPreview }
            .dropDestination(for: String.self) { dropped, location in
                guard let id = dropped.first else { return false }
                return model.handleDrop(draggedID: id, ontoID: item.id, region: region(forX: location.x))
            }
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

    @ViewBuilder
    private var dragPreview: some View {
        switch item {
        case .app(let app):
            DragPreview(path: app.id)
        case .folder:
            Image(systemName: "folder.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white)
        }
    }

    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { width = proxy.size.width }
                .onChange(of: proxy.size.width) { _, w in width = w }
        }
    }

    private func region(forX x: CGFloat) -> DropRegion {
        let edge = max(20, width * 0.28)
        if x < edge { return .before }
        if x > width - edge { return .after }
        return .onto
    }
}

/// Shown when a search matches nothing.
private struct EmptyResultsView: View {
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

/// Icon-sized drag image.
private struct DragPreview: View {
    let path: String
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.2))
            }
        }
        .frame(width: 72, height: 72)
        .task(id: path) { icon = await IconLoader.shared.icon(forPath: path) }
    }
}
