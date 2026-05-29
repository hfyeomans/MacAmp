import AVFoundation
import Accelerate
import Observation
import os

// MARK: - Butterchurn Audio Frame

/// Snapshot of audio data for Butterchurn visualization
/// Produced by VisualizerPipeline tap, consumed by ButterchurnBridge at 30 FPS
/// Sendable for safe cross-actor transfer in Swift 6
struct ButterchurnFrame: Sendable {
    let spectrum: [Float]       // 1024 frequency bins (from 2048-point FFT)
    let waveform: [Float]       // 1024 mono samples (time-domain)
    let timestamp: TimeInterval // CACurrentMediaTime() when captured
}

// MARK: - Visualizer Data

/// Container for all visualizer datasets produced by the audio tap
/// Sendable for safe cross-actor transfer in Swift 6
struct VisualizerData: Sendable {
    let rms: [Float]
    let spectrum: [Float]
    let waveform: [Float]
    let butterchurnSpectrum: [Float]
    let butterchurnWaveform: [Float]
}

// MARK: - VisualizerPipeline

/// Manages audio visualization tap and data processing.
/// Extracted from AudioPlayer for single responsibility and cleaner separation.
///
/// **Layer:** Mechanism (audio processing)
/// **Responsibilities:**
/// - Owns tap lifecycle and scratch buffer management
/// - Provides callbacks for visualizer data updates
/// - Handles all FFT/spectrum processing on audio thread
/// - Manages Butterchurn frame generation at 30 FPS
@MainActor
@Observable
final class VisualizerPipeline {
    // MARK: - Tap State

    @ObservationIgnored private var tapInstalled = false
    @ObservationIgnored private weak var mixerNode: AVAudioMixerNode?
    @ObservationIgnored private let feed = VisualizerFeed()
    @ObservationIgnored private var pollTimer: Timer?

    /// Optional main-thread hook invoked on every 30 Hz poll tick (engine or video).
    /// `AudioPlayer` uses it to poll each registered video-tap Context's sample rate
    /// for the EQ fanout (S3-2 Phase 5) — keeps `VisualizerPipeline` decoupled from
    /// `EqualizerController`. Fires regardless of whether new visualizer data arrived.
    @ObservationIgnored var onPollTick: (@MainActor () -> Void)?

    /// The shared visualizer feed. Exposed so the S3-2 video-tap producer
    /// (`videoTapVisualizerRender`) can publish to the SAME single-slot feed the
    /// engine producer uses — only one producer is active at a time (engine for
    /// audio, video tap for video), so the single-slot last-write-wins hand-off is
    /// correct without coordination.
    var sharedFeed: VisualizerFeed { feed }

    // MARK: - Visualizer Data Storage

    @ObservationIgnored private var peaks: [Float] = Array(repeating: 0.0, count: 20)
    @ObservationIgnored private var lastUpdateTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    @ObservationIgnored private var latestRMS: [Float] = []
    @ObservationIgnored private var latestSpectrum: [Float] = []
    @ObservationIgnored private var latestWaveform: [Float] = []

    // Butterchurn audio data - populated by tap, consumed at 30 FPS
    @ObservationIgnored private var butterchurnSpectrum: [Float] = Array(repeating: 0, count: 1024)
    @ObservationIgnored private var butterchurnWaveform: [Float] = Array(repeating: 0, count: 1024)
    @ObservationIgnored private var lastButterchurnUpdate: TimeInterval = 0

    // MARK: - Configuration

    /// Smoothing factor for visualizer levels (0..1, higher = smoother)
    var smoothing: Float = 0.6

    /// Peak falloff rate (units per second)
    var peakFalloff: Float = 1.2

    /// Cached spectrum/RMS mode to avoid per-frame AppSettings lookup
    /// AudioPlayer sets this when visualizerMode changes in AppSettings
    var useSpectrum: Bool = true

    // MARK: - Observable State (for UI)

    /// Current smoothed visualizer levels (20 bars)
    private(set) var levels: [Float] = []

    // MARK: - Initialization

    init() {}

    isolated deinit {
        // Belt-and-suspenders: today the lifecycle is owned by AudioEngineController,
        // which calls removeTap() (and thereby stopPollTimer()) on shutdown. This
        // guards future lifecycle refactors that might drop the last reference
        // without going through removeTap().
        pollTimer?.invalidate()
    }

    // MARK: - Tap Management

    /// Install visualizer tap on the given mixer node
    /// - Parameter mixer: The AVAudioMixerNode to tap
    func installTap(on mixer: AVAudioMixerNode) {
        guard !tapInstalled else { return }

        // Store weak reference for removal
        mixerNode = mixer

        // Remove any existing tap first
        mixer.removeTap(onBus: 0)

        let scratch = VisualizerScratchBuffers()
        let handler = Self.makeTapHandler(feed: feed, scratch: scratch)

        // Buffer size 2048 for Butterchurn FFT - provides 1024 frequency bins
        mixer.installTap(onBus: 0, bufferSize: 2048, format: nil, block: handler)
        tapInstalled = true
        startPollTimer()

        AppLog.debug(.audio, "VisualizerPipeline: Tap installed")
    }

    /// Remove visualizer tap if installed
    func removeTap() {
        guard tapInstalled else { return }
        pollTimer?.invalidate()
        pollTimer = nil
        if let mixer = mixerNode {
            mixer.removeTap(onBus: 0)
        }
        tapInstalled = false
        mixerNode = nil

        AppLog.debug(.audio, "VisualizerPipeline: Tap removed")
    }

    /// Clear cached visualizer data so UI shows empty bars instead of stale data.
    /// Call after removeTap() when transitioning away from audio playback.
    func clearData() {
        levels = []
        latestRMS = []
        latestSpectrum = []
        latestWaveform = []
        butterchurnSpectrum = Array(repeating: 0, count: 1024)
        butterchurnWaveform = Array(repeating: 0, count: 1024)
    }

    /// Check if tap is currently installed
    var isTapInstalled: Bool {
        tapInstalled
    }

    // MARK: - Video Visualization (S3-2 — video-tap producer)

    /// Start consuming the shared feed for VIDEO playback. During video the engine
    /// mixer tap is NOT installed (audio flows through AVPlayer, not the engine), so
    /// the 30 Hz poll timer that drives `feed.consume()` must be started independently.
    /// The producer is `videoTapVisualizerRender` (the `MTAudioProcessingTap` render
    /// path), which publishes to the same shared `feed`.
    /// Whether the 30 Hz feed poll timer is currently scheduled (engine OR video).
    var isPollTimerActive: Bool { pollTimer != nil }

    func startVideoVisualization() {
        startPollTimer()
        AppLog.debug(.audio, "VisualizerPipeline: video visualization started")
    }

    /// Stop video-driven consumption and clear stale bars. Call on video→audio
    /// switch or when video playback stops.
    func stopVideoVisualization() {
        pollTimer?.invalidate()
        pollTimer = nil
        clearData()
        AppLog.debug(.audio, "VisualizerPipeline: video visualization stopped")
    }

    // MARK: - Poll Timer

    private func startPollTimer() {
        pollTimer?.invalidate()
        // Add to .common run-loop mode so polling continues during user
        // gestures. Timer.scheduledTimer defaults to .default mode, which
        // pauses while the main run loop is in .eventTracking (active
        // DragGesture). That stalled the data pipeline and made the
        // visualizer appear frozen during slider interaction even though
        // VisualizerView's own .common-mode display timer kept firing.
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            dispatchPrecondition(condition: .onQueue(.main))
            MainActor.assumeIsolated {
                self?.pollVisualizerData()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func pollVisualizerData() {
        onPollTick?()  // fire regardless of data availability (sample-rate poll)
        guard let data = feed.consume() else { return }
        updateLevels(with: data, useSpectrum: useSpectrum)
    }

    // MARK: - Butterchurn Data Access

    /// Thread-safe snapshot of current Butterchurn audio data
    /// Called by ButterchurnBridge at 30 FPS to push data to JavaScript
    func snapshotButterchurnFrame() -> ButterchurnFrame {
        ButterchurnFrame(
            spectrum: butterchurnSpectrum,
            waveform: butterchurnWaveform,
            timestamp: lastButterchurnUpdate
        )
    }

    /// Nearest-neighbor resample: map `source` into an array of `targetCount` elements.
    private func resample(_ source: [Float], to targetCount: Int) -> [Float] {
        guard targetCount > 0 else { return [] }
        if source.count == targetCount { return source }
        guard !source.isEmpty else { return [Float](repeating: 0, count: targetCount) }
        var result = [Float](repeating: 0, count: targetCount)
        for i in 0..<targetCount {
            let sourceIndex = (i * source.count) / targetCount
            result[i] = source[min(sourceIndex, source.count - 1)]
        }
        return result
    }

    /// Get RMS data mapped to requested number of bands
    func getRMSData(bands: Int) -> [Float] {
        resample(latestRMS, to: bands)
    }

    /// Get waveform samples resampled to requested count
    func getWaveformSamples(count: Int) -> [Float] {
        resample(latestWaveform, to: count)
    }

    /// Get frequency data mapped to requested number of bands with logarithmic scaling
    /// - Parameters:
    ///   - bands: Number of output bands
    ///   - isPlaying: Whether audio is currently playing (controls output behavior)
    /// - Returns: Array of normalized frequency values (0.0-1.0)
    func getFrequencyData(bands: Int, isPlaying: Bool) -> [Float] {
        guard bands > 0 else { return [] }

        var result = [Float](repeating: 0, count: bands)

        if isPlaying && !levels.isEmpty {
            let sourceCount = levels.count

            for i in 0..<bands {
                let sourceIndex = (i * sourceCount) / bands
                let nextIndex = min(sourceIndex + 1, sourceCount - 1)

                let fraction = Float(i * sourceCount % bands) / Float(bands)
                let value1 = levels[sourceIndex]
                let value2 = levels[nextIndex]

                let interpolated = value1 * (1 - fraction) + value2 * fraction
                let scaled = log10(1.0 + interpolated * 9.0)

                result[i] = min(1.0, max(0.0, scaled * 0.8))
            }
        } else if isPlaying {
            for i in 0..<bands {
                result[i] = Float.random(in: 0.0...0.1)
            }
        }

        return result
    }

    // MARK: - Data Update (called from poll timer)

    /// Update visualizer levels with new data from shared buffer
    /// Called on MainActor from 30 Hz poll timer
    func updateLevels(with data: VisualizerData, useSpectrum: Bool) {
        // Store all visualizer datasets
        latestRMS = data.rms
        latestSpectrum = data.spectrum
        latestWaveform = data.waveform

        // Store Butterchurn data
        butterchurnSpectrum = data.butterchurnSpectrum
        butterchurnWaveform = data.butterchurnWaveform
        lastButterchurnUpdate = CACurrentMediaTime()

        // Apply smoothing to active mode
        let used = useSpectrum ? data.spectrum : data.rms
        let now = CFAbsoluteTimeGetCurrent()
        let dt = max(0, Float(now - lastUpdateTime))
        lastUpdateTime = now

        let alpha = max(0, min(1, smoothing))
        var smoothed = [Float](repeating: 0, count: used.count)

        for b in 0..<used.count {
            let prev = (b < levels.count) ? levels[b] : 0
            smoothed[b] = alpha * prev + (1 - alpha) * used[b]
            let fall = peakFalloff * dt
            let dropped = max(0, peaks[b] - fall)
            peaks[b] = max(dropped, smoothed[b])
        }

        levels = smoothed
    }

    // MARK: - Tap Handler (nonisolated)

    // swiftlint:disable function_body_length
    /// Build the tap handler in a nonisolated context so AVAudioEngine can call it on its realtime queue.
    /// Uses SPSC shared buffer instead of Task { @MainActor } to avoid allocations on the audio thread.
    private nonisolated static func makeTapHandler(
        feed: VisualizerFeed,
        scratch: VisualizerScratchBuffers
    ) -> @Sendable (AVAudioPCMBuffer, AVAudioTime?) -> Void {
        // swiftlint:disable:next closure_body_length
        { buffer, _ in
            let channelCount = Int(buffer.format.channelCount)
            guard channelCount > 0, let ptr = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            if frameCount == 0 { return }

            let bars = 20
            let cappedFrameCount = scratch.prepare(frameCount: frameCount, bars: bars, sampleRate: Float(buffer.format.sampleRate))

            // Mix channels to mono
            scratch.withMono { mono in
                let invCount = 1.0 / Float(channelCount)
                for frame in 0..<cappedFrameCount {
                    var sum: Float = 0
                    for channel in 0..<channelCount {
                        sum += ptr[channel][frame]
                    }
                    mono[frame] = sum * invCount
                }
            }

            // Compute RMS per bar
            scratch.withMonoReadOnly { mono in // swiftlint:disable:this closure_body_length
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

                // Compute spectrum using Goertzel algorithm with precomputed coefficients
                scratch.withSpectrum { spectrum in
                    let sampleCount = min(1024, cappedFrameCount)
                    if sampleCount > 0 {
                        let coefficients = scratch.goertzel.coefficients
                        let gains = scratch.goertzel.equalizationGains

                        for b in 0..<bars {
                            let coefficient = coefficients[b]
                            var s0: Float = 0
                            var s1: Float = 0
                            var s2: Float = 0
                            var index = 0
                            while index < sampleCount {
                                let sample = mono[index]
                                s0 = sample + coefficient * s1 - s2
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
                        for b in 0..<bars {
                            spectrum[b] = 0
                        }
                    }
                }
            }

            // Process Butterchurn FFT (2048-point for 1024 bins)
            scratch.withMonoReadOnly { mono in
                scratch.processButterchurnFFT(samples: mono, validCount: cappedFrameCount)
            }

            // Publish to feed (non-blocking: drops frame on contention)
            _ = feed.tryPublish(from: scratch, oscilloscopeSamples: 76, validFrameCount: cappedFrameCount)
        }
    }
    // swiftlint:enable function_body_length
}
