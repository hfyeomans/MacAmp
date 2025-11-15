import Foundation
import Observation

/// Observable state for VIDEO window sizing using segment-based resize
/// Persists to UserDefaults and provides reactive updates
@MainActor
@Observable
final class VideoWindowSizeState {
    // MARK: - Size State

    /// Current size in segments
    var size: Size2D = .videoDefault {
        didSet {
            // Persist to UserDefaults whenever size changes
            saveSize()
        }
    }

    // MARK: - Computed Properties

    /// Pixel dimensions calculated from segments
    var pixelSize: CGSize {
        size.toVideoPixels()
    }

    /// Width of center section in bottom bar (can be 0)
    var centerWidth: CGFloat {
        max(0, pixelSize.width - 250)  // 275 - 125 left - 125 right = 25, but uses 250 for margin
    }

    /// Number of center tiles to render in bottom bar
    var centerTileCount: Int {
        Int(centerWidth / 25)
    }

    /// Number of stretchy title tiles to render on EACH side
    /// At 275px: need 3 tiles per side to fill 25→center and center→cap
    var stretchyTilesPerSide: Int {
        // Each side needs to fill: cap(25px) to center_edge or center_edge to cap
        // At 275px: left side = 25 to 87.5 = 62.5px → need 3 tiles (overlap OK)
        // Calculate: (window_width - caps - center) / 2 / tile_width
        // (275 - 25 - 25 - 100) / 2 / 25 = 125 / 2 / 25 = 2.5 → round UP to 3
        let availableWidth = pixelSize.width - 50 - 100  // minus caps and center
        let perSide = availableWidth / 2  // divide between left and right
        return max(0, Int(ceil(perSide / 25)))  // round UP to ensure coverage
    }

    /// Distribution of stretchy tiles (same count on both sides for symmetry)
    var titlebarTileDistribution: (left: Int, right: Int) {
        let count = stretchyTilesPerSide
        return (count, count)  // Equal on both sides
    }

    /// Number of vertical border tiles needed based on height
    var verticalBorderTileCount: Int {
        let contentHeight = pixelSize.height - 20 - 38  // Minus titlebar and bottom bar
        return Int(ceil(contentHeight / 29))
    }

    /// Content area dimensions (for AVPlayerView)
    var contentSize: CGSize {
        CGSize(
            width: pixelSize.width - 11 - 8,   // Minus left/right borders
            height: pixelSize.height - 20 - 38  // Minus titlebar/bottom bar
        )
    }

    // MARK: - Initialization

    init() {
        // Load persisted size from UserDefaults
        loadSize()
    }

    // MARK: - Persistence

    private static let sizeKey = "videoWindowSize"

    private func saveSize() {
        let data = ["width": size.width, "height": size.height]
        UserDefaults.standard.set(data, forKey: Self.sizeKey)
    }

    private func loadSize() {
        guard let data = UserDefaults.standard.dictionary(forKey: Self.sizeKey),
              let width = data["width"] as? Int,
              let height = data["height"] as? Int else {
            // Default to current standard size if no saved value
            size = .videoDefault
            return
        }

        size = Size2D(width: width, height: height).clamped(min: .videoMinimum)
    }

    // MARK: - Convenience Methods

    /// Reset to default size
    func resetToDefault() {
        size = .videoDefault
    }

    /// Set to minimum size
    func setToMinimum() {
        size = .videoMinimum
    }

    /// Set to 2x size
    func setTo2x() {
        size = .video2x
    }

    /// Resize by delta segments (used by drag gesture)
    func resize(byWidthSegments deltaW: Int, heightSegments deltaH: Int) {
        let newSize = Size2D(
            width: size.width + deltaW,
            height: size.height + deltaH
        ).clamped(min: .videoMinimum)

        size = newSize
    }
}
