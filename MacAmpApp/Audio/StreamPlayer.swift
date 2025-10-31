import AVFoundation
import Observation
import Combine

@MainActor
@Observable
final class StreamPlayer {
    // MARK: - State

    private(set) var isPlaying: Bool = false
    private(set) var isBuffering: Bool = false
    private(set) var currentStation: RadioStation?
    private(set) var streamTitle: String?
    private(set) var streamArtist: String?
    private(set) var error: String?

    // MARK: - AVPlayer

    private let player = AVPlayer()
    private var statusObserver: AnyCancellable?
    private var itemStatusObserver: AnyCancellable?
    private var metadataObserver: AnyCancellable?
    private var timeObserver: Any?

    // MARK: - Initialization

    init() {
        setupObservers()
    }

    // MARK: - Playback Control

    func play(station: RadioStation) async {
        currentStation = station
        error = nil
        streamTitle = nil
        streamArtist = nil

        let playerItem = AVPlayerItem(url: station.streamURL)
        player.replaceCurrentItem(with: playerItem)

        setupMetadataObserver(for: playerItem)
        setupItemStatusObserver(for: playerItem)

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
        streamTitle = nil
        streamArtist = nil
        error = nil
    }

    // MARK: - Observers

    private func setupObservers() {
        // Observe playback status (Oracle: use RunLoop.main for @MainActor)
        statusObserver = player.publisher(for: \.timeControlStatus)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.handleStatusChange(status)
            }
    }

    private func handleStatusChange(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            isPlaying = true
            isBuffering = false
        case .paused:
            isPlaying = false
            isBuffering = false
        case .waitingToPlayAtSpecifiedRate:
            isBuffering = true
        @unknown default:
            break
        }
    }

    private func setupItemStatusObserver(for item: AVPlayerItem) {
        // Oracle: Cancel old observer before new one
        itemStatusObserver?.cancel()

        // Observe item status for error detection
        itemStatusObserver = item.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                if status == .failed {
                    self?.handlePlaybackError(item.error)
                }
            }
    }

    private func setupMetadataObserver(for item: AVPlayerItem) {
        // Oracle: Cancel old observer before new one
        metadataObserver?.cancel()

        // Observe timed metadata (ICY info from SHOUTcast)
        metadataObserver = item.publisher(for: \.timedMetadata)
            .receive(on: RunLoop.main)
            .sink { [weak self] metadata in
                self?.extractStreamMetadata(metadata)
            }
    }

    private func extractStreamMetadata(_ metadata: [AVMetadataItem]?) {
        guard let items = metadata else { return }

        // Oracle: Use commonKey and stringValue, not KVC
        for item in items {
            if item.commonKey == .commonKeyTitle,
               let title = item.stringValue {
                streamTitle = title
            }
            if item.commonKey == .commonKeyArtist,
               let artist = item.stringValue {
                streamArtist = artist
            }
        }
    }

    private func handlePlaybackError(_ playbackError: Error?) {
        if let playbackError {
            error = "Stream error: \(playbackError.localizedDescription)"
            isPlaying = false
            isBuffering = false
        }
    }

    // deinit is not needed - Combine cancellables clean up automatically
}
