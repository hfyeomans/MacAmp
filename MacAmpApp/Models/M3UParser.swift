import Foundation

/// Errors that can occur during M3U parsing
enum M3UParseError: Error, LocalizedError {
    case invalidFormat
    case fileNotFound
    case encodingError
    case emptyPlaylist

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid M3U format"
        case .fileNotFound:
            return "M3U file not found"
        case .encodingError:
            return "Unable to read M3U file (encoding error)"
        case .emptyPlaylist:
            return "M3U playlist is empty"
        }
    }
}

/// Parser for M3U and M3U8 playlist files
struct M3UParser {
    /// Parse an M3U file from disk
    static func parse(fileURL: URL) throws -> [M3UEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw M3UParseError.fileNotFound
        }

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            throw M3UParseError.encodingError
        }

        return try parse(content: content, relativeTo: fileURL)
    }

    /// Parse M3U content from a string
    static func parse(content: String, relativeTo baseURL: URL? = nil) throws -> [M3UEntry] {
        var entries: [M3UEntry] = []
        let lines = content.components(separatedBy: .newlines)

        var currentTitle: String?
        var currentDuration: Int?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            guard !trimmed.isEmpty else { continue }

            // Skip comments (except EXTINF)
            if trimmed.hasPrefix("#") {
                if trimmed.hasPrefix("#EXTINF:") {
                    // Parse EXTINF line: #EXTINF:duration,title
                    let parts = trimmed.dropFirst(8).components(separatedBy: ",")
                    if let durationStr = parts.first?.trimmingCharacters(in: .whitespaces),
                       let duration = Int(durationStr) {
                        currentDuration = duration
                    }
                    if parts.count > 1 {
                        currentTitle = parts.dropFirst().joined(separator: ",").trimmingCharacters(in: .whitespaces)
                    }
                }
                // Skip other comments (including #EXTM3U header)
                continue
            }

            // This is a URL/path line
            if let url = resolveURL(trimmed, relativeTo: baseURL) {
                let entry = M3UEntry(
                    url: url,
                    title: currentTitle,
                    duration: currentDuration
                )
                entries.append(entry)

                // Reset metadata for next entry
                currentTitle = nil
                currentDuration = nil
            }
        }

        guard !entries.isEmpty else {
            throw M3UParseError.emptyPlaylist
        }

        return entries
    }

    /// Resolve a URL string to an absolute URL
    /// Handles HTTP/HTTPS URLs, absolute file paths, relative paths, and Windows paths
    private static func resolveURL(_ urlString: String, relativeTo baseURL: URL?) -> URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)

        // Handle HTTP/HTTPS URLs (internet radio streams)
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return URL(string: trimmed)
        }

        // Handle absolute file paths (Unix-style)
        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed)
        }

        // Handle Windows absolute paths (C:\, D:\, etc.)
        if trimmed.count > 2 && trimmed[trimmed.index(trimmed.startIndex, offsetBy: 1)] == ":" {
            // Convert Windows path to Unix path (basic conversion)
            let unixPath = trimmed.replacingOccurrences(of: "\\", with: "/")
            return URL(fileURLWithPath: unixPath)
        }

        // Handle relative paths
        if let base = baseURL {
            // Get the directory containing the M3U file
            let baseDir = base.deletingLastPathComponent()
            // Resolve relative path from M3U directory
            return URL(fileURLWithPath: trimmed, relativeTo: baseDir).standardized
        }

        // Fallback: try as file URL
        return URL(fileURLWithPath: trimmed)
    }
}
