import Foundation
import Observation

/// Coordinates playback between local files (AudioPlayer) and internet radio streams (StreamPlayer).
///
/// This coordinator prevents both backends from playing simultaneously, which would cause audio chaos.
/// It provides a unified API for the UI to play content regardless of source type.
///
/// **Architecture:**
/// - Local files (.mp3, .flac, etc.) → AudioPlayer with 10-band EQ
/// - Internet radio (http://, https://) → StreamPlayer (AVPlayer, no EQ)
///
/// **Usage:**
/// ```swift
/// // Play a file URL
/// await coordinator.play(url: fileURL)
///
/// // Play a radio station
/// await coordinator.play(station: myStation)
///
/// // Unified controls
/// coordinator.pause()
/// coordinator.stop()
/// coordinator.togglePlayPause()
/// ```
///
/// **State Queries:**
/// - `streamTitle` - Current track/stream title
/// - `streamArtist` - Stream artist (radio only)
/// - `isBuffering` - Buffering state (radio only)
/// - `error` - Error message if playback failed
@MainActor
@Observable
final class PlaybackCoordinator {
    // MARK: - Dependencies

    private let audioPlayer: AudioPlayer       // Local files with EQ
    private let streamPlayer: StreamPlayer     // Internet radio

    // MARK: - Unified State

    /// Derived from the active audio source. True when audio is actively rendering to speakers.
    /// During stream buffering stalls, this returns false (audio is not being rendered).
    var isPlaying: Bool {
        switch currentSource {
        case .localTrack: return audioPlayer.isPlaying
        case .radioStation: return streamPlayer.isPlaying && !streamPlayer.isBuffering
        case .none: return false
        }
    }

    /// Derived from the active audio source. True when user has explicitly paused playback.
    /// False during buffering stalls (not user-initiated) and error states.
    var isPaused: Bool {
        switch currentSource {
        case .localTrack: return audioPlayer.isPaused
        case .radioStation:
            return !streamPlayer.isPlaying && !streamPlayer.isBuffering && streamPlayer.error == nil
        case .none: return false
        }
    }

    private(set) var currentSource: PlaybackSource?
    private(set) var currentTitle: String?
    private(set) var currentTrack: Track?  // For playlist position tracking

    enum PlaybackSource {
        case localTrack(URL)
        case radioStation(RadioStation)
    }

    // MARK: - Loopback Bridge (Phase 2)

    /// Shared ring buffer for MTAudioProcessingTap → AVAudioSourceNode transfer.
    /// Created during setupLoopbackBridge(), released during teardownLoopbackBridge().
    private var bridgeRingBuffer: LockFreeRingBuffer?

    // MARK: - Capability Flags

    /// Whether the stream backend is currently active (playing, paused, or buffering).
    /// Uses `currentSource` rather than `currentTrack?.isStream` because `currentTrack`
    /// can be nil when playing a station directly via `play(station:)`.
    /// Returns false when the stream is in an error state (no audio rendering),
    /// which re-enables EQ/balance controls so the user isn't stuck with dimmed UI.
    private var isStreamBackendActive: Bool {
        guard case .radioStation = currentSource else { return false }
        // Stream in error state is effectively inactive — re-enable controls
        return streamPlayer.error == nil
    }

    /// EQ available for local files always, and for streams when bridge is active (2.5).
    var supportsEQ: Bool { !isStreamBackendActive || audioPlayer.isBridgeActive }

    /// Balance available for local files always, and for streams when bridge is active (2.5).
    var supportsBalance: Bool { !isStreamBackendActive || audioPlayer.isBridgeActive }

    /// Visualizer available for local files always, and for streams when bridge is active (2.5).
    var supportsVisualizer: Bool { !isStreamBackendActive || audioPlayer.isBridgeActive }

    // MARK: - Initialization

    init(audioPlayer: AudioPlayer, streamPlayer: StreamPlayer) {
        self.audioPlayer = audioPlayer
        self.streamPlayer = streamPlayer

        // Sync persisted volume/balance to stream player so first stream play uses saved values
        streamPlayer.volume = audioPlayer.volume
        streamPlayer.balance = audioPlayer.balance

        self.audioPlayer.onTrackMetadataUpdate = { [weak self] track in
            guard let self else { return }
            self.updateTrackMetadata(track)
        }

        self.audioPlayer.onPlaylistAdvanceRequest = { [weak self] track in
            guard let self else { return }
            Task { @MainActor in
                await self.handleExternalPlaylistAdvance(track: track)
            }
        }
    }

    // MARK: - Loopback Bridge Lifecycle (2.4c)

    /// Tear down the loopback bridge. MUST be called BEFORE setupLoopbackBridge()
    /// to quiesce the producer before flushing the ring buffer (lesson #5).
    private func teardownLoopbackBridge() {
        streamPlayer.detachLoopbackTap()
        audioPlayer.deactivateStreamBridge()
        bridgeRingBuffer = nil
    }

    /// Set up the loopback bridge ring buffer. The tap is attached separately
    /// after stream play starts, and the engine bridge activates when tapPrepare fires.
    private func setupLoopbackBridge() {
        let ringBuffer = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        bridgeRingBuffer = ringBuffer
    }

    /// Attach the loopback tap to the current stream and wire up format-ready callback.
    /// Called after stream play() and setupLoopbackBridge().
    private func attachBridgeTap() async {
        guard let ringBuffer = bridgeRingBuffer else { return }

        await streamPlayer.attachLoopbackTap(
            ringBuffer: ringBuffer,
            onFormatReady: { [weak self, weak ringBuffer] sampleRate in
                // tapPrepare is NOT real-time — safe to dispatch to main
                Task { @MainActor [weak self] in
                    // Gate: verify this callback's ring buffer is still the active one
                    // (prevents stale stream A callback from activating on stream B's buffer)
                    guard let self,
                          let rb = self.bridgeRingBuffer,
                          rb === ringBuffer else { return }
                    self.audioPlayer.activateStreamBridge(ringBuffer: rb, sampleRate: sampleRate)
                }
            }
        )
    }

    // MARK: - Volume & Balance Routing

    /// Propagate volume to ALL backends unconditionally.
    /// Simpler than checking which is active, zero cost on idle players (no-op).
    func setVolume(_ vol: Float) {
        audioPlayer.volume = vol
        streamPlayer.volume = vol
        audioPlayer.videoPlaybackController.volume = vol
    }

    /// Propagate balance to ALL backends unconditionally.
    /// StreamPlayer stores balance but cannot apply it (no AVPlayer .pan property).
    func setBalance(_ bal: Float) {
        audioPlayer.balance = bal
        streamPlayer.balance = bal
    }

    // MARK: - Unified Playback Control

    func play(url: URL) async {
        if url.isFileURL {
            // STREAM → LOCAL: tear down bridge, stop stream
            teardownLoopbackBridge()
            streamPlayer.stop()

            // Play local file with EQ
            audioPlayer.addTrack(url: url)
            audioPlayer.play()
            currentSource = .localTrack(url)
            currentTitle = formattedLocalDisplayTitle(
                trackTitle: url.deletingPathExtension().lastPathComponent,
                trackArtist: "",
                url: url
            )
        } else {
            // ALWAYS teardown before setup (lesson #5: ring buffer race)
            teardownLoopbackBridge()
            audioPlayer.stop()
            streamPlayer.stop()

            // Setup bridge → play stream → attach tap
            setupLoopbackBridge()
            let station = RadioStation(name: url.lastPathComponent, streamURL: url)
            await streamPlayer.play(station: station)
            currentSource = .radioStation(station)
            currentTitle = streamPlayer.streamTitle ?? station.name
            await attachBridgeTap()
        }
    }

    /// Play a track from the playlist (supports both local files and streams)
    func play(track: Track) async {
        audioPlayer.updatePlaylistPosition(with: track)
        currentTrack = track

        if track.isStream {
            // ALWAYS teardown before setup (lesson #5: ring buffer race)
            teardownLoopbackBridge()
            audioPlayer.stop()
            streamPlayer.stop()

            // Setup bridge → play stream → attach tap
            setupLoopbackBridge()
            await streamPlayer.play(url: track.url, title: track.title, artist: track.artist)
            currentSource = .radioStation(RadioStation(name: track.title, streamURL: track.url))
            currentTitle = track.title
            await attachBridgeTap()
        } else {
            // STREAM → LOCAL: tear down bridge, stop stream
            teardownLoopbackBridge()
            streamPlayer.stop()

            // Play local file via AudioPlayer
            audioPlayer.playTrack(track: track)
            updateLocalPlaybackState(for: track)
        }
    }

    /// Play a radio station from favorites menu
    func play(station: RadioStation) async {
        // ALWAYS teardown before setup (lesson #5: ring buffer race)
        teardownLoopbackBridge()
        audioPlayer.stop()
        streamPlayer.stop()

        // Setup bridge → play stream → attach tap
        setupLoopbackBridge()
        await streamPlayer.play(station: station)
        currentSource = .radioStation(station)
        currentTitle = streamPlayer.streamTitle ?? station.name
        currentTrack = nil  // Not from playlist
        await attachBridgeTap()
    }

    func pause() {
        switch currentSource {
        case .localTrack:
            audioPlayer.pause()
        case .radioStation:
            streamPlayer.pause()
        case .none:
            break
        }
    }

    func stop() {
        teardownLoopbackBridge()
        audioPlayer.stop()
        streamPlayer.stop()
        currentSource = nil
        currentTitle = nil
        currentTrack = nil  // Clear so playlist highlighting resets
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if isPaused {
            resume()
        }
    }

    /// Navigate to next track in playlist
    func next() async {
        // Pass coordinator's currentTrack so PlaylistController can resolve position
        // even when audioPlayer.currentTrack is nil (e.g., during stream playback)
        let action = audioPlayer.nextTrack(from: currentTrack, isManualSkip: true)
        await handlePlaylistAdvance(action: action)
    }

    /// Navigate to previous track in playlist
    func previous() async {
        // Pass coordinator's currentTrack for position context during stream playback
        let action = audioPlayer.previousTrack(from: currentTrack)
        await handlePlaylistAdvance(action: action)
    }

    private func resume() {
        switch currentSource {
        case .localTrack:
            audioPlayer.play()
        case .radioStation:
            // Just resume, don't rebuild stream
            streamPlayer.player.play()
        case .none:
            break
        }
    }

    // MARK: - Helpers

    private func formattedLocalDisplayTitle(trackTitle: String, trackArtist: String, url: URL) -> String {
        let trimmedTitle = trackTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = trackArtist.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedTitle.isEmpty && !trimmedArtist.isEmpty {
            return "\(trimmedTitle) - \(trimmedArtist)"
        }

        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        if !trimmedArtist.isEmpty {
            return trimmedArtist
        }

        return url.deletingPathExtension().lastPathComponent
    }

    private func updateLocalPlaybackState(for track: Track) {
        currentTrack = track
        currentSource = .localTrack(track.url)
        currentTitle = formattedLocalDisplayTitle(
            trackTitle: track.title,
            trackArtist: track.artist,
            url: track.url
        )
    }

    private func handlePlaylistAdvance(action: AudioPlayer.PlaylistAdvanceAction) async {
        switch action {
        case .none:
            return
        case .restartCurrent:
            guard let track = currentTrack else { return }
            if track.isStream {
                await play(track: track)
            } else {
                updateLocalPlaybackState(for: track)
            }
        case .playLocally(let track):
            teardownLoopbackBridge()
            streamPlayer.stop()
            updateLocalPlaybackState(for: track)
        case .requestCoordinatorPlayback(let track):
            await play(track: track)
        }
    }

    /// Update coordinator state when metadata loads (don't replay)
    func updateTrackMetadata(_ track: Track) {
        // Check URL match (not ID - metadata loading creates new Track with different ID)
        guard let current = currentTrack, current.url == track.url else { return }

        // Update with real metadata
        currentTrack = track
        currentTitle = formattedLocalDisplayTitle(
            trackTitle: track.title,
            trackArtist: track.artist,
            url: track.url
        )

        // Note: Don't call play(track:) - that would replay the file
        // Just update metadata for display
    }

    private func handleExternalPlaylistAdvance(track: Track) async {
        if track.isStream {
            await play(track: track)
        } else {
            updateLocalPlaybackState(for: track)
        }
    }

    // MARK: - Unified State for UI

    /// Display title for main window (includes buffering status)
    var displayTitle: String {
        switch currentSource {
        case .radioStation:
            // Buffering takes priority
            if streamPlayer.isBuffering {
                return "Connecting..."
            }
            // Error state
            if streamPlayer.error != nil {
                return "buffer 0%"
            }
            // Live ICY metadata (overrides Track title)
            if let icy = streamPlayer.streamTitle {
                return icy
            }
            // Fallback to Track or station name
            return currentTrack?.title ?? currentTitle ?? "Internet Radio"

        case .localTrack(let url):
            if let title = currentTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                return title
            }

            let fallbackTitle = formattedLocalDisplayTitle(
                trackTitle: currentTrack?.title ?? "",
                trackArtist: currentTrack?.artist ?? "",
                url: url
            )

            return fallbackTitle.isEmpty ? "Unknown" : fallbackTitle

        case .none:
            return "MacAmp"
        }
    }

    /// Display artist for main window
    var displayArtist: String {
        switch currentSource {
        case .radioStation:
            // ICY metadata (overrides Track artist)
            return streamPlayer.streamArtist ?? currentTrack?.artist ?? ""
        case .localTrack:
            return currentTrack?.artist ?? ""
        case .none:
            return ""
        }
    }

    // MARK: - Legacy State Queries (for compatibility)

    var streamTitle: String? {
        switch currentSource {
        case .localTrack(let url):
            return url.deletingPathExtension().lastPathComponent
        case .radioStation:
            return streamPlayer.streamTitle
        case .none:
            return nil
        }
    }

    var streamArtist: String? {
        streamPlayer.streamArtist
    }

    var isBuffering: Bool {
        streamPlayer.isBuffering
    }

    var error: String? {
        streamPlayer.error
    }
}
