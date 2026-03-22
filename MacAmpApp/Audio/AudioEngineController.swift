import AVFoundation

/// Owns the AVAudioEngine graph and all node-level operations.
///
/// Responsibilities:
/// - Engine setup, graph wiring (local file + stream bridge paths)
/// - Audio scheduling (scheduleFrom)
/// - Stream bridge lifecycle (activate/deactivate with format invariants)
/// - Visualizer tap install/remove
/// - Node-level transport (play/pause/stop on playerNode)
/// - Progress timer
///
/// AudioPlayer retains ownership of:
/// - Playback state machine (seek guards, completion filtering)
/// - Track management and playlist navigation
/// - Video playback routing
/// - All public API forwarding (facade pattern)
@MainActor
final class AudioEngineController {

    // MARK: - Engine Internals

    let audioEngine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    private(set) var audioFile: AVAudioFile?
    private var progressTimer: Timer?
    private var playheadOffset: Double = 0

    // MARK: - Stream Bridge State

    private var streamSourceNode: AVAudioSourceNode?
    private var streamRingBuffer: LockFreeRingBuffer?
    private(set) var isBridgeActive: Bool = false

    // MARK: - Injected Dependencies

    private let eqNode: AVAudioUnitEQ
    private let visualizerPipeline: VisualizerPipeline

    // MARK: - Callbacks to AudioPlayer

    /// Called on every progress timer tick with (currentTime, progress).
    var onProgressUpdate: ((_ currentTime: Double, _ progress: Double) -> Void)?

    /// Called when a scheduled audio segment completes. The UUID identifies the seek operation
    /// that scheduled the segment, allowing AudioPlayer to filter stale completions.
    var onPlaybackEnded: ((_ fromSeekID: UUID?) -> Void)?

    /// Called when isBridgeActive changes so AudioPlayer can update its observable property.
    var onBridgeStateChanged: ((_ isActive: Bool) -> Void)?

    // MARK: - Init

    init(eqNode: AVAudioUnitEQ, visualizerPipeline: VisualizerPipeline) {
        self.eqNode = eqNode
        self.visualizerPipeline = visualizerPipeline
        setupEngine()
    }

    /// Tear down engine resources. Called from AudioPlayer's isolated deinit.
    func shutdown() {
        progressTimer?.invalidate()
        deactivateStreamBridge()
        visualizerPipeline.removeTap()
    }

    // MARK: - Engine Setup

    private func setupEngine() {
        audioEngine.attach(playerNode)
        audioEngine.attach(eqNode)
    }

    // MARK: - Graph Wiring (Local File Path)

    /// Rewire the engine graph for local file playback.
    /// Deactivates stream bridge if active, reconnects playerNode → EQ → mixer → output.
    ///
    /// **Critical:** Uses EXPLICIT format (never nil) to avoid -10868 format stickiness
    /// after stream bridge disconnection.
    func rewireForFile(_ file: AVAudioFile) {
        audioFile = file

        // Deactivate stream bridge if active
        if isBridgeActive {
            deactivateStreamBridge()
        }

        // Stop engine if running (between tracks)
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        // Clear all existing connections
        audioEngine.disconnectNodeInput(eqNode, bus: 0)
        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.disconnectNodeOutput(eqNode)

        // Reconnect with EXPLICIT format — never use nil after stream bridge
        let outputSampleRate = audioEngine.outputNode.inputFormat(forBus: 0).sampleRate
        let fileChannels = file.processingFormat.channelCount
        let graphFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: outputSampleRate,
            channels: fileChannels,
            interleaved: false
        )!
        audioEngine.connect(playerNode, to: eqNode, format: graphFormat)
        audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: graphFormat)

        // Verify mixer→output
        if audioEngine.outputConnectionPoints(for: audioEngine.mainMixerNode, outputBus: 0).isEmpty {
            audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)
        }

        audioEngine.prepare()
        startEngineIfNeeded()
        installVisualizerTapIfNeeded()
    }

    // MARK: - Audio Scheduling

    /// Schedules audio playback from a specific time.
    /// - Returns: `true` if audio was scheduled, `false` if track ended.
    func scheduleFrom(time: Double, seekID: UUID?) -> Bool {
        guard let file = audioFile else {
            AppLog.warn(.audio, "scheduleFrom: No audio file loaded")
            return false
        }

        let sampleRate = file.processingFormat.sampleRate
        let fileDuration = Double(file.length) / sampleRate

        // If seeking to or past the end, trigger completion immediately
        if time >= fileDuration - 0.01 {
            playheadOffset = fileDuration
            playerNode.stop()
            return false
        }

        let startFrame = AVAudioFramePosition(max(0, min(time, fileDuration)) * sampleRate)
        let totalFrames = file.length
        let framesRemaining = max(0, totalFrames - startFrame)

        playheadOffset = Double(startFrame) / sampleRate
        playerNode.stop()

        if framesRemaining > 0 {
            let completionID = seekID
            playerNode.scheduleSegment(
                file,
                startingFrame: startFrame,
                frameCount: AVAudioFrameCount(framesRemaining),
                at: nil,
                completionHandler: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.onPlaybackEnded?(completionID)
                    }
                }
            )

            if fileDuration.isFinite && fileDuration > 0 {
                Task { @MainActor in
                    // Caller can read currentDuration from audioFile directly
                }
            }

            return true
        } else {
            onPlaybackEnded?(nil)
            return false
        }
    }

    /// The duration of the currently loaded audio file in seconds.
    var currentFileDuration: Double {
        guard let file = audioFile else { return 0 }
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return 0 }
        return Double(file.length) / sampleRate
    }

    // MARK: - Engine Lifecycle

    /// Start the audio engine if not running. Returns true if engine is running after call.
    @discardableResult
    func startEngineIfNeeded() -> Bool {
        if !audioEngine.isRunning {
            audioEngine.prepare()
            do {
                try audioEngine.start()
            } catch {
                AppLog.error(.audio, "AudioEngine start error: \(error)")
                return false
            }
        }
        return audioEngine.isRunning
    }

    // MARK: - Progress Timer

    func startProgressTimer() {
        progressTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            dispatchPrecondition(condition: .onQueue(.main))
            MainActor.assumeIsolated {
                guard let self = self else { return }
                if let nodeTime = self.playerNode.lastRenderTime,
                   let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) {
                    let current = Double(playerTime.sampleTime) / playerTime.sampleRate + self.playheadOffset
                    let duration = self.currentFileDuration
                    let progress = duration > 0 ? current / duration : 0
                    self.onProgressUpdate?(current, progress)
                }
            }
        }
        progressTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func invalidateProgressTimer() {
        progressTimer?.invalidate()
    }

    // MARK: - Visualizer Tap

    func installVisualizerTapIfNeeded() {
        guard !visualizerPipeline.isTapInstalled else { return }
        visualizerPipeline.installTap(on: audioEngine.mainMixerNode)
    }

    func removeVisualizerTapIfNeeded() {
        visualizerPipeline.removeTap()
        visualizerPipeline.clearData()
    }

    // MARK: - Audio Transport (node-level)

    var isPlayerNodePlaying: Bool { playerNode.isPlaying }

    func playAudio() {
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    func pauseAudio() {
        playerNode.pause()
    }

    func stopAudio() {
        playerNode.stop()
    }

    // MARK: - Volume / Balance

    func setVolume(_ volume: Float) {
        playerNode.volume = volume
        streamSourceNode?.volume = volume
    }

    func setBalance(_ balance: Float) {
        playerNode.pan = balance
        streamSourceNode?.pan = balance
    }

    // MARK: - Stream Bridge

    /// Build the render block for AVAudioSourceNode. MUST be nonisolated static
    /// to avoid @MainActor isolation crash on the real-time audio thread.
    /// Reads interleaved Float32 PCM from the ring buffer.
    private nonisolated static func makeStreamRenderBlock(
        ringBuffer: LockFreeRingBuffer
    ) -> AVAudioSourceNodeRenderBlock {
        { isSilence, timestamp, frameCount, outputData in
            let ablPointer = UnsafeMutableAudioBufferListPointer(outputData)
            guard ablPointer.count == 1,
                  let firstBuffer = ablPointer.first,
                  firstBuffer.mNumberChannels == 2,
                  let data = firstBuffer.mData else {
                isSilence.pointee = ObjCBool(true)
                return noErr
            }

            let floatPtr = data.assumingMemoryBound(to: Float.self)
            let framesRead = ringBuffer.read(into: floatPtr, frameCount: Int(frameCount))

            if framesRead < Int(frameCount) {
                let channelCount = Int(firstBuffer.mNumberChannels)
                let remainingSamples = (Int(frameCount) - framesRead) * channelCount
                let offset = framesRead * channelCount
                memset(floatPtr + offset, 0, remainingSamples * MemoryLayout<Float>.size)
            }

            isSilence.pointee = ObjCBool(framesRead == 0)
            return noErr
        }
    }

    /// Activate the stream bridge: wire AVAudioSourceNode into the engine graph.
    /// Replaces the playerNode path with streamSourceNode → EQ → mixer → output.
    ///
    /// **Critical lessons (from T5 Phase 2):**
    /// - Source node format MUST be interleaved (matches ring buffer layout)
    /// - Graph connection format MUST be non-interleaved (engine internal)
    /// - MUST stop/reset engine before rewiring (lesson #3, avoids -10868)
    /// - MUST verify mixer→output after reset (lesson #4)
    func activateStreamBridge(ringBuffer: LockFreeRingBuffer, sampleRate: Float64) {
        guard !isBridgeActive else { return }

        streamRingBuffer = ringBuffer

        let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: true
        )!

        let renderBlock = Self.makeStreamRenderBlock(ringBuffer: ringBuffer)
        let sourceNode = AVAudioSourceNode(format: sourceFormat, renderBlock: renderBlock)
        streamSourceNode = sourceNode

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.reset()
        }

        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.disconnectNodeOutput(eqNode)
        audioEngine.attach(sourceNode)

        let graphFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: audioEngine.outputNode.inputFormat(forBus: 0).sampleRate,
            channels: 2,
            interleaved: false
        )

        audioEngine.connect(sourceNode, to: eqNode, format: graphFormat)
        audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: graphFormat)

        if audioEngine.outputConnectionPoints(for: audioEngine.mainMixerNode, outputBus: 0).isEmpty {
            audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)
        }

        audioEngine.prepare()
        guard startEngineIfNeeded() else {
            audioEngine.disconnectNodeOutput(sourceNode)
            audioEngine.detach(sourceNode)
            streamSourceNode = nil
            streamRingBuffer = nil
            AppLog.error(.audio, "AudioEngineController: Stream bridge activation aborted — engine failed to start")
            return
        }
        installVisualizerTapIfNeeded()

        isBridgeActive = true
        onBridgeStateChanged?(true)
        AppLog.info(.audio, "AudioEngineController: Stream bridge activated — \(sampleRate)Hz")
    }

    /// Deactivate the stream bridge — detach stream node, reset engine.
    /// Idempotent — safe to call when bridge is not active.
    func deactivateStreamBridge() {
        guard isBridgeActive else { return }

        audioEngine.stop()
        removeVisualizerTapIfNeeded()

        if let sourceNode = streamSourceNode {
            audioEngine.detach(sourceNode)
        }

        audioEngine.disconnectNodeInput(eqNode, bus: 0)
        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.disconnectNodeOutput(eqNode)

        let graphFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: audioEngine.outputNode.inputFormat(forBus: 0).sampleRate,
            channels: 2,
            interleaved: false
        )!
        audioEngine.connect(playerNode, to: eqNode, format: graphFormat)
        audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: graphFormat)

        if audioEngine.outputConnectionPoints(for: audioEngine.mainMixerNode, outputBus: 0).isEmpty {
            audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)
        }

        audioEngine.prepare()

        streamSourceNode = nil
        streamRingBuffer = nil
        isBridgeActive = false
        onBridgeStateChanged?(false)

        AppLog.info(.audio, "AudioEngineController: Stream bridge deactivated")
    }

    // MARK: - File Loading

    /// Load an audio file for playback. Rewires the engine graph.
    func loadFile(url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        rewireForFile(file)
    }

    /// Clear the loaded audio file (used by eject).
    func clearFile() {
        audioFile = nil
    }

    // MARK: - Engine State

    /// Whether the audio engine is currently running.
    var isEngineRunning: Bool { audioEngine.isRunning }
}
