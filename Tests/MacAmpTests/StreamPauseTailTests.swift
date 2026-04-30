import Atomics
import AVFoundation
import Foundation
import Testing
@testable import MacAmp

@MainActor
@Suite("Stream Pause Tail", .tags(.audio))
struct StreamPauseTailTests {

    @Test("Silence gate forces zero output and isSilence=true")
    func silenceGateProducesZeros() async {
        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let gate = ManagedAtomic<UInt8>(0)
        let block = AudioEngineController.makeStreamRenderBlockForTesting(
            ringBuffer: ring,
            silenceGate: gate
        )

        let frames = 512
        let nonzeroSamples = [Float](repeating: 0.5, count: frames * 2)

        let written = nonzeroSamples.withUnsafeBufferPointer { ptr -> Int in
            ring.write(from: ptr.baseAddress!, frameCount: frames)
        }
        #expect(written == frames)
        let output1 = renderOnce(block: block, frames: frames)
        #expect(output1.contains(where: { $0 != 0 }))

        let written2 = nonzeroSamples.withUnsafeBufferPointer { ptr -> Int in
            ring.write(from: ptr.baseAddress!, frameCount: frames)
        }
        #expect(written2 == frames)
        gate.store(1, ordering: .releasing)
        let (output2, isSilence2) = renderOnceCapturingSilence(block: block, frames: frames)
        #expect(output2.allSatisfy { $0 == 0 })
        #expect(isSilence2)

        // Gate path zero-filled rather than consumed — refill not needed.
        gate.store(0, ordering: .releasing)
        let output3 = renderOnce(block: block, frames: frames)
        #expect(output3.contains(where: { $0 != 0 }))
    }

    @Test("Pause from idle does not crash and leaves no warmup state")
    func pauseDuringBuffering() async {
        let player = StreamPlayer()
        player.pause()
        await player.drainTransportChainForTesting()

        #expect(player.userPausedForTesting == true)
        #expect(player.isPlaying == false)
        #expect(player.isBuffering == false)
        #expect(player.isResumeWarmupActiveForTesting == false)
        #expect(player.hasPrebufferContinuationForTesting == false)
    }

    @Test("Rapid pause/resume cycles do not leak warmup tasks or continuations")
    func pauseSpam() async {
        let player = StreamPlayer()

        for _ in 0..<10 {
            player.pause()
            player.resume()
        }

        // End on pause() so the warmup is cancelled at test exit.
        player.pause()
        await player.drainTransportChainForTesting()

        #expect(player.isResumeWarmupActiveForTesting == false)
        #expect(player.hasPrebufferContinuationForTesting == false)
        #expect(player.isResumeWarmingForTesting == false)
    }

    @Test("User-paused stream suppresses reconnect on socket death and resume issues live-edge restart")
    func longPauseSuppressesReconnect() async {
        let audioPlayer = AudioPlayer()
        let streamPlayer = StreamPlayer()
        let coordinator = PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)

        streamPlayer.setWasActivelyPlayingForTesting(true)
        let station = RadioStation(name: "Test", streamURL: URL(string: "http://invalid.test/stream")!)
        streamPlayer.setCurrentStationForTesting(station)

        // Count bridge-teardown callbacks while preserving the coordinator's wiring.
        let counter = TestCounter()
        let priorTerminated = streamPlayer.onStreamTerminated
        streamPlayer.onStreamTerminated = {
            counter.value += 1
            priorTerminated?()
        }

        streamPlayer.pause()
        #expect(streamPlayer.userPausedForTesting == true)

        let reconnectsBefore = streamPlayer.attemptReconnectInvocationCountForTesting
        let startsBefore = streamPlayer.pipelineStartInvocationCountForTesting

        streamPlayer.injectPipelineTerminationForTesting(
            .networkError("conn lost", NSURLErrorNetworkConnectionLost)
        )

        #expect(streamPlayer.attemptReconnectInvocationCountForTesting == reconnectsBefore)
        #expect(streamPlayer.isReconnecting == false)
        #expect(counter.value == 1)
        #expect(audioPlayer.isBridgeActive == false)

        streamPlayer.resume()
        await streamPlayer.drainTransportChainForTesting()

        #expect(streamPlayer.pipelineStartInvocationCountForTesting > startsBefore)

        streamPlayer.stop()
        _ = coordinator
    }

    @Test("Resume during .playing while gate is raised drops the silence gate")
    func resumeWhilePlayingDropsSilenceGate() async {
        let audioPlayer = AudioPlayer()
        let streamPlayer = StreamPlayer()
        let coordinator = PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)

        let station = RadioStation(name: "Test", streamURL: URL(string: "http://invalid.test/stream")!)
        streamPlayer.setCurrentStationForTesting(station)

        let gateRecorder = TestGateRecorder()
        let priorForwarder = streamPlayer.silenceGateForwarder
        streamPlayer.silenceGateForwarder = { silenced in
            gateRecorder.lastValue = silenced
            gateRecorder.callCount += 1
            priorForwarder?(silenced)
        }

        // Synthesize warmup-cancelled-mid-flight: gate raised + pipeline already .playing.
        streamPlayer.silenceGateForwarder?(true)
        #expect(gateRecorder.lastValue == true)

        streamPlayer.injectPipelineStateForTesting(.playing)
        streamPlayer.resume()
        await streamPlayer.drainTransportChainForTesting()

        #expect(gateRecorder.lastValue == false)
        #expect(streamPlayer.isResumeWarmingForTesting == false)
        #expect(streamPlayer.isPlaying == true)
        #expect(streamPlayer.isBuffering == false)
        _ = coordinator
    }

    @Test("resume() while pipeline is .playing does not issue fresh pipeline.start")
    func resumeWhileAlreadyPlayingNoOp() async {
        let audioPlayer = AudioPlayer()
        let streamPlayer = StreamPlayer()
        let coordinator = PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)

        let station = RadioStation(name: "Test", streamURL: URL(string: "http://invalid.test/stream")!)
        streamPlayer.setCurrentStationForTesting(station)

        streamPlayer.injectPipelineStateForTesting(.playing)

        let startsBefore = streamPlayer.pipelineStartInvocationCountForTesting
        streamPlayer.resume()
        await streamPlayer.drainTransportChainForTesting()

        #expect(streamPlayer.pipelineStartInvocationCountForTesting == startsBefore)
        #expect(streamPlayer.isResumeWarmingForTesting == false)
        _ = coordinator
    }

    @Test("Transport generation invalidates stale chained tasks after stop()")
    func transportGenerationInvalidation() async {
        let audioPlayer = AudioPlayer()
        let streamPlayer = StreamPlayer()
        let coordinator = PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)

        let station = RadioStation(name: "Test", streamURL: URL(string: "http://invalid.test/stream")!)
        streamPlayer.setCurrentStationForTesting(station)

        // Three rapid resumes queue T1→T2→T3. stop() cancels only the tail (T3) plus
        // bumps the generation; T1/T2 are gated by the generation guard inside chainTransport.
        streamPlayer.resume()
        streamPlayer.resume()
        streamPlayer.resume()
        streamPlayer.stop()
        await streamPlayer.drainTransportChainForTesting()

        #expect(streamPlayer.pipelineStartInvocationCountForTesting == 0)
        _ = coordinator
    }

    @Test("read() concurrent with flush() does not advance readHead past writeHead")
    func readFlushRaceCASGuard() async {
        let ring = LockFreeRingBuffer(capacity: 4096, channelCount: 2)
        let frames = 512

        // Pre-fill so a "normal" read would have data to consume.
        let samples = [Float](repeating: 0.5, count: frames * 2)
        let written = samples.withUnsafeBufferPointer { ptr -> Int in
            ring.write(from: ptr.baseAddress!, frameCount: frames)
        }
        #expect(written == frames)

        // Inject a flush() at the exact race window: between memcpy and the CAS.
        // Without the CAS guard, the post-flush readHead.store would be undone by the
        // unconditional increment, pushing readHead past writeHead. With CAS, the
        // compareExchange fails and read() returns 0.
        ring.beforeReadHeadAdvanceForTesting = {
            ring.flush(newGeneration: false)
        }

        var dest = [Float](repeating: 999, count: frames * 2)
        let framesRead = dest.withUnsafeMutableBufferPointer { bufPtr -> Int in
            ring.read(into: bufPtr.baseAddress!, frameCount: frames)
        }

        #expect(framesRead == 0, "read() must bail when CAS detects a concurrent flush")
        #expect(
            ring.readHeadForTesting == ring.writeHeadForTesting,
            "readHead must remain at writeHead (where flush stored it), not past it"
        )

        // Cleanup so subsequent tests aren't affected.
        ring.beforeReadHeadAdvanceForTesting = nil
    }

    @Test("Render block tail under gate is zero from the first quantum")
    func tailLengthBound() async {
        let ring = LockFreeRingBuffer(capacity: 32768, channelCount: 2)
        let gate = ManagedAtomic<UInt8>(0)
        let block = AudioEngineController.makeStreamRenderBlockForTesting(
            ringBuffer: ring,
            silenceGate: gate
        )

        let totalFrames = 16000
        var tone = [Float](repeating: 0, count: totalFrames * 2)
        let twoPi = 2.0 * Float.pi
        for i in 0..<totalFrames {
            let v = sin(twoPi * 1000 * Float(i) / 44100.0) * 0.5
            tone[i * 2] = v
            tone[i * 2 + 1] = v
        }
        let written = tone.withUnsafeBufferPointer { ptr -> Int in
            ring.write(from: ptr.baseAddress!, frameCount: totalFrames)
        }
        #expect(written == totalFrames)

        gate.store(1, ordering: .releasing)

        let perCall = 512
        var anyNonZero = false
        for _ in 0..<8 {
            let (output, isSilence) = renderOnceCapturingSilence(block: block, frames: perCall)
            #expect(isSilence)
            if output.contains(where: { $0 != 0 }) {
                anyNonZero = true
            }
        }

        #expect(anyNonZero == false)
    }

    // MARK: - Helpers

    private func renderOnce(
        block: AVAudioSourceNodeRenderBlock,
        frames: Int
    ) -> [Float] {
        renderOnceCapturingSilence(block: block, frames: frames).output
    }

    private func renderOnceCapturingSilence(
        block: AVAudioSourceNodeRenderBlock,
        frames: Int
    ) -> (output: [Float], isSilence: Bool) {
        var output = [Float](repeating: 999, count: frames * 2)
        var isSilence = ObjCBool(false)
        var timestamp = AudioTimeStamp()

        output.withUnsafeMutableBufferPointer { bufPtr in
            let dataPtr = UnsafeMutableRawPointer(bufPtr.baseAddress!)
            let audioBuffer = AudioBuffer(
                mNumberChannels: 2,
                mDataByteSize: UInt32(frames * 2 * MemoryLayout<Float>.size),
                mData: dataPtr
            )
            var abl = AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)
            withUnsafePointer(to: &timestamp) { tsPtr in
                _ = block(&isSilence, tsPtr, AVAudioFrameCount(frames), &abl)
            }
        }

        return (output, isSilence.boolValue)
    }
}

@MainActor
private final class TestCounter {
    var value: Int = 0
}

@MainActor
private final class TestGateRecorder {
    var lastValue: Bool = false
    var callCount: Int = 0
}
