import SwiftUI

/// Full-mode main window composition — assembles all child layers plus
/// small builders (titlebar, shuffle/repeat, clutter bar, time, visualizer).
struct MainWindowFullLayer: View {
    @Environment(SkinManager.self) private var skinManager
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(AppSettings.self) private var settings
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator
    @Environment(WindowFocusState.self) private var windowFocusState

    let interactionState: WinampMainWindowInteractionState
    let optionsPresenter: MainWindowOptionsMenuPresenter
    let openFileDialog: () -> Void

    private typealias Layout = WinampMainWindowLayout

    var body: some View {
        Group {
            // Titlebar buttons
            buildTitlebarButtons()

            // Indicators (play/pause, mono/stereo, bitrate, sample rate)
            MainWindowIndicatorsLayer(pauseBlinkVisible: interactionState.pauseBlinkVisible)

            // Time display
            buildTimeDisplay()

            // Track info (scrolling text)
            MainWindowTrackInfoLayer(interactionState: interactionState)

            // Spectrum analyzer
            buildSpectrumAnalyzer()

            // Transport buttons
            MainWindowTransportLayer(openFileDialog: openFileDialog)

            // Shuffle/Repeat buttons
            buildShuffleRepeatButtons()

            // Sliders (position, volume, balance)
            MainWindowSlidersLayer(interactionState: interactionState)

            // EQ/Playlist window toggles
            buildWindowToggleButtons()

            // Clutter bar buttons (O, A, I, D, V)
            buildClutterBarOAI()
            buildClutterBarDV()
        }
    }

    // MARK: - Titlebar Buttons

    @ViewBuilder
    private func buildTitlebarButtons() -> some View {
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

    // MARK: - Time Display

    @ViewBuilder
    private func buildTimeDisplay() -> some View {
        ZStack(alignment: .leading) {
            // Minutes mask
            Color.black
                .frame(width: 21, height: 13)
                .offset(x: 6, y: 0)

            // Seconds mask
            Color.black
                .frame(width: 21, height: 13)
                .offset(x: 34, y: 0)

            // Minus sign for remaining time
            if settings.timeDisplayMode == .remaining {
                ZStack(alignment: .topLeading) {
                    SimpleSpriteImage(.minusSign, width: 5, height: 1)
                        .offset(x: 0, y: 6)
                }
                .frame(width: 9, height: 13, alignment: .topLeading)
                .offset(x: 1, y: 0)
            }

            // Time digits (MM:SS)
            buildTimeDigits()
        }
        .at(Layout.timeDisplay)
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

    // MARK: - Spectrum Analyzer

    @ViewBuilder
    private func buildSpectrumAnalyzer() -> some View {
        VisualizerView()
            .frame(width: VisualizerLayout.width, height: VisualizerLayout.height)
            .background(Color.black.opacity(0.5))
            .at(Layout.spectrumAnalyzer)
    }

    // MARK: - Shuffle/Repeat

    @ViewBuilder
    private func buildShuffleRepeatButtons() -> some View {
        Group {
            Button(action: { audioPlayer.shuffleEnabled.toggle() }, label: {
                let spriteKey = audioPlayer.shuffleEnabled ? "MAIN_SHUFFLE_BUTTON_SELECTED" : "MAIN_SHUFFLE_BUTTON"
                SimpleSpriteImage(spriteKey, width: 47, height: 15)
            })
            .buttonStyle(.plain)
            .focusable(false)
            .at(Layout.shuffleButton)

            Button(action: { audioPlayer.repeatMode = audioPlayer.repeatMode.next() }, label: {
                let spriteKey = audioPlayer.repeatMode.isActive ? "MAIN_REPEAT_BUTTON_SELECTED" : "MAIN_REPEAT_BUTTON"
                ZStack {
                    SimpleSpriteImage(spriteKey, width: 28, height: 15)
                    if audioPlayer.repeatMode == .one {
                        Text("1")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 0)
                            .offset(x: 8, y: 0)
                    }
                }
            })
            .buttonStyle(.plain)
            .focusable(false)
            .help(audioPlayer.repeatMode.label)
            .at(Layout.repeatButton)
        }
    }

    // MARK: - Window Toggle Buttons

    @ViewBuilder
    private func buildWindowToggleButtons() -> some View {
        let coordinator = WindowCoordinator.shared
        let eqVisible = coordinator?.isEQWindowVisible ?? false
        let playlistVisible = coordinator?.isPlaylistWindowVisible ?? false

        Group {
            Button(action: { _ = coordinator?.toggleEQWindowVisibility() }, label: {
                SimpleSpriteImage(eqVisible ? "MAIN_EQ_BUTTON_SELECTED" : "MAIN_EQ_BUTTON", width: 23, height: 12)
            })
            .buttonStyle(.plain)
            .focusable(false)
            .at(Layout.eqButton)

            Button(action: { _ = coordinator?.togglePlaylistWindowVisibility() }, label: {
                SimpleSpriteImage(playlistVisible ? "MAIN_PLAYLIST_BUTTON_SELECTED" : "MAIN_PLAYLIST_BUTTON", width: 23, height: 12)
            })
            .buttonStyle(.plain)
            .focusable(false)
            .at(Layout.playlistButton)
        }
    }

    // MARK: - Clutter Bar

    @ViewBuilder
    private func buildClutterBarOAI() -> some View {
        Button(action: {
            optionsPresenter.showOptionsMenu(
                from: Layout.clutterButtonO,
                settings: settings,
                audioPlayer: audioPlayer,
                isDoubleSizeMode: settings.isDoubleSizeMode
            )
        }, label: {
            SimpleSpriteImage("MAIN_CLUTTER_BAR_BUTTON_O", width: 8, height: 8)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .help("Options menu (Ctrl+O, Ctrl+T for time)")
        .at(Layout.clutterButtonO)

        let aSprite = settings.isAlwaysOnTop ? "MAIN_CLUTTER_BAR_BUTTON_A_SELECTED" : "MAIN_CLUTTER_BAR_BUTTON_A"
        Button(action: { settings.isAlwaysOnTop.toggle() }, label: {
            SimpleSpriteImage(aSprite, width: 8, height: 7)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .help("Toggle always on top (Ctrl+A)")
        .at(Layout.clutterButtonA)

        let iSprite = settings.showTrackInfoDialog ? "MAIN_CLUTTER_BAR_BUTTON_I_SELECTED" : "MAIN_CLUTTER_BAR_BUTTON_I"
        Button(action: { settings.showTrackInfoDialog = true }, label: {
            SimpleSpriteImage(iSprite, width: 8, height: 7)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .help("Track information (Ctrl+I)")
        .at(Layout.clutterButtonI)
    }

    @ViewBuilder
    private func buildClutterBarDV() -> some View {
        let dSprite = settings.isDoubleSizeMode ? "MAIN_CLUTTER_BAR_BUTTON_D_SELECTED" : "MAIN_CLUTTER_BAR_BUTTON_D"
        Button(action: { settings.isDoubleSizeMode.toggle() }, label: {
            SimpleSpriteImage(dSprite, width: 8, height: 8)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .help("Toggle window size")
        .at(Layout.clutterButtonD)

        let vSprite = settings.showVideoWindow ? "MAIN_CLUTTER_BAR_BUTTON_V_SELECTED" : "MAIN_CLUTTER_BAR_BUTTON_V"
        Button(action: { settings.showVideoWindow.toggle() }, label: {
            SimpleSpriteImage(vSprite, width: 8, height: 7)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .help("Video Window (Ctrl+V)")
        .at(Layout.clutterButtonV)
    }
}
