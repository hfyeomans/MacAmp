
import SwiftUI

struct PlaylistWindowView: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer

    var body: some View {
        let style = skinManager.currentSkin?.playlistStyle
        let bgColor = style?.backgroundColor ?? .black
        let normalText = style?.normalTextColor ?? .white
        let currentText = style?.currentTextColor ?? .white
        let selectedBG = style?.selectedBackgroundColor ?? Color.blue.opacity(0.5)
        let textFont: Font = {
            if let name = style?.fontName { return .custom(name, size: 12) }
            return .system(size: 12)
        }()

        return VStack(spacing: 0) {
            Text("Playlist Editor")
                .font(.headline)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(normalText)
                .background(bgColor)

            List(audioPlayer.playlist) { track in
                Text("\(track.title) - \(track.artist)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(track == audioPlayer.currentTrack ? currentText : normalText)
                    .font(textFont)
                    .contentShape(Rectangle())
                    .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                    .listRowBackground(track == audioPlayer.currentTrack ? selectedBG : bgColor)
                    .onTapGesture { audioPlayer.playTrack(track: track) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(bgColor)
        }
        .frame(width: WindowSpec.playlist.size.width, height: WindowSpec.playlist.size.height)
        .background(WindowAccessor { window in
            WindowSnapManager.shared.register(window: window, kind: .playlist)
        })
    }
}

#Preview {
    PlaylistWindowView()
}
