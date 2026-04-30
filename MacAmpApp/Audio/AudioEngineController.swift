import AVFoundation
import Atomics
import os

/// Snapshot of pre-reconfiguration engine + bridge state, captured by
/// `AudioEngineController.handleEngineWillReconfigure()` and forwarded to
/// AudioPlayer via `onEngineWillReconfigure`. AudioPlayer uses these fields to
/// decide whether to resume after the rewire and from which time position.
///
/// Captured at notification time, so `wasPlaying` may already reflect
/// post-reconfigure state (the engine auto-stops on output route change). The
/// bridge flags are MacAmp-owned and stay accurate; `currentTime` is best-effort
/// from `playerNode.lastRenderTime`.
struct PreReconfigureSnapshot: Sendable {
    let wasPlaying: Bool
    let currentTime: Double
    let wasStreamBridge: Bool
    let wasVideoBridge: Bool
}

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
    /// Bridge-scoped silence gate. Single writer (MainActor `setStreamSilenced`,
    /// releasing store), single reader (render block, acquiring load).
    private var streamSilenceGate: ManagedAtomic<UInt8>?
    private(set) var isBridgeActive: Bool = false

    // MARK: - Video Bridge State

    private var videoSourceNode: AVAudioSourceNode?
    private var videoRingBuffer: LockFreeRingBuffer?
    private(set) var isVideoBridgeActive: Bool = false

    // MARK: - Engine Configuration Observer

    private let configObserver: AudioEngineConfigurationObserver

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

    /// Called at the START of an output-route reconfigure burst, before any rewire.
    /// AudioPlayer arms `seekGuardActive` and bumps `currentSeekID` here so the
    /// stale playerNode completion (that the impending engine restart will fire)
    /// is filtered. Snapshot fields let AudioPlayer reconstruct resume state in
    /// the matching `onEngineDidReconfigure` callback.
    var onEngineWillReconfigure: ((PreReconfigureSnapshot) -> Void)?

    /// Called once after the route change has settled (150 ms quiet window).
    /// Engine has been restarted and bridge connections refreshed; AudioPlayer
    /// re-applies volume/balance, reschedules from the saved position, and
    /// PlaybackCoordinator refreshes the stream workgroup.
    var onEngineDidReconfigure: (() -> Void)?

    // MARK: - Init

    init(eqNode: AVAudioUnitEQ, visualizerPipeline: VisualizerPipeline) {
        self.eqNode = eqNode
        self.visualizerPipeline = visualizerPipeline
        self.configObserver = AudioEngineConfigurationObserver(engine: audioEngine)
        setupEngine()
        configObserver.onWillReconfigure = { [weak self] in
            self?.handleEngineWillReconfigure()
        }
        configObserver.onDidReconfigure = { [weak self] in
            self?.handleEngineDidReconfigure()
        }
        configObserver.start()
    }

    /// Tear down engine resources. Called from AudioPlayer's isolated deinit.
    func shutdown() {
        configObserver.stop()
        progressTimer?.invalidate()
        deactivateStreamBridge()
        deactivateVideoBridge()
        visualizerPipeline.removeTap()
    }

    /// Sample rate of the engine output node's input bus. Bridges target this
    /// so the source node format matches the graph's downstream consumer rate.
    var outputSampleRate: Double {
        audioEngine.outputNode.inputFormat(forBus: 0).sampleRate
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

        // Deactivate any active bridge before rewiring to playerNode path
        if isBridgeActive {
            deactivateStreamBridge()
        }
        if isVideoBridgeActive {
            deactivateVideoBridge()
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

    // MARK: - Audio Workgroup

    /// The audio IO workgroup from the output node. Only valid while engine is running.
    /// Used by StreamDecodePipeline to join its decode thread to the real-time workgroup.
    /// Requires ObjC shim because AUAudioUnit.osWorkgroup is Swift-unavailable.
    var audioWorkgroup: os_workgroup_t? {
        guard audioEngine.isRunning else { return nil }
        return AUAudioUnitGetWorkgroup(audioEngine.outputNode.auAudioUnit)
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
        // .common run-loop mode keeps this firing during user gestures (.eventTracking).
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
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
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
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
        videoSourceNode?.volume = volume
    }

    func setBalance(_ balance: Float) {
        playerNode.pan = balance
        streamSourceNode?.pan = balance
        videoSourceNode?.pan = balance
    }

    /// Silence the stream render block. No-op when bridge is inactive.
    /// Producer side must be quiesced and ring flushed BEFORE clearing.
    func setStreamSilenced(_ silenced: Bool) {
        streamSilenceGate?.store(silenced ? 1 : 0, ordering: .releasing)
    }

    #if DEBUG
    var isStreamSilenceGateActive: Bool {
        (streamSilenceGate?.load(ordering: .relaxed) ?? 0) != 0
    }
    #endif

    // MARK: - Stream Bridge

    /// Render block for AVAudioSourceNode. MUST be nonisolated static — runs on the RT thread.
    /// Reads interleaved Float32 from `ringBuffer`; zero-fills + sets `isSilence=true` while
    /// `silenceGate` is non-zero (closes the pause window where decoded PCM is still in the ring).
    private nonisolated static func makeStreamRenderBlock(
        ringBuffer: LockFreeRingBuffer,
        silenceGate: ManagedAtomic<UInt8>
    ) -> AVAudioSourceNodeRenderBlock {
        { isSilence, _, frameCount, outputData in
            let ablPointer = UnsafeMutableAudioBufferListPointer(outputData)
            guard ablPointer.count == 1,
                  let firstBuffer = ablPointer.first,
                  firstBuffer.mNumberChannels == 2,
                  let data = firstBuffer.mData else {
                isSilence.pointee = ObjCBool(true)
                return noErr
            }

            let floatPtr = data.assumingMemoryBound(to: Float.self)
            let channelCount = Int(firstBuffer.mNumberChannels)
            let frames = Int(frameCount)

            if silenceGate.load(ordering: .acquiring) != 0 {
                memset(floatPtr, 0, frames * channelCount * MemoryLayout<Float>.size)
                isSilence.pointee = ObjCBool(true)
                return noErr
            }

            let framesRead = ringBuffer.read(into: floatPtr, frameCount: frames)

            if framesRead < frames {
                let remainingSamples = (frames - framesRead) * channelCount
                let offset = framesRead * channelCount
                memset(floatPtr + offset, 0, remainingSamples * MemoryLayout<Float>.size)
            }

            isSilence.pointee = ObjCBool(framesRead == 0)
            return noErr
        }
    }

    #if DEBUG
    /// Test seam: same render block, exposed without widening production visibility.
    internal nonisolated static func makeStreamRenderBlockForTesting(
        ringBuffer: LockFreeRingBuffer,
        silenceGate: ManagedAtomic<UInt8>
    ) -> AVAudioSourceNodeRenderBlock {
        makeStreamRenderBlock(ringBuffer: ringBuffer, silenceGate: silenceGate)
    }
    #endif

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
        if isVideoBridgeActive {
            deactivateVideoBridge()
        }

        streamRingBuffer = ringBuffer

        // Allocate gate before the render block captures it; lifetime ends in deactivateStreamBridge.
        let gate = ManagedAtomic<UInt8>(0)
        streamSilenceGate = gate

        let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: true
        )!

        let renderBlock = Self.makeStreamRenderBlock(ringBuffer: ringBuffer, silenceGate: gate)
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
            streamSilenceGate = nil
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
        streamSilenceGate = nil
        isBridgeActive = false
        onBridgeStateChanged?(false)

        AppLog.info(.audio, "AudioEngineController: Stream bridge deactivated")
    }

    // MARK: - Video Bridge

    /// Render block for the video AVAudioSourceNode. Reads interleaved Float32
    /// stereo from `ringBuffer` written by `VideoAudioTap`. Mirrors the stream
    /// render block but without a silence gate — video pause is enforced at
    /// AVPlayer (which stops driving the tap), not at the render block.
    ///
    /// Per Principle 4 (AHA Rule of Three) we do NOT extract a shared helper
    /// at N=2 — keep both render blocks inline. Re-evaluate at N=3.
    private nonisolated static func makeVideoRenderBlock(
        ringBuffer: LockFreeRingBuffer
    ) -> AVAudioSourceNodeRenderBlock {
        { isSilence, _, frameCount, outputData in
            let ablPointer = UnsafeMutableAudioBufferListPointer(outputData)
            guard ablPointer.count == 1,
                  let firstBuffer = ablPointer.first,
                  firstBuffer.mNumberChannels == 2,
                  let data = firstBuffer.mData else {
                isSilence.pointee = ObjCBool(true)
                return noErr
            }

            let floatPtr = data.assumingMemoryBound(to: Float.self)
            let channelCount = Int(firstBuffer.mNumberChannels)
            let frames = Int(frameCount)

            let framesRead = ringBuffer.read(into: floatPtr, frameCount: frames)

            if framesRead < frames {
                let remainingSamples = (frames - framesRead) * channelCount
                let offset = framesRead * channelCount
                memset(floatPtr + offset, 0, remainingSamples * MemoryLayout<Float>.size)
            }

            isSilence.pointee = ObjCBool(framesRead == 0)
            return noErr
        }
    }

    #if DEBUG
    /// Test seam: same render block, exposed without widening production visibility.
    internal nonisolated static func makeVideoRenderBlockForTesting(
        ringBuffer: LockFreeRingBuffer
    ) -> AVAudioSourceNodeRenderBlock {
        makeVideoRenderBlock(ringBuffer: ringBuffer)
    }
    #endif

    /// Activate the video bridge: wire AVAudioSourceNode into the engine graph.
    /// Replaces the playerNode path with `videoSourceNode → EQ → mixer → output`.
    /// Mutually exclusive with the stream bridge — deactivates it first.
    ///
    /// Mirrors `activateStreamBridge` lessons: explicit interleaved source
    /// format matching the ring layout, non-interleaved graph format, stop +
    /// reset before rewire (avoids -10868), verify mixer→output post-reset.
    func activateVideoBridge(ringBuffer: LockFreeRingBuffer, sampleRate: Float64) {
        guard !isVideoBridgeActive else { return }
        if isBridgeActive {
            deactivateStreamBridge()
        }
        if playerNode.isPlaying {
            playerNode.stop()
        }

        videoRingBuffer = ringBuffer

        let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: true
        )!

        let renderBlock = Self.makeVideoRenderBlock(ringBuffer: ringBuffer)
        let sourceNode = AVAudioSourceNode(format: sourceFormat, renderBlock: renderBlock)
        videoSourceNode = sourceNode

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.reset()
        }

        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.disconnectNodeOutput(eqNode)
        audioEngine.attach(sourceNode)

        let graphFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: outputSampleRate,
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
            videoSourceNode = nil
            videoRingBuffer = nil
            AppLog.error(.audio, "AudioEngineController: Video bridge activation aborted — engine failed to start")
            return
        }
        installVisualizerTapIfNeeded()

        isVideoBridgeActive = true
        AppLog.info(.audio, "AudioEngineController: Video bridge activated — \(sampleRate)Hz")
    }

    /// Deactivate the video bridge — detach video source node, restore default
    /// playerNode wiring. Idempotent.
    func deactivateVideoBridge() {
        guard isVideoBridgeActive else { return }

        audioEngine.stop()
        removeVisualizerTapIfNeeded()

        if let sourceNode = videoSourceNode {
            audioEngine.detach(sourceNode)
        }

        audioEngine.disconnectNodeInput(eqNode, bus: 0)
        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.disconnectNodeOutput(eqNode)

        let graphFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: outputSampleRate,
            channels: 2,
            interleaved: false
        )!
        audioEngine.connect(playerNode, to: eqNode, format: graphFormat)
        audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: graphFormat)

        if audioEngine.outputConnectionPoints(for: audioEngine.mainMixerNode, outputBus: 0).isEmpty {
            audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)
        }

        audioEngine.prepare()

        videoSourceNode = nil
        videoRingBuffer = nil
        isVideoBridgeActive = false

        AppLog.info(.audio, "AudioEngineController: Video bridge deactivated")
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

    // MARK: - Engine Configuration Change Handlers

    /// Invoked at burst start by `configObserver.onWillReconfigure`. Captures a
    /// snapshot of pre-rewire state and forwards it to AudioPlayer so seek guards
    /// can be armed before the engine restart fires a stale playerNode completion.
    ///
    /// **Caller note:** the system posts AVAudioEngineConfigurationChange *after*
    /// auto-stopping the engine, so by the time this runs `playerNode.isPlaying`
    /// is false and `lastRenderTime` is nil. The `wasPlaying` / `currentTime`
    /// fields below are therefore best-effort placeholders — AudioPlayer
    /// overrides them with its own authoritative state in
    /// `handleEngineWillReconfigure`. The bridge flags are MacAmp-owned and
    /// remain accurate.
    private func handleEngineWillReconfigure() {
        let snapshot = PreReconfigureSnapshot(
            wasPlaying: playerNode.isPlaying,
            currentTime: readPlayerNodeCurrentTime() ?? 0,
            wasStreamBridge: isBridgeActive,
            wasVideoBridge: isVideoBridgeActive
        )
        onEngineWillReconfigure?(snapshot)
    }

    /// Invoked once at burst end by `configObserver.onDidReconfigure` (150 ms
    /// quiet window). The system has auto-reconfigured the output to the new
    /// route and stopped the engine; we refresh format-dependent connections,
    /// verify mixer→output, restart the engine, and notify AudioPlayer to
    /// re-apply transient state and resume playback.
    private func handleEngineDidReconfigure() {
        // 1. Refresh stream bridge graph format if active. The graph format
        //    captured at activate time references the old output sample rate;
        //    re-establishing with the current outputNode format avoids
        //    AVAudioEngine's silent format-conversion overhead.
        if isBridgeActive, let sourceNode = streamSourceNode {
            audioEngine.disconnectNodeOutput(sourceNode)
            audioEngine.disconnectNodeOutput(eqNode)
            let graphFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: audioEngine.outputNode.inputFormat(forBus: 0).sampleRate,
                channels: 2,
                interleaved: false
            )!
            audioEngine.connect(sourceNode, to: eqNode, format: graphFormat)
            audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: graphFormat)
        }

        // 2. Refresh video bridge graph format if active. AVAudioEngine inserts
        //    an internal converter between the source node's declared rate (the
        //    tap's expectedSampleRate, fixed at attach time) and the new
        //    outputNode rate, so the source node itself stays as-is.
        if isVideoBridgeActive, let sourceNode = videoSourceNode {
            audioEngine.disconnectNodeOutput(sourceNode)
            audioEngine.disconnectNodeOutput(eqNode)
            let graphFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: outputSampleRate,
                channels: 2,
                interleaved: false
            )!
            audioEngine.connect(sourceNode, to: eqNode, format: graphFormat)
            audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: graphFormat)
        }

        // 3. Verify mixer → output connection survived the reconfigure.
        if audioEngine.outputConnectionPoints(for: audioEngine.mainMixerNode, outputBus: 0).isEmpty {
            audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)
        }

        // 4. Restart engine (system stopped it during reconfigure).
        audioEngine.prepare()
        _ = startEngineIfNeeded()

        // 5. Notify AudioPlayer to re-apply volume/balance and resume.
        onEngineDidReconfigure?()
    }

    /// Best-effort snapshot of player-node playback time, mirroring the
    /// computation in `startProgressTimer`. Returns nil during the brief
    /// post-restart window where `lastRenderTime` is not yet populated.
    private func readPlayerNodeCurrentTime() -> Double? {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return nil
        }
        return Double(playerTime.sampleTime) / playerTime.sampleRate + playheadOffset
    }

    // MARK: - Engine State

    /// Whether the audio engine is currently running.
    var isEngineRunning: Bool { audioEngine.isRunning }
}
