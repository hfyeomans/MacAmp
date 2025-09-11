import SwiftUI
import AppKit

/// Pixel-perfect recreation of Winamp's main window using absolute positioning
struct WinampMainWindow: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var dockingController: DockingController
    @Environment(\.openWindow) var openWindow
    
    @State private var isShadeMode: Bool = false
    @State private var showRemainingTime: Bool = false
    @State private var isScrubbing: Bool = false
    @State private var wasPlayingPreScrub: Bool = false
    @State private var scrubbingProgress: Double = 0.0
    
    // Track info scrolling state
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollTimer: Timer?
    
    // Winamp coordinate constants (from original Winamp and webamp)
    private struct Coords {
        // Transport buttons (all at y: 88)
        static let prevButton = CGPoint(x: 16, y: 88)
        static let playButton = CGPoint(x: 39, y: 88)
        static let pauseButton = CGPoint(x: 62, y: 88)
        static let stopButton = CGPoint(x: 85, y: 88)
        static let nextButton = CGPoint(x: 108, y: 88)
        static let ejectButton = CGPoint(x: 136, y: 89) // Slightly different
        
        // Time display
        static let timeDisplay = CGPoint(x: 39, y: 26)
        
        // Play/Pause indicator
        static let playPauseIndicator = CGPoint(x: 24, y: 28)
        
        // Track info display area (scrolling text)
        static let trackInfo = CGRect(x: 111, y: 27, width: 152, height: 11)
        
        // Spectrum analyzer (visualizer)
        static let spectrumAnalyzer = CGPoint(x: 24, y: 43)
        
        // Volume and Balance
        static let volumeSlider = CGPoint(x: 107, y: 57)
        static let balanceSlider = CGPoint(x: 177, y: 57)
        
        // Position slider
        static let positionSlider = CGPoint(x: 16, y: 72)
        
        // EQ/Playlist buttons
        static let eqButton = CGPoint(x: 219, y: 58)
        static let playlistButton = CGPoint(x: 242, y: 58)
        
        // Titlebar buttons (at top)
        static let minimizeButton = CGPoint(x: 244, y: 3)
        static let shadeButton = CGPoint(x: 254, y: 3)
        static let closeButton = CGPoint(x: 264, y: 3)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", 
                            width: WinampSizes.main.width, 
                            height: WinampSizes.main.height)
            
            // Title bar with "Winamp" text (overlays on background)
            SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED",
                            width: 275,
                            height: 14)
                .at(CGPoint(x: 0, y: 0))
            
            if !isShadeMode {
                // Full window mode
                buildFullWindow()
            } else {
                // Shade mode (collapsed to titlebar only)
                buildShadeMode()
            }
        }
        .frame(width: WinampSizes.main.width, 
               height: isShadeMode ? WinampSizes.mainShade.height : WinampSizes.main.height)
        .background(Color.black) // Fallback
        .onDisappear {
            scrollTimer?.invalidate()
            scrollTimer = nil
        }
    }
    
    @ViewBuilder
    private func buildFullWindow() -> some View {
        Group {
            // Titlebar buttons
            buildTitlebarButtons()
            
            // Play/Pause indicator
            buildPlayPauseIndicator()
            
            // Time display
            buildTimeDisplay()
            
            // Track info display
            buildTrackInfoDisplay()
            
            // Spectrum analyzer (visualizer)
            buildSpectrumAnalyzer()
            
            // Transport buttons
            buildTransportButtons()
            
            // Position slider
            buildPositionSlider()
            
            // Volume slider
            buildVolumeSlider()
            
            // Balance slider  
            buildBalanceSlider()
            
            // EQ/Playlist buttons
            buildWindowToggleButtons()
            
            // Additional Winamp elements (simplified)
            buildMonoStereoIndicator()
        }
    }
    
    @ViewBuilder
    private func buildShadeMode() -> some View {
        // In shade mode, only show essential controls in compact form
        buildTitlebarButtons()
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
            .at(Coords.minimizeButton)
            
            // Shade button
            Button(action: {
                isShadeMode.toggle()
            }) {
                SimpleSpriteImage("MAIN_SHADE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .at(Coords.shadeButton)
            
            // Close button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                SimpleSpriteImage("MAIN_CLOSE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .at(Coords.closeButton)
        }
    }
    
    @ViewBuilder
    private func buildPlayPauseIndicator() -> some View {
        let spriteKey = audioPlayer.isPlaying ? "MAIN_PLAYING_INDICATOR" : 
                       "MAIN_STOPPED_INDICATOR"
        
        SimpleSpriteImage(spriteKey, width: 9, height: 9)
            .at(Coords.playPauseIndicator)
    }
    
    @ViewBuilder
    private func buildTimeDisplay() -> some View {
        HStack(spacing: 0) {
            // Show minus sign for remaining time
            if showRemainingTime {
                SimpleSpriteImage("MINUS_SIGN", width: 5, height: 1)
                    .padding(.top, 6) // Align with digit baseline
            }
            
            // Time digits (MM:SS format)
            let timeToShow = showRemainingTime ? 
                max(0.0, audioPlayer.currentDuration - audioPlayer.currentTime) :
                audioPlayer.currentTime
            
            let digits = timeDigits(from: timeToShow)
            
            ForEach(0..<digits.count, id: \.self) { index in
                SimpleSpriteImage("DIGIT_\(digits[index])", width: 9, height: 13)
                
                // Add colon after minutes (background has colon, but we position digits around it)
                if index == 1 {
                    Spacer().frame(width: 3) // Space for colon in background
                }
            }
        }
        .at(Coords.timeDisplay)
        .contentShape(Rectangle())
        .onTapGesture {
            showRemainingTime.toggle()
        }
    }
    
    @ViewBuilder
    private func buildTransportButtons() -> some View {
        Group {
            // Previous
            Button(action: { audioPlayer.previousTrack() }) {
                SimpleSpriteImage("MAIN_PREVIOUS_BUTTON", width: 23, height: 18)
            }
            .buttonStyle(.plain)
            .at(Coords.prevButton)
            
            // Play
            Button(action: { audioPlayer.play() }) {
                SimpleSpriteImage("MAIN_PLAY_BUTTON", width: 23, height: 18)
            }
            .buttonStyle(.plain)
            .at(Coords.playButton)
            
            // Pause
            Button(action: { audioPlayer.pause() }) {
                SimpleSpriteImage("MAIN_PAUSE_BUTTON", width: 23, height: 18)
            }
            .buttonStyle(.plain)
            .at(Coords.pauseButton)
            
            // Stop
            Button(action: { audioPlayer.stop() }) {
                SimpleSpriteImage("MAIN_STOP_BUTTON", width: 23, height: 18)
            }
            .buttonStyle(.plain)
            .at(Coords.stopButton)
            
            // Next
            Button(action: { audioPlayer.nextTrack() }) {
                SimpleSpriteImage("MAIN_NEXT_BUTTON", width: 23, height: 18)
            }
            .buttonStyle(.plain)
            .at(Coords.nextButton)
            
            // Eject (handles file loading like original Winamp)
            Button(action: { 
                openFileDialog() // File loading integrated into eject button
            }) {
                SimpleSpriteImage("MAIN_EJECT_BUTTON", width: 22, height: 16)
            }
            .buttonStyle(.plain)
            .at(Coords.ejectButton)
        }
    }
    
    @ViewBuilder
    private func buildPositionSlider() -> some View {
        // Position slider background
        SimpleSpriteImage("MAIN_POSITION_SLIDER_BACKGROUND", width: 248, height: 10)
            .at(Coords.positionSlider)
        
        // Interactive scrubbing area - positioned exactly over the slider
        Color.clear
            .frame(width: 248, height: 10)
            .contentShape(Rectangle())
            .at(Coords.positionSlider)
            .onTapGesture { location in
                // Simple click-to-seek without scrubbing
                let progress = min(1.0, max(0.0, Double(location.x / 248)))
                if audioPlayer.currentDuration > 0 {
                    let targetTime = progress * audioPlayer.currentDuration
                    audioPlayer.seek(to: targetTime, resume: audioPlayer.isPlaying)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .local)
                    .onChanged { value in
                        handlePositionScrub(value)
                    }
                    .onEnded { value in
                        handlePositionScrubEnd(value)
                    }
            )
        
        // Position slider thumb (moves based on playback progress or scrubbing)
        let currentProgress = isScrubbing ? scrubbingProgress : audioPlayer.playbackProgress
        SimpleSpriteImage("MAIN_POSITION_SLIDER_THUMB", width: 29, height: 10)
            .at(CGPoint(x: Coords.positionSlider.x + (248 - 29) * currentProgress,
                       y: Coords.positionSlider.y))
            .allowsHitTesting(false) // Thumb shouldn't block interaction
    }
    
    @ViewBuilder
    private func buildVolumeSlider() -> some View {
        WinampVolumeSlider(volume: $audioPlayer.volume)
            .at(Coords.volumeSlider)
    }
    
    @ViewBuilder
    private func buildBalanceSlider() -> some View {
        WinampBalanceSlider(balance: $audioPlayer.balance)
            .at(Coords.balanceSlider)
    }
    
    @ViewBuilder
    private func buildWindowToggleButtons() -> some View {
        Group {
            // EQ button
            Button(action: {
                dockingController.toggleEqualizer()
            }) {
                SimpleSpriteImage("MAIN_EQ_BUTTON", width: 23, height: 12)
            }
            .buttonStyle(.plain)
            .at(Coords.eqButton)
            
            // Playlist button
            Button(action: {
                dockingController.togglePlaylist()
            }) {
                SimpleSpriteImage("MAIN_PLAYLIST_BUTTON", width: 23, height: 12)
            }
            .buttonStyle(.plain)
            .at(Coords.playlistButton)
        }
    }
    
    @ViewBuilder
    private func buildTrackInfoDisplay() -> some View {
        // Track info scrolling text display
        let trackText = audioPlayer.currentTitle.isEmpty ? "MacAmp" : audioPlayer.currentTitle
        let textWidth = trackText.count * 5 // Approximate character width in Winamp font
        let displayWidth = Int(Coords.trackInfo.width)
        
        if textWidth > displayWidth {
            // Need to scroll for long text
            HStack(spacing: 0) {
                buildTextSprites(for: trackText)
                    .offset(x: scrollOffset)
                    .onAppear {
                        startScrolling()
                    }
                    .onChange(of: audioPlayer.currentTitle) { _ in
                        resetScrolling()
                    }
            }
            .frame(width: Coords.trackInfo.width, height: Coords.trackInfo.height)
            .clipped()
            .at(CGPoint(x: Coords.trackInfo.minX, y: Coords.trackInfo.minY))
        } else {
            // Static text for short names
            buildTextSprites(for: trackText)
                .frame(width: Coords.trackInfo.width, height: Coords.trackInfo.height, alignment: .leading)
                .at(CGPoint(x: Coords.trackInfo.minX, y: Coords.trackInfo.minY))
        }
    }
    
    @ViewBuilder
    private func buildTextSprites(for text: String) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(text.uppercased().enumerated()), id: \.offset) { index, character in
                // Convert character to proper sprite code
                // Winamp TEXT.BMP uses lowercase ASCII codes for letters
                let charCode: UInt8 = {
                    if let ascii = character.asciiValue {
                        if character.isLetter && character.isUppercase {
                            // Convert uppercase letters to lowercase ASCII codes
                            return ascii + 32
                        } else {
                            return ascii
                        }
                    }
                    return 32 // Default to space
                }()
                
                SimpleSpriteImage("CHARACTER_\(charCode)", width: 5, height: 6)
            }
        }
    }
    
    @ViewBuilder
    private func buildMonoStereoIndicator() -> some View {
        // Mono/Stereo indicator
        SimpleSpriteImage("MAIN_STEREO", width: 29, height: 12)
            .at(x: 212, y: 41)
    }
    
    @ViewBuilder
    private func buildSpectrumAnalyzer() -> some View {
        VisualizerView()
            .frame(width: 76, height: 16)
            .background(Color.black.opacity(0.5))
            .at(Coords.spectrumAnalyzer)
    }
    
    private func openFileDialog() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.audio]
        openPanel.allowsMultipleSelection = true  // Allow multiple files like Winamp
        openPanel.canChooseDirectories = false
        
        openPanel.begin { response in
            if response == .OK {
                for url in openPanel.urls {
                    audioPlayer.loadTrack(url: url)
                }
            }
        }
    }
    
    // MARK: - Scrolling Animation Functions
    
    private func startScrolling() {
        guard scrollTimer == nil else { return }
        
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            let trackText = audioPlayer.currentTitle.isEmpty ? "MacAmp" : audioPlayer.currentTitle
            let textWidth = CGFloat(trackText.count * 5)
            let displayWidth = Coords.trackInfo.width
            
            if textWidth > displayWidth {
                withAnimation(.linear(duration: 0.15)) {
                    scrollOffset -= 5 // Move left by one character width
                    
                    // Reset when we've scrolled past the end
                    if abs(scrollOffset) >= textWidth + 20 { // Add some padding
                        scrollOffset = displayWidth
                    }
                }
            }
        }
    }
    
    private func resetScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        scrollOffset = 0
        
        // Restart scrolling if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            startScrolling()
        }
    }
    
    // MARK: - Helper Functions
    
    private func timeDigits(from seconds: Double) -> [Int] {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        
        return [
            minutes / 10,  // First minute digit
            minutes % 10,  // Second minute digit  
            secs / 10,     // First second digit
            secs % 10      // Second second digit
        ]
    }
    
    private func handlePositionScrub(_ value: DragGesture.Value) {
        if !isScrubbing {
            isScrubbing = true
            wasPlayingPreScrub = audioPlayer.isPlaying
            // Pause during scrubbing to avoid audio conflicts
            if wasPlayingPreScrub {
                audioPlayer.pause()
            }
        }
        
        // Calculate progress based on location in the 248px wide slider
        let x = min(max(0, value.location.x), 248)
        let progress = Double(x / 248)
        
        // Only update visual position during scrubbing - don't seek audio yet
        scrubbingProgress = progress
    }
    
    private func handlePositionScrubEnd(_ value: DragGesture.Value) {
        // Calculate final position
        let x = min(max(0, value.location.x), 248)
        let progress = Double(x / 248)
        
        // Perform single audio seek at the end
        if audioPlayer.currentDuration > 0 {
            let targetTime = progress * audioPlayer.currentDuration
            audioPlayer.seek(to: targetTime, resume: wasPlayingPreScrub)
        }
        
        // End scrubbing mode - let playbackProgress take over
        isScrubbing = false
        // Don't reset scrubbingProgress - it will be ignored once isScrubbing is false
    }
}

#Preview {
    WinampMainWindow()
        .environmentObject(SkinManager())
        .environmentObject(AudioPlayer())
        .environmentObject(DockingController())
}