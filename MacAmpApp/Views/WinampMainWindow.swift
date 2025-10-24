import SwiftUI
import AppKit

/// Pixel-perfect recreation of Winamp's main window using absolute positioning
struct WinampMainWindow: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var dockingController: DockingController
    @Environment(\.openWindow) var openWindow

    // CRITICAL: Prevent unnecessary body re-evaluations that cause ghost images
    // SwiftUI re-evaluates body when ANY @EnvironmentObject publishes changes
    // This was causing 7+ evaluations before old views cleanup, creating visual doubles
    @State private var displayedTime: Int = 0  // Cache rounded time to reduce updates
    
    @State private var isShadeMode: Bool = false
    @State private var showRemainingTime: Bool = false
    @State private var isScrubbing: Bool = false
    @State private var wasPlayingPreScrub: Bool = false
    @State private var scrubbingProgress: Double = 0.0
    
    // Track info scrolling state
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollTimer: Timer?

    // Pause blinking state
    @State private var pauseBlinkVisible: Bool = true
    @State private var pauseBlinkTimer: Timer?
    @State private var isViewVisible: Bool = false

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
        
        // Shuffle/Repeat buttons (to the right of eject)
        static let shuffleButton = CGPoint(x: 164, y: 89)
        static let repeatButton = CGPoint(x: 211, y: 89)

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
            // Background (preprocessed to remove static digits, keeping ":")
            SimpleSpriteImage("MAIN_WINDOW_BACKGROUND",
                            width: WinampSizes.main.width,
                            height: WinampSizes.main.height)

            // Title bar with "Winamp" text (overlays on background)
            // Make ONLY the title bar draggable using macOS 15's WindowDragGesture
            SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED",
                            width: 275,
                            height: 14)
                .at(CGPoint(x: 0, y: 0))
                .gesture(WindowDragGesture())

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
        .onAppear {
            isViewVisible = true
        }
        .onChange(of: audioPlayer.isPaused) { _, isPaused in
            if isPaused {
                // Start blinking timer
                pauseBlinkTimer?.invalidate()
                pauseBlinkVisible = true
                pauseBlinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    pauseBlinkVisible.toggle()
                }
                if let timer = pauseBlinkTimer {
                    RunLoop.main.add(timer, forMode: .common)
                }
            } else {
                // Stop blinking timer
                pauseBlinkTimer?.invalidate()
                pauseBlinkTimer = nil
                pauseBlinkVisible = true
            }
        }
        .onDisappear {
            isViewVisible = false
            scrollTimer?.invalidate()
            scrollTimer = nil
            pauseBlinkTimer?.invalidate()
            pauseBlinkTimer = nil
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

            // Shuffle/Repeat buttons
            buildShuffleRepeatButtons()

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
            
            // Bitrate and sample rate display
            buildBitrateDisplay()
            buildSampleRateDisplay()
        }
    }
    
    @ViewBuilder
    private func buildShadeMode() -> some View {
        // Shade mode shows a compact 275×14px bar with essential controls
        ZStack {
            // Shade background
            SimpleSpriteImage("MAIN_SHADE_BACKGROUND", width: 275, height: 14)
                .at(CGPoint(x: 0, y: 0))

            // Transport controls (compact layout)
            HStack(spacing: 2) {
                // Previous
                Button(action: { audioPlayer.previousTrack() }) {
                    SimpleSpriteImage("MAIN_PREVIOUS_BUTTON", width: 23, height: 18)
                        .scaleEffect(0.6) // Scale down for shade mode
                }
                .buttonStyle(.plain)

                // Play
                Button(action: { audioPlayer.play() }) {
                    SimpleSpriteImage("MAIN_PLAY_BUTTON", width: 23, height: 18)
                        .scaleEffect(0.6)
                }
                .buttonStyle(.plain)

                // Pause
                Button(action: { audioPlayer.pause() }) {
                    SimpleSpriteImage("MAIN_PAUSE_BUTTON", width: 23, height: 18)
                        .scaleEffect(0.6)
                }
                .buttonStyle(.plain)

                // Stop
                Button(action: { audioPlayer.stop() }) {
                    SimpleSpriteImage("MAIN_STOP_BUTTON", width: 23, height: 18)
                        .scaleEffect(0.6)
                }
                .buttonStyle(.plain)

                // Next
                Button(action: { audioPlayer.nextTrack() }) {
                    SimpleSpriteImage("MAIN_NEXT_BUTTON", width: 22, height: 18)
                        .scaleEffect(0.6)
                }
                .buttonStyle(.plain)
            }
            .at(CGPoint(x: 45, y: 3))

            // Time display (compact)
            buildTimeDisplay()
                .scaleEffect(0.7)
                .at(CGPoint(x: 150, y: 7))

            // Titlebar buttons (keep same position)
            buildTitlebarButtons()
        }
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
    
    private func buildPlayPauseIndicator() -> some View {
        let spriteKey: String
        if audioPlayer.isPlaying {
            spriteKey = "MAIN_PLAYING_INDICATOR"
        } else if audioPlayer.isPaused {
            spriteKey = "MAIN_PAUSED_INDICATOR"
        } else {
            spriteKey = "MAIN_STOPPED_INDICATOR"
        }

        return SimpleSpriteImage(spriteKey, width: 9, height: 9)
            .at(Coords.playPauseIndicator)
    }
    
    @ViewBuilder
    private func buildTimeDisplay() -> some View {
        ZStack(alignment: .leading) {
            // MASK: Black out ONLY digit positions (not colon)
            // Internet Archive has "00:00" in MAIN.BMP, we need to hide those static digits
            // But keep the ":" from the background (it's static by design)

            // Minutes mask: covers x:6 to x:26 (both minute digits with gap)
            Color.black
                .frame(width: 21, height: 13)
                .offset(x: 6, y: 0)

            // Colon gap: x:27 to x:33 is LEFT UNTOUCHED for background ":"

            // Seconds mask: covers x:34 to x:55 (both second digits with gap)
            Color.black
                .frame(width: 21, height: 13)
                .offset(x: 34, y: 0)

            // Show minus sign for remaining time (position 1)
            if showRemainingTime {
                SimpleSpriteImage(.minusSign, width: 5, height: 1)
                    .offset(x: 1, y: 6)
            }

            // Time digits (MM:SS format) with absolute positioning
            let timeToShow = showRemainingTime ?
                max(0.0, audioPlayer.currentDuration - audioPlayer.currentTime) :
                audioPlayer.currentTime

            let digits = timeDigits(from: timeToShow)

            // Position each digit with proper Winamp spacing
            // Only hide digits when paused and blink is off, colon always visible
            let shouldShowDigits = !audioPlayer.isPaused || pauseBlinkVisible

            // Minutes (with 2px gap between digits)
            if shouldShowDigits {
                SimpleSpriteImage(.digit(digits[0]), width: 9, height: 13)
                    .offset(x: 6, y: 0)

                SimpleSpriteImage(.digit(digits[1]), width: 9, height: 13)
                    .offset(x: 17, y: 0)
            }

            // NOTE: Colon comes from MAIN.BMP background - NOT rendered here!
            // All Winamp skins have ":" baked into MAIN.BMP at this position
            // It's static (doesn't blink) by original Winamp design

            // Seconds (with 2px gap between digits)
            if shouldShowDigits {
                SimpleSpriteImage(.digit(digits[2]), width: 9, height: 13)
                    .offset(x: 35, y: 0)

                SimpleSpriteImage(.digit(digits[3]), width: 9, height: 13)
                    .offset(x: 46, y: 0)
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
    private func buildShuffleRepeatButtons() -> some View {
        Group {
            // Shuffle button
            Button(action: {
                audioPlayer.shuffleEnabled.toggle()
            }) {
                let spriteKey = audioPlayer.shuffleEnabled ? "MAIN_SHUFFLE_BUTTON_SELECTED" : "MAIN_SHUFFLE_BUTTON"
                SimpleSpriteImage(spriteKey, width: 47, height: 15)
            }
            .buttonStyle(.plain)
            .at(Coords.shuffleButton)

            // Repeat button
            Button(action: {
                audioPlayer.repeatEnabled.toggle()
            }) {
                let spriteKey = audioPlayer.repeatEnabled ? "MAIN_REPEAT_BUTTON_SELECTED" : "MAIN_REPEAT_BUTTON"
                SimpleSpriteImage(spriteKey, width: 28, height: 15)
            }
            .buttonStyle(.plain)
            .at(Coords.repeatButton)
        }
    }

    @ViewBuilder
    private func buildPositionSlider() -> some View {
        // Only show position slider when a track is loaded
        if audioPlayer.currentTrack != nil {
            ZStack(alignment: .topLeading) {
                // Position slider background
                SimpleSpriteImage("MAIN_POSITION_SLIDER_BACKGROUND", width: 248, height: 10)
                    .at(Coords.positionSlider)

                // Position slider thumb (moves based on playback progress or scrubbing)
                let currentProgress = isScrubbing ? scrubbingProgress : audioPlayer.playbackProgress
                SimpleSpriteImage("MAIN_POSITION_SLIDER_THUMB", width: 29, height: 10)
                    .at(CGPoint(x: Coords.positionSlider.x + (248 - 29) * currentProgress,
                               y: Coords.positionSlider.y))
                    .allowsHitTesting(false) // Thumb shouldn't block interaction

                // Interactive scrubbing area using GeometryReader (like volume slider)
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handlePositionDrag(value, in: geo)
                                }
                                .onEnded { value in
                                    handlePositionDragEnd(value, in: geo)
                                }
                        )
                }
                .frame(width: 248, height: 10)
                .at(Coords.positionSlider)
            }
        }
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
                    .offset(x: scrollOffset, y: -2)  // Move UP to center: 6px text in 11px area
                    .onAppear {
                        startScrolling()
                    }
                    .onChange(of: audioPlayer.currentTitle) { _, _ in
                        resetScrolling()
                    }
            }
            .frame(width: Coords.trackInfo.width, height: Coords.trackInfo.height)
            .clipped()
            .at(CGPoint(x: Coords.trackInfo.minX, y: Coords.trackInfo.minY))
        } else {
            // Static text for short names
            buildTextSprites(for: trackText)
                .offset(y: -2)  // Move UP to center: 6px text in 11px area
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
        // Mono/Stereo indicator - shows the appropriate indicator based on channel count
        ZStack {
            // Only show indicators when a track is loaded
            let hasTrack = audioPlayer.currentTrack != nil
            
            // Show mono indicator first (at x: 212)
            SimpleSpriteImage(hasTrack && audioPlayer.channelCount == 1 ? "MAIN_MONO_SELECTED" : "MAIN_MONO",
                            width: 27, height: 12)
                .at(x: 212, y: 41)
            
            // Show stereo indicator second (at x: 239)
            SimpleSpriteImage(hasTrack && audioPlayer.channelCount == 2 ? "MAIN_STEREO_SELECTED" : "MAIN_STEREO", 
                            width: 29, height: 12)
                .at(x: 239, y: 41)
        }
    }
    
    @ViewBuilder
    private func buildBitrateDisplay() -> some View {
        // Only show when a track is loaded
        if audioPlayer.currentTrack != nil && audioPlayer.bitrate > 0 {
            let bitrateText = "\(audioPlayer.bitrate)"
            HStack(spacing: 0) {
                ForEach(Array(bitrateText.enumerated()), id: \.offset) { _, character in
                    if let ascii = character.asciiValue {
                        SimpleSpriteImage("CHARACTER_\(ascii)", width: 5, height: 6)
                    }
                }
            }
            .at(x: 111, y: 43)  // Position near the visualizer area
        }
    }
    
    @ViewBuilder
    private func buildSampleRateDisplay() -> some View {
        // Only show when a track is loaded
        if audioPlayer.currentTrack != nil && audioPlayer.sampleRate > 0 {
            let khz = audioPlayer.sampleRate / 1000
            let sampleRateText = "\(khz)"
            HStack(spacing: 0) {
                ForEach(Array(sampleRateText.enumerated()), id: \.offset) { _, character in
                    if let ascii = character.asciiValue {
                        SimpleSpriteImage("CHARACTER_\(ascii)", width: 5, height: 6)
                    }
                }
            }
            .at(x: 156, y: 43)  // Position to the right of bitrate
        }
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
                    audioPlayer.addTrack(url: url)
                }
            }
        }
    }
    
    // MARK: - Scrolling Animation Functions
    
    private func startScrolling() {
        guard scrollTimer == nil else { return }
        guard isViewVisible else { return }

        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak audioPlayer] _ in
            // Access main actor properties synchronously to prevent race conditions
            // The timer already fires on the main thread, so we can use assumeIsolated
            guard let audioPlayer = audioPlayer else { return }

            MainActor.assumeIsolated {
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
        if let timer = scrollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func resetScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        scrollOffset = 0
        
        // Restart scrolling if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard self.isViewVisible else { return }
            self.startScrolling()
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
    
    private func handlePositionDrag(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        if !isScrubbing {
            isScrubbing = true
            wasPlayingPreScrub = audioPlayer.isPlaying
            // Pause during scrubbing to avoid audio conflicts
            if wasPlayingPreScrub {
                audioPlayer.pause()
            }
        }
        
        // Calculate progress based on location in the geometry
        let width = geometry.size.width
        let x = min(max(0, value.location.x), width)
        let progress = Double(x / width)
        
        // Only update visual position during scrubbing - don't seek audio yet
        scrubbingProgress = progress
    }
    
    private func handlePositionDragEnd(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        // Calculate final position
        let width = geometry.size.width
        let x = min(max(0, value.location.x), width)
        let progress = Double(x / width)

        // Update visual progress immediately so slider shows where user dragged
        scrubbingProgress = progress

        // Perform seek - use seekToPercent which handles file duration correctly
        audioPlayer.seekToPercent(progress, resume: wasPlayingPreScrub)

        // CRITICAL: Keep isScrubbing = true until the progress timer has had at least
        // 2-3 cycles to update with the new seek position. This prevents the slider
        // from jumping to an incorrect position due to stale AVAudioPlayerNode render times.
        // The progress timer runs every 0.1s, so 0.3s gives it 3 cycles to stabilize.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isScrubbing = false
        }
    }
}

#Preview {
    WinampMainWindow()
        .environmentObject(SkinManager())
        .environmentObject(AudioPlayer())
        .environmentObject(DockingController())
}
