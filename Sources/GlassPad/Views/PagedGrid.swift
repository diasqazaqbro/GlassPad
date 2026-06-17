import SwiftUI

struct PagedGrid: View {
    @Bindable var model: LaunchpadModel
    var namespace: Namespace.ID
    var onLaunch: (InstalledApp) -> Void

    @State private var scrolledPage: Int?
    @State private var syncingFromModel = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let scale = AppSettings.gridDensity.scale
            let cols = Metrics.columnCount(forWidth: geo.size.width, scale: scale)
            let rows = Metrics.rowCount(forHeight: geo.size.height, scale: scale)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(model.pages.enumerated()), id: \.offset) { index, items in
                        PageView(items: items, model: model, namespace: namespace, iconScale: scale, onLaunch: onLaunch)
                            .frame(width: geo.size.width)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition(id: $scrolledPage, anchor: .center)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
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
            .onChange(of: scrolledPage) { _, new in
                guard !syncingFromModel, let new, new != model.currentPage else { return }
                model.currentPage = new
            }
            .onChange(of: model.currentPage) { _, new in
                guard scrolledPage != new else { return }
                syncingFromModel = true
                withAnimation(reduceMotion ? nil : Metrics.pop) { scrolledPage = new }
                DispatchQueue.main.async { syncingFromModel = false }
            }
        }
    }
}

private struct PageView: View {
    let items: [LaunchpadItem]
    @Bindable var model: LaunchpadModel
    var namespace: Namespace.ID
    var iconScale: CGFloat
    var onLaunch: (InstalledApp) -> Void

    var body: some View {
        LazyVGrid(columns: columns, spacing: Metrics.rowSpacing) {
            ForEach(items) { item in
                ItemCell(item: item, model: model, namespace: namespace, iconScale: iconScale, onLaunch: onLaunch)
            }
        }
        .padding(.horizontal, Metrics.gridHorizontalMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Metrics.columnSpacing, alignment: .top), count: model.columns)
    }
}

private struct ItemCell: View {
    let item: LaunchpadItem
    @Bindable var model: LaunchpadModel
    var namespace: Namespace.ID
    var iconScale: CGFloat
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
            AppCell(app: app, isSelected: model.selectedItemID == item.id, isLaunching: model.launchingItemID == item.id, iconScale: iconScale) { onLaunch(app) }
        case .folder(let folder):
            FolderCell(folder: folder, apps: model.resolvedApps(in: folder), isSelected: model.selectedItemID == item.id, isOpen: model.openFolder?.id == folder.id, iconScale: iconScale, namespace: namespace) {
                withAnimation(reduceMotion ? nil : Metrics.morph) { model.openFolder = folder }
            }
        }
    }

    @ViewBuilder
    private var dragPreview: some View {
        switch item {
        case .app(let app): DragPreview(path: app.id)
        case .folder: Image(systemName: "folder.fill").font(.system(size: 48)).foregroundStyle(.white)
        }
    }

    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear.onAppear { width = proxy.size.width }.onChange(of: proxy.size.width) { _, w in width = w }
        }
    }

    private func region(forX x: CGFloat) -> DropRegion {
        let edge = max(20, width * 0.28)
        if x < edge { return .before }
        if x > width - edge { return .after }
        return .onto
    }
}

private struct EmptyResultsView: View {
    let query: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass").font(.system(size: 48, weight: .light)).foregroundStyle(.white.opacity(0.6))
            Text("No results for “\(query)”").font(.system(size: 18, weight: .medium)).foregroundStyle(.white.opacity(0.85))
        }.shadow(color: .black.opacity(0.4), radius: 3, y: 1)
    }
}

private struct NoAppsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x3").font(.system(size: 48, weight: .light)).foregroundStyle(.white.opacity(0.6))
            Text("No apps found").font(.system(size: 18, weight: .medium)).foregroundStyle(.white.opacity(0.85))
        }.shadow(color: .black.opacity(0.4), radius: 3, y: 1)
    }
}

private struct DragPreview: View {
    let path: String
    @State private var icon: NSImage?
    var body: some View {
        Group {
            if let icon { Image(nsImage: icon).resizable().interpolation(.high).scaledToFit() }
            else { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.2)) }
        }
        .frame(width: 72, height: 72)
        .task(id: path) { icon = await IconLoader.shared.icon(forPath: path) }
    }
}
