import SwiftUI

/// Vertical, sectioned search results shown INSTEAD of the paged grid while a query is
/// active (so the custom pager is structurally untouched — it isn't even in the tree).
/// Sections: matched **Apps**, then Spotlight **Files**, then a **search the web** row.
/// Keyboard selection (`model.selectedItemID`) highlights a cell and auto-scrolls to it;
/// the flat order matches `model.searchSelectionIDs`.
struct SearchResultsView: View {
    @Bindable var model: LaunchpadModel
    var namespace: Namespace.ID
    var onLaunch: (InstalledApp) -> Void
    var onOpenFile: (FileResult) -> Void
    var onSearchWeb: () -> Void

    private var scale: CGFloat { AppSettings.gridDensity.scale }
    private var appItems: [LaunchpadItem] { model.displayedItems } // apps-only while searching
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Metrics.columnSpacing, alignment: .top),
              count: max(1, model.columns))
    }
    private var isEmpty: Bool { appItems.isEmpty && model.fileResults.isEmpty }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metrics.searchSectionSpacing) {
                    if !appItems.isEmpty {
                        section(L("search.section.apps")) {
                            LazyVGrid(columns: gridColumns, spacing: Metrics.rowSpacing) {
                                ForEach(appItems) { item in
                                    if case .app(let app) = item {
                                        AppCell(app: app,
                                                isSelected: model.selectedItemID == item.id,
                                                isLaunching: model.launchingItemID == item.id,
                                                iconScale: scale) { onLaunch(app) }
                                            .id(item.id)
                                    }
                                }
                            }
                        }
                    }

                    if !model.fileResults.isEmpty {
                        section(L("search.section.files")) {
                            LazyVGrid(columns: gridColumns, spacing: Metrics.rowSpacing) {
                                ForEach(model.fileResults) { file in
                                    FileResultCell(result: file,
                                                   isSelected: model.selectedItemID == FileResult.selectionID(file.id),
                                                   iconScale: scale) { onOpenFile(file) }
                                        .id(FileResult.selectionID(file.id))
                                }
                            }
                        }
                    }

                    webSearchRow
                        .id(LaunchpadModel.webSearchSelectionID)
                }
                .padding(.horizontal, Metrics.gridHorizontalMargin)
                .padding(.top, Metrics.searchAreaHeight)
                .padding(.bottom, Metrics.pageDotsAreaHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay {
                if isEmpty && !model.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Apps empty but the web row is always offered below — only show the
                    // big "nothing found" mark when there are truly no app/file hits.
                    EmptyResultsView(query: model.query)
                        .allowsHitTesting(false)
                        .padding(.bottom, 120)
                }
            }
            .onChange(of: model.selectedItemID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: Metrics.searchSectionFontSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            content()
        }
    }

    /// A full-width glass row that runs a web search for the current query.
    private var webSearchRow: some View {
        let selected = model.selectedItemID == LaunchpadModel.webSearchSelectionID
        return Button(action: onSearchWeb) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                Text(L("search.web", model.query))
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "return")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(selected ? Metrics.selectedHighlightOpacity : 0))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("search.web", model.query))
    }
}

/// A Spotlight file hit: icon over its name, with a dim parent-folder subtitle. Tap
/// (or Return when selected) opens the file with its default app.
struct FileResultCell: View {
    let result: FileResult
    var isSelected: Bool
    var iconScale: CGFloat
    var onOpen: () -> Void

    @State private var icon: NSImage?
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var highlightOpacity: Double {
        if isSelected { return Metrics.selectedHighlightOpacity }
        if hovering { return Metrics.hoverHighlightOpacity }
        return 0
    }
    private var scale: CGFloat { (isSelected || hovering) ? Metrics.hoverScale : 1 }

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 6) {
                iconView
                    .frame(width: Metrics.iconSize * iconScale, height: Metrics.iconSize * iconScale)
                Text(result.name)
                    .font(.system(size: Metrics.labelFontSize))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    .frame(maxWidth: Metrics.labelMaxWidth)
                Text(parentLabel)
                    .font(.system(size: Metrics.fileSubtitleFontSize))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: Metrics.labelMaxWidth)
            }
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: Metrics.cellCornerRadius, style: .continuous)
                    .fill(.white.opacity(highlightOpacity))
            }
            .scaleEffect(scale)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : Metrics.pop, value: scale)
        .accessibilityLabel(L("search.file.a11y", result.name))
        .accessibilityHint(L("search.file.hint"))
        .task(id: result.id) { icon = await IconLoader.shared.icon(forPath: result.path) }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon {
            Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.08))
        }
    }

    /// Parent folder, abbreviated with `~` for the home directory.
    private var parentLabel: String {
        (result.url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
    }
}
