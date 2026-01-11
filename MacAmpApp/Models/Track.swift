import Foundation

// MARK: - Track

/// Represents a single audio or video track in the playlist.
/// Provides metadata and identifies stream vs local file playback routing.
struct Track: Identifiable, Equatable, Sendable {
    let id = UUID()
    let url: URL
    var title: String
    var artist: String
    var duration: Double

    /// Returns true if this track is an internet radio stream (HTTP/HTTPS URL)
    /// Streams cannot be played via AudioPlayer (which uses AVAudioFile for local files only)
    /// and must be routed through PlaybackCoordinator → StreamPlayer instead.
    var isStream: Bool {
        !url.isFileURL && (url.scheme == "http" || url.scheme == "https")
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Playback State

/// Reason why playback stopped
enum PlaybackStopReason: Equatable, Sendable {
    case manual     // User pressed stop
    case completed  // Track finished playing
    case ejected    // Track was removed from playlist
}

/// Current state of the audio/video player
enum PlaybackState: Equatable, Sendable {
    case idle
    case preparing
    case playing
    case paused
    case stopped(PlaybackStopReason)
}
