import SwiftUI

/// Play/pause indicator, mono/stereo, bitrate, and sample rate displays.
/// Only re-evaluates when playback state or audio metadata changes.
struct MainWindowIndicatorsLayer: View {
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator
    @Environment(AudioPlayer.self) private var audioPlayer
    let pauseBlinkVisible: Bool

    private typealias Layout = WinampMainWindowLayout

    var body: some View {
        // Play/Pause indicator
        buildPlayPauseIndicator()

        // Mono/Stereo indicator
        buildMonoStereoIndicator()

        // Bitrate display
        buildBitrateDisplay()

        // Sample rate display
        buildSampleRateDisplay()
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
            .at(Layout.playPauseIndicator)
    }

    @ViewBuilder
    private func buildMonoStereoIndicator() -> some View {
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
    private func buildBitrateDisplay() -> some View {
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
    private func buildSampleRateDisplay() -> some View {
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
}
