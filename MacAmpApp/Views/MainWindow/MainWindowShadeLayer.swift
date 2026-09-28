import SwiftUI

/// Shade (collapsed) mode. Buttons and the position well are part of the skin's shade strip, so
/// they're invisible hit areas (Webamp `main-window.css` `.shade` rules); only pressed sprites and
/// the position thumb are drawn.
struct MainWindowShadeLayer: View {
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator
    @Environment(AppSettings.self) private var settings
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(WindowFocusState.self) private var windowFocusState

    let interactionState: WinampMainWindowInteractionState
    let optionsPresenter: MainWindowOptionsMenuPresenter
    let openFileDialog: () -> Void

    private typealias Layout = WinampMainWindowLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Not hit-testable, so the titlebar drag handle underneath still moves the window.
            SimpleSpriteImage(windowFocusState.isMainKey ? "MAIN_SHADE_BACKGROUND_SELECTED" : "MAIN_SHADE_BACKGROUND",
                              width: 275, height: 14)
                .allowsHitTesting(false)

            buildShadeTransportButtons()
            buildShadePositionSlider()
            // Webamp clips the full-width visualizer to the strip's 38 px well rather than squeezing it.
            VisualizerView(height: 5)
                .frame(width: 38, height: 5, alignment: .leading)
                .clipped()
                .at(Layout.shadeVisualizer)
            buildShadeTimeDisplay()
            buildShadeTitlebarButtons()
        }
    }

    // MARK: - Shade Transport Buttons

    @ViewBuilder
    private func buildShadeTransportButtons() -> some View {
        Group {
            SkinHitButton(width: 7, height: 10) { Task { await playbackCoordinator.previous() } }
                .at(CGPoint(x: 169, y: 2))
            SkinHitButton(width: 10, height: 10) { playbackCoordinator.togglePlayPause() }
                .at(CGPoint(x: 176, y: 2))
            SkinHitButton(width: 9, height: 10) { playbackCoordinator.pause() }
                .at(CGPoint(x: 186, y: 2))
            SkinHitButton(width: 9, height: 10) { playbackCoordinator.stop() }
                .at(CGPoint(x: 195, y: 2))
            SkinHitButton(width: 10, height: 10) { Task { await playbackCoordinator.next() } }
                .at(CGPoint(x: 204, y: 2))
            SkinHitButton(width: 10, height: 10) { openFileDialog() }
                .at(CGPoint(x: 215, y: 2))
        }
    }

    // MARK: - Shade Position Slider

    @ViewBuilder
    private func buildShadePositionSlider() -> some View {
        let progress = interactionState.isScrubbing ? interactionState.scrubbingProgress : audioPlayer.playbackProgress
        // Webamp picks the thumb by progress: left third, middle, right third.
        let thumb = progress <= 0.33 ? "MAIN_SHADE_POSITION_THUMB_LEFT"
            : progress >= 0.66 ? "MAIN_SHADE_POSITION_THUMB_RIGHT" : "MAIN_SHADE_POSITION_THUMB"
        ZStack(alignment: .topLeading) {
            SimpleSpriteImage("MAIN_SHADE_POSITION_BACKGROUND", width: 17, height: 7)
                .allowsHitTesting(false)
            SimpleSpriteImage(thumb, width: 3, height: 7)
                .offset(x: (17 - 3) * progress)
                .allowsHitTesting(false)
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in interactionState.handlePositionDrag(value, in: geo, audioPlayer: audioPlayer) }
                            .onEnded { value in interactionState.handlePositionDragEnd(value, in: geo, audioPlayer: audioPlayer) }
                    )
            }
        }
        .frame(width: 17, height: 7, alignment: .topLeading)
        .at(CGPoint(x: 226, y: 4))
    }

    // MARK: - Shade Time Display

    /// TEXT.BMP characters at Webamp's `MiniTime` offsets; the colon is part of the strip.
    @ViewBuilder
    private func buildShadeTimeDisplay() -> some View {
        let stopped = !playbackCoordinator.isPlaying && !playbackCoordinator.isPaused
        let remaining = settings.timeDisplayMode == .remaining && !stopped
        let duration = playbackCoordinator.displayDuration
        let seconds = remaining && duration > 0
            ? max(0.0, duration - playbackCoordinator.displayTime)
            : playbackCoordinator.displayTime
        let digits = interactionState.timeDigits(from: seconds).map { Character(String($0)) }
        let visible = !stopped && (!playbackCoordinator.isPaused || interactionState.pauseBlinkVisible)
        let characters: [Character] = [remaining ? "-" : " "] + digits
        ZStack(alignment: .topLeading) {
            ForEach(Array(zip([1, 7, 12, 20, 25], characters)), id: \.0) { left, character in
                let code = visible ? character.asciiValue ?? 32 : 32
                SimpleSpriteImage("CHARACTER_\(code)", width: 5, height: 6)
                    .offset(x: CGFloat(left))
            }
        }
        .frame(width: 30, height: 6, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { settings.toggleTimeDisplayMode() }
        .at(Layout.shadeTime)
    }

    // MARK: - Shade Titlebar Buttons

    @ViewBuilder
    private func buildShadeTitlebarButtons() -> some View {
        Group {
            SkinHitButton(pressedSprite: "MAIN_OPTIONS_BUTTON_DEPRESSED", width: 9, height: 9) {
                optionsPresenter.showOptionsMenu(from: Layout.optionsButton, settings: settings,
                                                 audioPlayer: audioPlayer, isDoubleSizeMode: settings.isDoubleSizeMode)
            }
            .at(Layout.optionsButton)

            SkinHitButton(pressedSprite: "MAIN_MINIMIZE_BUTTON_DEPRESSED", width: 9, height: 9) {
                WindowCoordinator.shared?.minimizeApp()
            }
            .at(Layout.minimizeButton)

            SkinHitButton(pressedSprite: "MAIN_SHADE_BUTTON_SELECTED_DEPRESSED", width: 9, height: 9) {
                settings.isMainWindowShaded.toggle()
            }
            .at(Layout.shadeButton)

            SkinHitButton(pressedSprite: "MAIN_CLOSE_BUTTON_DEPRESSED", width: 9, height: 9) {
                NSApplication.shared.terminate(nil)
            }
            .at(Layout.closeButton)
        }
    }
}
