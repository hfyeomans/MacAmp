import Foundation

/// Represents a single entry in an M3U playlist
struct M3UEntry: Equatable {
    /// The URL of the media file (can be local file path or remote stream)
    let url: URL

    /// Optional title from #EXTINF directive
    let title: String?

    /// Optional duration in seconds from #EXTINF directive (-1 indicates unknown/stream)
    let duration: Int?

    /// Computed property to determine if this is a remote stream (HTTP/HTTPS)
    var isRemoteStream: Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }

    /// Initialize an M3U entry with a URL and optional metadata
    init(url: URL, title: String? = nil, duration: Int? = nil) {
        self.url = url
        self.title = title
        self.duration = duration
    }
}
