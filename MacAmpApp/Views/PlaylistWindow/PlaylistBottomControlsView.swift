import SwiftUI

struct PlaylistBottomControlsView: View {
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator

    let windowWidth: CGFloat
    let windowHeight: CGFloat
    let menuPresenter: PlaylistMenuPresenter

    private var totalPlaylistDuration: Double {
        audioPlayer.playlist.reduce(0.0) { total, track in
            total + track.duration
        }
    }

    private var remainingTime: Double {
        guard audioPlayer.currentDuration > 0 else { return 0 }
        return max(0, audioPlayer.currentDuration - audioPlayer.currentTime)
    }

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private var trackTimeText: String {
        guard audioPlayer.currentTrack != nil,
              audioPlayer.currentDuration > 0 else {
            return ":"
        }

        let current = formatTime(audioPlayer.currentTime)
        let total = formatTime(totalPlaylistDuration)
        return "\(current) / \(total)"
    }

    private var remainingTimeText: String {
        guard audioPlayer.isPlaying,
              audioPlayer.currentTrack != nil,
              audioPlayer.currentDuration > 0 else {
            return ""
        }

        let remaining = formatTime(remainingTime)
        return "-\(remaining)"
    }

    var body: some View {
        buildMenuButtons()
        buildTransportButtons()
        buildTimeDisplays()
    }

    @ViewBuilder
    private func buildMenuButtons() -> some View {
        let buttonY = windowHeight - 24

        Button(action: { menuPresenter.showAddMenu() }, label: {
            Color.clear.frame(width: 22, height: 18).contentShape(Rectangle())
        }).buttonStyle(.plain).focusable(false).position(x: 16, y: buttonY)

        Button(action: { menuPresenter.showRemMenu() }, label: {
            Color.clear.frame(width: 22, height: 18).contentShape(Rectangle())
        }).buttonStyle(.plain).focusable(false).position(x: 42, y: buttonY)

        Button(action: { menuPresenter.showSelNotSupportedAlert() }, label: {
            Color.clear.frame(width: 18, height: 18).contentShape(Rectangle())
        }).buttonStyle(.plain).focusable(false).position(x: 78, y: buttonY)

        Button(action: { menuPresenter.showMiscMenu() }, label: {
            Color.clear.frame(width: 18, height: 18).contentShape(Rectangle())
        }).buttonStyle(.plain).focusable(false).position(x: 105, y: buttonY)

        Button(action: { menuPresenter.showListMenu() }, label: {
            Color.clear.frame(width: 22, height: 18).contentShape(Rectangle())
        }).buttonStyle(.plain).focusable(false).position(x: windowWidth - 32, y: buttonY)
    }

    @ViewBuilder
    private func buildTransportButtons() -> some View {
        let transportY = windowHeight - 12
        let baseX = windowWidth - 150 + 8

        transportButton(action: { Task { await playbackCoordinator.previous() } }, x: baseX, y: transportY)
        transportButton(action: { playbackCoordinator.togglePlayPause() }, x: baseX + 11, y: transportY)
        transportButton(action: { playbackCoordinator.pause() }, x: baseX + 22, y: transportY)
        transportButton(action: { playbackCoordinator.stop() }, x: baseX + 33, y: transportY)
        transportButton(action: { Task { await playbackCoordinator.next() } }, x: baseX + 44, y: transportY)
        transportButton(action: {
            PlaylistWindowActions.shared.presentAddFilesPanel(audioPlayer: audioPlayer, playbackCoordinator: playbackCoordinator)
        }, x: baseX + 50, y: transportY)
    }

    private func transportButton(action: @escaping () -> Void, x: CGFloat, y: CGFloat) -> some View {
        Button(action: action, label: {
            Color.clear.frame(width: 10, height: 9).contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: x, y: y)
    }

    @ViewBuilder
    private func buildTimeDisplays() -> some View {
        let rightSectionStart = windowWidth - 150
        let timeY1 = windowHeight - 26
        let timeY2 = windowHeight - 13

        PlaylistTimeText(trackTimeText)
            .position(x: rightSectionStart + 51, y: timeY1)

        if !remainingTimeText.isEmpty {
            PlaylistTimeText(remainingTimeText)
                .position(x: rightSectionStart + 78, y: timeY2)
        }
    }
}
