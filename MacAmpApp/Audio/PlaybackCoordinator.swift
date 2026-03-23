import Foundation
import Observation

/// Coordinates playback between local files (AudioPlayer) and internet radio streams (StreamPlayer).
///
/// This coordinator prevents both backends from playing simultaneously, which would cause audio chaos.
/// It provides a unified API for the UI to play content regardless of source type.
///
/// **Architecture:**
/// - Local files (.mp3, .flac, etc.) → AudioPlayer (AVAudioPlayerNode) with 10-band EQ
/// - Internet radio (http://, https://) → StreamPlayer (custom decode pipeline) → AudioPlayer stream bridge (AVAudioSourceNode) with EQ + visualization
///
/// **Usage:**
/// ```swift
/// // Play a track from the playlist
/// await coordinator.play(track: myTrack)
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

    // MARK: - Unified Display Time

    /// Elapsed time for display — delegates to the active backend.
    /// Local files: engine progress timer. Streams: anchor-based elapsed counter.
    var displayTime: Double {
        switch currentSource {
        case .radioStation: return streamPlayer.elapsedTime
        case .localTrack: return audioPlayer.currentTime
        case nil: return 0
        }
    }

    /// Duration for display — 0 for streams (unknown/infinite).
    var displayDuration: Double {
        switch currentSource {
        case .radioStation: return 0
        case .localTrack: return audioPlayer.currentDuration
        case nil: return 0
        }
    }

    // MARK: - Playlist Position

    /// Track position string ("3/15") — nil when no playlist track is active.
    /// Guards against stale values during non-playlist playback (Oracle finding).
    var trackPositionString: String? {
        guard currentTrack != nil,
              let position = audioPlayer.playlistPosition else { return nil }
        return "\(position)/\(audioPlayer.playlistCount)"
    }

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

    /// EQ is available when not streaming, OR when stream bridge is active
    /// (stream decoded through AVAudioEngine). Dimmed only during stream error
    /// or before bridge activates (prebuffering).
    var supportsEQ: Bool { !isStreamBackendActive || audioPlayer.isBridgeActive }

    /// Balance is available when not streaming, OR when stream bridge is active.
    var supportsBalance: Bool { !isStreamBackendActive || audioPlayer.isBridgeActive }

    /// Visualizer is available when not streaming, OR when stream bridge is active
    /// (audio tap on mixer receives stream PCM through the bridge).
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

        // Wire stream pipeline format-ready callback to activate engine bridge
        self.streamPlayer.onFormatReady = { [weak self] sampleRate in
            guard let self,
                  let ringBuffer = self.streamPlayer.currentRingBuffer else { return }
            self.audioPlayer.activateStreamBridge(ringBuffer: ringBuffer, sampleRate: sampleRate)

            // Pass the audio IO workgroup to the decode pipeline so its thread
            // shares the real-time scheduling group with the Core Audio IO thread
            self.streamPlayer.setAudioWorkgroup(self.audioPlayer.audioWorkgroup)
        }

        // Wire stream terminal state callback for bridge teardown
        self.streamPlayer.onStreamTerminated = { [weak self] in
            guard let self else { return }
            if self.audioPlayer.isBridgeActive {
                self.audioPlayer.deactivateStreamBridge()
            }
        }
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
    /// With the unified pipeline, balance is applied via AVAudioEngine (streamSourceNode.pan).
    func setBalance(_ bal: Float) {
        audioPlayer.balance = bal
        streamPlayer.balance = bal
    }

    // MARK: - Unified Playback Control

    /// Play a track from the playlist (supports both local files and streams)
    func play(track: Track) async {
        audioPlayer.updatePlaylistPosition(with: track)
        currentTrack = track

        if track.isStream {
            // Stop local file if playing
            audioPlayer.deactivateStreamBridge()
            audioPlayer.stop()

            // Play stream via StreamPlayer (bridge activates via onFormatReady callback)
            await streamPlayer.play(url: track.url, title: track.title, artist: track.artist)
            currentSource = .radioStation(RadioStation(name: track.title, streamURL: track.url))
            currentTitle = track.title
        } else {
            // Stop stream + deactivate bridge if playing
            audioPlayer.deactivateStreamBridge()
            streamPlayer.stop()

            // Play local file via AudioPlayer
            audioPlayer.playTrack(track: track)
            updateLocalPlaybackState(for: track)
        }
    }

    /// Play a radio station from favorites menu
    func play(station: RadioStation) async {
        // Stop local file + deactivate any existing bridge
        audioPlayer.deactivateStreamBridge()
        audioPlayer.stop()

        // Play stream
        await streamPlayer.play(station: station)
        currentSource = .radioStation(station)
        currentTitle = streamPlayer.streamTitle ?? station.name
        currentTrack = nil  // Not from playlist
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
        audioPlayer.deactivateStreamBridge()
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
            streamPlayer.resume()
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
            audioPlayer.deactivateStreamBridge()
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
            // Error state — show user-friendly message
            if let streamError = streamPlayer.error {
                return streamError
            }
            // Station name (from RadioStation or track title)
            let stationName = streamPlayer.currentStation?.name ?? currentTrack?.title ?? currentTitle ?? "Internet Radio"

            // Combine station name + ICY track title (scrollable in Winamp title bar)
            if let icy = streamPlayer.streamTitle {
                return "\(stationName) - \(icy)"
            }
            return stationName

        case .localTrack(let url):
            let posPrefix = trackPositionString.map { "\($0). " } ?? ""

            if let title = currentTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                return "\(posPrefix)\(title)"
            }

            let fallbackTitle = formattedLocalDisplayTitle(
                trackTitle: currentTrack?.title ?? "",
                trackArtist: currentTrack?.artist ?? "",
                url: url
            )

            return "\(posPrefix)\(fallbackTitle.isEmpty ? "Unknown" : fallbackTitle)"

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
