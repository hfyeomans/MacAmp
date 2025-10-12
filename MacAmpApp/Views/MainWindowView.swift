import SwiftUI
import AppKit // Import AppKit for NSApplication

struct MainWindowView: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer // Access AudioPlayer
    @EnvironmentObject var settings: AppSettings

    @State private var isShadeMode: Bool = false
    @State private var showRemainingTime: Bool = false
    @State private var isScrubbing: Bool = false
    @State private var wasPlayingPreScrub: Bool = false
    @Environment(\.openWindow) var openWindow // Access openWindow environment value
    
    // MARK: - Whimsy & Animation States
    @State private var buttonHovers: Set<String> = []
    @State private var glassPulse: Double = 1.0
    @State private var volumeGlow: Bool = false
    @State private var timeDisplayBounce: Bool = false
    @State private var lastPlayState: Bool = false
    @State private var showPlaySuccessFeedback: Bool = false
    @State private var liquidRipple: CGPoint? = nil

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

                        // Control Buttons with Liquid Glass interactions
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                NSApp.keyWindow?.miniaturize(nil)
                            }
                        }) {
                            Image(nsImage: minimizeButton)
                                .resizable()
                                .frame(width: 9, height: 9)
                                .scaleEffect(buttonHovers.contains("minimize") ? 1.15 : 1.0)
                                .shadow(color: .white.opacity(0.3), radius: buttonHovers.contains("minimize") ? 2 : 0)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if hovering { buttonHovers.insert("minimize") } else { buttonHovers.remove("minimize") }
                            }
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                isShadeMode.toggle()
                            }
                        }) {
                            Image(nsImage: shadeButton)
                                .resizable()
                                .frame(width: 9, height: 9)
                                .scaleEffect(buttonHovers.contains("shade") ? 1.15 : 1.0)
                                .shadow(color: .blue.opacity(0.4), radius: buttonHovers.contains("shade") ? 3 : 0)
                                .rotationEffect(.degrees(isShadeMode ? 180 : 0))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if hovering { buttonHovers.insert("shade") } else { buttonHovers.remove("shade") }
                            }
                        }

                        Button(action: {
                            withAnimation(.easeIn(duration: 0.2)) {
                                NSApplication.shared.terminate(nil)
                            }
                        }) {
                            Image(nsImage: closeButton)
                                .resizable()
                                .frame(width: 9, height: 9)
                                .scaleEffect(buttonHovers.contains("close") ? 1.2 : 1.0)
                                .shadow(color: .red.opacity(0.5), radius: buttonHovers.contains("close") ? 4 : 0)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if hovering { buttonHovers.insert("close") } else { buttonHovers.remove("close") }
                            }
                        }
                    }
                    .frame(height: 14) // Height of the title bar

                    // Only show these elements if not in shade mode
                    if !isShadeMode {
                        // Playback Controls with delightful feedback
                        HStack(spacing: 0) {
                            PlaybackButton(id: "prev", image: prevButton, size: CGSize(width: 23, height: 18), hovers: $buttonHovers) {
                                audioPlayer.previousTrack()
                            }

                            PlaybackButton(id: "play", image: playButton, size: CGSize(width: 23, height: 18), hovers: $buttonHovers) {
                                audioPlayer.play()
                                triggerPlayFeedback()
                            }

                            PlaybackButton(id: "pause", image: pauseButton, size: CGSize(width: 23, height: 18), hovers: $buttonHovers) {
                                audioPlayer.pause()
                            }

                            PlaybackButton(id: "stop", image: stopButton, size: CGSize(width: 23, height: 18), hovers: $buttonHovers) {
                                audioPlayer.stop()
                            }

                            PlaybackButton(id: "next", image: nextButton, size: CGSize(width: 23, height: 18), hovers: $buttonHovers) {
                                audioPlayer.nextTrack()
                            }

                            PlaybackButton(id: "eject", image: ejectButton, size: CGSize(width: 22, height: 16), hovers: $buttonHovers) {
                                audioPlayer.eject()
                            }
                        }
                        .padding(.top, 10) // Adjust spacing as needed

                        // Volume and Balance Sliders with glass effects
                        HStack(spacing: 0) {
                            VolumeSliderView(
                                background: volumeBackground,
                                thumb: volumeThumb,
                                value: $audioPlayer.volume
                            )
                            .frame(width: volumeBackground.size.width, height: 14)
                            .overlay(
                                Rectangle()
                                    .fill(LinearGradient(
                                        colors: [.clear, .white.opacity(0.2), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .opacity(volumeGlow ? 0.6 : 0)
                                    .animation(.easeInOut(duration: 0.3), value: volumeGlow)
                                    .blendMode(.overlay)
                            )
                            .onChange(of: audioPlayer.volume) { _, _ in
                                triggerVolumeGlow()
                            }

                            BalanceSliderView(
                                background: balanceBackground,
                                thumb: balanceThumb,
                                value: $audioPlayer.balance
                            )
                            .frame(width: balanceBackground.size.width, height: 14)
                            .overlay(
                                Circle()
                                    .fill(RadialGradient(
                                        colors: [.white.opacity(0.3), .clear],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 20
                                    ))
                                    .scaleEffect(volumeGlow ? 1.2 : 0.8)
                                    .opacity(volumeGlow ? 0.4 : 0)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: volumeGlow)
                                    .blendMode(.softLight)
                            )
                        }
                        .padding(.top, 5) // Adjust spacing as needed

                        // Time Display with delightful interactions
                        HStack(spacing: 0) {
                            if showRemainingTime, let minus = skin.images["MINUS_SIGN"] {
                                Image(nsImage: minus)
                                    .resizable()
                                    .frame(width: minus.size.width, height: minus.size.height)
                                    .padding(.trailing, 2)
                                    .scaleEffect(timeDisplayBounce ? 1.1 : 1.0)
                            }
                            let remaining = max(0.0, audioPlayer.currentDuration - audioPlayer.currentTime)
                            let timeline = showRemainingTime ? remaining : audioPlayer.currentTime
                            let digits = timeDigits(seconds: timeline)
                            ForEach(0..<digits.count, id: \.self) { idx in
                                if let digitImage = skin.images["DIGIT_" + String(digits[idx])] {
                                    Image(nsImage: digitImage)
                                        .resizable()
                                        .frame(width: 9, height: 13)
                                        .scaleEffect(timeDisplayBounce ? 1.05 : 1.0)
                                        .shadow(color: .cyan.opacity(0.3), radius: timeDisplayBounce ? 1 : 0)
                                }
                            }
                        }
                        .padding(.top, 5)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                showRemainingTime.toggle()
                                timeDisplayBounce = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    timeDisplayBounce = false
                                }
                            }
                        }
                        .overlay(
                            Rectangle()
                                .fill(.white.opacity(0.1))
                                .opacity(timeDisplayBounce ? 1 : 0)
                                .animation(.easeOut(duration: 0.2), value: timeDisplayBounce)
                                .allowsHitTesting(false)
                        )

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

                        // Load File Button with delightful glass styling
                        Button("Load Music File") {
                            let openPanel = NSOpenPanel()
                            openPanel.allowedContentTypes = [.audio]
                            openPanel.allowsMultipleSelection = false
                            openPanel.canChooseDirectories = false

                            openPanel.begin { response in
                                if response == .OK {
                                    if let selectedURL = openPanel.url {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            audioPlayer.loadTrack(url: selectedURL)
                                            showPlaySuccessFeedback = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            withAnimation(.easeOut(duration: 0.3)) {
                                                showPlaySuccessFeedback = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .conditionalButtonStyle(enabled: settings.shouldUseContainerBackground)
                        .scaleEffect(buttonHovers.contains("load") ? 1.05 : 1.0)
                        .shadow(color: settings.shouldUseContainerBackground ? .blue.opacity(0.3) : .clear, 
                               radius: buttonHovers.contains("load") ? 4 : 0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                                .opacity(buttonHovers.contains("load") ? 1 : 0)
                                .animation(.easeInOut(duration: 0.2), value: buttonHovers.contains("load"))
                        )
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if hovering { buttonHovers.insert("load") } else { buttonHovers.remove("load") }
                            }
                        }
                        .padding(.top, 5)
                        .overlay(
                            // Success feedback overlay
                            Text("Track Loaded!")
                                .font(.caption)
                                .foregroundColor(.green)
                                .opacity(showPlaySuccessFeedback ? 1 : 0)
                                .scaleEffect(showPlaySuccessFeedback ? 1.1 : 0.8)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showPlaySuccessFeedback)
                                .offset(y: -25)
                        )

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
                VStack {
                    Text("Loading Skin...")
                        .foregroundColor(.primary)
                    ProgressView()
                        .scaleEffect(0.8)
                }
                .frame(width: 275, height: 116)
                .conditionalContainerBackground(enabled: settings.shouldUseContainerBackground)
            }
        }
        .frame(width: 275, height: isShadeMode ? 14 : 116)
        .background(semanticBackground)
        .background(WindowAccessor { window in
            WindowSnapManager.shared.register(window: window, kind: .main)
        })
        .overlay(
            // Liquid ripple effect
            liquidRippleEffect()
        )
        .onReceive(audioPlayer.$isPlaying) { isPlaying in
            handlePlayStateChange(isPlaying)
        }
        .onAppear {
            startGlassPulseAnimation()
        }
    }
    
    // MARK: - Whimsy Helper Functions
    private func triggerPlayFeedback() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showPlaySuccessFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showPlaySuccessFeedback = false
            }
        }
    }
    
    private func triggerVolumeGlow() {
        withAnimation(.easeInOut(duration: 0.2)) {
            volumeGlow = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                volumeGlow = false
            }
        }
    }
    
    private func handlePlayStateChange(_ isPlaying: Bool) {
        if isPlaying && !lastPlayState {
            // Just started playing - trigger celebration
            triggerLiquidRipple(at: CGPoint(x: 135, y: 50))
        }
        lastPlayState = isPlaying
    }
    
    private func triggerLiquidRipple(at point: CGPoint) {
        withAnimation(.easeOut(duration: 0.6)) {
            liquidRipple = point
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            liquidRipple = nil
        }
    }
    
    private func startGlassPulseAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glassPulse = 1.02
        }
    }
    
    // MARK: - Liquid Ripple Effect
    @ViewBuilder
    private func liquidRippleEffect() -> some View {
        if let ripplePoint = liquidRipple, settings.shouldUseContainerBackground {
            Circle()
                .stroke(.white.opacity(0.6), lineWidth: 2)
                .frame(width: 40, height: 40)
                .scaleEffect(3.0)
                .opacity(0.0)
                .position(ripplePoint)
                .animation(.easeOut(duration: 0.6), value: liquidRipple)
        }
    }
    
    // MARK: - Semantic Background
    @ViewBuilder
    private var semanticBackground: some View {
        if settings.shouldUseContainerBackground {
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(.regularMaterial)
                    .opacity(0.7)
                    .overlay(
                        // Liquid glass refraction effect
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.1), .clear, .cyan.opacity(0.05), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .opacity(audioPlayer.isPlaying ? 0.3 : 0.1)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                                  value: audioPlayer.isPlaying)
                    )
            } else {
                Rectangle()
                    .fill(.regularMaterial)
                    .opacity(0.8)
            }
        } else {
            Color.clear
        }
    }
}

// MARK: - Liquid Glass Integration Extensions

private extension View {
    @ViewBuilder
    func conditionalButtonStyle(enabled: Bool) -> some View {
        if enabled {
            if #available(macOS 26.0, *) {
                self.buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .clear, .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            } else {
                self
            }
        } else {
            self
        }
    }
    
    @ViewBuilder
    func conditionalContainerBackground(enabled: Bool) -> some View {
        if enabled {
            if #available(macOS 26.0, *) {
                self.containerBackground(.regularMaterial, for: .window)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.05), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                self.background(Color.gray)
            }
        } else {
            self.background(Color.gray)
        }
    }
}

// MARK: - Playback Button Component
struct PlaybackButton: View {
    let id: String
    let image: NSImage
    let size: CGSize
    @Binding var hovers: Set<String>
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                action()
            }
        }) {
            Image(nsImage: image)
                .resizable()
                .frame(width: size.width, height: size.height)
                .scaleEffect(hovers.contains(id) ? 1.1 : 1.0)
                .shadow(
                    color: shadowColor,
                    radius: hovers.contains(id) ? 3 : 0
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                        .opacity(hovers.contains(id) ? 1 : 0)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if hovering { hovers.insert(id) } else { hovers.remove(id) }
            }
        }
    }
    
    private var shadowColor: Color {
        switch id {
        case "play": return .green.opacity(0.5)
        case "stop": return .red.opacity(0.4)
        case "prev", "next": return .blue.opacity(0.4)
        case "pause": return .orange.opacity(0.4)
        case "eject": return .purple.opacity(0.4)
        default: return .white.opacity(0.3)
        }
    }
}

#Preview {
    MainWindowView()
        .environmentObject(SkinManager())
        .environmentObject(AppSettings.instance())
}

