import Foundation
import Observation

/// Observable state for MILKDROP window sizing using segment-based resize
/// Persists to UserDefaults and provides reactive updates
///
/// MILKDROP titlebar has 7 sections with gold fillers that expand symmetrically:
/// LEFT_CAP(25) + LEFT_GOLD(n×25) + LEFT_END(25) + CENTER(3×25=75) + RIGHT_END(25) + RIGHT_GOLD(n×25) + RIGHT_CAP(25)
///
/// Chrome dimensions:
/// - Titlebar: 20px
/// - Bottom bar: 14px (much smaller than VIDEO's 38px)
/// - Left border: 11px
/// - Right border: 8px
@MainActor
@Observable
final class MilkdropWindowSizeState {
    // MARK: - Size State

    /// Current size in segments
    var size: Size2D = .milkdropDefault {
        didSet {
            saveSize()
        }
    }

    // MARK: - Computed Properties

    /// Pixel dimensions calculated from segments
    var pixelSize: CGSize {
        size.toMilkdropPixels()
    }

    /// Width of center section in bottom bar: window - LEFT(125) - RIGHT(125)
    var centerWidth: CGFloat {
        max(0, pixelSize.width - 250)
    }

    /// Number of 25px center tiles in bottom bar
    var centerTileCount: Int {
        Int(centerWidth / 25)
    }

    /// Content height: window - titlebar(20) - bottomBar(14) = window - 34
    var contentHeight: CGFloat {
        pixelSize.height - 34
    }

    /// Content width: window - leftBorder(11) - rightBorder(8) = window - 19
    var contentWidth: CGFloat {
        pixelSize.width - 19
    }

    /// Number of 29px vertical border tiles needed based on content height
    var verticalBorderTileCount: Int {
        Int(ceil(contentHeight / 29))
    }

    /// Content size for WKWebView/Butterchurn
    var contentSize: CGSize {
        CGSize(width: contentWidth, height: contentHeight)
    }

    // MARK: - MILKDROP Titlebar Layout
    // Structure: LEFT_CAP(25) + LEFT_GOLD(n×25) + LEFT_END(25) + CENTER(3×25) + RIGHT_END(25) + RIGHT_GOLD(n×25) + RIGHT_CAP(25)
    // Fixed: LEFT_CAP + LEFT_END + RIGHT_END + RIGHT_CAP = 100px
    // Center: 3 grey tiles = 75px (fixed)
    // Variable: LEFT_GOLD + RIGHT_GOLD expand symmetrically

    /// Gold filler tiles per side (symmetric)
    /// At 275px: (275 - 100 - 75) / 2 / 25 = 2 tiles per side (matches current fixed layout)
    /// Uses ceil() to ensure tiles fully cover the space at all widths (Pattern 9)
    var goldFillerTilesPerSide: Int {
        let goldSpace = pixelSize.width - 100 - 75  // Fixed caps/ends (100) + center grey (75)
        let perSide = goldSpace / 2.0
        return max(0, Int(ceil(perSide / 25.0)))
    }

    /// Center grey tiles (fixed at 3 - expand gold fillers instead)
    var centerGreyTileCount: Int { 3 }

    /// X position for center section start (after LEFT_CAP + LEFT_GOLD + LEFT_END)
    var centerSectionStartX: CGFloat {
        25 + CGFloat(goldFillerTilesPerSide) * 25 + 25
    }

    /// X position for MILKDROP HD letters (centered in 75px center section)
    var milkdropLettersCenterX: CGFloat {
        centerSectionStartX + 37.5  // Center of 75px center section
    }

    // MARK: - Initialization

    init() {
        loadSize()
    }

    // MARK: - Persistence

    private static let sizeKey = "milkdropWindowSize"

    private func saveSize() {
        let data = ["width": size.width, "height": size.height]
        UserDefaults.standard.set(data, forKey: Self.sizeKey)
    }

    func loadSize() {
        guard let data = UserDefaults.standard.dictionary(forKey: Self.sizeKey),
              let width = data["width"] as? Int,
              let height = data["height"] as? Int else {
            size = .milkdropDefault
            return
        }

        size = Size2D(width: width, height: height).clamped(min: .milkdropMinimum)
    }

    // MARK: - Convenience Methods

    /// Reset to default size
    func resetToDefault() {
        size = .milkdropDefault
    }

    /// Set to minimum size
    func setToMinimum() {
        size = .milkdropMinimum
    }

    /// Resize by delta segments (used by drag gesture)
    func resize(byWidthSegments deltaW: Int, heightSegments deltaH: Int) {
        let newSize = Size2D(
            width: size.width + deltaW,
            height: size.height + deltaH
        ).clamped(min: .milkdropMinimum)

        size = newSize
    }
}
