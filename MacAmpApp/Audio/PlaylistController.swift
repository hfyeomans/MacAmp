import Foundation
import Observation

/// Manages playlist state and navigation logic.
/// Extracted from AudioPlayer as part of the Option C incremental refactoring.
///
/// Layer: Mechanism (pure logic, no playback side effects)
/// Responsibilities:
/// - Maintain playlist of tracks
/// - Track current position in playlist
/// - Compute next/previous track based on shuffle and repeat modes
/// - Return navigation actions (does NOT initiate playback)
///
/// Design: Returns `PlaylistAdvanceAction` for AudioPlayer to handle.
/// This separation allows pure unit testing of navigation logic.
@MainActor
@Observable
final class PlaylistController {

    // MARK: - Navigation Action

    /// Action to be performed after playlist navigation
    enum AdvanceAction: Equatable {
        case none
        case restartCurrent
        case playTrack(Track)
        case requestCoordinatorPlayback(Track)
        case endOfPlaylist
    }

    // MARK: - State

    /// All tracks in the playlist
    private(set) var playlist: [Track] = []

    /// Index of the currently playing track
    private var currentIndex: Int?

    /// Whether shuffle mode is enabled
    var shuffleEnabled: Bool = false

    /// Tracks when playlist has reached the end (no repeat)
    private(set) var hasEnded: Bool = false

    /// URLs of tracks currently being loaded (to prevent duplicates)
    @ObservationIgnored private var pendingTrackURLs: Set<URL> = []

    // MARK: - Pending URL Management

    /// Add a URL to the pending set (used during async metadata loading)
    func addPendingURL(_ url: URL) {
        pendingTrackURLs.insert(url)
    }

    /// Remove a URL from the pending set (called when loading completes)
    func removePendingURL(_ url: URL) {
        pendingTrackURLs.remove(url)
    }

    // MARK: - Computed Properties

    /// Repeat mode (delegates to AppSettings)
    var repeatMode: AppSettings.RepeatMode {
        get { AppSettings.instance().repeatMode }
        set { AppSettings.instance().repeatMode = newValue }
    }

    /// The currently selected track
    var currentTrack: Track? {
        guard let index = currentIndex, playlist.indices.contains(index) else {
            return nil
        }
        return playlist[index]
    }

    /// Number of tracks in playlist
    var count: Int { playlist.count }

    /// Whether playlist is empty
    var isEmpty: Bool { playlist.isEmpty }

    // MARK: - Playlist Operations

    /// Add a track to the playlist
    func addTrack(_ track: Track) {
        playlist.append(track)
        AppLog.debug(.audio, "Added '\(track.title)' to playlist (total: \(playlist.count) tracks)")
    }

    /// Add a placeholder track (for async loading)
    func addPlaceholder(_ track: Track) {
        playlist.append(track)
        AppLog.debug(.audio, "Queued placeholder '\(track.title)' (total: \(playlist.count) tracks)")
    }

    /// Replace a placeholder with the loaded track
    func replacePlaceholder(id: UUID, with track: Track) -> Bool {
        if let index = playlist.firstIndex(where: { $0.id == id }) {
            AppLog.debug(.audio, "Replacing placeholder at index \(index) with loaded track")
            playlist[index] = track
            return true
        }
        return false
    }

    /// Check if a track URL is already in playlist or pending
    func containsTrack(url: URL) -> Bool {
        let normalizedURL = url.standardizedFileURL
        return playlist.contains { $0.url.standardizedFileURL == normalizedURL } ||
               pendingTrackURLs.contains(normalizedURL)
    }

    /// Remove a track at the specified index
    func removeTrack(at index: Int) {
        guard playlist.indices.contains(index) else { return }
        playlist.remove(at: index)

        // Adjust current index if needed
        if let current = currentIndex {
            if index < current {
                currentIndex = current - 1
            } else if index == current {
                currentIndex = nil
            }
        }
        AppLog.debug(.audio, "Removed track at index \(index), \(playlist.count) remaining")
    }

    /// Remove all tracks from the playlist
    func clear() {
        playlist.removeAll()
        currentIndex = nil
        hasEnded = false
        pendingTrackURLs.removeAll()
        AppLog.debug(.audio, "Playlist cleared")
    }

    // MARK: - Position Management

    /// Update the current position based on a track
    func updatePosition(with track: Track?) {
        guard let track else {
            currentIndex = nil
            return
        }

        if let index = playlist.firstIndex(of: track) {
            currentIndex = index
            hasEnded = false
        } else {
            currentIndex = nil
        }
    }

    /// Mark playlist as ended (for external state sync)
    func markEnded() {
        hasEnded = true
        currentIndex = nil
    }

    /// Reset the ended flag
    func resetEnded() {
        hasEnded = false
    }

    // MARK: - Navigation

    /// Compute the next track to play with external position context.
    /// Used when the caller has track context that AudioPlayer lacks (e.g., during stream playback
    /// where audioPlayer.currentTrack is nil but PlaybackCoordinator.currentTrack is set).
    /// - Parameters:
    ///   - track: External track context for position resolution. If non-nil, position is synced before navigation.
    ///     If nil (e.g., direct station playback not from playlist), clears stale index to prevent incorrect navigation.
    ///   - isManualSkip: Whether this is a user-initiated skip (affects repeat-one behavior)
    /// - Returns: The action to perform (caller handles playback)
    func nextTrack(from track: Track?, isManualSkip: Bool = false) -> AdvanceAction {
        // Always sync position: non-nil track resolves index, nil clears stale index
        updatePosition(with: track)
        return nextTrack(isManualSkip: isManualSkip)
    }

    /// Compute the previous track to play with external position context.
    /// - Parameter track: External track context for position resolution. If non-nil, position is synced before navigation.
    ///   If nil (e.g., direct station playback not from playlist), clears stale index to prevent incorrect navigation.
    /// - Returns: The action to perform (caller handles playback)
    func previousTrack(from track: Track?) -> AdvanceAction {
        // Always sync position: non-nil track resolves index, nil clears stale index
        updatePosition(with: track)
        return previousTrack()
    }

    /// Compute the next track to play
    /// - Parameter isManualSkip: Whether this is a user-initiated skip (affects repeat-one behavior)
    /// - Returns: The action to perform (caller handles playback)
    func nextTrack(isManualSkip: Bool = false) -> AdvanceAction {
        guard !playlist.isEmpty else { return .none }

        hasEnded = false

        // Repeat-one: Only auto-restart on track end, allow manual skips
        if repeatMode == .one && !isManualSkip {
            guard let track = currentTrack else { return .none }
            return track.isStream ? .requestCoordinatorPlayback(track) : .restartCurrent
        }

        // Shuffle mode: pick random track
        if shuffleEnabled {
            guard let randomTrack = playlist.randomElement(),
                  let randomIndex = playlist.firstIndex(of: randomTrack) else {
                return .none
            }
            currentIndex = randomIndex
            return randomTrack.isStream ? .requestCoordinatorPlayback(randomTrack) : .playTrack(randomTrack)
        }

        // Sequential: find next index
        let activeIndex = resolveActiveIndex()
        let nextIndex = activeIndex + 1

        if nextIndex < playlist.count {
            let track = playlist[nextIndex]
            currentIndex = nextIndex
            return track.isStream ? .requestCoordinatorPlayback(track) : .playTrack(track)
        }

        // End of playlist reached
        if repeatMode == .all {
            let track = playlist[0]
            currentIndex = 0
            return track.isStream ? .requestCoordinatorPlayback(track) : .playTrack(track)
        }

        // Repeat mode .off: stop at playlist end
        hasEnded = true
        currentIndex = nil
        return .endOfPlaylist
    }

    /// Compute the previous track to play
    /// - Returns: The action to perform (caller handles playback)
    func previousTrack() -> AdvanceAction {
        guard !playlist.isEmpty else { return .none }

        // Shuffle mode: pick random track
        if shuffleEnabled {
            guard let track = playlist.randomElement(),
                  let index = playlist.firstIndex(of: track) else {
                return .none
            }
            currentIndex = index
            hasEnded = false
            return track.isStream ? .requestCoordinatorPlayback(track) : .playTrack(track)
        }

        // Sequential: find previous index
        guard let activeIndex = currentIndex ?? findCurrentTrackIndex() else {
            return .none
        }

        if activeIndex > 0 {
            let previousIndex = activeIndex - 1
            let track = playlist[previousIndex]
            currentIndex = previousIndex
            hasEnded = false
            return track.isStream ? .requestCoordinatorPlayback(track) : .playTrack(track)
        }

        // At beginning: restart current track
        return .restartCurrent
    }

    /// Select a specific track by index
    func selectTrack(at index: Int) -> Track? {
        guard playlist.indices.contains(index) else { return nil }
        currentIndex = index
        hasEnded = false
        return playlist[index]
    }

    // MARK: - Private Helpers

    private func resolveActiveIndex() -> Int {
        if let index = currentIndex {
            return index
        }
        if let index = findCurrentTrackIndex() {
            currentIndex = index
            return index
        }
        return -1
    }

    private func findCurrentTrackIndex() -> Int? {
        guard let track = currentTrack else { return nil }
        return playlist.firstIndex(of: track)
    }
}
