import SwiftUI
import AppKit

/// Pixel-perfect recreation of Winamp's main window using absolute positioning
struct WinampMainWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(DockingController.self) var dockingController
    @Environment(AppSettings.self) var settings
    @Environment(PlaybackCoordinator.self) var playbackCoordinator
    @Environment(WindowFocusState.self) var windowFocusState

    // CRITICAL: Prevent unnecessary body re-evaluations that cause ghost images
    // SwiftUI re-evaluates body when ANY @EnvironmentObject publishes changes
    // This was causing 7+ evaluations before old views cleanup, creating visual doubles

    // NOTE: isShadeMode moved to AppSettings.isMainWindowShaded for cross-window observation
    // Playlist window needs to know when main window is shaded to show mini visualizer
    @State var isScrubbing: Bool = false
    @State var wasPlayingPreScrub: Bool = false
    @State var scrubbingProgress: Double = 0.0

    // Track info scrolling state
    @State var scrollOffset: CGFloat = 0
    @State var scrollTimer: Timer?

    // Pause blinking state
    @State var pauseBlinkVisible: Bool = true
    @State var isViewVisible: Bool = false

    // Menu state - keep strong reference to prevent premature deallocation
    @State var activeOptionsMenu: NSMenu?

    // Timer publisher for pause blink animation (Swift 6 pattern)
    let pauseBlinkTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    // Computed: Is this window currently focused?
    private var isWindowActive: Bool {
        windowFocusState.isMainKey
    }

    // Winamp coordinate constants (from original Winamp and webamp)
    struct Coords {
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

        // Clutter bar (vertical button strip, left side)
        static let clutterBar = CGPoint(x: 10, y: 22)
        static let clutterButtonO = CGPoint(x: 10, y: 25)  // top: 3px relative
        static let clutterButtonA = CGPoint(x: 10, y: 33)  // top: 11px relative
        static let clutterButtonI = CGPoint(x: 10, y: 40)  // top: 18px relative
        static let clutterButtonD = CGPoint(x: 10, y: 47)  // top: 25px relative
        static let clutterButtonV = CGPoint(x: 10, y: 55)  // top: 33px relative
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background (preprocessed to remove static digits, keeping ":")
            SimpleSpriteImage("MAIN_WINDOW_BACKGROUND",
                            width: WinampSizes.main.width,
                            height: WinampSizes.main.height)

            // Title bar - apply .at() to drag handle itself for proper positioning
            WinampTitlebarDragHandle(windowKind: .main, size: CGSize(width: 275, height: 14)) {
                SimpleSpriteImage(isWindowActive ? "MAIN_TITLE_BAR_SELECTED" : "MAIN_TITLE_BAR",
                                width: 275,
                                height: 14)
            }
            .at(CGPoint(x: 0, y: 0))

            if !settings.isMainWindowShaded {
                // Full window mode
                buildFullWindow()
            } else {
                // Shade mode (collapsed to titlebar only)
                buildShadeMode()
            }
        }
        .frame(
            width: WinampSizes.main.width,
            height: settings.isMainWindowShaded ? WinampSizes.mainShade.height : WinampSizes.main.height,
            alignment: .topLeading
        )
        .scaleEffect(
            settings.isDoubleSizeMode ? 2.0 : 1.0,
            anchor: .topLeading
        )
        .frame(
            width: settings.isDoubleSizeMode ? WinampSizes.main.width * 2 : WinampSizes.main.width,
            height: settings.isMainWindowShaded
                ? (settings.isDoubleSizeMode ? WinampSizes.mainShade.height * 2 : WinampSizes.mainShade.height)
                : (settings.isDoubleSizeMode ? WinampSizes.main.height * 2 : WinampSizes.main.height),
            alignment: .topLeading
        )
        .fixedSize()  // Lock measured size so background sees final geometry
        .background(Color.black) // Must be AFTER fixedSize to see scaled dimensions
        .sheet(isPresented: Binding(
            get: { settings.showTrackInfoDialog },
            set: { settings.showTrackInfoDialog = $0 }
        )) {
            TrackInfoView()
        }
        .onChange(of: settings.showOptionsMenuTrigger) { _, newValue in
            if newValue {
                // Show options menu when triggered by keyboard shortcut
                showOptionsMenu(from: Coords.clutterButtonO)
                // Reset trigger
                settings.showOptionsMenuTrigger = false
            }
        }
        .onAppear {
            isViewVisible = true
        }
        .onReceive(pauseBlinkTimer) { _ in
            // Only blink when paused (Swift 6 safe pattern)
            if playbackCoordinator.isPaused {
                pauseBlinkVisible.toggle()
            } else {
                pauseBlinkVisible = true  // Always visible when not paused
            }
        }
        .onDisappear {
            isViewVisible = false
            scrollTimer?.invalidate()
            scrollTimer = nil
            // Note: pauseBlinkTimer is now a publisher, auto-managed by SwiftUI
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
            buildTransportPlaybackButtons()
            buildTransportNavButtons()

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

            // Clutter bar buttons (O, A, I, D, V) - split for closure_body_length
            buildClutterBarOAI()
            buildClutterBarDV()

            // Additional Winamp elements (simplified)
            buildMonoStereoIndicator()
            
            // Bitrate and sample rate display
            buildBitrateDisplay()
            buildSampleRateDisplay()
        }
    }
    
    @ViewBuilder
    private func buildShadeMode() -> some View {
        ZStack(alignment: .topLeading) {
            SimpleSpriteImage("MAIN_SHADE_BACKGROUND", width: 275, height: 14)
                .at(CGPoint(x: 0, y: 0))

            buildShadeTransportButtons()

            buildTimeDisplay()
                .scaleEffect(0.7)
                .at(CGPoint(x: 150, y: 7))

            buildTitlebarButtons()
        }
    }

    @ViewBuilder
    private func buildShadeTransportButtons() -> some View {
        HStack(spacing: 2) {
            Button(action: { Task { await playbackCoordinator.previous() } }, label: {
                SimpleSpriteImage("MAIN_PREVIOUS_BUTTON", width: 23, height: 18).scaleEffect(0.6)
            })
            .buttonStyle(.plain)
            .focusable(false)

            Button(action: { playbackCoordinator.togglePlayPause() }, label: {
                SimpleSpriteImage("MAIN_PLAY_BUTTON", width: 23, height: 18).scaleEffect(0.6)
            })
            .buttonStyle(.plain)
            .focusable(false)

            Button(action: { playbackCoordinator.pause() }, label: {
                SimpleSpriteImage("MAIN_PAUSE_BUTTON", width: 23, height: 18).scaleEffect(0.6)
            })
            .buttonStyle(.plain)
            .focusable(false)

            Button(action: { playbackCoordinator.stop() }, label: {
                SimpleSpriteImage("MAIN_STOP_BUTTON", width: 23, height: 18).scaleEffect(0.6)
            })
            .buttonStyle(.plain)
            .focusable(false)

            Button(action: { Task { await playbackCoordinator.next() } }, label: {
                SimpleSpriteImage("MAIN_NEXT_BUTTON", width: 22, height: 18).scaleEffect(0.6)
            })
            .buttonStyle(.plain)
            .focusable(false)
        }
        .at(CGPoint(x: 45, y: 3))
    }
    
    @ViewBuilder
    private func buildTitlebarButtons() -> some View {
        Group {
            // Minimize button
            Button(action: {
                WindowCoordinator.shared?.minimizeKeyWindow()
            }, label: {
                SimpleSpriteImage("MAIN_MINIMIZE_BUTTON", width: 9, height: 9)
            })
            .buttonStyle(.plain)
            .focusable(false)
            .at(Coords.minimizeButton)

            // Shade button
            Button(action: {
                settings.isMainWindowShaded.toggle()
            }, label: {
                SimpleSpriteImage("MAIN_SHADE_BUTTON", width: 9, height: 9)
            })
            .buttonStyle(.plain)
            .focusable(false)
            .at(Coords.shadeButton)

            // Close button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }, label: {
                SimpleSpriteImage("MAIN_CLOSE_BUTTON", width: 9, height: 9)
            })
            .buttonStyle(.plain)
            .focusable(false)
            .at(Coords.closeButton)
        }
    }
    
    private func buildPlayPauseIndicator() -> some View {
        let spriteKey: String
        if playbackCoordinator.isPlaying {
            spriteKey = "MAIN_PLAYING_INDICATOR"
        } else if playbackCoordinator.isPaused {
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
            if settings.timeDisplayMode == .remaining {
                // Create a 9x13 container to match digit frames, then center the 5x1 minus sprite
                ZStack(alignment: .topLeading) {
                    SimpleSpriteImage(.minusSign, width: 5, height: 1)
                        .offset(x: 0, y: 6) // Center vertically: (13-1)/2 = 6
                }
                .frame(width: 9, height: 13, alignment: .topLeading)
                .offset(x: 1, y: 0) // Position the container at x:1
            }

            // Time digits (MM:SS) — colon comes from MAIN.BMP background
            buildTimeDigits()
        }
        .at(Coords.timeDisplay)
        .contentShape(Rectangle())
        .onTapGesture {
            settings.toggleTimeDisplayMode()
        }
    }
    
    @ViewBuilder
    private func buildTimeDigits() -> some View {
        let timeToShow = settings.timeDisplayMode == .remaining ?
            max(0.0, audioPlayer.currentDuration - audioPlayer.currentTime) :
            audioPlayer.currentTime
        let digits = timeDigits(from: timeToShow)
        let shouldShowDigits = !playbackCoordinator.isPaused || pauseBlinkVisible

        if shouldShowDigits {
            SimpleSpriteImage(.digit(digits[0]), width: 9, height: 13).offset(x: 6, y: 0)
            SimpleSpriteImage(.digit(digits[1]), width: 9, height: 13).offset(x: 17, y: 0)
        }
        if shouldShowDigits {
            SimpleSpriteImage(.digit(digits[2]), width: 9, height: 13).offset(x: 35, y: 0)
            SimpleSpriteImage(.digit(digits[3]), width: 9, height: 13).offset(x: 46, y: 0)
        }
    }

    func openFileDialog() {
        PlaylistWindowActions.shared.presentAddFilesPanel(audioPlayer: audioPlayer, playbackCoordinator: playbackCoordinator)
    }
}

#Preview {
    WinampMainWindow()
        .environment(SkinManager())
        .environment(AudioPlayer())
        .environment(DockingController())
}
