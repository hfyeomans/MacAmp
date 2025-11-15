import SwiftUI

/// Layout constants for Video Window (matches Playlist dimensions: 275×232)
private enum VideoWindowLayout {
    static let windowSize = CGSize(width: 275, height: 232)
    static let titlebarHeight: CGFloat = 20  // Titlebar sprite height
    static let bottomBarHeight: CGFloat = 38  // Bottom bar sprite height
    static let leftBorderWidth: CGFloat = 11
    static let rightBorderWidth: CGFloat = 8

    static let contentX: CGFloat = leftBorderWidth  // 11
    static let contentY: CGFloat = titlebarHeight   // 20
    static let contentWidth: CGFloat = windowSize.width - leftBorderWidth - rightBorderWidth  // 256
    static let contentHeight: CGFloat = windowSize.height - titlebarHeight - bottomBarHeight  // 174
}

/// Video Window - Pixel-perfect VIDEO.bmp chrome using absolute positioning
/// Matches Main/EQ/Playlist pattern: ZStack + SimpleSpriteImage + .at()
struct VideoWindowChromeView<Content: View>: View {
    @ViewBuilder let content: Content

    @State private var metadataScrollOffset: CGFloat = 0
    @State private var metadataScrollTimer: Timer?

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(WindowFocusState.self) private var windowFocusState

    // Computed: Is this window currently focused?
    private var isWindowActive: Bool {
        windowFocusState.isVideoKey
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            Color.black
                .frame(width: VideoWindowLayout.windowSize.width, height: VideoWindowLayout.windowSize.height)

            // Titlebar - full width drag handle wrapping all sprites
            WinampTitlebarDragHandle(windowKind: .video, size: CGSize(width: VideoWindowLayout.windowSize.width, height: VideoWindowLayout.titlebarHeight)) {
                ZStack(alignment: .topLeading) {
                    let suffix = isWindowActive ? "ACTIVE" : "INACTIVE"

                    // Left cap (25px)
                    SimpleSpriteImage("VIDEO_TITLEBAR_TOP_LEFT_\(suffix)", width: 25, height: VideoWindowLayout.titlebarHeight)
                        .position(x: 12.5, y: 10)

                    // Left tiles
                    ForEach(0..<3, id: \.self) { i in
                        SimpleSpriteImage("VIDEO_TITLEBAR_STRETCHY_\(suffix)", width: 25, height: VideoWindowLayout.titlebarHeight)
                            .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
                    }

                    // Center "WINAMP VIDEO" text
                    SimpleSpriteImage("VIDEO_TITLEBAR_TOP_CENTER_\(suffix)", width: 100, height: VideoWindowLayout.titlebarHeight)
                        .position(x: 137.5, y: 10)

                    // Right tiles
                    ForEach(0..<3, id: \.self) { i in
                        SimpleSpriteImage("VIDEO_TITLEBAR_STRETCHY_\(suffix)", width: 25, height: VideoWindowLayout.titlebarHeight)
                            .position(x: 187.5 + 12.5 + CGFloat(i) * 25, y: 10)
                    }

                    // Right cap
                    SimpleSpriteImage("VIDEO_TITLEBAR_TOP_RIGHT_\(suffix)", width: 25, height: VideoWindowLayout.titlebarHeight)
                        .position(x: 262.5, y: 10)
                }
            }
            .position(x: 137.5, y: 10)  // Center the entire drag handle

            // Side borders - tiled vertically like playlist (29px per tile)
            let sideHeight: CGFloat = 174  // 232 - 20 - 38
            let sideTileCount = Int(ceil(sideHeight / 29))  // 6 tiles
            ForEach(0..<sideTileCount, id: \.self) { i in
                // Left border (11px wide)
                SimpleSpriteImage("VIDEO_BORDER_LEFT", width: 11, height: 29)
                    .position(x: 5.5, y: 20 + 14.5 + CGFloat(i) * 29)

                // Right border (8px wide)
                SimpleSpriteImage("VIDEO_BORDER_RIGHT", width: 8, height: 29)
                    .position(x: 271, y: 20 + 14.5 + CGFloat(i) * 29)  // 275 - 4 = 271
            }

            // Content area
            content
                .frame(width: VideoWindowLayout.contentWidth, height: VideoWindowLayout.contentHeight)
                .position(x: VideoWindowLayout.windowSize.width / 2, y: 20 + sideHeight / 2)

            // Bottom bar - 3 pieces (left + tiled center + right)
            // Left section (125px) - buttons, align with left border
            SimpleSpriteImage("VIDEO_BOTTOM_LEFT", width: 125, height: 38)
                .position(x: 62.5, y: 213)

            // Center tiles - fill gap between left and right sections
            let bottomGap = VideoWindowLayout.windowSize.width - 125 - 125  // 25px
            let bottomTileCount = Int(ceil(bottomGap / 25))  // 1 tile
            ForEach(0..<bottomTileCount, id: \.self) { i in
                SimpleSpriteImage("VIDEO_BOTTOM_TILE", width: 25, height: 38)
                    .position(x: 125 + 12.5 + CGFloat(i) * 25, y: 213)
            }

            // Right section (125px) - info area, align with right border
            SimpleSpriteImage("VIDEO_BOTTOM_RIGHT", width: 125, height: 38)
                .position(x: 212.5, y: 213)

            // Video metadata text overlay (rendered using TEXT.bmp sprites)
            if !audioPlayer.videoMetadataString.isEmpty {
                buildVideoMetadataText()
            }
        }
        .frame(minWidth: VideoWindowLayout.windowSize.width, minHeight: VideoWindowLayout.windowSize.height, alignment: .topLeading)
        .background(Color.black)
        .onDisappear {
            // Clean up timer to prevent leaks
            metadataScrollTimer?.invalidate()
            metadataScrollTimer = nil
        }
    }

    @ViewBuilder
    private func buildVideoMetadataText() -> some View {
        // Render video metadata using TEXT.bmp sprites (same pattern as main window)
        let text = audioPlayer.videoMetadataString
        let textWidth = CGFloat(text.count * 5)  // 5px per character
        let displayWidth: CGFloat = 115  // Constrained to VIDEO_BOTTOM_RIGHT sprite (125px - margins)

        HStack(spacing: 0) {
            ForEach(Array(text.uppercased().enumerated()), id: \.offset) { _, character in
                let charCode: UInt8 = {
                    if let ascii = character.asciiValue {
                        // Convert uppercase to lowercase ASCII for TEXT.bmp lookup
                        if character.isLetter && character.isUppercase {
                            return ascii + 32
                        }
                        return ascii
                    }
                    return 32  // Space
                }()

                SimpleSpriteImage("CHARACTER_\(charCode)", width: 5, height: 6)
            }
        }
        .offset(x: textWidth > displayWidth ? metadataScrollOffset : 0, y: 0)
        .frame(width: displayWidth, height: 6, alignment: .leading)
        .clipped()
        .position(x: 170, y: 213)  // Centered in VIDEO_BOTTOM_RIGHT section
        .onAppear {
            if textWidth > displayWidth {
                startMetadataScrolling(textWidth: textWidth, displayWidth: displayWidth)
            }
        }
        .onChange(of: audioPlayer.videoMetadataString) { _, _ in
            resetMetadataScrolling()
            if textWidth > displayWidth {
                startMetadataScrolling(textWidth: textWidth, displayWidth: displayWidth)
            }
        }
    }

    private func startMetadataScrolling(textWidth: CGFloat, displayWidth: CGFloat) {
        metadataScrollTimer?.invalidate()
        metadataScrollOffset = 0

        metadataScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            // Timer fires on main thread, directly update @State
            MainActor.assumeIsolated {
                self.metadataScrollOffset -= 5  // Move left by one character width

                // Reset when scrolled past end
                if abs(self.metadataScrollOffset) >= textWidth + 20 {
                    self.metadataScrollOffset = displayWidth
                }
            }
        }
        if let timer = metadataScrollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func resetMetadataScrolling() {
        metadataScrollTimer?.invalidate()
        metadataScrollTimer = nil
        metadataScrollOffset = 0
    }
}
