import AudioToolbox
import Foundation

/// Wraps Apple's AudioConverter C API for decoding compressed audio packets
/// (MP3, AAC) to Float32 interleaved stereo PCM.
///
/// **Input:** Compressed packets from AudioFileStreamParser (with packet descriptions)
/// **Output:** Float32 interleaved stereo PCM at the source sample rate
///
/// **Threading:** Confined to the decode serial queue. Not Sendable.
///
/// **C API Lifetime:**
/// - `AudioConverterNew()` creates the converter (after format is known)
/// - `AudioConverterFillComplexBuffer()` decodes packets via input callback
/// - `AudioConverterDispose()` disposes — MUST be called BEFORE AudioFileStreamClose()
///
/// **Pre-allocation:** Output buffer is allocated once and reused to avoid
/// allocations during the decode loop.
///
/// **Layer:** Mechanism (C API wrapper, no async, no actor isolation)
final class AudioConverterDecoder {

    /// Custom status code signaling no more input data available.
    /// AudioConverter stops decoding when the input callback returns this.
    /// FourCC 'ndta' — unique to avoid collision with system error codes.
    static let noMoreInputData: OSStatus = 0x6e647461  // 'ndta'

    // MARK: - Configuration

    /// Output PCM format: Float32 interleaved stereo
    private(set) var outputFormat: AudioStreamBasicDescription

    /// Input compressed format (from AudioFileStreamParser)
    private(set) var inputFormat: AudioStreamBasicDescription

    /// Sample rate of the decoded output
    var sampleRate: Float64 { outputFormat.mSampleRate }

    // MARK: - State

    private var converter: AudioConverterRef?

    /// Queued compressed packets waiting to be decoded
    private var packetQueue: [(data: Data, descriptions: [AudioStreamPacketDescription])] = []

    /// Stable storage for the current packet being fed to the converter's input callback.
    /// These buffers persist across the callback return so AudioConverter can read from them.
    /// CRITICAL: Do NOT use withUnsafeBytes in the callback — pointer invalidates on scope exit.
    private var inputBuffer: UnsafeMutableRawPointer?
    private var inputBufferSize: Int = 0
    private var inputDescriptions: UnsafeMutableBufferPointer<AudioStreamPacketDescription>?
    private var inputDescriptionCount: Int = 0
    private var inputConsumed: Bool = true

    /// The decode queue this decoder is confined to (set by owner, checked in debug builds).
    var confinementQueue: DispatchQueue?

    private func assertConfinement() {
        #if DEBUG
        if let queue = confinementQueue {
            dispatchPrecondition(condition: .onQueue(queue))
        }
        #endif
    }

    /// Pre-allocated output buffer (frames * channels * sizeof(Float32))
    private static let maxOutputFrames = 1024
    private var outputBuffer: UnsafeMutablePointer<Float>
    private let outputBufferSize: Int

    // MARK: - Initialization

    /// Create a decoder for the given input format.
    /// - Parameters:
    ///   - inputFormat: Compressed audio format (ASBD from AudioFileStreamParser)
    ///   - magicCookie: AAC magic cookie data (nil for MP3)
    init(inputFormat: AudioStreamBasicDescription, magicCookie: Data? = nil) {
        self.inputFormat = inputFormat

        // Output: Float32 interleaved stereo at source sample rate
        let sampleRate = inputFormat.mSampleRate > 0 ? inputFormat.mSampleRate : 44100.0
        let channels: UInt32 = 2
        self.outputFormat = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: channels * UInt32(MemoryLayout<Float>.size),
            mFramesPerPacket: 1,
            mBytesPerFrame: channels * UInt32(MemoryLayout<Float>.size),
            mChannelsPerFrame: channels,
            mBitsPerChannel: UInt32(MemoryLayout<Float>.size * 8),
            mReserved: 0
        )

        // Pre-allocate output buffer
        let frameCount = Self.maxOutputFrames
        outputBufferSize = frameCount * Int(channels)
        outputBuffer = .allocate(capacity: outputBufferSize)
        outputBuffer.initialize(repeating: 0, count: outputBufferSize)

        // Create converter
        var converterRef: AudioConverterRef?
        var inFormat = inputFormat
        var outFormat = self.outputFormat
        let status = AudioConverterNew(&inFormat, &outFormat, &converterRef)

        if status == noErr {
            converter = converterRef
            AppLog.info(.audio, "AudioConverterDecoder: Created — \(inputFormat.mSampleRate)Hz → Float32 stereo")
        } else {
            AppLog.error(.audio, "AudioConverterDecoder: Failed to create converter (status: \(status))")
        }

        // Set magic cookie if provided (required for AAC)
        if let cookie = magicCookie, let converterRef {
            cookie.withUnsafeBytes { rawBuffer in
                guard let ptr = rawBuffer.baseAddress else { return }
                let cookieStatus = AudioConverterSetProperty(
                    converterRef,
                    kAudioConverterDecompressionMagicCookie,
                    UInt32(cookie.count),
                    ptr
                )
                if cookieStatus != noErr {
                    AppLog.warn(.audio, "AudioConverterDecoder: Failed to set magic cookie (status: \(cookieStatus))")
                }
            }
        }
    }

    deinit {
        dispose()
        outputBuffer.deallocate()
    }

    // MARK: - Packet Enqueue

    /// Enqueue compressed packets for decoding.
    /// - Parameters:
    ///   - data: Compressed packet data (copied from AudioFileStream callback)
    ///   - descriptions: Packet descriptions (copied from AudioFileStream callback)
    func enqueue(data: Data, descriptions: [AudioStreamPacketDescription]) {
        assertConfinement()
        packetQueue.append((data: data, descriptions: descriptions))
    }

    // MARK: - Decoding

    /// Decode queued packets into Float32 PCM.
    /// Returns a pointer to the internal output buffer and the number of frames decoded.
    /// The pointer is valid until the next call to `decode()`.
    ///
    /// - Returns: Tuple of (buffer pointer, frame count), or nil if no data available
    func decode() -> (UnsafePointer<Float>, Int)? {
        assertConfinement()
        guard converter != nil, !packetQueue.isEmpty else { return nil }

        // Take the first queued packet and copy into stable storage
        let packet = packetQueue.removeFirst()
        prepareInputBuffer(data: packet.data, descriptions: packet.descriptions)

        var outputBufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: outputFormat.mChannelsPerFrame,
                mDataByteSize: UInt32(outputBufferSize * MemoryLayout<Float>.size),
                mData: outputBuffer
            )
        )

        var outputFrameCount = UInt32(Self.maxOutputFrames)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = AudioConverterFillComplexBuffer(
            converter!,
            inputDataCallback,
            selfPtr,
            &outputFrameCount,
            &outputBufferList,
            nil  // No output packet descriptions for PCM
        )

        switch status {
        case noErr, Self.noMoreInputData:
            // noMoreInputData is normal — converter consumed all available input
            let frameCount = Int(outputFrameCount)
            return frameCount > 0 ? (UnsafePointer(outputBuffer), frameCount) : nil

        default:
            AppLog.warn(.audio, "AudioConverterDecoder: Decode error (status: \(status))")
            return nil
        }
    }

    /// Check if there are queued packets waiting to be decoded.
    var hasQueuedPackets: Bool { !packetQueue.isEmpty }

    // MARK: - Stable Input Storage

    /// Copy packet data and descriptions into stable memory that persists across
    /// the AudioConverter input callback return. The callback sets pointers into
    /// these buffers; they must remain valid until AudioConverterFillComplexBuffer returns.
    private func prepareInputBuffer(data: Data, descriptions: [AudioStreamPacketDescription]) {
        // Free previous input buffer
        freeInputBuffer()

        // Copy packet data into stable allocation
        inputBufferSize = data.count
        inputBuffer = .allocate(byteCount: inputBufferSize, alignment: MemoryLayout<UInt8>.alignment)
        data.copyBytes(to: inputBuffer!.assumingMemoryBound(to: UInt8.self), count: inputBufferSize)

        // Copy packet descriptions into stable allocation
        if !descriptions.isEmpty {
            inputDescriptionCount = descriptions.count
            let descPtr = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: descriptions.count)
            for (i, desc) in descriptions.enumerated() {
                descPtr[i] = desc
            }
            inputDescriptions = UnsafeMutableBufferPointer(start: descPtr, count: descriptions.count)
        } else {
            inputDescriptionCount = 0
            inputDescriptions = nil
        }

        inputConsumed = false
    }

    /// Free stable input storage. Safe to call multiple times.
    private func freeInputBuffer() {
        if let buf = inputBuffer {
            buf.deallocate()
            inputBuffer = nil
            inputBufferSize = 0
        }
        if let descs = inputDescriptions {
            descs.baseAddress?.deallocate()
            inputDescriptions = nil
            inputDescriptionCount = 0
        }
        inputConsumed = true
    }

    // MARK: - Cleanup

    /// Dispose the converter. Safe to call multiple times.
    /// MUST be called BEFORE AudioFileStreamParser.close().
    func dispose() {
        assertConfinement()
        if let converter {
            AudioConverterDispose(converter)
            self.converter = nil
        }
        packetQueue.removeAll()
        freeInputBuffer()
    }

    // MARK: - Input Data Callback

    /// C callback that AudioConverter calls when it needs more compressed input data.
    /// Pointers set in ioData/outDataPacketDescription point into stable allocations
    /// (prepareInputBuffer) that persist until the next decode() call.
    private let inputDataCallback: AudioConverterComplexInputDataProc = {
        converter, ioNumberDataPackets, ioData, outDataPacketDescription, inUserData in

        guard let inUserData else {
            ioNumberDataPackets.pointee = 0
            return 0x6e647461  // 'ndta' — no more input data
        }

        let decoder = Unmanaged<AudioConverterDecoder>.fromOpaque(inUserData).takeUnretainedValue()

        // Already consumed or no data available
        guard !decoder.inputConsumed,
              let dataPtr = decoder.inputBuffer,
              decoder.inputBufferSize > 0 else {
            ioNumberDataPackets.pointee = 0
            return 0x6e647461  // 'ndta' — no more input data
        }

        // Point AudioConverter at stable memory
        ioData.pointee.mNumberBuffers = 1
        ioData.pointee.mBuffers.mData = dataPtr
        ioData.pointee.mBuffers.mDataByteSize = UInt32(decoder.inputBufferSize)
        ioData.pointee.mBuffers.mNumberChannels = decoder.inputFormat.mChannelsPerFrame

        // Provide packet descriptions if available
        if let descs = decoder.inputDescriptions {
            ioNumberDataPackets.pointee = UInt32(descs.count)
            if let outDescPtr = outDataPacketDescription {
                outDescPtr.pointee = descs.baseAddress
            }
        } else {
            // No descriptions — constant bitrate format (e.g., some MP3 streams)
            ioNumberDataPackets.pointee = UInt32(decoder.inputBufferSize) / (decoder.inputFormat.mBytesPerPacket > 0 ? decoder.inputFormat.mBytesPerPacket : 1)
        }

        // Mark consumed so we don't provide the same data twice
        decoder.inputConsumed = true

        return noErr
    }
}
