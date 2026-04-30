import Atomics
import AudioToolbox
import CoreMedia
@preconcurrency import AVFoundation
@preconcurrency import MediaToolbox

/// Wraps `MTAudioProcessingTap` for routing AVPlayer video audio into the
/// shared engine path (LockFreeRingBuffer → AVAudioSourceNode → EQ → mixer).
///
/// **Lifecycle:** `attach(to:)` returns an `AVMutableAudioMix` whose first input
/// parameters carry the tap. Caller assigns the mix to `playerItem.audioMix`.
/// At teardown, caller MUST set `playerItem.audioMix = nil` BEFORE calling
/// `detach()`; otherwise AVPlayer keeps calling into a dead tap.
///
/// **Threading:** the C-convention callbacks fire on the AVPlayer audio render
/// thread (not main, not Sendable-checked). They access `VideoAudioTapContext`
/// which is `@unchecked Sendable` and queue-confined to that thread once
/// `tapPrepare` runs. The Swift-facing API is `@MainActor`.
///
/// **Format handling:** `tapPrepare` inspects the upstream PCM ASBD and lazily
/// builds an `AudioConverter` if the source isn't already Float32 interleaved
/// stereo at `expectedSampleRate`. Mono / 5.1 / non-Float32 / non-target-rate
/// sources all flow through the converter. If `AudioConverterNew` fails, the
/// tap sets `fallbackRequested` and stops writing to the ring; Phase 5
/// watchdog reads that flag in addition to the lastCallbackHostTime stall.
///
/// **AudioConverter is load-bearing**, not optional (see Phase 0 spike
/// findings in `tasks/video-audio-engine-routing/research.md`): without it,
/// 44.1 kHz audio plays as bursts of silence at the engine's 48 kHz consumer
/// rate.
@MainActor
final class VideoAudioTap {
    enum Error: Swift.Error {
        case noAudioTrack
        case creationFailed(OSStatus)
    }

    private let context: VideoAudioTapContext
    private var tap: MTAudioProcessingTap?

    init(ringBuffer: LockFreeRingBuffer, expectedSampleRate: Float64) {
        self.context = VideoAudioTapContext(
            ringBuffer: ringBuffer,
            expectedSampleRate: expectedSampleRate
        )
    }

    /// Build an `AVMutableAudioMix` carrying this tap, ready to assign to
    /// `playerItem.audioMix`. The mix targets the first audio track on the
    /// player item's asset.
    func attach(to playerItem: AVPlayerItem) async throws -> AVMutableAudioMix {
        let audioTracks = try await playerItem.asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            throw Error.noAudioTrack
        }

        // Reset per-attach context state so a reused tap instance can't
        // inherit a previous asset's channel layout when the new one carries
        // no metadata.
        context.sourceChannelLayout = nil

        // Capture the source channel layout from the format description, when
        // present. AudioConverter's surround→stereo downmix matrix needs the
        // exact input layout to do the right thing — guessing from channel
        // count alone (`kAudioChannelLayoutTag_AAC_5_1` etc.) only handles the
        // common cases.
        if let formatDesc = try await audioTrack.load(.formatDescriptions).first {
            var sizeOut = 0
            if let layoutPtr = CMAudioFormatDescriptionGetChannelLayout(
                formatDesc, sizeOut: &sizeOut
            ), sizeOut > 0 {
                context.sourceChannelLayout = Data(bytes: layoutPtr, count: sizeOut)
            }
        }

        let retained = Unmanaged.passRetained(context)
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: retained.toOpaque(),
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: tapUnprepare,
            process: tapProcess
        )

        var tapRef: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tapRef
        )

        guard status == noErr, let tapRef else {
            // tapInit never ran — release our +1 on the context.
            retained.release()
            AppLog.error(.audio, "VideoAudioTap: MTAudioProcessingTapCreate failed (status: \(status))")
            throw Error.creationFailed(status)
        }

        self.tap = tapRef

        let inputParams = AVMutableAudioMixInputParameters(track: audioTrack)
        inputParams.audioTapProcessor = tapRef

        let mix = AVMutableAudioMix()
        mix.inputParameters = [inputParams]
        return mix
    }

    /// Drop our hold on the tap. Caller MUST have already set
    /// `playerItem.audioMix = nil` so AVPlayer's hold is gone too — otherwise
    /// the tap stays alive until the player item is dropped. Idempotent.
    /// `tapFinalize` fires once the last reference is released and is what
    /// drops the +1 on the context.
    func detach() {
        tap = nil
    }

    /// Mach absolute time of the most recent `tapProcess` callback, for the
    /// Phase 5 stall watchdog. Returns 0 before the first callback.
    var lastCallbackHostTime: UInt64 {
        context.lastCallbackHostTime.load(ordering: .relaxed)
    }

    /// Set when `tapPrepare` could not build an AudioConverter for a non-target
    /// source format. Phase 5 fallback engages immediately on this flag (don't
    /// wait for the host-time watchdog).
    var fallbackRequested: Bool {
        context.fallbackRequested.load(ordering: .relaxed)
    }
}

// MARK: - Context (heap-allocated, queue-confined)

/// Heap state shared across the C-convention tap callbacks. Owned by exactly
/// one `Unmanaged.passRetained` from `attach(to:)` and released in
/// `tapFinalize`. Confined to the tap render thread once `tapPrepare` runs.
final class VideoAudioTapContext: @unchecked Sendable {
    let ringBuffer: LockFreeRingBuffer
    let expectedSampleRate: Float64

    /// Source AudioChannelLayout bytes captured from the asset's format
    /// description, when available. Threaded into tapPrepare so the converter
    /// gets the actual surround layout (not a guess from channel count).
    var sourceChannelLayout: Data?

    var processingFormat: AudioStreamBasicDescription?
    var converter: AudioConverterRef?
    var converterScratch: UnsafeMutablePointer<Float>?
    var converterScratchFrameCapacity: Int = 0

    /// Single-shot handoff for the AudioConverter input callback. tapProcess
    /// stashes the source bufferList here, the input callback drains it once
    /// and clears, and subsequent input-callback invocations within the same
    /// FillComplexBuffer return `noMoreInputData`.
    var pendingSourceBufferList: UnsafeMutablePointer<AudioBufferList>?
    var pendingSourcePackets: UInt32 = 0

    let lastCallbackHostTime = ManagedAtomic<UInt64>(0)
    let fallbackRequested = ManagedAtomic<Bool>(false)

    init(ringBuffer: LockFreeRingBuffer, expectedSampleRate: Float64) {
        self.ringBuffer = ringBuffer
        self.expectedSampleRate = expectedSampleRate
    }

    deinit {
        if let converter {
            AudioConverterDispose(converter)
        }
        converterScratch?.deallocate()
    }
}

// MARK: - Constants

/// FourCC 'ndta' — signals the AudioConverter input callback that no more
/// input data is available for this FillComplexBuffer pass.
private let noMoreInputData: OSStatus = 0x6e647461

// MARK: - C-convention callbacks

private let tapInit: MTAudioProcessingTapInitCallback = { _, clientInfo, tapStorageOut in
    // Stash the opaque context pointer where every later callback can fetch
    // it via MTAudioProcessingTapGetStorage. tapStorageOut is just a slot;
    // it does not retain.
    tapStorageOut.pointee = clientInfo
}

private let tapFinalize: MTAudioProcessingTapFinalizeCallback = { tap in
    let storage = MTAudioProcessingTapGetStorage(tap)
    Unmanaged<VideoAudioTapContext>.fromOpaque(storage).release()
}

private let tapPrepare: MTAudioProcessingTapPrepareCallback = { tap, maxFrames, processingFormat in
    let ctx = Unmanaged<VideoAudioTapContext>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap))
        .takeUnretainedValue()

    let src = processingFormat.pointee
    ctx.processingFormat = src

    if shouldBypassConverter(source: src, expectedSampleRate: ctx.expectedSampleRate) {
        return
    }

    let stereoBytesPerFrame = UInt32(2 * MemoryLayout<Float>.size)
    var dst = AudioStreamBasicDescription(
        mSampleRate: ctx.expectedSampleRate,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagsNativeFloatPacked,
        mBytesPerPacket: stereoBytesPerFrame,
        mFramesPerPacket: 1,
        mBytesPerFrame: stereoBytesPerFrame,
        mChannelsPerFrame: 2,
        mBitsPerChannel: UInt32(MemoryLayout<Float>.size * 8),
        mReserved: 0
    )
    var srcCopy = src
    var converterRef: AudioConverterRef?
    let status = AudioConverterNew(&srcCopy, &dst, &converterRef)
    guard status == noErr, let converterRef else {
        ctx.fallbackRequested.store(true, ordering: .relaxed)
        return
    }

    // AudioConverter's default behavior for a channel-count mismatch is
    // *routing*, not mixing — mono → L+silent-R, 5.1 → drop the last 4
    // channels. We install explicit channel maps / layouts and turn on
    // PerformDownmix so the converter applies its real mix matrix.
    if !configureChannelMapping(
        converter: converterRef,
        sourceChannels: src.mChannelsPerFrame,
        sourceLayout: ctx.sourceChannelLayout
    ) {
        AudioConverterDispose(converterRef)
        ctx.fallbackRequested.store(true, ordering: .relaxed)
        return
    }

    ctx.converter = converterRef
    // Allocate scratch with 2× headroom over maxFrames to absorb upsampling
    // ratios (worst realistic case is 44.1 → 48 kHz at ~1.088×).
    let frames = max(Int(maxFrames) * 2, 1)
    ctx.converterScratch = .allocate(capacity: frames * 2)
    ctx.converterScratchFrameCapacity = frames
}

// MARK: - Format classification (testable)

/// Returns true when the source PCM format is byte-identical to the engine's
/// canonical format — interleaved native-endian Float32 stereo at the engine's
/// expected rate — so the converter can be skipped.
func shouldBypassConverter(
    source: AudioStreamBasicDescription,
    expectedSampleRate: Float64
) -> Bool {
    let stereoBytesPerFrame = UInt32(2 * MemoryLayout<Float>.size)
    let nativeFloatPacked = kAudioFormatFlagsNativeFloatPacked
    return source.mFormatID == kAudioFormatLinearPCM
        && (source.mFormatFlags & nativeFloatPacked) == nativeFloatPacked
        && (source.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0
        && source.mBitsPerChannel == 32
        && source.mChannelsPerFrame == 2
        && source.mBytesPerFrame == stereoBytesPerFrame
        && source.mFramesPerPacket == 1
        && source.mSampleRate == expectedSampleRate
}

/// Inferred AAC-style channel layout for surround channel counts (3-8) when
/// the format description didn't carry an explicit layout. mp4/m4v video
/// audio is overwhelmingly AAC, so AAC tags downmix more accurately than
/// the older `MPEG_*_A` tags. Returns nil for non-surround counts (mono,
/// stereo, 9+) — caller handles those separately.
func inferredSurroundChannelLayoutTag(
    forChannelCount channels: UInt32
) -> AudioChannelLayoutTag? {
    switch channels {
    case 3: return kAudioChannelLayoutTag_AAC_3_0
    case 4: return kAudioChannelLayoutTag_AAC_4_0
    case 5: return kAudioChannelLayoutTag_AAC_5_0
    case 6: return kAudioChannelLayoutTag_AAC_5_1
    case 7: return kAudioChannelLayoutTag_AAC_6_1
    case 8: return kAudioChannelLayoutTag_AAC_7_1
    default: return nil
    }
}

// MARK: - Channel mapping

/// Configure the converter's channel routing for a mono / stereo / surround
/// source so output is a true stereo signal. Returns false if the source
/// channel count cannot be mapped to a known layout (caller engages
/// fallback). Stereo input is a no-op — AudioConverter passes it through.
private func configureChannelMapping(
    converter: AudioConverterRef,
    sourceChannels: UInt32,
    sourceLayout: Data?
) -> Bool {
    switch sourceChannels {
    case 2:
        return true
    case 1:
        // Duplicate the single channel into both L and R. Channel-map index
        // i means "output channel i comes from input channel map[i]".
        let map: [Int32] = [0, 0]
        let size = UInt32(map.count * MemoryLayout<Int32>.size)
        let status = map.withUnsafeBufferPointer { ptr in
            AudioConverterSetProperty(
                converter,
                kAudioConverterChannelMap,
                size,
                ptr.baseAddress!
            )
        }
        return status == noErr
    default:
        // Surround: install input + output layouts and turn on
        // PerformDownmix so AudioConverter applies its built-in mix matrix.
        // Prefer the actual layout from the format description; fall back to
        // an AAC-style guess only if metadata didn't carry one.
        let inStatus: OSStatus
        if let sourceLayout {
            inStatus = sourceLayout.withUnsafeBytes { buffer -> OSStatus in
                guard let baseAddress = buffer.baseAddress else { return -1 }
                return AudioConverterSetProperty(
                    converter,
                    kAudioConverterInputChannelLayout,
                    UInt32(buffer.count),
                    baseAddress
                )
            }
        } else {
            guard let inputTag = inferredSurroundChannelLayoutTag(
                forChannelCount: sourceChannels
            ) else {
                return false
            }
            var inputLayout = AudioChannelLayout()
            inputLayout.mChannelLayoutTag = inputTag
            inStatus = AudioConverterSetProperty(
                converter,
                kAudioConverterInputChannelLayout,
                UInt32(MemoryLayout<AudioChannelLayout>.size),
                &inputLayout
            )
        }
        guard inStatus == noErr else { return false }

        var outputLayout = AudioChannelLayout()
        outputLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        let outStatus = AudioConverterSetProperty(
            converter,
            kAudioConverterOutputChannelLayout,
            UInt32(MemoryLayout<AudioChannelLayout>.size),
            &outputLayout
        )
        guard outStatus == noErr else { return false }

        var performDownmix: UInt32 = 1
        let dmStatus = AudioConverterSetProperty(
            converter,
            kAudioConverterPropertyPerformDownmix,
            UInt32(MemoryLayout<UInt32>.size),
            &performDownmix
        )
        return dmStatus == noErr
    }
}

private let tapUnprepare: MTAudioProcessingTapUnprepareCallback = { tap in
    let ctx = Unmanaged<VideoAudioTapContext>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap))
        .takeUnretainedValue()

    if let converter = ctx.converter {
        AudioConverterDispose(converter)
        ctx.converter = nil
    }
    ctx.converterScratch?.deallocate()
    ctx.converterScratch = nil
    ctx.converterScratchFrameCapacity = 0
}

private let tapProcess: MTAudioProcessingTapProcessCallback = {
    tap, framesToProcess, _, bufferList, framesOut, flagsOut in

    let ctx = Unmanaged<VideoAudioTapContext>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap))
        .takeUnretainedValue()

    // Pull source audio from upstream into the bufferList Core Audio handed us.
    // The bufferList must NOT be zeroed by us — AVPlayer plays it (Phase 3
    // mutes via player.volume = 0).
    let getStatus = MTAudioProcessingTapGetSourceAudio(
        tap, framesToProcess, bufferList, flagsOut, nil, framesOut
    )
    guard getStatus == noErr else { return }

    let frames = Int(framesOut.pointee)
    guard frames > 0 else { return }

    ctx.lastCallbackHostTime.store(mach_absolute_time(), ordering: .relaxed)

    if let converter = ctx.converter, let scratch = ctx.converterScratch {
        ctx.pendingSourceBufferList = bufferList
        ctx.pendingSourcePackets = UInt32(frames)

        var outAbl = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: 2,
                mDataByteSize: UInt32(ctx.converterScratchFrameCapacity * 2 * MemoryLayout<Float>.size),
                mData: UnsafeMutableRawPointer(scratch)
            )
        )
        var outFrames = UInt32(ctx.converterScratchFrameCapacity)
        let storage = MTAudioProcessingTapGetStorage(tap)
        let convStatus = AudioConverterFillComplexBuffer(
            converter,
            converterInputCallback,
            storage,
            &outFrames,
            &outAbl,
            nil
        )
        if (convStatus == noErr || convStatus == noMoreInputData) && outFrames > 0 {
            _ = ctx.ringBuffer.write(from: scratch, frameCount: Int(outFrames))
        }
        ctx.pendingSourceBufferList = nil
        ctx.pendingSourcePackets = 0
        return
    }

    if ctx.fallbackRequested.load(ordering: .relaxed) {
        // Converter was needed but couldn't be built — skip the ring write
        // entirely so the consumer drains to silence. Phase 5 fallback will
        // engage on the flag.
        return
    }

    // Bypass path: source already matches target format.
    if let dataPtr = bufferList.pointee.mBuffers.mData {
        let floats = dataPtr.bindMemory(to: Float.self, capacity: frames * 2)
        _ = ctx.ringBuffer.write(from: floats, frameCount: frames)
    }
}

// AudioConverter input callback. Hands off the source bufferList captured by
// tapProcess in one shot; subsequent invocations within the same
// FillComplexBuffer return `noMoreInputData`.
private let converterInputCallback: AudioConverterComplexInputDataProc = {
    _, ioNumberDataPackets, ioData, _, inUserData in

    guard let inUserData else {
        ioNumberDataPackets.pointee = 0
        return noMoreInputData
    }
    let ctx = Unmanaged<VideoAudioTapContext>.fromOpaque(inUserData).takeUnretainedValue()

    guard ctx.pendingSourcePackets > 0,
          let source = ctx.pendingSourceBufferList else {
        ioNumberDataPackets.pointee = 0
        return noMoreInputData
    }

    let outListPtr = UnsafeMutableAudioBufferListPointer(ioData)
    let inListPtr = UnsafeMutableAudioBufferListPointer(source)
    let bufferCount = min(outListPtr.count, inListPtr.count)
    for i in 0..<bufferCount {
        outListPtr[i] = inListPtr[i]
    }
    ioNumberDataPackets.pointee = ctx.pendingSourcePackets
    ctx.pendingSourcePackets = 0
    return noErr
}
