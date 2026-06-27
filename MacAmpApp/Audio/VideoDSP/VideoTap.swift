@preconcurrency import AVFoundation
import AudioToolbox
import CoreAudioTypes
import Foundation
import MediaToolbox

/// Errors raised while building a video-side processing tap. Only
/// `createFailed` is currently thrown — `noAudioTrack` is handled at
/// the caller (the audioMixBuilder closure simply returns `nil` to
/// `loadVideo`, which then constructs the player without a tap).
enum VideoTapError: Error {
    case createFailed(OSStatus)
}

/// Cached Mach timebase, queried once at load so the render path does no syscall.
private let videoTapMachTimebase: mach_timebase_info_data_t = {
    var info = mach_timebase_info_data_t()
    mach_timebase_info(&info)
    return info
}()

/// Convert a `mach_absolute_time` tick delta to nanoseconds (render-thread-safe;
/// fast-paths the 1:1 timebase common on Apple Silicon).
@inline(__always)
private func videoTapHostTicksToNanos(_ ticks: UInt64) -> UInt64 {
    let tb = videoTapMachTimebase
    return tb.numer == tb.denom ? ticks : ticks &* UInt64(tb.numer) / UInt64(tb.denom)
}

/// Force the one-time initialization of `videoTapMachTimebase` (a file-scope `let`,
/// lazily initialized via a once-token). Called from `buildAudioMix` on the main
/// actor so the render thread never pays the once-token on its first sampled callback.
private func prewarmVideoTapTimebase() {
    _ = videoTapMachTimebase.numer
}

// MARK: - C-callback closures
//
// All five callbacks are file-scope `private let` constants typed to the
// matching `MTAudioProcessingTap*Callback` typealias. They are invoked on
// the render thread (`MTAudioProcessingTap`-owned, not Swift-concurrency
// managed). Per ADR-3 the closures use only `Unmanaged` lookup +
// atomic-disciplined Context fields; nothing inside captures Swift state.

private let tapInit: MTAudioProcessingTapInitCallback = { _, clientInfo, tapStorageOut in
    tapStorageOut.pointee = clientInfo
}

private let tapFinalize: MTAudioProcessingTapFinalizeCallback = { tap in
    let storage = MTAudioProcessingTapGetStorage(tap)
    Unmanaged<VideoTapContext>.fromOpaque(storage).release()
}

private let tapPrepare: MTAudioProcessingTapPrepareCallback = { tap, _, processingFormat in
    let storage = MTAudioProcessingTapGetStorage(tap)
    let context = Unmanaged<VideoTapContext>.fromOpaque(storage).takeUnretainedValue()

    let asbd = processingFormat.pointee
    let isLinearPCM = asbd.mFormatID == kAudioFormatLinearPCM
    let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
    let is32Bit = asbd.mBitsPerChannel == 32
    let supported = isLinearPCM && isFloat && is32Bit

    let tag = supported
        ? VideoTapContext.formatTagSupportedFloat32LPCM
        : VideoTapContext.formatTagUnsupported
    // Publish the sample rate (and isActive) BEFORE the release-store of the format
    // tag: `tapProcess` acquire-loads the tag as the gate, so anything that must be
    // visible alongside it (the budget math + visualizer both read `pendingSampleRate`)
    // has to be stored first. Otherwise a render thread that sees the new tag could
    // still read a stale/zero sample rate.
    context.pendingSampleRate.store(asbd.mSampleRate.bitPattern, ordering: .relaxed)
    context.isActive.store(true, ordering: .relaxed)
    context.processingFormatTag.store(tag, ordering: .releasing)
}

private let tapUnprepare: MTAudioProcessingTapUnprepareCallback = { tap in
    let storage = MTAudioProcessingTapGetStorage(tap)
    let context = Unmanaged<VideoTapContext>.fromOpaque(storage).takeUnretainedValue()
    context.isActive.store(false, ordering: .relaxed)
}

private let tapProcess: MTAudioProcessingTapProcessCallback = { tap, framesToProcess, _, bufferList, framesOut, flagsOut in
    let storage = MTAudioProcessingTapGetStorage(tap)
    let context = Unmanaged<VideoTapContext>.fromOpaque(storage).takeUnretainedValue()

    let status = MTAudioProcessingTapGetSourceAudio(tap, framesToProcess, bufferList, flagsOut, nil, framesOut)
    guard status == noErr else { return }

    let callIndex = context.processCallCount.add(1, ordering: .relaxed).oldValue  // pre-increment value
    _ = context.frameCount.add(UInt64(framesOut.pointee), ordering: .relaxed)

    let formatTag = context.processingFormatTag.load(ordering: .acquiring)
    guard formatTag == VideoTapContext.formatTagSupportedFloat32LPCM else {
        return  // Pass-through: unsupported ASBD (ADR-11) or not yet prepared.
    }

    // ===== Phase 3 render path (ADR-5 steps 2-6) =====

    // Step 2 — flush filter state on a stream discontinuity (seek / new stream)
    // so stale history does not bleed across the cut (ADR-9).
    if (flagsOut.pointee & MTAudioProcessingTapFlags(kMTAudioProcessingTapFlag_StartOfStream)) != 0 {
        context.cascade.reset()
    }

    let frames = Int(framesOut.pointee)
    guard frames > 0 else { return }

    // Phase 6 — deadline-miss telemetry: time every 64th callback only (the timing
    // itself runs solely on sampled callbacks). `callIndex` is the pre-increment
    // counter, so this fires on callbacks 0, 64, 128, …
    let sampleTiming = (callIndex & 63) == 0
    let startTicks = sampleTiming ? mach_absolute_time() : 0

    let preamp = Float(bitPattern: context.preampLinearGainBits.load(ordering: .relaxed))
    let eqOn = context.isEqOn.load(ordering: .relaxed)
    let balance = Float(bitPattern: context.balance.load(ordering: .relaxed))

    // Step 5 prep — refresh the render-owned coefficient cache via the Context's
    // Mutex with a non-blocking trylock (ADR-4 amendment #2). Double-optional:
    // outer nil = contended → reuse cache; .some(nil) = no install yet → bypass;
    // .some(.some) = update cache.
    if eqOn {
        if !context.cascade.isEngaged {
            context.cascade.reset()  // clean re-enable: flush stale filter history
            context.cascade.isEngaged = true
        }
        switch context.coefficients.withLockIfAvailable({ $0 }) {
        case .some(.some(let set)): context.cascade.currentCoefficients = set
        case .some(.none): context.cascade.currentCoefficients = nil
        case .none: break
        }
    } else {
        context.cascade.isEngaged = false
    }

    // Step 6 params — balance ∈ [-1, 1], 0.0 = center (see `VideoTap.balanceGains`).
    let applyBalance = balance != 0.0
    let (leftGain, rightGain) = VideoTap.balanceGains(balance)
    let applyPreamp = preamp != 1.0

    let bufferPointer = UnsafeMutableAudioBufferListPointer(bufferList)
    var globalChannel = 0
    for buffer in bufferPointer {
        guard let raw = buffer.mData else { continue }
        let channelsInBuffer = Int(buffer.mNumberChannels)
        guard channelsInBuffer > 0 else { continue }
        let floatCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
        let framesInBuffer = floatCount / channelsInBuffer
        let samples = raw.assumingMemoryBound(to: Float.self)

        // Step 3 — preamp over every sample in this buffer.
        if applyPreamp {
            for i in 0..<floatCount { samples[i] *= preamp }
        }

        let stride = channelsInBuffer
        for c in 0..<channelsInBuffer {
            let channelIndex = globalChannel + c
            let base = samples + c

            // Steps 4 + 5 — gated EQ cascade.
            if eqOn {
                context.cascade.process(base, frameCount: framesInBuffer, channel: channelIndex, stride: stride)
            }

            // Step 6 — balance trim on L (ch 0) / R (ch 1); higher channels untouched.
            if applyBalance {
                let gain: Float? = channelIndex == 0 ? leftGain : (channelIndex == 1 ? rightGain : nil)
                if let gain, gain != 1.0 {
                    var p = base
                    for _ in 0..<framesInBuffer { p.pointee *= gain; p += stride }
                }
            }
        }
        globalChannel += channelsInBuffer
    }

    // Step 7 — visualizer feed (ADR-6 dual-producer). Publish pre-computed arrays
    // from the now-processed buffer to the shared feed (non-blocking trylock).
    let sampleRate = Double(bitPattern: context.pendingSampleRate.load(ordering: .relaxed))
    videoTapVisualizerRender(bufferList: bufferList, frames: frames, sampleRate: sampleRate,
                             scratch: context.scratch, feed: context.feed)

    // Phase 6 — close the deadline-miss sample over the full DSP + visualizer work.
    // ADVISORY telemetry: 1/64 sampling gives production observability, NOT the dense
    // per-callback coverage Phase 8's hard "99p ≤10% / no single >50%" CPU gate needs
    // (Phase 8 adds an every-callback benchmark mode).
    if sampleTiming, sampleRate.isFinite, sampleRate > 0 {
        let endTicks = mach_absolute_time()
        let elapsedNanos = videoTapHostTicksToNanos(endTicks &- startTicks)
        let budgetNanos = UInt64(Double(frames) / sampleRate * 1_000_000_000)
        context.recordProcessingDeadline(elapsedNanos: elapsedNanos, budgetNanos: budgetNanos, nowHostTime: endTicks)
    }
}

// MARK: - Audio-mix builder + detach

enum VideoTap {
    #if DEBUG
    /// Test seam: when true, `buildAudioMix` takes the `MTAudioProcessingTapCreate`
    /// failure branch (ADR-10 release-on-fail). DEBUG-only; reset after each use.
    nonisolated(unsafe) static var _testForceTapCreateFailure = false
    #endif

    /// Stereo balance gain law for `tapProcess` step 6. `balance` ∈ [-1, 1] with
    /// 0.0 = center — the SAME convention as `AudioPlayer.balance` /
    /// `AVAudioNode.pan`, so the Phase 5 fanout can write the app's balance value
    /// straight through. Unity on the near channel, linear attenuation of the far
    /// channel (full-left `-1` → R muted; full-right `+1` → L muted). Input is
    /// clamped to [-1, 1] defensively.
    static func balanceGains(_ balance: Float) -> (left: Float, right: Float) {
        let b = min(max(balance, -1.0), 1.0)
        let left: Float = b <= 0 ? 1.0 : 1.0 - b
        let right: Float = b >= 0 ? 1.0 : 1.0 + b
        return (left, right)
    }

    /// Build the `MTAudioProcessingTap` and wrap it in an
    /// `AVMutableAudioMix` for assignment to a not-yet-constructed
    /// `AVPlayerItem.audioMix`. Caller must subsequently set
    /// `playerItem.audioMix = <returned mix>` BEFORE constructing the
    /// `AVPlayer` (per ADR-7 — `audioMix` is set once and not mutated
    /// during playback). On `MTAudioProcessingTapCreate` failure the
    /// retained Context is released before throwing so the +1 retain
    /// does not leak (ADR-10).
    @MainActor
    static func buildAudioMix(audioTrack: AVAssetTrack, context: VideoTapContext) throws -> AVMutableAudioMix {
        prewarmVideoTapTimebase()  // init the Mach timebase off the render thread (Phase 6)
        let retained = Unmanaged.passRetained(context)
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(retained.toOpaque()),
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: tapUnprepare,
            process: tapProcess
        )

        var tapOut: MTAudioProcessingTap?
        let status: OSStatus
        #if DEBUG
        // Test seam (ADR-10): SKIP the real create and force the failure branch so
        // lifecycle tests can assert the +1 `passRetained` is released, not leaked.
        // Must short-circuit BEFORE the real create — otherwise a real tap would be
        // built and its `tapFinalize` would also release the Context (double release).
        if VideoTap._testForceTapCreateFailure {
            status = OSStatus(-1)
        } else {
            status = MTAudioProcessingTapCreate(
                kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tapOut)
        }
        #else
        status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tapOut)
        #endif
        guard status == noErr, let tap = tapOut else {
            retained.release()
            throw VideoTapError.createFailed(status)
        }

        let inputParams = AVMutableAudioMixInputParameters(track: audioTrack)
        inputParams.audioTapProcessor = tap

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = [inputParams]
        return audioMix
    }

    /// Detach the tap from a currently-active player item. Used during
    /// teardown when the surrounding player is going away. AVPlayer's
    /// deallocation chain fires `tapFinalize` (possibly asynchronously)
    /// once the last reference to the tap drops, releasing the Context.
    /// Caller is expected to pause the player before calling detach to
    /// honor ADR-7's "audioMix not mutated during playback".
    @MainActor
    static func detach(from playerItem: AVPlayerItem) {
        playerItem.audioMix = nil
    }
}
