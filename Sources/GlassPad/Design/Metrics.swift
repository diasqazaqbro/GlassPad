import SwiftUI

/// All design constants live here — no magic numbers in views (CLAUDE.md).
enum Metrics {
    // MARK: - Grid
    static let iconSize: CGFloat = 100
    static let cellWidth: CGFloat = 124
    static let cellHeight: CGFloat = 138
    static let columnSpacing: CGFloat = 14
    static let rowSpacing: CGFloat = 22
    static let labelFontSize: CGFloat = 13
    static let labelMaxWidth: CGFloat = 116
    static let gridHorizontalMargin: CGFloat = 80
    static let gridBottomInset: CGFloat = 72

    static let preferredColumns = 7
    static let preferredRows = 5

    /// Columns derived from available width (HIG: don't hardcode for one display).
    static func columnCount(forWidth width: CGFloat) -> Int {
        let usable = width - gridHorizontalMargin * 2
        let perColumn = cellWidth + columnSpacing
        let n = Int((usable / perColumn).rounded(.down))
        return max(4, min(9, n))
    }

    /// Rows derived from available height (minus the search and page-dot chrome).
    static func rowCount(forHeight height: CGFloat) -> Int {
        let usable = height - searchAreaHeight - pageDotsAreaHeight
        let perRow = cellHeight + rowSpacing
        let n = Int((usable / perRow).rounded(.down))
        return max(2, min(7, n))
    }

    static var searchAreaHeight: CGFloat { searchTopPadding + searchPillHeight + searchBottomPadding }
    static let pageDotsAreaHeight: CGFloat = 64

    // MARK: - Search pill
    static let searchPillWidth: CGFloat = 360
    static let searchPillHeight: CGFloat = 44
    static let searchTopPadding: CGFloat = 36
    static let searchBottomPadding: CGFloat = 28
    static let searchFontSize: CGFloat = 16

    // MARK: - Backdrop
    static let backdropDim: Double = 0.22

    // MARK: - Cell appearance
    static let cellCornerRadius: CGFloat = 22
    static let hoverScale: CGFloat = 1.06
    static let hoverHighlightOpacity: Double = 0.14
    static let selectedHighlightOpacity: Double = 0.20

    // MARK: - Motion
    static let pop = Animation.spring(response: 0.3, dampingFraction: 0.8)
    static let overlayFadeIn: TimeInterval = 0.18
    static let overlayFadeOut: TimeInterval = 0.14
    static let appearScaleFrom: CGFloat = 0.96
}
