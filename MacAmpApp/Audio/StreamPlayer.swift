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
/// - Automatic reconnection with exponential backoff on network errors
///
/// **Observable State:**
/// - `isPlaying` — Playback state
/// - `isBuffering` — Network buffering / prebuffering / reconnecting state
/// - `isReconnecting` — True during reconnect attempts
/// - `currentStation` — Currently playing station
/// - `streamTitle` — Live metadata (song title from ICY)
/// - `streamArtist` — Live metadata (artist name from ICY)
/// - `error` — Error message if stream fails permanently
///
/// **Usage:**
/// Should be used via PlaybackCoordinator for proper coordination with AudioPlayer.
@MainActor
@Observable
final class StreamPlayer {
    // MARK: - State

    private(set) var isPlaying: Bool = false
    private(set) var isBuffering: Bool = false
    private(set) var isReconnecting: Bool = false
    private(set) var currentStation: RadioStation?
    private(set) var streamTitle: String?
    private(set) var streamArtist: String?
    private(set) var error: String?

    /// Stream volume (0.0-1.0 linear amplitude).
    var volume: Float = 0.75

    /// Stream balance (-1.0 left to 1.0 right).
    var balance: Float = 0.0

    // MARK: - Pipeline

    private let pipeline = StreamDecodePipeline()

    @ObservationIgnored private var ringBuffer: LockFreeRingBuffer?

    // MARK: - Reconnect State

    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var reconnectAttempt: Int = 0
    @ObservationIgnored private var wasActivelyPlaying: Bool = false
    @ObservationIgnored private var playbackStableTask: Task<Void, Never>?

    private static let maxReconnectAttempts = 10
    private static let maxBackoffSeconds: Double = 16.0

    // MARK: - Initialization

    init() {
        setupPipelineCallbacks()
    }

    isolated deinit {
        reconnectTask?.cancel()
        playbackStableTask?.cancel()
        pipeline.stop()
    }

    // MARK: - Playback Control

    func play(station: RadioStation) async {
        cancelReconnect()
        wasActivelyPlaying = false
        currentStation = station
        error = nil
        streamTitle = nil
        streamArtist = nil

        let rb = LockFreeRingBuffer(capacity: 32768, channelCount: 2)
        ringBuffer = rb

        pipeline.start(url: station.streamURL, ringBuffer: rb)
    }

    func play(url: URL, title: String? = nil, artist: String? = nil) async {
        let station = RadioStation(
            name: title ?? url.host ?? "Internet Radio",
            streamURL: url
        )

        await play(station: station)

        if streamTitle == nil { streamTitle = title }
        if streamArtist == nil { streamArtist = artist }
    }

    func pause() {
        cancelReconnect()
        pipeline.pause()
        // Also stop the pipeline if it's mid-connect/buffer (pause is no-op in those states)
        if case .connecting = pipeline.state { pipeline.stop() }
        if case .buffering = pipeline.state { pipeline.stop() }
        isPlaying = false
        isBuffering = false
    }

    func resume() {
        pipeline.resume()
        isPlaying = true
    }

    func stop() {
        cancelReconnect()
        pipeline.stop()
        isPlaying = false
        isBuffering = false
        isReconnecting = false
        currentStation = nil
        streamTitle = nil
        streamArtist = nil
        error = nil
        ringBuffer = nil
        currentSampleRate = 0
        wasActivelyPlaying = false
    }

    // MARK: - Ring Buffer Access (for PlaybackCoordinator bridge lifecycle)

    var currentRingBuffer: LockFreeRingBuffer? { ringBuffer }

    private(set) var currentSampleRate: Float64 = 0

    // MARK: - Pipeline Callbacks

    private func setupPipelineCallbacks() {
        pipeline.onStateChange = { [weak self] (state: StreamDecodePipeline.StreamState) in
            guard let self else { return }
            switch state {
            case .idle:
                self.isPlaying = false
                self.isBuffering = false
                // Don't fire onStreamTerminated here — onTermination handles reconnect vs terminal
            case .connecting, .buffering:
                self.isPlaying = false
                self.isBuffering = true
            case .playing:
                self.isPlaying = true
                self.isBuffering = false
                self.isReconnecting = false
                self.wasActivelyPlaying = true
                self.startPlaybackStableTimer()
            case .paused:
                self.isPlaying = false
                self.isBuffering = false
            case .error:
                self.isPlaying = false
                self.isBuffering = false
                // Don't fire onStreamTerminated here — onTermination handles reconnect vs terminal
            }
        }

        pipeline.onTermination = { [weak self] reason in
            guard let self else { return }
            self.handleTermination(reason)
        }

        pipeline.onFormatReady = { [weak self] (sampleRate: Float64) in
            guard let self else { return }
            self.currentSampleRate = sampleRate
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

    // MARK: - Reconnect Logic

    private func handleTermination(_ reason: StreamDecodePipeline.StreamTerminationReason) {
        if wasActivelyPlaying && isReconnectable(reason) {
            attemptReconnect()
        } else {
            // Terminal failure — no reconnect
            isReconnecting = false
            ringBuffer = nil
            if error == nil {
                error = reason.userMessage
            }
            onStreamTerminated?()
        }
    }

    private func isReconnectable(_ reason: StreamDecodePipeline.StreamTerminationReason) -> Bool {
        switch reason {
        case .networkError(_, let code):
            // DNS resolution failure, bad URL — terminal (will never succeed on retry)
            let terminalCodes = [
                NSURLErrorCannotFindHost,     // -1003: hostname doesn't exist
                NSURLErrorUnsupportedURL,     // -1002: malformed URL
                NSURLErrorBadURL,             // -1000: invalid URL
            ]
            return !terminalCodes.contains(code)
        case .serverClosed, .httpServerError, .playlistResolutionFailed:
            return true
        case .httpClientError, .decodeError, .invalidResponse, .userStopped:
            return false
        }
    }

    private func attemptReconnect() {
        reconnectAttempt += 1
        guard reconnectAttempt <= Self.maxReconnectAttempts else {
            isReconnecting = false
            isBuffering = false
            error = "Connection lost after \(Self.maxReconnectAttempts) attempts"
            onStreamTerminated?()
            return
        }

        isReconnecting = true
        isBuffering = true
        error = nil

        // Tear down bridge (critical — new ring buffer needs new bridge activation)
        onStreamTerminated?()

        let attempt = reconnectAttempt
        reconnectTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let delay = min(Self.maxBackoffSeconds, pow(2.0, Double(attempt - 1)))
            AppLog.info(.audio, "StreamPlayer: Reconnect attempt \(attempt)/\(Self.maxReconnectAttempts) in \(delay)s")

            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return // Cancelled
            }

            guard !Task.isCancelled, let station = self.currentStation else { return }

            let rb = LockFreeRingBuffer(capacity: 32768, channelCount: 2)
            self.ringBuffer = rb
            self.pipeline.start(url: station.streamURL, ringBuffer: rb)
        }
    }

    private func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        playbackStableTask?.cancel()
        playbackStableTask = nil
        reconnectAttempt = 0
        isReconnecting = false
    }

    private func startPlaybackStableTimer() {
        playbackStableTask?.cancel()
        playbackStableTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return // Cancelled
            }
            guard let self, self.isPlaying else { return }
            // Stream has been stable for 5 seconds — reset reconnect counter
            if self.reconnectAttempt > 0 {
                AppLog.info(.audio, "StreamPlayer: Playback stable — reconnect counter reset")
            }
            self.reconnectAttempt = 0
        }
    }

    // MARK: - Callbacks (to PlaybackCoordinator)

    var onFormatReady: (@MainActor (Float64) -> Void)?

    /// Called when stream reaches a terminal state OR needs bridge teardown for reconnect.
    /// PlaybackCoordinator uses this to deactivate the engine bridge.
    var onStreamTerminated: (@MainActor () -> Void)?
}

// MARK: - StreamTerminationReason User Message

extension StreamDecodePipeline.StreamTerminationReason {
    /// User-facing error message for the main window display.
    /// Keep short — the Winamp title bar has limited space.
    var userMessage: String {
        switch self {
        case .networkError(_, let code):
            switch code {
            case NSURLErrorCannotFindHost: return "Host not found"
            case NSURLErrorTimedOut: return "Connection timed out"
            case NSURLErrorNetworkConnectionLost: return "Connection lost"
            case NSURLErrorNotConnectedToInternet: return "No internet connection"
            case NSURLErrorCannotConnectToHost: return "Cannot connect to server"
            default: return "Network error"
            }
        case .serverClosed: return "Stream ended"
        case .httpClientError(let code): return "HTTP error \(code)"
        case .httpServerError(let code): return "Server error \(code)"
        case .decodeError: return "Unsupported audio format"
        case .invalidResponse: return "Invalid server response"
        case .playlistResolutionFailed: return "Playlist not found"
        case .userStopped: return ""
        }
    }
}
