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

    // MARK: - Initialization

    init(audioPlayer: AudioPlayer, streamPlayer: StreamPlayer) {
        self.audioPlayer = audioPlayer
        self.streamPlayer = streamPlayer

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

    // MARK: - Unified Playback Control

    func play(url: URL) async {
        if url.isFileURL {
            // Stop stream if playing
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
            // Stop local file if playing
            audioPlayer.stop()

            // Play stream (no EQ)
            let station = RadioStation(name: url.lastPathComponent, streamURL: url)
            await streamPlayer.play(station: station)
            currentSource = .radioStation(station)
            currentTitle = streamPlayer.streamTitle ?? station.name
        }
    }

    /// Play a track from the playlist (supports both local files and streams)
    func play(track: Track) async {
        audioPlayer.updatePlaylistPosition(with: track)
        currentTrack = track

        if track.isStream {
            // Stop local file if playing
            audioPlayer.stop()

            // Play stream via StreamPlayer
            await streamPlayer.play(url: track.url, title: track.title, artist: track.artist)
            currentSource = .radioStation(RadioStation(name: track.title, streamURL: track.url))
            currentTitle = track.title
        } else {
            // Stop stream if playing
            streamPlayer.stop()

            // Play local file via AudioPlayer
            audioPlayer.playTrack(track: track)
            updateLocalPlaybackState(for: track)
        }
    }

    /// Play a radio station from favorites menu
    func play(station: RadioStation) async {
        // Stop local file if playing
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
