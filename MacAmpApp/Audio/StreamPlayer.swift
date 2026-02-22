@preconcurrency import AVFoundation
import Observation
import Combine

/// Plays internet radio streams using AVPlayer.
///
/// **Features:**
/// - HTTP/HTTPS stream playback
/// - HLS (.m3u8) adaptive streaming support
/// - ICY metadata extraction (SHOUTcast/Icecast)
/// - Buffering state detection
/// - Error handling for network issues
///
/// **Limitations:**
/// - No EQ support (AVPlayer cannot use AVAudioUnitEQ)
/// - For local files with EQ, use AudioPlayer instead
///
/// **Observable State:**
/// - `isPlaying` - Playback state
/// - `isBuffering` - Network buffering state
/// - `currentStation` - Currently playing station
/// - `streamTitle` - Live metadata (song title)
/// - `streamArtist` - Live metadata (artist name)
/// - `error` - Error message if stream fails
///
/// **Usage:**
/// Should be used via PlaybackCoordinator for proper coordination with AudioPlayer.
@MainActor
@Observable
final class StreamPlayer: NSObject, @preconcurrency AVPlayerItemMetadataOutputPushDelegate {
    // MARK: - State

    private(set) var isPlaying: Bool = false
    private(set) var isBuffering: Bool = false
    private(set) var currentStation: RadioStation?
    private(set) var streamTitle: String?
    private(set) var streamArtist: String?
    private(set) var error: String?

    /// Stream volume (0.0-1.0 linear amplitude, same scale as AVAudioPlayerNode.volume).
    /// Synced to the internal AVPlayer on every change.
    var volume: Float = 0.75 {
        didSet { player.volume = volume }
    }

    /// Stream balance (-1.0 left to 1.0 right). Stored but NOT applied —
    /// AVPlayer has no .pan property. Enables uniform propagation from
    /// PlaybackCoordinator without backend type checks. Will be applied
    /// when Phase 2 Loopback Bridge routes streams through AVAudioEngine.
    var balance: Float = 0.0

    // MARK: - AVPlayer

    let player = AVPlayer()  // Internal for PlaybackCoordinator resume access
    private var statusObserver: AnyCancellable?
    private var itemStatusObserver: AnyCancellable?
    private var currentMetadataOutput: AVPlayerItemMetadataOutput?

    // MARK: - Initialization

    override init() {
        super.init()
        setupObservers()
    }

    // MARK: - Playback Control

    /// Play a radio station (for favorites menu)
    func play(station: RadioStation) async {
        currentStation = station
        error = nil
        streamTitle = nil
        streamArtist = nil

        let playerItem = AVPlayerItem(url: station.streamURL)
        player.replaceCurrentItem(with: playerItem)

        setupMetadataObserver(for: playerItem)
        setupItemStatusObserver(for: playerItem)

        // Apply current volume before playback starts (persisted volume from UserDefaults)
        player.volume = volume

        player.play()
        isPlaying = true
    }

    /// Play a stream from URL (for playlist tracks)
    /// Preserves Track metadata (title/artist) until ICY metadata loads
    func play(url: URL, title: String? = nil, artist: String? = nil) async {
        // Create internal RadioStation for playback
        let station = RadioStation(
            name: title ?? url.host ?? "Internet Radio",
            streamURL: url
        )

        // Play the stream (play(station:) clears streamTitle/streamArtist)
        await play(station: station)

        // Reapply initial metadata if ICY hasn't arrived yet during connection
        if streamTitle == nil { streamTitle = title }
        if streamArtist == nil { streamArtist = artist }
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
        // Observe playback status (use RunLoop.main for @MainActor safety)
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
        // Cancel old observer before creating new one
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
        // Modern API: AVPlayerItemMetadataOutput with delegate (macOS 15+)
        let output = AVPlayerItemMetadataOutput(identifiers: nil)
        output.setDelegate(self, queue: DispatchQueue.main)
        item.add(output)
        currentMetadataOutput = output
    }

    // MARK: - AVPlayerItemMetadataOutputPushDelegate

    func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        // Since delegate queue is DispatchQueue.main and class is @MainActor, this is safe
        // Process metadata groups
        for group in groups {
            for item in group.items {
                // Modern API: load(.stringValue) - async, non-deprecated
                if item.commonKey == .commonKeyTitle {
                    Task { @MainActor in
                        if let title = try? await item.load(.stringValue) {
                            streamTitle = title
                        }
                    }
                } else if item.commonKey == .commonKeyArtist {
                    Task { @MainActor in
                        if let artist = try? await item.load(.stringValue) {
                            streamArtist = artist
                        }
                    }
                }
            }
        }
    }

    func metadataOutputSequenceWasFlushed(_ output: AVPlayerItemMetadataOutput) {
        // Clear stale metadata when the sequence resets
        streamTitle = nil
        streamArtist = nil
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
