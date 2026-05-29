import AudioToolbox
import CoreAudioTypes
import Foundation

/// Video-tap parallel of the engine-side visualizer producer (ADR-6 dual-producer).
///
/// Consumes the tap's `AudioBufferList` (already EQ/balance-processed by `tapProcess`),
/// computes the same pre-computed visualizer arrays the engine `makeTapHandler`
/// produces — mono downmix → 20-bar RMS → 20-bar Goertzel spectrum → 2048-pt
/// Butterchurn FFT — into the per-tap `VisualizerScratchBuffers`, then publishes to
/// the shared `VisualizerFeed` (non-blocking; drops the frame on contention).
///
/// **Threading.** Runs entirely on the render thread inside `tapProcess`. The
/// `scratch` is render-confined (one per tap); the `feed` is the shared single-slot
/// SPSC hand-off whose `tryPublish` uses a `trylock`.
///
/// **Drift note (ADR-6).** The RMS-bar and Goertzel-spectrum math below MUST stay
/// numerically identical to `VisualizerPipeline.makeTapHandler`. ADR-6 keeps the two
/// producers parallel (different input buffer types) rather than extracting a shared
/// helper; the Butterchurn FFT is already shared via `processButterchurnFFT`. If you
/// change the RMS or Goertzel formula in one producer, change both.
func videoTapVisualizerRender(
    bufferList: UnsafeMutablePointer<AudioBufferList>,
    frames: Int,
    sampleRate: Double,
    scratch: VisualizerScratchBuffers,
    feed: VisualizerFeed
) {
    guard frames > 0, sampleRate > 0 else { return }
    let bars = 20
    let cappedFrameCount = scratch.prepare(frameCount: frames, bars: bars, sampleRate: Float(sampleRate))
    guard cappedFrameCount > 0 else { return }

    // Downmix every channel to mono. Handles non-interleaved (1 channel per buffer,
    // many buffers) and interleaved (N channels in one buffer). `prepare` already
    // zeroed `mono`, so accumulate then scale by the total channel count.
    scratch.withMono { mono in
        let abl = UnsafeMutableAudioBufferListPointer(bufferList)
        var totalChannels = 0
        for buffer in abl {
            guard let raw = buffer.mData else { continue }
            let chans = Int(buffer.mNumberChannels)
            guard chans > 0 else { continue }
            // Cap reads by the buffer's actual byte size, not just `frames`, to
            // never index past `mData` (matches the Phase 3 DSP path).
            let bufFrames = Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * chans)
            let n = min(cappedFrameCount, bufFrames)
            guard n > 0 else { continue }
            let samples = raw.assumingMemoryBound(to: Float.self)
            if chans == 1 {
                for f in 0..<n { mono[f] += samples[f] }
            } else {
                for f in 0..<n {
                    var sum: Float = 0
                    for c in 0..<chans { sum += samples[f * chans + c] }
                    mono[f] += sum
                }
            }
            totalChannels += chans
        }
        if totalChannels > 1 {
            let inv = 1.0 / Float(totalChannels)
            for f in 0..<cappedFrameCount { mono[f] *= inv }
        }
    }

    scratch.withMonoReadOnly { mono in
        // 20-bar RMS — MUST match VisualizerPipeline.makeTapHandler.
        scratch.withRms { rms in
            let bucketSize = max(1, cappedFrameCount / bars)
            var cursor = 0
            for b in 0..<bars {
                let start = cursor
                let end = min(cappedFrameCount, start + bucketSize)
                if end > start {
                    var sumSq: Float = 0
                    var index = start
                    while index < end {
                        let sample = mono[index]
                        sumSq += sample * sample
                        index += 1
                    }
                    var value = sqrt(sumSq / Float(end - start))
                    value = min(1.0, value * 4.0)
                    rms[b] = value
                } else {
                    rms[b] = 0
                }
                cursor = end
            }
        }

        // 20-bar Goertzel spectrum — MUST match VisualizerPipeline.makeTapHandler.
        scratch.withSpectrum { spectrum in
            let sampleCount = min(1024, cappedFrameCount)
            if sampleCount > 0 {
                let coefficients = scratch.goertzel.coefficients
                let gains = scratch.goertzel.equalizationGains
                for b in 0..<bars {
                    let coefficient = coefficients[b]
                    var s1: Float = 0
                    var s2: Float = 0
                    var index = 0
                    while index < sampleCount {
                        let sample = mono[index]
                        let s0 = sample + coefficient * s1 - s2
                        s2 = s1
                        s1 = s0
                        index += 1
                    }
                    let power = s1 * s1 + s2 * s2 - coefficient * s1 * s2
                    var value = sqrt(max(0, power)) / Float(sampleCount)
                    value *= gains[b]
                    value = min(1.0, value * 15.0)
                    spectrum[b] = value
                }
            } else {
                for b in 0..<bars { spectrum[b] = 0 }
            }
        }
    }

    // Butterchurn FFT (shared scratch method).
    scratch.withMonoReadOnly { mono in
        scratch.processButterchurnFFT(samples: mono, validCount: cappedFrameCount)
    }

    _ = feed.tryPublish(from: scratch, oscilloscopeSamples: 76, validFrameCount: cappedFrameCount)
}
