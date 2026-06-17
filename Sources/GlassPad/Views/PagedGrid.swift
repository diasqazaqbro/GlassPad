import SwiftUI

/// Horizontally paged grid of launcher items (apps + folders).
///
/// ## Why this pager is stable AND smooth
///
/// Paging is driven entirely by SwiftUI's built-in **view-aligned** scrolling —
/// no custom `ScrollTargetBehavior`, no hand-rolled container `DragGesture`, no
/// manual `.offset`. There is exactly **one** source of truth for the visible
/// page (`scrolledPage`, the `.scrollPosition` id); `model.currentPage` mirrors
/// it through a single guarded, non-oscillating bridge.
///
///  1. **STABLE.** `.scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))`
///     always snaps the resting offset to a page boundary (each page is
///     `.id`-tagged and exactly the container width), so it is *mathematically
///     impossible* to come to rest between pages — no jitter, no "landed at 0.5"
///     state. `.alwaysByOne` is a hard one-page-per-gesture cap computed
///     synchronously by the framework from the live offset + velocity, so a swipe
///     can never skip a page no matter how fast, and rapid consecutive swipes each
///     resolve to one definite boundary. (The rejected `PageFlickBehavior` jumped
///     two pages because it added `fromPage ± 1` to a `fromPage` sampled
///     asynchronously, which lagged a fast gesture by a page.)
///
///  2. **COMFORTABLE.** Plain `.paging` requires dragging past the half-way point,
///     which the user found too stiff. `.viewAligned` is velocity-driven: a light
///     two-finger flick (which carries velocity, not displacement) turns the page —
///     no near-half-page drag — while `.alwaysByOne` still caps it at one page.
///
///  3. **SMOOTH (the fix).** The snap mechanic was never the lag — the *render cost
///     per scroll frame* was. Three per-frame costs are now gone:
///       • **No live Liquid Glass behind the moving icons.** This grid renders
///         *outside* any `GlassEffectContainer` (see `LaunchpadView`), and its
///         folder tiles use a cheap static material while scrolling (real glass
///         only while a folder is open, when the grid is static — `useLiveGlass`).
///         So a swipe recomputes zero glass backdrop, exactly like real Launchpad.
///       • **No per-frame page re-slice.** The page list is read from a *stored*
///         `model.pages` (O(1)); it used to be a computed property that re-`stride`d
///         + allocated ~100 items on every body evaluation.
///       • **No mid-fling thrash.** The `scrolledPage → currentPage` bridge only
///         ever writes a *different* integer (and ignores a transient `nil`), so it
///         cannot re-invalidate the body with the same value during the fling.
///
///  4. **COEXISTS WITH DRAG-TO-REORDER.** There is deliberately **no** custom
///     `DragGesture` on the container — the single most important decision here.
///     The pager rides only `ScrollView`'s native, content-drag-aware scroll
///     recognizer, so a press that begins on a `.draggable` cell starts a drag
///     session (lifting the icon) while a free horizontal pan scrolls the page.
///     Nothing on the container can swallow a cell's `.draggable` press-drag, and
///     nothing for the cell drag to fight. (A simultaneous / high-priority container
///     `DragGesture` layered over per-cell `.draggable` — the rejected anti-pattern —
///     routinely has both recognizers contend for the same press; this design
///     removes that entire class of conflict.)
///
///  5. **SYNCS with `model.currentPage`.** Swipe-driven changes flow one way
///     (`scrolledPage → currentPage`, no animation). Programmatic changes — page
///     dots, keyboard arrows via `model.move`, `Cmd+1…9` via `model.goToPage` —
///     flow the other way (`currentPage → scrolledPage`, animated), guarded by
///     `syncingFromModel` so the echo can never bounce back and restart the scroll
///     animation mid-fling.
struct PagedGrid: View {
    @Bindable var model: LaunchpadModel
    var namespace: Namespace.ID
    /// Forwarded to `FolderCell`: render folder tiles as real glass (for the morph)
    /// only while a folder is open — i.e. when the grid is static, never mid-swipe.
    var useLiveGlass: Bool = false
    var onLaunch: (InstalledApp) -> Void

    /// THE single source of truth for the visible page. Bound to `.scrollPosition`,
    /// so the scroll view and this value are identical by construction.
    @State private var scrolledPage: Int?
    /// True only while we are applying a *programmatic* scroll (dots / keyboard).
    /// Guards the `scrolledPage → currentPage` bridge from writing back the value we
    /// just set, so the two sides can never ping-pong. Set and cleared synchronously
    /// across the paired `onChange` handlers — no async re-arming, no timing race.
    @State private var syncingFromModel = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let scale = AppSettings.gridDensity.scale
            let cols = Metrics.columnCount(forWidth: geo.size.width, scale: scale)
            let rows = Metrics.rowCount(forHeight: geo.size.height, scale: scale)

            ScrollView(.horizontal) {
                // EAGER HStack (not Lazy): every page is built up front, so a swipe
                // never realizes a page's ~35 cells mid-fling — that just-in-time
                // realization was the scroll hitch. The pages count is small and
                // bounded; the one-time build at appear is cheap (icons load async,
                // cached), and off-screen pages are clipped (clipping re-enabled
                // below), so eager realization adds no per-frame draw cost.
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
                        .frame(width: geo.size.width)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            // Built-in page-aligned snapping. `.alwaysByOne` = at most one page per
            // gesture (stable), but velocity-driven so a light flick is enough (comfortable).
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition(id: $scrolledPage, anchor: .center)
            .scrollIndicators(.hidden)
            .overlay {
                if model.searching && model.displayedItems.isEmpty {
                    EmptyResultsView(query: model.query)
                } else if !model.searching && model.didLoad && model.displayedItems.isEmpty {
                    NoAppsView()
                }
            }
            .onAppear {
                model.setGrid(columns: cols, rows: rows)
                scrolledPage = model.currentPage
            }
            .onChange(of: cols) { model.setGrid(columns: cols, rows: rows) }
            .onChange(of: rows) { model.setGrid(columns: cols, rows: rows) }
            // Swipe-driven: the user dragged the scroll view to a new page. Ignore the
            // value we ourselves just set programmatically (guarded below), and ignore
            // a transient `nil` (the binding is briefly nil during layout changes).
            .onChange(of: scrolledPage) { _, new in
                guard !syncingFromModel, let new, new != model.currentPage else { return }
                model.currentPage = new
            }
            // Programmatic-driven: dots tapped or keyboard moved the page. Scroll to
            // match. Arm the guard before mutating `scrolledPage` so the resulting
            // echo is swallowed by the handler above, then disarm synchronously — the
            // `scrolledPage` onChange runs as part of this same state-application pass,
            // so by the time we return the echo has already been (and only ever could
            // be) ignored. No DispatchQueue, no timing assumption.
            .onChange(of: model.currentPage) { _, new in
                guard scrolledPage != new else { return }
                syncingFromModel = true
                withAnimation(reduceMotion ? nil : Metrics.pop) { scrolledPage = new }
                syncingFromModel = false
            }
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
        // its cells until they enter the scroll viewport, which re-introduces a
        // per-page scroll hitch even with an eager outer HStack. Explicit rows are
        // built immediately, so a swipe composites a ready page.
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
/// Drag-to-reorder coexists with the pager because the pager attaches **no custom
/// `DragGesture`** to the container — it relies solely on `ScrollView`'s native
/// scroll recognizer plus the built-in view-aligned `ScrollTargetBehavior`. That
/// recognizer is content-drag aware: a press that begins on a `.draggable` cell
/// starts a drag session (lifting the icon), while a free horizontal pan scrolls
/// the page. There is therefore nothing on the container to "swallow" the cell's
/// draggable press-drag, and nothing for the cell drag to fight.
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
