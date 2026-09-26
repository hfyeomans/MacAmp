# Plan: Video Audio Engine Routing

> **Status:** PLANNED — Sprint S3, Wave S3-2 (sequential after S3-1 merged)
> **Branch:** `feat/video-audio-engine-routing`
> **Spike branch:** `spike/vaer-av-drift-measurement` (throwaway)
> **PR target:** PR #C
> **Predecessors:** `mainwindow-visualizer-isolation` + `stream-pause-tail` merged
> **Updated:** 2026-04-27

---

## 1. Problem Statement

Video files (mp4/mov/m4v/avi) currently route audio directly from `AVPlayer` to system hardware, bypassing `AVAudioEngine` entirely. Concrete user-visible failures:

1. **No EQ on video.** The 10-band `AVAudioUnitEQ` does not process video audio. EQ presets, manual band adjustments, and EQ on/off all silently no-op for video tracks.
2. **No visualizer on video.** `snapshotButterchurnFrame()` returns nil when `currentMediaType == .video` (`AudioPlayer.swift:633`), and the visualizer tap is removed when switching from audio to video (`AudioPlayer.swift:347-349`). Spectrum analyzer and oscilloscope are dark for the entire video track.
3. **No balance control for video.** `AudioPlayer.balance` only routes through `playerNode.pan` and `streamSourceNode.pan`. Video's `AVPlayer.volume` setter exists, but pan does not — the balance slider is silently ignored.
4. **Inconsistent UI affordances.** `playbackCoordinator.supportsAudioProcessing` returns true for video sessions (because `isStreamBackendActive` is false), so the EQ window and balance slider are NOT dimmed, but they have no audible effect. Users get a UI lie.

**Root cause:** Video has its own audio path (`VideoPlaybackController.player.volume`) that does not pass through the engine graph. The unified-audio-pipeline work (T7) unified local files and streams through `AVAudioEngine`, but explicitly left video for a future task. This is that task.

---

## 2. Non-Goals

This task is intentionally scoped narrow:

- **NOT supporting AirPlay routing for video.** AirPlay (PR #69) abandoned in-app triggers; system Control Center still routes the engine output. Video's engine path will inherit that behaviour for free, but no AirPlay-specific work is in scope.
- **NOT supporting non-local video sources.** HTTP/HLS video URLs are out of scope. `AudioPlayer.detectMediaType` only reaches video for the four local-file extensions; that surface stays unchanged. (Note: MTAudioProcessingTap is documented to fail for streaming AVPlayerItems per Apple QA1716; staying with local-file URLs is what makes this approach viable.)
- **NOT replacing AVPlayer for rendering.** AVPlayer continues to handle codec negotiation, frame timing, and visual presentation. We only intercept its decoded audio.
- **NOT implementing the post-S3 Structure Sprint moves.** `VideoPlaybackController.swift` stays in `Audio/`. New files (`VideoAudioTap.swift`, `AudioEngineConfigurationObserver.swift`) land in `Audio/` per the post-S3 placement policy.
- **NOT extending `supportsAudioProcessing` semantics beyond a single video-bridge fork.** No new capability protocol hierarchy.
- **NOT adding new MediaType cases.** `MediaType` stays `.audio | .video`. The unified routing is an internal concern of the video path.
- **NOT touching the seek state machine in `AudioPlayer`.** Video seek already works; we only ensure the audio bridge tracks AVPlayer seeks.
- **NOT a refactor of `AudioPlayer` or `AudioEngineController`.** Pure additive surface.

---

## 3. Pre-Decomposition Gate Checklist

This task is feature work with a small additive decomposition (two new files). The gate still applies:

- [x] **Problem statement written** — §1 above. Concrete failure modes: no EQ, no visualizer, no balance, inconsistent dimming.
- [x] **Non-goals listed** — §2 above.
- [x] **Principles contract approved** —
    - Principle 1 (Problem-First): yes, three concrete user-visible failures.
    - Principle 3 (State Ownership): tap callbacks own real-time state; ring buffer is single source of truth for video audio samples; AudioEngineController stays sole owner of the engine graph.
    - Principle 4 (AHA / Rule of Three): the existing `streamSourceNode + LockFreeRingBuffer` pattern is the second occurrence (after streams). Per the safety-invariant exception (FFI / threading), we ARE allowed to extract a thin shared helper at N=2 — but we will NOT, because the call sites differ in producer (decode queue vs MTAudioProcessingTap C callback) and lifetime. Keep them as parallel implementations sharing only `LockFreeRingBuffer` + `AVAudioSourceNode` types. Re-evaluate at N=3.
    - Principle 5 (API Surface): `AudioEngineController` gets new `activateVideoBridge(ringBuffer:sampleRate:)` and `deactivateVideoBridge()` methods (parallel to stream bridge). `LockFreeRingBuffer` and `AVAudioSourceNode` already have appropriate visibility — no widening needed. `VideoPlaybackController` gets a small additive parameter on `loadVideo`. No `private → internal` widening.
    - Principle 6 (No Pass-Through): `VideoAudioTap` does real work (PCM extraction, format conversion if needed, ring buffer write). `AudioEngineConfigurationObserver` does real work (NotificationCenter observation, debounce, fan-out to AudioEngineController). Neither is a pass-through.
    - Principle 7 (ADR + Kill Switch): §16 below defines kill criteria; §18 lists rollback steps.
- [x] **Responsibility map exists** —
    - `VideoAudioTap` owns: MTAudioProcessingTap lifecycle, C callbacks, ring buffer writes, format detection, last-callback timestamp (for stall detection).
    - `VideoPlaybackController` owns: AVPlayer lifecycle, audioMix attachment, AVPlayer.volume mute/unmute fallback, callbacks for time updates.
    - `AudioEngineController` owns: engine graph wiring including new `videoSourceNode`, plus engine config change observer registration.
    - `AudioEngineConfigurationObserver` owns: notification subscription, debouncing, fan-out via callbacks (no engine state).
    - `AudioPlayer` owns: video routing decisions (which bridge to activate), tap-failure fallback policy, capability reporting (`isVideoBridgeActive`).
    - `PlaybackCoordinator` owns: capability surface (`supportsAudioProcessing` for video sessions).
- [x] **Complexity assessed** — Cognitive complexity is concentrated in (a) MTAudioProcessingTap C callbacks (high cognitive density per line, low LOC) and (b) the engine config observer recovery flow (medium cognitive). Both are isolated to single files. No high-cognitive-high-LOC mixing.
- [x] **Candidate split scored** — see §4 (Architecture).
- [x] **Public/internal API delta listed** — see §13.
- [x] **Stop criteria defined** — §16.

**Hard gate cleared.**

---

## 4. Architecture Overview

### Current (3 paths)

```
Local audio → AVAudioPlayerNode → EQ → mixer → output       (EQ, viz, balance work)
Streams     → decode → ring → AVAudioSourceNode → EQ → mixer → output   (EQ, viz, balance work)
Video       → AVPlayer → speakers (direct)                  (NO EQ, NO viz, NO balance)
```

### Target

```
Local audio → AVAudioPlayerNode → EQ → mixer → output                          (unchanged)
Streams     → decode → ring → AVAudioSourceNode (streamSourceNode) → EQ → mixer → output  (unchanged)
Video audio → MTAudioProcessingTap → ring → AVAudioSourceNode (videoSourceNode) → EQ → mixer → output  (NEW)
Video frames → AVPlayer (volume=0) → screen                                    (unchanged)
```

`videoSourceNode` and `streamSourceNode` are siblings — different ring buffers, different producers, but identical engine-side topology. They are mutually exclusive: only one active at a time, gated by `isBridgeActive` style flags. Local-file path (`playerNode`) remains a third mutually-exclusive option.

### Three-bridge state machine

`AudioEngineController` will own three flags and wire them as exclusive:

- `isBridgeActive` (existing, stream)
- `isVideoBridgeActive` (NEW)
- Implicit: `playerNode` is the active path when neither bridge flag is true.

Activating the video bridge deactivates the stream bridge (and vice versa). Activating the local-file path deactivates both bridges (`rewireForFile()` already drops the stream bridge — extend it to also drop the video bridge).

---

## 5. Phase 0: A/V Sync Spike (Throwaway Branch)

> **Goal:** Empirically measure A/V drift on the bare-minimum tap → ring → engine path before committing to a sync strategy. Apple docs on `AVPlayer.masterClock`, pre-roll, and `AVSynchronizedLayer` are thin; ground-truth measurement beats more synthesized research.

### 5.1 Branch Strategy

- Branch name: `spike/vaer-av-drift-measurement`
- Branched from: `main` HEAD at the time the spike runs (after S3-1 merged so `AudioEngineController` reflects current state).
- **Throwaway.** Never merged. Findings go into `tasks/video-audio-engine-routing/research.md` under a new "Phase 0 — Spike Results" section. Branch is deleted after measurement.
- All sync-strategy code in the implementation phases is rewritten cleanly on `feat/video-audio-engine-routing` from main — the spike is a measurement tool, not a code source.

### 5.2 Test Corpus

Five sample files, all stored in `~/Movies/macamp-vaer-spike/` (NOT committed):

| # | Container | Audio sample rate | Audio channels | Duration | Source |
|---|-----------|-------------------|----------------|----------|--------|
| 1 | mp4 (h264) | 44.1 kHz | stereo | ~3 min | Public-domain music video |
| 2 | mp4 (h264) | 48.0 kHz | stereo | ~3 min | Public-domain trailer |
| 3 | mov (h264) | 48.0 kHz | stereo | ~3 min | iPhone-recorded sample |
| 4 | m4v (h264) | 44.1 kHz | stereo | ~3 min | Apple sample asset |
| 5 | mp4 (h264) | 48.0 kHz | 5.1 → downmixed to stereo at tap | ~3 min | Re-encoded sample |

**Selection criteria:** mix of 44.1/48 kHz to validate that AudioConverter handles sample-rate mismatch, and one 5.1 source to confirm the tap downmix path. All files have a sharp **audio transient** (hand-clap or door-slam) and a **synchronized visual frame** (white frame inserted at clap).

If clean public-domain files cannot be sourced, the spike author records three-second clapperboard-style files locally, sufficient for the measurement harness.

### 5.3 Measurement Protocol

For each file, run a **5-minute playback** with the tap → ring → engine path active. The 5-minute window matches the production verification target (§14.1) — a 60-second run can hide slow-growing drift that would surface for a real user. If a file is shorter than 5 minutes, loop it back-to-back to fill the window.

**Drift metric:** offset between
- the AVPlayer time at which a tagged video frame is presented (use `AVPlayerItemVideoOutput.copyPixelBuffer(forItemTime:)` and the marker frame's timestamp)
- and the host time at which the corresponding audio peak passes through the ring-buffer read head (record host time when `LockFreeRingBuffer.read` returns the chunk containing the matching sample, identified by the tap's input PTS).

Capture quantities per playback:

1. **Initial offset** (samples written by tap before engine starts pulling) — proxy for pre-roll latency.
2. **Sustained drift sampled at 5 s, 30 s, 60 s, 120 s, 240 s, 300 s** — does it grow, shrink, or stay flat over the full window?
3. **Peak drift over the 5-minute window** — worst-case observation, not just endpoint.
4. **Audible-perception sanity check** — author plays the file in headphones and reports clap-vs-flash desync as one of: "imperceptible", "noticeable but tolerable", "clearly desynced".

The spike PASSES a file only if (a) sustained drift is below threshold AND (b) peak drift over the 5-minute window also stays below the same threshold. Single-spike outliers (e.g., one 80 ms spike at 200 s on an otherwise 12 ms-stable run) count against the file.

**Tooling:** lightweight Swift test target in the spike branch only; outputs CSV + console summary. No Instruments traces required.

### 5.4 Outcome Decision Tree

After all five files measured (5-minute runs each), the decision is binary per file. ALL five files must pass at the same threshold tier; mixed outcomes escalate to the next tier:

| Sustained AND peak drift (worst file) | Strategy chosen for Phase 4 | Action |
|---|---|---|
| < 30 ms across all 5 files | **None.** Ship without a sync mechanism. | Skip Phase 4 entirely. |
| 30–100 ms on any file | **`AVPlayer.masterClock`** set to engine output device clock; re-run the spike with masterClock enabled | Path A only proceeds if rerun shows < 30 ms across all 5 files. |
| 30–100 ms after masterClock rerun | **Pre-roll buffering**; re-run the spike again with pre-roll enabled | Path B only proceeds if rerun shows < 30 ms across all 5 files. |
| > 100 ms after both masterClock and pre-roll re-runs | **KILL SWITCH.** Cancel task. | Revert spike, do NOT open `feat/video-audio-engine-routing`. Document lessons. |

The decision is binary and recorded in research.md before opening the implementation branch. Plan + todo are re-read after the spike completes (the relevant Phase 4 section is annotated "TBD pending Phase 0").

There is no "ship 2 of 3 capabilities" partial-success path at the spike stage. If the engine bridge cannot reach the < 30 ms target, video does not get the engine path, and the task is killed. Capability-subset fallback only applies during late implementation if a SPECIFIC sub-capability (e.g., balance) misbehaves while EQ + visualizer are fine — see §16 "Scope-reduction fallback" for that distinct, late-stage case.

### 5.5 Spike Hygiene

- No production tests added to the main test plan.
- Spike branch CSV outputs and any sample files are gitignored (added to a local `.gitignore` on the spike branch only — not pushed).
- After findings written to research.md, run `git branch -D spike/vaer-av-drift-measurement` locally. Remote is never pushed.

---

## 6. Phase 1: Engine Configuration Change Observer

This phase ships independently of the video audio path — it's a missing piece from the AirPlay PR (#69) that benefits the existing local-file and stream paths regardless of video. It MUST land before Phase 3 because the video bridge needs the same recovery hook.

### 6.1 New File: `Audio/AudioEngineConfigurationObserver.swift`

**Layer:** Mechanism (notification observer with no domain state)

**Responsibilities:**

- Subscribe to `AVAudioEngine.configurationChangeNotification` for a specific engine instance.
- Debounce bursts (route changes can fire 2–3 notifications in <100 ms).
- Fan out to `onWillReconfigure` and `onDidReconfigure` callbacks on `@MainActor`.
- Tear down on deinit.

**API:**

```swift
@MainActor
final class AudioEngineConfigurationObserver {
    init(engine: AVAudioEngine)
    var onWillReconfigure: (@MainActor () -> Void)?
    var onDidReconfigure: (@MainActor () -> Void)?
    func start()
    func stop()
    deinit  // implicit cleanup
}
```

**Implementation notes:**

- Notification fires on arbitrary thread; bridge to `@MainActor` via `Task { @MainActor in ... }`.
- Debounce window: 150 ms (collect any same-event bursts, fire once).
- Generation counter: increment on each notification; only the latest `Task` fires the `onDid` callback (cancelled tasks early-return).
- Observer token stored in `private var observerToken: NSObjectProtocol?`.
- `start()` is idempotent.

### 6.2 Wire into `AudioEngineController.swift`

Add as `@ObservationIgnored private let configObserver: AudioEngineConfigurationObserver`. Initialize in `setupEngine()`. Wire `onWillReconfigure` / `onDidReconfigure` callbacks to internal handlers `handleEngineWillReconfigure()` and `handleEngineDidReconfigure()`.

`handleEngineWillReconfigure()` flow:

1. Fire `onEngineWillReconfigure?(snapshot)` callback (AudioPlayer arms `seekGuardActive` and `isHandlingCompletion` per the AirPlay plan §1.3 in `tasks/done/airplay-integration/plan.md`).
2. Capture `engine.isRunning`, `playerNode.isPlaying`, `isBridgeActive`, `isVideoBridgeActive`.
3. Capture current playback time so AudioPlayer can resume.

`handleEngineDidReconfigure()` flow:

1. If engine was running, restart with the new output device format.
2. If `isBridgeActive`: disconnect `streamSourceNode`, reconnect with refreshed graph format.
3. If `isVideoBridgeActive`: disconnect `videoSourceNode`, reconnect with refreshed graph format.
4. Verify `mixer → output` connection.
5. Fire `onEngineDidReconfigure?()` (AudioPlayer re-applies volume/balance, seeks to saved position, refreshes stream workgroup via PlaybackCoordinator).

### 6.3 Callbacks Surfaced from AudioEngineController

```swift
struct PreReconfigureSnapshot: Sendable {
    let wasPlaying: Bool       // best-effort; AudioPlayer overrides — see §6.3 contract note
    let currentTime: Double    // best-effort; AudioPlayer overrides — see §6.3 contract note
    let wasStreamBridge: Bool  // authoritative (MacAmp-owned)
    let wasVideoBridge: Bool   // authoritative (MacAmp-owned, false until Phase 3)
}

var onEngineWillReconfigure: ((_ snapshot: PreReconfigureSnapshot) -> Void)?
var onEngineDidReconfigure: (() -> Void)?
```

AudioPlayer wires these in init. PlaybackCoordinator subscribes to an AudioPlayer-level `onEngineReconfigured` to refresh the stream workgroup (matches the design in `tasks/done/airplay-integration/plan.md` §1.3).

**Contract note — split state ownership** (added 2026-04-30 after manual verification surfaced an AirPlay-resume bug, commit `3267091`):

The `wasPlaying` and `currentTime` fields in `PreReconfigureSnapshot` are **best-effort placeholders**, not authoritative. The system posts `AVAudioEngineConfigurationChange` *after* auto-stopping the engine — by the time `handleEngineWillReconfigure` runs, `playerNode.isPlaying` is already false and `playerNode.lastRenderTime` is nil (so `readPlayerNodeCurrentTime` returns nil and the snapshot's `currentTime` falls back to 0).

AudioPlayer is the authoritative source for those two fields and **MUST override them** in its `handleEngineWillReconfigure` handler:
- `currentTime`: use `self.currentTime` (updated by the progress timer ~100 ms before the reconfigure — accurate to within one tick).
- `wasPlaying`: use `self.isPlaying` (transition-managed; reflects user intent independent of engine running state).

The bridge flags (`wasStreamBridge`, `wasVideoBridge`) come from MacAmp-owned engine state and remain accurate at notification time — they are NOT overridden by AudioPlayer.

**Cancellation contract** (added 2026-04-30, commit `fabe5e2`):

A user action (`play`/`pause`/`stop`/`seek`/`playTrack`) within the ~150 ms gap between `onWill` and `onDid` would otherwise allow the stale `onDid` callback to override the user's new intent (e.g. user pauses → `onDid` reschedules and resumes). AudioPlayer therefore exposes a private `cancelPendingReconfigure()` helper that nils the stored snapshot, called at the start of every user-intent entry point. `handleEngineDidReconfigure` early-returns when the snapshot is nil, so the user-intent paths are the cancel hook.

**Phase 3 refactor opportunity** — the split state ownership is documented but the type still carries unreliable engine-derived fields. A cleaner long-term shape narrows `PreReconfigureSnapshot` to MacAmp-owned bridge facts only, with AudioPlayer carrying its own play-state/time separately:

```swift
// Future shape (Phase 3 candidate, when wasVideoBridge becomes a real flag):
struct PreReconfigureSnapshot: Sendable {
    let wasStreamBridge: Bool
    let wasVideoBridge: Bool
}
```

This is deferred to Phase 3 because: (a) it's a refactor for clarity, not a correctness fix; (b) the override pattern is tested and documented; (c) folding into Phase 3's video-bridge wiring keeps the type churn in one place.

### 6.4 Explicit Seek-Guard / Completion-Filter Coordination

The AudioPlayer state machine has three interlocking guards (`AudioPlayer.swift:48-50`):

- `currentSeekID: UUID` — identifies the current seek operation; completions for older IDs are ignored.
- `seekGuardActive: Bool` — blocks `onPlaybackEnded` for nil-seekID completions during transient state changes.
- `isHandlingCompletion: Bool` — re-entrancy guard for the completion handler.

`scheduleSegment` completion handlers carry their seekID at scheduling time. Engine reconfiguration (stop + restart + reschedule) WILL fire a `playerNode` completion for the previously scheduled segment — that completion carries the OLD seekID. Without explicit handling, this would trigger a spurious "track ended → advance to next track".

**`onWillReconfigure` AudioPlayer handler (explicit step list):**

1. `let savedSeekID = currentSeekID`.
2. `let savedTime = currentTime` (captured before any state mutation).
3. `currentSeekID = UUID()` — bumps the ID so the impending playerNode completion (carrying `savedSeekID`) will be filtered by `shouldIgnoreCompletion`.
4. `seekGuardActive = true` — extra safety for nil-seekID completion paths.
5. `isHandlingCompletion = true` — prevents re-entrancy from the suppressed completion.
6. Snapshot returned from `engine` reflects `wasPlaying = isPlaying || isBridgeActive || engine.isVideoBridgeActive`.
7. Save `wasStreamBridge = isBridgeActive` and `wasVideoBridge = engine.isVideoBridgeActive`.

**`onDidReconfigure` AudioPlayer handler (explicit step list):**

1. Re-apply `engine.setVolume(volume)` and `engine.setBalance(balance)`.
2. If local audio path was active (snapshot `!wasStreamBridge && !wasVideoBridge` AND `audioFile != nil`):
    - **Always reschedule** from `savedTime` with the bumped `currentSeekID`, even if paused. Without this, a subsequent `play()` (which does NOT itself reschedule, see `AudioPlayer.swift:417-439`) would resume the now-detached previous segment.
    - **Branch on `wasPlaying`:**
        - If `wasPlaying`: resume immediately (`engine.playAudio()` + `engine.startProgressTimer()`).
        - If paused: do NOT call `playAudio()`. The reschedule alone primes the playerNode; the next user `play()` will start it. Restore `playbackState = .paused`.
3. If stream bridge was active: AVAudioSourceNode + ring buffer survived. Just refresh workgroup via `onEngineReconfigured` callback to PlaybackCoordinator.
4. If video bridge was active: AVAudioSourceNode + ring buffer survived. AVPlayer handles its own clock continuation. No additional resume needed (paused video stays paused via AVPlayer).
5. Schedule `seekGuardActive = false` after 100 ms (matches existing pattern at `AudioPlayer.swift:603`).
6. Schedule `isHandlingCompletion = false` after 200 ms (matches existing pattern at `AudioPlayer.swift:673`).

**Why bump `currentSeekID` first:** the AudioEngineController stops the engine (or AVAudioSourceNode formats become stale) DURING reconfiguration. Whatever scheduling existed will fire a completion handler with the OLD seekID. By bumping `currentSeekID` BEFORE the engine stop happens, `shouldIgnoreCompletion(from: savedSeekID)` will return true when that stale completion arrives. This is the same pattern AudioPlayer already uses for explicit `seek()` and `playTrack()` (see lines 317, 377, 595).

The 100 ms / 200 ms delays match the existing seek/completion timings exactly. Do NOT shorten them — the AudioEngine restart can take longer than expected on the host's first play after device switch.

### 6.4 Manual Verification (Phase 1 only)

Engine config change is hard to unit test deterministically (depends on Core Audio HAL). Add a manual verification checklist to `todo.md` Phase 1:

- Local file playing → switch output via Control Center → audio resumes within ~1 s, EQ still active, no crash.
- Stream playing → switch output → audio resumes within ~1 s, ICY metadata still flowing.
- Video playing (after Phase 6 lands) → switch output → video keeps playing, audio resumes.

---

## 7. Phase 2: MTAudioProcessingTap Implementation

### 7.1 New File: `Audio/VideoAudioTap.swift`

**Layer:** Mechanism (FFI + real-time audio path)

**Responsibilities:**

- Create + configure an `MTAudioProcessingTap` with C-convention callbacks.
- Wire the tap into an `AVMutableAudioMix` for an `AVPlayerItem`.
- Pull PCM via `MTAudioProcessingTapGetSourceAudio()` in `tapProcess`.
- Convert to Float32 interleaved if source format differs (use `AudioConverter` when needed).
- Write to `LockFreeRingBuffer`.
- Track `lastCallbackHostTime` (atomic) for stall detection.
- Tear down cleanly on `tapFinalize`.

### 7.2 Swift 6.2 + `@convention(c)` Compatibility

**Verified during plan writing (against research.md and `Audio/Streaming/StreamDecodePipeline.swift` patterns):**

- Swift 6.2 strict concurrency permits `@convention(c)` function values, but they may NOT capture context. Tap callbacks therefore pass an `UnsafeMutableRawPointer` "client info" pointer through `MTAudioProcessingTapCallbacks.clientInfo`, and unpack on entry.
- Client info is an `Unmanaged<VideoAudioTapContext>` (heap-allocated, retained for tap lifetime). Released in `tapFinalize`.
- `VideoAudioTapContext` is a `final class` declared `@unchecked Sendable` (queue-confined to the tap thread). It owns the ring-buffer reference (already `@unchecked Sendable`), the format descriptor, and the optional `AudioConverterRef`.
- Format detection: first call to `tapPrepare` provides the `AudioStreamBasicDescription`. If `mSampleRate` ≠ engine sample rate or non-stereo, allocate an `AudioConverter` (rare — ring buffer was deliberately format-agnostic and downstream graph reformats anyway, but a tap providing surround needs explicit downmix).
- All callbacks marked `@convention(c)`.

### 7.3 Tap Lifecycle

```swift
@MainActor
final class VideoAudioTap {
    init(ringBuffer: LockFreeRingBuffer, expectedSampleRate: Float64)
    func attach(to playerItem: AVPlayerItem) throws -> AVMutableAudioMix
    func detach()
    var lastCallbackHostTime: UInt64 { get }  // atomic, for stall detection
    deinit
}
```

`attach(to:)` builds:

1. `MTAudioProcessingTapCallbacks` struct populated with `tapPrepare/tapProcess/tapUnprepare/tapFinalize` `@convention(c)` functions.
2. `MTAudioProcessingTapCreate` with `kMTAudioProcessingTapCreationFlag_PostEffects` (post-AVPlayer's own audio effects, but pre-output).
3. `AVMutableAudioMixInputParameters` linked to the player item's first audio track.
4. `AVMutableAudioMix` with the input parameters.
5. Returns the audio mix; caller assigns to `playerItem.audioMix`.

`detach()` invalidates the tap, releases the `Unmanaged<Context>`. Caller must clear `playerItem.audioMix` separately.

### 7.4 Tap Callbacks (C-convention)

- **`tapPrepare(tap, maxFrames, processingFormat)`** — Capture `processingFormat`. If incompatible with the ring buffer's expected format, lazily build an `AudioConverter`. Set context's `isPrepared = true`.
- **`tapProcess(tap, framesToProcess, flags, bufferList, framesOut, flagsOut)`** —
    1. Call `MTAudioProcessingTapGetSourceAudio(tap, framesToProcess, bufferList, flagsOut, nil, framesOut)`.
    2. If converter present: run `AudioConverterFillComplexBuffer` from sourceBufferList → temporary ring-buffer-format buffer.
    3. Call `ringBuffer.write(from: ptr, frameCount: written)`.
    4. Update `lastCallbackHostTime` atomically.
    5. **Critical:** the bufferList must still contain audio when `tapProcess` returns — AVPlayer plays it. We do NOT zero it here; we only read it. AVPlayer's `volume = 0` (set in Phase 3) is what mutes the output, not silencing the buffer.
- **`tapUnprepare(tap)`** — Mark context's `isPrepared = false`. Tear down converter if any.
- **`tapFinalize(tap)`** — Release the `Unmanaged<Context>`.

### 7.5 Buffer-Format Edge Cases

- **Source mono:** convert to stereo via duplication (in converter ASBD, set output channels = 2; AudioConverter handles it).
- **Source 5.1+ surround:** explicit ASBD downmix to stereo; AudioConverter handles it with default mixer matrix.
- **Source non-Float32:** AudioConverter handles. Some video files have integer-PCM or compressed audio tracks at the tap layer; tap usually delivers decoded PCM, but format must be inspected.
- **Source rate mismatch:** AudioConverter resamples to the ring buffer's sample rate.

If `AudioConverterNew` fails (unsupported source format), Phase 5 fallback engages immediately.

---

## 8. Phase 3: Engine Source Node + Wiring

### 8.1 Add `videoSourceNode` to `AudioEngineController`

Mirror the existing stream-bridge pattern (`AudioEngineController.swift:32-34, 277-405`). Additions:

```swift
// Parallel to streamSourceNode
private var videoSourceNode: AVAudioSourceNode?
private var videoRingBuffer: LockFreeRingBuffer?
private(set) var isVideoBridgeActive: Bool = false

// Public API
func activateVideoBridge(ringBuffer: LockFreeRingBuffer, sampleRate: Float64)
func deactivateVideoBridge()

// Render block
private nonisolated static func makeVideoRenderBlock(ringBuffer: LockFreeRingBuffer)
    -> AVAudioSourceNodeRenderBlock
```

The render block can literally be the same as `makeStreamRenderBlock` — same signature, same body. **Per Principle 4 (AHA Rule of Three),** we do NOT extract a shared helper at N=2. Keep both inline. Re-evaluate only if a third source-node consumer appears (unlikely).

### 8.2 Mutual Exclusion Between Three Paths

Modify the three activation entry points so that activating any one path deactivates the other two:

- `rewireForFile(_:)`: deactivate stream bridge (already does), AND deactivate video bridge (NEW).
- `activateStreamBridge(...)`: stays as-is, but ALSO calls `deactivateVideoBridge()` first.
- `activateVideoBridge(...)`: calls `deactivateStreamBridge()` first; stops `playerNode` if running.

Volume/balance distribution: extend `setVolume` and `setBalance` to also forward to `videoSourceNode`:

```swift
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
```

### 8.3 Wire from AudioPlayer

`AudioPlayer.playTrack` already routes video tracks to `videoPlaybackController.loadVideo`. Modify the video branch (`AudioPlayer.swift:354-360`) to:

1. Build a `LockFreeRingBuffer` (capacity 4096, channels 2 — same defaults as stream bridge).
2. Create a `VideoAudioTap` referencing this ring.
3. Call `videoPlaybackController.loadVideo(url:autoPlay:audioTap:)` — extend the API to accept the tap and attach it BEFORE `play()`.
4. After successful tap attach, call `engine.activateVideoBridge(ringBuffer:sampleRate:)`.
5. Set `videoPlaybackController.player.volume = 0` to mute AVPlayer's direct audio.
6. Begin AVPlayer playback (which begins ring-buffer fill).

### 8.4 Tap Attach Ordering

CRITICAL ordering (validated during plan writing — this is a known footgun):

1. Create `AVPlayer` with the URL (in `loadVideo`).
2. Wait for `AVPlayerItem.status == .readyToPlay` (`load(.tracks, .duration)` async API). Required because the tap needs the audio track in the asset, only available after the asset loads.
3. Build `AVMutableAudioMix` via `VideoAudioTap.attach(to: playerItem)`.
4. Assign `playerItem.audioMix = mix`.
5. Set `player.volume = 0`.
6. Call `engine.activateVideoBridge(...)`.
7. `player.play()`.

If steps 2–4 fail (no audio track, e.g., silent video), Phase 5 fallback path: skip the bridge, leave `player.volume = 1`, and capability flags reflect "no audio processing".

### 8.5 Stop / Cleanup

`AudioPlayer.stop()` for video:

1. `videoPlaybackController.stop()` (which calls `cleanup()` internally — clears AVPlayer).
2. `engine.deactivateVideoBridge()`.
3. `videoAudioTap.detach()` and release.

Symmetric to `playTrack` activation.

### 8.6 Engine Idle During Video

Local-audio path stops the engine between tracks (line `audioEngine.stop()` in `rewireForFile`). For video, the engine must KEEP RUNNING because the source node pulls samples continuously. `activateVideoBridge` calls `startEngineIfNeeded()` after wiring. The engine remains running for the video's duration.

---

## 9. Phase 4: Sync Strategy Implementation (TBD per Phase 0)

This phase has three possible outcomes, decided by Phase 0 (§5.4):

### Path NONE — drift < 30 ms baseline

- No sync code added.
- This phase becomes a no-op.
- Document in research.md "Phase 0 Results" section that no sync was needed.

### Path A — `AVPlayer.masterClock`

In `VideoPlaybackController.loadVideo`, after creating the AVPlayer:

```swift
// Pseudocode — exact API resolved by spike on macOS 15.0
if let outputAU = audioEngineController.outputAudioUnit {
    var deviceClock: CMClock?
    // CMAudioDeviceClockCreate or AVAudioEngine.outputNode.audioUnit.deviceClock
    player.masterClock = deviceClock
}
```

The exact API depends on macOS version. The spike measurements determine the right call. If `masterClock` setup fails, fall back to Path NONE behaviour (don't crash; sync drift is non-fatal).

**Open question for spike:** verify which API yields a `CMClock` from the engine output unit on macOS 15+.

### Path B — Pre-roll buffering

In the `playTrack` video branch:

1. Activate video bridge.
2. Pre-roll: AVPlayer must be playing for the tap to fire. Set `player.rate = 0` then `player.play()`, watch for first `tapProcess` callback (via `lastCallbackHostTime` becoming non-zero), then wait 50 ms of additional samples to accumulate in the ring.
3. Set `player.rate = 1.0` to resume normal playback.

This is more invasive than Path A; only chosen if A fails. Implementation details deferred to post-spike; the spike author writes a 1-page sub-plan into research.md before coding Phase 4 Path B.

### Path KILL — drift > 100 ms with all strategies

Cancel task. See §16.

---

## 10. Phase 5: Tap Failure Fallback

### 10.1 Detection

`VideoAudioTap.lastCallbackHostTime` is updated atomically on every `tapProcess` call. A `MainActor` watchdog timer in `AudioPlayer` (or new `VideoTapWatchdog` if cleaner) checks every 250 ms:

- If `(now - lastCallbackHostTime) > 1000 ms` AND `videoPlaybackController.isPlaying` AND `engine.isVideoBridgeActive`: declare tap failure.

The 1-second threshold is conservative — `tapProcess` typically fires every 10–50 ms during playback. A 1-second gap is unambiguously a stall.

### 10.2 Fallback Sequence

On tap failure detection (must run on `@MainActor`, in this exact order):

1. **Cancel watchdog first** — `videoTapWatchdogTask?.cancel(); videoTapWatchdogTask = nil`. Critical: do this BEFORE any other step so a re-trigger on the next 250 ms tick doesn't compound the fallback work or cause a re-entrancy loop.
2. **Set fallback flag** — `videoTapFallbackActive = true`. Capability surface immediately reports false; EQ window dims.
3. **Log** — `AppLog.error(.audio, "Video audio tap stalled (last callback >1s ago) — restoring AVPlayer.volume fallback")`.
4. **Deactivate engine bridge** — `engine.deactivateVideoBridge()`. Engine returns to default playerNode wiring; `videoSourceNode` detached and released.
5. **Detach the tap and clear the audioMix** —
    - `videoPlaybackController.detachAudioTap()` (new `VideoPlaybackController` method that performs the next two steps internally):
        - `playerItem.audioMix = nil` (ESSENTIAL — without this, the failed tap remains attached to the player item; AVPlayer may still call into the dead tap).
        - `videoAudioTap.detach()` (invalidates the tap, releases the `Unmanaged<Context>`).
    - `videoAudioTap = nil` and `videoRingBuffer = nil` on AudioPlayer side.
6. **Restore AVPlayer volume** — `videoPlaybackController.player?.volume = audioPlayer.volume`. AVPlayer now plays its own audio directly, with the user's set volume.
7. **Reset transient flags** — clear any seek guards or completion-handler state set during the bridge teardown so subsequent video controls behave normally: `seekGuardActive = false`. Do NOT bump `currentSeekID` (no scheduled segment to invalidate; bridge had no playerNode involvement).
8. **Capability flag re-evaluation** — call `playbackCoordinator.objectWillChange.send()` is NOT required because `supportsAudioProcessing` is a computed @Observable getter that re-evaluates. Verify the EQ window updates by manual test (covered in todo Phase 5 manual checklist).
9. UI banner — explicitly **out of scope** for this task; just log. Tracked as deferred item D.1.

**Idempotency:** call sites must guard with `guard !videoTapFallbackActive else { return }` at the very top of the fallback method. The watchdog could fire twice in quick succession (race between the cancel in step 1 and an in-flight tick).

**State reset on next track:** when `playTrack` runs for any subsequent track (audio, stream, or video), `videoTapFallbackActive = false` is reset BEFORE the per-track setup begins. Fresh slate per track; no carry-over.

### 10.3 Volume Forwarding During Fallback

While `videoTapFallbackActive`, `AudioPlayer.volume`'s didSet must forward to `videoPlaybackController.volume` directly (already does in current code — that path is preserved).

Capability flag `supportsAudioProcessing` reflects the fallback (returns false).

### 10.4 No Re-Arm

For simplicity, fallback is sticky for the current track. New track playback creates a fresh `VideoAudioTap`. No automatic recovery — keep state machine simple.

---

## 11. Phase 6: Capability Flag Surface

### 11.1 What the Codebase Actually Has

The task brief mentions `supportsEQ` and `supportsVisualizer` as separate flags. The codebase actually has a single `playbackCoordinator.supportsAudioProcessing` (`PlaybackCoordinator.swift:120`) used by both EQ window and balance slider. The visualizer branch is a separate guard inside `AudioPlayer.snapshotButterchurnFrame()` (`currentMediaType == .audio && isEngineRendering`) and the spectrum visualizer reads `audioPlayer.isEngineRendering` (`VisualizerView.swift:73`).

**Design decision:** keep the single flag; do NOT introduce new flags. Adjust the existing surface so it tells the truth.

### 11.2 Changes to `PlaybackCoordinator.supportsAudioProcessing`

Current:

```swift
var supportsAudioProcessing: Bool { !isStreamBackendActive || audioPlayer.isBridgeActive }
```

New:

```swift
var supportsAudioProcessing: Bool {
    // Stream session: gated by stream bridge activation
    if isStreamBackendActive { return audioPlayer.isBridgeActive }
    // Video session: gated by video bridge activation (and not in tap fallback)
    if audioPlayer.currentMediaType == .video {
        return audioPlayer.isVideoBridgeActive && !audioPlayer.videoTapFallbackActive
    }
    // Local file: always supported
    return true
}
```

Where `audioPlayer.isVideoBridgeActive` is exposed read-only via:

```swift
var isVideoBridgeActive: Bool { engine.isVideoBridgeActive }
```

(parallel to existing `isBridgeActive` line 59).

### 11.3 Changes to `AudioPlayer.snapshotButterchurnFrame()`

Current (line 632–635):

```swift
func snapshotButterchurnFrame() -> ButterchurnFrame? {
    guard currentMediaType == .audio && isEngineRendering else { return nil }
    return visualizerPipeline.snapshotButterchurnFrame()
}
```

New:

```swift
func snapshotButterchurnFrame() -> ButterchurnFrame? {
    guard isEngineRendering else { return nil }
    // Video plays through engine when video bridge is active; reject tap-fallback case
    if currentMediaType == .video, !engine.isVideoBridgeActive { return nil }
    return visualizerPipeline.snapshotButterchurnFrame()
}
```

The `audio`-only guard becomes a `videoBridgeActive`-aware guard. Local audio and stream paths still pass through. Video tap-fallback path returns nil (no engine audio to visualize).

### 11.4 Visualizer Tap Removal Removal

`AudioPlayer.playTrack` lines 347–349 currently remove the visualizer tap when switching from audio to video. Remove that branch — the tap should stay installed because video now feeds the engine.

### 11.5 Existing `isEngineRendering` Check

Line 62: `var isEngineRendering: Bool { engine.isEngineRunning && (isPlaying || isBridgeActive) }`

Extend to include video bridge:

```swift
var isEngineRendering: Bool {
    engine.isEngineRunning && (isPlaying || isBridgeActive || engine.isVideoBridgeActive)
}
```

This makes `VisualizerView.onReceive(updateTimer)` (line 73) automatically tick during video playback.

### 11.6 Volume didSet During Video Bridge

Current `AudioPlayer.volume.didSet` (lines 65–71) forwards to both `engine.setVolume(volume)` and `videoPlaybackController.volume = volume`. With the bridge active, `videoPlaybackController.volume` setter writes to `player.volume` which we kept at 0. Need to gate:

```swift
var volume: Float = 0.75 {
    didSet {
        engine?.setVolume(volume)
        // Only forward to AVPlayer when in fallback (bridge inactive)
        if videoTapFallbackActive {
            videoPlaybackController.volume = volume
        }
        UserDefaults.standard.set(volume, forKey: Keys.volume)
    }
}
```

When the video bridge is active, `engine.setVolume` adjusts `videoSourceNode.volume` (audible). AVPlayer stays at 0.

`VideoPlaybackController.volume` semantics: keep current behaviour (sets `player.volume`). Phase 3 `loadVideo` extension explicitly overrides `player.volume = 0` after setting it from the synced `volume` property. This is the simplest split that respects single-source-of-truth (AudioPlayer owns volume policy).

---

## 12. Phase 7: Tests

### 12.1 New Tests (Swift Testing)

All new tests live in `Tests/MacAmpTests/Audio/` mirroring the existing layout.

#### `VideoAudioTapTests.swift`

- `@Test func attachReturnsValidAudioMix() throws` — given a stub `AVPlayerItem` with a known audio track, attach succeeds and returns a non-nil `AVMutableAudioMix` with one input parameters entry.
- `@Test func detachReleasesContext() throws` — measure heap behaviour via `weak var` to ensure no leak.
- `@Test func ringBufferReceivesFramesFromTap() async throws` — synthetic test: drive the tap with a fabricated `AudioBufferList` and verify `LockFreeRingBuffer.read` returns the data. Requires a small test seam: a test-only entry point `VideoAudioTap.testInjectFrames(_:frameCount:)` that bypasses the C callback path. Mark with `@_spi(Testing)` to keep production surface clean.
- `@Test func formatMismatchTriggersAudioConverter()` — give the tap a 48 kHz mono ASBD; verify the converter is built and downstream samples are 44.1 kHz stereo.

Real MTAudioProcessingTap callbacks cannot be unit-tested in isolation because they require an `AVPlayer` actively playing. These tests exercise the wrapper plumbing only; the C path is exercised in integration testing (manual verification).

#### `AudioEngineControllerVideoBridgeTests.swift`

- `@Test func activateVideoBridgeAddsSourceNode()` — call `activateVideoBridge`; assert `audioEngine.attachedNodes` count grew by 1; assert `isVideoBridgeActive == true`.
- `@Test func activateVideoBridgeDeactivatesStreamBridge()` — pre-activate stream; activate video; assert stream bridge inactive.
- `@Test func deactivateVideoBridgeIsIdempotent()` — call twice; no crash; flag false.
- `@Test func setVolumeForwardsToVideoSourceNode()` — activate video bridge; setVolume(0.5); assert `videoSourceNode.volume == 0.5`.

#### `EngineConfigObserverTests.swift`

- `@Test func observerFiresOnSyntheticNotification()` — post a fake `AVAudioEngine.configurationChangeNotification`; assert `onWillReconfigure` and `onDidReconfigure` both fire on @MainActor.
- `@Test func observerDebouncesBurst()` — post 3 notifications within 50 ms; assert callbacks fire exactly once.

#### `AudioPlayerVideoCapabilityTests.swift`

- `@Test func supportsAudioProcessingWithActiveVideoBridge()` — set `currentMediaType = .video` and force `isVideoBridgeActive = true`; assert `supportsAudioProcessing == true`.
- `@Test func supportsAudioProcessingWithVideoTapFallback()` — set `videoTapFallbackActive = true`; assert false.
- `@Test func snapshotButterchurnFrameWorksForVideo()` — same conditions; verify non-nil frame.

#### `VideoTapFallbackTests.swift`

- `@Test func watchdogDetectsStaleCallback()` — manually set `lastCallbackHostTime` to (now - 2s); tick watchdog; assert fallback engaged.
- `@Test func fallbackRestoresAVPlayerVolume()` — wire stub video controller; trigger fallback; assert `player.volume == userVolume`.

### 12.2 Manual Verification (Phase 7)

Documented in `todo.md`. Items not testable automatically:

- 5-min real video playback with TSan: no warnings, no audio dropouts.
- Switch output device via Control Center mid-video: video keeps playing, audio resumes.
- EQ band slider during video: audible difference.
- Visualizer animates during video.
- Balance slider during video: audible L/R shift.
- Drift target: < 30 ms sustained over 5 minutes (subjective + measure with same harness as Phase 0 spike).

### 12.3 Engine Config Observer — Hard to Unit Test

Documented in `todo.md` as "MANUAL: switch output device while playing local file, verify resumes within 1s; same for stream and video".

---

## 13. Files Inventory

### New Files

| Path | Purpose | Approx. LOC |
|---|---|---|
| `MacAmpApp/Audio/VideoAudioTap.swift` | MTAudioProcessingTap wrapper, C callbacks, ring-buffer producer | ~250 |
| `MacAmpApp/Audio/AudioEngineConfigurationObserver.swift` | Observer for `configurationChangeNotification` with debounce | ~80 |
| `Tests/MacAmpTests/Audio/VideoAudioTapTests.swift` | Tap wrapper plumbing tests | ~120 |
| `Tests/MacAmpTests/Audio/AudioEngineControllerVideoBridgeTests.swift` | Video bridge activation tests | ~80 |
| `Tests/MacAmpTests/Audio/EngineConfigObserverTests.swift` | Observer tests | ~60 |
| `Tests/MacAmpTests/Audio/AudioPlayerVideoCapabilityTests.swift` | Capability flag tests | ~50 |
| `Tests/MacAmpTests/Audio/VideoTapFallbackTests.swift` | Fallback path tests | ~60 |

### Modified Files

| Path | Change |
|---|---|
| `MacAmpApp/Audio/AudioEngineController.swift` | Add `videoSourceNode`, `videoRingBuffer`, `isVideoBridgeActive`, `activateVideoBridge`, `deactivateVideoBridge`, `makeVideoRenderBlock`. Wire `AudioEngineConfigurationObserver`. Add `onEngineWillReconfigure`/`onEngineDidReconfigure` callbacks. Extend `setVolume`/`setBalance` to include video source node. Extend `rewireForFile` to deactivate video bridge. |
| `MacAmpApp/Audio/AudioPlayer.swift` | Wire engine config callbacks (arm seek guards on will, resume on did). Modify `playTrack` video branch to create tap + activate video bridge. Modify `stop` to deactivate video bridge. Adjust `volume.didSet` to gate AVPlayer forwarding on fallback flag. Update `isEngineRendering` and `snapshotButterchurnFrame` per §11. Remove visualizer-tap-removal in `playTrack` audio→video switch (lines 347–349). Add `videoTapFallbackActive` flag, `videoTapWatchdogTask`, and watchdog logic. Expose `isVideoBridgeActive` getter. |
| `MacAmpApp/Audio/VideoPlaybackController.swift` | Extend `loadVideo` signature to accept optional `audioTap: VideoAudioTap?`. After AVPlayerItem ready, attach tap and assign `audioMix`. Track an internal `attachedTap` reference for cleanup. Add new `detachAudioTap()` method that sets `playerItem.audioMix = nil` and calls `attachedTap?.detach()` (used by Phase 5 fallback). Extend `cleanup()` to call `detachAudioTap()`. |
| `MacAmpApp/Audio/PlaybackCoordinator.swift` | Update `supportsAudioProcessing` per §11.2. Subscribe to AudioPlayer `onEngineReconfigured` to refresh stream workgroup. Extend `setVolume` to skip explicit `videoPlaybackController.volume` forwarding (now handled by `engine.setVolume`). |
| `project.yml` | Add new files to source list. Run `xcodegen generate` after. |

### Touched (read-only awareness, no code change)

| Path | Why |
|---|---|
| `MacAmpApp/Audio/LockFreeRingBuffer.swift` | Used as-is. No changes. |
| `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` | Pattern reference. No changes. |
| `MacAmpApp/Views/VisualizerView.swift` | Trigger condition (`isEngineRendering`) extends to video automatically. |
| `MacAmpApp/Views/MainWindow/MainWindowSlidersLayer.swift` | Reads `supportsAudioProcessing`; behaviour change is invisible to view. |
| `MacAmpApp/Views/WinampEqualizerWindow.swift` | Reads `supportsAudioProcessing`; behaviour change is invisible to view. |

### File-conflict awareness with sibling S3 tasks

Per `tasks/_context/state.md` cross-task file conflict map: this task's only "possibly" overlap is `AudioEngineController.swift` with `stream-pause-tail`. `stream-pause-tail` is in S3-1 and merges first. After S3-1 lands, plan revisits AudioEngineController to reconcile. Expected reconciliation: minimal — `stream-pause-tail` modifies `deactivateStreamBridge` for tail playout, while this task adds a parallel video bridge. Surface area is disjoint.

---

## 14. Verification Approach

### 14.1 Quantitative Drift Target

Sustained A/V drift < 30 ms over a 5-minute playback for the canonical test files from Phase 0. Measured with the same harness used in the spike.

### 14.2 Build + TSan

- `xcodegen generate`
- `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`
- `xcodebuildmcp macos test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`
- 5-min real video playback launched from xcodebuildmcp run, with TSan attached. Console must be free of data-race warnings.

### 14.3 Regression Suite (Manual)

Verify existing paths still work:

- Local mp3 playback: EQ + visualizer + balance still functional.
- Internet radio (44.1 kHz and 48 kHz stations): EQ + visualizer + ICY metadata still functional.
- Switch local → stream → local: no engine-reset failures (-10868), no double audio.
- Stream pause-tail (from `stream-pause-tail` task) still works (no regression in tail playout).
- Visualizer pause during volume drag (from `mainwindow-visualizer-isolation`) still resolved.

### 14.4 Edge Cases

- Video file with no audio track → fallback path; player runs muted-by-design with no engine audio. No crash.
- Video file with mono audio → tap downmixes to stereo via converter.
- Video file with 5.1 audio → tap downmixes to stereo via converter.
- Video → next track is local audio: engine bridge teardown clean.
- Video → next track is stream: video bridge → stream bridge transition.
- Video paused, output device changed, video resumed: engine config observer reconnects.
- Video reaches end-of-file: `onPlaybackEnded` fires, bridge deactivates cleanly.

### 14.5 Verification Agent

Per the Multi-step Context Engineering convention (`CLAUDE.md` §6), use a separate sub-agent for verification — it reads the plan and validates feature works end-to-end. The verification agent's findings go into a new `verification.md` in the task folder.

---

## 15. Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| A/V drift exceeds 30 ms with no sync mechanism | HIGH | Phase 0 spike measures drift before any production code; Path A/B chosen empirically |
| `AVPlayer.masterClock` API differs across macOS versions | MED | Spike validates exact API on macOS 15+; if it fails, Path B (pre-roll) takes over |
| MTAudioProcessingTap silently fails for some video file | MED | Phase 5 watchdog detects stall, falls back to AVPlayer.volume |
| AVPlayer volume = 0 fallback creates silent video | LOW | Watchdog detection is fast (1 s threshold) |
| Sample-rate mismatch (48 kHz video, 44.1 kHz engine) | LOW | AudioConverter handled in tap (Phase 2.5); ring buffer is format-agnostic; downstream graph reformats |
| Swift 6.2 `@convention(c)` + ARC issues with client info pointer | LOW | `Unmanaged<Context>` with explicit `passRetained` / `release` in `tapFinalize` |
| Engine config observer fires recursively during reconnection | MED | Debounce + generation counter ensures one effective fire per burst |
| Video bridge active simultaneously with stream bridge (audio chaos) | MED | Mutual-exclusion enforcement in three activation paths (§8.2); covered by tests |
| Tap callback runs at high frequency, ARC retain on context | LOW | Context is `Unmanaged.passUnretained` per call; only retained once at attach, released at finalize |
| Tap watchdog false-positive during AVPlayer pause | LOW | Watchdog gated on `videoPlaybackController.isPlaying` (only checks while playing) |
| Video → audio MediaType switch leaves bridge active | MED | Mutual-exclusion in `playTrack` audio branch deactivates video bridge before scheduling local file |

---

## 16. Stop Criteria / Kill Switch

Per Principle 7, this task has explicit cancel criteria:

### Hard kill (revert spike, do not open implementation branch)

- Phase 0 measures > 100 ms sustained drift with both `masterClock` (Path A) and pre-roll (Path B) attempted, on multiple test files.
- MTAudioProcessingTap fails to fire `tapProcess` for two or more of the five test files. (Indicates a fundamental Apple platform issue with local file paths, not a fixable bug.)
- Swift 6.2 strict concurrency rejects the `@convention(c)` callback model in a way that cannot be worked around (e.g., `Unmanaged` pattern triggers Sendable failures we cannot suppress with documented `@unchecked` on a queue-confined class).

If hit: delete `spike/vaer-av-drift-measurement` branch, write findings to research.md, mark task PERMANENTLY DEFERRED in tasks_index, do not proceed.

### Soft kill (revert mid-implementation)

- After Phase 1 + Phase 2 land but Phase 3 reveals graph wiring incompatibility (e.g., engine refuses both stream and video source nodes simultaneously even though they're mutually exclusive — would indicate a deeper issue).
- TSan reports unfixable data race in tap → ring buffer path.

If hit: revert all video-routing commits on `feat/video-audio-engine-routing`, leaving only Phase 1 (engine config observer) + tests as a smaller useful PR. The observer is independently valuable for AirPlay route changes.

### Scope-reduction fallback (NOT a kill)

If A/V sync is fine but ONE of the three capabilities (EQ/visualizer/balance) has unforeseen problems on video specifically:

- Ship the working two and document the third as a follow-up.
- Update `supportsAudioProcessing` to reflect the actual subset.
- This is acceptable because the user-visible improvement is still net-positive.

---

## 17. Branch + PR Plan

### 17.1 Branch Strategy

- Spike: `spike/vaer-av-drift-measurement` (Phase 0 only, throwaway, never pushed).
- Implementation: `feat/video-audio-engine-routing` from `main` after S3-1 (mainwindow-visualizer-isolation + stream-pause-tail) merged.
- Single PR (PR #C in S3 sequencing).

### 17.2 Commit Hygiene

Suggested commit boundaries (one per phase):

1. `feat(audio): add AudioEngineConfigurationObserver` (Phase 1, includes wiring in AudioEngineController + tests)
2. `feat(audio): add VideoAudioTap with MTAudioProcessingTap callbacks` (Phase 2, tap-only)
3. `feat(audio): wire video source node into engine graph` (Phase 3, AudioEngineController + AudioPlayer integration)
4. `feat(audio): video A/V sync via masterClock` (Phase 4 — only if Path A; otherwise Path B as a separate commit, or skipped entirely)
5. `feat(audio): add tap-failure watchdog and fallback` (Phase 5)
6. `feat(audio): enable EQ + visualizer + balance for video sessions` (Phase 6 — small, capability surface only)
7. `test(audio): video routing test coverage` (Phase 7)

Each commit is independently buildable + testable. PR diff stays reviewable.

### 17.3 PR Description Template

- Problem statement (link to plan §1)
- Phase 0 spike findings link (research.md section)
- File-by-file summary
- Manual test checklist (engine config observer, tap fallback)
- TSan output snippet
- Drift measurement summary
- Co-Authored-By: Claude Opus 4.7

### 17.4 Oracle Gate

Before requesting human review:

- Run Codex Oracle on full diff. Iterate to ≥ 9/10.
- Address actionable comments; classify nitpicks/false-positives per project convention.

---

## 18. Rollback Plan

If post-merge issues surface:

- **Single-commit revert preferred.** PR #C is one merge commit; `git revert -m 1 <merge-sha>` restores main to pre-video-routing state.
- **Partial rollback** (keep observer): if only the video bridge has issues, cherry-pick the Phase 1 commits onto a `hotfix/keep-engine-config-observer` branch and force-push the revert PR with the partial restoration.
- **State migration:** none — no UserDefaults keys added, no schema changes.
- **User-visible regression after rollback:** video returns to no-EQ/no-viz/no-balance state. Pre-existing behaviour, no data loss.

A rollback decision is made by the user (project owner) based on telemetry / user-reported issues post-merge. Plan author's responsibility ends at PR merge + verification report.

---

## 19. Open Items (Tracked in todo.md, Not Blockers)

- Confirm exact `AVPlayer.masterClock` setter API on macOS 15.0 (resolved in spike).
- Decide on `VideoAudioTap` test seam: `@_spi(Testing)` injection method vs. protocol abstraction. Lean toward `@_spi(Testing)` for minimal surface widening.
- Watchdog cadence: 250 ms feels right; spike may show different values.
- Whether to surface a UI banner on tap fallback. Out of scope for this task; tracked in tasks_index "deferred" inventory.

---

## Oracle Validation Summary

**Final score:** 9.4/10 (PASS) — Codex Oracle (`gpt-5.3-codex`, `reasoningEffort: xhigh`).

**Iterations:** 3.

**Iteration 1 (7.2/10):** Identified three blockers:
1. Tap fallback under-specified — missing explicit `audioMix=nil`, watchdog cancel, idempotency guard, state reset.
2. Phase 1 reconfigure flow under-specified — needed explicit `currentSeekID` bumping BEFORE engine restart and 100/200 ms guard release timings.
3. Phase 0 spike protocol too short (60 s) and kill switch not fully binary — partial-success path leaked into spike-stage decision.

**Iteration 2 (8.7/10):** Two remaining issues:
1. Paused local-file reconfigure path missing — `play()` does not reschedule (AudioPlayer.swift:417), so paused → output-change → resume would replay the detached pre-restart segment.
2. Tap teardown contract inconsistent between plan §10.2, file inventory, and todo 3.5.4.

**Iteration 3 (9.4/10): PASS.** Both iteration-2 issues resolved:
- Reconfigure now ALWAYS reschedules local-file path from saved time with bumped seekID, with explicit paused/playing sub-branches.
- `VideoPlaybackController.detachAudioTap()` introduced as a single unified teardown method used by both normal cleanup and Phase 5 fallback.

**Outstanding (not blocking):**
- Phase 4 sync strategy is conditional on Phase 0 spike outcome — that conditionality is the design intent and Oracle accepts it.
- Watchdog cadence (250 ms) is empirical; spike data may suggest tuning.

The plan is ready to execute pending Phase 0 spike completion.
