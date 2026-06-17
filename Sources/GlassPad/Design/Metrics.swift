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

    /// The grid's top inset — the single source used by BOTH `LaunchpadView.grid`'s
    /// top padding AND the model's reorder slot math (`slotIndex`/`slotCenterGlobal`),
    /// so the gridSpace→page-local row mapping can never silently drift from the
    /// visual layout. Equals the search-chrome height by definition.
    static var gridTopInset: CGFloat { searchAreaHeight }

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

    // MARK: - Drag-to-reorder (live reflow)
    /// Spring the grid cells use to glide to a new slot when the live drag changes
    /// the insertion index. Keyed on `model.reorderRevision` (NOT currentPage), so it
    /// can never animate the pager offset — that stays on `pageSpring` on the outer
    /// HStack. Snappy + lightly damped so cells part to make room cleanly.
    static let reorderSpring = Animation.spring(response: 0.3, dampingFraction: 0.82)
    /// How much the lifted (floating) icon grows while being dragged.
    static let dragLiftScale: CGFloat = 1.15
    /// Distance (points) from the left/right screen edge that arms a page flip while
    /// dragging an icon, so you can carry it across pages like real Launchpad.
    static let edgeFlipBand: CGFloat = 64
    /// How long the cursor must dwell in the edge band before the page flips.
    static let edgeFlipDwell: TimeInterval = 0.55
    /// Cursor-to-cell-center distance that arms a folder merge instead of a reflow
    /// (small, so only a deliberate hover over a tile's center makes a folder).
    static let folderMergeRadius: CGFloat = 40
    /// Highlight strength on the tile the drag will merge into.
    static let folderTargetHighlightOpacity: Double = 0.26

    // MARK: - File search (Spotlight)
    /// Max file hits shown in the Files section of search results.
    static let fileResultLimit: Int = 24
    /// Debounce (ms) before a keystroke kicks off a Spotlight query.
    static let spotlightDebounceMS: Int = 180
    /// Section header + file-path-subtitle type sizes in search results.
    static let searchSectionFontSize: CGFloat = 15
    static let fileSubtitleFontSize: CGFloat = 11
    static let searchSectionSpacing: CGFloat = 30
}
