# Research: Internet Streaming Volume Control

> **Purpose:** Captures all research findings, reference implementations, and technical analysis for enabling volume control and equalizer on internet radio streams.

---

## Status: COMPLETE - DOUBLE REVIEWED (Oracle B+ → Swift 6.2 Addendum)

## Problem Statement

Internet radio streams played via AVPlayer have no working volume controls or equalizer. Local file playback via AVAudioEngine supports both. Users expect consistent volume/EQ behavior regardless of audio source.

---

## 1. Current Architecture Analysis

### Dual-Backend Audio System

MacAmp uses two incompatible audio backends coordinated by `PlaybackCoordinator`:

**Local Files (AVAudioEngine):**
```
AVAudioFile -> AVAudioPlayerNode -> AVAudioUnitEQ (10-band) -> AVAudioMixerNode -> OutputNode
                                                                      |
                                                               [Audio Tap]
                                                                      |
                                                              VisualizerPipeline
```
- Full 10-band EQ (60Hz-16kHz, Winamp-accurate frequencies)
- Real-time spectrum analysis via Goertzel + vDSP FFT
- Volume control via `playerNode.volume` (0.0-1.0)
- Balance control via `playerNode.pan` (-1.0 to 1.0)

**Internet Radio (AVPlayer):**
```
HTTP URL -> AVPlayer -> System Audio (closed pipeline)
```
- No EQ capability (no node graph exposed)
- No audio tap for visualization
- Volume available via `player.volume` but NOT WIRED TO UI
- ICY metadata extraction works

### Root Cause: Volume Not Working

The UI volume slider binds ONLY to `audioPlayer.volume`:

```swift
// WinampMainWindow.swift (line ~535)
@Bindable var player = audioPlayer
WinampVolumeSlider(volume: $player.volume)

// AudioPlayer.swift (lines 79-85)
var volume: Float = 0.75 {
    didSet {
        playerNode.volume = volume              // AVAudioPlayerNode only
        videoPlaybackController.volume = volume  // Video AVPlayer only
        UserDefaults.standard.set(volume, forKey: Keys.volume)
        // NOTE: StreamPlayer is NEVER updated here
    }
}
```

**StreamPlayer.swift** has an AVPlayer (`let player = AVPlayer()`) but exposes NO volume property and has NO volume control methods. The UI slider has no path to affect stream volume.

### Root Cause: EQ Not Working

AVAudioUnitEQ is an AVAudioEngine node. It cannot be inserted into AVPlayer's internal audio pipeline. AVPlayer is a high-level "black box" that routes directly to system audio output with no developer-accessible intermediate processing.

```swift
// AudioPlayer.swift - EQ only connected to AVAudioEngine graph
private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
// Connected: playerNode -> eqNode -> mainMixerNode
// StreamPlayer has NO eqNode and CANNOT have one
```

### Root Cause: Visualization Not Working

The VisualizerPipeline installs an audio tap on `audioEngine.mainMixerNode`:

```swift
// AudioPlayer.swift (line ~776)
visualizerPipeline.installTap(on: audioEngine.mainMixerNode)
```

AVPlayer has no mixer node to tap. No PCM data is accessible for spectrum/waveform analysis during stream playback.

---

## 2. Key Files and Line References

| Component | File | Lines | Key Property/Method |
|-----------|------|-------|-------------------|
| Volume Control | AudioPlayer.swift | 79-85 | `var volume: Float` with didSet |
| Balance Control | AudioPlayer.swift | 87-92 | `var balance: Float` with didSet |
| EQ Setup | AudioPlayer.swift | 37, 633-652 | `eqNode`, `configureEQ()` |
| StreamPlayer | StreamPlayer.swift | 42, full file (199 lines) | `let player = AVPlayer()` |
| Stream Check | Track.swift | 17-19 | `var isStream: Bool` |
| Coordinator Routing | PlaybackCoordinator.swift | 100-122 | `play(track:)` |
| UI Volume Binding | WinampMainWindow.swift | 533-537 | `buildVolumeSlider()` |
| UI EQ Binding | WinampEqualizerWindow.swift | 8 | `@Environment(AudioPlayer.self)` |
| Visualizer Tap | AudioPlayer.swift | 776-778 | `installVisualizerTapIfNeeded()` |
| Video Volume | VideoPlaybackController.swift | 46-50 | `var volume: Float` with didSet |

---

## 3. Solution Approaches Analyzed

### Approach A: AVPlayer.volume for Stream Volume Control

**Feasibility: 10/10 | Complexity: Low | Recommended: YES**

AVPlayer has a native `.volume` property (0.0-1.0) that works independently of system volume. This is reliable for HLS and ICY streams.

**Implementation strategy:**
1. Add `volume` property to StreamPlayer with didSet syncing to `player.volume`
2. Wire PlaybackCoordinator to propagate volume changes to active backend
3. OR: Have AudioPlayer.volume didSet also update StreamPlayer when streaming

**Gotcha:** AVPlayer.volume is linear amplitude. AVAudioEngine uses the same linear scale for playerNode.volume, so no conversion needed. Both use 0.0-1.0 range.

**Balance:** AVPlayer does NOT have a native `.pan` property. Balance/panning would require MTAudioProcessingTap (Approach C) or accepting the limitation.

### Approach B: Disable EQ UI During Stream Playback

**Feasibility: 10/10 | Complexity: Low | Recommended: YES (as baseline)**

Accept the architectural limitation. When streaming, grey out or indicate that EQ is unavailable.

**Implementation:**
1. Add `isStreamPlaying` computed property to PlaybackCoordinator
2. EQ window checks this and shows visual indicator (dimmed sliders, tooltip)
3. Consistent with Winamp's own behavior for some stream types

### Approach C: MTAudioProcessingTap for Visualization + EQ

**Feasibility: 6-9/10 | Complexity: High | Recommended: Phase 2**

MTAudioProcessingTap is Apple's API for intercepting AVPlayer's audio pipeline. It provides raw PCM buffers in a real-time callback.

**For Visualization (Feasibility 9/10):**
- Extract samples in `tapProcess` callback
- Perform FFT using vDSP (same as current VisualizerPipeline)
- Feed data to existing visualization UI
- Pre-allocate all buffers (no allocations on audio thread)

**For EQ (Feasibility 6/10):**
- Modify samples in-place in the tap callback
- Must implement 10-band biquad IIR filters using `vDSP_biquad`
- No pre-built AVAudioUnitEQ equivalent for taps
- Real-time thread safety critical (no Swift allocations)
- Must pre-compute filter coefficients matching Winamp frequencies

**Setup code pattern:**
```swift
func attachTap(to playerItem: AVPlayerItem) {
    var callbacks = MTAudioProcessingTapCallbacks(
        version: kMTAudioProcessingTapCallbacksVersion_0,
        clientInfo: Unmanaged.passUnretained(self).toOpaque(),
        init: tapInit, finalize: tapFinalize,
        prepare: tapPrepare, unprepare: tapUnprepare,
        process: tapProcess
    )
    var tap: Unmanaged<MTAudioProcessingTap>?
    MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks,
        kMTAudioProcessingTapCreationFlag_PreEffects, &tap)

    let params = AVMutableAudioMixInputParameters(
        track: playerItem.asset.tracks(withMediaType: .audio).first)
    params.audioTapProcessor = tap?.takeRetainedValue()

    let mix = AVMutableAudioMix()
    mix.inputParameters = [params]
    playerItem.audioMix = mix
}
```

**Key risks:**
- MTAudioProcessingTap is a C-level API with manual memory management
- Callback runs on real-time audio thread (no allocations, no locks, no Swift ARC)
- Must handle format changes mid-stream (HLS adaptive bitrate switches)
- Must pre-allocate all DSP buffers (mirrors VisualizerScratchBuffers pattern)

### Approach D: AVAudioEngine for HTTP Streams (Manual Streaming)

**Feasibility: 4/10 | Complexity: Extreme | NOT Recommended**

Replace AVPlayer with a custom streaming pipeline:
1. URLSession downloads stream data (push model)
2. Find frame headers (MP3 sync words, AAC ADTS headers)
3. Decode to PCM using AudioConverterRef
4. Buffer in ring buffer
5. Feed AVAudioPlayerNode (pull model)

**Problems:**
- Push-pull impedance mismatch requires complex ring buffer
- Must handle all audio codecs (MP3, AAC, OGG Vorbis)
- Must handle HLS adaptive streaming with manifest parsing
- Must handle ICY metadata extraction manually
- Essentially re-implementing AVPlayer from scratch
- Fragile, error-prone, months of work

### Approach E: Third-Party Libraries (AudioKit / AudioStreamer)

**Feasibility: 9/10 | Complexity: Medium | Worth Investigating**

Libraries like AudioKit wrap the complexity of feeding streams into AVAudioEngine.

**Pros:** Pre-built stream→engine pipeline, EQ and visualization "for free"
**Cons:** New dependency, potential maintenance burden, may not support all stream types

**Not recommended for MacAmp** due to the project's preference for minimal dependencies (only ZIPFoundation currently).

### Approach F: Core Audio HAL / AUAudioUnit

**Feasibility: 3/10 | Complexity: Extreme | NOT Recommended**

System-level audio interception. Requires audio server plugins or system extensions. Overkill for app-level playback.

---

## 4. Reference: How Winamp and Webamp Handle This

### Winamp (Windows)
Uses a **unified pipeline**. ALL audio (local files AND network streams) is decoded to PCM first, then passed through:
1. Visualization plugins (vis_*.dll)
2. DSP/EQ plugins (dsp_*.dll)
3. Output plugins (out_*.dll)

The key insight: Winamp decodes everything to PCM before processing. The EQ never sees "a stream" vs "a file" - it only sees PCM samples.

### Webamp (JavaScript)
Uses Web Audio API with a unified graph:
```
MediaElementSource (<audio>) -> BiquadFilterNode (EQ) -> AnalyserNode (Vis) -> Destination
```

Web Audio API allows connecting ANY audio source (including streaming `<audio>` elements) to filter and analyzer nodes. This is the architecture AVFoundation lacks - there's no equivalent of connecting AVPlayer to AVAudioEngine nodes.

---

## 5. Feasibility Matrix

| Approach | Volume | EQ | Visualization | Feasibility | Complexity | Recommendation |
|----------|--------|----|----|-------------|------------|----------------|
| A: AVPlayer.volume | YES | NO | NO | 10/10 | Low | Phase 1 |
| B: Disable EQ UI | N/A | INDICATED | N/A | 10/10 | Low | Phase 1 |
| C: MTAudioProcessingTap (read) | NO | NO | YES | 6-7/10 | High | Phase 2 (requires pipeline refactor) |
| C: MTAudioProcessingTap (write) | NO | YES | YES | 3-5/10 | Very High | Phase 3 (optional) |
| D: Manual AVAudioEngine streaming | YES | YES | YES | 4/10 | Extreme | NOT recommended |
| E: Third-party (AudioKit) | YES | YES | YES | 9/10 | Medium | NOT recommended (dependency) |
| F: Core Audio HAL | YES | YES | YES | 3/10 | Extreme | NOT recommended |

---

## 6. Recommended Phased Approach

### Phase 1: Volume Control + Capability Flags (Immediate, Low Risk)
1. Add `volume` property to StreamPlayer synced to `player.volume`
2. Route volume through PlaybackCoordinator to active backend (Oracle-recommended Option B)
3. Add capability flags to PlaybackCoordinator (`supportsEQ`, `supportsBalance`, `supportsVisualizer`)
4. Grey out / indicate EQ is unavailable during stream playback
5. Disable balance slider during stream playback (no AVPlayer .pan property)
6. Persist stream volume using same UserDefaults pattern

### Phase 2: Stream Visualization via MTAudioProcessingTap (Medium-High Risk)
**Prerequisite:** Refactor VisualizerPipeline to eliminate allocations in callback path (lines 493, 509, 518)
1. Make VisualizerPipeline callback zero-allocation (pre-allocated buffers, no Task dispatch)
2. Implement MTAudioProcessingTap READ-ONLY on StreamPlayer's AVPlayerItem
3. Extract PCM samples in tap callback (pre-allocated buffers)
4. Feed extracted data to VisualizerPipeline for spectrum/waveform display
5. Reroute VisualizerView playback state check (line 74) to include stream playback
6. Handle format changes for HLS adaptive bitrate (reinitialize in tapPrepare)

### Phase 3: Stream EQ via MTAudioProcessingTap (Very High Risk, Optional)
1. Implement 10-band biquad IIR filters using vDSP_biquad
2. Pre-compute filter coefficients for Winamp frequency bands (approximate match to AVAudioUnitEQ)
3. Modify audio samples in-place in tap callback
4. Must be zero-allocation on audio thread
5. Handle ABR format changes (reinitialize filter state in tapPrepare)
6. Significant testing required for audio quality

---

## 7. Oracle Review Answers (gpt-5.3-codex, xhigh reasoning)

**Grade: B+** — Core diagnosis correct, feasibility scores needed recalibration.

### Q1: MTAudioProcessingTap deprecation status?
**NOT deprecated.** Still present in macOS 15+ SDK headers (`MediaToolbox/MTAudioProcessingTap.h`). No replacement API announced. Safe to use for Phases 2-3.

### Q2: HLS adaptive bitrate switching + MTAudioProcessingTap?
**Yes, causes problems.** ABR switches trigger `tapUnprepare` → `tapPrepare` cycles (format change). Must handle gracefully by reinitializing DSP buffers in `tapPrepare`. Pre-allocate for worst-case format (48kHz stereo float32).

### Q3: AVPlayer balance/pan without MTAudioProcessingTap?
**No simpler way.** AVPlayer has no `.pan` property. Balance requires either MTAudioProcessingTap DSP (channel gain manipulation) or accepting the limitation. **Phase 1 should explicitly disable the balance slider during stream playback.**

### Q4: Volume routing — PlaybackCoordinator vs AudioPlayer.volume didSet?
**PlaybackCoordinator (Option B) recommended.** Cleaner separation of concerns. AudioPlayer shouldn't need to know about StreamPlayer. The coordinator already manages backend switching — it should also manage volume/balance propagation.

### Q5: vDSP_biquad vs AVAudioUnitEQ filter curves?
**Approximate match, not exact.** vDSP_biquad implements standard IIR biquad filters. AVAudioUnitEQ may use proprietary filter curves or oversampling. Perceptually close enough for Winamp-style EQ, but not bit-identical.

### Additional Oracle Corrections

**Feasibility recalibration:**
| Original | Corrected | Reason |
|----------|-----------|--------|
| Tap-read visualization: 9/10 | **6-7/10** | VisualizerPipeline allocates in callback path (lines 493, 509), dispatches Task per buffer (line 518) — incompatible with real-time tap constraints. Must refactor pipeline first. |
| Tap-write EQ: 6/10 | **3-5/10** | Custom biquad implementation + zero-allocation constraint + format change handling = very high complexity. |

**Additional findings:**
1. **VisualizerView gates on `audioPlayer.isPlaying`** (line 74) — stream visualization won't render even with tap data unless this check is rerouted to include stream playback state.
2. **Phase 1 should include capability flags** (`supportsEQ`, `supportsBalance`, `supportsVisualizer`) on PlaybackCoordinator to cleanly gate UI features per backend.
3. **VisualizerPipeline refactoring prerequisite** — Before Phase 2, the pipeline's callback must be made zero-allocation. Current implementation violates real-time audio thread constraints.

---

## 8. Swift 6.2+ & macOS 26 Research Addendum (Gemini + Oracle)

> **Research conducted:** Gemini CLI deep research + Oracle (gpt-5.3-codex, xhigh reasoning) independent web research. Both reviewed for convergence.

### Confirmed: No Direct AVPlayer → AVAudioEngine Bridge

Both Gemini and Oracle independently confirm: **No new API exists in macOS 15 or macOS 26 to directly bridge AVPlayer output into AVAudioEngine.** They remain separate audio domains. `AVAudioSourceNode` cannot pull from AVPlayer. `AVAudioSinkNode` cannot capture AVPlayer output. No `AVPlayer.outputNode` property exists.

### NEW Approach G: "Loopback Bridge" — Tap → Ring Buffer → AVAudioSourceNode → AVAudioEngine

**Both Gemini and Oracle converged on this as the most promising new architecture for full stream EQ + visualization.** This was not in our original research.

```
AVPlayer → MTAudioProcessingTap (extract PCM) → Lock-Free Ring Buffer → AVAudioSourceNode → AVAudioEngine
                                                                                                    |
                                                                              AVAudioUnitEQ (built-in, no custom biquads!)
                                                                                                    |
                                                                              MainMixerNode → [installTap for Viz] → Output
```

**Key insight:** Once stream audio is inside AVAudioEngine via AVAudioSourceNode, you get the EXISTING `AVAudioUnitEQ` and visualization tap for free. No custom vDSP_biquad implementation needed. This eliminates Phase 3's "very high risk" entirely.

**Feasibility:** Oracle rates **5-6.5/10**, Gemini more optimistic. Consensus: **5.5-6.5/10**

**Technical challenges:**
- Clock sync between tap thread and render thread (underrun/overrun handling)
- Sample-rate/channel format drift on HLS ABR switches
- Real-time callback constraints on BOTH sides (tap + source node render block)
- Must mute AVPlayer's direct output to prevent double-render (hear audio twice)
- Lock-free ring buffer implementation using Swift Atomics
- Swift 6 Sendability friction — MTAudioProcessingTap types are explicitly `non-Sendable`

**Advantages over Phase 3 (tap-write EQ):**
- Uses existing `AVAudioUnitEQ` instead of custom biquad filters
- Uses existing `installTap` for visualization instead of custom FFT in tap callback
- Balance/pan available via engine nodes
- Single implementation gives EQ + visualization + balance (all three)

**Implementation pattern:**
```swift
// 1. MTAudioProcessingTap extracts PCM from AVPlayer
let tapProcess: MTAudioProcessingTapProcessCallback = { tap, numberFrames, flags, bufferList, ... in
    MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferList, ...)
    ringBuffer.write(bufferList)  // Lock-free write
}

// 2. AVAudioSourceNode pulls from ring buffer into AVAudioEngine
let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList in
    let framesRead = ringBuffer.read(into: audioBufferList, count: frameCount)
    if framesRead == 0 { /* fill silence to keep engine running */ }
    return noErr
}

// 3. Connect: sourceNode → eqNode → mainMixerNode → output
// 4. installTap on mainMixerNode for visualization (existing pattern)
```

### NEW Approach H: CoreAudio Process Taps (`AudioHardwareCreateProcessTap`)

**Oracle finding (Gemini disagrees on recommendation):**

- Available since **macOS 14.2**, improved in macOS 26 with `CATapDescription.bundleIDs`
- Backend-agnostic: captures audio from any process, including your own app
- Could provide visualization data without MTAudioProcessingTap
- Oracle rates **8/10** for visualization, **8.5/10** on macOS 26

**Gemini's counter-recommendation: Avoid.**
- Requires `com.apple.security.system-audio-capture` entitlement
- Designed for system-level capture (ScreenFlow, Zoom), not self-app EQ
- May face App Store rejection for a music player
- Overkill for capturing your own app's audio

**Consensus:** Process taps are interesting for visualization-only use cases but **not recommended for MacAmp** due to entitlement requirements and intended use case mismatch. MTAudioProcessingTap or the Loopback Bridge are better paths.

### Swift 6.2 Language Features Relevant to Audio

| Feature | Relevance | macOS Availability |
|---------|-----------|-------------------|
| `nonisolated(unsafe)` | Mark tap callback shared state to bypass actor isolation checks | macOS 15+ |
| `~Copyable` types | Zero-copy buffer wrappers for audio data transfer between tap and engine | macOS 15+ |
| `InlineArray` (SE-0453) | Stack-allocated fixed-size arrays for DSP scratch buffers (no malloc in callback) | **macOS 26+ only** |
| `Span` | Safe pointer-like access to contiguous memory without copying | **macOS 26+ only** |
| Typed throws | Better error handling in non-realtime audio control paths | macOS 15+ |
| `@unchecked Sendable` | Still needed for tap types (MTAudioProcessingTap is explicitly non-Sendable in Swift 6) | macOS 15+ |

**Impact on implementation:**
- `nonisolated(unsafe)` simplifies sharing ring buffer state between tap and render threads
- `~Copyable` prevents accidental buffer copies on the audio thread (compile-time safety)
- `InlineArray`/`Span` are powerful but macOS 26+ only — cannot use if targeting macOS 15+
- MTAudioProcessingTap C callback interop unchanged — still requires `UnsafeMutableRawPointer` contexts

### Accelerate / vDSP: No Material Changes

No new high-level DSP abstractions replacing `vDSP_biquad`. The `vDSP.Biquad<T>` Swift overlay remains stable. If using the Loopback Bridge (Approach G), custom biquad filters become unnecessary since `AVAudioUnitEQ` handles EQ natively.

### macOS 26 AVFoundation Changes (Not Helpful for Our Use Case)

| New API | Purpose | Relevance |
|---------|---------|-----------|
| `AVPlayer.observationEnabled` | Swift Observation support for AVPlayer | Nice for UI binding, doesn't help audio pipeline |
| `AVPlayer.networkResourcePriority` | Network scheduling | Operational, not DSP |
| `AUAudioMix` + `CNAssetSpatialAudioInfo` | Cinematic/spatial audio mixing | Specialized for spatial assets, not generic streams |
| `CATapDescription.bundleIDs` | Process tap targeting | See Approach H (not recommended) |

### Revised Feasibility Matrix (Post Swift 6.2 Research)

| Approach | Volume | EQ | Vis | Balance | Feasibility | Complexity | Recommendation |
|----------|--------|----|-----|---------|-------------|------------|----------------|
| A: AVPlayer.volume | YES | NO | NO | NO | 10/10 | Low | **Phase 1** |
| B: Disable EQ/Balance UI | N/A | INDICATED | N/A | INDICATED | 10/10 | Low | **Phase 1** |
| C: MTAudioProcessingTap (read) | NO | NO | YES | NO | 6-7/10 | High | Phase 2 alt |
| C: MTAudioProcessingTap (write) | NO | YES | YES | NO | 3-5/10 | Very High | Superseded by G |
| **G: Loopback Bridge (NEW)** | **YES** | **YES** | **YES** | **YES** | **5.5-6.5/10** | **High** | **Phase 2 (recommended)** |
| H: CoreAudio Process Tap | NO | NO | YES | NO | 8/10 | Medium | Not recommended (entitlement) |
| D: Manual AVAudioEngine streaming | YES | YES | YES | YES | 4/10 | Extreme | NOT recommended |
| E: Third-party (AudioKit) | YES | YES | YES | YES | 9/10 | Medium | NOT recommended (dependency) |

### Revised Phased Approach

**Phase 1** (unchanged): Volume + capability flags + disable EQ/balance during streams

**Phase 2** (revised): **Loopback Bridge** instead of separate visualization-only tap
- Implement MTAudioProcessingTap to extract PCM from AVPlayer
- Implement lock-free ring buffer (Swift Atomics)
- Feed AVAudioSourceNode → existing AVAudioEngine graph
- Get EQ + visualization + balance ALL working through existing engine infrastructure
- Mute AVPlayer direct output to prevent double-render
- Handle ABR format changes gracefully

**Phase 3** (eliminated): No longer needed — Loopback Bridge gives EQ via built-in `AVAudioUnitEQ`

### Open Questions for Planning

1. Should the Loopback Bridge mute AVPlayer via `player.volume = 0` or `player.isMuted = true`? (Muting may affect tap behavior)
2. What ring buffer size is optimal? (Must balance latency vs underrun risk)
3. Should we prototype the ring buffer independently before integrating with audio pipeline?
4. Does MacAmp target macOS 15+ only? (Determines if `InlineArray`/`Span` are available)

---

## 9. Sources

- **Codebase analysis:** AudioPlayer.swift, StreamPlayer.swift, PlaybackCoordinator.swift, VisualizerPipeline.swift, VideoPlaybackController.swift, WinampMainWindow.swift, WinampEqualizerWindow.swift
- **Documentation:** docs/MACAMP_ARCHITECTURE_GUIDE.md, docs/IMPLEMENTATION_PATTERNS.md, docs/SPRITE_SYSTEM_COMPLETE.md
- **Project knowledge:** BUILDING_RETRO_MACOS_APPS_SKILL.md (Dual-Backend Pattern, section lines 92-148)
- **Gemini research (round 1):** MTAudioProcessingTap feasibility, AVPlayer volume reliability, Winamp/webamp architecture comparison
- **Gemini research (round 2):** Swift 6.2+ audio capabilities, Loopback Bridge architecture, CoreAudio process taps, InlineArray/~Copyable for real-time audio
- **Oracle review (round 1):** gpt-5.3-codex xhigh — feasibility recalibration, capability flags recommendation
- **Oracle review (round 2):** gpt-5.3-codex xhigh — CoreAudio process taps (macOS 14.2+), Loopback Bridge feasibility (5-6.5/10), Swift 6.2 Sendability analysis, revised feasibility matrix
- **Apple documentation:** AVFoundation, MediaToolbox (MTAudioProcessingTap), Accelerate (vDSP), CoreAudio (AudioHardwareTapping)
- **Apple SDK headers (Xcode 26):** AVPlayer.h, AVAudioMix.h, MTAudioProcessingTap.h, AVAudioSourceNode.h, AVAudioSinkNode.h, AudioHardwareTapping.h, CATapDescription.h
- **Swift Evolution:** SE-0453 (InlineArray), SE-0466 (default actor isolation), SE-0412 (strict concurrency)
- **WWDC 2025:** Session 251 (audio recording capabilities), Session 268 (AVFoundation metrics)
