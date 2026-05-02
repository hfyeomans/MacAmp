import Foundation
import os

// MARK: - Visualizer Feed (Lock-Free Audio-to-Main Transfer)

/// Single-slot SPSC hand-off carrying pre-computed visualizer arrays from the
/// audio render thread to the main thread. Uses `os_unfair_lock` with `trylock`
/// on the audio thread (non-blocking, drops frame on contention) and a regular
/// blocking lock on the main thread (safe to block briefly at 30 Hz poll).
///
/// **Producers:** the engine-side mainMixerNode tap (existing) and the video-side
/// `MTAudioProcessingTap` render path (S3-2 `avplayer-native-video-dsp`). Both
/// publish pre-computed arrays — RMS×20, Goertzel spectrum×20, oscilloscope
/// waveform×76, Butterchurn FFT spectrum×1024, Butterchurn FFT waveform×1024 —
/// not raw PCM. Each producer runs the DSP into its own per-tap
/// `VisualizerScratchBuffers` instance and calls `tryPublish(from:)`.
///
/// **Consumer:** `VisualizerPipeline` polls `consume()` from a 30 Hz main-thread
/// `Timer` in `.common` run-loop mode. Last-write-wins; no queue.
final class VisualizerFeed: @unchecked Sendable {
    private var rms = [Float](repeating: 0, count: 20)
    private var spectrum = [Float](repeating: 0, count: 20)
    private var waveform = [Float](repeating: 0, count: 76)
    private var bcSpectrum = [Float](repeating: 0, count: 1024)
    private var bcWaveform = [Float](repeating: 0, count: 1024)
    private var waveformCount: Int = 0
    private var rmsCount: Int = 0
    private var spectrumCount: Int = 0

    private var lock = os_unfair_lock()
    private var generation: UInt64 = 0
    private var lastConsumed: UInt64 = 0

    /// Copy Float elements via memcpy. Audio-thread safe (no allocation).
    private func copyFloatBuffer(from source: [Float], to destination: inout [Float], count: Int? = nil) {
        let limit = min(source.count, destination.count)
        let n = min(count ?? limit, limit)
        guard n > 0 else { return }
        source.withUnsafeBufferPointer { src in
            destination.withUnsafeMutableBufferPointer { dst in
                guard let s = src.baseAddress, let d = dst.baseAddress else { return }
                memcpy(d, s, n * MemoryLayout<Float>.stride)
            }
        }
    }

    /// Audio thread: try to publish data (non-blocking).
    /// Returns false if lock is contended (frame is dropped).
    func tryPublish(from scratch: VisualizerScratchBuffers, oscilloscopeSamples: Int, validFrameCount: Int) -> Bool {
        guard os_unfair_lock_trylock(&lock) else { return false }
        defer { os_unfair_lock_unlock(&lock) }

        let rCount = min(scratch.rms.count, rms.count)
        copyFloatBuffer(from: scratch.rms, to: &rms, count: rCount)
        rmsCount = rCount

        let sCount = min(scratch.spectrum.count, spectrum.count)
        copyFloatBuffer(from: scratch.spectrum, to: &spectrum, count: sCount)
        spectrumCount = sCount

        // Downsample waveform using validFrameCount (not mono.count)
        let scratchMono = scratch.mono
        let monoLen = validFrameCount
        let step = max(1, monoLen / oscilloscopeSamples)
        let actualSamples = min(oscilloscopeSamples, waveform.count)
        scratchMono.withUnsafeBufferPointer { src in
            waveform.withUnsafeMutableBufferPointer { dst in
                guard let s = src.baseAddress, let d = dst.baseAddress else { return }
                for i in 0..<actualSamples {
                    let idx = min(i * step, monoLen - 1)
                    d[i] = s[idx]
                }
            }
        }
        waveformCount = actualSamples

        copyFloatBuffer(from: scratch.butterchurnSpectrum, to: &bcSpectrum)
        copyFloatBuffer(from: scratch.butterchurnWaveform, to: &bcWaveform)

        generation &+= 1
        return true
    }

    /// Main thread: consume latest data (blocking lock, safe for main thread).
    func consume() -> VisualizerData? {
        os_unfair_lock_lock(&lock)

        guard generation != lastConsumed else {
            os_unfair_lock_unlock(&lock)
            return nil
        }
        lastConsumed = generation

        // Copy raw data under lock (memcpy only, no construction)
        let localRms = Array(rms.prefix(rmsCount))
        let localSpec = Array(spectrum.prefix(spectrumCount))
        let localWave = Array(waveform.prefix(waveformCount))
        let localBcSpec = Array(bcSpectrum)
        let localBcWave = Array(bcWaveform)

        os_unfair_lock_unlock(&lock)

        // Construct VisualizerData after releasing lock
        return VisualizerData(
            rms: localRms,
            spectrum: localSpec,
            waveform: localWave,
            butterchurnSpectrum: localBcSpec,
            butterchurnWaveform: localBcWave
        )
    }
}
