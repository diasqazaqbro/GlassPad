import SwiftUI

/// Horizontally paged grid of launcher items (apps + folders). Paging stays in
/// sync across swipe, dots, and keyboard via `scrollPosition` ↔ `model.currentPage`.
struct PagedGrid: View {
    @Bindable var model: LaunchpadModel
    var namespace: Namespace.ID
    var onLaunch: (InstalledApp) -> Void

    @State private var scrolledPage: Int?

    var body: some View {
        GeometryReader { geo in
            let cols = Metrics.columnCount(forWidth: geo.size.width)
            let rows = Metrics.rowCount(forHeight: geo.size.height)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(model.pages.enumerated()), id: \.offset) { index, items in
                        PageView(items: items, model: model, namespace: namespace, onLaunch: onLaunch)
                            .frame(width: geo.size.width)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrolledPage)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .onAppear {
                model.setGrid(columns: cols, rows: rows)
                scrolledPage = model.currentPage
            }
            .onChange(of: cols) { model.setGrid(columns: cols, rows: rows) }
            .onChange(of: rows) { model.setGrid(columns: cols, rows: rows) }
            .onChange(of: scrolledPage) { _, new in
                if let new, new != model.currentPage { model.currentPage = new }
            }
            .onChange(of: model.currentPage) { _, new in
                if scrolledPage != new {
                    withAnimation(Metrics.pop) { scrolledPage = new }
                }
            }
        }
    }
}

/// A single page: a grid of `model.columns` columns, top-aligned and centered.
private struct PageView: View {
    let items: [LaunchpadItem]
    @Bindable var model: LaunchpadModel
    var namespace: Namespace.ID
    var onLaunch: (InstalledApp) -> Void

    var body: some View {
        LazyVGrid(columns: columns, spacing: Metrics.rowSpacing) {
            ForEach(items) { item in
                ItemCell(item: item, model: model, namespace: namespace, onLaunch: onLaunch)
            }
        }
        .padding(.horizontal, Metrics.gridHorizontalMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: Metrics.columnSpacing, alignment: .top),
            count: model.columns
        )
    }
}

/// Wraps an app/folder cell with drag-and-drop. Dropping onto a cell's center
/// makes/extends a folder; dropping near the left/right edge reorders.
private struct ItemCell: View {
    let item: LaunchpadItem
    @Bindable var model: LaunchpadModel
    var namespace: Namespace.ID
    var onLaunch: (InstalledApp) -> Void

    @State private var width: CGFloat = Metrics.cellWidth

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
            AppCell(app: app, isSelected: model.selectedItemID == item.id) { onLaunch(app) }
        case .folder(let folder):
            FolderCell(
                folder: folder,
                apps: model.resolvedApps(in: folder),
                isSelected: model.selectedItemID == item.id,
                isOpen: model.openFolder?.id == folder.id,
                namespace: namespace
            ) {
                withAnimation(Metrics.morph) { model.openFolder = folder }
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
