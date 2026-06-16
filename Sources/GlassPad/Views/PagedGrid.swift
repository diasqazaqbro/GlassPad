import SwiftUI

/// Horizontally paged grid. Each page is a full-width grid of `model.columns`
/// columns. Paging is driven three ways, all kept in sync via `scrollPosition`:
/// trackpad/scroll swipe, the page dots, and the keyboard (`model.currentPage`).
struct PagedGrid: View {
    @Bindable var model: LaunchpadModel
    var onLaunch: (InstalledApp) -> Void

    @State private var scrolledPage: Int?

    var body: some View {
        GeometryReader { geo in
            let cols = Metrics.columnCount(forWidth: geo.size.width)
            let rows = Metrics.rowCount(forHeight: geo.size.height)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(model.pages.enumerated()), id: \.offset) { index, items in
                        PageView(items: items, model: model, onLaunch: onLaunch)
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
            // User swipe → model.
            .onChange(of: scrolledPage) { _, new in
                if let new, new != model.currentPage { model.currentPage = new }
            }
            // Keyboard / dots → scroll.
            .onChange(of: model.currentPage) { _, new in
                if scrolledPage != new {
                    withAnimation(Metrics.pop) { scrolledPage = new }
                }
            }
        }
    }
}

/// A single page of the grid. Reads `model.columns` so its layout always matches
/// the page chunking, and highlights the keyboard-selected app.
private struct PageView: View {
    let items: [InstalledApp]
    @Bindable var model: LaunchpadModel
    var onLaunch: (InstalledApp) -> Void

    var body: some View {
        LazyVGrid(columns: columns, spacing: Metrics.rowSpacing) {
            ForEach(items) { app in
                AppCell(app: app, isSelected: model.selectedApp?.id == app.id) {
                    onLaunch(app)
                }
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
