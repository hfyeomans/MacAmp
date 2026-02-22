import SwiftUI

/// Shade (collapsed) mode — minimal transport, time display, and titlebar buttons.
struct MainWindowShadeLayer: View {
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator
    @Environment(AppSettings.self) private var settings
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(WindowFocusState.self) private var windowFocusState

    let interactionState: WinampMainWindowInteractionState

    private typealias Layout = WinampMainWindowLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            SimpleSpriteImage("MAIN_SHADE_BACKGROUND", width: 275, height: 14)
                .at(CGPoint(x: 0, y: 0))

            buildShadeTransportButtons()
            buildShadeTimeDisplay()
            buildShadeTitlebarButtons()
        }
    }

    // MARK: - Shade Transport Buttons

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

    // MARK: - Shade Time Display

    @ViewBuilder
    private func buildShadeTimeDisplay() -> some View {
        ZStack(alignment: .leading) {
            Color.black
                .frame(width: 21, height: 13)
                .offset(x: 6, y: 0)

            Color.black
                .frame(width: 21, height: 13)
                .offset(x: 34, y: 0)

            if settings.timeDisplayMode == .remaining {
                ZStack(alignment: .topLeading) {
                    SimpleSpriteImage(.minusSign, width: 5, height: 1)
                        .offset(x: 0, y: 6)
                }
                .frame(width: 9, height: 13, alignment: .topLeading)
                .offset(x: 1, y: 0)
            }

            let timeToShow = settings.timeDisplayMode == .remaining ?
                max(0.0, audioPlayer.currentDuration - audioPlayer.currentTime) :
                audioPlayer.currentTime
            let digits = interactionState.timeDigits(from: timeToShow)
            let shouldShowDigits = !playbackCoordinator.isPaused || interactionState.pauseBlinkVisible

            if shouldShowDigits {
                SimpleSpriteImage(.digit(digits[0]), width: 9, height: 13).offset(x: 6, y: 0)
                SimpleSpriteImage(.digit(digits[1]), width: 9, height: 13).offset(x: 17, y: 0)
            }
            if shouldShowDigits {
                SimpleSpriteImage(.digit(digits[2]), width: 9, height: 13).offset(x: 35, y: 0)
                SimpleSpriteImage(.digit(digits[3]), width: 9, height: 13).offset(x: 46, y: 0)
            }
        }
        .scaleEffect(0.7)
        .at(CGPoint(x: 150, y: 7))
        .contentShape(Rectangle())
        .onTapGesture {
            settings.toggleTimeDisplayMode()
        }
    }

    // MARK: - Shade Titlebar Buttons

    @ViewBuilder
    private func buildShadeTitlebarButtons() -> some View {
        Group {
            Button(action: {
                WindowCoordinator.shared?.minimizeKeyWindow()
            }, label: {
                SimpleSpriteImage("MAIN_MINIMIZE_BUTTON", width: 9, height: 9)
            })
            .buttonStyle(.plain)
            .focusable(false)
            .at(Layout.minimizeButton)

            Button(action: {
                settings.isMainWindowShaded.toggle()
            }, label: {
                SimpleSpriteImage("MAIN_SHADE_BUTTON", width: 9, height: 9)
            })
            .buttonStyle(.plain)
            .focusable(false)
            .at(Layout.shadeButton)

            Button(action: {
                NSApplication.shared.terminate(nil)
            }, label: {
                SimpleSpriteImage("MAIN_CLOSE_BUTTON", width: 9, height: 9)
            })
            .buttonStyle(.plain)
            .focusable(false)
            .at(Layout.closeButton)
        }
    }
}
