import Foundation
import Observation

/// Plays internet radio streams using a custom decode pipeline.
///
/// **Architecture:**
/// Replaces the previous AVPlayer-based implementation with a custom decode chain:
/// `URLSession → ICYFramer → AudioFileStreamParser → AudioConverterDecoder → LockFreeRingBuffer`
///
/// The decoded PCM feeds into AudioPlayer's AVAudioEngine via AVAudioSourceNode,
/// enabling EQ, visualization, and balance for streams — feature parity with local files.
///
/// **Features:**
/// - HTTP/HTTPS progressive stream playback (SHOUTcast/Icecast)
/// - MP3 and AAC decoding via AudioToolbox
/// - ICY metadata extraction (StreamTitle, StreamArtist)
/// - Buffering state detection with prebuffer threshold
/// - Error handling for network issues
///
/// **Observable State:**
/// - `isPlaying` — Playback state
/// - `isBuffering` — Network buffering / prebuffering state
/// - `currentStation` — Currently playing station
/// - `streamTitle` — Live metadata (song title from ICY)
/// - `streamArtist` — Live metadata (artist name from ICY)
/// - `error` — Error message if stream fails
///
/// **Usage:**
/// Should be used via PlaybackCoordinator for proper coordination with AudioPlayer.
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

    /// Stream volume (0.0-1.0 linear amplitude).
    /// With the unified pipeline, volume is applied via AVAudioEngine
    /// (AudioPlayer.volume didSet propagates to playerNode/streamSourceNode).
    /// This property is stored for PlaybackCoordinator.setVolume() propagation.
    var volume: Float = 0.75

    /// Stream balance (-1.0 left to 1.0 right).
    /// With the unified pipeline, balance is applied via AVAudioEngine
    /// (AudioPlayer.balance didSet propagates to playerNode/streamSourceNode.pan).
    var balance: Float = 0.0

    // MARK: - Pipeline

    private let pipeline = StreamDecodePipeline()

    /// The ring buffer shared between the pipeline (producer) and AudioPlayer's
    /// AVAudioSourceNode (consumer). Created per-stream, passed to pipeline on start.
    @ObservationIgnored private var ringBuffer: LockFreeRingBuffer?

    // MARK: - Initialization

    init() {
        setupPipelineCallbacks()
    }

    isolated deinit {
        pipeline.stop()
    }

    // MARK: - Playback Control

    /// Play a radio station (for favorites menu).
    func play(station: RadioStation) async {
        currentStation = station
        error = nil
        streamTitle = nil
        streamArtist = nil

        // Create a fresh ring buffer for this stream
        let rb = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        ringBuffer = rb

        pipeline.start(url: station.streamURL, ringBuffer: rb)
    }

    /// Play a stream from URL (for playlist tracks).
    /// Preserves Track metadata (title/artist) until ICY metadata loads.
    func play(url: URL, title: String? = nil, artist: String? = nil) async {
        let station = RadioStation(
            name: title ?? url.host ?? "Internet Radio",
            streamURL: url
        )

        await play(station: station)

        // Reapply initial metadata if ICY hasn't arrived yet
        if streamTitle == nil { streamTitle = title }
        if streamArtist == nil { streamArtist = artist }
    }

    func pause() {
        pipeline.pause()
        isPlaying = false
    }

    /// Resume a paused stream. Used by PlaybackCoordinator.togglePlayPause().
    func resume() {
        pipeline.resume()
        isPlaying = true
    }

    func stop() {
        pipeline.stop()
        isPlaying = false
        isBuffering = false
        currentStation = nil
        streamTitle = nil
        streamArtist = nil
        error = nil
        ringBuffer = nil
    }

    // MARK: - Ring Buffer Access (for PlaybackCoordinator bridge lifecycle)

    /// The current ring buffer, if a stream is active.
    /// PlaybackCoordinator passes this to AudioPlayer.activateStreamBridge().
    var currentRingBuffer: LockFreeRingBuffer? { ringBuffer }

    /// The detected sample rate from the current stream (for engine format configuration).
    var currentSampleRate: Float64 { pipeline.ringBuffer != nil ? 44100.0 : 0 }

    // MARK: - Pipeline Callbacks

    private func setupPipelineCallbacks() {
        pipeline.onStateChange = { [weak self] (state: StreamDecodePipeline.StreamState) in
            guard let self else { return }
            switch state {
            case .idle:
                self.isPlaying = false
                self.isBuffering = false
            case .connecting, .buffering:
                self.isPlaying = false
                self.isBuffering = true
            case .playing:
                self.isPlaying = true
                self.isBuffering = false
            case .paused:
                self.isPlaying = false
                self.isBuffering = false
            case .error(let message):
                self.isPlaying = false
                self.isBuffering = false
                self.error = message
            }
        }

        pipeline.onFormatReady = { [weak self] (sampleRate: Float64) in
            guard let self else { return }
            // PlaybackCoordinator will pick this up via onFormatReady callback
            // and call audioPlayer.activateStreamBridge(ringBuffer:sampleRate:)
            self.onFormatReady?(sampleRate)
        }

        pipeline.onMetadata = { [weak self] (metadata: ICYFramer.ICYMetadata) in
            guard let self else { return }
            if let title = metadata.title {
                self.streamTitle = title
            }
            if let artist = metadata.artist {
                self.streamArtist = artist
            }
        }
    }

    // MARK: - Callbacks (to PlaybackCoordinator)

    /// Called when audio format is detected and prebuffering is complete.
    /// PlaybackCoordinator uses this to activate the engine bridge.
    var onFormatReady: (@MainActor (Float64) -> Void)?
}
