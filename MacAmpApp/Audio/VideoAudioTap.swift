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

    let isFloat = (src.mFormatFlags & kAudioFormatFlagIsFloat) != 0
    let isPacked = (src.mFormatFlags & kAudioFormatFlagIsPacked) != 0
    let isNonInterleaved = (src.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0
    let stereoBytesPerFrame = UInt32(2 * MemoryLayout<Float>.size)
    let bypassConverter = src.mFormatID == kAudioFormatLinearPCM
        && isFloat
        && isPacked
        && !isNonInterleaved
        && src.mBitsPerChannel == 32
        && src.mChannelsPerFrame == 2
        && src.mBytesPerFrame == stereoBytesPerFrame
        && src.mSampleRate == ctx.expectedSampleRate

    if bypassConverter { return }

    var dst = AudioStreamBasicDescription(
        mSampleRate: ctx.expectedSampleRate,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
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
    // channels. To get duplication for mono and a real downmix matrix for
    // surround, we install explicit channel maps / layouts.
    if !configureChannelMapping(converter: converterRef, sourceChannels: src.mChannelsPerFrame) {
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

/// Configure the converter's channel routing for a mono / stereo / surround
/// source so output is a true stereo signal. Returns false if the source
/// channel count cannot be mapped to a known layout (caller engages
/// fallback). Stereo input is a no-op — AudioConverter passes it through.
private func configureChannelMapping(
    converter: AudioConverterRef,
    sourceChannels: UInt32
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
        // Surround / unusual channel counts: install standard layouts so
        // AudioConverter applies its built-in downmix matrix to stereo.
        guard let inputTag = surroundLayoutTag(forChannelCount: sourceChannels) else {
            return false
        }
        var inputLayout = AudioChannelLayout()
        inputLayout.mChannelLayoutTag = inputTag
        var outputLayout = AudioChannelLayout()
        outputLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        let layoutSize = UInt32(MemoryLayout<AudioChannelLayout>.size)
        let inStatus = AudioConverterSetProperty(
            converter,
            kAudioConverterInputChannelLayout,
            layoutSize,
            &inputLayout
        )
        let outStatus = AudioConverterSetProperty(
            converter,
            kAudioConverterOutputChannelLayout,
            layoutSize,
            &outputLayout
        )
        return inStatus == noErr && outStatus == noErr
    }
}

/// Common surround layouts found in mp4/mov/m4v audio tracks. Returns nil
/// for non-standard channel counts; the caller treats that as fallback.
private func surroundLayoutTag(forChannelCount channels: UInt32) -> AudioChannelLayoutTag? {
    switch channels {
    case 3: return kAudioChannelLayoutTag_MPEG_3_0_A    // L R C
    case 4: return kAudioChannelLayoutTag_Quadraphonic
    case 5: return kAudioChannelLayoutTag_MPEG_5_0_A    // L R C Ls Rs
    case 6: return kAudioChannelLayoutTag_MPEG_5_1_A    // L R C LFE Ls Rs
    case 7: return kAudioChannelLayoutTag_MPEG_6_1_A
    case 8: return kAudioChannelLayoutTag_MPEG_7_1_A
    default: return nil
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
