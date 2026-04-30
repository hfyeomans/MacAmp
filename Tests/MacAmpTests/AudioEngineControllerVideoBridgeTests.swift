import AVFoundation
import Foundation
import Testing
@testable import MacAmp

@MainActor
@Suite("AudioEngineController Video Bridge", .tags(.audio))
struct AudioEngineControllerVideoBridgeTests {

    private func makeController() -> AudioEngineController {
        let eq = AVAudioUnitEQ(numberOfBands: 10)
        let viz = VisualizerPipeline()
        return AudioEngineController(eqNode: eq, visualizerPipeline: viz)
    }

    @Test("activateVideoBridge wires the video source node and flips the flag")
    func activateVideoBridgeAddsSourceNode() {
        let controller = makeController()
        defer { controller.shutdown() }

        #expect(controller.isVideoBridgeActive == false)

        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        controller.activateVideoBridge(ringBuffer: ring, sampleRate: 48_000)

        #expect(controller.isVideoBridgeActive == true)
        #expect(controller.isBridgeActive == false)
    }

    @Test("activateVideoBridge deactivates the stream bridge first")
    func activateVideoBridgeDeactivatesStreamBridge() {
        let controller = makeController()
        defer { controller.shutdown() }

        let streamRing = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        controller.activateStreamBridge(ringBuffer: streamRing, sampleRate: 44_100)
        #expect(controller.isBridgeActive == true)

        let videoRing = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        controller.activateVideoBridge(ringBuffer: videoRing, sampleRate: 48_000)

        #expect(controller.isBridgeActive == false)
        #expect(controller.isVideoBridgeActive == true)
    }

    @Test("deactivateVideoBridge is idempotent")
    func deactivateVideoBridgeIsIdempotent() {
        let controller = makeController()
        defer { controller.shutdown() }

        // No-op when inactive.
        controller.deactivateVideoBridge()
        #expect(controller.isVideoBridgeActive == false)

        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        controller.activateVideoBridge(ringBuffer: ring, sampleRate: 48_000)
        #expect(controller.isVideoBridgeActive == true)

        controller.deactivateVideoBridge()
        #expect(controller.isVideoBridgeActive == false)

        // Second call is a no-op (no crash, flag stays false).
        controller.deactivateVideoBridge()
        #expect(controller.isVideoBridgeActive == false)
    }

    @Test("activateStreamBridge deactivates an active video bridge first")
    func activateStreamBridgeDeactivatesVideoBridge() {
        let controller = makeController()
        defer { controller.shutdown() }

        let videoRing = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        controller.activateVideoBridge(ringBuffer: videoRing, sampleRate: 48_000)
        #expect(controller.isVideoBridgeActive == true)

        let streamRing = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        controller.activateStreamBridge(ringBuffer: streamRing, sampleRate: 44_100)

        #expect(controller.isVideoBridgeActive == false)
        #expect(controller.isBridgeActive == true)
    }

    @Test("Video render block reads frames from the ring buffer")
    func videoRenderBlockReadsRingBuffer() async {
        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let block = AudioEngineController.makeVideoRenderBlockForTesting(ringBuffer: ring)

        let frames = 512
        let nonzeroSamples = [Float](repeating: 0.5, count: frames * 2)
        let written = nonzeroSamples.withUnsafeBufferPointer { ptr -> Int in
            ring.write(from: ptr.baseAddress!, frameCount: frames)
        }
        #expect(written == frames)

        let output = renderOnce(block: block, frames: frames)
        #expect(output.contains(where: { $0 != 0 }))
    }

    @Test("Video render block zero-fills underflow and reports isSilence on empty ring")
    func videoRenderBlockSilenceOnEmptyRing() async {
        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let block = AudioEngineController.makeVideoRenderBlockForTesting(ringBuffer: ring)

        let frames = 256
        let (output, isSilence) = renderOnceCapturingSilence(block: block, frames: frames)
        #expect(output.allSatisfy { $0 == 0 })
        #expect(isSilence)
    }
}

// MARK: - Render helpers (mirrored from StreamPauseTailTests)

@MainActor
private func renderOnce(block: AVAudioSourceNodeRenderBlock, frames: Int) -> [Float] {
    let channels = 2
    var samples = [Float](repeating: 0, count: frames * channels)
    samples.withUnsafeMutableBufferPointer { samplesPtr in
        let buffer = AudioBuffer(
            mNumberChannels: UInt32(channels),
            mDataByteSize: UInt32(frames * channels * MemoryLayout<Float>.size),
            mData: UnsafeMutableRawPointer(samplesPtr.baseAddress!)
        )
        var bufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: buffer)
        var isSilence: ObjCBool = false
        var timestamp = AudioTimeStamp()
        _ = block(&isSilence, &timestamp, AVAudioFrameCount(frames), &bufferList)
    }
    return samples
}

@MainActor
private func renderOnceCapturingSilence(
    block: AVAudioSourceNodeRenderBlock,
    frames: Int
) -> ([Float], Bool) {
    let channels = 2
    var samples = [Float](repeating: 0, count: frames * channels)
    var observedSilence = false
    samples.withUnsafeMutableBufferPointer { samplesPtr in
        let buffer = AudioBuffer(
            mNumberChannels: UInt32(channels),
            mDataByteSize: UInt32(frames * channels * MemoryLayout<Float>.size),
            mData: UnsafeMutableRawPointer(samplesPtr.baseAddress!)
        )
        var bufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: buffer)
        var isSilence: ObjCBool = false
        var timestamp = AudioTimeStamp()
        _ = block(&isSilence, &timestamp, AVAudioFrameCount(frames), &bufferList)
        observedSilence = isSilence.boolValue
        _ = buffer
    }
    return (samples, observedSilence)
}
