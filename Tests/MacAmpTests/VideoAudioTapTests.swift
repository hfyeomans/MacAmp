import AudioToolbox
import AVFoundation
import Foundation
import Testing
@testable import MacAmp

@MainActor
@Suite("Video Audio Tap", .tags(.audio))
struct VideoAudioTapTests {

    @Test("Attach returns a mix with one input parameters object for a valid audio asset")
    func attachReturnsAudioMixForAudioAsset() async throws {
        let url = try writeSilenceWAV(frames: 4_800, sampleRate: 48_000)
        defer { try? FileManager.default.removeItem(at: url) }

        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        let ring = LockFreeRingBuffer(capacity: 4_096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)

        let mix = try await tap.attach(to: item)
        #expect(mix.inputParameters.count == 1)
        let params = mix.inputParameters.first
        #expect(params != nil)
        #expect(params?.audioTapProcessor != nil)

        tap.detach()
    }

    @Test("Attach throws noAudioTrack when the asset has no audio")
    func attachThrowsForVideoOnlyAsset() async throws {
        // An empty composition has zero tracks of any media type — exercises the
        // .noAudioTrack guard without needing a video-only file on disk.
        let composition = AVMutableComposition()
        let item = AVPlayerItem(asset: composition)
        let ring = LockFreeRingBuffer(capacity: 4_096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)

        await #expect(throws: VideoAudioTap.Error.self) {
            _ = try await tap.attach(to: item)
        }
    }

    @Test("Detach is idempotent")
    func detachIsIdempotent() async throws {
        let url = try writeSilenceWAV(frames: 4_800, sampleRate: 48_000)
        defer { try? FileManager.default.removeItem(at: url) }

        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        let ring = LockFreeRingBuffer(capacity: 4_096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)
        _ = try await tap.attach(to: item)

        tap.detach()
        tap.detach() // no crash, no double-release
    }

    @Test("Public state is zeroed before the first tap callback fires")
    func initialStateBeforeFirstCallback() {
        let ring = LockFreeRingBuffer(capacity: 4_096, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: 48_000)

        #expect(tap.lastCallbackHostTime == 0)
        #expect(tap.fallbackRequested == false)
    }

    // MARK: - Format classification

    @Test("Bypass predicate accepts canonical Float32 stereo at expected rate")
    func bypassAcceptsCanonical() {
        let asbd = canonicalFloat32Stereo(sampleRate: 48_000)
        #expect(shouldBypassConverter(source: asbd, expectedSampleRate: 48_000))
    }

    @Test("Bypass rejects 64-bit float stereo at expected rate")
    func bypassRejectsFloat64() {
        var asbd = canonicalFloat32Stereo(sampleRate: 48_000)
        asbd.mBitsPerChannel = 64
        asbd.mBytesPerFrame = 16
        asbd.mBytesPerPacket = 16
        #expect(!shouldBypassConverter(source: asbd, expectedSampleRate: 48_000))
    }

    @Test("Bypass rejects mono")
    func bypassRejectsMono() {
        var asbd = canonicalFloat32Stereo(sampleRate: 48_000)
        asbd.mChannelsPerFrame = 1
        asbd.mBytesPerFrame = 4
        asbd.mBytesPerPacket = 4
        #expect(!shouldBypassConverter(source: asbd, expectedSampleRate: 48_000))
    }

    @Test("Bypass rejects sample-rate mismatch")
    func bypassRejectsSampleRateMismatch() {
        let asbd = canonicalFloat32Stereo(sampleRate: 44_100)
        #expect(!shouldBypassConverter(source: asbd, expectedSampleRate: 48_000))
    }

    @Test("Bypass rejects non-interleaved stereo")
    func bypassRejectsNonInterleaved() {
        var asbd = canonicalFloat32Stereo(sampleRate: 48_000)
        asbd.mFormatFlags |= kAudioFormatFlagIsNonInterleaved
        asbd.mBytesPerFrame = 4 // per-channel, not per-frame, in non-interleaved
        #expect(!shouldBypassConverter(source: asbd, expectedSampleRate: 48_000))
    }

    @Test("Bypass rejects integer PCM")
    func bypassRejectsInteger() {
        var asbd = canonicalFloat32Stereo(sampleRate: 48_000)
        asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        #expect(!shouldBypassConverter(source: asbd, expectedSampleRate: 48_000))
    }

    @Test("AAC surround layout map covers 3-8 channels")
    func surroundLayoutMapping() {
        #expect(inferredSurroundChannelLayoutTag(forChannelCount: 3) == kAudioChannelLayoutTag_AAC_3_0)
        #expect(inferredSurroundChannelLayoutTag(forChannelCount: 4) == kAudioChannelLayoutTag_AAC_4_0)
        #expect(inferredSurroundChannelLayoutTag(forChannelCount: 5) == kAudioChannelLayoutTag_AAC_5_0)
        #expect(inferredSurroundChannelLayoutTag(forChannelCount: 6) == kAudioChannelLayoutTag_AAC_5_1)
        #expect(inferredSurroundChannelLayoutTag(forChannelCount: 7) == kAudioChannelLayoutTag_AAC_6_1)
        #expect(inferredSurroundChannelLayoutTag(forChannelCount: 8) == kAudioChannelLayoutTag_AAC_7_1)
    }

    @Test("Surround layout map returns nil for non-surround counts")
    func surroundLayoutRejectsNonSurround() {
        #expect(inferredSurroundChannelLayoutTag(forChannelCount: 0) == nil)
        #expect(inferredSurroundChannelLayoutTag(forChannelCount: 1) == nil)
        #expect(inferredSurroundChannelLayoutTag(forChannelCount: 2) == nil)
        #expect(inferredSurroundChannelLayoutTag(forChannelCount: 9) == nil)
        #expect(inferredSurroundChannelLayoutTag(forChannelCount: 16) == nil)
    }
}

// MARK: - Helpers

private func canonicalFloat32Stereo(sampleRate: Float64) -> AudioStreamBasicDescription {
    let bytesPerFrame = UInt32(2 * MemoryLayout<Float>.size)
    return AudioStreamBasicDescription(
        mSampleRate: sampleRate,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagsNativeFloatPacked,
        mBytesPerPacket: bytesPerFrame,
        mFramesPerPacket: 1,
        mBytesPerFrame: bytesPerFrame,
        mChannelsPerFrame: 2,
        mBitsPerChannel: 32,
        mReserved: 0
    )
}

// MARK: - Helpers

@MainActor
private func writeSilenceWAV(frames: AVAudioFrameCount, sampleRate: Double) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("vatap_test_\(UUID().uuidString).wav")
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    buffer.frameLength = frames
    try file.write(from: buffer)
    return url
}
