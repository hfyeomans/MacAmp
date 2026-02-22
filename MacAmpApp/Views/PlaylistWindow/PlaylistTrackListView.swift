import SwiftUI

struct PlaylistTrackListView: View {
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator

    let sizeState: PlaylistWindowSizeState
    let playlistStyle: PlaylistStyle
    @Binding var scrollOffset: Int
    let onTrackTap: (Int) -> Void
    let selectedIndices: Set<Int>

    var body: some View {
        let trackWidth = sizeState.contentWidth
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(audioPlayer.playlist.enumerated()), id: \.element.id) { index, track in
                        trackRow(track: track, index: index)
                            .frame(width: trackWidth, height: 13)
                            .background(trackBackground(track: track, index: index))
                            .id(index)
                            .onTapGesture(count: 2) {
                                Task { await playbackCoordinator.play(track: track) }
                            }
                            .onTapGesture { onTrackTap(index) }
                    }
                }
            }
            .onChange(of: scrollOffset) { _, newOffset in
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(newOffset, anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    private func trackRow(track: Track, index: Int) -> some View {
        let textColor = trackTextColor(track: track)
        HStack(spacing: 2) {
            Text("\(index + 1).")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(textColor)
                .frame(width: 18, alignment: .trailing)

            Text("\(track.title) - \(track.artist)")
                .font(.system(size: 9))
                .foregroundColor(textColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            Text(formatDuration(track.duration))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(textColor)
                .frame(width: 38, alignment: .trailing)
                .padding(.trailing, 3)
        }
        .padding(.horizontal, 2)
    }

    private func trackTextColor(track: Track) -> Color {
        if let currentTrack = playbackCoordinator.currentTrack, currentTrack.url == track.url {
            return playlistStyle.currentTextColor
        }
        return playlistStyle.normalTextColor
    }

    private func trackBackground(track: Track, index: Int) -> Color {
        if selectedIndices.contains(index) {
            return playlistStyle.selectedBackgroundColor.opacity(0.6)
        }
        return Color.clear
    }

    private func formatDuration(_ duration: Double) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
