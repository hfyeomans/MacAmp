import SwiftUI
import AppKit // Import AppKit for NSApplication

struct MainWindowView: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer // Access AudioPlayer

    @State private var isShadeMode: Bool = false
    @State private var showRemainingTime: Bool = false
    @State private var isScrubbing: Bool = false
    @State private var wasPlayingPreScrub: Bool = false
    @Environment(\.openWindow) var openWindow // Access openWindow environment value

    // Helper: convert seconds to [m1, m2, s1, s2]
    private func timeDigits(seconds: Double) -> [Int] {
        let total = max(0, Int(seconds))
        let minutes = total / 60
        let secs = total % 60
        return [minutes / 10, minutes % 10, secs / 10, secs % 10]
    }

    var body: some View {
        ZStack {
            if let skin = skinManager.currentSkin,
               let mainWindowBackground = skin.images["MAIN_WINDOW_BACKGROUND"],
               let titleBarImage = skin.images["MAIN_TITLE_BAR"],
               let minimizeButton = skin.images["MAIN_MINIMIZE_BUTTON"],
               let shadeButton = skin.images["MAIN_SHADE_BUTTON"],
               let closeButton = skin.images["MAIN_CLOSE_BUTTON"],
               let prevButton = skin.images["MAIN_PREVIOUS_BUTTON"],
               let playButton = skin.images["MAIN_PLAY_BUTTON"],
               let pauseButton = skin.images["MAIN_PAUSE_BUTTON"],
               let stopButton = skin.images["MAIN_STOP_BUTTON"],
               let nextButton = skin.images["MAIN_NEXT_BUTTON"],
               let ejectButton = skin.images["MAIN_EJECT_BUTTON"],
               let volumeBackground = skin.images["MAIN_VOLUME_BACKGROUND"],
               let volumeThumb = skin.images["MAIN_VOLUME_THUMB"],
               let balanceBackground = skin.images["MAIN_BALANCE_BACKGROUND"],
               let balanceThumb = skin.images["MAIN_BALANCE_THUMB"],
               // Ensure basic digit sprite presence
               let _ = skin.images["DIGIT_0"],
               let progressBarBackground = skin.images["MAIN_POSITION_SLIDER_BACKGROUND"],
               let progressBarThumb = skin.images["MAIN_POSITION_SLIDER_THUMB"],
               let playlistToggleButton = skin.images["MAIN_PLAYLIST_BUTTON"],
               let eqToggleButton = skin.images["MAIN_EQ_BUTTON"] // New: EQ button image
            {

                // Main Window Background
                Image(nsImage: mainWindowBackground)
                    .resizable()
                    .scaledToFit()

                VStack(spacing: 0) {
                    // Title Bar
                    HStack(spacing: 0) {
                        Image(nsImage: titleBarImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 275 - (9*3), height: 14) // Adjust width for buttons

                        Spacer() // Pushes buttons to the right

                        // Control Buttons
                        Button(action: {
                            NSApp.keyWindow?.miniaturize(nil) // Minimize the window
                        }) {
                            Image(nsImage: minimizeButton)
                                .resizable()
                                .frame(width: 9, height: 9)
                        }
                        .buttonStyle(PlainButtonStyle()) // Remove default button styling

                        Button(action: {
                            isShadeMode.toggle()
                        }) {
                            Image(nsImage: shadeButton)
                                .resizable()
                                .frame(width: 9, height: 9)
                        }
                        .buttonStyle(PlainButtonStyle()) // Remove default button styling

                        Button(action: {
                            NSApplication.shared.terminate(nil) // Quits the application
                        }) {
                            Image(nsImage: closeButton)
                                .resizable()
                                .frame(width: 9, height: 9)
                        }
                        .buttonStyle(PlainButtonStyle()) // Remove default button styling
                    }
                    .frame(height: 14) // Height of the title bar

                    // Only show these elements if not in shade mode
                    if !isShadeMode {
                        // Playback Controls
                        HStack(spacing: 0) {
                            Button(action: { audioPlayer.previousTrack() }) {
                                Image(nsImage: prevButton)
                                    .resizable()
                                    .frame(width: 23, height: 18)
                            }.buttonStyle(PlainButtonStyle())

                            Button(action: { audioPlayer.play() }) {
                                Image(nsImage: playButton)
                                    .resizable()
                                    .frame(width: 23, height: 18)
                            }.buttonStyle(PlainButtonStyle())

                            Button(action: { audioPlayer.pause() }) {
                                Image(nsImage: pauseButton)
                                    .resizable()
                                    .frame(width: 23, height: 18)
                            }.buttonStyle(PlainButtonStyle())

                            Button(action: { audioPlayer.stop() }) {
                                Image(nsImage: stopButton)
                                    .resizable()
                                    .frame(width: 23, height: 18)
                            }.buttonStyle(PlainButtonStyle())

                            Button(action: { audioPlayer.nextTrack() }) {
                                Image(nsImage: nextButton)
                                    .resizable()
                                    .frame(width: 23, height: 18)
                            }.buttonStyle(PlainButtonStyle())

                            Button(action: { audioPlayer.eject() }) {
                                Image(nsImage: ejectButton)
                                    .resizable()
                                    .frame(width: 22, height: 16)
                            }.buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 10) // Adjust spacing as needed

                        // Volume and Balance Sliders
                        HStack(spacing: 0) {
                            VolumeSliderView(
                                background: volumeBackground,
                                thumb: volumeThumb,
                                value: $audioPlayer.volume
                            )
                            .frame(width: volumeBackground.size.width, height: 14)

                            BalanceSliderView(
                                background: balanceBackground,
                                thumb: balanceThumb,
                                value: $audioPlayer.balance
                            )
                            .frame(width: balanceBackground.size.width, height: 14)
                        }
                        .padding(.top, 5) // Adjust spacing as needed

                        // Time Display (MM:SS using digit sprites; minus shown in remaining mode)
                        HStack(spacing: 0) {
                            if showRemainingTime, let minus = skin.images["MINUS_SIGN"] {
                                Image(nsImage: minus)
                                    .resizable()
                                    .frame(width: minus.size.width, height: minus.size.height)
                                    .padding(.trailing, 2)
                            }
                            let remaining = max(0.0, audioPlayer.currentDuration - audioPlayer.currentTime)
                            let timeline = showRemainingTime ? remaining : audioPlayer.currentTime
                            let digits = timeDigits(seconds: timeline)
                            ForEach(0..<digits.count, id: \.self) { idx in
                                if let digitImage = skin.images["DIGIT_" + String(digits[idx])] {
                                    Image(nsImage: digitImage)
                                        .resizable()
                                        .frame(width: 9, height: 13)
                                }
                            }
                        }
                        .padding(.top, 5)
                        .contentShape(Rectangle())
                        .onTapGesture { showRemainingTime.toggle() }

                        // Song Title Marquee
                        Text(audioPlayer.currentTitle)
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 15) // Approximate marquee size
                            .background(Color.black.opacity(0.5)) // For visibility
                            .padding(.top, 5) // Adjust spacing as needed

                        // Progress Bar
                        ZStack(alignment: .leading) {
                            Image(nsImage: progressBarBackground)
                                .resizable()
                                .frame(width: 248, height: 10)

                            // Filled portion during normal playback
                            Image(nsImage: progressBarThumb)
                                .resizable()
                                .frame(width: 248 * audioPlayer.playbackProgress, height: 10)
                                .clipped()

                            // Invisible interactive layer for scrubbing
                            GeometryReader { geo in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                if !isScrubbing {
                                                    isScrubbing = true
                                                    wasPlayingPreScrub = audioPlayer.isPlaying
                                                    if wasPlayingPreScrub { audioPlayer.pause() }
                                                }
                                                let width = geo.size.width
                                                let x = min(max(0, value.location.x), width)
                                                let progress = Double(x / width)
                                                if audioPlayer.currentDuration > 0 {
                                                    let t = progress * audioPlayer.currentDuration
                                                    // Update UI immediately while dragging
                                                    audioPlayer.currentTime = t
                                                    audioPlayer.playbackProgress = progress
                                                }
                                            }
                                            .onEnded { value in
                                                let width = geo.size.width
                                                let x = min(max(0, value.location.x), width)
                                                let progress = Double(x / width)
                                                let t = progress * (audioPlayer.currentDuration)
                                                audioPlayer.seek(to: t, resume: wasPlayingPreScrub)
                                                isScrubbing = false
                                            }
                                    )
                            }
                            .frame(width: 248, height: 10)
                        }
                        .frame(width: 248, height: 10)
                        .padding(.top, 5)

                        // Visualizer + controls
                        VStack(spacing: 2) {
                            VisualizerView()
                                .frame(width: 200, height: 30)
                            VisualizerOptions()
                                .environmentObject(audioPlayer)
                        }
                        .padding(.top, 5)

                        // Load File Button
                        Button("Load Music File") {
                            let openPanel = NSOpenPanel()
                            openPanel.allowedContentTypes = [.audio]
                            openPanel.allowsMultipleSelection = false
                            openPanel.canChooseDirectories = false

                            openPanel.begin {
                                response in
                                if response == .OK {
                                    if let selectedURL = openPanel.url {
                                        audioPlayer.loadTrack(url: selectedURL)
                                    }
                                }
                            }
                        }
                        .padding(.top, 5)

                        // Playlist Toggle Button
                        Button(action: {
                            openWindow(id: "playlistWindow")
                        }) {
                            Image(nsImage: playlistToggleButton)
                                .resizable()
                                .frame(width: 23, height: 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 5)

                        // EQ Toggle Button
                        Button(action: {
                            openWindow(id: "equalizerWindow")
                        }) {
                            Image(nsImage: eqToggleButton)
                                .resizable()
                                .frame(width: 23, height: 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 5)

                    }

                    Spacer() // Pushes content to the top

                    // Other UI elements will go here
                }
            } else {
                Text("Loading Skin...")
                    .frame(width: 275, height: 116) // Placeholder size
                    .background(Color.gray)
            }
        }
        .frame(width: 275, height: isShadeMode ? 14 : 116) // Adjust height based on shade mode
        .background(WindowAccessor { window in
            WindowSnapManager.shared.register(window: window, kind: .main)
        })
    }
}

#Preview {
    MainWindowView()
        .environmentObject(SkinManager())
}

