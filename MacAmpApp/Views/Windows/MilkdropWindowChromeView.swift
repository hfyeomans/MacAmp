import SwiftUI

/// Layout constants for Milkdrop Window (general purpose window using GEN.bmp)
/// Default size matches video window: 275×232
private enum MilkdropWindowLayout {
    static let windowSize = CGSize(width: 275, height: 232)
    static let titlebarHeight: CGFloat = 20  // GEN titlebar sprite height
    static let bottomBarHeight: CGFloat = 14  // GEN bottom bar sprite height
    static let leftBorderWidth: CGFloat = 11  // GEN_MIDDLE_LEFT width
    static let rightBorderWidth: CGFloat = 8   // GEN_MIDDLE_RIGHT width

    static let contentX: CGFloat = leftBorderWidth  // 11
    static let contentY: CGFloat = titlebarHeight   // 20
    static let contentWidth: CGFloat = windowSize.width - leftBorderWidth - rightBorderWidth  // 256
    static let contentHeight: CGFloat = windowSize.height - titlebarHeight - bottomBarHeight  // 198
}

/// Milkdrop Window - Pixel-perfect GEN.bmp chrome using absolute positioning
/// Matches Main/EQ/Playlist/Video pattern: ZStack + SimpleSpriteImage + .at()
struct MilkdropWindowChromeView<Content: View>: View {
    /// Size state for dynamic layout (segment-based resizing)
    let sizeState: MilkdropWindowSizeState
    @ViewBuilder let content: Content

    @Environment(WindowFocusState.self) private var windowFocusState
    private var isWindowActive: Bool { windowFocusState.isMilkdropKey }

    /// Pixel dimensions from sizeState
    private var pixelSize: CGSize { sizeState.pixelSize }

    /// Content area dimensions for WKWebView
    private var contentSize: CGSize { sizeState.contentSize }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            Color.black
                .frame(width: MilkdropWindowLayout.windowSize.width, height: MilkdropWindowLayout.windowSize.height)

            // Titlebar - full width drag handle wrapping all sprites
            WinampTitlebarDragHandle(windowKind: .milkdrop, size: CGSize(width: MilkdropWindowLayout.windowSize.width, height: MilkdropWindowLayout.titlebarHeight)) {
                ZStack(alignment: .topLeading) {
                    let suffix = isWindowActive ? "_SELECTED" : ""

                    // Section 1: Left cap (25px) - column 0
                    SimpleSpriteImage("GEN_TOP_LEFT\(suffix)", width: 25, height: MilkdropWindowLayout.titlebarHeight)
                        .position(x: 12.5, y: 10)

                    // Section 2: Left gold bar tiles - columns 1-2 (2 tiles)
                    ForEach(0..<2, id: \.self) { i in
                        SimpleSpriteImage("GEN_TOP_LEFT_RIGHT_FILL\(suffix)", width: 25, height: MilkdropWindowLayout.titlebarHeight)
                            .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
                    }

                    // Section 3: Left fixed (25px) - column 3
                    SimpleSpriteImage("GEN_TOP_LEFT_END\(suffix)", width: 25, height: MilkdropWindowLayout.titlebarHeight)
                        .position(x: 87.5, y: 10)

                    // Section 4: Center grey tiles - columns 4-6 (3 tiles = 75px)
                    // Symmetric layout: only odd tile counts allow equal gold fills
                    // Center spans x:100-175, midpoint at x:137.5 = window center
                    ForEach(0..<3, id: \.self) { i in
                        SimpleSpriteImage("GEN_TOP_CENTER_FILL\(suffix)", width: 25, height: 20)
                            .position(x: 100 + 12.5 + CGFloat(i) * 25, y: 10)
                    }

                    // Section 5: Right fixed (25px) - column 7
                    SimpleSpriteImage("GEN_TOP_RIGHT_END\(suffix)", width: 25, height: MilkdropWindowLayout.titlebarHeight)
                        .position(x: 187.5, y: 10)

                    // Section 6: Right gold bar tiles - columns 8-9 (2 tiles = 50px, symmetric with left)
                    ForEach(0..<2, id: \.self) { i in
                        SimpleSpriteImage("GEN_TOP_LEFT_RIGHT_FILL\(suffix)", width: 25, height: MilkdropWindowLayout.titlebarHeight)
                            .position(x: 200 + 12.5 + CGFloat(i) * 25, y: 10)
                    }

                    // Section 7: Right cap with close button (25px) - column 10
                    SimpleSpriteImage("GEN_TOP_RIGHT\(suffix)", width: 25, height: MilkdropWindowLayout.titlebarHeight)
                        .position(x: 262.5, y: 10)

                    // MILKDROP HD letters - centered in 75px grey section (total width: 66px)
                    // Each letter uses two-piece sprites (TOP + BOTTOM) stacked vertically
                    // Center section spans x: 100-175, center at x: 137.5
                    // Gap: (75px - 66px) / 2 = 4.5px each side
                    milkdropLetters
                        .position(x: 137.5, y: 8)
                }
            }
            .position(x: 137.5, y: 10)

            // Side borders - tiled vertically (29px per tile)
            let sideHeight: CGFloat = 198  // 232 - 20 - 14
            let sideTileCount = Int(ceil(sideHeight / 29))  // 7 tiles
            ForEach(0..<sideTileCount, id: \.self) { i in
                // Left border (11px wide)
                SimpleSpriteImage("GEN_MIDDLE_LEFT", width: 11, height: 29)
                    .position(x: 5.5, y: 20 + 14.5 + CGFloat(i) * 29)

                // Right border (8px wide)
                SimpleSpriteImage("GEN_MIDDLE_RIGHT", width: 8, height: 29)
                    .position(x: 271, y: 20 + 14.5 + CGFloat(i) * 29)  // 275 - 4 = 271
            }

            // Content area
            content
                .frame(width: MilkdropWindowLayout.contentWidth, height: MilkdropWindowLayout.contentHeight)
                .position(x: MilkdropWindowLayout.windowSize.width / 2, y: 20 + sideHeight / 2)

            // Bottom bar - 3 pieces (left corner + tiled center + right corner with resizer)
            SimpleSpriteImage("GEN_BOTTOM_LEFT", width: 125, height: 14)
                .position(x: 62.5, y: 225)

            // Center tiles - TWO-PIECE sprite (13px + 1px, excludes cyan)
            ForEach(0..<1, id: \.self) { i in
                VStack(spacing: 0) {
                    SimpleSpriteImage("GEN_BOTTOM_FILL_TOP", width: 25, height: 13)
                    SimpleSpriteImage("GEN_BOTTOM_FILL_BOTTOM", width: 25, height: 1)
                }
                .position(x: 125 + 12.5 + CGFloat(i) * 25, y: 225)
            }

            // Right corner with resize button (125px)
            SimpleSpriteImage("GEN_BOTTOM_RIGHT", width: 125, height: 14)
                .position(x: 212.5, y: 225)

            // Close button is baked into GEN_TOP_RIGHT; no additional sprite needed here
        }
        .frame(width: MilkdropWindowLayout.windowSize.width, height: MilkdropWindowLayout.windowSize.height, alignment: .topLeading)
        .fixedSize()
        .background(Color.black)
    }

    /// MILKDROP HD letters HStack - renders text as two-piece sprites with space
    /// Letter widths: M=8, I=4, L=5, K=7, D=6, R=7, O=6, P=6, space=5, H=6, gap=1, D=6
    /// Total: 49 (MILKDROP) + 5 (space) + 6 (H) + 1 (gap) + 6 (D) = 67px
    /// Gap: (75px center - 67px text) / 2 = 4px each side
    private var milkdropLetters: some View {
        HStack(spacing: 0) {
            // MILKDROP
            makeLetter("M", width: 8)
            makeLetter("I", width: 4)
            makeLetter("L", width: 5)
            makeLetter("K", width: 7)
            makeLetter("D", width: 6)
            makeLetter("R", width: 7)
            makeLetter("O", width: 6)
            makeLetter("P", width: 6)
            // Space (5px gap between words)
            Color.clear.frame(width: 5, height: 8)
            // HD (1px spacer between H and D to prevent touching)
            makeLetter("H", width: 6)
            Color.clear.frame(width: 1, height: 8)
            makeLetter("D", width: 6)
        }
    }

    /// Renders a single GEN letter as two vertically-stacked sprites (TOP + BOTTOM)
    /// Selected state: TOP height=6, BOTTOM height=2
    /// Normal state: TOP height=6, BOTTOM height=1
    @ViewBuilder
    private func makeLetter(_ letter: String, width: CGFloat) -> some View {
        let prefix = isWindowActive ? "GEN_TEXT_SELECTED_" : "GEN_TEXT_"
        let bottomHeight: CGFloat = isWindowActive ? 2 : 1

        VStack(spacing: 0) {
            SimpleSpriteImage("\(prefix)\(letter)_TOP", width: width, height: 6)
            SimpleSpriteImage("\(prefix)\(letter)_BOTTOM", width: width, height: bottomHeight)
        }
    }
}
