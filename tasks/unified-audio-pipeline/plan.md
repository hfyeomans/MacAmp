# Plan: Unified Audio Pipeline (Custom Stream Decode)

> **Purpose:** Replace AVPlayer-based streaming with a custom decode pipeline that feeds PCM into AVAudioEngine, enabling EQ, visualization, and balance for internet radio streams.

---

## Before / After Architecture

### BEFORE (Current Dual Backend)

```
LOCAL FILES (AVAudioEngine — full processing):
AVAudioFile → AVAudioPlayerNode → AVAudioUnitEQ(10-band) → mainMixerNode → outputNode
                                        │                        │
                                   [EQ processing]         [visualizer tap]
                                                                 │
                                                          VisualizerPipeline
                                                          (spectrum, waveform, Butterchurn)

INTERNET RADIO (AVPlayer — black box, no processing):
HTTP URL → AVPlayer → System Audio Output (direct)
              │
         [ICY metadata via AVPlayerItemMetadataOutput]
         [volume via AVPlayer.volume]
         ❌ No EQ, No visualizer, No balance
```

### AFTER (Unified Pipeline)

```
LOCAL FILES (unchanged):
AVAudioFile → AVAudioPlayerNode ──┐
                                   │
                                   ▼
                            AVAudioUnitEQ(10-band)
                                   │
                            mainMixerNode ──► [visualizer tap] ──► VisualizerPipeline
                                   │
                              outputNode ──► Speakers

INTERNET RADIO (custom decode pipeline):
HTTP URL → URLSession ──► ICYFramer ──► AudioFileStream ──► AudioConverter
              │               │                                    │
         [HTTP headers]  [StreamTitle]                      [Float32 PCM]
         [icy-metaint]  [StreamArtist]                          │
                                                        LockFreeRingBuffer
                                                         (SPSC, 4096 frames)
                                                                │
                                                        AVAudioSourceNode ──┐
                                                                            │
                                                                            ▼
                                                                     AVAudioUnitEQ(10-band)
                                                                            │
                                                                     mainMixerNode ──► [visualizer tap]
                                                                            │
                                                                       outputNode ──► Speakers
```

**Key insight:** Both paths converge at AVAudioEngine. The engine doesn't know or care if PCM came from a local file or a decoded stream.

## Implementation Phases

### Phase 1: Core Decode Pipeline (MVP)

**Goal:** Progressive HTTP streams (SHOUTcast/Icecast MP3/AAC) decoded to PCM, feeding AVAudioEngine.

#### 1.1 ICYFramer (new file: `MacAmpApp/Audio/Streaming/ICYFramer.swift`)

Strips ICY metadata from HTTP byte stream before audio reaches parser.

- Parse `icy-metaint` from HTTP response headers
- Count audio bytes, extract metadata blocks at intervals
- Emit `.audio(Data)` and `.metadata(ICYMetadata)` chunks
- Parse `StreamTitle='Artist - Title';` from metadata blocks
- Pure value type (struct), no async, no state beyond counters

#### 1.2 AudioFileStreamParser (new file: `MacAmpApp/Audio/Streaming/AudioFileStreamParser.swift`)

Wraps Apple's C-based AudioFileStream API for parsing compressed audio packets.

- `AudioFileStreamOpen()` with format hint (MP3 or AAC based on Content-Type)
- `AudioFileStreamParseBytes()` fed by ICYFramer audio chunks
- Property callback: capture DataFormat (ASBD), MagicCookie (for AAC)
- Packets callback: enqueue compressed packets for converter
- `AudioFileStreamClose()` on teardown

#### 1.3 AudioConverterDecoder (new file: `MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift`)

Wraps Apple's AudioConverter for decoding compressed packets to Float32 PCM.

- Input: compressed ASBD from AudioFileStream + packet queue
- Output: Float32 interleaved stereo at 44100 Hz (normalized)
- `AudioConverterNew()` with input/output ASBDs
- `AudioConverterFillComplexBuffer()` with input data callback
- `AudioConverterSetProperty()` for magic cookie (AAC)
- Handle format changes: dispose old converter, create new, flush ring buffer with generation increment
- Pre-allocate decode output buffer (no allocation during decode loop)

**C API lifetime management (Oracle P2-2):**
- Packet data must be copied before returning from AudioFileStream callback (data pointer only valid during callback)
- Packet descriptions must be copied alongside packet data (same lifetime)
- `AudioConverterDispose()` MUST be called before `AudioFileStreamClose()` (converter may reference parser state)
- After `stop()`, invalidate all callback context pointers before disposing C objects
- Use `Unmanaged.passRetained/release` pattern for callback context (same as VisualizerPipeline)

#### 1.4 StreamDecodePipeline (new file: `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift`)

Orchestrates the full pipeline. **Note (Oracle P1-1):** Cannot be a Swift `actor` directly because `URLSessionDataDelegate` requires `NSObject` conformance. Use an `NSObject` delegate proxy that forwards bytes to the pipeline, or use `URLSession.asyncBytes` (async sequence, no delegate needed).

**Recommended approach:** `@MainActor` class (not actor) with internal serial decode DispatchQueue. URLSession delegate is a lightweight `NSObject` proxy that forwards `didReceive(data:)` to the decode queue. This matches the existing PlaybackCoordinator/@MainActor pattern.

- Manages URLSession data task with `Icy-MetaData: 1` header
- NSObject delegate proxy forwards bytes to decode serial queue
- Routes bytes through ICYFramer → AudioFileStreamParser → AudioConverterDecoder
- Ring buffer write happens on decode queue (non-RT, can allocate)
- **Stream generation token (Oracle P1-3):** Each `start()` call increments a generation counter. Callbacks check generation before activating bridge or writing to ring buffer. Prevents stale callbacks from previous streams.
- **Prebuffer threshold (Oracle P2-4):** Don't call `onFormatReady` until ring buffer has minimum ~2048 frames buffered. Prevents startup underruns.
- Publishes state changes to StreamPlayer via @Sendable callbacks:
  - `onStateChange: (StreamState) -> Void` (playing/buffering/error)
  - `onFormatReady: (Float64) -> Void` (triggers activateStreamBridge)
  - `onMetadata: (ICYMetadata) -> Void` (StreamTitle/StreamArtist)
- **Format hint handling (Oracle P2-3):** Map Content-Type broadly: `audio/mpeg` → MP3, `audio/aac`/`audio/aacp`/`audio/x-aac` → AAC, `application/octet-stream` → auto-detect (pass 0 to AudioFileStreamOpen)

#### 1.5 StreamPlayer Modification

Replace AVPlayer internals with StreamDecodePipeline.

**Remove:**
- AVPlayer instance and lifecycle
- AVPlayerItemMetadataOutput
- Combine-based status/item observers
- play(station:) AVPlayerItem creation

**Add:**
- StreamDecodePipeline ownership
- Pipeline callback wiring in init
- Forwarding play/pause/stop to pipeline

**Preserve (unchanged API):**
- `isPlaying`, `isBuffering`, `streamTitle`, `streamArtist`, `error`
- `volume`, `balance` properties
- `play(station:)`, `play(url:)`, `pause()`, `stop()`

**Add (Oracle P1-2):**
- `resume()` method for PlaybackCoordinator's `togglePlayPause()` resume path (currently calls `streamPlayer.player.play()` — must be replaced with pipeline resume)

**Remove:**
- `let player = AVPlayer()` property (was `internal` for PlaybackCoordinator resume access — no longer needed)

#### 1.6 PlaybackCoordinator Bridge Lifecycle

Simplify bridge lifecycle (no tap attach/detach needed).

- `setupStreamBridge()`: create ring buffer, pass to StreamDecodePipeline
- `teardownStreamBridge()`: stop pipeline, deactivate engine bridge, nil ring buffer
- Pipeline's `onFormatReady` callback triggers `audioPlayer.activateStreamBridge()`
- Sequence: teardown → stop → create pipeline with ring buffer → start pipeline → wait for format ready → engine activates

#### 1.7 AudioPlayer Consumer Side (re-add from prior work)

Re-implement the AVAudioSourceNode consumer (documented in research, previously Oracle-reviewed):

- `streamSourceNode: AVAudioSourceNode?`
- `makeStreamRenderBlock()` — nonisolated static func, RT-safe
- `activateStreamBridge(ringBuffer:sampleRate:)` — stop/reset/rewire engine
- `deactivateStreamBridge()` — disconnect stream node, rewire playerNode
- `isBridgeActive`, `isEngineRendering` computed properties
- Volume/balance didSet propagation to streamSourceNode

#### 1.8 VisualizerView Update

Re-apply `isPlaying` → `isEngineRendering` changes (4 sites, previously documented).

#### 1.9 Capability Flags Update

Re-apply `|| audioPlayer.isBridgeActive` to supportsEQ/Balance/Visualizer.

### Phase 2: Hardening & Optimization (Post-MVP)

#### 2.1 Network Error Recovery
- Auto-reconnect with exponential backoff on network drops
- AudioFileStream reset on reconnection (new stream ID)
- UI indication of reconnecting state

#### 2.2 os_workgroup Integration
- Retrieve workgroup from AVAudioEngine output node
- Join decode thread to audio workgroup
- Prevents CPU core parking on Apple Silicon under load

#### 2.3 macOS 26 Passthrough Guard
- Validate AudioConverter output format is always Float32 PCM
- Guard against non-PCM frames from macOS 26 passthrough mode

#### 2.4 OGG Vorbis Support (if needed)
- Evaluate libvorbis/libogg dependency
- Or defer indefinitely (most internet radio is MP3/AAC)

### Phase 3: HLS Support (Future, Separate Task)

- M3U8 playlist parser
- TS segment downloader
- Feed segment audio data to AudioFileStream
- ABR quality switching
- This is a significant effort — may warrant its own task

## Files Modified / Created

| File | Action | Description |
|------|--------|-------------|
| `Audio/Streaming/ICYFramer.swift` | NEW | ICY metadata protocol parser |
| `Audio/Streaming/AudioFileStreamParser.swift` | NEW | AudioFileStream C API wrapper |
| `Audio/Streaming/AudioConverterDecoder.swift` | NEW | AudioConverter C API wrapper |
| `Audio/Streaming/StreamDecodePipeline.swift` | NEW | Pipeline orchestrator (actor) |
| `Audio/StreamPlayer.swift` | MODIFY | Replace AVPlayer with pipeline |
| `Audio/AudioPlayer.swift` | MODIFY | Re-add consumer side (sourceNode, bridge) |
| `Audio/PlaybackCoordinator.swift` | MODIFY | Simplified bridge lifecycle + flags |
| `Views/VisualizerView.swift` | MODIFY | isPlaying → isEngineRendering |

## What Gets Reused

| Component | Source | Status | Notes |
|-----------|--------|--------|-------|
| LockFreeRingBuffer | `Audio/LockFreeRingBuffer.swift` (in main) | As-is, no changes | Already in main from PR #50 |
| VisualizerPipeline | `Audio/VisualizerPipeline.swift` (in main) | As-is | Gets data from engine tap automatically |
| PlaybackCoordinator orchestration pattern | In main | Modified in Phase 1.6 | Add bridge lifecycle, update flags |
| Phase 1 volume routing | PR #53 (in main) | As-is | setVolume/setBalance routing stays |

**Clarification (Oracle P2-5):** The consumer-side code (AVAudioSourceNode, makeStreamRenderBlock, activateStreamBridge, etc.) is NOT in main — it was reverted in commit `987b2f3`. These patterns must be **re-implemented** during Phase 1.7, using the documented code patterns in the "Prior Work Reference" section below. The patterns are proven (were Oracle-reviewed before revert) but the actual code must be written fresh.

## What Gets Removed (Depreciated)

All MTAudioProcessingTap code was already reverted to main in commit `987b2f3`. Nothing to remove.

## Commit Strategy

1. Phase 1.1-1.3: Core decode components (ICYFramer, Parser, Converter)
2. Phase 1.4: StreamDecodePipeline actor
3. Phase 1.5: StreamPlayer modification
4. Phase 1.6-1.7: PlaybackCoordinator + AudioPlayer bridge
5. Phase 1.8-1.9: VisualizerView + capability flags
6. Build + Oracle review
7. Verification (V1-V10)

## Verification Plan

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
- [ ] **V12** Stop stream: clean teardown, no orphan tasks
- [ ] **V13** Extended playback (30+ min): no drift, no memory growth
- [ ] **V14** Network drop during stream: graceful error (Phase 2 adds auto-reconnect)

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| AudioFileStream doesn't support stream format | MEDIUM | Format hint based on Content-Type; fallback to auto-detect |
| AudioConverter sample rate mismatch | LOW | Normalize all output to 44100 Hz; converter handles SRC |
| Network jitter causes ring buffer underrun | LOW | 4096 frame buffer (~85ms); AudioConverter provides steady output |
| Swift 6.2 C callback isolation | MEDIUM | Follow VisualizerPipeline.makeTapHandler() pattern; nonisolated static |
| ICY metadata corrupts audio stream | LOW | ICYFramer strips metadata before parser sees bytes |

## Prior Work Reference (From T5 Phase 2 Branch)

The `feature/stream-loopback-bridge` branch contained working, Oracle-reviewed consumer-side code that was reverted (commit `987b2f3`) because the producer side (MTAudioProcessingTap) was dead. This code should be **re-used as reference** during implementation:

### AudioPlayer.swift Consumer Side (Re-implement in Phase 1.7)

Previously in commits `d47da07` and `a5f96b3`. Key patterns to re-use:

```swift
// 1. Stream source node property
@ObservationIgnored private var streamSourceNode: AVAudioSourceNode?
@ObservationIgnored private var streamRingBuffer: LockFreeRingBuffer?
private(set) var isBridgeActive: Bool = false
var isEngineRendering: Bool { audioEngine.isRunning && (isPlaying || isBridgeActive) }

// 2. Render block — MUST be nonisolated static (Swift 6.2 lesson #1)
private nonisolated static func makeStreamRenderBlock(ringBuffer: LockFreeRingBuffer) -> AVAudioSourceNodeRenderBlock

// 3. Source node format — MUST be interleaved (lesson #2)
AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 2, interleaved: true)

// 4. Graph format — MUST be non-interleaved (lesson #2)
let deviceFormat = audioEngine.outputNode.inputFormat(forBus: 0)
AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: deviceFormat.sampleRate, channels: 2, interleaved: false)

// 5. Engine rewire — MUST stop/reset first (lesson #3)
audioEngine.stop() → audioEngine.reset() → disconnect → connect → prepare → start

// 6. Verify mixer→output after reset (lesson #4)
if audioEngine.outputConnectionPoints(for: mainMixerNode, outputBus: 0).isEmpty { reconnect }

// 7. isSilence — explicit ObjCBool reset (Oracle fix)
isSilence.pointee = ObjCBool(framesRead == 0)
```

### PlaybackCoordinator.swift Bridge Lifecycle (Simplify in Phase 1.6)

Previously in commit `0ba7b1a`. Key patterns:

```swift
// Capability flags (re-use exactly)
var supportsEQ: Bool { !isStreamBackendActive || audioPlayer.isBridgeActive }
var supportsBalance: Bool { !isStreamBackendActive || audioPlayer.isBridgeActive }
var supportsVisualizer: Bool { !isStreamBackendActive || audioPlayer.isBridgeActive }

// Bridge lifecycle — simplify (no tap attach/detach needed)
// OLD: teardown → stop → setup ring buffer → play stream → attach tap → wait for tapPrepare
// NEW: teardown → stop → create pipeline with ring buffer → start pipeline → onFormatReady activates bridge
```

### VisualizerView.swift (Re-apply in Phase 1.8)

4 sites: `audioPlayer.isPlaying` → `audioPlayer.isEngineRendering` (lines 74, 78, 103, 263)

### Critical Lessons Learned (MUST follow)

From `tasks/_context/claude-mistakes-stream-loopback-bridge.md`:

1. **@MainActor isolation crash:** Render blocks in @MainActor methods inherit isolation → crash on audio thread. Use `nonisolated private static func`.
2. **Non-interleaved format = silent audio:** Source node block format MUST be interleaved (matches ring buffer). Graph connection format MUST be non-interleaved.
3. **Hot-swap crash (-10868):** MUST stop/reset engine before rewiring. Follow `rewireForCurrentFile()` pattern.
4. **Mixer→output disconnects after reset:** MUST verify and reconnect after `audioEngine.reset()`.
5. **Ring buffer race:** MUST teardown before setup. Producer must be quiesced before flush.

### Related PRs

- **PR #53** (merged): T5 Phase 1 — Stream volume control + capability flags. Established PlaybackCoordinator.setVolume/setBalance routing. **Still in main, no changes needed.**
- **PR #49** (merged): N1-N6 internet radio fixes. Established PlaybackCoordinator computed state (isPlaying/isPaused). **Still in main, no changes needed.**

## UI Dimming Behavior (Phase 1 → Unified Pipeline Transition)

Phase 1 (PR #53, in main) added UI dimming that disables EQ, balance, and visualizer controls during stream playback. This was correct at the time because AVPlayer couldn't feed AVAudioEngine.

**Current behavior (main, with AVPlayer streams):**
- `supportsEQ` returns `false` during streams → EQ sliders dimmed (opacity 0.5, non-interactive)
- `supportsBalance` returns `false` during streams → balance slider dimmed
- `supportsVisualizer` returns `false` during streams → (unused by UI currently)

**Locations:**
- `PlaybackCoordinator.swift:87` — `var supportsEQ: Bool { !isStreamBackendActive }`
- `PlaybackCoordinator.swift:91` — `var supportsBalance: Bool { !isStreamBackendActive }`
- `PlaybackCoordinator.swift:97` — `var supportsVisualizer: Bool { !isStreamBackendActive }`
- `WinampEqualizerWindow.swift:105-106` — `.opacity(supportsEQ ? 1.0 : 0.5)` + `.allowsHitTesting(supportsEQ)`
- `MainWindowSlidersLayer.swift:64-66` — `.opacity(supportsBalance ? 1.0 : 0.5)` + `.allowsHitTesting(supportsBalance)` + tooltip

**After unified pipeline (Phase 1.6g):**
- Change flags to: `!isStreamBackendActive || audioPlayer.isBridgeActive`
- When bridge is active (stream decoded through AVAudioEngine), all flags return `true`
- EQ, balance, visualizer controls un-dim automatically — **no UI changes needed**
- The dimming code stays in place for the error state fallback (stream fails → controls re-dim)

## T1 Phase 4 (Engine Transport Extraction)

**Status:** Deferred until after this task completes. Engine transport boundaries will change when streamSourceNode is added. Phase 4 should extract transport AFTER the unified pipeline stabilizes to get correct extraction boundaries.
