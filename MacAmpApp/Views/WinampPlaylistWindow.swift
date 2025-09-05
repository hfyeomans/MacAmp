import SwiftUI
import AppKit

/// Pixel-perfect recreation of Winamp's playlist window using absolute positioning
struct WinampPlaylistWindow: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    @State private var selectedTrackIndex: Int? = nil
    
    // Winamp playlist coordinate constants (from Webamp CSS)
    private struct PLCoords {
        // Window sections (webamp layout)
        static let topHeight: CGFloat = 20        // .playlist-top min/max-height: 20px
        static let bottomHeight: CGFloat = 38     // .playlist-bottom height: 38px
        static let leftBorderWidth: CGFloat = 12  // .playlist-middle-left width: 12px
        static let rightScrollWidth: CGFloat = 20 // .playlist-middle-right width: 20px

        // Track area (calculated from window sections)
        static let trackAreaX: CGFloat = leftBorderWidth
        static let trackAreaY: CGFloat = topHeight + 3 // .playlist-middle-center padding: 3px 0
        static let trackAreaWidth: CGFloat = WinampSizes.playlistBase.width - leftBorderWidth - rightScrollWidth
        // Height is computed as (total - top - bottom) minus 3px top + 3px bottom padding

        // Titlebar buttons (same as other windows)
        static let minimizeButton = CGPoint(x: 244, y: 3)
        static let shadeButton = CGPoint(x: 254, y: 3)
        static let closeButton = CGPoint(x: 264, y: 3)
        
        // Bottom control buttons (CORRECTED from webamp)
        static let bottomY: CGFloat = WinampSizes.playlistBase.height - bottomHeight + 12 // bottom:12px
        
        // Left side buttons
        static let addButton = CGPoint(x: 14, y: bottomY)
        static let removeButton = CGPoint(x: 43, y: bottomY)  
        static let selectionButton = CGPoint(x: 72, y: bottomY)
        static let miscButton = CGPoint(x: 101, y: bottomY)
        
        // Right side elements
        static let listButton = CGPoint(x: WinampSizes.playlistBase.width - 22 - 22, y: bottomY)
        
        // Track specifications (EXACT webamp specs)
        static let trackHeight: CGFloat = 13     // .track-cell height/line-height: 13px
        static let fontSize: CGFloat = 9         // font-size: 9px
        static let letterSpacing: CGFloat = 0.5  // letter-spacing: 0.5px
        static let durationRightPadding: CGFloat = 3 // playlist-track-durations > div { padding-right: 3px }
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background chrome using PLEDIT sprites
            buildPlaylistChrome()
            
            // Main playlist content area
            buildPlaylistContent()
            
            // Titlebar buttons
            buildTitlebarButtons()
            
            // Bottom control buttons
            buildControlButtons()
            
            // Scrollbar (simplified for now)
            buildScrollbar()
        }
        .frame(width: WinampSizes.playlistBase.width, height: WinampSizes.playlistBase.height)
        .background(Color.black) // Fallback
    }
    
    @ViewBuilder
    private func buildPlaylistChrome() -> some View {
        // CORRECTED: Proper PLEDIT chrome structure from webamp
        Group {
            // Top section (CORRECTED tiling)
            SimpleSpriteImage("PLAYLIST_TOP_LEFT_CORNER", width: 25, height: 20)
                .at(x: 0, y: 0)
            
            // Title bar fill (100px sections)
            SimpleSpriteImage("PLAYLIST_TITLE_BAR", width: 100, height: 20)
                .at(x: 25, y: 0)
            
            SimpleSpriteImage("PLAYLIST_TITLE_BAR", width: 100, height: 20)
                .at(x: 125, y: 0)
            
            SimpleSpriteImage("PLAYLIST_TOP_RIGHT_CORNER", width: 25, height: 20)
                .at(x: 250, y: 0)
            
            // Left border tiles (CORRECTED count and positioning)
            let sideHeight = WinampSizes.playlistBase.height - PLCoords.topHeight - PLCoords.bottomHeight
            let tileCount = Int(sideHeight / 29) + 1
            
            ForEach(0..<tileCount, id: \.self) { index in
                SimpleSpriteImage("PLAYLIST_LEFT_TILE", width: 12, height: 29)
                    .at(x: 0, y: PLCoords.topHeight + CGFloat(index) * 29)
            }
            
            // Right border tiles (CORRECTED)  
            ForEach(0..<tileCount, id: \.self) { index in
                SimpleSpriteImage("PLAYLIST_RIGHT_TILE", width: 20, height: 29)
                    .at(x: WinampSizes.playlistBase.width - 20, y: PLCoords.topHeight + CGFloat(index) * 29)
            }
            
            // Bottom corners (CORRECTED positioning)
            let bottomY = WinampSizes.playlistBase.height - PLCoords.bottomHeight
            SimpleSpriteImage("PLAYLIST_BOTTOM_LEFT_CORNER", width: 125, height: 38)
                .at(x: 0, y: bottomY)
            
            SimpleSpriteImage("PLAYLIST_BOTTOM_RIGHT_CORNER", width: 150, height: 38)
                .at(x: 125, y: bottomY)
        }
    }
    
    @ViewBuilder
    private func buildPlaylistContent() -> some View {
        // Track list area with EXACT webamp styling
        // Center area height minus 3px top + 3px bottom padding (matches Webamp CSS)
        let contentHeight = WinampSizes.playlistBase.height - PLCoords.topHeight - PLCoords.bottomHeight - 6
        
        // Black background for track area (like Winamp)
        Rectangle()
            .fill(Color.black)
            .frame(width: PLCoords.trackAreaWidth, height: contentHeight)
            .at(x: PLCoords.trackAreaX, y: PLCoords.trackAreaY)
        
        // Track list with proper scrolling
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(audioPlayer.playlist.enumerated()), id: \.element.id) { index, track in
                    playlistRow(track: track, index: index)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            audioPlayer.playTrack(track: track)
                            selectedTrackIndex = index
                        }
                        .background(trackBackgroundColor(track: track, index: index))
                }
                
                // Add some tracks for testing if playlist is empty
                if audioPlayer.playlist.isEmpty {
                    ForEach(1..<15, id: \.self) { index in
                        HStack(spacing: 1) {
                            Text("\(index).")
                                .font(.system(size: PLCoords.fontSize, design: .monospaced))
                                .foregroundColor(.green)
                                .frame(width: 18, alignment: .trailing)
                            
                            Text("Sample Track \(index) - Artist Name")
                                .font(.system(size: PLCoords.fontSize))
                                .kerning(PLCoords.letterSpacing)
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                            
                            Text("\(index % 3 + 2):0\(index % 5 + 1)")
                                .font(.system(size: PLCoords.fontSize, design: .monospaced))
                                .foregroundColor(.green)
                                .frame(width: 30, alignment: .trailing)
                        }
                        .padding(.horizontal, 1)
                        .frame(height: PLCoords.trackHeight)
                        .background(index == 3 ? Color.blue.opacity(0.8) : Color.clear) // Highlight one track
                    }
                }
            }
        }
        .frame(width: PLCoords.trackAreaWidth, height: contentHeight)
        .at(x: PLCoords.trackAreaX, y: PLCoords.trackAreaY)
        .clipped()
    }
    
    @ViewBuilder
    private func playlistRow(track: Track, index: Int) -> some View {
        HStack(spacing: 1) {
            // Track number (EXACT webamp styling)  
            Text("\(index + 1).")
                .font(.system(size: PLCoords.fontSize, design: .monospaced))
                .foregroundColor(trackTextColor(track: track))
                .frame(width: 18, alignment: .trailing)
            
            // Track info (EXACT webamp styling with letter spacing effect)
            Text("\(track.title) - \(track.artist)")
                .font(.system(size: PLCoords.fontSize))
                .kerning(PLCoords.letterSpacing) // SwiftUI letter spacing
                .foregroundColor(trackTextColor(track: track))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            
            // Duration (EXACT webamp styling)
            Text(formatDuration(track.duration))
                .font(.system(size: PLCoords.fontSize, design: .monospaced))
                .foregroundColor(trackTextColor(track: track))
                .frame(width: 30, alignment: .trailing)
                .padding(.trailing, PLCoords.durationRightPadding)
        }
        .padding(.horizontal, 1) // Minimal padding like webamp
        .frame(height: PLCoords.trackHeight) // EXACT 13px height
    }
    
    @ViewBuilder
    private func buildTitlebarButtons() -> some View {
        Group {
            // Minimize button
            Button(action: {
                NSApp.keyWindow?.miniaturize(nil)
            }) {
                SimpleSpriteImage("MAIN_MINIMIZE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .at(PLCoords.minimizeButton)
            
            // Shade button
            Button(action: {
                // TODO: Implement playlist shade mode
            }) {
                SimpleSpriteImage("MAIN_SHADE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .at(PLCoords.shadeButton)
            
            // Close button
            Button(action: {
                NSApp.keyWindow?.close()
            }) {
                SimpleSpriteImage("MAIN_CLOSE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .at(PLCoords.closeButton)
        }
    }
    
    @ViewBuilder
    private func buildControlButtons() -> some View {
        Group {
            // Add button
            Button(action: { openFileDialog() }) {
                SimpleSpriteImage("PLAYLIST_ADD_FILE", width: 22, height: 18)
            }
            .buttonStyle(.plain)
            .at(PLCoords.addButton)
            
            // Remove button  
            Button(action: { removeSelectedTrack() }) {
                SimpleSpriteImage("PLAYLIST_REMOVE_SELECTED", width: 22, height: 18)
            }
            .buttonStyle(.plain)
            .at(PLCoords.removeButton)
            
            // Selection button
            Button(action: { /* TODO: Selection menu */ }) {
                SimpleSpriteImage("PLAYLIST_CROP", width: 22, height: 18)
            }
            .buttonStyle(.plain)
            .at(PLCoords.selectionButton)
            
            // Misc button
            Button(action: { /* TODO: Misc menu */ }) {
                SimpleSpriteImage("PLAYLIST_MISC_OPTIONS", width: 22, height: 18)
            }
            .buttonStyle(.plain)
            .at(PLCoords.miscButton)
            
            // List button (right side)
            Button(action: { /* TODO: List menu */ }) {
                SimpleSpriteImage("PLAYLIST_SORT_LIST", width: 22, height: 18)
            }
            .buttonStyle(.plain)
            .at(PLCoords.listButton)
        }
    }
    
    @ViewBuilder
    private func buildScrollbar() -> some View {
        // Scrollbar area (EXACT Webamp dimensions and positioning)
        let scrollAreaX = WinampSizes.playlistBase.width - PLCoords.rightScrollWidth // 20px gutter
        let scrollAreaY = PLCoords.topHeight                                        // starts below top (20px)
        let scrollAreaHeight = WinampSizes.playlistBase.height - PLCoords.topHeight - PLCoords.bottomHeight // total - 58
        
        // Scrollbar background (integrated with right chrome)
        // This area is handled by the PLAYLIST_RIGHT_TILE sprites
        
        // Scroll handle (Webamp: margin-left 5, width 8, height 18; slider height = total - 58)
        // For now, render at the top of the gutter (no scroll position state yet)
        SimpleSpriteImage("PLAYLIST_SCROLL_HANDLE", width: 8, height: 18)
            .at(x: scrollAreaX + 5, y: scrollAreaY)
    }
    
    // MARK: - Helper Functions
    
    private func trackTextColor(track: Track) -> Color {
        if let currentTrack = audioPlayer.currentTrack, currentTrack.id == track.id {
            // Current track: WHITE (#FFFFFF) like webamp  
            return Color.white
        }
        // Normal track: BRIGHT GREEN (#00FF00) like webamp default
        return Color(red: 0.0, green: 1.0, blue: 0.0)
    }
    
    private func trackBackgroundColor(track: Track, index: Int) -> Color {
        if let currentTrack = audioPlayer.currentTrack, currentTrack.id == track.id {
            // Current track background: BLUE (#0000C6) like webamp
            return Color(red: 0.0, green: 0.0, blue: 0.776)
        }
        if selectedTrackIndex == index {
            // Selected (but not current): lighter blue
            return Color.blue.opacity(0.4)
        }
        // Normal background: TRANSPARENT over black
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
                    audioPlayer.loadTrack(url: url)
                }
            }
        }
    }
    
    private func removeSelectedTrack() {
        guard let index = selectedTrackIndex,
              index < audioPlayer.playlist.count else { return }
        
        // TODO: Remove track from playlist
        selectedTrackIndex = nil
    }
    
    private func removeAllTracks() {
        // TODO: Clear playlist
        selectedTrackIndex = nil
    }
}

#Preview {
    WinampPlaylistWindow()
        .environmentObject(SkinManager())
        .environmentObject(AudioPlayer())
}
