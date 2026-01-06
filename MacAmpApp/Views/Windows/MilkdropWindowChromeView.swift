import SwiftUI

/// Milkdrop Window - Pixel-perfect GEN.bmp chrome using dynamic layout
/// Matches Main/EQ/Playlist/Video pattern: ZStack + SimpleSpriteImage + .at()
///
/// Titlebar has 7 sections with gold fillers that expand symmetrically:
/// LEFT_CAP(25) + LEFT_GOLD(n×25) + LEFT_END(25) + CENTER(3×25=75) + RIGHT_END(25) + RIGHT_GOLD(n×25) + RIGHT_CAP(25)
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
                .frame(width: pixelSize.width, height: pixelSize.height)

            // Dynamic titlebar
            buildDynamicTitlebar()

            // Dynamic side borders
            buildDynamicBorders()

            // Content area (WKWebView for Butterchurn)
            content
                .frame(width: contentSize.width, height: contentSize.height)
                .position(x: pixelSize.width / 2, y: 20 + contentSize.height / 2)

            // Dynamic bottom bar
            buildDynamicBottomBar()
        }
        .frame(width: pixelSize.width, height: pixelSize.height, alignment: .topLeading)
        .fixedSize()
        .background(Color.black)
    }

    // MARK: - Dynamic Titlebar (7 sections)

    @ViewBuilder
    private func buildDynamicTitlebar() -> some View {
        let suffix = isWindowActive ? "_SELECTED" : ""
        let goldTiles = sizeState.goldFillerTilesPerSide
        let centerStart = sizeState.centerSectionStartX

        WinampTitlebarDragHandle(windowKind: .milkdrop, size: CGSize(width: pixelSize.width, height: 20)) {
            ZStack(alignment: .topLeading) {
                // Section 1: Left cap (25px)
                SimpleSpriteImage("GEN_TOP_LEFT\(suffix)", width: 25, height: 20)
                    .position(x: 12.5, y: 10)

                // Section 2: Left gold bar tiles (dynamic count)
                ForEach(0..<goldTiles, id: \.self) { i in
                    SimpleSpriteImage("GEN_TOP_LEFT_RIGHT_FILL\(suffix)", width: 25, height: 20)
                        .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
                }

                // Section 3: Left end (25px)
                SimpleSpriteImage("GEN_TOP_LEFT_END\(suffix)", width: 25, height: 20)
                    .position(x: centerStart - 12.5, y: 10)

                // Section 4: Center grey tiles (fixed 3 tiles = 75px)
                ForEach(0..<sizeState.centerGreyTileCount, id: \.self) { i in
                    SimpleSpriteImage("GEN_TOP_CENTER_FILL\(suffix)", width: 25, height: 20)
                        .position(x: centerStart + 12.5 + CGFloat(i) * 25, y: 10)
                }

                // Section 5: Right end (25px)
                SimpleSpriteImage("GEN_TOP_RIGHT_END\(suffix)", width: 25, height: 20)
                    .position(x: centerStart + 75 + 12.5, y: 10)

                // Section 6: Right gold bar tiles (symmetric with left)
                ForEach(0..<goldTiles, id: \.self) { i in
                    SimpleSpriteImage("GEN_TOP_LEFT_RIGHT_FILL\(suffix)", width: 25, height: 20)
                        .position(x: centerStart + 75 + 25 + 12.5 + CGFloat(i) * 25, y: 10)
                }

                // Section 7: Right cap with close button (25px)
                SimpleSpriteImage("GEN_TOP_RIGHT\(suffix)", width: 25, height: 20)
                    .position(x: pixelSize.width - 12.5, y: 10)

                // MILKDROP HD letters - centered in 75px center section
                milkdropLetters
                    .position(x: sizeState.milkdropLettersCenterX, y: 8)
            }
        }
        .position(x: pixelSize.width / 2, y: 10)
    }

    // MARK: - Dynamic Borders

    @ViewBuilder
    private func buildDynamicBorders() -> some View {
        let tileCount = sizeState.verticalBorderTileCount

        ForEach(0..<tileCount, id: \.self) { i in
            // Left border (11px wide)
            SimpleSpriteImage("GEN_MIDDLE_LEFT", width: 11, height: 29)
                .position(x: 5.5, y: 20 + 14.5 + CGFloat(i) * 29)

            // Right border (8px wide)
            SimpleSpriteImage("GEN_MIDDLE_RIGHT", width: 8, height: 29)
                .position(x: pixelSize.width - 4, y: 20 + 14.5 + CGFloat(i) * 29)
        }
    }

    // MARK: - Dynamic Bottom Bar

    @ViewBuilder
    private func buildDynamicBottomBar() -> some View {
        let bottomBarY = pixelSize.height - 7  // 14px bar, center at 7

        // LEFT section (125px fixed)
        SimpleSpriteImage("GEN_BOTTOM_LEFT", width: 125, height: 14)
            .position(x: 62.5, y: bottomBarY)

        // CENTER section (dynamic tiles) - TWO-PIECE sprites (13px + 1px = 14px)
        let centerCount = sizeState.centerTileCount
        ForEach(0..<centerCount, id: \.self) { i in
            VStack(spacing: 0) {
                SimpleSpriteImage("GEN_BOTTOM_FILL_TOP", width: 25, height: 13)
                SimpleSpriteImage("GEN_BOTTOM_FILL_BOTTOM", width: 25, height: 1)
            }
            .position(x: 125 + 12.5 + CGFloat(i) * 25, y: bottomBarY)
        }

        // RIGHT section (125px fixed) - contains resize corner
        SimpleSpriteImage("GEN_BOTTOM_RIGHT", width: 125, height: 14)
            .position(x: pixelSize.width - 62.5, y: bottomBarY)
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
