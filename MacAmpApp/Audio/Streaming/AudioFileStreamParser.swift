import AudioToolbox
import Foundation

/// Wraps Apple's AudioFileStream C API for parsing compressed audio packets
/// from progressive HTTP streams (MP3, AAC).
///
/// Receives raw audio bytes (after ICY metadata stripping) and emits:
/// - Audio format description (ASBD) when detected
/// - Magic cookie data (for AAC)
/// - Compressed audio packets with descriptions
///
/// **Threading:** Confined to the decode serial queue. Not Sendable — accessed
/// only from StreamDecodePipeline's decode queue. Debug assertions verify
/// queue confinement on public methods.
///
/// **C API Lifetime:**
/// - `AudioFileStreamOpen()` creates the parser
/// - `AudioFileStreamParseBytes()` feeds data, triggers callbacks
/// - `AudioFileStreamClose()` disposes — MUST be called after AudioConverterDispose()
///
/// **Layer:** Mechanism (C API wrapper, no async, no actor isolation)
final class AudioFileStreamParser {

    // MARK: - Callback Types

    /// Called when the audio format is detected.
    var onFormatAvailable: ((AudioStreamBasicDescription) -> Void)?

    /// Called when magic cookie data is available (needed for AAC).
    var onMagicCookie: ((Data) -> Void)?

    /// Called when compressed audio packets are available for decoding.
    var onPackets: ((Data, [AudioStreamPacketDescription]) -> Void)?

    /// Called when a parse error occurs. Allows pipeline to surface errors to UI.
    var onError: ((String) -> Void)?

    // MARK: - State

    private var streamID: AudioFileStreamID?
    private var inputFormat: AudioStreamBasicDescription?

    /// The decode queue this parser is confined to (set by owner, checked in debug builds).
    var confinementQueue: DispatchQueue?

    private func assertConfinement() {
        #if DEBUG
        if let queue = confinementQueue {
            dispatchPrecondition(condition: .onQueue(queue))
        }
        #endif
    }

    // MARK: - Initialization

    /// Create a parser with a format hint.
    /// - Parameter formatHint: `kAudioFileMP3Type`, `kAudioFileAAC_ADTSType`, or 0 for auto-detect
    init(formatHint: AudioFileTypeID) {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = AudioFileStreamOpen(
            selfPtr,
            propertyListenerCallback,
            packetsCallback,
            formatHint,
            &streamID
        )

        if status != noErr {
            AppLog.error(.audio, "AudioFileStreamParser: Failed to open stream (status: \(status))")
            onError?("AudioFileStream open failed (status: \(status))")
        }
    }

    deinit {
        close()
    }

    // MARK: - Parsing

    /// Feed raw audio bytes to the parser. Triggers callbacks as data is parsed.
    /// - Parameter data: Compressed audio bytes (after ICY metadata removal)
    func parse(_ data: Data) {
        assertConfinement()
        guard let streamID else { return }

        let status = data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return OSStatus(kAudioFileStreamError_UnspecifiedError) }
            return AudioFileStreamParseBytes(
                streamID,
                UInt32(rawBuffer.count),
                baseAddress,
                []  // No flags — continuous stream
            )
        }

        if status != noErr && status != kAudioFileStreamError_NotOptimized {
            AppLog.warn(.audio, "AudioFileStreamParser: Parse error (status: \(status))")
            onError?("AudioFileStream parse error (status: \(status))")
        }
    }

    /// Close and dispose the parser. Safe to call multiple times.
    func close() {
        assertConfinement()
        if let streamID {
            AudioFileStreamClose(streamID)
            self.streamID = nil
        }
    }

    // MARK: - C Callbacks

    /// Property listener — called when stream properties become available.
    private let propertyListenerCallback: AudioFileStream_PropertyListenerProc = {
        clientData, streamID, propertyID, ioFlags in

        let parser = Unmanaged<AudioFileStreamParser>.fromOpaque(clientData).takeUnretainedValue()

        switch propertyID {
        case kAudioFileStreamProperty_DataFormat:
            var asbd = AudioStreamBasicDescription()
            var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            let status = AudioFileStreamGetProperty(streamID, propertyID, &size, &asbd)
            if status == noErr {
                parser.inputFormat = asbd
                parser.onFormatAvailable?(asbd)
                AppLog.info(.audio, "AudioFileStreamParser: Format detected — "
                    + "\(asbd.mFormatID.fourCharString) \(asbd.mSampleRate)Hz "
                    + "\(asbd.mChannelsPerFrame)ch \(asbd.mBitsPerChannel)bit")
            }

        case kAudioFileStreamProperty_MagicCookieData:
            var size: UInt32 = 0
            var writable: DarwinBoolean = false
            let sizeStatus = AudioFileStreamGetPropertyInfo(streamID, propertyID, &size, &writable)
            guard sizeStatus == noErr, size > 0 else { return }

            var cookie = Data(count: Int(size))
            let status = cookie.withUnsafeMutableBytes { rawBuffer in
                guard let ptr = rawBuffer.baseAddress else { return OSStatus(kAudioFileStreamError_UnspecifiedError) }
                return AudioFileStreamGetProperty(streamID, propertyID, &size, ptr)
            }
            if status == noErr {
                parser.onMagicCookie?(cookie)
                AppLog.debug(.audio, "AudioFileStreamParser: Magic cookie (\(size) bytes)")
            }

        case kAudioFileStreamProperty_ReadyToProducePackets:
            AppLog.debug(.audio, "AudioFileStreamParser: Ready to produce packets")

        default:
            break
        }
    }

    /// Packets callback — called when compressed audio packets are available.
    private let packetsCallback: AudioFileStream_PacketsProc = {
        clientData, numberBytes, numberPackets, inputData, packetDescriptions in

        guard numberPackets > 0 else { return }
        let parser = Unmanaged<AudioFileStreamParser>.fromOpaque(clientData).takeUnretainedValue()

        // Copy packet data — pointer is only valid during this callback
        let data = Data(bytes: inputData, count: Int(numberBytes))

        // Copy packet descriptions — pointer is only valid during this callback
        var descriptions: [AudioStreamPacketDescription] = []
        if let packetDescriptions {
            descriptions = Array(UnsafeBufferPointer(
                start: packetDescriptions,
                count: Int(numberPackets)
            ))
        }

        parser.onPackets?(data, descriptions)
    }
}

// MARK: - AudioFormatID Helper

private extension UInt32 {
    /// Convert a FourCC audio format ID to a readable string.
    var fourCharString: String {
        let bytes = withUnsafeBytes(of: bigEndian) { Array($0) }
        return String(bytes.map { Character(UnicodeScalar($0)) })
    }
}
