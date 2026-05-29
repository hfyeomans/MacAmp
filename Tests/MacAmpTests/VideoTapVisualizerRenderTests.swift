import AudioToolbox
import CoreAudioTypes
import Foundation
import Testing
@testable import MacAmp

/// Correctness tests for the Phase 4 video-tap visualizer producer
/// (`videoTapVisualizerRender`, ADR-6 dual-producer). Verifies the mono downmix
/// (interleaved + non-interleaved), RMS bars, and Goertzel spectrum against known
/// inputs, and that results reach the shared `VisualizerFeed`.
@Suite("VideoTap visualizer render", .tags(.audio))
struct VideoTapVisualizerRenderTests {
    static let sampleRate = 48_000.0
    static let frames = 2_048

    /// Render one non-interleaved buffer list (1 channel per buffer) and return the
    /// published data.
    static func renderNonInterleaved(_ channels: [[Float]]) -> VisualizerData? {
        let frameCount = channels.first?.count ?? 0
        let abl = AudioBufferList.allocate(maximumBuffers: channels.count)
        var allocs: [UnsafeMutablePointer<Float>] = []
        for (i, ch) in channels.enumerated() {
            let p = UnsafeMutablePointer<Float>.allocate(capacity: ch.count)
            p.initialize(from: ch, count: ch.count)
            allocs.append(p)
            abl[i] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(ch.count * 4), mData: p)
        }
        defer { for p in allocs { p.deallocate() }; free(abl.unsafeMutablePointer) }

        let scratch = VisualizerScratchBuffers()
        let feed = VisualizerFeed()
        videoTapVisualizerRender(bufferList: abl.unsafeMutablePointer, frames: frameCount,
                                 sampleRate: sampleRate, scratch: scratch, feed: feed)
        return feed.consume()
    }

    /// Render one interleaved buffer (N channels in a single buffer) and return the
    /// published data.
    static func renderInterleaved(_ interleaved: [Float], channels: Int) -> VisualizerData? {
        let frameCount = interleaved.count / channels
        let abl = AudioBufferList.allocate(maximumBuffers: 1)
        let p = UnsafeMutablePointer<Float>.allocate(capacity: interleaved.count)
        p.initialize(from: interleaved, count: interleaved.count)
        defer { p.deallocate(); free(abl.unsafeMutablePointer) }
        abl[0] = AudioBuffer(mNumberChannels: UInt32(channels),
                             mDataByteSize: UInt32(interleaved.count * 4), mData: p)

        let scratch = VisualizerScratchBuffers()
        let feed = VisualizerFeed()
        videoTapVisualizerRender(bufferList: abl.unsafeMutablePointer, frames: frameCount,
                                 sampleRate: sampleRate, scratch: scratch, feed: feed)
        return feed.consume()
    }

    static func sine(_ hz: Double, amplitude: Float = 1.0, count: Int = frames) -> [Float] {
        let w = 2.0 * Double.pi * hz / sampleRate
        return (0..<count).map { amplitude * Float(sin(w * Double($0))) }
    }

    @Test("Silence publishes all-zero RMS and spectrum")
    func silenceIsZero() throws {
        let data = try #require(Self.renderNonInterleaved([[Float](repeating: 0, count: Self.frames)]))
        #expect(data.rms.allSatisfy { $0 == 0 })
        #expect(data.spectrum.allSatisfy { $0 == 0 })
    }

    @Test("Full-scale tone drives RMS bars toward the clamp and a spectral peak")
    func toneHasEnergy() throws {
        let data = try #require(Self.renderNonInterleaved([Self.sine(1_000)]))
        #expect(data.rms.contains { $0 > 0.5 }, "expected strong RMS energy for a full-scale tone")
        #expect(data.rms.allSatisfy { $0 <= 1.0 }, "RMS must be clamped to 1.0")
        let peak = data.spectrum.max() ?? 0
        let peakBar = data.spectrum.firstIndex(of: peak) ?? -1
        #expect(peak > 0, "expected a spectral peak for a 1 kHz tone")
        #expect(peakBar > 0 && peakBar < 19, "1 kHz peak should land in a mid bar, not the edges (got bar \(peakBar))")
    }

    @Test("Mono downmix: interleaved stereo matches non-interleaved")
    func interleavedMatchesNonInterleaved() throws {
        let left = Self.sine(440, amplitude: 0.7)
        let right = Self.sine(1_500, amplitude: 0.4)
        let nonInter = try #require(Self.renderNonInterleaved([left, right]))

        var interleaved = [Float](repeating: 0, count: left.count * 2)
        for i in 0..<left.count { interleaved[i * 2] = left[i]; interleaved[i * 2 + 1] = right[i] }
        let inter = try #require(Self.renderInterleaved(interleaved, channels: 2))

        for b in 0..<20 {
            #expect(abs(nonInter.rms[b] - inter.rms[b]) < 1e-5, "rms bar \(b) differs across layouts")
            #expect(abs(nonInter.spectrum[b] - inter.spectrum[b]) < 1e-5, "spectrum bar \(b) differs across layouts")
        }
    }

    @Test("Video visualization poll timer starts and stops cleanly")
    @MainActor
    func videoVisualizationTimerLifecycle() {
        let pipeline = VisualizerPipeline()
        #expect(pipeline.isPollTimerActive == false)
        pipeline.startVideoVisualization()
        #expect(pipeline.isPollTimerActive == true, "startVideoVisualization must schedule the poll timer")
        // Idempotent: a second start (e.g. repeat-one restart) does not leave a dangling timer.
        pipeline.startVideoVisualization()
        #expect(pipeline.isPollTimerActive == true)
        pipeline.stopVideoVisualization()
        #expect(pipeline.isPollTimerActive == false, "stopVideoVisualization must invalidate the poll timer")
    }

    @Test("Stereo downmix averages channels (L+R)/2")
    func stereoDownmixAverages() throws {
        // Identical L/R → mono == that signal → same RMS as a single-channel render.
        let tone = Self.sine(800, amplitude: 0.5)
        let dual = try #require(Self.renderNonInterleaved([tone, tone]))
        let single = try #require(Self.renderNonInterleaved([tone]))
        for b in 0..<20 {
            #expect(abs(dual.rms[b] - single.rms[b]) < 1e-5, "identical-stereo downmix should equal mono at bar \(b)")
        }
    }
}
