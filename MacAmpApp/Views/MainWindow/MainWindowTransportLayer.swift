import SwiftUI

/// Transport playback buttons: previous, play, pause, stop, next, eject.
/// Separate View struct creates a recomposition boundary — only re-evaluates
/// when PlaybackCoordinator state actually used by these buttons changes.
struct MainWindowTransportLayer: View {
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator
    let openFileDialog: () -> Void

    private typealias Layout = WinampMainWindowLayout

    var body: some View {
        // Playback buttons
        Button(action: { Task { await playbackCoordinator.previous() } }, label: {
            SimpleSpriteImage("MAIN_PREVIOUS_BUTTON", width: 23, height: 18)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .at(Layout.prevButton)

        Button(action: { playbackCoordinator.togglePlayPause() }, label: {
            SimpleSpriteImage("MAIN_PLAY_BUTTON", width: 23, height: 18)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .at(Layout.playButton)

        Button(action: { playbackCoordinator.pause() }, label: {
            SimpleSpriteImage("MAIN_PAUSE_BUTTON", width: 23, height: 18)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .at(Layout.pauseButton)

        // Nav buttons
        Button(action: { playbackCoordinator.stop() }, label: {
            SimpleSpriteImage("MAIN_STOP_BUTTON", width: 23, height: 18)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .at(Layout.stopButton)

        Button(action: { Task { await playbackCoordinator.next() } }, label: {
            SimpleSpriteImage("MAIN_NEXT_BUTTON", width: 23, height: 18)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .at(Layout.nextButton)

        Button(action: { openFileDialog() }, label: {
            SimpleSpriteImage("MAIN_EJECT_BUTTON", width: 22, height: 16)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .at(Layout.ejectButton)
    }
}
