import Foundation

struct RadioStation: Identifiable, Codable {
    let id: UUID
    let name: String
    let streamURL: URL
    let genre: String?
    let source: Source

    enum Source: Codable {
        case m3uPlaylist(String)  // From M3U file
        case manual              // User-added
        case directory           // From radio directory
    }

    init(id: UUID = UUID(), name: String, streamURL: URL, genre: String? = nil, source: Source = .manual) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.genre = genre
        self.source = source
    }
}
