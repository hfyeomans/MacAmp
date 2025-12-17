import Foundation
import Observation

/// Observable state for PLAYLIST window sizing using segment-based resize
/// Persists to UserDefaults and provides reactive updates
///
/// Layout Constants:
/// - Segment size: 25px width × 29px height
/// - Base window: 275×116px (minimum)
/// - Default window: 275×232px ([0,4] segments)
/// - Top bar: 20px height
/// - Bottom bar: 38px height
/// - Left border: 12px, Right border: 20px
/// - Track row height: 13px
/// - Bottom bar sections: LEFT 125px + CENTER (dynamic) + RIGHT 150px = 275px minimum
@MainActor
@Observable
final class PlaylistWindowSizeState {
    // MARK: - Constants

    /// Segment dimensions (Winamp resize grid)
    static let segmentWidth: CGFloat = 25
    static let segmentHeight: CGFloat = 29

    /// Base window dimensions (minimum size)
    static let baseWidth: CGFloat = 275
    static let baseHeight: CGFloat = 116

    /// Chrome dimensions
    static let topBarHeight: CGFloat = 20
    static let bottomBarHeight: CGFloat = 38
    static let leftBorderWidth: CGFloat = 12
    static let rightBorderWidth: CGFloat = 20

    /// Bottom bar section widths
    static let bottomLeftWidth: CGFloat = 125
    static let bottomRightWidth: CGFloat = 150

    /// Track rendering
    static let trackRowHeight: CGFloat = 13

    /// Content area padding (scroll track is inside right border)
    static let contentAreaTopPadding: CGFloat = 0

    // MARK: - Size State

    /// Current size in segments (persisted)
    var size: Size2D = .playlistDefault {
        didSet {
            saveSize()
        }
    }

    // MARK: - Computed Properties: Pixel Dimensions

    /// Pixel dimensions calculated from segments
    var pixelSize: CGSize {
        size.toPlaylistPixels()
    }

    /// Window width in pixels
    var windowWidth: CGFloat {
        pixelSize.width
    }

    /// Window height in pixels
    var windowHeight: CGFloat {
        pixelSize.height
    }

    // MARK: - Computed Properties: Bottom Bar

    /// Width of center tiling section in bottom bar (can be 0)
    /// Formula: windowWidth - bottomLeftWidth - bottomRightWidth
    var centerWidth: CGFloat {
        max(0, windowWidth - Self.bottomLeftWidth - Self.bottomRightWidth)
    }

    /// Number of 25px center tiles to render in bottom bar
    var centerTileCount: Int {
        Int(centerWidth / Self.segmentWidth)
    }

    // MARK: - Computed Properties: Top Bar (Titlebar)

    /// Number of 25px tiles to fill the top bar background (from left corner to window edge)
    /// Tiles render UNDER the title bar, which overlays them in the center
    var topBarTileCount: Int {
        // Tiles fill from left corner (25px) to window edge
        Int(ceil((windowWidth - 25) / Self.segmentWidth))
    }

    /// Whether to show titlebar spacers (Webamp parity: even width segments = show spacers)
    var showTitlebarSpacers: Bool {
        size.width % 2 == 0
    }

    // MARK: - Computed Properties: Side Borders

    /// Height of the content area (between top bar and bottom bar)
    var sideHeight: CGFloat {
        windowHeight - Self.topBarHeight - Self.bottomBarHeight
    }

    /// Number of 29px vertical border tiles needed
    var verticalBorderTileCount: Int {
        Int(ceil(sideHeight / Self.segmentHeight))
    }

    // MARK: - Computed Properties: Content Area

    /// Content area size (where track list renders)
    /// Width: window - left border - right border
    /// Height: window - top bar - bottom bar
    var contentSize: CGSize {
        CGSize(
            width: windowWidth - Self.leftBorderWidth - Self.rightBorderWidth,
            height: windowHeight - Self.topBarHeight - Self.bottomBarHeight
        )
    }

    /// Content area width (243px at minimum size)
    var contentWidth: CGFloat {
        contentSize.width
    }

    /// Content area height (174px at [0,4] default size)
    var contentHeight: CGFloat {
        contentSize.height
    }

    // MARK: - Computed Properties: Track Metrics

    /// Number of fully visible tracks that fit in content area
    /// Formula: floor(contentHeight / trackRowHeight)
    var visibleTrackCount: Int {
        Int(floor(contentHeight / Self.trackRowHeight))
    }

    /// Total scroll track height for scroll slider calculations
    /// This is the vertical range the scroll thumb can move
    var scrollTrackHeight: CGFloat {
        // Scroll track is inside the content area, minus some padding for thumb ends
        max(0, contentHeight - 20)  // 20px reserved for thumb positioning
    }

    // MARK: - Initialization

    init() {
        loadSize()
    }

    // MARK: - Persistence

    private static let sizeKey = "playlistWindowSize"

    private func saveSize() {
        let data = ["width": size.width, "height": size.height]
        UserDefaults.standard.set(data, forKey: Self.sizeKey)
    }

    private func loadSize() {
        guard let data = UserDefaults.standard.dictionary(forKey: Self.sizeKey),
              let width = data["width"] as? Int,
              let height = data["height"] as? Int else {
            // Default to standard playlist size if no saved value
            size = .playlistDefault
            return
        }

        size = Size2D(width: width, height: height).clamped(min: .playlistMinimum)
    }

    // MARK: - Convenience Methods

    /// Reset to default size (275×232)
    func resetToDefault() {
        size = .playlistDefault
    }

    /// Set to minimum size (275×116)
    func setToMinimum() {
        size = .playlistMinimum
    }

    /// Set to 2x width (550×232)
    func setTo2xWidth() {
        size = .playlist2xWidth
    }

    /// Resize by delta segments (used by drag gesture)
    func resize(byWidthSegments deltaW: Int, heightSegments deltaH: Int) {
        let newSize = Size2D(
            width: size.width + deltaW,
            height: size.height + deltaH
        ).clamped(min: .playlistMinimum)

        size = newSize
    }

    /// Set size directly from segment values (used by resize handle)
    func setSize(widthSegments: Int, heightSegments: Int) {
        size = Size2D(
            width: widthSegments,
            height: heightSegments
        ).clamped(min: .playlistMinimum)
    }
}
