import SwiftUI

/// Layout constants for Video Window (chrome component sizes)
private enum VideoWindowLayout {
    static let titlebarHeight: CGFloat = 20
    static let bottomBarHeight: CGFloat = 38
    static let leftBorderWidth: CGFloat = 11
    static let rightBorderWidth: CGFloat = 8
    static let bottomLeftWidth: CGFloat = 125
    static let bottomRightWidth: CGFloat = 125
}

/// Video Window - Dynamic sizing with VIDEO.bmp chrome using Size2D segments
/// Resizable pattern matching Playlist: 25×29px quantized resize
struct VideoWindowChromeView<Content: View>: View {
    @ViewBuilder let content: Content
    let sizeState: VideoWindowSizeState

    @State private var metadataScrollOffset: CGFloat = 0
    @State private var metadataScrollTimer: Timer?
    @State private var dragStartSize: Size2D?  // Oracle fix: struct-level state for drag

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(WindowFocusState.self) private var windowFocusState

    // Computed: Is this window currently focused?
    private var isWindowActive: Bool {
        windowFocusState.isVideoKey
    }

    // MARK: - Dynamic Layout Calculations

    private var pixelSize: CGSize {
        sizeState.pixelSize
    }

    private var contentSize: CGSize {
        sizeState.contentSize
    }

    private var contentCenterY: CGFloat {
        VideoWindowLayout.titlebarHeight + contentSize.height / 2
    }

    private var bottomBarY: CGFloat {
        pixelSize.height - VideoWindowLayout.bottomBarHeight / 2
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            Color.black
                .frame(width: pixelSize.width, height: pixelSize.height)

            // Titlebar - dynamic width drag handle wrapping all sprites
            buildDynamicTitlebar()

            // Side borders - tiled vertically based on height
            buildDynamicBorders()

            // Content area
            content
                .frame(width: contentSize.width, height: contentSize.height)
                .position(x: pixelSize.width / 2, y: contentCenterY)

            // Bottom bar - three-section layout with dynamic center
            buildDynamicBottomBar()

            // Video metadata text overlay
            if !audioPlayer.videoMetadataString.isEmpty {
                buildVideoMetadataText()
            }

            // Clickable button regions
            buildVideoWindowButtons()

            // Resize handle (bottom-right corner)
            buildResizeHandle()
        }
        .frame(width: pixelSize.width, height: pixelSize.height, alignment: .topLeading)
        .background(Color.black)
        .onDisappear {
            metadataScrollTimer?.invalidate()
            metadataScrollTimer = nil
        }
    }

    // MARK: - Dynamic Titlebar

    @ViewBuilder
    private func buildDynamicTitlebar() -> some View {
        WinampTitlebarDragHandle(windowKind: .video, size: CGSize(width: pixelSize.width, height: VideoWindowLayout.titlebarHeight)) {
            ZStack(alignment: .topLeading) {
                let suffix = isWindowActive ? "ACTIVE" : "INACTIVE"
                let distribution = sizeState.titlebarTileDistribution
                let centerX = pixelSize.width / 2

                // Left cap (25px)
                SimpleSpriteImage("VIDEO_TITLEBAR_TOP_LEFT_\(suffix)", width: 25, height: 20)
                    .position(x: 12.5, y: 10)

                // Left stretchy tiles (grow from right to left)
                ForEach(0..<distribution.left, id: \.self) { i in
                    SimpleSpriteImage("VIDEO_TITLEBAR_STRETCHY_\(suffix)", width: 25, height: 20)
                        .position(x: centerX - 50 - 12.5 - CGFloat(i) * 25, y: 10)
                }

                // Center "WINAMP VIDEO" text (100px, always centered)
                SimpleSpriteImage("VIDEO_TITLEBAR_TOP_CENTER_\(suffix)", width: 100, height: 20)
                    .position(x: centerX, y: 10)

                // Right stretchy tiles (grow from left to right)
                ForEach(0..<distribution.right, id: \.self) { i in
                    SimpleSpriteImage("VIDEO_TITLEBAR_STRETCHY_\(suffix)", width: 25, height: 20)
                        .position(x: centerX + 50 + 12.5 + CGFloat(i) * 25, y: 10)
                }

                // Right cap (25px)
                SimpleSpriteImage("VIDEO_TITLEBAR_TOP_RIGHT_\(suffix)", width: 25, height: 20)
                    .position(x: pixelSize.width - 12.5, y: 10)
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
            SimpleSpriteImage("VIDEO_BORDER_LEFT", width: 11, height: 29)
                .position(x: 5.5, y: 20 + 14.5 + CGFloat(i) * 29)

            // Right border (8px wide)
            SimpleSpriteImage("VIDEO_BORDER_RIGHT", width: 8, height: 29)
                .position(x: pixelSize.width - 4, y: 20 + 14.5 + CGFloat(i) * 29)
        }
    }

    // MARK: - Dynamic Bottom Bar

    @ViewBuilder
    private func buildDynamicBottomBar() -> some View {
        // Three-section layout: LEFT (125px) + CENTER (tiles) + RIGHT (125px)

        // LEFT section (125px fixed) - baked-on buttons
        SimpleSpriteImage("VIDEO_BOTTOM_LEFT", width: 125, height: 38)
            .position(x: 62.5, y: bottomBarY)

        // CENTER section (dynamic) - tiles VIDEO_BOTTOM_TILE
        let centerCount = sizeState.centerTileCount
        ForEach(0..<centerCount, id: \.self) { i in
            SimpleSpriteImage("VIDEO_BOTTOM_TILE", width: 25, height: 38)
                .position(x: 125 + 12.5 + CGFloat(i) * 25, y: bottomBarY)
        }

        // RIGHT section (125px fixed) - metadata display
        SimpleSpriteImage("VIDEO_BOTTOM_RIGHT", width: 125, height: 38)
            .position(x: pixelSize.width - 62.5, y: bottomBarY)
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
        .position(x: pixelSize.width - 105, y: bottomBarY)  // Dynamic: inside VIDEO_BOTTOM_RIGHT
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

    @ViewBuilder
    private func buildVideoWindowButtons() -> some View {
        // 1X button - clickable region over baked-on sprite
        // Sprite coordinates in VIDEO_BOTTOM_LEFT: x=24, y=9 (relative to sprite)
        // Window coordinates: Fixed to LEFT section
        Button(action: {
            sizeState.size = .videoDefault  // Set to [0,4] = 275×232
        }) {
            Color.clear
                .frame(width: 15, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: 31.5, y: bottomBarY)  // Dynamic Y position

        // 2X button - clickable region over baked-on sprite
        // Sprite coordinates in VIDEO_BOTTOM_LEFT: x=39, y=9 (relative to sprite)
        // Window coordinates: Fixed to LEFT section
        Button(action: {
            sizeState.size = .video2x  // Set to [11,12] = 550×464
        }) {
            Color.clear
                .frame(width: 15, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: 46.5, y: bottomBarY)  // Dynamic Y position
    }

    // MARK: - Resize Handle

    @ViewBuilder
    private func buildResizeHandle() -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Oracle fix: Capture start size on first drag tick
                        if dragStartSize == nil {
                            dragStartSize = sizeState.size
                            WindowSnapManager.shared.beginProgrammaticAdjustment()
                        }

                        guard let baseSize = dragStartSize else { return }

                        // Oracle fix: Use towardZero rounding to prevent oscillation
                        let widthDelta = Int((value.translation.width / 25).rounded(.towardZero))
                        let heightDelta = Int((value.translation.height / 29).rounded(.towardZero))

                        // Calculate new size with minimum constraint
                        let candidate = Size2D(
                            width: max(0, baseSize.width + widthDelta),
                            height: max(0, baseSize.height + heightDelta)
                        )

                        // Oracle fix: Only update if size actually changed (prevents fighting)
                        if candidate != sizeState.size {
                            sizeState.size = candidate
                        }
                    }
                    .onEnded { _ in
                        // Oracle fix: Clean up and end snap suppression
                        dragStartSize = nil
                        WindowSnapManager.shared.endProgrammaticAdjustment()
                    }
            )
            .position(x: pixelSize.width - 10, y: pixelSize.height - 10)
    }
}
