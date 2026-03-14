import Foundation

/// Strips ICY (SHOUTcast/Icecast) metadata from an HTTP byte stream,
/// separating audio data from inline metadata blocks.
///
/// **ICY Protocol:**
/// 1. Client sends `Icy-MetaData: 1` in HTTP request headers
/// 2. Server responds with `icy-metaint: N` (metadata interval in bytes)
/// 3. After every N audio bytes, server inserts: 1 length byte (L), then L*16 metadata bytes
/// 4. Metadata format: `StreamTitle='Artist - Title';StreamUrl='...';`
///
/// **Usage:**
/// ```swift
/// var framer = ICYFramer()
/// framer.configure(metaInterval: metaint)  // from icy-metaint response header
/// let chunks = framer.consume(data)        // feed each URLSession data chunk
/// for chunk in chunks {
///     switch chunk {
///     case .audio(let audioData): parser.parse(audioData)
///     case .metadata(let meta):   updateUI(meta.title, meta.artist)
///     }
/// }
/// ```
///
/// **Layer:** Mechanism (pure data transformation, no I/O, no async)
struct ICYFramer: Sendable {

    // MARK: - Output Types

    /// A chunk emitted by the framer after processing raw bytes.
    enum Chunk: Sendable {
        case audio(Data)
        case metadata(ICYMetadata)
    }

    /// Parsed ICY metadata fields.
    struct ICYMetadata: Sendable {
        let title: String?
        let artist: String?
    }

    // MARK: - State

    /// Metadata interval in bytes (from `icy-metaint` HTTP response header).
    /// When 0, all bytes are treated as audio (no metadata framing).
    private var metaInterval: Int = 0

    /// Number of audio bytes consumed since last metadata block.
    private var audioByteCount: Int = 0

    /// Parsing state machine.
    private enum State: Sendable {
        case audio              // Consuming audio bytes
        case metaLengthByte     // Next byte is metadata length indicator
        case metaData(Int)      // Consuming N metadata bytes
    }

    private var state: State = .audio

    /// Accumulator for metadata bytes spanning multiple data chunks.
    private var metaBuffer = Data()

    // MARK: - Configuration

    /// Configure the framer with the metadata interval from the HTTP response.
    /// Call once after receiving the `icy-metaint` header value.
    /// - Parameter metaInterval: Byte interval between metadata blocks (0 = no metadata)
    mutating func configure(metaInterval: Int) {
        self.metaInterval = max(0, metaInterval)
        audioByteCount = 0
        state = .audio
        metaBuffer = Data()
    }

    // MARK: - Processing

    /// Process a chunk of raw bytes from the HTTP stream.
    /// Returns an array of audio and metadata chunks in the order they appear.
    ///
    /// - Parameter data: Raw bytes from URLSession data callback
    /// - Returns: Array of `.audio(Data)` and `.metadata(ICYMetadata)` chunks
    mutating func consume(_ data: Data) -> [Chunk] {
        // No metadata framing — pass all bytes as audio
        guard metaInterval > 0 else {
            return data.isEmpty ? [] : [.audio(data)]
        }

        var chunks: [Chunk] = []
        var offset = data.startIndex

        while offset < data.endIndex {
            switch state {
            case .audio:
                let remaining = metaInterval - audioByteCount
                let available = data.endIndex - offset
                let bytesToConsume = min(remaining, available)

                if bytesToConsume > 0 {
                    let audioSlice = data[offset..<(offset + bytesToConsume)]
                    chunks.append(.audio(Data(audioSlice)))
                    offset += bytesToConsume
                    audioByteCount += bytesToConsume
                }

                if audioByteCount >= metaInterval {
                    state = .metaLengthByte
                    audioByteCount = 0
                }

            case .metaLengthByte:
                let lengthIndicator = Int(data[offset])
                offset += 1
                let metaSize = lengthIndicator * 16

                if metaSize == 0 {
                    // No metadata this cycle — resume audio
                    state = .audio
                } else {
                    metaBuffer = Data()
                    metaBuffer.reserveCapacity(metaSize)
                    state = .metaData(metaSize)
                }

            case .metaData(let totalSize):
                let needed = totalSize - metaBuffer.count
                let available = data.endIndex - offset
                let bytesToConsume = min(needed, available)

                metaBuffer.append(data[offset..<(offset + bytesToConsume)])
                offset += bytesToConsume

                if metaBuffer.count >= totalSize {
                    // Complete metadata block — parse and emit
                    let metadata = Self.parseMetadata(metaBuffer)
                    chunks.append(.metadata(metadata))
                    metaBuffer = Data()
                    state = .audio
                }
            }
        }

        return chunks
    }

    // MARK: - Metadata Parsing

    /// Parse ICY metadata string into structured fields.
    /// Format: `StreamTitle='Artist - Title';StreamUrl='http://...';`
    /// Encoding: Latin-1 (ISO 8859-1) per SHOUTcast spec, with null padding.
    private static func parseMetadata(_ data: Data) -> ICYMetadata {
        // ICY metadata is Latin-1 encoded with null byte padding
        guard let raw = String(data: data, encoding: .isoLatin1) else {
            return ICYMetadata(title: nil, artist: nil)
        }

        // Trim null padding
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))

        let title = extractField(named: "StreamTitle", from: trimmed)
        // Some stations put artist in StreamTitle as "Artist - Title"
        let (parsedArtist, parsedTitle) = splitArtistTitle(title)

        return ICYMetadata(title: parsedTitle, artist: parsedArtist)
    }

    /// Extract a field value from ICY metadata string.
    /// Pattern: `FieldName='value';`
    private static func extractField(named field: String, from string: String) -> String? {
        let prefix = "\(field)='"
        guard let startRange = string.range(of: prefix) else { return nil }
        let valueStart = startRange.upperBound
        guard let endQuote = string[valueStart...].firstIndex(of: "'") else {
            // No closing quote — take rest of string
            let value = String(string[valueStart...])
            return value.isEmpty ? nil : value
        }
        let value = String(string[valueStart..<endQuote])
        return value.isEmpty ? nil : value
    }

    /// Split "Artist - Title" format into separate components.
    /// Returns (artist, title). If no separator found, artist is nil and title is the full string.
    private static func splitArtistTitle(_ streamTitle: String?) -> (artist: String?, title: String?) {
        guard let streamTitle, !streamTitle.isEmpty else {
            return (nil, nil)
        }
        // Common separator: " - " (with spaces)
        if let separatorRange = streamTitle.range(of: " - ") {
            let artist = String(streamTitle[..<separatorRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let title = String(streamTitle[separatorRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            return (
                artist.isEmpty ? nil : artist,
                title.isEmpty ? nil : title
            )
        }
        return (nil, streamTitle)
    }
}
