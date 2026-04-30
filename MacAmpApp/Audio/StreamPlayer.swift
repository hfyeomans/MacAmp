import Foundation
import Observation
import os

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

    // MARK: - Pipeline

    private let pipeline = StreamDecodePipeline()

    @ObservationIgnored private var ringBuffer: LockFreeRingBuffer?

    // MARK: - Elapsed Time (anchor-based, not accumulator — avoids timer drift)

    private(set) var elapsedTime: Double = 0
    @ObservationIgnored private var elapsedTimer: Timer?
    @ObservationIgnored private var elapsedAccumulated: Double = 0
    @ObservationIgnored private var elapsedStartedAt: ContinuousClock.Instant?

    // MARK: - Reconnect State

    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var reconnectAttempt: Int = 0
    @ObservationIgnored private var wasActivelyPlaying: Bool = false
    @ObservationIgnored private var playbackStableTask: Task<Void, Never>?

    private static let maxReconnectAttempts = 10
    private static let maxBackoffSeconds: Double = 16.0

    // MARK: - Pause / Resume State

    /// True between `pause()` and the next `resume()`/`play()`/`stop()`. Suppresses
    /// auto-reconnect in `handleTermination` so a socket death during pause stays paused.
    @ObservationIgnored private var userPaused: Bool = false

    /// Drained by `pipeline.onPrebufferReady`, the warmup timeout sub-task, or `cancelResumeWarmup`.
    @ObservationIgnored private var prebufferReadyContinuation: CheckedContinuation<Void, Never>?

    @ObservationIgnored private var resumeWarmupTask: Task<Void, Never>?

    /// Identity guard so a cancelled warmup's tail can't clobber `resumeWarmupTask` after a
    /// newer warmup has been assigned.
    @ObservationIgnored private var resumeWarmupGeneration: UInt64 = 0

    /// While true, the pipeline `.playing` callback skips the user-visible `isPlaying` flip
    /// — the warmup task owns that transition until the silence gate drops.
    @ObservationIgnored private var isResumeWarming: Bool = false

    /// Serial chain of async transport calls; prevents rapid pause/resume from racing.
    @ObservationIgnored private var pipelineTransportTask: Task<Void, Never>?

    /// Bumped on every session reset (`play`, `stop`, `handleTermination`, warmup-timeout fallback).
    /// `chainTransport` captures it and bails after `await prior?.value` if it changed —
    /// covers stale tasks that aren't the chain tail and so don't get cancelled.
    @ObservationIgnored private var transportGeneration: UInt64 = 0

    /// Set by `PlaybackCoordinator.init`; calls `AudioPlayer.setStreamSilenced` (engine no-ops
    /// when bridge is inactive, so this is safe to call any time).
    @ObservationIgnored var silenceGateForwarder: (@MainActor (Bool) -> Void)?

    // MARK: - Initialization

    init() {
        setupPipelineCallbacks()
    }

    isolated deinit {
        elapsedTimer?.invalidate()
        reconnectTask?.cancel()
        playbackStableTask?.cancel()
        resumeWarmupTask?.cancel()
        pipelineTransportTask?.cancel()
        pipeline.stop()
    }

    // MARK: - Playback Control

    func play(station: RadioStation) async {
        cancelReconnect()
        cancelResumeWarmup()
        pipelineTransportTask?.cancel()
        pipelineTransportTask = nil
        transportGeneration &+= 1                       // invalidate any in-flight chained transport
        resetElapsedTime()
        userPaused = false
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
        cancelResumeWarmup()
        cancelReconnect()
        stopElapsedTimer()
        userPaused = true
        silenceGateForwarder?(true)

        if case .connecting = pipeline.state {
            pipeline.stop()
        } else if case .buffering = pipeline.state {
            pipeline.stop()
        } else {
            // Chained so a rapid prior resume completes before this pause runs.
            chainTransport { [weak self] in
                await self?.pipeline.pauseByUser()
            }
        }

        isPlaying = false
        isBuffering = false
        // wasActivelyPlaying intentionally not cleared — needed for socket-death-during-pause.
    }

    func resume() {
        cancelResumeWarmup()
        userPaused = false

        // Set BEFORE chainTransport — resumeByUser will transition pipeline to .playing and we
        // need onStateChange to defer to the warmup task for the user-visible isPlaying flip.
        isResumeWarming = true
        isBuffering = true

        chainTransport { [weak self] in
            guard let self else { return }
            if Task.isCancelled || self.userPaused { return }

            switch self.pipeline.state {
            case .paused:
                // Arm warmup AFTER the resume barrier — earlier and `startResumeWarmup`'s
                // `availableFrames >= 8192` short-circuit would fire on stale pre-pause PCM.
                await self.pipeline.resumeByUser()
                if Task.isCancelled || self.userPaused { return }
                self.startResumeWarmup()

            case .idle, .error:
                // Pipeline torn down — bridge is guaranteed inactive in these states.
                // Fresh DecodeContext won't fire onPrebufferReady (it's for live-context
                // resume), so don't arm warmup; let onStateChange handle the .playing flip.
                if let station = self.currentStation {
                    let rb = LockFreeRingBuffer(capacity: 32768, channelCount: 2)
                    self.ringBuffer = rb
                    #if DEBUG
                    self.pipelineStartInvocationCountForTesting += 1
                    #endif
                    self.pipeline.start(url: station.streamURL, ringBuffer: rb)
                    self.isResumeWarming = false
                } else {
                    self.cancelResumeWarmup()
                    self.isBuffering = false              // resume()'s sync set is wrong without a station
                    self.onStreamStateChanged?()
                }

            case .connecting, .buffering, .playing:
                // Already alive — restarting would re-bind the engine to a new ring without
                // first deactivating the bridge, stranding render on the old (empty) ring.
                self.isResumeWarming = false
                // Drop the gate: a duplicate resume during warmup cancels the warmup before
                // its own gate-drop ran. (For first-play .connecting/.buffering this is a no-op.)
                self.silenceGateForwarder?(false)

                if case .playing = self.pipeline.state {
                    // No future state-change will clear isBuffering; do it here.
                    self.isBuffering = false
                    self.isPlaying = true
                    self.onStreamStateChanged?()
                }
            }
        }
    }

    func stop() {
        cancelReconnect()
        cancelResumeWarmup()
        pipelineTransportTask?.cancel()
        pipelineTransportTask = nil
        transportGeneration &+= 1                       // invalidate any in-flight chained transport
        resetElapsedTime()
        userPaused = false
        // Drop the gate in case stop() interrupted a paused state — otherwise a future
        // source-node reuse path would inherit a stuck-raised gate.
        silenceGateForwarder?(false)
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

    // MARK: - Audio Workgroup

    /// Forward the audio IO workgroup to the decode pipeline.
    /// Called by PlaybackCoordinator after bridge activation.
    func setAudioWorkgroup(_ workgroup: os_workgroup_t?) {
        pipeline.setAudioWorkgroup(workgroup)
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
                self.stopElapsedTimer()
            case .connecting, .buffering:
                self.isPlaying = false
                self.isBuffering = true
                self.stopElapsedTimer()
            case .playing:
                if self.isResumeWarming {
                    // Render is still gated; warmup owns the user-visible flip.
                    self.startPlaybackStableTimer()
                } else {
                    self.isPlaying = true
                    self.isBuffering = false
                    self.isReconnecting = false
                    self.wasActivelyPlaying = true
                    self.startPlaybackStableTimer()
                    self.startElapsedTimer()
                }
            case .paused:
                self.isPlaying = false
                self.isBuffering = false
                self.stopElapsedTimer()
            case .error:
                self.isPlaying = false
                self.isBuffering = false
                self.stopElapsedTimer()
            }
            self.onStreamStateChanged?()
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

        pipeline.onPrebufferReady = { [weak self] in
            guard let self else { return }
            if let pending = self.prebufferReadyContinuation {
                self.prebufferReadyContinuation = nil
                pending.resume()
            }
        }

        pipeline.onMetadata = { [weak self] (metadata: ICYFramer.ICYMetadata) in
            guard let self else { return }
            if let title = metadata.title {
                self.streamTitle = title
            }
            if let artist = metadata.artist {
                self.streamArtist = artist
            }

            // Note: Winamp classic does NOT reset elapsed time on ICY metadata change.
            // decode_pos_ms counts continuously from Play until Stop. ICY metadata
            // only updates the title display. (Verified from Winamp source: in_mp3/giofile.cpp)

            self.onMetadataChanged?()
        }
    }

    // MARK: - Elapsed Time Control

    private static func durationSeconds(_ d: Duration) -> Double {
        let (seconds, attoseconds) = d.components
        return Double(seconds) + Double(attoseconds) / 1_000_000_000_000_000_000
    }

    private func startElapsedTimer() {
        elapsedStartedAt = .now
        elapsedTimer?.invalidate()
        // .common run-loop mode keeps this firing during user gestures (.eventTracking).
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let startedAt = self.elapsedStartedAt else { return }
                let elapsed = Self.durationSeconds(startedAt.duration(to: .now))
                self.elapsedTime = self.elapsedAccumulated + elapsed
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        elapsedTimer = timer
    }

    private func stopElapsedTimer() {
        if let startedAt = elapsedStartedAt {
            elapsedAccumulated += Self.durationSeconds(startedAt.duration(to: .now))
            elapsedStartedAt = nil
            elapsedTime = elapsedAccumulated
        }
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func resetElapsedTime() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        elapsedTime = 0
        elapsedAccumulated = 0
        elapsedStartedAt = nil
    }

    // MARK: - Reconnect Logic

    private func handleTermination(_ reason: StreamDecodePipeline.StreamTerminationReason) {
        cancelResumeWarmup()
        // Must clear; otherwise a subsequent reconnect's .playing transition stays suppressed.
        isResumeWarming = false
        pipelineTransportTask?.cancel()
        pipelineTransportTask = nil
        transportGeneration &+= 1

        if userPaused {
            // No auto-reconnect during user pause. Bridge teardown is still required —
            // without it, `activateStreamBridge`'s `guard !isBridgeActive` blocks the
            // post-resume re-activation, stranding render on the dead ring.
            ringBuffer = nil
            isReconnecting = false
            onStreamTerminated?()
            // Skip onStreamStateChanged so Now Playing keeps "paused" instead of flickering "stopped".
            return
        }

        if wasActivelyPlaying && isReconnectable(reason) {
            attemptReconnect()
        } else {
            isReconnecting = false
            ringBuffer = nil
            let message = reason.userMessage
            if error == nil && !message.isEmpty {
                error = message
            }
            onStreamTerminated?()
            onStreamStateChanged?()
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
        isResumeWarming = false
        #if DEBUG
        attemptReconnectInvocationCountForTesting += 1
        #endif
        reconnectAttempt += 1
        guard reconnectAttempt <= Self.maxReconnectAttempts else {
            isReconnecting = false
            isBuffering = false
            ringBuffer = nil
            error = "Connection lost after \(Self.maxReconnectAttempts) attempts"
            onStreamTerminated?()
            onStreamStateChanged?()
            return
        }

        isReconnecting = true
        isBuffering = true
        error = nil

        // Tear down bridge (critical — new ring buffer needs new bridge activation)
        onStreamTerminated?()
        onStreamStateChanged?()

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

    // MARK: - Pause / Resume Helpers

    /// Serialize an async transport call onto the chain. The post-await `transportGeneration`
    /// guard catches stale tasks that aren't the chain tail and so don't get `cancel()`-ed.
    private func chainTransport(_ op: @escaping @MainActor @Sendable () async -> Void) {
        let prior = pipelineTransportTask
        let myGeneration = transportGeneration
        pipelineTransportTask = Task { @MainActor [weak self] in
            await prior?.value
            guard let self else { return }
            guard !Task.isCancelled, self.transportGeneration == myGeneration else { return }
            await op()
        }
    }

    /// Drain the continuation FIRST, then cancel — lets the child exit through its
    /// `withCheckedContinuation` instead of needing an `onCancel` handler.
    private func cancelResumeWarmup() {
        if let pending = prebufferReadyContinuation {
            prebufferReadyContinuation = nil
            pending.resume()
        }
        resumeWarmupTask?.cancel()
        resumeWarmupTask = nil
        isResumeWarming = false
        resumeWarmupGeneration &+= 1
    }

    /// Caller must ensure no prior warmup is in flight (every cancel site calls
    /// `cancelResumeWarmup()` first).
    private func startResumeWarmup() {
        cancelResumeWarmup()
        isResumeWarming = true

        resumeWarmupGeneration &+= 1
        let myGeneration = resumeWarmupGeneration
        resumeWarmupTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Don't nil `resumeWarmupTask` if a newer warmup has been assigned.
            @MainActor func clearTaskIfMine() {
                if self.resumeWarmupGeneration == myGeneration {
                    self.resumeWarmupTask = nil
                }
            }

            // Sibling task drains the continuation after 1s so the parent can't hang.
            // The generation guard prevents an older warmup's timeout from waking a newer one.
            let timeoutTask: Task<Void, Never> = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                guard self.resumeWarmupGeneration == myGeneration else { return }
                if let pending = self.prebufferReadyContinuation {
                    self.prebufferReadyContinuation = nil
                    pending.resume()
                }
            }

            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                if let rb = self.ringBuffer, rb.availableFrames >= 8192 {
                    cont.resume()
                    return
                }
                if let stale = self.prebufferReadyContinuation {
                    self.prebufferReadyContinuation = nil
                    stale.resume()
                }
                self.prebufferReadyContinuation = cont
            }

            timeoutTask.cancel()

            guard !Task.isCancelled, !self.userPaused else {
                clearTaskIfMine()
                return
            }

            let havePrebuffer = (self.ringBuffer?.availableFrames ?? 0) >= 8192

            if !havePrebuffer {
                self.isResumeWarming = false
                clearTaskIfMine()
                if let station = self.currentStation {
                    self.transportGeneration &+= 1
                    // Bridge teardown BEFORE fresh start — `activateStreamBridge` short-circuits
                    // on `!isBridgeActive`, otherwise the engine stays bound to the dead ring.
                    self.onStreamTerminated?()
                    let fresh = LockFreeRingBuffer(capacity: 32768, channelCount: 2)
                    self.ringBuffer = fresh
                    #if DEBUG
                    self.pipelineStartInvocationCountForTesting += 1
                    #endif
                    self.pipeline.start(url: station.streamURL, ringBuffer: fresh)
                } else {
                    self.isBuffering = false
                    self.onStreamStateChanged?()
                }
                return
            }

            self.silenceGateForwarder?(false)
            self.isBuffering = false
            self.isResumeWarming = false
            self.isPlaying = true
            self.startElapsedTimer()
            self.onStreamStateChanged?()
            clearTaskIfMine()
        }
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

    /// Called when ICY metadata updates streamTitle/streamArtist.
    /// PlaybackCoordinator uses this to update Now Playing info.
    var onMetadataChanged: (@MainActor () -> Void)?

    /// Called when stream transport state changes (connecting/buffering/playing/paused/error).
    /// PlaybackCoordinator uses this to update Now Playing playback state.
    var onStreamStateChanged: (@MainActor () -> Void)?

    #if DEBUG
    // MARK: - Test Seams (DEBUG only — never compiled into release builds)

    internal var isResumeWarmupActiveForTesting: Bool {
        guard let task = resumeWarmupTask else { return false }
        return !task.isCancelled
    }

    internal var hasPrebufferContinuationForTesting: Bool { prebufferReadyContinuation != nil }
    internal var isResumeWarmingForTesting: Bool { isResumeWarming }
    internal var userPausedForTesting: Bool { userPaused }
    internal var pipelineStateForTesting: StreamDecodePipeline.StreamState { pipeline.state }

    /// Counts every invocation of `attemptReconnect()` since process start.
    /// Used by `longPauseSuppressesReconnect` to assert no reconnect fires while paused.
    internal private(set) var attemptReconnectInvocationCountForTesting: Int = 0

    /// Counts every fresh `pipeline.start(...)` issued from `resume()`'s live-edge restart
    /// branch and from the warmup task's timeout fallback. Used by `longPauseSuppressesReconnect`
    /// to assert resume after socket-death produces a fresh start, not `dataTask.resume()`.
    internal private(set) var pipelineStartInvocationCountForTesting: Int = 0

    /// Test-only: inject a pipeline termination event without going through URLSession.
    /// Routes through `pipeline.onTermination` → `handleTermination` end-to-end.
    internal func injectPipelineTerminationForTesting(_ reason: StreamDecodePipeline.StreamTerminationReason) {
        pipeline.injectTerminationForTesting(reason)
    }

    /// Test-only: bypass full `play(station:)` pipeline by directly setting the active-play
    /// flag. Used to set up `longPauseSuppressesReconnect` without spinning up a real URLSession.
    internal func setWasActivelyPlayingForTesting(_ value: Bool) {
        wasActivelyPlaying = value
    }

    /// Test-only: set the current station without going through `play(station:)`.
    /// Used to drive `resume()`'s live-edge restart branch when pipeline.state is not `.paused`.
    internal func setCurrentStationForTesting(_ station: RadioStation) {
        currentStation = station
    }

    /// Test-only: drive `pipeline.state` directly. Used to verify `resume()` no-ops when the
    /// pipeline is already in `.playing` / `.connecting` / `.buffering`.
    internal func injectPipelineStateForTesting(_ state: StreamDecodePipeline.StreamState) {
        pipeline.setStateForTesting(state)
    }

    /// Await the current transport-chain tail. Deterministic alternative to `Task.yield()`
    /// loops in tests that need to observe state after chained `pause()`/`resume()` calls.
    internal func drainTransportChainForTesting() async {
        await pipelineTransportTask?.value
    }

    /// Await the current resume-warmup task if any. For tests that need to observe state
    /// after the warmup completes (or times out).
    internal func drainResumeWarmupForTesting() async {
        await resumeWarmupTask?.value
    }
    #endif
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
