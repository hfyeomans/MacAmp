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
        print("DEBUG M3UParser: Parsing file at: \(fileURL.path)")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("DEBUG M3UParser: File not found!")
            throw M3UParseError.fileNotFound
        }

        print("DEBUG M3UParser: File exists, reading content...")
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            print("DEBUG M3UParser: Encoding error!")
            throw M3UParseError.encodingError
        }

        print("DEBUG M3UParser: Content loaded, length: \(content.count) chars")
        print("DEBUG M3UParser: First 200 chars: \(String(content.prefix(200)))")
        return try parse(content: content, relativeTo: fileURL)
    }

    /// Parse M3U content from a string
    static func parse(content: String, relativeTo baseURL: URL? = nil) throws -> [M3UEntry] {
        print("DEBUG M3UParser: parse() called, baseURL: \(baseURL?.path ?? "nil")")
        var entries: [M3UEntry] = []
        let lines = content.components(separatedBy: .newlines)
        print("DEBUG M3UParser: Split into \(lines.count) lines")

        var currentTitle: String?
        var currentDuration: Int?

        for (lineNum, line) in lines.enumerated() {
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
                    print("DEBUG M3UParser: Line \(lineNum): EXTINF - title: \(currentTitle ?? "nil"), duration: \(currentDuration ?? -1)")
                }
                // Skip other comments (including #EXTM3U header)
                continue
            }

            // This is a URL/path line
            print("DEBUG M3UParser: Line \(lineNum): URL/path line: '\(trimmed)'")
            if let url = resolveURL(trimmed, relativeTo: baseURL) {
                let entry = M3UEntry(
                    url: url,
                    title: currentTitle,
                    duration: currentDuration
                )
                entries.append(entry)
                print("DEBUG M3UParser: Added entry: \(url.path)")

                // Reset metadata for next entry
                currentTitle = nil
                currentDuration = nil
            } else {
                print("DEBUG M3UParser: WARNING - Failed to resolve URL: '\(trimmed)'")
            }
        }

        print("DEBUG M3UParser: Parsed \(entries.count) entries total")
        guard !entries.isEmpty else {
            print("DEBUG M3UParser: Empty playlist!")
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
