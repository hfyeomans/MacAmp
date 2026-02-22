import SwiftUI
import AppKit

struct WinampPlaylistWindow: View {
    @Environment(SkinManager.self) private var skinManager
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(AppSettings.self) private var settings
    @Environment(RadioStationLibrary.self) private var radioLibrary
    @Environment(WindowFocusState.self) private var windowFocusState

    @State private var ui = PlaylistWindowInteractionState()
    @State private var menuDelegate = PlaylistMenuDelegate()
    @State private var sizeState = PlaylistWindowSizeState()

    private var windowWidth: CGFloat { sizeState.windowWidth }
    private var windowHeight: CGFloat { sizeState.windowHeight }

    private var isWindowActive: Bool {
        windowFocusState.isPlaylistKey
    }

    private var maxScrollOffset: Int {
        max(0, audioPlayer.playlist.count - sizeState.visibleTrackCount)
    }

    private var playlistStyle: PlaylistStyle {
        skinManager.currentSkin?.playlistStyle ?? PlaylistStyle(
            normalTextColor: Color(red: 0, green: 1.0, blue: 0),
            currentTextColor: .white,
            backgroundColor: Color.black,
            selectedBackgroundColor: Color(red: 0, green: 0, blue: 0.776),
            fontName: nil
        )
    }

    private var menuPresenter: PlaylistMenuPresenter {
        PlaylistMenuPresenter(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            menuDelegate: menuDelegate,
            windowHeight: windowHeight,
            windowWidth: windowWidth,
            selectedIndices: ui.selectedIndices
        )
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                if !ui.isShadeMode {
                    buildCompleteBackground()
                    buildContentOverlay()
                } else {
                    PlaylistShadeView(
                        windowWidth: windowWidth,
                        isWindowActive: isWindowActive,
                        onMinimize: { WindowCoordinator.shared?.minimizeKeyWindow() },
                        onShadeToggle: { ui.isShadeMode.toggle() },
                        onClose: { WindowCoordinator.shared?.hidePlaylistWindow() }
                    )
                }
            }
            .frame(width: windowWidth, height: ui.isShadeMode ? 14 : windowHeight)
        }
        .frame(width: windowWidth, height: ui.isShadeMode ? 14 : windowHeight)
        .background(Color.black)
        .onAppear {
            ui.installKeyboardMonitor { [audioPlayer] in audioPlayer.playlist.count }
            PlaylistWindowActions.shared.radioLibrary = radioLibrary
            WindowCoordinator.shared?.updatePlaylistWindowSize(to: sizeState.pixelSize)
        }
        .onChange(of: sizeState.size) { _, newSize in
            let pixelSize = newSize.toPlaylistPixels()
            WindowCoordinator.shared?.updatePlaylistWindowSize(to: pixelSize)
        }
        .onDisappear {
            ui.removeKeyboardMonitor()
        }
    }

    // MARK: - Content Overlay

    @ViewBuilder
    private func buildContentOverlay() -> some View {
        let contentWidth = sizeState.contentWidth
        let contentHeight = sizeState.contentHeight
        let contentCenterX = PlaylistWindowSizeState.leftBorderWidth + (contentWidth / 2)
        let contentCenterY = PlaylistWindowSizeState.topBarHeight + (contentHeight / 2)

        ZStack {
            playlistStyle.backgroundColor

            PlaylistTrackListView(
                sizeState: sizeState,
                playlistStyle: playlistStyle,
                scrollOffset: $ui.scrollOffset,
                onTrackTap: { ui.handleTrackTap(index: $0) },
                selectedIndices: ui.selectedIndices
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: contentWidth, height: contentHeight)
        .position(x: contentCenterX, y: contentCenterY)
        .clipped()

        PlaylistBottomControlsView(
            windowWidth: windowWidth,
            windowHeight: windowHeight,
            menuPresenter: menuPresenter
        )

        PlaylistTitleBarButtons(
            windowWidth: windowWidth,
            onMinimize: { WindowCoordinator.shared?.minimizeKeyWindow() },
            onShadeToggle: { ui.isShadeMode.toggle() },
            onClose: { WindowCoordinator.shared?.hidePlaylistWindow() }
        )

        PlaylistScrollSlider(
            scrollOffset: $ui.scrollOffset,
            totalTracks: audioPlayer.playlist.count,
            visibleTracks: sizeState.visibleTrackCount
        )
        .frame(height: sizeState.contentHeight - 4)
        .position(x: windowWidth - 15, y: PlaylistWindowSizeState.topBarHeight + (sizeState.contentHeight / 2))
        .onChange(of: audioPlayer.playlist.count) { _, _ in
            ui.clampScrollOffset(maxOffset: maxScrollOffset)
        }
        .onChange(of: sizeState.visibleTrackCount) { _, _ in
            ui.clampScrollOffset(maxOffset: maxScrollOffset)
        }

        PlaylistResizeHandle(
            windowWidth: windowWidth,
            windowHeight: windowHeight,
            sizeState: sizeState,
            dragStartSize: $ui.dragStartSize,
            isDragging: $ui.isDragging,
            resizePreview: ui.resizePreview
        )
    }

    // MARK: - Background Chrome

    @ViewBuilder
    private func buildCompleteBackground() -> some View {
        let suffix = isWindowActive ? "_SELECTED" : ""

        // === TOP BAR ===
        SimpleSpriteImage("PLAYLIST_TOP_LEFT\(isWindowActive ? "_SELECTED" : "_CORNER")", width: 25, height: 20)
            .position(x: 12.5, y: 10)

        ForEach(0..<sizeState.topBarTileCount, id: \.self) { i in
            SimpleSpriteImage("PLAYLIST_TOP_TILE\(suffix)", width: 25, height: 20)
                .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
        }

        WinampTitlebarDragHandle(windowKind: .playlist, size: CGSize(width: 100, height: 20)) {
            SimpleSpriteImage("PLAYLIST_TITLE_BAR\(suffix)", width: 100, height: 20)
        }
        .position(x: windowWidth / 2, y: 10)

        SimpleSpriteImage("PLAYLIST_TOP_RIGHT_CORNER\(suffix)", width: 25, height: 20)
            .position(x: windowWidth - 12.5, y: 10)

        // === SIDE BORDERS ===
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
        let showVisualizer = sizeState.size.width >= 3

        SimpleSpriteImage("PLAYLIST_BOTTOM_LEFT_CORNER", width: 125, height: 38)
            .position(x: 62.5, y: windowHeight - 19)

        let centerEndX: CGFloat = showVisualizer ? (windowWidth - 225) : (windowWidth - 150)
        let centerAvailableWidth = max(0, centerEndX - 125)
        let centerTileCount = Int(centerAvailableWidth / 25)

        if centerTileCount > 0 {
            ForEach(0..<centerTileCount, id: \.self) { i in
                SimpleSpriteImage("PLAYLIST_BOTTOM_TILE", width: 25, height: 38)
                    .position(x: 125 + 12.5 + CGFloat(i) * 25, y: windowHeight - 19)
            }
        }

        if showVisualizer {
            SimpleSpriteImage("PLAYLIST_VISUALIZER_BACKGROUND", width: 75, height: 38)
                .position(x: windowWidth - 187.5, y: windowHeight - 19)

            if settings.isMainWindowShaded {
                VisualizerView()
                    .frame(width: 76, height: 16)
                    .frame(width: 72, alignment: .leading)
                    .clipped()
                    .position(x: windowWidth - 187, y: windowHeight - 18)
            }
        }

        SimpleSpriteImage("PLAYLIST_BOTTOM_RIGHT_CORNER", width: 150, height: 38)
            .position(x: windowWidth - 75, y: windowHeight - 19)
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
