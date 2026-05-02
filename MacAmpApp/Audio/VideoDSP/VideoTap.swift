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
    context.processingFormatTag.store(tag, ordering: .releasing)
    context.pendingSampleRate.store(asbd.mSampleRate.bitPattern, ordering: .relaxed)
    context.isActive.store(true, ordering: .relaxed)
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

    _ = context.processCallCount.add(1, ordering: .relaxed)
    _ = context.frameCount.add(UInt64(framesOut.pointee), ordering: .relaxed)

    let formatTag = context.processingFormatTag.load(ordering: .acquiring)
    guard formatTag == VideoTapContext.formatTagSupportedFloat32LPCM else {
        return  // Pass-through: unsupported ASBD (ADR-11) or not yet prepared.
    }

    // Phase 2 stops here. Phase 3 adds biquad + balance; Phase 4 adds
    // visualizer DSP. Until then this tap is observably pass-through —
    // AVPlayer's downstream pipeline plays the buffer unchanged.
}

// MARK: - Audio-mix builder + detach

enum VideoTap {
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
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PreEffects,
            &tapOut
        )
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
