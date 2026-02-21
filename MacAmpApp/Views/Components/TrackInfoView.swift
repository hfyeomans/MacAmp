import SwiftUI

/// Track information dialog showing metadata for the currently playing track
struct TrackInfoView: View {
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Track Information")
                .font(.headline)
                .padding(.top, 10)

            buildContent()

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 10)
        }
        .frame(minWidth: 350, minHeight: 200)
    }

    @ViewBuilder
    private func buildContent() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if audioPlayer.currentTrack != nil {
                buildLocalTrackInfo()
            } else if case .radioStation = playbackCoordinator.currentSource {
                buildStreamInfo()
            } else {
                Text("No track or stream loaded")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            }
        }
        .frame(minWidth: 300, maxWidth: 400)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func buildLocalTrackInfo() -> some View {
        if let title = audioPlayer.currentTrack?.title, !title.isEmpty {
            InfoRow(label: "Title:", value: title)
        }

        if let artist = audioPlayer.currentTrack?.artist, !artist.isEmpty {
            InfoRow(label: "Artist:", value: artist)
        }

        if audioPlayer.currentDuration > 0 {
            InfoRow(label: "Duration:", value: formatDuration(audioPlayer.currentDuration))
        }

        Divider()

        buildTechnicalDetails()

        if audioPlayer.bitrate == 0 && audioPlayer.sampleRate == 0 {
            Text("Limited metadata available")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func buildStreamInfo() -> some View {
        InfoRow(label: "Stream:", value: playbackCoordinator.displayTitle)

        Divider()

        buildTechnicalDetails()

        Text("Stream playback - some metadata may be unavailable")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 4)
    }

    @ViewBuilder
    private func buildTechnicalDetails() -> some View {
        if audioPlayer.bitrate > 0 {
            InfoRow(label: "Bitrate:", value: "\(audioPlayer.bitrate) kbps")
        }

        if audioPlayer.sampleRate > 0 {
            let khz = audioPlayer.sampleRate / 1000
            InfoRow(label: "Sample Rate:", value: "\(khz) kHz")
        }

        if audioPlayer.channelCount > 0 {
            let channelText = audioPlayer.channelCount == 1 ? "Mono" :
                            audioPlayer.channelCount == 2 ? "Stereo" :
                            "\(audioPlayer.channelCount) channels"
            InfoRow(label: "Channels:", value: channelText)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

/// Helper view for displaying label-value pairs
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12))
    }
}

#Preview {
    let audioPlayer = AudioPlayer()
    let streamPlayer = StreamPlayer()
    return TrackInfoView()
        .environment(audioPlayer)
        .environment(PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer))
}
