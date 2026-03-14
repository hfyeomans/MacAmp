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
/// **Input buffer contract (Oracle fix):**
/// The input callback provides pointers to compressed data. Apple's contract requires
/// these pointers remain valid until the NEXT input callback invocation. The callback
/// pulls packets from the queue itself and keeps the previous buffer alive until replaced.
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

    /// Queued compressed packets waiting to be decoded.
    /// The input callback pulls from this queue directly.
    private var packetQueue: [(data: Data, descriptions: [AudioStreamPacketDescription])] = []

    /// Current input buffer — kept alive until AFTER FillComplexBuffer returns.
    private var currentInputBuffer: UnsafeMutableRawPointer?
    private var currentInputSize: Int = 0
    private var currentInputDescs: UnsafeMutablePointer<AudioStreamPacketDescription>?
    private var currentInputDescCount: Int = 0

    /// Previously used input buffers — kept alive during the entire FillComplexBuffer call
    /// because AudioConverter may perform look-ahead/overlap-add that references prior data.
    /// Freed after FillComplexBuffer returns.
    private var retainedBuffers: [(UnsafeMutableRawPointer, UnsafeMutablePointer<AudioStreamPacketDescription>?)] = []

    /// The decode queue this decoder is confined to (set by owner, checked in debug builds).
    var confinementQueue: DispatchQueue?

    private func assertConfinement() {
        #if DEBUG
        if let queue = confinementQueue {
            dispatchPrecondition(condition: .onQueue(queue))
        }
        #endif
    }

    /// Pre-allocated output buffer — 4096 frames (enough for multiple MP3/AAC frames)
    private static let maxOutputFrames = 4096
    private var outputBuffer: UnsafeMutablePointer<Float>
    private let outputBufferSize: Int

    // MARK: - Initialization

    /// - Parameters:
    ///   - inputFormat: Compressed audio format (ASBD from AudioFileStreamParser)
    ///   - outputSampleRate: Target output sample rate (use device rate to avoid engine SRC)
    ///   - magicCookie: AAC magic cookie data (nil for MP3)
    init(inputFormat: AudioStreamBasicDescription, outputSampleRate: Float64 = 48000.0, magicCookie: Data? = nil) {
        self.inputFormat = inputFormat

        // Output at stream's native sample rate — let the engine mixer handle SRC
        // to device output rate. This avoids AudioConverter SRC artifacts.
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

    func enqueue(data: Data, descriptions: [AudioStreamPacketDescription]) {
        assertConfinement()
        packetQueue.append((data: data, descriptions: descriptions))
    }

    // MARK: - Decoding

    /// Decode all queued packets into Float32 PCM in a single call.
    /// The input callback pulls packets from the queue incrementally.
    /// Returns a pointer to the internal output buffer and the number of frames decoded.
    /// The pointer is valid until the next call to `decode()`.
    func decode() -> (UnsafePointer<Float>, Int)? {
        assertConfinement()
        guard converter != nil, !packetQueue.isEmpty else { return nil }

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
            nil
        )

        switch status {
        case noErr, Self.noMoreInputData:
            let frameCount = Int(outputFrameCount)
            return frameCount > 0 ? (UnsafePointer(outputBuffer), frameCount) : nil

        default:
            AppLog.warn(.audio, "AudioConverterDecoder: Decode error (status: \(status))")
            return nil
        }
    }

    /// Check if there are queued packets waiting to be decoded.
    var hasQueuedPackets: Bool { !packetQueue.isEmpty }

    // MARK: - Input Buffer Management

    /// Prepare the next packet from the queue into stable memory.
    /// The PREVIOUS buffer is freed here — this is safe because Apple's contract
    /// says the buffer must be valid until the NEXT callback invocation.
    /// By freeing at the START of each callback, the previous buffer lived
    /// through the entire gap between callbacks.
    private func advanceToNextPacket() -> Bool {
        guard !packetQueue.isEmpty else { return false }

        // Free PREVIOUS buffer (safe — converter is done with it since it's calling us again)
        freeCurrentInput()

        let packet = packetQueue.removeFirst()

        // Copy packet data into stable allocation
        currentInputSize = packet.data.count
        currentInputBuffer = .allocate(byteCount: currentInputSize, alignment: MemoryLayout<UInt8>.alignment)
        packet.data.copyBytes(to: currentInputBuffer!.assumingMemoryBound(to: UInt8.self), count: currentInputSize)

        // Copy packet descriptions into stable allocation
        if !packet.descriptions.isEmpty {
            currentInputDescCount = packet.descriptions.count
            currentInputDescs = .allocate(capacity: packet.descriptions.count)
            for (i, desc) in packet.descriptions.enumerated() {
                currentInputDescs![i] = desc
            }
        } else {
            currentInputDescCount = 0
            currentInputDescs = nil
        }

        return true
    }

    /// Free the current input buffer. Safe to call multiple times.
    private func freeCurrentInput() {
        if let buf = currentInputBuffer {
            buf.deallocate()
            currentInputBuffer = nil
            currentInputSize = 0
        }
        if let descs = currentInputDescs {
            descs.deallocate()
            currentInputDescs = nil
            currentInputDescCount = 0
        }
    }

    // MARK: - Cleanup

    func dispose() {
        assertConfinement()
        if let converter {
            AudioConverterDispose(converter)
            self.converter = nil
        }
        packetQueue.removeAll()
        freeCurrentInput()
    }

    // MARK: - Input Data Callback

    /// C callback that AudioConverter calls when it needs more compressed input data.
    /// Pulls the NEXT packet from the queue each invocation.
    /// The PREVIOUS buffer remains valid until this callback is called again (Apple contract).
    private let inputDataCallback: AudioConverterComplexInputDataProc = {
        converter, ioNumberDataPackets, ioData, outDataPacketDescription, inUserData in

        guard let inUserData else {
            ioNumberDataPackets.pointee = 0
            return 0x6e647461  // 'ndta'
        }

        let decoder = Unmanaged<AudioConverterDecoder>.fromOpaque(inUserData).takeUnretainedValue()

        // Pull next packet from queue (frees previous buffer — safe per Apple contract)
        guard decoder.advanceToNextPacket(),
              let dataPtr = decoder.currentInputBuffer else {
            ioNumberDataPackets.pointee = 0
            return 0x6e647461  // 'ndta' — no more input data
        }

        // Point AudioConverter at stable memory
        ioData.pointee.mNumberBuffers = 1
        ioData.pointee.mBuffers.mData = dataPtr
        ioData.pointee.mBuffers.mDataByteSize = UInt32(decoder.currentInputSize)
        ioData.pointee.mBuffers.mNumberChannels = decoder.inputFormat.mChannelsPerFrame

        // Provide packet descriptions if available
        if let descs = decoder.currentInputDescs, decoder.currentInputDescCount > 0 {
            ioNumberDataPackets.pointee = UInt32(decoder.currentInputDescCount)
            if let outDescPtr = outDataPacketDescription {
                outDescPtr.pointee = descs
            }
        } else {
            // CBR format — compute packet count from buffer size
            let bytesPerPacket = decoder.inputFormat.mBytesPerPacket
            ioNumberDataPackets.pointee = bytesPerPacket > 0
                ? UInt32(decoder.currentInputSize) / bytesPerPacket
                : 1
        }

        return noErr
    }
}
