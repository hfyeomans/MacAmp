# TODO: Unified Audio Pipeline (Custom Stream Decode)

> **Purpose:** Broken-down task checklist derived from plan.md. Each item is a discrete, verifiable unit of work.

---

## Status: PENDING ORACLE REVIEW
>
> **Prerequisite:** `swift-concurrency-62-cleanup` PR 1 must be merged (SWIFT_VERSION 6.2 established).
> **Post-task:** `swift-concurrency-62-cleanup` PR 2 adds AudioPlayer `isolated deinit` + `@concurrent`.

---

## Phase 1: Core Decode Pipeline (MVP)

### 1.1 ICYFramer — ✅ DONE
- [x] **1.1a** Create `MacAmpApp/Audio/Streaming/ICYFramer.swift`
- [x] **1.1b** Parse `icy-metaint` from HTTP response headers
- [x] **1.1c** Implement byte counting and metadata block extraction
- [x] **1.1d** Parse `StreamTitle='...'` from metadata blocks (Latin-1 encoding)
- [x] **1.1e** Emit `.audio(Data)` and `.metadata(ICYMetadata)` chunks
- [x] **1.1f** Handle edge cases: no metaint header (pass all bytes as audio), partial metadata blocks across data chunks

### 1.2 AudioFileStreamParser — ✅ DONE
- [x] **1.2a** Create `MacAmpApp/Audio/Streaming/AudioFileStreamParser.swift`
- [x] **1.2b** Wrap `AudioFileStreamOpen` with format hint (MP3 or AAC based on Content-Type or URL extension)
- [x] **1.2c** Implement property listener callback: capture DataFormat (ASBD), MagicCookie
- [x] **1.2d** Implement packets callback: enqueue compressed packets with descriptions
- [x] **1.2e** Implement `parse(_ data: Data)` method feeding `AudioFileStreamParseBytes`
- [x] **1.2f** Implement `close()` for cleanup
- [x] **1.2g** Handle @convention(c) callbacks with Unmanaged context pointer + debug queue assertions

### 1.3 AudioConverterDecoder — ✅ DONE
- [x] **1.3a** Create `MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift`
- [x] **1.3b** Create converter with input ASBD (from parser) → output Float32 interleaved stereo
- [x] **1.3c** Set magic cookie for AAC via `AudioConverterSetProperty`
- [x] **1.3d** Implement input data callback with stable buffer allocation (Oracle HIGH fix)
- [x] **1.3e** Implement `decode() -> (UnsafePointer<Float>, Int)?` returning PCM frames
- [x] **1.3f** Pre-allocate decode output buffer (no allocation during decode loop)
- [x] **1.3g** Handle nil packet descriptions for CBR formats (Oracle MEDIUM fix)
- [x] **1.3h** Handle `AudioConverterFillComplexBuffer` with FourCC error code 'ndta' (Oracle LOW fix)

### 1.4 StreamDecodePipeline — ✅ DONE
- [x] **1.4a** Create `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` — @MainActor class + DecodeContext (@unchecked Sendable, queue-confined)
- [x] **1.4b** Create SessionDelegateProxy (immutable `let` callbacks via init, @unchecked Sendable) — Oracle MEDIUM fix
- [x] **1.4c** Implement URLSession data task with `Icy-MetaData: 1` header
- [x] **1.4d** Route data through ICYFramer → Parser → Decoder on serial decode queue
- [x] **1.4e** Write decoded PCM to LockFreeRingBuffer on decode queue
- [x] **1.4f** Generation token: incremented on BOTH start() AND stop(), checked in all callbacks — Oracle HIGH fix
- [x] **1.4g** Prebuffer threshold: onFormatReady fires after 2048 frames, single-fire per context
- [x] **1.4h** @MainActor @Sendable callbacks: onStateChange, onFormatReady, onMetadata
- [x] **1.4i** Lifecycle: start(url:ringBuffer:), pause(), resume(), stop(), isolated deinit
- [x] **1.4j** Format hint from URL extension and path; Content-Type helper available
- [x] **1.4k** URLSession delegate on dedicated OperationQueue
- [x] **1.4l** C API dispose ordering: decoder.dispose() before parser.close() in shutdown()
- [x] **1.4m** Case-insensitive icy-metaint header lookup — Oracle LOW fix
- [x] **1.4n** Error/completion paths call stopInternal() for full teardown — Oracle MEDIUM fix
- [x] **1.4o** isShutdown guard in decode loop prevents stale PCM after stop — Oracle HIGH fix

### 1.5 StreamPlayer Modification — ✅ DONE
- [x] **1.5a** Removed AVPlayer, AVPlayerItem, AVPlayerItemMetadataOutput, NSObject base class
- [x] **1.5b** Removed Combine, @preconcurrency import AVFoundation, all observers
- [x] **1.5c** Added StreamDecodePipeline as owned dependency (created in init)
- [x] **1.5d** Wired pipeline callbacks to @Observable state via setupPipelineCallbacks()
- [x] **1.5e** Forward play(station:)/play(url:)/pause()/stop() to pipeline
- [x] **1.5f** Added `resume()` method; updated PlaybackCoordinator to use it
- [x] **1.5g** Removed AVPlayer property; added currentRingBuffer/currentSampleRate for bridge
- [x] **1.5h** Preserved volume/balance properties (stored, engine applies via AudioPlayer)
- [x] **1.5i** No AVFoundation/CoreMedia/MediaToolbox imports needed
- [x] **1.5j** Added `isolated deinit` calling `pipeline.stop()`
- [x] **1.5k** Added `onFormatReady` callback for PlaybackCoordinator bridge activation

### 1.6 PlaybackCoordinator Bridge Lifecycle — ✅ DONE
- [x] **1.6a** Ring buffer created per-stream in StreamPlayer, passed via onFormatReady
- [x] **1.6b** Bridge setup via onFormatReady → audioPlayer.activateStreamBridge()
- [x] **1.6c** Bridge teardown via audioPlayer.deactivateStreamBridge() in all transition paths
- [x] **1.6d** Wired streamPlayer.onFormatReady → activateStreamBridge in init
- [x] **1.6e** Added deactivateStreamBridge in play(url:), play(track:), play(station:) — Oracle HIGH fix: stream-to-stream path
- [x] **1.6f** Added deactivateStreamBridge in stop()
- [x] **1.6g** Capability flags: `!isStreamBackendActive || audioPlayer.isBridgeActive`
- [x] **1.6h** resume() calls streamPlayer.resume()
- [x] **1.6i** Wired streamPlayer.onStreamTerminated → deactivateStreamBridge for error/idle states — Oracle MEDIUM fix
- [x] **1.6j** Added deactivateStreamBridge in handlePlaylistAdvance .playLocally — Oracle HIGH fix

### 1.7 AudioPlayer Consumer Side — ✅ DONE
- [x] **1.7a** Added streamSourceNode: AVAudioSourceNode? (@ObservationIgnored)
- [x] **1.7b** Added streamRingBuffer: LockFreeRingBuffer? (@ObservationIgnored)
- [x] **1.7c** Added isBridgeActive: Bool (private(set))
- [x] **1.7d** Added isEngineRendering: Bool computed property
- [x] **1.7e** makeStreamRenderBlock() — nonisolated static, RT-safe, buffer layout validation — Oracle MEDIUM fix
- [x] **1.7f** activateStreamBridge(ringBuffer:sampleRate:) — interleaved source, non-interleaved graph, stop/reset/rewire
- [x] **1.7g** deactivateStreamBridge() — idempotent, disconnect/detach/restore playerNode
- [x] **1.7h** Mixer→output verify after reset (lesson #4)
- [x] **1.7i** volume/balance didSet propagates to streamSourceNode?.volume/.pan
- [x] **1.7j** getFrequencyData uses isEngineRendering
- [x] **1.7k** snapshotButterchurnFrame uses isEngineRendering
- [x] **1.7l** deactivateStreamBridge is idempotent — cleanup order: bridge → nil sourceNode → nil ringBuffer → reset flag

### 1.8 VisualizerView Update — ✅ DONE
- [x] **1.8a-d** All 4 sites: `audioPlayer.isPlaying` → `audioPlayer.isEngineRendering`

### 1.9 Build & Verify
- [ ] **1.9a** Build with Xcode (clean build)
- [ ] **1.9b** Oracle review (gpt-5.3-codex, xhigh)
- [ ] **1.9c** Fix any Oracle findings

---

## Phase 1 Verification

- [ ] **V1** Progressive MP3 stream plays with audio output
- [ ] **V2** Progressive AAC stream plays with audio output
- [ ] **V3** ICY metadata displays (StreamTitle, StreamArtist)
- [ ] **V4** EQ sliders affect stream audio
- [ ] **V5** Spectrum analyzer shows data during stream
- [ ] **V6** Oscilloscope shows data during stream
- [ ] **V7** Milkdrop/Butterchurn visualizer shows data during stream
- [ ] **V8** Balance slider pans stream audio
- [ ] **V9** Switch stream ↔ local file: no crash, controls update
- [ ] **V10** Local file playback unchanged (regression test)
- [ ] **V11** Volume persists across stream/local switches
- [ ] **V12** Stop stream: clean teardown, no orphan tasks (use Swift 6.2 task naming for diagnosis)
- [ ] **V13** Extended playback (30+ min): no drift, no memory growth
- [ ] **V14** Network drop during stream: graceful error state

---

## Phase 2: Hardening & Optimization (Post-MVP, Separate PR)

- [ ] **2.1** Network error recovery: auto-reconnect with exponential backoff
- [ ] **2.2** os_workgroup integration: join decode thread to audio workgroup
- [ ] **2.3** macOS 26 passthrough guard: validate output format is always Float32 PCM
- [ ] **2.4** OGG Vorbis support (evaluate libvorbis dependency or defer)

---

## Phase 3: HLS Support (Future, Separate Task)

- [ ] **3.1** M3U8 playlist parser
- [ ] **3.2** TS segment downloader
- [ ] **3.3** Feed segment audio to AudioFileStream
- [ ] **3.4** ABR quality switching
- [ ] **3.5** Integration with StreamDecodePipeline

---

## Reference: Prior Work to Re-Use

These items were implemented, Oracle-reviewed, and documented in the `feature/stream-loopback-bridge` branch before being reverted (commit `987b2f3`). The code patterns are preserved in `plan.md` and `research.md`.

| Item | Original Commit | Re-use In |
|------|----------------|-----------|
| makeStreamRenderBlock() pattern | `d47da07` | Phase 1.7e |
| activateStreamBridge() engine rewire | `d47da07` | Phase 1.7f |
| deactivateStreamBridge() cleanup | `d47da07` | Phase 1.7g |
| Capability flags with isBridgeActive | `0ba7b1a` | Phase 1.6g |
| VisualizerView isEngineRendering (4 sites) | `0ba7b1a` | Phase 1.8 |
| isSilence ObjCBool fix | `a5f96b3` | Phase 1.7e |
| Ring buffer identity gate in callbacks | `a5f96b3` | Phase 1.6d |
