import AVFoundation
import Foundation
import MediaToolbox
import Synchronization

// MARK: - Tap context (heap object shared with C-callback boundary)

final class TapContext: @unchecked Sendable {
    let gainBits: Atomic<UInt32>
    let processCallCount: Atomic<UInt64>
    let totalFrames: Atomic<UInt64>
    let inPlaceConfirmed: Atomic<Bool>
    let modificationVerified: Atomic<Bool>

    init(initialGain: Float) {
        self.gainBits = Atomic<UInt32>(initialGain.bitPattern)
        self.processCallCount = Atomic<UInt64>(0)
        self.totalFrames = Atomic<UInt64>(0)
        self.inPlaceConfirmed = Atomic<Bool>(false)
        self.modificationVerified = Atomic<Bool>(false)
    }

    var gain: Float {
        Float(bitPattern: gainBits.load(ordering: .relaxed))
    }
}

// MARK: - C-convention tap callbacks

private let tapInit: MTAudioProcessingTapInitCallback = { _, clientInfo, tapStorageOut in
    tapStorageOut.pointee = clientInfo
}

private let tapFinalize: MTAudioProcessingTapFinalizeCallback = { tap in
    let storage = MTAudioProcessingTapGetStorage(tap)
    Unmanaged<TapContext>.fromOpaque(storage).release()
}

private let tapPrepare: MTAudioProcessingTapPrepareCallback = { _, maxFrames, processingFormat in
    let asbd = processingFormat.pointee
    let interleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0
    let formatTag = String(format: "0x%08X", asbd.mFormatID)
    print("[tapPrepare] sampleRate=\(asbd.mSampleRate) channels=\(asbd.mChannelsPerFrame) bitsPerChannel=\(asbd.mBitsPerChannel) interleaved=\(interleaved) formatID=\(formatTag) maxFrames=\(maxFrames)")
}

private let tapUnprepare: MTAudioProcessingTapUnprepareCallback = { _ in
    print("[tapUnprepare]")
}

private let tapProcess: MTAudioProcessingTapProcessCallback = { tap, framesToProcess, _, bufferList, framesOut, flagsOut in
    let storage = MTAudioProcessingTapGetStorage(tap)
    let context = Unmanaged<TapContext>.fromOpaque(storage).takeUnretainedValue()

    let status = MTAudioProcessingTapGetSourceAudio(tap, framesToProcess, bufferList, flagsOut, nil, framesOut)
    guard status == noErr else {
        print("[tapProcess] GetSourceAudio failed: \(status)")
        return
    }

    let actualFrames = framesOut.pointee
    _ = context.processCallCount.add(1, ordering: .relaxed)
    _ = context.totalFrames.add(UInt64(actualFrames), ordering: .relaxed)

    let abl = UnsafeMutableAudioBufferListPointer(bufferList)
    if !context.inPlaceConfirmed.load(ordering: .relaxed),
       let firstData = abl.first?.mData {
        context.inPlaceConfirmed.store(true, ordering: .relaxed)
        print("[tapProcess] In-place buffer confirmed: numberBuffers=\(abl.count) firstBuffer.mData=\(firstData) frames=\(actualFrames)")
    }

    let gain = context.gain
    var preMod: Float = 0
    var postMod: Float = 0
    let needsVerify = !context.modificationVerified.load(ordering: .relaxed)

    if needsVerify, let firstBuf = abl.first, let raw = firstBuf.mData, actualFrames > 0 {
        preMod = raw.assumingMemoryBound(to: Float.self)[0]
    }

    for buffer in abl {
        let frameCount = Int(actualFrames)
        let channelsPerBuffer = Int(buffer.mNumberChannels)
        let totalSamples = frameCount * channelsPerBuffer
        guard let raw = buffer.mData else { continue }
        let ptr = raw.assumingMemoryBound(to: Float.self)
        for i in 0..<totalSamples {
            ptr[i] *= gain
        }
    }

    if needsVerify, abs(preMod) > 0.001, let firstBuf = abl.first, let raw = firstBuf.mData {
        postMod = raw.assumingMemoryBound(to: Float.self)[0]
        let expected = preMod * gain
        let tolerance = abs(expected) * 0.01 + 1e-6
        if abs(postMod - expected) <= tolerance {
            context.modificationVerified.store(true, ordering: .relaxed)
            print("[tapProcess] Write verified: pre=\(preMod) post=\(postMod) expected=\(expected) (gain=\(gain))")
        }
    }
}

// MARK: - Main

@MainActor
func runSpike() async throws {
    guard CommandLine.arguments.count >= 2 else {
        print("Usage: \(CommandLine.arguments[0]) <video-file-path> [gain=0.1]")
        exit(2)
    }

    let path = CommandLine.arguments[1]
    let gainArg = CommandLine.arguments.count >= 3 ? Float(CommandLine.arguments[2]) ?? 0.1 : 0.1
    let url = URL(fileURLWithPath: path)
    let asset = AVURLAsset(url: url)

    print("[main] Asset: \(path)")
    print("[main] Gain: \(gainArg) (\(20.0 * log10(Double(gainArg))) dB)")

    let context = TapContext(initialGain: gainArg)

    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
    guard let audioTrack = audioTracks.first else {
        print("[main] No audio track in asset")
        exit(1)
    }
    let duration = try await asset.load(.duration)
    print("[main] Duration: \(String(format: "%.2f", CMTimeGetSeconds(duration)))s")

    var callbacks = MTAudioProcessingTapCallbacks(
        version: kMTAudioProcessingTapCallbacksVersion_0,
        clientInfo: UnsafeMutableRawPointer(Unmanaged.passRetained(context).toOpaque()),
        init: tapInit,
        finalize: tapFinalize,
        prepare: tapPrepare,
        unprepare: tapUnprepare,
        process: tapProcess
    )

    var tapOut: MTAudioProcessingTap?
    let createStatus = MTAudioProcessingTapCreate(
        kCFAllocatorDefault,
        &callbacks,
        kMTAudioProcessingTapCreationFlag_PreEffects,
        &tapOut
    )
    guard createStatus == noErr, let tap = tapOut else {
        print("[main] MTAudioProcessingTapCreate failed: \(createStatus)")
        exit(1)
    }
    print("[main] Tap created with _PreEffects flag")

    let inputParams = AVMutableAudioMixInputParameters(track: audioTrack)
    inputParams.audioTapProcessor = tap

    let audioMix = AVMutableAudioMix()
    audioMix.inputParameters = [inputParams]

    let item = AVPlayerItem(asset: asset)
    item.audioMix = audioMix
    let player = AVPlayer(playerItem: item)

    var ready = false
    for _ in 0..<50 {
        if item.status == .readyToPlay {
            ready = true
            break
        }
        if item.status == .failed {
            print("[main] Item failed: \(String(describing: item.error))")
            exit(1)
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    guard ready else {
        print("[main] Timed out waiting for readyToPlay")
        exit(1)
    }

    print("[main] Playing… you should hear \(String(format: "%.1f", 20.0 * log10(Double(gainArg)))) dB attenuation vs unmodified")
    player.play()

    let durationSec = CMTimeGetSeconds(duration)
    try await Task.sleep(nanoseconds: UInt64((durationSec + 0.5) * 1_000_000_000))

    print("[main] -- summary --")
    print("[main] tapProcess invocations:    \(context.processCallCount.load(ordering: .relaxed))")
    print("[main] frames processed:          \(context.totalFrames.load(ordering: .relaxed))")
    print("[main] in-place buffer confirmed: \(context.inPlaceConfirmed.load(ordering: .relaxed))")
    print("[main] modification verified:     \(context.modificationVerified.load(ordering: .relaxed))")
}

try await runSpike()
