import SwiftUI
import AppKit

@MainActor
final class PlaylistWindowActions: NSObject {
    static let shared = PlaylistWindowActions()

    var selectedIndices: Set<Int> = []
    weak var radioLibrary: RadioStationLibrary?

    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func presentAddFilesPanel(audioPlayer: AudioPlayer, playbackCoordinator: PlaybackCoordinator? = nil) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.audio, .playlist, .movie]  // NEW: Support video files
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.title = "Add Files to Playlist"
        openPanel.message = "Select audio files, video files, or playlists"

        openPanel.begin { response in
            if response == .OK {
                let urls = openPanel.urls
                Task { @MainActor [weak self, urls, audioPlayer, playbackCoordinator] in
                    guard let self else { return }

                    // Remember if playlist was empty (for autoplay detection)
                    let wasEmpty = audioPlayer.playlist.isEmpty

                    self.handleSelectedURLs(urls, audioPlayer: audioPlayer)

                    // If playlist was empty and AudioPlayer autoplayed, sync coordinator state
                    if wasEmpty, let firstTrack = audioPlayer.currentTrack, let coordinator = playbackCoordinator {
                        await coordinator.play(track: firstTrack)
                    }

                    // Note: externalPlaybackHandler should be set once in MacAmpApp initialization
                    // Not here - setting it here clobbers coordinator's handler for playlist advance
                }
            }
        }
    }

    private func handleSelectedURLs(_ urls: [URL], audioPlayer: AudioPlayer) {
        for url in urls {
            let fileExtension = url.pathExtension.lowercased()
            if fileExtension == "m3u" || fileExtension == "m3u8" {
                // Load M3U/M3U8 files using radioLibrary
                if let radioLibrary {
                    loadM3UPlaylist(url, audioPlayer: audioPlayer, radioLibrary: radioLibrary)
                } else {
                    // Fallback if radioLibrary not available (shouldn't happen)
                    showAlert("Error", "Radio library not initialized. Please restart the app.")
                }
            } else {
                audioPlayer.addTrack(url: url)
            }
        }
    }

    private func loadM3UPlaylist(_ url: URL, audioPlayer: AudioPlayer, radioLibrary: RadioStationLibrary) {
        do {
            let entries = try M3UParser.parse(fileURL: url)
            var addedStreams = 0
            var addedFiles = 0

            for entry in entries {
                if entry.isRemoteStream {
                    // Add to playlist as Track (RadioStationLibrary is for favorites menu only)
                    let streamTrack = Track(
                        url: entry.url,
                        title: entry.title ?? "Unknown Station",
                        artist: "Internet Radio",
                        duration: 0.0  // Streams have no duration
                    )
                    audioPlayer.playlist.append(streamTrack)
                    addedStreams += 1
                } else {
                    // Add local file to playlist
                    audioPlayer.addTrack(url: entry.url)
                    addedFiles += 1
                }
            }

            // Show feedback
            let alert = NSAlert()
            alert.messageText = "M3U Playlist Loaded"

            var message = ""
            if addedFiles > 0 {
                message += "Added \(addedFiles) local file(s)"
            }
            if addedStreams > 0 {
                if !message.isEmpty { message += "\n" }
                message += "Added \(addedStreams) internet radio stream(s)"
            }
            message += "\n\nAll items visible in playlist."

            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to Load M3U Playlist"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc func addURL(_ sender: NSMenuItem) {
        guard let audioPlayer = sender.representedObject as? AudioPlayer else {
            showAlert("Error", "Audio player not available")
            return
        }

        let alert = NSAlert()
        alert.messageText = "Add Internet Radio Station"
        alert.informativeText = "Enter the stream URL (HTTP or HTTPS):"

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "http://stream.example.com/radio.mp3"
        alert.accessoryView = input

        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let urlString = input.stringValue.trimmingCharacters(in: .whitespaces)

            guard !urlString.isEmpty else {
                showAlert("Invalid URL", "Please enter a valid URL")
                return
            }

            guard let url = URL(string: urlString),
                  url.scheme == "http" || url.scheme == "https" else {
                showAlert("Invalid URL", "URL must start with http:// or https://")
                return
            }

            // Add to playlist as Track (RadioStationLibrary is for favorites menu only)
            let stationName = url.host ?? url.lastPathComponent
            let streamTrack = Track(
                url: url,
                title: stationName,
                artist: "Internet Radio",
                duration: 0.0
            )

            audioPlayer.playlist.append(streamTrack)

            showAlert("Stream Added", "Added '\(stationName)' to playlist.\n\nClick to play!")
        }
    }

    @objc func addDirectory(_ sender: NSMenuItem) {
        addFile(sender)
    }

    @objc func addFile(_ sender: NSMenuItem) {
        guard let audioPlayer = sender.representedObject as? AudioPlayer else {
            return
        }
        presentAddFilesPanel(audioPlayer: audioPlayer)
    }

    @objc func removeSelected(_ sender: NSMenuItem) {
        guard let audioPlayer = sender.representedObject as? AudioPlayer else {
            return
        }

        let indices = PlaylistWindowActions.shared.selectedIndices
        if indices.isEmpty {
            showAlert("Remove Selected", "No tracks selected")
        } else {
            for index in indices.sorted().reversed() {
                if index < audioPlayer.playlist.count {
                    audioPlayer.playlist.remove(at: index)
                }
            }
            PlaylistWindowActions.shared.selectedIndices = []
        }
    }

    @objc func cropPlaylist(_ sender: NSMenuItem) {
        guard let audioPlayer = sender.representedObject as? AudioPlayer else {
            return
        }

        let indices = PlaylistWindowActions.shared.selectedIndices
        if indices.isEmpty {
            showAlert("Crop Playlist", "No tracks selected. Select tracks to keep, then crop.")
        } else {
            let validIndices = indices.sorted().filter { $0 < audioPlayer.playlist.count }
            let selectedTracks = validIndices.map { audioPlayer.playlist[$0] }
            audioPlayer.playlist = selectedTracks
            PlaylistWindowActions.shared.selectedIndices = []
        }
    }

    @objc func removeAll(_ sender: NSMenuItem) {
        guard let audioPlayer = sender.representedObject as? AudioPlayer else {
            return
        }
        audioPlayer.playlist = []
    }

    @objc func removeMisc(_ sender: NSMenuItem) {
        showAlert("Remove Misc", "Not supported yet")
    }

    @objc func sortList(_ sender: NSMenuItem) {
        showAlert("Sort List", "Not supported yet")
    }

    @objc func fileInfo(_ sender: NSMenuItem) {
        showAlert("File Info", "Not supported yet")
    }

    @objc func miscOptions(_ sender: NSMenuItem) {
        showAlert("Misc Options", "Not supported yet")
    }

    @objc func newList(_ sender: NSMenuItem) {
        showAlert("New List", "Not supported yet")
    }

    @objc func saveList(_ sender: NSMenuItem) {
        showAlert("Save List", "Not supported yet")
    }

    @objc func loadList(_ sender: NSMenuItem) {
        showAlert("Load List", "Not supported yet")
    }
}

struct WinampPlaylistWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(AppSettings.self) var settings
    @Environment(RadioStationLibrary.self) var radioLibrary
    @Environment(PlaybackCoordinator.self) var playbackCoordinator
    @Environment(WindowFocusState.self) var windowFocusState

    @State private var selectedIndices: Set<Int> = []
    @State private var isShadeMode: Bool = false
    @State private var keyboardMonitor: Any?
    @State private var menuDelegate = PlaylistMenuDelegate()  // NSMenuDelegate for keyboard navigation
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
    private var windowWidth: CGFloat { sizeState.windowWidth }
    private var windowHeight: CGFloat { sizeState.windowHeight }

    // Computed: Is this window currently focused?
    private var isWindowActive: Bool {
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

    private var playlistStyle: PlaylistStyle {
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
        GeometryReader { geometry in
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
                            .id(index)  // Enable scroll-to by index
                            .onTapGesture(count: 2) {
                                // Double-click: Play via PlaybackCoordinator (handles both local + streams)
                                Task {
                                    await playbackCoordinator.play(track: track)
                                }
                            }
                            .onTapGesture {
                                // Single-click: Handle selection
                                let modifiers = NSEvent.modifierFlags

                                if modifiers.contains(.shift) {
                                    if selectedIndices.contains(index) {
                                        selectedIndices.remove(index)
                                    } else {
                                        selectedIndices.insert(index)
                                    }
                                } else {
                                    selectedIndices = [index]
                                }
                            }
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
        Button(action: { showAddMenu() }) {
            Color.clear.frame(width: 22, height: 18).contentShape(Rectangle())
        }.buttonStyle(.plain).focusable(false).position(x: 16, y: buttonY)

        Button(action: { showRemMenu() }) {
            Color.clear.frame(width: 22, height: 18).contentShape(Rectangle())
        }.buttonStyle(.plain).focusable(false).position(x: 42, y: buttonY)

        Button(action: { showSelNotSupportedAlert() }) {
            Color.clear.frame(width: 18, height: 18).contentShape(Rectangle())
        }.buttonStyle(.plain).focusable(false).position(x: 78, y: buttonY)

        Button(action: { showMiscMenu() }) {
            Color.clear.frame(width: 18, height: 18).contentShape(Rectangle())
        }.buttonStyle(.plain).focusable(false).position(x: 105, y: buttonY)

        // RIGHT section button (fixed position from right edge)
        Button(action: { showListMenu() }) {
            Color.clear.frame(width: 22, height: 18).contentShape(Rectangle())
        }.buttonStyle(.plain).focusable(false).position(x: windowWidth - 32, y: buttonY)
    }

    @ViewBuilder
    private func buildPlaylistTransportButtons() -> some View {
        // Transport buttons: In RIGHT section of bottom bar (150px from right edge)
        // Y position: 12px from bottom (windowHeight - 12)
        let transportY = windowHeight - 12
        // X offset: Center of RIGHT section is at (windowWidth - 75)
        // Transport buttons start ~8px into the RIGHT section from its center
        let rightSectionStart = windowWidth - 150
        let baseX = rightSectionStart + 8  // Start of transport buttons in RIGHT section

        Button(action: {
            Task { await playbackCoordinator.previous() }
        }) {
            Color.clear
                .frame(width: 10, height: 9)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: baseX, y: transportY)

        Button(action: {
            playbackCoordinator.togglePlayPause()
        }) {
            Color.clear
                .frame(width: 10, height: 9)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: baseX + 11, y: transportY)

        Button(action: {
            playbackCoordinator.pause()
        }) {
            Color.clear
                .frame(width: 10, height: 9)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: baseX + 22, y: transportY)

        Button(action: {
            playbackCoordinator.stop()
        }) {
            Color.clear
                .frame(width: 10, height: 9)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: baseX + 33, y: transportY)

        Button(action: {
            Task { await playbackCoordinator.next() }
        }) {
            Color.clear
                .frame(width: 10, height: 9)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: baseX + 44, y: transportY)

        Button(action: {
            openFileDialog()
        }) {
            Color.clear
                .frame(width: 10, height: 9)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: baseX + 50, y: transportY)
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
    private func buildTitleBarButtons() -> some View {
        // Title bar buttons: Positioned relative to right edge
        let buttonY: CGFloat = 7.5

        Button(action: { WindowCoordinator.shared?.minimizeKeyWindow() }) {
            SimpleSpriteImage("MAIN_MINIMIZE_BUTTON", width: 9, height: 9)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: windowWidth - 26.5, y: buttonY)

        Button(action: {
            isShadeMode.toggle()
        }) {
            SimpleSpriteImage("MAIN_SHADE_BUTTON", width: 9, height: 9)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: windowWidth - 16.5, y: buttonY)

        Button(action: { WindowCoordinator.shared?.hidePlaylistWindow() }) {
            SimpleSpriteImage("MAIN_CLOSE_BUTTON", width: 9, height: 9)
        }
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

    @ViewBuilder
    private func buildShadeMode() -> some View {
        ZStack {
            let suffix = isWindowActive ? "_SELECTED" : ""
            // Shade mode uses full window width titlebar (at 275 fixed width for sprite)
            SimpleSpriteImage("PLAYLIST_TITLE_BAR\(suffix)", width: 275, height: 14)
                .frame(width: windowWidth, height: 14)  // Scale to window width
                .position(x: windowWidth / 2, y: 7)

            if let currentTrack = playbackCoordinator.currentTrack {
                Text("\(currentTrack.title) - \(currentTrack.artist)")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: windowWidth - 75)  // Leave room for buttons
                    .position(x: (windowWidth - 75) / 2, y: 7)
            } else {
                Text("Winamp Playlist")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                    .position(x: (windowWidth - 75) / 2, y: 7)
            }

            buildTitleBarButtons()
        }
        .frame(width: windowWidth, height: 14)
    }

    private func trackTextColor(track: Track) -> Color {
        // Use coordinator's current track for highlighting
        if let currentTrack = playbackCoordinator.currentTrack, currentTrack.url == track.url {
            return playlistStyle.currentTextColor
        }
        return playlistStyle.normalTextColor
    }

    private func trackBackground(track: Track, index: Int) -> Color {
        // Only show background for selected tracks (not current track)
        if selectedIndices.contains(index) {
            return playlistStyle.selectedBackgroundColor.opacity(0.6)
        }
        return Color.clear
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func openFileDialog() {
        PlaylistWindowActions.shared.presentAddFilesPanel(audioPlayer: audioPlayer, playbackCoordinator: playbackCoordinator)
    }

    
    private func removeSelectedTrack() {
        guard let index = selectedIndices.first,
              index < audioPlayer.playlist.count else { return }
        audioPlayer.playlist.remove(at: index)
        selectedIndices.remove(index)
    }

    // Menu positioning helper - get playlist window's contentView (not keyWindow)
    private func playlistContentView() -> NSView? {
        // Try to get actual playlist window from WindowCoordinator
        if let view = WindowCoordinator.shared?.playlistWindow?.contentView {
            return view
        }
        // Fallback for previews/tooling
        return NSApp.keyWindow?.contentView
    }

    // Present menu at correct position relative to playlist window
    private func presentPlaylistMenu(_ menu: NSMenu, at point: NSPoint) {
        guard let contentView = playlistContentView() else { return }
        menu.popUp(positioning: nil, at: point, in: contentView)
    }

    private func showAddMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = menuDelegate  // Enable keyboard navigation

        let addURLItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_ADD_URL",
            selectedSprite: "PLAYLIST_ADD_URL_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.addURL),
            target: PlaylistWindowActions.shared
        )
        addURLItem.representedObject = audioPlayer
        menu.addItem(addURLItem)

        let addDirItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_ADD_DIR",
            selectedSprite: "PLAYLIST_ADD_DIR_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.addDirectory),
            target: PlaylistWindowActions.shared
        )
        addDirItem.representedObject = audioPlayer
        menu.addItem(addDirItem)

        let addFileItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_ADD_FILE",
            selectedSprite: "PLAYLIST_ADD_FILE_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.addFile),
            target: PlaylistWindowActions.shared
        )
        addFileItem.representedObject = audioPlayer
        menu.addItem(addFileItem)

        // Use playlist-specific positioning (not keyWindow)
        // NSPoint uses bottom-left origin, so y = windowHeight - distanceFromTop
        presentPlaylistMenu(menu, at: NSPoint(x: 12, y: windowHeight - 68))
    }

    private func showRemMenu() {
        PlaylistWindowActions.shared.selectedIndices = selectedIndices

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = menuDelegate  // Enable keyboard navigation

        let remMiscItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_REMOVE_MISC",
            selectedSprite: "PLAYLIST_REMOVE_MISC_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.removeMisc),
            target: PlaylistWindowActions.shared
        )
        remMiscItem.representedObject = audioPlayer
        menu.addItem(remMiscItem)

        let remAllItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_REMOVE_ALL",
            selectedSprite: "PLAYLIST_REMOVE_ALL_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.removeAll),
            target: PlaylistWindowActions.shared
        )
        remAllItem.representedObject = audioPlayer
        menu.addItem(remAllItem)

        let cropItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_CROP",
            selectedSprite: "PLAYLIST_CROP_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.cropPlaylist),
            target: PlaylistWindowActions.shared
        )
        cropItem.representedObject = audioPlayer
        menu.addItem(cropItem)

        let remSelItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_REMOVE_SELECTED",
            selectedSprite: "PLAYLIST_REMOVE_SELECTED_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.removeSelected),
            target: PlaylistWindowActions.shared
        )
        remSelItem.representedObject = audioPlayer
        menu.addItem(remSelItem)

        // Use playlist-specific positioning (not first window)
        // REM menu has 4 items, needs more space (87px from top)
        presentPlaylistMenu(menu, at: NSPoint(x: 41, y: windowHeight - 87))
    }

    private func showSelNotSupportedAlert() {
        let alert = NSAlert()
        alert.messageText = "Selection Menu"
        alert.informativeText = "Not supported yet. Use Shift+click for multi-select (planned feature)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showMiscMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = menuDelegate  // Enable keyboard navigation

        let sortItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_SORT_LIST",
            selectedSprite: "PLAYLIST_SORT_LIST_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.sortList),
            target: PlaylistWindowActions.shared
        )
        sortItem.representedObject = audioPlayer
        menu.addItem(sortItem)

        let fileInfoItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_FILE_INFO",
            selectedSprite: "PLAYLIST_FILE_INFO_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.fileInfo),
            target: PlaylistWindowActions.shared
        )
        fileInfoItem.representedObject = audioPlayer
        menu.addItem(fileInfoItem)

        let miscOptionsItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_MISC_OPTIONS",
            selectedSprite: "PLAYLIST_MISC_OPTIONS_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.miscOptions),
            target: PlaylistWindowActions.shared
        )
        miscOptionsItem.representedObject = audioPlayer
        menu.addItem(miscOptionsItem)

        // Use playlist-specific positioning (not first window)
        presentPlaylistMenu(menu, at: NSPoint(x: 100, y: windowHeight - 68))
    }

    private func showListMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = menuDelegate  // Enable keyboard navigation

        let newListItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_NEW_LIST",
            selectedSprite: "PLAYLIST_NEW_LIST_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.newList),
            target: PlaylistWindowActions.shared
        )
        newListItem.representedObject = audioPlayer
        menu.addItem(newListItem)

        let saveListItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_SAVE_LIST",
            selectedSprite: "PLAYLIST_SAVE_LIST_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.saveList),
            target: PlaylistWindowActions.shared
        )
        saveListItem.representedObject = audioPlayer
        menu.addItem(saveListItem)

        let loadListItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_LOAD_LIST",
            selectedSprite: "PLAYLIST_LOAD_LIST_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.loadList),
            target: PlaylistWindowActions.shared
        )
        loadListItem.representedObject = audioPlayer
        menu.addItem(loadListItem)

        // Use playlist-specific positioning (not first window)
        // X position relative to right edge for LIST menu
        presentPlaylistMenu(menu, at: NSPoint(x: windowWidth - 46, y: windowHeight - 68))
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
