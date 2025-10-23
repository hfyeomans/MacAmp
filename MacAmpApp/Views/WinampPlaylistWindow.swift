import SwiftUI
import AppKit

/// Clean rebuild of Winamp's playlist window with pixel-perfect sprite positioning
struct WinampPlaylistWindow: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var settings: AppSettings

    @State private var selectedTrackIndex: Int? = nil
    @State private var isShadeMode: Bool = false

    // Window dimensions
    private let windowWidth: CGFloat = 275
    private let windowHeight: CGFloat = 232

    // MARK: - Time Display Computed Properties

    /// Total duration of all tracks in the playlist
    private var totalPlaylistDuration: Double {
        audioPlayer.playlist.reduce(0.0) { total, track in
            total + track.duration
        }
    }

    /// Remaining time in current track (always positive)
    private var remainingTime: Double {
        guard audioPlayer.currentDuration > 0 else { return 0 }
        return max(0, audioPlayer.currentDuration - audioPlayer.currentTime)
    }

    /// Format time as MM:SS
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Track time display text: "MM:SS / MM:SS" or just ":" when idle
    private var trackTimeText: String {
        guard audioPlayer.currentTrack != nil,
              audioPlayer.currentDuration > 0 else {
            return ":"  // Show only colon when idle
        }

        let current = formatTime(audioPlayer.currentTime)
        let total = formatTime(totalPlaylistDuration)
        return "\(current) / \(total)"
    }

    /// Remaining time display text: "-MM:SS" or empty when not playing
    private var remainingTimeText: String {
        guard audioPlayer.isPlaying,
              audioPlayer.currentTrack != nil,
              audioPlayer.currentDuration > 0 else {
            return ""  // Hidden when not playing
        }

        let remaining = formatTime(remainingTime)
        return "-\(remaining)"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if !isShadeMode {
                    // Full window mode
                    // CRITICAL: Build complete background first as a single layer
                    buildCompleteBackground()

                    // Then overlay interactive content
                    buildContentOverlay()
                } else {
                    // Shade mode
                    buildShadeMode()
                }
            }
            .frame(width: windowWidth, height: isShadeMode ? 14 : windowHeight)
        }
        .frame(width: windowWidth, height: isShadeMode ? 14 : windowHeight)
        // NO additional backgrounds - this was causing the offset issue
    }
    
    // MARK: - Complete Background Assembly
    @ViewBuilder
    private func buildCompleteBackground() -> some View {
        // Build the entire playlist chrome as a single background layer
        Group {
            // Top section (0, 0)
            SimpleSpriteImage("PLAYLIST_TOP_LEFT_CORNER", width: 25, height: 20)
                .position(x: 12.5, y: 10) // position uses center, so width/2, height/2
            
            // Top tiles - fill between corners
            ForEach(0..<10, id: \.self) { i in
                SimpleSpriteImage("PLAYLIST_TOP_TILE", width: 25, height: 20)
                    .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
            }
            
            // Title bar - Make ONLY this draggable using macOS 15's WindowDragGesture
            SimpleSpriteImage("PLAYLIST_TITLE_BAR", width: 100, height: 20)
                .position(x: 137.5, y: 10) // centered at 137.5
                .gesture(WindowDragGesture())
            
            SimpleSpriteImage("PLAYLIST_TOP_RIGHT_CORNER", width: 25, height: 20)
                .position(x: 262.5, y: 10) // 275 - 12.5
            
            // Left border tiles
            let sideHeight = 192 // 232 - 20 (top) - 38 (bottom) = 174, but we need overlap
            let leftTileCount = Int(ceil(CGFloat(sideHeight) / 29))
            ForEach(0..<leftTileCount, id: \.self) { i in
                SimpleSpriteImage("PLAYLIST_LEFT_TILE", width: 12, height: 29)
                    .position(x: 6, y: 20 + 14.5 + CGFloat(i) * 29)
            }
            
            // Right border tiles  
            ForEach(0..<leftTileCount, id: \.self) { i in
                SimpleSpriteImage("PLAYLIST_RIGHT_TILE", width: 20, height: 29)
                    .position(x: 265, y: 20 + 14.5 + CGFloat(i) * 29)
            }
            
            // Bottom section - Webamp 3-section layout
            // Left (125px) anchored to left:0, Right (150px) anchored to right:0
            ZStack(alignment: .topLeading) {
                // Left section background - anchored to left edge
                HStack(spacing: 0) {
                    SimpleSpriteImage("PLAYLIST_BOTTOM_LEFT_CORNER", width: 125, height: 38)
                    Spacer()  // Center spacer (flexible width)
                    SimpleSpriteImage("PLAYLIST_BOTTOM_RIGHT_CORNER", width: 150, height: 38)
                }
                .frame(height: 38)
                .position(x: windowWidth / 2, y: 213)
            }
            
            // Fill any gap in bottom with tiles if corners don't meet
            // This prevents the black gap issue
            if let skin = skinManager.currentSkin,
               let bottomTile = skin.images["PLAYLIST_BOTTOM_TILE"] {
                // Bottom tiles don't exist in default skin, but if they do, use them
                Image(nsImage: bottomTile)
                    .resizable()
                    .frame(width: 25, height: 38)
                    .position(x: 137.5, y: 213)
            }
        }
    }
    
    // MARK: - Content Overlay
    @ViewBuilder
    private func buildContentOverlay() -> some View {
        Group {
            // Track list area with black background
            Color.black
                .frame(width: 243, height: 174) // 275 - 12 - 20 = 243 width
                .position(x: 133.5, y: 107) // Center of content area: 12 + 243/2 = 133.5

            // Track list content
            buildTrackList()
                .frame(width: 243, height: 174)
                .position(x: 133.5, y: 107)
                .clipped()
            
            // Control buttons at bottom
            buildBottomControls()

            // Transport control buttons (play, pause, stop, next, prev)
            buildPlaylistTransportButtons()

            // Time displays (track time and remaining time)
            buildTimeDisplays()

            // Title bar buttons
            buildTitleBarButtons()
            
            // Scrollbar
            SimpleSpriteImage("PLAYLIST_SCROLL_HANDLE", width: 8, height: 18)
                .position(x: 260, y: 30) // In the right gutter
        }
    }
    
    // MARK: - Track List
    @ViewBuilder
    private func buildTrackList() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(audioPlayer.playlist.enumerated()), id: \.element.id) { index, track in
                    trackRow(track: track, index: index)
                        .frame(width: 243, height: 13)
                        .background(trackBackground(track: track, index: index))
                        .onTapGesture {
                            // Only play if it's a different track (avoid restarting same track)
                            if audioPlayer.currentTrack?.url != track.url {
                                audioPlayer.playTrack(track: track)
                            }
                            selectedTrackIndex = index
                        }
                }
            }
        }
    }
    
    @ViewBuilder
    private func trackRow(track: Track, index: Int) -> some View {
        HStack(spacing: 2) {
            Text("\(index + 1).")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(trackTextColor(track: track))
                .frame(width: 18, alignment: .trailing)
            
            Text("\(track.title) - \(track.artist)")
                .font(.system(size: 9))
                .kerning(0.5)
                .foregroundColor(trackTextColor(track: track))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            
            Text(formatDuration(track.duration))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(trackTextColor(track: track))
                .frame(width: 30, alignment: .trailing)
                .padding(.trailing, 3)
        }
        .padding(.horizontal, 2)
    }
    
    // MARK: - Bottom Button Click Targets
    @ViewBuilder
    private func buildBottomControls() -> some View {
        Group {
            // NOTE: The 4 menu button graphics (ADD, REM, SEL, MISC) are BAKED INTO
            // the PLAYLIST_BOTTOM_LEFT_CORNER sprite. These are just transparent click targets.

            // Add File button - transparent click target over baked-in button graphic
            Button(action: { openFileDialog() }) {
                Color.clear
                    .frame(width: 22, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 25, y: 206)

            // Remove Selected button
            Button(action: { removeSelectedTrack() }) {
                Color.clear
                    .frame(width: 22, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 54, y: 206)

            // Selection/Crop button
            Button(action: {}) {
                Color.clear
                    .frame(width: 22, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 83, y: 206)

            // Misc Options button
            Button(action: {}) {
                Color.clear
                    .frame(width: 22, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 112, y: 206)
        }
    }

    // MARK: - Transport Controls (Playback Buttons)
    @ViewBuilder
    private func buildPlaylistTransportButtons() -> some View {
        Group {
            // NOTE: Gold button icons are BAKED INTO the PLAYLIST_BOTTOM_RIGHT_CORNER sprite!
            // These are transparent click targets positioned over the visual icons in the background.

            // Previous button - transparent click target over gold icon in background
            // Corner at X:195 (left edge at 120), buttons at offsets 8, 19, 30, 41, 52, 63
            Button(action: {
                audioPlayer.previousTrack()
            }) {
                Color.clear
                    .frame(width: 10, height: 9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 133, y: 220)  // 120 + 8

            // Play button
            Button(action: {
                if audioPlayer.isPaused {
                    audioPlayer.play()
                } else if !audioPlayer.isPlaying {
                    audioPlayer.play()
                }
            }) {
                Color.clear
                    .frame(width: 10, height: 9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 144, y: 220)  // 125 + 19

            // Pause button
            Button(action: {
                audioPlayer.pause()
            }) {
                Color.clear
                    .frame(width: 10, height: 9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 155, y: 220)  // 125 + 30

            // Stop button
            Button(action: {
                audioPlayer.stop()
            }) {
                Color.clear
                    .frame(width: 10, height: 9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 166, y: 220)  // 125 + 41

            // Next button
            Button(action: {
                audioPlayer.nextTrack()
            }) {
                Color.clear
                    .frame(width: 10, height: 9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 177, y: 220)  // 125 + 52

            // Eject button
            Button(action: {
                openFileDialog()
            }) {
                Color.clear
                    .frame(width: 10, height: 9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 188, y: 220)  // 125 + 63
        }
    }

    // MARK: - Time Displays
    @ViewBuilder
    private func buildTimeDisplays() -> some View {
        Group {
            // Mini Time Display (MM:SS format) - positioned in info bar
            // Corner left edge at 120, webamp offset is left:66px from corner
            // Time position: 120 + 66 = 186
            Text(trackTimeText)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(Color(red: 0, green: 1.0, blue: 0))  // Green from PLEDIT.TXT (#00FF00)
                .position(x: 191, y: 217)

            // Remaining Time Display (-MM:SS format)
            // Positioned above mini-time
            if !remainingTimeText.isEmpty {
                Text(remainingTimeText)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0, green: 1.0, blue: 0))  // Green (#00FF00)
                    .position(x: 191, y: 205)
            }
        }
    }

    // MARK: - Title Bar Buttons
    @ViewBuilder
    private func buildTitleBarButtons() -> some View {
        Group {
            Button(action: { NSApp.keyWindow?.miniaturize(nil) }) {
                SimpleSpriteImage("MAIN_MINIMIZE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .position(x: 248.5, y: 7.5)
            
            Button(action: {
                isShadeMode.toggle()
            }) {
                SimpleSpriteImage("MAIN_SHADE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .position(x: 258.5, y: 7.5)
            
            Button(action: { NSApp.keyWindow?.close() }) {
                SimpleSpriteImage("MAIN_CLOSE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .position(x: 268.5, y: 7.5)
        }
    }

    // MARK: - Shade Mode
    @ViewBuilder
    private func buildShadeMode() -> some View {
        // Playlist shade mode shows compact title bar with current track info
        ZStack {
            // Use the playlist title bar sprite as background
            SimpleSpriteImage("PLAYLIST_TITLE_BAR", width: 275, height: 14)
                .position(x: 137.5, y: 7)

            // Show current track name in shade mode
            if let currentTrack = audioPlayer.currentTrack {
                Text("\(currentTrack.title) - \(currentTrack.artist)")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 200)
                    .position(x: 100, y: 7)
            } else {
                Text("Winamp Playlist")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                    .position(x: 100, y: 7)
            }

            // Titlebar buttons
            buildTitleBarButtons()
        }
        .frame(width: windowWidth, height: 14)
    }

    // MARK: - Helper Functions
    private func trackTextColor(track: Track) -> Color {
        // Use URL comparison for reliable track matching (IDs are UUID and may change)
        if let currentTrack = audioPlayer.currentTrack, currentTrack.url == track.url {
            return Color.white  // White text for currently playing track (PLEDIT.TXT)
        }
        return Color(red: 0.0, green: 1.0, blue: 0.0)  // Green text for normal tracks
    }

    private func trackBackground(track: Track, index: Int) -> Color {
        // Use URL comparison for reliable track matching (IDs are UUID and may change)
        if let currentTrack = audioPlayer.currentTrack, currentTrack.url == track.url {
            return Color(red: 0.0, green: 0.0, blue: 0.776)  // Blue background for playing (#0000C6)
        }
        if selectedTrackIndex == index {
            return Color.blue.opacity(0.4)  // Lighter blue for selection
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
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.audio]
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false

        openPanel.begin { response in
            if response == .OK {
                for url in openPanel.urls {
                    audioPlayer.addTrack(url: url)
                }
            }
        }
    }
    
    private func removeSelectedTrack() {
        guard let index = selectedTrackIndex,
              index < audioPlayer.playlist.count else { return }
        selectedTrackIndex = nil
    }
}

// Extension to use position instead of offset for sprites
extension SimpleSpriteImage {
    func position(x: CGFloat, y: CGFloat) -> some View {
        self.position(CGPoint(x: x, y: y))
    }
}

#Preview {
    WinampPlaylistWindow()
        .environmentObject(SkinManager())
        .environmentObject(AudioPlayer())
        .environmentObject(AppSettings.instance())
}