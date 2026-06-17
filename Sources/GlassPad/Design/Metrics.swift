import SwiftUI
import AppKit

/// All design constants live here — no magic numbers in views (CLAUDE.md).
enum Metrics {
    // MARK: - Accessibility
    /// `Reduce Motion` (System Settings › Accessibility › Display). Read on the
    /// main actor at imperative animation sites (model/controller); SwiftUI views
    /// should prefer `@Environment(\.accessibilityReduceMotion)`. When true, pass
    /// `nil` to `withAnimation`/`.animation` so state changes apply instantly.
    @MainActor static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

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
    /// `scale` is the density multiplier: <1 packs more columns, >1 fewer.
    static func columnCount(forWidth width: CGFloat, scale: CGFloat = 1) -> Int {
        let usable = width - gridHorizontalMargin * 2
        let perColumn = (cellWidth + columnSpacing) * scale
        let n = Int((usable / perColumn).rounded(.down))
        return max(4, min(9, n))
    }

    /// Rows that fit in the grid's available height. The caller (LaunchpadView)
    /// already insets the grid by the search + page-dot chrome via padding, so the
    /// passed `height` IS the usable grid area — do NOT subtract the chrome again
    /// (that double-subtraction left ~2 rows of empty space and spilled apps onto an
    /// extra page).
    static func rowCount(forHeight height: CGFloat, scale: CGFloat = 1) -> Int {
        let perRow = (cellHeight + rowSpacing) * scale
        let n = Int((height / perRow).rounded(.down))
        return max(2, min(8, n))
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

    // MARK: - Folders
    static let folderTileCornerRadius: CGFloat = 22
    static let folderTilePadding: CGFloat = 12
    static let folderOverlayCornerRadius: CGFloat = 36
    static let folderOverlayMaxWidth: CGFloat = 640
    static let folderOverlayDim: Double = 0.32
    static let glassContainerSpacing: CGFloat = 28

    // MARK: - Motion
    static let pop = Animation.spring(response: 0.3, dampingFraction: 0.8)
    /// Page-flip spring for the custom pager's `.offset`. Tuned for a crisp,
    /// native-Launchpad flip over a full page width: fast enough to feel immediate,
    /// damped just under 1 so it settles cleanly with no visible overshoot/bounce
    /// (a between-pages wobble would read as resting off-boundary).
    static let pageSpring = Animation.spring(response: 0.32, dampingFraction: 0.86)
    /// Fraction of a page width a live swipe must cover to commit (else velocity).
    static let pageCommitFraction: CGFloat = 0.25
    /// Swipe speed (points/sec) that commits a page regardless of displacement — a
    /// light two-finger flick turns the page without dragging a quarter-width.
    static let pageFlickVelocity: CGFloat = 380
    /// How much the stack moves per point of over-pull at the first/last page.
    static let pageRubberBand: CGFloat = 0.32
    static let morph = Animation.bouncy(duration: 0.42)
    static let overlayFadeIn: TimeInterval = 0.18
    static let overlayFadeOut: TimeInterval = 0.14
    static let appearScaleFrom: CGFloat = 0.96
    static let launchPopScale: CGFloat = 1.22
    static let launchDismissDelay: TimeInterval = 0.13
}
