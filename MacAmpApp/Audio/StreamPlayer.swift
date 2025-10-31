import AVFoundation
import Observation

@MainActor
@Observable
final class StreamPlayer {
    // MARK: - State

    private(set) var isPlaying: Bool = false
    private(set) var isBuffering: Bool = false
    private(set) var currentStation: RadioStation?

    // MARK: - AVPlayer

    private let player = AVPlayer()

    // MARK: - Initialization

    init() {
        // Basic initialization
        // Observers will be added in next commit
    }

    // MARK: - Playback Control

    func play(station: RadioStation) async {
        currentStation = station

        let playerItem = AVPlayerItem(url: station.streamURL)
        player.replaceCurrentItem(with: playerItem)

        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        currentStation = nil
    }

    deinit {
        player.pause()
    }
}
