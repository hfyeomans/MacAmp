import SwiftUI

/// Volume, balance, and position sliders.
/// Only re-evaluates when volume/balance/progress or scrubbing state changes.
struct MainWindowSlidersLayer: View {
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator
    let interactionState: WinampMainWindowInteractionState

    private typealias Layout = WinampMainWindowLayout

    var body: some View {
        buildPositionSlider()
        buildVolumeSlider()
        buildBalanceSlider()
    }

    @ViewBuilder
    private func buildPositionSlider() -> some View {
        if audioPlayer.currentTrack != nil {
            ZStack(alignment: .topLeading) {
                SimpleSpriteImage("MAIN_POSITION_SLIDER_BACKGROUND", width: 248, height: 10)
                    .at(Layout.positionSlider)

                let currentProgress = interactionState.isScrubbing ? interactionState.scrubbingProgress : audioPlayer.playbackProgress
                SimpleSpriteImage("MAIN_POSITION_SLIDER_THUMB", width: 29, height: 10)
                    .at(CGPoint(x: Layout.positionSlider.x + (248 - 29) * currentProgress,
                               y: Layout.positionSlider.y))
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
                .frame(width: 248, height: 10)
                .at(Layout.positionSlider)
            }
        }
    }

    @ViewBuilder
    private func buildVolumeSlider() -> some View {
        let volumeBinding = Binding<Float>(
            get: { audioPlayer.volume },
            set: { playbackCoordinator.setVolume($0) }
        )
        WinampVolumeSlider(volume: volumeBinding)
            .at(Layout.volumeSlider)
    }

    @ViewBuilder
    private func buildBalanceSlider() -> some View {
        let balanceBinding = Binding<Float>(
            get: { audioPlayer.balance },
            set: { playbackCoordinator.setBalance($0) }
        )
        WinampBalanceSlider(balance: balanceBinding)
            .at(Layout.balanceSlider)
            .opacity(playbackCoordinator.supportsBalance ? 1.0 : 0.5)
            .allowsHitTesting(playbackCoordinator.supportsBalance)
            .help(playbackCoordinator.supportsBalance ? "Balance" : "Balance unavailable during streaming")
    }
}
