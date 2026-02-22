@preconcurrency import AVFoundation
import CoreMedia
import MediaToolbox
import Observation
import Combine

// MARK: - Loopback Tap Context (2.2g — @unchecked Sendable + nonisolated(unsafe))

/// Context shared between MTAudioProcessingTap callbacks.
/// Passed as `clientInfo` during tap creation, retrieved via `MTAudioProcessingTapGetStorage`.
/// @unchecked Sendable: accessed from CoreMedia callback threads with nonisolated(unsafe) mutable state.
private final class LoopbackTapContext: @unchecked Sendable {
    let ringBuffer: LockFreeRingBuffer
    let onFormatReady: @Sendable (Float64) -> Void

    // Written in tapPrepare (setup thread), read in tapProcess (RT thread)
    nonisolated(unsafe) var sampleRate: Float64 = 0
    nonisolated(unsafe) var channelCount: UInt32 = 0
    nonisolated(unsafe) var isNonInterleaved: Bool = false

    // Pre-allocated in tapPrepare for mono→stereo or non-interleaved→interleaved conversion.
    // Used in tapProcess (RT thread) — zero allocation on hot path (2.2h).
    nonisolated(unsafe) var scratchBuffer: UnsafeMutablePointer<Float>?
    nonisolated(unsafe) var scratchFrameCapacity: Int = 0

    init(ringBuffer: LockFreeRingBuffer, onFormatReady: @escaping @Sendable (Float64) -> Void) {
        self.ringBuffer = ringBuffer
        self.onFormatReady = onFormatReady
    }

    deinit {
        scratchBuffer?.deallocate()
    }
}

// MARK: - Loopback Tap Callbacks (2.2a — Top-level @convention(c), NOT closures inside @MainActor)

// These are top-level functions to avoid Swift 6.2 @MainActor isolation inheritance.
// Lessons learned #1: Closures inside @MainActor methods crash on audio threads (EXC_BREAKPOINT).

private func loopbackTapInit(
    tap: MTAudioProcessingTap,
    clientInfo: UnsafeMutableRawPointer?,
    tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
    // Store context pointer for subsequent callbacks
    tapStorageOut.pointee = clientInfo
}

private func loopbackTapFinalize(tap: MTAudioProcessingTap) {
    // Release the retained context (balances Unmanaged.passRetained in attachLoopbackTap)
    let storage = MTAudioProcessingTapGetStorage(tap)
    Unmanaged<LoopbackTapContext>.fromOpaque(storage).release()
}

// 2.2c + 2.7a: Capture format, configure ring buffer, increment generation ID
private func loopbackTapPrepare(
    tap: MTAudioProcessingTap,
    maxFrames: CMItemCount,
    processingFormat: UnsafePointer<AudioStreamBasicDescription>
) {
    let storage = MTAudioProcessingTapGetStorage(tap)
    let context = Unmanaged<LoopbackTapContext>.fromOpaque(storage).takeUnretainedValue()

    let format = processingFormat.pointee
    context.sampleRate = format.mSampleRate
    context.channelCount = format.mChannelsPerFrame
    context.isNonInterleaved = (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0

    // 2.7b: Pre-allocate scratch buffer for worst-case (stereo interleaved output)
    let scratchSamples = Int(maxFrames) * 2  // Always stereo output
    context.scratchBuffer?.deallocate()
    context.scratchBuffer = .allocate(capacity: scratchSamples)
    context.scratchBuffer?.initialize(repeating: 0, count: scratchSamples)
    context.scratchFrameCapacity = Int(maxFrames)

    // Flush ring buffer with new generation (producer quiesced during prepare)
    // 2.7a: Reinitialize ring buffer on format change with generation ID increment
    context.ringBuffer.flush(newGeneration: true)

    // Notify AudioPlayer of stream format (safe here — tapPrepare is NOT real-time)
    // Always report 2 channels — ring buffer is always stereo
    context.onFormatReady(format.mSampleRate)
}

// 2.2d: Flush ring buffer, signal reader
private func loopbackTapUnprepare(tap: MTAudioProcessingTap) {
    let storage = MTAudioProcessingTapGetStorage(tap)
    let context = Unmanaged<LoopbackTapContext>.fromOpaque(storage).takeUnretainedValue()

    // Flush ring buffer (producer quiesced during unprepare)
    context.ringBuffer.flush(newGeneration: true)
}

// 2.2b + 2.2h: Copy PCM to ring buffer, zero output, real-time safe
private func loopbackTapProcess(
    tap: MTAudioProcessingTap,
    numberFrames: CMItemCount,
    flags: MTAudioProcessingTapFlags,
    bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
    numberFramesOut: UnsafeMutablePointer<CMItemCount>,
    flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    // 2.2h: Real-time safety — zero allocations, zero locks, zero ARC, zero logging

    // Get source audio from upstream
    let status = MTAudioProcessingTapGetSourceAudio(
        tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut
    )
    guard status == noErr else { return }

    let frameCount = Int(numberFramesOut.pointee)
    guard frameCount > 0 else { return }

    let storage = MTAudioProcessingTapGetStorage(tap)
    let context = Unmanaged<LoopbackTapContext>.fromOpaque(storage).takeUnretainedValue()
    let ablPtr = UnsafeMutableAudioBufferListPointer(bufferListInOut)

    let channels = context.channelCount

    // Write to ring buffer — always as interleaved stereo
    if channels >= 2 && !context.isNonInterleaved && ablPtr.count == 1 {
        // Fast path: already interleaved stereo — write directly
        if let data = ablPtr[0].mData?.assumingMemoryBound(to: Float.self) {
            _ = context.ringBuffer.write(from: data, frameCount: frameCount)
        }
    } else if let scratch = context.scratchBuffer, frameCount <= context.scratchFrameCapacity {
        // Conversion path: mono→stereo upmixing or non-interleaved→interleaved
        if channels == 1 {
            // Mono → stereo upmixing (defensive — mono streams exist)
            // For mono, interleaved/non-interleaved is identical (single buffer)
            if ablPtr.count >= 1, let mono = ablPtr[0].mData?.assumingMemoryBound(to: Float.self) {
                for i in 0..<frameCount {
                    scratch[i * 2] = mono[i]
                    scratch[i * 2 + 1] = mono[i]
                }
                _ = context.ringBuffer.write(from: scratch, frameCount: frameCount)
            }
        } else if context.isNonInterleaved && ablPtr.count >= 2 {
            // Non-interleaved stereo → interleaved
            let left = ablPtr[0].mData?.assumingMemoryBound(to: Float.self)
            let right = ablPtr[1].mData?.assumingMemoryBound(to: Float.self)
            if let left {
                for i in 0..<frameCount {
                    scratch[i * 2] = left[i]
                    scratch[i * 2 + 1] = right?[i] ?? left[i]
                }
                _ = context.ringBuffer.write(from: scratch, frameCount: frameCount)
            }
        }
    }

    // 2.2b: Zero output buffer to prevent double-render (silence AVPlayer direct output)
    // Per Apple QA1783, PreEffects tap runs before mix effects — zeroing is deterministic
    for i in 0..<ablPtr.count {
        if let data = ablPtr[i].mData {
            memset(data, 0, Int(ablPtr[i].mDataByteSize))
        }
    }
}

/// Plays internet radio streams using AVPlayer.
///
/// **Features:**
/// - HTTP/HTTPS stream playback
/// - HLS (.m3u8) adaptive streaming support
/// - ICY metadata extraction (SHOUTcast/Icecast)
/// - Buffering state detection
/// - Error handling for network issues
///
/// **Limitations:**
/// - No EQ support (AVPlayer cannot use AVAudioUnitEQ)
/// - For local files with EQ, use AudioPlayer instead
///
/// **Observable State:**
/// - `isPlaying` - Playback state
/// - `isBuffering` - Network buffering state
/// - `currentStation` - Currently playing station
/// - `streamTitle` - Live metadata (song title)
/// - `streamArtist` - Live metadata (artist name)
/// - `error` - Error message if stream fails
///
/// **Usage:**
/// Should be used via PlaybackCoordinator for proper coordination with AudioPlayer.
@MainActor
@Observable
final class StreamPlayer: NSObject, @preconcurrency AVPlayerItemMetadataOutputPushDelegate {
    // MARK: - State

    private(set) var isPlaying: Bool = false
    private(set) var isBuffering: Bool = false
    private(set) var currentStation: RadioStation?
    private(set) var streamTitle: String?
    private(set) var streamArtist: String?
    private(set) var error: String?

    /// Stream volume (0.0-1.0 linear amplitude, same scale as AVAudioPlayerNode.volume).
    /// Synced to the internal AVPlayer on every change.
    var volume: Float = 0.75 {
        didSet { player.volume = volume }
    }

    /// Stream balance (-1.0 left to 1.0 right). Stored but NOT applied —
    /// AVPlayer has no .pan property. Enables uniform propagation from
    /// PlaybackCoordinator without backend type checks. Will be applied
    /// when Phase 2 Loopback Bridge routes streams through AVAudioEngine.
    var balance: Float = 0.0

    // MARK: - Loopback Bridge (Phase 2)

    /// The active MTAudioProcessingTap reference (macOS 26 SDK: direct type, not Unmanaged)
    private var currentTapRef: MTAudioProcessingTap?

    // MARK: - AVPlayer

    let player = AVPlayer()  // Internal for PlaybackCoordinator resume access
    private var statusObserver: AnyCancellable?
    private var itemStatusObserver: AnyCancellable?
    private var currentMetadataOutput: AVPlayerItemMetadataOutput?

    // MARK: - Initialization

    override init() {
        super.init()
        setupObservers()
    }

    // MARK: - Playback Control

    /// Play a radio station (for favorites menu)
    func play(station: RadioStation) async {
        currentStation = station
        error = nil
        streamTitle = nil
        streamArtist = nil

        let playerItem = AVPlayerItem(url: station.streamURL)
        player.replaceCurrentItem(with: playerItem)

        setupMetadataObserver(for: playerItem)
        setupItemStatusObserver(for: playerItem)

        // Apply current volume before playback starts (persisted volume from UserDefaults)
        player.volume = volume

        player.play()
        isPlaying = true
    }

    /// Play a stream from URL (for playlist tracks)
    /// Preserves Track metadata (title/artist) until ICY metadata loads
    func play(url: URL, title: String? = nil, artist: String? = nil) async {
        // Create internal RadioStation for playback
        let station = RadioStation(
            name: title ?? url.host ?? "Internet Radio",
            streamURL: url
        )

        // Play the stream (play(station:) clears streamTitle/streamArtist)
        await play(station: station)

        // Reapply initial metadata if ICY hasn't arrived yet during connection
        if streamTitle == nil { streamTitle = title }
        if streamArtist == nil { streamArtist = artist }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        currentStation = nil
        streamTitle = nil
        streamArtist = nil
        error = nil
    }

    // MARK: - Loopback Tap (2.2e, 2.2f)

    /// Attach an MTAudioProcessingTap to the current AVPlayerItem for loopback bridge.
    /// Must be called after play() so AVPlayerItem exists.
    /// Uses kMTAudioProcessingTapCreationFlag_PreEffects to get audio before effects.
    func attachLoopbackTap(
        ringBuffer: LockFreeRingBuffer,
        onFormatReady: @escaping @Sendable (Float64) -> Void
    ) async {
        guard let currentItem = player.currentItem else { return }

        // Create context (retained, released in loopbackTapFinalize)
        let context = LoopbackTapContext(ringBuffer: ringBuffer, onFormatReady: onFormatReady)
        let clientInfo = Unmanaged.passRetained(context).toOpaque()

        // Set up callbacks (2.2a: top-level @convention(c) functions)
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: clientInfo,
            init: loopbackTapInit,
            finalize: loopbackTapFinalize,
            prepare: loopbackTapPrepare,
            unprepare: loopbackTapUnprepare,
            process: loopbackTapProcess
        )

        // Create tap (macOS 26 SDK: direct MTAudioProcessingTap?, not Unmanaged)
        var tap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PreEffects,
            &tap
        )

        guard status == noErr, let tap else {
            // Release context on failure (balances passRetained above)
            Unmanaged<LoopbackTapContext>.fromOpaque(clientInfo).release()
            return
        }

        currentTapRef = tap

        // Load audio tracks (modern async API, macOS 15+)
        guard let tracks = try? await currentItem.asset.loadTracks(withMediaType: .audio) else {
            return
        }

        // Create audio mix with tap on all audio tracks
        let audioMix = AVMutableAudioMix()
        var inputParams: [AVMutableAudioMixInputParameters] = []
        for track in tracks {
            let params = AVMutableAudioMixInputParameters(track: track)
            params.audioTapProcessor = tap
            inputParams.append(params)
        }
        audioMix.inputParameters = inputParams
        currentItem.audioMix = audioMix
    }

    /// Detach the MTAudioProcessingTap from the current AVPlayerItem.
    /// Safe to call even if no tap is attached. Quiesces the producer
    /// so ring buffer can be safely flushed afterward.
    func detachLoopbackTap() {
        player.currentItem?.audioMix = nil
        currentTapRef = nil
    }

    // MARK: - Observers

    private func setupObservers() {
        // Observe playback status (use RunLoop.main for @MainActor safety)
        statusObserver = player.publisher(for: \.timeControlStatus)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.handleStatusChange(status)
            }
    }

    private func handleStatusChange(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            isPlaying = true
            isBuffering = false
        case .paused:
            isPlaying = false
            isBuffering = false
        case .waitingToPlayAtSpecifiedRate:
            isBuffering = true
        @unknown default:
            break
        }
    }

    private func setupItemStatusObserver(for item: AVPlayerItem) {
        // Cancel old observer before creating new one
        itemStatusObserver?.cancel()

        // Observe item status for error detection
        itemStatusObserver = item.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                if status == .failed {
                    self?.handlePlaybackError(item.error)
                }
            }
    }

    private func setupMetadataObserver(for item: AVPlayerItem) {
        // Modern API: AVPlayerItemMetadataOutput with delegate (macOS 15+)
        let output = AVPlayerItemMetadataOutput(identifiers: nil)
        output.setDelegate(self, queue: DispatchQueue.main)
        item.add(output)
        currentMetadataOutput = output
    }

    // MARK: - AVPlayerItemMetadataOutputPushDelegate

    func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        // Since delegate queue is DispatchQueue.main and class is @MainActor, this is safe
        // Process metadata groups
        for group in groups {
            for item in group.items {
                // Modern API: load(.stringValue) - async, non-deprecated
                if item.commonKey == .commonKeyTitle {
                    Task { @MainActor in
                        if let title = try? await item.load(.stringValue) {
                            streamTitle = title
                        }
                    }
                } else if item.commonKey == .commonKeyArtist {
                    Task { @MainActor in
                        if let artist = try? await item.load(.stringValue) {
                            streamArtist = artist
                        }
                    }
                }
            }
        }
    }

    func metadataOutputSequenceWasFlushed(_ output: AVPlayerItemMetadataOutput) {
        // Clear stale metadata when the sequence resets
        streamTitle = nil
        streamArtist = nil
    }

    private func handlePlaybackError(_ playbackError: Error?) {
        if let playbackError {
            error = "Stream error: \(playbackError.localizedDescription)"
            isPlaying = false
            isBuffering = false
        }
    }

    // deinit is not needed - Combine cancellables clean up automatically
}
