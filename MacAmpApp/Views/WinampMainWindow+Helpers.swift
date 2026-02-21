import SwiftUI
import AppKit

// MARK: - Scrolling, Helpers, and Options Menu
// Extracted from WinampMainWindow to reduce type/file body length.

extension WinampMainWindow {

    // MARK: - Scrolling Animation

    func startScrolling() {
        guard scrollTimer == nil else { return }
        guard isViewVisible else { return }

        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [playbackCoordinator] _ in
            Task { @MainActor in
                let trackText = playbackCoordinator.displayTitle.isEmpty ? "MacAmp" : playbackCoordinator.displayTitle
                let textWidth = CGFloat(trackText.count * 5)
                let displayWidth = Coords.trackInfo.width

                if textWidth > displayWidth {
                    scrollOffset -= 5

                    if abs(scrollOffset) >= textWidth + 20 {
                        scrollOffset = displayWidth
                    }
                }
            }
        }
        if let timer = scrollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func resetScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        scrollOffset = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard self.isViewVisible else { return }
            self.startScrolling()
        }
    }

    // MARK: - Helper Functions

    func timeDigits(from seconds: Double) -> [Int] {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60

        return [
            minutes / 10,
            minutes % 10,
            secs / 10,
            secs % 10
        ]
    }

    func handlePositionDrag(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        if !isScrubbing {
            isScrubbing = true
            wasPlayingPreScrub = audioPlayer.isPlaying
            if wasPlayingPreScrub {
                audioPlayer.pause()
            }
        }

        let width = geometry.size.width
        let x = min(max(0, value.location.x), width)
        let progress = Double(x / width)

        scrubbingProgress = progress
    }

    func handlePositionDragEnd(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        let width = geometry.size.width
        let x = min(max(0, value.location.x), width)
        let progress = Double(x / width)

        scrubbingProgress = progress
        audioPlayer.seekToPercent(progress, resume: wasPlayingPreScrub)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isScrubbing = false
        }
    }

    // MARK: - View Builders (extracted for type_body_length)

    @ViewBuilder
    func buildTransportPlaybackButtons() -> some View {
        Button(action: { Task { await playbackCoordinator.previous() } }, label: {
            SimpleSpriteImage("MAIN_PREVIOUS_BUTTON", width: 23, height: 18)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .at(Coords.prevButton)

        Button(action: { playbackCoordinator.togglePlayPause() }, label: {
            SimpleSpriteImage("MAIN_PLAY_BUTTON", width: 23, height: 18)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .at(Coords.playButton)

        Button(action: { playbackCoordinator.pause() }, label: {
            SimpleSpriteImage("MAIN_PAUSE_BUTTON", width: 23, height: 18)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .at(Coords.pauseButton)
    }

    @ViewBuilder
    func buildTransportNavButtons() -> some View {
        Button(action: { playbackCoordinator.stop() }, label: {
            SimpleSpriteImage("MAIN_STOP_BUTTON", width: 23, height: 18)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .at(Coords.stopButton)

        Button(action: { Task { await playbackCoordinator.next() } }, label: {
            SimpleSpriteImage("MAIN_NEXT_BUTTON", width: 23, height: 18)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .at(Coords.nextButton)

        Button(action: { openFileDialog() }, label: {
            SimpleSpriteImage("MAIN_EJECT_BUTTON", width: 22, height: 16)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .at(Coords.ejectButton)
    }

    @ViewBuilder
    func buildShuffleRepeatButtons() -> some View {
        Group {
            Button(action: { audioPlayer.shuffleEnabled.toggle() }, label: {
                let spriteKey = audioPlayer.shuffleEnabled ? "MAIN_SHUFFLE_BUTTON_SELECTED" : "MAIN_SHUFFLE_BUTTON"
                SimpleSpriteImage(spriteKey, width: 47, height: 15)
            })
            .buttonStyle(.plain)
            .focusable(false)
            .at(Coords.shuffleButton)

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
            .at(Coords.repeatButton)
        }
    }

    @ViewBuilder
    func buildPositionSlider() -> some View {
        if audioPlayer.currentTrack != nil {
            ZStack(alignment: .topLeading) {
                SimpleSpriteImage("MAIN_POSITION_SLIDER_BACKGROUND", width: 248, height: 10)
                    .at(Coords.positionSlider)

                let currentProgress = isScrubbing ? scrubbingProgress : audioPlayer.playbackProgress
                SimpleSpriteImage("MAIN_POSITION_SLIDER_THUMB", width: 29, height: 10)
                    .at(CGPoint(x: Coords.positionSlider.x + (248 - 29) * currentProgress,
                               y: Coords.positionSlider.y))
                    .allowsHitTesting(false)

                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in handlePositionDrag(value, in: geo) }
                                .onEnded { value in handlePositionDragEnd(value, in: geo) }
                        )
                }
                .frame(width: 248, height: 10)
                .at(Coords.positionSlider)
            }
        }
    }

    @ViewBuilder
    func buildVolumeSlider() -> some View {
        @Bindable var player = audioPlayer
        WinampVolumeSlider(volume: $player.volume)
            .at(Coords.volumeSlider)
    }

    @ViewBuilder
    func buildBalanceSlider() -> some View {
        @Bindable var player = audioPlayer
        WinampBalanceSlider(balance: $player.balance)
            .at(Coords.balanceSlider)
    }

    @ViewBuilder
    func buildWindowToggleButtons() -> some View {
        let coordinator = WindowCoordinator.shared
        let eqVisible = coordinator?.isEQWindowVisible ?? false
        let playlistVisible = coordinator?.isPlaylistWindowVisible ?? false

        Group {
            Button(action: { _ = coordinator?.toggleEQWindowVisibility() }, label: {
                SimpleSpriteImage(eqVisible ? "MAIN_EQ_BUTTON_SELECTED" : "MAIN_EQ_BUTTON", width: 23, height: 12)
            })
            .buttonStyle(.plain)
            .focusable(false)
            .at(Coords.eqButton)

            Button(action: { _ = coordinator?.togglePlaylistWindowVisibility() }, label: {
                SimpleSpriteImage(playlistVisible ? "MAIN_PLAYLIST_BUTTON_SELECTED" : "MAIN_PLAYLIST_BUTTON", width: 23, height: 12)
            })
            .buttonStyle(.plain)
            .focusable(false)
            .at(Coords.playlistButton)
        }
    }

    @ViewBuilder
    func buildClutterBarOAI() -> some View {
        Button(action: { showOptionsMenu(from: Coords.clutterButtonO) }, label: {
            SimpleSpriteImage("MAIN_CLUTTER_BAR_BUTTON_O", width: 8, height: 8)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .help("Options menu (Ctrl+O, Ctrl+T for time)")
        .at(Coords.clutterButtonO)

        let aSprite = settings.isAlwaysOnTop ? "MAIN_CLUTTER_BAR_BUTTON_A_SELECTED" : "MAIN_CLUTTER_BAR_BUTTON_A"
        Button(action: { settings.isAlwaysOnTop.toggle() }, label: {
            SimpleSpriteImage(aSprite, width: 8, height: 7)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .help("Toggle always on top (Ctrl+A)")
        .at(Coords.clutterButtonA)

        let iSprite = settings.showTrackInfoDialog ? "MAIN_CLUTTER_BAR_BUTTON_I_SELECTED" : "MAIN_CLUTTER_BAR_BUTTON_I"
        Button(action: { settings.showTrackInfoDialog = true }, label: {
            SimpleSpriteImage(iSprite, width: 8, height: 7)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .help("Track information (Ctrl+I)")
        .at(Coords.clutterButtonI)
    }

    @ViewBuilder
    func buildClutterBarDV() -> some View {
        let dSprite = settings.isDoubleSizeMode ? "MAIN_CLUTTER_BAR_BUTTON_D_SELECTED" : "MAIN_CLUTTER_BAR_BUTTON_D"
        Button(action: { settings.isDoubleSizeMode.toggle() }, label: {
            SimpleSpriteImage(dSprite, width: 8, height: 8)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .help("Toggle window size")
        .at(Coords.clutterButtonD)

        let vSprite = settings.showVideoWindow ? "MAIN_CLUTTER_BAR_BUTTON_V_SELECTED" : "MAIN_CLUTTER_BAR_BUTTON_V"
        Button(action: { settings.showVideoWindow.toggle() }, label: {
            SimpleSpriteImage(vSprite, width: 8, height: 7)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .help("Video Window (Ctrl+V)")
        .at(Coords.clutterButtonV)
    }

    @ViewBuilder
    func buildTrackInfoDisplay() -> some View {
        let trackText = playbackCoordinator.displayTitle.isEmpty ? "MacAmp" : playbackCoordinator.displayTitle
        let textWidth = trackText.count * 5
        let displayWidth = Int(Coords.trackInfo.width)

        if textWidth > displayWidth {
            HStack(spacing: 0) {
                buildTextSprites(for: trackText)
                    .offset(x: scrollOffset, y: -2)
                    .onAppear { startScrolling() }
                    .onChange(of: playbackCoordinator.displayTitle) { _, _ in resetScrolling() }
            }
            .frame(width: Coords.trackInfo.width, height: Coords.trackInfo.height)
            .clipped()
            .at(CGPoint(x: Coords.trackInfo.minX, y: Coords.trackInfo.minY))
        } else {
            buildTextSprites(for: trackText)
                .offset(y: -2)
                .frame(width: Coords.trackInfo.width, height: Coords.trackInfo.height, alignment: .leading)
                .at(CGPoint(x: Coords.trackInfo.minX, y: Coords.trackInfo.minY))
        }
    }

    @ViewBuilder
    func buildTextSprites(for text: String) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(text.uppercased().enumerated()), id: \.offset) { _, character in
                let charCode: UInt8 = {
                    if let ascii = character.asciiValue {
                        return character.isLetter && character.isUppercase ? ascii + 32 : ascii
                    }
                    return 32
                }()
                SimpleSpriteImage("CHARACTER_\(charCode)", width: 5, height: 6)
            }
        }
    }

    @ViewBuilder
    func buildMonoStereoIndicator() -> some View {
        ZStack {
            let hasTrack = audioPlayer.currentTrack != nil
            SimpleSpriteImage(hasTrack && audioPlayer.channelCount == 1 ? "MAIN_MONO_SELECTED" : "MAIN_MONO",
                            width: 27, height: 12)
                .at(x: 212, y: 41)
            SimpleSpriteImage(hasTrack && audioPlayer.channelCount == 2 ? "MAIN_STEREO_SELECTED" : "MAIN_STEREO",
                            width: 29, height: 12)
                .at(x: 239, y: 41)
        }
    }

    @ViewBuilder
    func buildBitrateDisplay() -> some View {
        if audioPlayer.currentTrack != nil && audioPlayer.bitrate > 0 {
            let bitrateText = "\(audioPlayer.bitrate)"
            HStack(spacing: 0) {
                ForEach(Array(bitrateText.enumerated()), id: \.offset) { _, character in
                    if let ascii = character.asciiValue {
                        SimpleSpriteImage("CHARACTER_\(ascii)", width: 5, height: 6)
                    }
                }
            }
            .at(x: 111, y: 43)
        }
    }

    @ViewBuilder
    func buildSampleRateDisplay() -> some View {
        if audioPlayer.currentTrack != nil && audioPlayer.sampleRate > 0 {
            let sampleRateText = "\(audioPlayer.sampleRate / 1000)"
            HStack(spacing: 0) {
                ForEach(Array(sampleRateText.enumerated()), id: \.offset) { _, character in
                    if let ascii = character.asciiValue {
                        SimpleSpriteImage("CHARACTER_\(ascii)", width: 5, height: 6)
                    }
                }
            }
            .at(x: 156, y: 43)
        }
    }

    @ViewBuilder
    func buildSpectrumAnalyzer() -> some View {
        VisualizerView()
            .frame(width: VisualizerLayout.width, height: VisualizerLayout.height)
            .background(Color.black.opacity(0.5))
            .at(Coords.spectrumAnalyzer)
    }

    // MARK: - Options Menu (O Button)

    func showOptionsMenu(from buttonPosition: CGPoint) {
        let menu = NSMenu()
        activeOptionsMenu = menu

        buildOptionsMenuItems(menu: menu)

        let mainWindow = NSApp.windows.first { window in
            return window.isVisible && !window.isMiniaturized &&
                   (window.frame.width == WinampSizes.main.width ||
                    window.frame.width == WinampSizes.main.width * 2)
        } ?? NSApp.keyWindow

        if let window = mainWindow {
            let scale: CGFloat = settings.isDoubleSizeMode ? 2.0 : 1.0
            let screenPoint = NSPoint(
                x: window.frame.minX + (buttonPosition.x * scale),
                y: window.frame.maxY - ((buttonPosition.y + 8) * scale)
            )
            menu.popUp(positioning: nil, at: screenPoint, in: nil)
        }
    }

    private func buildOptionsMenuItems(menu: NSMenu) {
        // Time display mode items
        menu.addItem(createMenuItem(
            title: "Time: Elapsed",
            isChecked: settings.timeDisplayMode == .elapsed,
            action: { [weak settings] in
                if settings?.timeDisplayMode != .elapsed {
                    settings?.toggleTimeDisplayMode()
                }
            }
        ))

        menu.addItem(createMenuItem(
            title: "Time: Remaining",
            isChecked: settings.timeDisplayMode == .remaining,
            action: { [weak settings] in
                if settings?.timeDisplayMode != .remaining {
                    settings?.toggleTimeDisplayMode()
                }
            }
        ))

        menu.addItem(.separator())

        menu.addItem(createMenuItem(
            title: "Double Size",
            isChecked: settings.isDoubleSizeMode,
            keyEquivalent: "d",
            modifiers: .control,
            action: { [weak settings] in
                settings?.isDoubleSizeMode.toggle()
            }
        ))

        buildRepeatShuffleMenuItems(menu: menu)
    }

    private func buildRepeatShuffleMenuItems(menu: NSMenu) {
        menu.addItem(createMenuItem(
            title: "Repeat: Off",
            isChecked: audioPlayer.repeatMode == .off,
            action: { [weak audioPlayer] in
                audioPlayer?.repeatMode = .off
            }
        ))

        menu.addItem(createMenuItem(
            title: "Repeat: All",
            isChecked: audioPlayer.repeatMode == .all,
            action: { [weak audioPlayer] in
                audioPlayer?.repeatMode = .all
            }
        ))

        menu.addItem(createMenuItem(
            title: "Repeat: One",
            isChecked: audioPlayer.repeatMode == .one,
            keyEquivalent: "r",
            modifiers: .control,
            action: { [weak audioPlayer] in
                audioPlayer?.repeatMode = .one
            }
        ))

        menu.addItem(createMenuItem(
            title: "Shuffle",
            isChecked: audioPlayer.shuffleEnabled,
            keyEquivalent: "s",
            modifiers: .control,
            action: { [weak audioPlayer] in
                audioPlayer?.shuffleEnabled.toggle()
            }
        ))
    }

    @MainActor
    private func createMenuItem(
        title: String,
        isChecked: Bool,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = [],
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: keyEquivalent)
        item.state = isChecked ? .on : .off
        item.keyEquivalentModifierMask = modifiers

        let actionTarget = MenuItemTarget(action: action)
        item.target = actionTarget
        item.action = #selector(MenuItemTarget.execute)
        item.representedObject = actionTarget

        return item
    }
}

/// Helper class to bridge closures to NSMenuItem actions
@MainActor
private class MenuItemTarget: NSObject {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func execute() {
        action()
    }
}
