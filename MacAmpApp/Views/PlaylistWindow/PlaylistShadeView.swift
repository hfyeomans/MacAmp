import SwiftUI

struct PlaylistShadeView: View {
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator

    let windowWidth: CGFloat
    let isWindowActive: Bool
    let onMinimize: () -> Void
    let onShadeToggle: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            let suffix = isWindowActive ? "_SELECTED" : ""
            SimpleSpriteImage("PLAYLIST_TITLE_BAR\(suffix)", width: 275, height: 14)
                .frame(width: windowWidth, height: 14)
                .position(x: windowWidth / 2, y: 7)

            if let currentTrack = playbackCoordinator.currentTrack {
                Text("\(currentTrack.title) - \(currentTrack.artist)")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: windowWidth - 75)
                    .position(x: (windowWidth - 75) / 2, y: 7)
            } else {
                Text("Winamp Playlist")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                    .position(x: (windowWidth - 75) / 2, y: 7)
            }

            PlaylistTitleBarButtons(
                windowWidth: windowWidth,
                onMinimize: onMinimize,
                onShadeToggle: onShadeToggle,
                onClose: onClose
            )
        }
        .frame(width: windowWidth, height: 14)
    }
}
