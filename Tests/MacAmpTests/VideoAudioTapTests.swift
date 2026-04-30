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
