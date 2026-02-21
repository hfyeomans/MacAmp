import SwiftUI
import AppKit

struct WinampPlaylistWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(AppSettings.self) var settings
    @Environment(RadioStationLibrary.self) var radioLibrary
    @Environment(PlaybackCoordinator.self) var playbackCoordinator
    @Environment(WindowFocusState.self) var windowFocusState

    @State var selectedIndices: Set<Int> = []
    @State private var isShadeMode: Bool = false
    @State private var keyboardMonitor: Any?
    @State var menuDelegate = PlaylistMenuDelegate()  // NSMenuDelegate for keyboard navigation
    @State private var sizeState = PlaylistWindowSizeState()

    // Resize gesture state (Phase 3)
    @State private var dragStartSize: Size2D?
    @State private var isDragging: Bool = false
    @State private var resizePreview = WindowResizePreviewOverlay()

    // Scroll state (Phase 4)
    @State private var scrollOffset: Int = 0

    /// Maximum valid scroll offset (clamped to prevent out-of-bounds)
    private var maxScrollOffset: Int {
        max(0, audioPlayer.playlist.count - sizeState.visibleTrackCount)
    }

    /// Clamped scroll offset that's always valid
    private var clampedScrollOffset: Int {
        min(scrollOffset, maxScrollOffset)
    }

    // Dynamic dimensions from size state
    var windowWidth: CGFloat { sizeState.windowWidth }
    var windowHeight: CGFloat { sizeState.windowHeight }

    // Computed: Is this window currently focused?
    var isWindowActive: Bool {
        windowFocusState.isPlaylistKey
    }

    private var totalPlaylistDuration: Double {
        audioPlayer.playlist.reduce(0.0) { total, track in
            total + track.duration
        }
    }

    private var remainingTime: Double {
        guard audioPlayer.currentDuration > 0 else { return 0 }
        return max(0, audioPlayer.currentDuration - audioPlayer.currentTime)
    }

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private var trackTimeText: String {
        guard audioPlayer.currentTrack != nil,
              audioPlayer.currentDuration > 0 else {
            return ":"
        }

        let current = formatTime(audioPlayer.currentTime)
        let total = formatTime(totalPlaylistDuration)
        return "\(current) / \(total)"
    }

    private var remainingTimeText: String {
        guard audioPlayer.isPlaying,
              audioPlayer.currentTrack != nil,
              audioPlayer.currentDuration > 0 else {
            return ""
        }

        let remaining = formatTime(remainingTime)
        return "-\(remaining)"
    }

    var playlistStyle: PlaylistStyle {
        skinManager.currentSkin?.playlistStyle ?? PlaylistStyle(
            normalTextColor: Color(red: 0, green: 1.0, blue: 0),
            currentTextColor: .white,
            backgroundColor: Color.black,
            selectedBackgroundColor: Color(red: 0, green: 0, blue: 0.776),
            fontName: nil
        )
    }

    private var playlistBackgroundColor: Color {
        playlistStyle.backgroundColor
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                if !isShadeMode {
                    buildCompleteBackground()
                    buildContentOverlay()
                } else {
                    buildShadeMode()
                }
            }
            .frame(width: windowWidth, height: isShadeMode ? 14 : windowHeight)
        }
        .frame(width: windowWidth, height: isShadeMode ? 14 : windowHeight)
        .background(Color.black)
        .onAppear {
            // Store monitor reference to keep it alive
            keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                return handleKeyPress(event: event)
            }

            // Inject radioLibrary into shared actions for ADD URL functionality
            PlaylistWindowActions.shared.radioLibrary = radioLibrary

            // CRITICAL: Sync NSWindow size from persisted PlaylistWindowSizeState
            // This ensures the AppKit window matches the SwiftUI layout on launch
            WindowCoordinator.shared?.updatePlaylistWindowSize(to: sizeState.pixelSize)
        }
        // Sync NSWindow when sizeState.size changes programmatically (e.g., resetToDefault)
        .onChange(of: sizeState.size) { _, newSize in
            let pixelSize = newSize.toPlaylistPixels()
            WindowCoordinator.shared?.updatePlaylistWindowSize(to: pixelSize)
        }
        .onDisappear {
            // Clean up keyboard monitor
            if let monitor = keyboardMonitor {
                NSEvent.removeMonitor(monitor)
                keyboardMonitor = nil
            }
        }
    }
    
    private func handleKeyPress(event: NSEvent) -> NSEvent? {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "a" {
            selectedIndices = Set(0..<audioPlayer.playlist.count)
            return nil
        }

        if event.keyCode == 53 || (event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "d") {
            selectedIndices = []
            return nil
        }

        return event
    }

    @ViewBuilder
    private func buildCompleteBackground() -> some View {
        let suffix = isWindowActive ? "_SELECTED" : ""

        // === TOP BAR ===
        // Winamp layout: Tiles as BACKGROUND layer, then title/corners OVERLAY on top
        // This matches webamp's flex-grow approach: tiles fill entire width, title overlays

        // 1. Left corner (bottom layer, at left edge)
        SimpleSpriteImage("PLAYLIST_TOP_LEFT\(isWindowActive ? "_SELECTED" : "_CORNER")", width: 25, height: 20)
            .position(x: 12.5, y: 10)

        // 2. Background tiles: Fill from left corner (25px) to window edge
        // Tiles render UNDER the title bar (drawn first in ZStack)
        ForEach(0..<sizeState.topBarTileCount, id: \.self) { i in
            SimpleSpriteImage("PLAYLIST_TOP_TILE\(suffix)", width: 25, height: 20)
                .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
        }

        // 3. Title bar OVERLAY (centered, drawn on top of tiles)
        WinampTitlebarDragHandle(windowKind: .playlist, size: CGSize(width: 100, height: 20)) {
            SimpleSpriteImage("PLAYLIST_TITLE_BAR\(suffix)", width: 100, height: 20)
        }
        .position(x: windowWidth / 2, y: 10)

        // 4. Right corner OVERLAY (at right edge, drawn on top of tiles)
        SimpleSpriteImage("PLAYLIST_TOP_RIGHT_CORNER\(suffix)", width: 25, height: 20)
            .position(x: windowWidth - 12.5, y: 10)

        // === SIDE BORDERS ===
        // Dynamic vertical tiling based on window height
        let borderTileCount = sizeState.verticalBorderTileCount
        ForEach(0..<borderTileCount, id: \.self) { i in
            SimpleSpriteImage("PLAYLIST_LEFT_TILE", width: 12, height: 29)
                .position(x: 6, y: 20 + 14.5 + CGFloat(i) * 29)
        }

        ForEach(0..<borderTileCount, id: \.self) { i in
            SimpleSpriteImage("PLAYLIST_RIGHT_TILE", width: 20, height: 29)
                .position(x: windowWidth - 10, y: 20 + 14.5 + CGFloat(i) * 29)
        }

        // === BOTTOM BAR ===
        // Layout: LEFT (125px) + CENTER tiles + [VISUALIZER (75px) when wide] + RIGHT (150px)
        // Webamp: showVisualizer = playlistSize[0] > 2 (3+ width segments = 350px minimum)
        // Visualizer positioned at right:150px in CSS = between center and right sections

        let showVisualizer = sizeState.size.width >= 3  // 275 + 75 = 350px minimum

        // Left section (0 to 125px)
        SimpleSpriteImage("PLAYLIST_BOTTOM_LEFT_CORNER", width: 125, height: 38)
            .position(x: 62.5, y: windowHeight - 19)

        // Center tiles: fill from 125px to visualizer (or right section if no visualizer)
        // With visualizer: center ends at windowWidth - 225 (leaving 75px for visualizer)
        // Without visualizer: center ends at windowWidth - 150
        let centerEndX: CGFloat = showVisualizer ? (windowWidth - 225) : (windowWidth - 150)
        let centerAvailableWidth = max(0, centerEndX - 125)
        let centerTileCount = Int(centerAvailableWidth / 25)

        if centerTileCount > 0 {
            ForEach(0..<centerTileCount, id: \.self) { i in
                SimpleSpriteImage("PLAYLIST_BOTTOM_TILE", width: 25, height: 38)
                    .position(x: 125 + 12.5 + CGFloat(i) * 25, y: windowHeight - 19)
            }
        }

        // Visualizer background (75px, only when window wide enough)
        // Position: from (windowWidth - 225) to (windowWidth - 150)
        if showVisualizer {
            SimpleSpriteImage("PLAYLIST_VISUALIZER_BACKGROUND", width: 75, height: 38)
                .position(x: windowWidth - 187.5, y: windowHeight - 19)

            // Mini visualizer: Only active when main window is SHADED
            // When main window is in full mode, its visualizer is visible and this stays empty
            // Gemini verified: render full 76px width, clip to 72px for historical accuracy
            if settings.isMainWindowShaded {
                VisualizerView()
                    .frame(width: 76, height: 16)           // Render at full size
                    .frame(width: 72, alignment: .leading)  // Clip to 72px (4px hidden from right)
                    .clipped()
                    // Position within the 75×38 visualizer container
                    // Container spans: x=(windowWidth-225) to (windowWidth-150), y=(windowHeight-38) to windowHeight
                    // CSS reference: wrapper at top:12px, left:2px within container
                    // Visualizer center: x = (windowWidth-225) + 2 + 36 = windowWidth-187
                    //                   y = (windowHeight-38) + 12 + 8 = windowHeight-18
                    .position(x: windowWidth - 187, y: windowHeight - 18)
            }
        }

        // Right section (windowWidth - 150 to windowWidth)
        SimpleSpriteImage("PLAYLIST_BOTTOM_RIGHT_CORNER", width: 150, height: 38)
            .position(x: windowWidth - 75, y: windowHeight - 19)
    }
    
    @ViewBuilder
    private func buildContentOverlay() -> some View {
        // Content area: Dynamic sizing based on window dimensions
        let contentWidth = sizeState.contentWidth
        let contentHeight = sizeState.contentHeight
        let contentCenterX = PlaylistWindowSizeState.leftBorderWidth + (contentWidth / 2)
        let contentCenterY = PlaylistWindowSizeState.topBarHeight + (contentHeight / 2)

        ZStack {
            playlistBackgroundColor

            buildTrackList()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: contentWidth, height: contentHeight)
        .position(x: contentCenterX, y: contentCenterY)
        .clipped()

            buildBottomControls()
            buildPlaylistTransportButtons()
            buildTimeDisplays()
            buildTitleBarButtons()

        // Scroll slider (Phase 4 - functional scroll with binding)
        PlaylistScrollSlider(
            scrollOffset: $scrollOffset,
            totalTracks: audioPlayer.playlist.count,
            visibleTracks: sizeState.visibleTrackCount
        )
        .frame(height: sizeState.contentHeight - 4)  // Leave room for top/bottom padding
        .position(x: windowWidth - 15, y: PlaylistWindowSizeState.topBarHeight + (sizeState.contentHeight / 2))
        // Clamp scrollOffset when playlist size changes
        .onChange(of: audioPlayer.playlist.count) { _, _ in
            if scrollOffset > maxScrollOffset {
                scrollOffset = maxScrollOffset
            }
        }
        // Clamp scrollOffset when window is resized (visible tracks change)
        .onChange(of: sizeState.visibleTrackCount) { _, _ in
            if scrollOffset > maxScrollOffset {
                scrollOffset = maxScrollOffset
            }
        }

        // Resize handle (20×20 hit area at bottom-right corner)
        buildResizeHandle()
    }
    
    @ViewBuilder
    private func buildTrackList() -> some View {
        let trackWidth = sizeState.contentWidth
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(audioPlayer.playlist.enumerated()), id: \.element.id) { index, track in
                        trackRow(track: track, index: index)
                            .frame(width: trackWidth, height: 13)
                            .background(trackBackground(track: track, index: index))
                            .id(index)
                            .onTapGesture(count: 2) {
                                Task { await playbackCoordinator.play(track: track) }
                            }
                            .onTapGesture { handleTrackTap(index: index) }
                    }
                }
            }
            .onChange(of: scrollOffset) { _, newOffset in
                // Sync: scroll slider → scroll view
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(newOffset, anchor: .top)
                }
            }
        }
    }
    
    @ViewBuilder
    private func trackRow(track: Track, index: Int) -> some View {
        let textColor = trackTextColor(track: track)
        HStack(spacing: 2) {
            // Track number - real text instead of bitmap font
            Text("\(index + 1).")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(textColor)
                .frame(width: 18, alignment: .trailing)

            // Track title and artist - real text instead of bitmap font
            Text("\(track.title) - \(track.artist)")
                .font(.system(size: 9))
                .foregroundColor(textColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            // Duration - real text instead of bitmap font
            Text(formatDuration(track.duration))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(textColor)
                .frame(width: 38, alignment: .trailing)
                .padding(.trailing, 3)
        }
        .padding(.horizontal, 2)
    }
    
    @ViewBuilder
    private func buildBottomControls() -> some View {
        // Bottom menu buttons: Positioned relative to window edges
        // Y position: 24px from bottom (windowHeight - 24)
        let buttonY = windowHeight - 24

        // LEFT section buttons (fixed positions from left)
        Button(action: { showAddMenu() }, label: {
            Color.clear.frame(width: 22, height: 18).contentShape(Rectangle())
        }).buttonStyle(.plain).focusable(false).position(x: 16, y: buttonY)

        Button(action: { showRemMenu() }, label: {
            Color.clear.frame(width: 22, height: 18).contentShape(Rectangle())
        }).buttonStyle(.plain).focusable(false).position(x: 42, y: buttonY)

        Button(action: { showSelNotSupportedAlert() }, label: {
            Color.clear.frame(width: 18, height: 18).contentShape(Rectangle())
        }).buttonStyle(.plain).focusable(false).position(x: 78, y: buttonY)

        Button(action: { showMiscMenu() }, label: {
            Color.clear.frame(width: 18, height: 18).contentShape(Rectangle())
        }).buttonStyle(.plain).focusable(false).position(x: 105, y: buttonY)

        // RIGHT section button (fixed position from right edge)
        Button(action: { showListMenu() }, label: {
            Color.clear.frame(width: 22, height: 18).contentShape(Rectangle())
        }).buttonStyle(.plain).focusable(false).position(x: windowWidth - 32, y: buttonY)
    }

    @ViewBuilder
    private func buildPlaylistTransportButtons() -> some View {
        let transportY = windowHeight - 12
        let baseX = windowWidth - 150 + 8

        playlistTransportButton(action: { Task { await playbackCoordinator.previous() } }, x: baseX, y: transportY)
        playlistTransportButton(action: { playbackCoordinator.togglePlayPause() }, x: baseX + 11, y: transportY)
        playlistTransportButton(action: { playbackCoordinator.pause() }, x: baseX + 22, y: transportY)
        playlistTransportButton(action: { playbackCoordinator.stop() }, x: baseX + 33, y: transportY)
        playlistTransportButton(action: { Task { await playbackCoordinator.next() } }, x: baseX + 44, y: transportY)
        playlistTransportButton(action: { openFileDialog() }, x: baseX + 50, y: transportY)
    }

    private func playlistTransportButton(action: @escaping () -> Void, x: CGFloat, y: CGFloat) -> some View {
        Button(action: action, label: {
            Color.clear.frame(width: 10, height: 9).contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: x, y: y)
    }

    @ViewBuilder
    private func buildTimeDisplays() -> some View {
        // Time displays: In RIGHT section of bottom bar
        let rightSectionStart = windowWidth - 150
        let timeY1 = windowHeight - 26  // First time display (track time)
        let timeY2 = windowHeight - 13  // Second time display (remaining)

        PlaylistTimeText(trackTimeText)
            .position(x: rightSectionStart + 51, y: timeY1)

        if !remainingTimeText.isEmpty {
            PlaylistTimeText(remainingTimeText)
                .position(x: rightSectionStart + 78, y: timeY2)
        }
    }

    @ViewBuilder
    func buildTitleBarButtons() -> some View {
        // Title bar buttons: Positioned relative to right edge
        let buttonY: CGFloat = 7.5

        Button(action: { WindowCoordinator.shared?.minimizeKeyWindow() }, label: {
            SimpleSpriteImage("MAIN_MINIMIZE_BUTTON", width: 9, height: 9)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: windowWidth - 26.5, y: buttonY)

        Button(action: {
            isShadeMode.toggle()
        }, label: {
            SimpleSpriteImage("MAIN_SHADE_BUTTON", width: 9, height: 9)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: windowWidth - 16.5, y: buttonY)

        Button(action: { WindowCoordinator.shared?.hidePlaylistWindow() }, label: {
            SimpleSpriteImage("MAIN_CLOSE_BUTTON", width: 9, height: 9)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: windowWidth - 6.5, y: buttonY)
    }

    // MARK: - Resize Handle (Phase 3)

    @ViewBuilder
    private func buildResizeHandle() -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Capture start size on first drag tick
                        if dragStartSize == nil {
                            dragStartSize = sizeState.size
                            isDragging = true
                            // CRITICAL: Prevent magnetic snapping during resize
                            WindowSnapManager.shared.beginProgrammaticAdjustment()
                        }

                        guard let baseSize = dragStartSize else { return }

                        // Calculate quantized size from drag delta (25×29px segments)
                        let widthDelta = Int(round(value.translation.width / PlaylistWindowSizeState.segmentWidth))
                        let heightDelta = Int(round(value.translation.height / PlaylistWindowSizeState.segmentHeight))

                        let candidate = Size2D(
                            width: max(0, baseSize.width + widthDelta),
                            height: max(0, baseSize.height + heightDelta)
                        )

                        // APPKIT PREVIEW: Update overlay window via coordinator bridge
                        // Note: Playlist window does NOT use double-size mode (unlike main/EQ windows)
                        if let coordinator = WindowCoordinator.shared {
                            let previewPixels = candidate.toPlaylistPixels()
                            coordinator.showPlaylistResizePreview(resizePreview, previewSize: previewPixels)
                        }
                    }
                    .onEnded { value in
                        // Calculate final size from total drag
                        guard let baseSize = dragStartSize else { return }

                        let widthDelta = Int(round(value.translation.width / PlaylistWindowSizeState.segmentWidth))
                        let heightDelta = Int(round(value.translation.height / PlaylistWindowSizeState.segmentHeight))

                        let finalSize = Size2D(
                            width: max(0, baseSize.width + widthDelta),
                            height: max(0, baseSize.height + heightDelta)
                        )

                        // COMMIT: Update actual size (triggers persistence via didSet)
                        sizeState.size = finalSize

                        // Sync NSWindow frame via coordinator bridge
                        if let coordinator = WindowCoordinator.shared {
                            coordinator.updatePlaylistWindowSize(to: sizeState.pixelSize)
                            coordinator.hidePlaylistResizePreview(resizePreview)
                        }

                        // Clean up
                        isDragging = false
                        dragStartSize = nil
                        // CRITICAL: Re-enable magnetic snapping
                        WindowSnapManager.shared.endProgrammaticAdjustment()
                    }
            )
            .position(x: windowWidth - 10, y: windowHeight - 10)
    }
}

extension SimpleSpriteImage {
    func position(x: CGFloat, y: CGFloat) -> some View {
        self.position(CGPoint(x: x, y: y))
    }
}

#Preview {
    WinampPlaylistWindow()
        .environment(SkinManager())
        .environment(AudioPlayer())
        .environment(AppSettings.instance())
}
