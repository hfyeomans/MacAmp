# Plan: AVPlayer-Native Video DSP

> **Status:** PLANNING — awaiting Oracle gate (target ≥9/10).
> **Created:** 2026-05-01
> **Sprint:** S3, Wave **S3-2** (architectural pivot from `feat/video-audio-engine-routing`).
> **Branch:** `feat/avplayer-native-video-dsp`
> **PR target:** PR #C (replaces the previous S3-2 PR target).
> **Predecessors:** S3-1A ✅, S3-1B ✅, Phase 1 (engine config observer) ✅ as cherry-pick base.
> **Successors (file-conflict aware):** S3-3 (`hls-streaming-support`) and S3-4 (`ogg-vorbis-support`) both touch `MacAmpApp/Audio/StreamDecodePipeline.swift` and `MacAmpApp/Audio/StreamPlayer.swift` — this plan does NOT touch those files (audio-side path unchanged). See §11 conflict map.
> **Source of truth:** `tasks/avplayer-native-video-dsp/research.md` (Oracle 10/10 after 5 review rounds, commit `46bb6af`).
> **Spike artifact:** `spike/avplayer-inplace-tap-dsp` branch (kept locally until S3-2 close).

---

## 1. Problem Statement

Video files in MacAmp currently play with no EQ, no balance, and no visualizer participation. The previous attempt (`feat/video-audio-engine-routing`, paused-as-reference at commit `5af91eb`) routed video audio out of AVPlayer through `AVAudioEngine` to apply DSP. That approach reached Phase 7 testing and failed for four documented reasons (see `tasks/_context/s3-2-pivot.md`):

1. **`AVAudioEngineConfigurationChange` is unreliable for AirPlay/AirPods route changes.** The notification only fires when the engine's effective configuration actually changes; AirPods route through the AirPlay subsystem and don't always trigger it. Proven by a missing log line in user traces during Phase 7 — the watchdog gate never armed for the bug case.
2. **Master-clock-coupled video stalls.** AVPlayer's audio queue is the master clock for video on macOS. Any ring under-run on the engine consumer side stalled the master clock, which stalled the video frame. Larger ring (16 K frames) mitigated but did not eliminate.
3. **Dual-clock-domain drift.** Engine output clock and AVPlayer master clock are unsynchronized. Drift accumulated on long playback (>5–10 min) and reset on pause/resume. Phase 7 fixes (Mastering SRC + 16 K ring) reduced perceived drift but the topology guaranteed residue.
4. **Tinning artifacts from the second SRC stage** — `AudioConverter`'s quality tier had to be raised to Mastering / Max to approximate AVPlayer's native pipeline. Net fidelity tax remained.

This plan implements the **contrarian architecture** decided 2026-05-01: don't drag video audio out of AVPlayer. Apply DSP in-place inside the same `MTAudioProcessingTap` so AVPlayer's native pipeline plays the modified buffer. No ring, no engine clock for video, no second SRC stage, no master-clock coupling. Audio files and streams continue through `AVAudioEngine` unchanged.

**Success criteria:**
- Video playback applies the user's current 10-band EQ + balance state, audibly matching the engine path within ≤0.5 dB across 20 Hz – 20 kHz.
- Spectrum analyzer + Butterchurn animate from video audio (same DSP cadence as engine path).
- AirPods connect / disconnect mid-playback, AirPlay-2 handoff, system default-output change all produce no audio drop, no video stall, no DSP-state loss.
- ≥10 minutes continuous playback, A/V sync within ±40 ms, no perceptible drift.
- Render-thread `tapProcess` 99th-percentile wall-clock ≤10 % of buffer budget on Apple Silicon **and** Intel.
- All TSan-on tests green.

---

## 2. Non-Goals

- **NOT** changing the audio-side path (local files, streams). Engine path stays intact: `AVAudioPlayerNode`, `AVAudioSourceNode`, `AVAudioUnitEQ`, balance node, engine-tap visualizer all remain.
- **NOT** delivering HLS-video DSP. `MTAudioProcessingTap` does not fire reliably for streaming `AVPlayerItem`s (Apple QA1716; see `tasks/_context/state.md`). HLS-video DSP is a separate future task.
- **NOT** sharing EQ math between engine `AVAudioUnitEQ` and the new tap-side `BiquadCascade`. Per Principle 4 (AHA Rule of Three), the math is duplicated WET — different threading, different parameter-update paths, different ownership models. A shared abstraction would require flag-driven divergence (the wrong abstraction).
- **NOT** introducing a fallback path / capability flag (`videoTapFallbackActive` is on the saved branch's denylist). The new architecture has no fallback because there is no engine bridge to fall back from.
- **NOT** rebuilding `VisualizerSharedBuffer`'s SPSC contract. The existing single-slot last-write-wins structure is reused (Principle 5 — minimize API surface). Visibility promotion + rename only.
- **NOT** introducing the `swift-atomics` package. `Synchronization.Atomic` (stdlib in Swift 6.0, macOS 15+) replaces all atomic uses on this branch.
- **NOT** changing `EqualizerController`'s public API for the audio side. The new tap Context becomes a new fan-out target only.
- **NOT** touching `tasks/done/`, `MacAmpApp/Audio/StreamDecodePipeline.swift`, `MacAmpApp/Audio/StreamPlayer.swift`, or any test plan / scheme configuration.
- **NOT** validating macOS 14 or earlier. Deployment target is macOS 15+ (`Synchronization` requires it).

---

## 3. Pre-Decomposition Gate Checklist (per `tasks/_context/principles.md`)

This task is **architectural pivot + new module**, not pure decomposition. Gate is still completed:

- [x] **1. Problem statement written** — see §1 (engine-routing topology fights the macOS platform; in-place tap DSP sidesteps the four documented failure modes).
- [x] **2. Non-goals listed** — see §2.
- [x] **3. Principles contract approved:**
  - **P1 Problem-First:** four concrete, user-visible failure modes on the saved branch. Architecture pivot is problem-driven, not cleanup-driven.
  - **P2 Cohesion > Line Count:** in-place tap DSP keeps EQ + balance + visualizer-feed-write all in one render-thread function. No fragmentation across actors / queues.
  - **P3 State Ownership Sacred:** `EqualizerController` remains the single owner of user EQ state (`isEqOn`, `preampLinearGain`, 10 `bandGainsDB`); `AudioPlayer` remains the single owner of `balance`. Tap Context is a *consumer* of both via atomic-pointer hand-off (ADR-4 for EQ coefficients) and atomic Float bit-pattern (for balance) — not a parallel writer. Render-thread mutations are confined to the buffer pointer alone. Two existing single-sources-of-truth, parallel fanout pattern (ADR-5) — not a centralization.
  - **P4 Rule of Three (AHA):** EQ math lives twice (engine `AVAudioUnitEQ` + tap-side `BiquadCascade`). Accepted at first occurrence per the safety-invariant exception — the two implementations have different threading domains, different parameter-update mechanisms, different lifetimes. Sharing would require flag-driven divergence (rejected per AHA).
  - **P5 API Surface Minimization:** two private nested types in `VisualizerPipeline.swift` are promoted to module-internal (`VisualizerSharedBuffer` → `VisualizerFeed`, `VisualizerScratchBuffers`). Justified because dual-producer (engine + video tap) is a real new capability. No `internal → public` widening anywhere.
  - **P6 No Pass-Through Middlemen:** the new tap render function is a real worker (DSP execution, not forwarding). The `setVideoTapEnabled` facade on `AudioPlayer` (if introduced) follows the existing `setStreamSilenced` / `setVolume` pattern (also a facade, not a middleman).
  - **P7 ADR + Kill Switch:** §4 has 11 ADRs; §9 has Stop Criteria; §12 has Rollback Plan.
- [x] **4. Responsibility map exists** — see §5.5.
- [x] **5. Complexity assessed:** new module `MacAmpApp/Audio/VideoDSP/` (~5 new files, ~800-1000 LOC). Highest-cognitive-density file: `VideoTap.swift` (C-callback closures + Unmanaged lifetime + DSP orchestration). Bounded by §6 phase decomposition and §10 test plan.
- [x] **6. Candidate split scored:** the new `VideoDSP/` module is a single cohesive unit (one tap + one Context + one BiquadCascade + one render function). Not a decomposition of existing code; it is new functionality with one coherent responsibility (apply DSP in-place to AVPlayer's audio buffer).
- [x] **7. Public/internal API delta listed** — see §5.4.
- [x] **8. Stop criteria defined** — see §9.

**Hard gate cleared.**

---

## 4. Architecture Decision Record (ADR)

### ADR-1: In-place tap DSP topology
**Decision.** Apply EQ + balance + visualizer DSP inside `tapProcess` by modifying the `bufferList` AVPlayer hands us. AVPlayer plays the modified buffer. No ring, no engine bridge, no second SRC stage.
**Drivers.** Saved branch failed for four reasons (problem statement §1). New topology removes ring under-runs, dual-clock-domain drift, and SRC tinning at the cost of a bounded per-render-cycle stall risk if `tapProcess` overruns its deadline (no drift accumulation; see Q3 in research.md).
**Trade-off accepted.** Render-thread DSP overrun causes transient audio glitch + transient video stall, bounded per render cycle. Mitigated by ≤10 % budget gate (§7).
**Kill switch.** §9 (CPU benchmark fail, numerical EQ match fail, route-change matrix fail).

### ADR-2: `_PreEffects` flag
**Decision.** `kMTAudioProcessingTapCreationFlag_PreEffects`.
**Drivers.** Source-side DSP that should layer with AVPlayer's downstream chain (spatial audio, hardware mixing). `_PostEffects` would suit a metering-only tap; the saved branch used `_PostEffects` because it was draining for a downstream consumer.
**Trade-off.** If a future Milkdrop-only metering tap is needed, it adds a separate `_PostEffects` tap (different `MTAudioProcessingTap`, different Context, no interference).
**Source.** `research-notes/apple-docs.md` Q2 (Apple SDK header verbatim).

### ADR-3: Concurrency contract — non-actor `Context` + `@unchecked Sendable` + `Synchronization.Atomic`
**Decision.** `final class VideoTapContext: @unchecked Sendable` (non-actor). All cross-thread state uses `Synchronization.Atomic<T>` (or `Synchronization.Mutex<T>` for non-trivially-atomic state). No `nonisolated(unsafe)` markers on individual fields.
**Drivers.** `Synchronization.Atomic<T>` is itself `Sendable` (Swift 6.0 stdlib); per-field unsafety markers are noise. The class envelope's `@unchecked Sendable` exists solely to silence the C-callback FFI boundary check.
**Rejected alternatives:**
- Per-field `nonisolated(unsafe)` — unnecessary with `Atomic<T>` already `Sendable`.
- Actor-isolated Context — Context is fundamentally non-isolated (render thread accesses via `Unmanaged`, not via actor messaging).
- `swift-atomics` `ManagedAtomic<T>` — external package we don't need.
- Mutex-only state — render-thread blocking on `Mutex` is a correctness hazard at the audio render deadline.
**Source.** `research.md` Concurrency Decision Record.

### ADR-4: Coefficient hand-off — atomic-pointer double-buffer snapshot
**Decision.** Two pre-allocated `BiquadCoefficientSet` blocks (one "active," one "inactive"). Main thread writes into the inactive block, then atomically swaps a pointer (`Atomic<UnsafePointer<BiquadCoefficientSet>>`). Render thread reads via atomic pointer load on each `tapProcess` entry.
**Drivers.** Lock-free; zero teardown risk (the entire 50-coefficient set swaps atomically); one indirect load per buffer (~1 ns on Apple Silicon, negligible vs ~10 ms render quantum).
**Rejected alternatives:**
- 100 individual `Atomic<UInt32>` (Float bit-pattern). Simpler but coefficient sets can tear (e.g., render thread reads 4-of-5 new + 1-of-5 old). Usually inaudible at user-EQ-update rate but theoretically possible.
- `Synchronization.Mutex<BiquadCoefficientSet>` with `withLockIfAvailable` (skip-update on contention). Adds a contention path; render thread could miss coefficient updates indefinitely.
**Memory model.** Allocation: `UnsafeMutablePointer<BiquadCoefficientSet>.allocate(capacity: 1)`, deallocate in `Context.deinit`. Two long-lived allocations per Context. Pointer swap uses `.acquiringAndReleasing` ordering on store; render thread uses `.acquiring` on load.

### ADR-5: EQ and balance state fanout — two canonical owners, parallel fanout pattern
**Decision.**
- **EQ state** (`isEqOn: Bool`, `preampLinearGain: Float`, `bandGainsDB: (Float ×10)`) is owned by `EqualizerController` (current state). On any user-driven change, `EqualizerController` fans out to two consumers:
  1. Engine-side `AVAudioUnitEQ` parameter writes (existing path, unchanged).
  2. Tap-side: recompute `BiquadCoefficientSet` for the current sample rate, write it into the inactive double-buffer block, atomic-swap the pointer (ADR-4). Also push `isEqOn` into the Context's atomic gate (used to bypass biquad processing in `tapProcess` when `isEqOn=false`). Also push `preampLinearGain` into the Context's atomic.
- **Balance state** (`balance: Float`, range 0.0 = full L, 0.5 = center, 1.0 = full R) is owned by `AudioPlayer` (existing state at `AudioPlayer.swift:86`). On change, `AudioPlayer.balance.didSet` fans out to two consumers:
  1. Engine-side balance node parameter (existing path, unchanged).
  2. Tap-side: write Float bit-pattern to `VideoTapContext.balance: Atomic<UInt32>`.

Both Contexts (one per video AVPlayerItem) are registered with `EqualizerController` AND `AudioPlayer` at attach and unregistered at detach. Registration immediately pushes current state into the new Context (so the tap is up-to-date before its first `tapProcess` invocation).

**Render-path order in `tapProcess`** (after `MTAudioProcessingTapGetSourceAudio` succeeds):
1. **Format gate** (ADR-11): if ASBD is not Float32 LPCM, return immediately (pass-through).
2. **Filter-state reset gate** (ADR-9): if `flagsOut.pointee.contains(.startOfStream)`, call `context.cascade.reset()`.
3. **Preamp gain**: `let preamp = Float(bitPattern: context.preampLinearGainBits.load(.relaxed))`. If `preamp != 1.0`, multiply every sample by `preamp` (single multiply per sample per channel).
4. **EQ on/off gate**: if `context.isEqOn.load(.relaxed) == false`, skip step 5.
5. **`BiquadCascade.process`**: load coefficient pointer atomically; if non-nil, run 10-band cascade in place.
6. **Balance**: `let bal = Float(bitPattern: context.balance.load(.relaxed))`; compute `lGain = min(1, 2*(1-bal))`, `rGain = min(1, 2*bal)`; multiply L and R buffers (or skip if exactly center, `bal == 0.5`).
7. **Visualizer DSP** (Phase 4): mono-mix + RMS + Goertzel + FFT into per-tap scratch; `feed.tryPublish`.
8. Return.

**Bypass semantics summary** (CPU cost when each is "off"):

| State | CPU cost when off |
|---|---|
| `isEqOn = false` | Steps 4-5 skipped; preamp + balance still apply |
| `preamp = 0 dB` (linear=1.0) | Step 3 single load + comparison; multiply skipped |
| `balance = 0.5` (center) | Step 6 single load + comparison; multiplies skipped |
| Format unsupported | Steps 2-7 all skipped (pass-through) |
| Visualizer disabled (future toggle) | Step 7 skipped (TBD; Phase 4 detail) |

**Drivers.** Two existing single-sources-of-truth (EqualizerController for EQ, AudioPlayer for balance). Fanout pattern is identical for both. Avoids forcing a cross-cutting migration of `balance` ownership.
**Rejected alternatives.**
- Centralize both EQ and balance into `EqualizerController`. Larger refactor with no clear win — `AudioPlayer.balance` already works correctly with the engine path.
- Each consumer pulls on its own schedule. Adds polling concerns and engine/tap synchronization lag.
- Single combined fanout call. Different rate-of-change profiles (EQ recomputes 50 coefficients per change; balance is a single Float) — separate paths are cleaner.

### ADR-6: Visualizer dual-producer pattern — parallel render functions, no flag-driven generalization
**Decision.** Keep the existing engine-tap render function (`makeTapHandler` in `VisualizerPipeline.swift:565`) untouched. Add a new render function (`videoTapVisualizerRender`) that consumes `AudioBufferList` (vs `AVAudioPCMBuffer` for engine). Both use the same `VisualizerFeed` + `VisualizerScratchBuffers` types.
**Drivers.** Different threading contracts (engine `nonisolated static @Sendable` closure vs C-callback), different buffer shapes, different lifetime models. AHA Rule of Three: 2 callers ≠ extract.
**Rejected alternative.** Generalize `makeTapHandler` over both buffer types via a flag. Would require flag-driven divergence inside the closure — the wrong abstraction.
**Visualizer feed contract.** Mono Float32 pre-computed arrays (RMS×20, Goertzel×20, oscilloscope×76, FFT×1024+1024). Matches the existing engine-side contract; surround sources downmix to mono in the new render function. The audible path leaves channel layout untouched.

### ADR-7: Tap lifecycle — one tap per AVPlayerItem; `audioMix` immutable during playback
**Decision.** Each video `AVPlayerItem` gets a freshly-built `MTAudioProcessingTap` + `VideoTapContext` pair at item construction. `audioMix` is set once before `play()` and **not mutated during playback**. Detach: `pause()` → `replaceCurrentItem(with: …)` → AVPlayer's chain calls `tapFinalize` once the tap's last reference is dropped.
**`Unmanaged` balance.** +1 from `passRetained(context)` at attach. -1 from `Unmanaged<VideoTapContext>.fromOpaque(storage).release()` in `tapFinalize`. Exactly once.
**Production-required hardening.** Tap-create failure path releases the `Unmanaged` before throwing/returning (ADR-10).
**Tear-down assumption (revisited if Phase 7 testing proves otherwise).** `tapFinalize` may fire asynchronously on a background queue; tear-down code does not wait synchronously for it. A "tap is alive" atomic gate on the Context is **not** added by default; Phase 7 lifecycle tests determine whether one is necessary.

### ADR-8: `BiquadCascade` implementation — RBJ cookbook formulas
**Decision.** RBJ (Robert Bristow-Johnson) Audio EQ Cookbook octave-bandwidth peaking-EQ formula for 8 parametric bands; analogous low/high-shelf formulas for bands 0 and 9.
**Drivers.** Apple SDK header (`AudioUnitParameters.h`, `kAUNBandEQFilterType_Parametric`) states verbatim that `AVAudioUnitEQ` uses Butterworth analog prototype with octave bandwidth — that maps exactly to RBJ's published formula. Numerical match is feasible by construction (research.md Q2, HIGH confidence).
**Per-band parameters** (read from current `EqualizerController.swift`):

| Band | Frequency (Hz) | Type | BW (oct) |
|---|---|---|---|
| 0 | 70 | Low shelf | n/a |
| 1 | 180 | Parametric | 1.0 |
| 2 | 320 | Parametric | 1.0 |
| 3 | 600 | Parametric | 1.0 |
| 4 | 1 000 | Parametric | 1.0 |
| 5 | 3 000 | Parametric | 1.0 |
| 6 | 6 000 | Parametric | 1.0 |
| 7 | 12 000 | Parametric | 1.0 |
| 8 | 14 000 | Parametric | 1.0 |
| 9 | 16 000 | High shelf | n/a |

**Acceptance criterion.** ≤0.5 dB worst-case magnitude error vs `AVAudioUnitEQ` across 20 Hz – 20 kHz; ≤1 dB hard reject (research.md Q2).

### ADR-9: Filter state on seek — flush on `kMTAudioProcessingTapFlag_StartOfStream`
**Decision.** Reset `BiquadCascade` filter state (each band's `z[1]` and `z[2]` history samples) when `tapProcess` receives `kMTAudioProcessingTapFlag_StartOfStream`.
**Drivers.** Carry-over filter history at seek boundaries produces transient artifacts (~10 ms of incorrect output as the filter re-converges). Flushing avoids the artifact at zero correctness cost — the filter takes ~5 samples to re-converge from zero state (sub-ms at 44.1 kHz, imperceptible).
**Rejected alternative.** Accept the transient. Smaller code but audibly inferior at every seek.

### ADR-10: Tap-create failure releases `Unmanaged<Context>` (production hardening)
**Decision.** The `Unmanaged.passRetained(context)` is captured into a local before populating `clientInfo`. On `MTAudioProcessingTapCreate` failure, the local's `release()` is called explicitly before the error path returns/throws.
**Drivers.** If `Create` fails, `tapInit` never fires and the +1 retain leaks. The spike (`spikes/avplayer-inplace-tap-dsp/Sources/InPlaceTapSpike/main.swift:131-149`) cuts this corner. Production cannot.
**Pattern (canonical):**
```swift
let retained = Unmanaged.passRetained(context)
var callbacks = MTAudioProcessingTapCallbacks(...)
callbacks.clientInfo = UnsafeMutableRawPointer(retained.toOpaque())

var tapOut: MTAudioProcessingTap?
let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tapOut)
guard status == noErr, let tap = tapOut else {
    retained.release()
    throw VideoTapError.createFailed(status)
}
```

### ADR-11: ASBD format guard — DSP only on 32-bit Float LPCM, pass-through otherwise
**Decision.** `tapPrepare` reads the `AudioStreamBasicDescription`. DSP path runs only when `mFormatID == kAudioFormatLinearPCM && (mFormatFlags & kAudioFormatFlagIsFloat) != 0 && mBitsPerChannel == 32`. Other formats: `tapProcess` calls `MTAudioProcessingTapGetSourceAudio` and returns immediately (pass-through).
**Drivers.** `BiquadCascade.process` assumes Float32. The spike assumes the same — production cannot. AVPlayer's typical decoder output for AAC/MP3 in modern macOS is Float32 LPCM, so the pass-through path should rarely fire in practice; but it's the correctness floor.
**Logging.** When pass-through engages, log once per item (not per buffer) at info level so support can diagnose "EQ doesn't apply to this video" reports.

---

## 5. Files Affected

### 5.1 New files

| File | Purpose | LOC est | Phase |
|---|---|---|---|
| `MacAmpApp/Audio/VisualizerFeed.swift` | Extracted `VisualizerSharedBuffer`, renamed | ~80 | 1 |
| `MacAmpApp/Audio/VisualizerScratchBuffers.swift` | Extracted from `VisualizerPipeline.swift` (optional — may stay nested-but-non-private) | ~60 | 1 |
| `MacAmpApp/Audio/VideoDSP/VideoTapContext.swift` | Tap context (atomics, coefficient pointer, Unmanaged lifetime helpers, `VideoTapDiagnostics` snapshot type) | ~180 | 2 |
| `MacAmpApp/Audio/VideoDSP/VideoTap.swift` | C-callback closures, tap creation factory, `AVMutableAudioMix` wiring, `VideoTapError` | ~250 | 2 |
| `MacAmpApp/Audio/VideoDSP/BiquadCoefficientSet.swift` | 50-coefficient struct + RBJ formula computation | ~120 | 3 |
| `MacAmpApp/Audio/VideoDSP/BiquadCascade.swift` | 10-band cascade, in-place processing function, `reset()` | ~100 | 3 |
| `MacAmpApp/Audio/VideoDSP/VideoTapVisualizerRender.swift` | Tap-side video render function (mono-mix + RMS + Goertzel + FFT + tryPublish) | ~120 | 4 |
| `Tests/MacAmpTests/BiquadNumericalMatchTests.swift` | Log-sweep numerical match vs `AVAudioUnitEQ`; EQ-toggle bypass test; preamp parity test | ~180 | 3 |
| `Tests/MacAmpTests/VideoTapLifecycleTests.swift` | TSan-on lifecycle tests | ~200 | 7 |
| `Tests/MacAmpTests/VideoTapDSPTests.swift` | Tap DSP unit + integration tests | ~250 | 2-5 |

### 5.2 Modified files

| File | Change | LOC est | Phase |
|---|---|---|---|
| `MacAmpApp/Audio/VisualizerPipeline.swift` | Type renames + visibility-promote at L36, L169, L330, L565 | ~30 modified | 1 |
| `MacAmpApp/Audio/AudioPlayer.swift` | Wire video-item playback to attach tap; balance fanout to tap Context (`balance.didSet` adds tap-side write); facade `attachVideoTap`/`detachVideoTap` | ~80 added | 2, 5 |
| `MacAmpApp/Audio/EqualizerController.swift` | Add `EqualizerState` snapshot struct (private nested); `WeakBox<VideoTapContext>` registry; `registerVideoTapContext`/`unregisterVideoTapContext` API; fanout to registered Contexts on EQ change (preamp, isEqOn, band gains) | ~80 added | 5 |
| `MacAmpApp/Windows/WinampVideoWindowController.swift` | (potentially) Wire EQ/balance/visualizer UI surfaces to video playback | ~20 added | 9 |
| `project.yml` | (no manual edits — `project.yml` uses path-based source globs; `xcodegen generate` re-discovers files automatically. Run `xcodegen generate` after each phase that adds files) | n/a | 1, 2, 3, 4, 7 |

### 5.2.1 Helper types specified inline

These are small types declared as part of larger files; called out here so the inventory is complete:

| Type | Purpose | Where declared | LOC | Phase |
|---|---|---|---|---|
| `EqualizerState` | `Sendable` snapshot: `isEqOn: Bool`, `preampLinearGain: Float`, `bandGainsDB: (Float ×10)`. Used as the input to `BiquadCoefficientSet.compute`. | private nested in `EqualizerController.swift` | ~10 | 3 (declared) |
| `BiquadCoefs` | Per-band tuple `(b0, b1, b2, a1, a2)` — five `Float`s. | private nested in `BiquadCoefficientSet.swift` | ~5 | 3 |
| `WeakBox<T: AnyObject>` | Tiny weak-reference wrapper used by `EqualizerController.registeredVideoTapContexts`. | private nested in `EqualizerController.swift` | ~5 | 5 |
| `VideoTapDiagnostics` | `Sendable` snapshot for telemetry display: `processCallCount`, `frameCount`, `budgetOverrunCount`, `deadlineRiskCount`. | nested in `VideoTapContext.swift` | ~10 | 6 |
| `VideoTapError` | `Error` enum: `createFailed(OSStatus)`, `formatUnsupported(AudioStreamBasicDescription)`. | nested in `VideoTap.swift` | ~10 | 2 |

### 5.3 Files explicitly NOT touched (per non-goals)

- `MacAmpApp/Audio/StreamDecodePipeline.swift` — stream-side path
- `MacAmpApp/Audio/StreamPlayer.swift` — stream-side path
- `MacAmpApp/Audio/AudioEngineController.swift` — engine path stays intact
- `MacAmpApp/Audio/LockFreeRingBuffer.swift` — no transport ring on this path
- `MacAmpApp/Audio/AudioConverterDecoder.swift` — no conversion on this path
- Anything in `tasks/done/` — read-only reference
- Anything in `tasks/video-audio-engine-routing/` — paused-as-reference, read-only

### 5.4 Public/internal API delta

- `VisualizerSharedBuffer` (private nested class) → `VisualizerFeed` (module-internal, file-scope)
- `VisualizerScratchBuffers` (private nested class) → module-internal (extracted or kept nested-but-non-private)
- `VisualizerPipeline.makeTapHandler` signature: parameter types change from `VisualizerSharedBuffer` to `VisualizerFeed` (private→nothing — same call site)
- New: `VideoTapContext`, `VideoTap`, `BiquadCoefficientSet`, `BiquadCascade`, `videoTapVisualizerRender(...)` — all module-internal (no `public`)
- New: `AudioPlayer.attachVideoTap(to:)` / `AudioPlayer.detachVideoTap()` (module-internal — facade only, no state widening)
- New: `EqualizerController.registerVideoTapContext(_:)` / `EqualizerController.unregisterVideoTapContext(_:)` (module-internal)

### 5.5 Responsibility map

| Concern | Owner | Layer |
|---|---|---|
| User EQ state (`isEqOn`, `preampLinearGain`, 10 `bandGainsDB`) | `EqualizerController` | Bridge |
| User balance state (`balance: Float`) | `AudioPlayer` (`balance` at `AudioPlayer.swift:86`, existing) | Bridge |
| EQ → engine `AVAudioUnitEQ` parameter writes | `EqualizerController` | Bridge |
| EQ → tap `BiquadCoefficientSet` computation + atomic-pointer swap | `EqualizerController` (computes) → `VideoTapContext` (holds) | Bridge → Mechanism |
| Balance → engine balance node parameter | `AudioPlayer.balance.didSet` (existing) | Bridge |
| Balance → tap `VideoTapContext.balance: Atomic<UInt32>` (Float bit-pattern) | `AudioPlayer.balance.didSet` fanout (Phase 5 addition) | Bridge → Mechanism |
| Tap C-callbacks | `VideoTap.swift` (file-scope `private let` closures) | Mechanism |
| Tap Context lifetime (`Unmanaged` retain/release) | `VideoTap.attach(to:)` (retain) + `tapFinalize` (release) | Mechanism |
| Render-thread DSP execution | `BiquadCascade.process` + balance gain step + `videoTapVisualizerRender` | Mechanism |
| ASBD format detection / DSP gating | `tapPrepare` reads ASBD into `VideoTapContext.processingFormat` | Mechanism |
| Visualizer hand-off (single-slot SPSC) | `VisualizerFeed` | Mechanism |
| Visualizer pre-computed array consumption | `VisualizerPipeline` | Bridge |
| Video item attach/detach lifecycle | `AudioPlayer` | Bridge |
| Sample-rate-dependent coefficient recompute | Triggered by `tapPrepare` ASBD change → `VideoTapContext.handleSampleRateChange(_:)` → `EqualizerController.recomputeForSampleRate(_:)` | Mechanism → Bridge |

---

## 6. Implementation Phases

Each phase is individually reviewable and individually testable. Each phase ends with TSan-on build + test green; no phase merges to `main` (single PR at end of Phase 8 / 9).

### Phase 1 — `VisualizerFeed` + `VisualizerScratchBuffers` extraction

**Goal.** Promote the two private nested types in `VisualizerPipeline.swift` to module-internal so the future video-tap render function can use them. Engine path behavior: byte-for-byte identical.

**Files.**
- `MacAmpApp/Audio/VisualizerPipeline.swift`: rename `VisualizerSharedBuffer` → `VisualizerFeed` (L36); promote both classes from `private` to file-scope (or extract); update field type at L330 (`sharedBuffer: VisualizerSharedBuffer` → `feed: VisualizerFeed`); update parameter type in `makeTapHandler` signature at L565.
- New: `MacAmpApp/Audio/VisualizerFeed.swift` — extracted body of `VisualizerSharedBuffer`, renamed.
- New (optional): `MacAmpApp/Audio/VisualizerScratchBuffers.swift` — extracted body. If keeping nested for cohesion with `VisualizerPipeline`, drop `private` modifier instead.

**Verification.**
- TSan-on test suite: 110/110 (matches saved branch's full surface) or current count, no new failures.
- Manual smoke: load a music file, verify spectrum bars + Butterchurn animate identically to pre-change behavior.
- Run `xcodegen generate` once.

**Exit criteria.** Engine-path test surface unchanged; new types are visible to `MacAmpApp/Audio/VideoDSP/` (Phase 2 onward).

**Estimated LOC.** ~30 modified, ~100-150 new (across 1-2 files).

---

### Phase 2 — Production tap scaffold (Context + lifecycle + ASBD guard + leak fix; pass-through DSP)

**Goal.** Build the production tap end-to-end with the C-callback machinery, `Unmanaged` lifetime, ASBD format guard (ADR-11), and tap-create failure release path (ADR-10) — but **NO** biquad math yet. The tap reads source audio in place and writes it back unchanged. Video plays with audible audio (no DSP applied).

**Files.**
- New: `MacAmpApp/Audio/VideoDSP/VideoTapContext.swift`
  - `final class VideoTapContext: @unchecked Sendable`
  - Atomic state: `coefficientSetPointer: Atomic<UnsafePointer<BiquadCoefficientSet>?>` (ADR-4 — pointer can be nil during pass-through), `balance: Atomic<UInt32>` (Float bit-pattern, default 0.5), `isActive: Atomic<Bool>`, `processingFormatTag: Atomic<UInt32>` (encoded ASBD-validity bit-mask), `processCallCount: Atomic<UInt64>` (telemetry), `frameCount: Atomic<UInt64>` (telemetry).
  - Methods: `init`, `deinit` (deallocate coefficient blocks), `installCoefficientSet(_ new: BiquadCoefficientSet)` (called from main thread), `currentCoefficients() -> UnsafePointer<BiquadCoefficientSet>?` (called from render thread).
- New: `MacAmpApp/Audio/VideoDSP/VideoTap.swift`
  - `enum VideoTapError: Error` (createFailed, formatUnsupported, etc.)
  - File-scope `private let tapInit/Finalize/Prepare/Unprepare/Process` C-callback closures (per-callback bodies described below).
  - `static func attach(to playerItem: AVPlayerItem, context: VideoTapContext) throws` — builds callbacks struct, calls `MTAudioProcessingTapCreate` with ADR-10 release-on-fail, builds `AVMutableAudioMix` + `AVMutableAudioMixInputParameters`, assigns `playerItem.audioMix`. Note: per ADR-7, `audioMix` is set ONCE here.
  - `static func detach(from playerItem: AVPlayerItem)` — sets `playerItem.audioMix = nil`. AVPlayer's chain handles `tapFinalize` async.
- Modify: `MacAmpApp/Audio/AudioPlayer.swift`
  - Add: `private var videoTapContext: VideoTapContext?` (one-tap-per-item invariant; replaced on item swap)
  - Add: facade `attachVideoTap(to playerItem: AVPlayerItem)` and `detachVideoTap(from playerItem: AVPlayerItem)`
  - Wire to existing video playback flow (existing `WinampVideoWindowController` likely creates the AVPlayer/AVPlayerItem; intercept after `AVPlayerItem` construction, before `play()`).

**Tap callback bodies (Phase 2 versions):**
- `tapInit`: `tapStorageOut.pointee = clientInfo` (already-retained Unmanaged).
- `tapFinalize`: `Unmanaged<VideoTapContext>.fromOpaque(storage).release()`.
- `tapPrepare`: read `processingFormat.pointee` (ASBD); store into `VideoTapContext.processingFormatTag` (bit-mask: 0 = supported Float32 LPCM, 1 = unsupported pass-through, 2 = sample-rate change since last prepare). Log once per prepare.
- `tapUnprepare`: log; no state change.
- `tapProcess`:
  ```swift
  // 1. Pull source audio in place. The flagsOut pointer is shared between this tap's
  //    output flags and the source's output flags — GetSourceAudio writes the source's
  //    StartOfStream/EndOfStream into it, which we both read here AND propagate downstream.
  let getStatus = MTAudioProcessingTapGetSourceAudio(
      tap, framesToProcess, bufferList, flagsOut, /* timeRangeOut */ nil, framesOut)
  guard getStatus == noErr else { return }

  // 2. Format gate (ADR-11)
  if context.processingFormatTag.load(ordering: .relaxed) != formatTagSupportedFloat32 {
      return  // pass-through (no DSP)
  }

  // 3. (Phase 2 stops here — Phase 3 adds steps 3-7 from ADR-5 render-path order.)
  ```

**Verification.**
- Unit test: `VideoTap.attach` with a synthetic `AVPlayerItem` succeeds; `detach` releases. Test the create-failure path by injecting a corrupted callbacks struct (or by inserting a `MTAudioProcessingTapCreate` mock if feasible) — assert `Unmanaged` is released.
- TSan-on integration test: video clip plays, callbacks fire (counters non-zero), no leak.
- Manual smoke on all 5 clapperboard clips: each plays normally.
- Allocations Instruments: video playback start → end → Context allocation count = N items played; deallocation count = N (no leak).

**Exit criteria.** Video plays normally with the tap installed but no DSP applied. Lifecycle is clean (no leak under TSan + Allocations). ASBD guard correctly disables/enables the (pass-through) DSP path on Float32 vs non-Float32 sources.

**Estimated LOC.** ~400 new, ~30 modified.

---

### Phase 3 — `BiquadCascade` + balance + numerical match verification

**Goal.** Implement the full audible DSP path: 10-band biquad cascade (RBJ cookbook) + balance gain. Add numerical-equivalence test vs `AVAudioUnitEQ`. Coefficient hand-off uses atomic-pointer double-buffer (ADR-4).

**Files.**
- New: `MacAmpApp/Audio/VideoDSP/BiquadCoefficientSet.swift`
  - `struct BiquadCoefficientSet { let bands: (BiquadCoefs, BiquadCoefs, ..., BiquadCoefs) }` (10 bands, fixed-size for Sendable conformance and to enable raw-pointer storage).
  - `static func compute(for state: EqualizerState, sampleRate: Double) -> BiquadCoefficientSet` — per-band RBJ formulas (ADR-8).
- New: `MacAmpApp/Audio/VideoDSP/BiquadCascade.swift`
  - Stateful per-channel filter history (`z1`, `z2` per band per channel).
  - `mutating func process(buffer: UnsafeMutableBufferPointer<Float>, channels: Int, frames: Int, coefficients: UnsafePointer<BiquadCoefficientSet>)` — in-place direct-form-II biquad, 10 bands cascaded, per channel.
  - `mutating func reset()` — zero filter history (called on `kMTAudioProcessingTapFlag_StartOfStream` per ADR-9).
- Modify: `VideoTap.swift` `tapProcess` body — implement the full 8-step render path from ADR-5 (format gate already in Phase 2; this phase adds steps 2 through 6):
  1. (Already done in Phase 2) `MTAudioProcessingTapGetSourceAudio(...)` writes the source's `kMTAudioProcessingTapFlag_StartOfStream` / `_EndOfStream` into `flagsOut.pointee`.
  2. **Filter-state reset** (ADR-9): if `flagsOut.pointee.contains(.startOfStream)`, call `context.cascade.reset()`.
  3. **Preamp**: load `context.preampLinearGainBits.load(.relaxed)`, decode to Float; if not 1.0, multiply samples by preamp.
  4. **EQ on/off gate**: if `context.isEqOn.load(.relaxed) == false`, skip step 5.
  5. **`BiquadCascade.process`**: load coefficient pointer atomically; if non-nil, run 10-band cascade in place.
  6. **Balance**: load `context.balance.load(.relaxed)`, decode to Float; compute lGain/rGain (per-channel multiplies), apply if not center.
- New: `Tests/MacAmpTests/BiquadNumericalMatchTests.swift`
  - **Test 1 — full EQ active.** For each of 5 EQ presets (flat, bass-boost, treble-boost, mid-scoop, full-tilt-boost), render a 0 dBFS log sine sweep (20 Hz – 20 kHz, 10 s) through:
    1. `AVAudioUnitEQ` configured identically (offline render via `AVAudioEngine` `manualRenderingMode`).
    2. `BiquadCascade` configured identically (in-process Float32 array math).
    
    Compare per-frequency-bin magnitude. Assert ≤0.5 dB worst-case across the audible band; ≤1 dB hard reject.
  - **Test 2 — EQ-toggle bypass parity.** Render the same sweep with `isEqOn = false`. Assert `BiquadCascade` output is bit-identical to input scaled by preamp+balance only (no per-band attenuation). Assert engine-side `AVAudioUnitEQ.bypass = true` produces equivalent passthrough.
  - **Test 3 — preamp parity.** Render sine at 1 kHz, 0 dBFS, with bands flat and preamp values −12, −6, 0, +6, +12 dB. Assert `BiquadCascade` output magnitude matches input × `10^(preamp/20)` within ≤0.1 dB. Assert engine-side `AVAudioUnitEQ.globalGain` produces the same offset.
  - **Test 4 — balance parity.** Render stereo white noise at 0 dBFS with balance values 0.0, 0.25, 0.5, 0.75, 1.0. Assert `VideoTapContext` balance multiplies match engine-side balance node output channel-by-channel within ≤0.1 dB.

**Verification.**
- `BiquadNumericalMatchTests` green at ≤0.5 dB.
- Manual audible test: play video with EQ at "bass boost" preset; audible bass increase. Switch to "treble boost"; audible treble increase. Toggle EQ off; audio passes through clean.
- TSan-on test suite green.

**Exit criteria.** Audible EQ effect on video matches engine-path EQ effect (≤0.5 dB tolerance); balance audibly affects video L/R; filter state flushes on seek without artifacts.

**Estimated LOC.** ~250 new, ~30 modified to `VideoTap.swift`.

---

### Phase 4 — Visualizer DSP integration (video-tap render path)

**Goal.** Add the parallel render function `videoTapVisualizerRender` (ADR-6) that runs the same DSP as today's engine tap (mono mix + 20-bar RMS + Goertzel + 2048-pt FFT) into per-tap `VisualizerScratchBuffers`, then publishes via `VisualizerFeed.tryPublish`. Spectrum bars + Butterchurn animate from video audio.

**Files.**
- New: `MacAmpApp/Audio/VideoDSP/VideoTapVisualizerRender.swift`
  - `func videoTapVisualizerRender(bufferList: UnsafeMutablePointer<AudioBufferList>, frames: Int, sampleRate: Double, scratch: VisualizerScratchBuffers, feed: VisualizerFeed)`
  - Mono-mixes N channels (for audible-path 1/2/5.1/7.1 — surround uses `inferredSurroundChannelLayoutTag` downmix coefficients per Q5 allowlist; the visualizer feed contract is mono per ADR-6)
  - Runs RMS + Goertzel + vDSP FFT (matches `VisualizerPipeline.swift:579-658` engine implementation byte-for-byte)
  - Calls `feed.tryPublish(from: scratch, oscilloscopeSamples: 76, validFrameCount: frames)` (drop on contention)
- Modify: `VideoTapContext.swift`
  - Hold weak/owned reference to `VisualizerFeed` (shared instance) and owned `VisualizerScratchBuffers` (per-tap)
  - `init(...)` accepts both
- Modify: `VideoTap.swift` `tapProcess` — after balance step, call `videoTapVisualizerRender(...)`.
- Modify: `VideoTap.attach(to:)` factory — accepts `VisualizerFeed` (the shared instance held by `VisualizerPipeline`); allocates `VisualizerScratchBuffers` and passes both into `VideoTapContext`.
- Modify: `AudioPlayer.attachVideoTap(...)` — wires `VisualizerFeed` (resolved via `VisualizerPipeline`) into `VideoTap.attach`.

**Verification.**
- Manual: play video clip → spectrum bars animate. Play Butterchurn-mode → patterns react to audio.
- 5.1 surround clip: visualizer receives mono-downmixed signal; bars don't clip; Butterchurn animates.
- TSan-on: no contention warning on `VisualizerFeed` lock (trylock-drop already guards render thread; main-thread consumer at 30 Hz blocks normally).
- Performance smoke (Phase 8 has the formal benchmark): playback feels smooth, no audible glitches, no visible video stalls.

**Exit criteria.** Spectrum + Butterchurn animate from video audio across all 5 clapperboard clips. Engine-path visualizer behavior unchanged.

**Estimated LOC.** ~150 new, ~50 modified.

---

### Phase 5 — EQ and balance state fanout (parallel from `EqualizerController` + `AudioPlayer`)

**Goal.** Wire EQ fanout from `EqualizerController` and balance fanout from `AudioPlayer` (ADR-5 — two canonical owners, parallel fanout). Both feed the new tap-side `VideoTapContext` in addition to their existing engine consumers.

**Files.**
- Modify: `MacAmpApp/Audio/EqualizerController.swift`
  - Add private nested type: `struct EqualizerState: Sendable, Equatable { let isEqOn: Bool; let preampLinearGain: Float; let bandGainsDB: (Float, Float, Float, Float, Float, Float, Float, Float, Float, Float) }`
  - Add private nested type: `final class WeakBox<T: AnyObject> { weak var value: T?; init(_ v: T) { self.value = v } }`
  - Add: `private var registeredVideoTapContexts: [WeakBox<VideoTapContext>] = []` (weak refs; Context lifecycle owned by `AudioPlayer`).
  - Add: `func registerVideoTapContext(_ context: VideoTapContext, sampleRate: Double)` — appends weak ref; computes `BiquadCoefficientSet` at the given sample rate; pushes via `context.installCoefficientSet(_:)`; pushes `isEqOn` and `preampLinearGain` atomics.
  - Add: `func unregisterVideoTapContext(_ context: VideoTapContext)` — removes ref by identity.
  - Add: `func handleSampleRateChange(_ context: VideoTapContext, newSampleRate: Double)` — recomputes coefficient set for the new rate and pushes via `installCoefficientSet`. Called from main-thread polling (see sample-rate handling below).
  - Modify: existing EQ slider / preset / preamp change handlers — after writing to engine `AVAudioUnitEQ`, iterate `registeredVideoTapContexts` (skipping nil refs), call appropriate atomic-write helpers per context. The EQ-state struct is captured into a local before the loop to avoid re-reading state per iteration.
- Modify: `MacAmpApp/Audio/AudioPlayer.swift`
  - Add: `private var registeredVideoTapContexts: [WeakBox<VideoTapContext>] = []` (separate registry for balance fanout).
  - Modify: `var balance: Float { didSet { ... } }` (existing) — after writing to engine balance, iterate `registeredVideoTapContexts` and write Float bit-pattern to each Context's `balance` atomic.
  - Add: `func attachVideoTap(to playerItem: AVPlayerItem, sampleRate: Double) throws -> VideoTapContext` — builds Context, calls `VideoTap.attach(...)` (ADR-7, ADR-10), registers Context with both `equalizerController.registerVideoTapContext(context, sampleRate: sampleRate)` and `self.registeredVideoTapContexts`, returns the Context (for caller to retain through item lifetime).
  - Add: `func detachVideoTap(_ context: VideoTapContext, from playerItem: AVPlayerItem)` — unregisters from both registries, calls `VideoTap.detach(from: playerItem)`.
- **Sample-rate handling.** Decision: **polled atomic** (no `Notification`). `tapPrepare` writes the new sample rate to `VideoTapContext.pendingSampleRate: Atomic<UInt64>` (Double bit-pattern stored as UInt64). `VisualizerPipeline`'s existing 30 Hz main-thread `Timer` (which already polls visualizer state) gets a small added check: for each registered Context, if `pendingSampleRate` differs from the last seen value, call `equalizerController.handleSampleRateChange(...)`. Justification: avoids a new actor hop on a high-frequency event; piggybacks on existing main-thread polling.

**Verification.**
- Unit test: register a `VideoTapContext` at 44.1 kHz; call `EqualizerController.setBandGain(_:band:)`; assert the Context's coefficient pointer changed AND the new coefficients match RBJ formula at 44.1 kHz.
- Unit test: change `AudioPlayer.balance`; assert all registered Contexts' `balance` atomics updated.
- Manual: drag EQ slider during video playback → audio changes in real time. Drag balance slider → audio pans in real time.
- Engine-path regression: with EQ slider dragged during AUDIO file playback, audio changes (existing behavior unchanged).
- TSan-on test suite green.

**Verification.**
- Unit test: register a `VideoTapContext`; call `EqualizerController.setBandGain(_:band:)`; assert the Context's coefficient pointer changed.
- Manual: drag EQ slider during video playback → audio changes in real time. Drag balance → audio pans.
- Engine-path regression: with EQ slider dragged during AUDIO file playback, audio changes (existing behavior unchanged).
- TSan-on test suite green.

**Exit criteria.** EQ + balance fan-out works for both engine and tap consumers. User cannot perceive any latency or inconsistency between engine path and tap path during slider drags.

**Estimated LOC.** ~80 modified to `EqualizerController.swift`, ~30 modified to `AudioPlayer.swift`.

---

### Phase 6 — Production telemetry (deadline-miss instrumentation)

**Goal.** Add the deadline-miss instrumentation called for in `spike-findings.md` "Production-translation hazards" item 3 — necessary for the Phase 8 CPU benchmark gate and for production observability of "EQ doesn't work on this video" reports.

**Files.**
- Modify: `VideoTap.swift` `tapProcess`
  - Sample-and-alarm: every Nth callback (e.g. N=64, ~2-3 Hz at typical buffer sizes), capture `mach_absolute_time()` at entry and exit. Compute delta in nanoseconds (using `mach_timebase_info_data_t`).
  - Compare delta to buffer wall-clock budget (`framesToProcess / sampleRate * 1e9`).
  - If delta > 10 % of budget, atomically increment `VideoTapContext.budgetOverrunCount`. If delta > 50 %, atomically increment `VideoTapContext.deadlineRiskCount` and log once-per-second (rate-limited via host-time gate atomic).
- Modify: `VideoTapContext.swift`
  - Add: `let budgetOverrunCount: Atomic<UInt64>(0)`, `let deadlineRiskCount: Atomic<UInt64>(0)`, `let lastLoggedHostTime: Atomic<UInt64>(0)`.
  - Add: `var diagnosticSnapshot: VideoTapDiagnostics { ... }` that returns a `Sendable` snapshot for main-thread display / logs.

**Verification.**
- Unit test: inject a synthetic delay in `tapProcess` (debug-only, gated by `_test` seam) → assert `budgetOverrunCount` increments.
- Manual: stress test with all 10 EQ bands at +24 dB on Apple Silicon, observe overrun counts (expected: 0 over 30 s playback). Repeat with intentionally heavier load (e.g. simulated extra DSP) → counts increase as expected.

**Exit criteria.** Telemetry visible in Console (filtered by subsystem). Phase 8 CPU benchmark uses these counters to assert pass/fail.

**Estimated LOC.** ~80 modified to `VideoTap.swift` + `VideoTapContext.swift`.

---

### Phase 7 — Lifecycle + production tests

**Goal.** Exhaustive lifecycle test coverage. Catches the failure modes documented in the Tap Lifecycle Contract (research.md): rapid track skip, tap-create failure, pause/resume, seek, item replacement during playback, signed-bundle smoke.

**Files.**
- New: `Tests/MacAmpTests/VideoTapLifecycleTests.swift`
  - Test: 10 tap create/attach/play/replace cycles in 1 s — no leak (assert via `Unmanaged`-balance accounting in `_test*` seam).
  - Test: tap-create injected failure path — Context is released, no leak (uses `_testForceTapCreateFailure` seam).
  - Test: attach + immediate stop before any `tapProcess` invocation — `tapFinalize` still fires.
  - Test: pause + resume cycle — Context state preserved (atomic counters increment monotonically).
  - Test: seek mid-playback — `BiquadCascade.reset()` invoked (verified via `_testFilterStateZero` seam).
  - Test: `replaceCurrentItem(with: nil)` during active `tapProcess` — no UAF (verified via TSan + asan if available; baseline = no crash).
- Manual: build + sign a Debug `.app` (per `docs/RELEASE_BUILD_GUIDE.md` minus notarization for Debug); play video → confirm tap behavior matches the unsigned CLI spike (tap fires, EQ audible).

**Verification.**
- All lifecycle tests TSan-green.
- Signed Debug `.app` smoke test: video plays, EQ audible, no leak in Allocations Instruments over 1-minute playback.

**Exit criteria.** Lifecycle is bulletproof; signed-bundle smoke test passes.

**Estimated LOC.** ~250 new (test file).

---

### Phase 8 — Verification matrix execution + state.md update

**Goal.** Execute every gate from research.md "Verification gate matrix" (§7 below). Document results in `tasks/avplayer-native-video-dsp/state.md` (or a new `verification.md`). Any gate failure → stop, update plan, fix, retest.

**Tier 1 — static gates (one-time):**
1. **CPU benchmark.** Apple Silicon (M-series) + Intel build target, 3 clip configurations (44.1 stereo, 48 stereo, 48 5.1), baseline (pass-through tap) vs full chain (BiquadCascade + balance + visualizer DSP). Sampled over ≥30 s playback per configuration. Pass: 99th-percentile `tapProcess` wall-clock ≤10 % of buffer budget. Reject: any single sample >50 %.
2. **Numerical EQ match.** `BiquadNumericalMatchTests` (Phase 3). Pass: ≤0.5 dB worst-case across 5 presets × 20 Hz – 20 kHz. Reject: ≤1 dB.
3. **TSan.** Full `MacAmpApp` test suite green with `-enableThreadSanitizer YES`.

**Tier 2 — dynamic transition gates (each requires manual setup):**
4. **Long-playback drift.** ≥10 minutes continuous video playback (loop a short clip if no long source available). Pass: A/V sync within ±40 ms (visual confirmation; if measurable artifact appears, document and fail).
5. **Route-change matrix.** AirPods 1st-gen + AirPods Pro + AirPlay-1 receiver + AirPlay-2 receiver. For each: connect mid-playback / disconnect mid-playback. Pass: tap callbacks resume within 500 ms, no DSP-state loss (EQ still audible after route change), no silent output, no Console UAF/crash log.
6. **System default-output change.** Settings → Sound → Output device switch mid-playback (e.g. internal speakers ↔ HDMI display speakers). Pass: same as route-change.
7. **Bluetooth codec switch.** AAC ↔ SBC (forced via `Bluetooth Explorer` or CLI) mid-playback. Pass: tap callback continuity, no audio drop > 200 ms.
8. **Mid-playback format re-prepare.** AVPlayerItem audio-track swap (rare in MacAmp; testable via constructed multi-track item). Pass: `tapPrepare` re-fires; `tapProcess` resumes with new ASBD; coefficient recompute fires.
9. **Surround handling.** 5.1 clip plays through native AVPlayer downmix correctly (audible stereo or 5.1 depending on output device); visualizer feed downmix to mono is non-clipping; EQ applies uniformly across all 6 channels.
10. **Item replacement during playback.** `player.replaceCurrentItem(with: nextItem)` for video → audio file (and vice versa) at random points. Pass: outgoing item's `tapFinalize` fires; no leak; no UAF; ≤200 ms audio gap.

**Tier 3 — lifecycle gates** (covered by Phase 7 tests):
11. Rapid track skip (10 items in 1 s)
12. Tap-create failure path
13. Pause/resume cycle
14. Seek mid-playback
15. Signed-bundle smoke test

**Documentation.** Each gate's pass/fail signal recorded in `state.md` with date + commit SHA. Failures route to ADR amendment + Phase 7 retry.

**Exit criteria.** All 15 gates pass.

**Estimated LOC.** Documentation only (no new code unless a gate failure triggers a fix).

---

### Phase 9 — UI integration polish + final smoke

**Goal.** Ensure all video-window UI surfaces (EQ button, balance slider, visualizer mode toggle) are wired and behave end-to-end. Final smoke test on the unsigned debug build.

**Files.**
- Audit: `MacAmpApp/Windows/WinampVideoWindowController.swift`, `MacAmpApp/Views/WinampVideoWindow.swift` (and the chrome view at `MacAmpApp/Views/Windows/VideoWindowChromeView.swift`) — confirm EQ + balance + visualizer-mode UI surfaces exist for the video window context. Add menu items / wiring as needed (likely minimal; the existing video window already shares EQ + balance UI with the audio window via `AppSettings` / `EqualizerController` / `AudioPlayer`).
- Documentation: update `docs/VIDEO_WINDOW.md` with the new in-place tap DSP architecture (architecture section); update `docs/MACAMP_ARCHITECTURE_GUIDE.md` if the tap path adds cross-cutting concerns worth noting.

**Verification.**
- End-to-end: launch app, open video window, load video, toggle EQ, drag bands, drag balance, switch visualizer mode (spectrum ↔ Butterchurn). All work.
- TSan-on full test suite green.
- Pre-PR Codex Oracle review (per `feedback_sprint_workflow.md`).

**Exit criteria.** PR-ready.

**Estimated LOC.** ~20-50 modified, mostly to UI bridging.

---

## 7. Verification Gate Matrix Execution Plan

(See research.md "Verification gate matrix" for the canonical list. Phase 8 §6 above is the execution plan.)

| Tier | Gate | Phase that produces it | Phase that runs it |
|---|---|---|---|
| Static | CPU benchmark | Phase 6 (telemetry) | Phase 8 |
| Static | Numerical EQ match | Phase 3 (test) | Phase 3 + Phase 8 (re-confirm) |
| Static | TSan | Every phase | Phase 8 (final) |
| Dynamic | Long-playback drift | n/a | Phase 8 |
| Dynamic | Route-change matrix | n/a (architectural assertion) | Phase 8 |
| Dynamic | System default-output change | n/a | Phase 8 |
| Dynamic | Bluetooth codec switch | n/a | Phase 8 |
| Dynamic | Mid-playback format re-prepare | Phase 5 (sample-rate handler) | Phase 8 |
| Dynamic | Surround handling | Phase 4 (visualizer mono downmix) | Phase 8 |
| Dynamic | Item replacement during playback | Phase 2 (lifecycle) | Phase 8 |
| Lifecycle | Rapid track skip | Phase 7 (test) | Phase 7 |
| Lifecycle | Tap-create failure | Phase 2 (ADR-10) + Phase 7 (test) | Phase 7 |
| Lifecycle | Pause/resume | Phase 2 | Phase 7 |
| Lifecycle | Seek | Phase 3 (ADR-9) | Phase 7 |
| Lifecycle | Signed-bundle smoke | n/a | Phase 7 |

---

## 8. Risk Register

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
|---|---|---|---|---|---|
| R1 | Numerical EQ match >0.5 dB | LOW | MEDIUM | Phase 3 test gates implementation; ≤1 dB hard reject; if exceeded, RBJ formula audit + double-precision intermediates considered | Phase 3 |
| R2 | CPU budget exceeded on Intel | LOW | HIGH | Phase 6 telemetry detects; Phase 8 gate enforces; fallback strategy (lower-order biquad / fewer bands) documented in research.md Q3 | Phase 8 |
| R3 | Route change loses DSP state | UNKNOWN | HIGH | Phase 8 dynamic gates exercise all 4 route types; fix path: `tapPrepare` re-fires on route change → coefficient recompute via Phase 5 sample-rate handler | Phase 8 |
| R4 | `tapFinalize` doesn't fire after `replaceCurrentItem` | LOW | HIGH | Phase 7 lifecycle test asserts; if it fires async only, document the timing + add "tap is alive" atomic for fast-skip safety | Phase 7 |
| R5 | `MTAudioProcessingTap` survives item replacement and reuses Context | UNKNOWN | LOW | One-tap-per-item invariant (ADR-7) makes this moot — each item builds a fresh tap | Phase 2 |
| R6 | Render-thread overrun causes audible glitch | MEDIUM | MEDIUM | Phase 6 telemetry detects; Phase 8 budget gate enforces; visualizer DSP is the largest single cost — drop-on-contention via `tryPublish` already protects against pathological cases | Phase 6 |
| R7 | Coefficient pointer atomic correctness | NEGLIGIBLE | n/a | No CAS loop is used (the swap is a single `store(_:ordering:)`), so ABA isn't applicable. The two-block double-buffer guarantees the render thread reads either the old block or the new block, never a torn intermediate state | n/a |
| R8 | `Synchronization.Atomic<T>` Sendable assumption wrong on a future Swift version | NEGLIGIBLE | LOW | Pinned to Swift 6.2+, macOS 15+; `Atomic` is stdlib type with `Sendable` conformance documented | n/a |
| R9 | Spike branch's `*= gain` simplicity hides surround channel layout edge case | LOW | MEDIUM | Phase 8 gate 9 explicitly tests 5.1 surround clip; ASBD format guard (ADR-11) gates DSP enable | Phase 8 |
| R10 | UI integration surfaces missing for video-window EQ/balance | MEDIUM | LOW | Phase 9 audit pass; wiring is incremental | Phase 9 |
| R11 | `xcodegen generate` race / project.yml conflict on parallel branches | LOW | LOW | This is the only S3 task in flight that adds new files in `MacAmpApp/Audio/` → no conflict (S3-3, S3-4 land later; rebase order documented in §11) | §11 |

---

## 9. Stop Criteria / Kill Switches

This task abandons (and the architecture pivots again) if any of these fail:

1. **Phase 3 numerical EQ match: >1 dB worst-case** vs `AVAudioUnitEQ` across 20 Hz – 20 kHz on any of the 5 standard presets. RBJ cookbook is the published Apple-derived formula; if it doesn't match, something is wrong with our implementation OR Apple isn't using stock RBJ. Investigate before proceeding.
2. **Phase 8 CPU benchmark: 99th-percentile >10 %** of buffer budget on Apple Silicon, OR any single sample >50 % on either platform. Indicates the architecture cannot meet the deadline. Mitigations: lower-order biquad (8-band? cascade order reduction?), drop visualizer DSP for video (audible-only path), or pivot back to engine-routing with a fundamentally different ring strategy.
3. **Phase 8 route-change matrix: any AirPods/AirPlay disconnect causes DSP-state loss or persistent silent output.** Indicates AVPlayer's native route handling has a hole the architecture didn't anticipate. Mitigations: explicit route observer (HAL property listener — DENY-listed, but reconsider), or accept the loss and document.
4. **Phase 7 lifecycle test: leak detected in rapid-skip or tap-create-failure paths.** Indicates `Unmanaged` discipline is broken. Mitigations: audit retain/release accounting, add `_testTapBalance` seam to assert.
5. **Phase 8 long-playback: A/V drift >40 ms over 10 minutes.** Indicates the single-clock-domain assumption is wrong (unlikely, since AVPlayer's own clock drives both). Mitigations: investigate AVPlayer-internal queue behavior; document; potentially deliver without long-playback guarantee.

If a kill switch fires:
- Pause the branch; do not merge.
- Document in `state.md` with diagnosis + commit SHA.
- Update plan.md (new ADR or amend existing); re-run Oracle.
- Resume from the failing phase or pivot architecture.

---

## 10. Test Plan

| Layer | Tests | Phase |
|---|---|---|
| Unit (BiquadCascade) | RBJ formula correctness; per-band coefficient values match published RBJ table at 1 kHz, +6 dB, BW=1.0; reset() zeros filter state | 3 |
| Unit (BiquadCoefficientSet) | Sample-rate change recomputes; preset values map to expected coefficient signatures | 3 |
| Unit (VideoTapContext) | Atomic-pointer swap is observed by render-thread mock; `installCoefficientSet` doesn't allocate | 2 |
| Integration (numerical match) | Log sweep through both `AVAudioUnitEQ` and `BiquadCascade`, ≤0.5 dB across 5 presets | 3 |
| Integration (lifecycle) | 10 rapid track skips no leak; create-fail releases Context; pause/resume preserves state; seek resets filter state | 7 |
| Integration (DSP application) | `tapProcess` modifies buffer; AVPlayer plays modified buffer (auditory + spectrum capture via `_testTapOutputCapture` seam) | 2-5 |
| Manual (end-to-end) | All 5 clapperboard clips play with EQ; visualizer animates from video; balance affects video L/R; route-change scenarios per Phase 8 | 8 |
| Manual (signed-bundle smoke) | Build + sign Debug `.app` per `docs/RELEASE_BUILD_GUIDE.md` (no notarization), play video, EQ audible, no leak | 7 |
| Performance (CPU benchmark) | `tapProcess` wall-clock 99th-percentile ≤10 % buffer budget on AS + Intel × 3 clip configs | 8 |
| TSan | Full `MacAmpApp` test suite green at every phase boundary | every |

---

## 11. Conflict Map (file conflicts with peer / successor branches)

This branch is the only S3 task currently in flight; no peer branches.

**Successor branches that will rebase onto `feat/avplayer-native-video-dsp`:**
- **S3-3 `feat/hls-streaming-support`.** Touches `MacAmpApp/Audio/StreamDecodePipeline.swift` and `MacAmpApp/Audio/StreamPlayer.swift`. **No overlap with this plan** (this plan does not touch those files). No rebase conflict.
- **S3-4 `feat/ogg-vorbis-support`.** Same files as S3-3. **No overlap.**

**Files this plan touches that might conflict with other in-flight work:**
- `MacAmpApp/Audio/EqualizerController.swift` — the deferred `timer-scheduled-on-common-extension` task (per `tasks/_context/resume-prompt.md`) does NOT touch this file. No conflict.
- `MacAmpApp/Audio/AudioPlayer.swift` — same; no overlap.
- `MacAmpApp/Audio/VisualizerPipeline.swift` — same; no overlap.

**Rebase order if S3-3 / S3-4 land later:**
- S3-2 (this) → S3-3 → S3-4 (chronological).
- S3-3 / S3-4 add new files; no rebase conflict expected.

---

## 12. Rollback Plan

This task adds new files (`VideoDSP/` module) and modifies a small number of existing files. Rollback strategy:

1. **If a kill switch fires (§9):** revert the failing phase's commits via `git revert <SHA>` on the branch; keep prior phases' progress. Restart from the failing phase.
2. **If the entire architecture must abandon:** the branch is throwaway. Switch back to `feat/video-audio-engine-routing` (saved-as-reference) and resume there with new mitigations. The new task folder `tasks/avplayer-native-video-dsp/` is preserved as a "what we tried, why it failed" reference.
3. **If specific commits cause regressions discovered post-merge:** `git revert <SHA>` on `main` for the offending commit(s); fix forward in a new task.
4. **Engine path is never at risk.** All modifications to `EqualizerController`, `AudioPlayer`, `VisualizerPipeline` are additive (new methods, type renames at the boundary). The engine code path remains byte-for-byte identical (per Phase 1 exit criterion). Rolling back the new tap module restores audio-side behavior with no engine-side regression.

**Cleanup at S3-2 close (post-merge):**
- Delete local branch `spike/avplayer-inplace-tap-dsp` (throwaway).
- Move `tasks/avplayer-native-video-dsp/` → `tasks/done/avplayer-native-video-dsp/` (per project workflow).
- Update `tasks/_context/resume-prompt.md`, `tasks/_context/state.md`, `tasks/_context/tasks_index.md`.
- Mark `tasks/_context/s3-2-pivot.md` as resolved.
- Single `chore: close out avplayer-native-video-dsp (PR #C)` commit.

---

## 13. Open Implementation Questions (deferred to phase boundaries; not research gaps)

These items are documented for resolution during the named phase. They are **not** architectural decisions (those are settled in §4 ADRs) — they are tactical choices that depend on observed runtime behavior or developer-time judgment.

| Q | Phase | Default if unresolved at phase start | Notes |
|---|---|---|---|
| Does `tapFinalize` fire synchronously on `replaceCurrentItem` or async? | 2 | Assume async (per ADR-7 default) | Phase 7 lifecycle tests observe empirically. If sync, simplify tear-down — but plan does not depend on it. |
| Add a "tap is alive" atomic on Context for fast item-switch pre-emption? | 7 | No (per ADR-7 default) | Add only if Phase 7 lifecycle tests demonstrate a UAF window. |
| `VisualizerScratchBuffers` extracted to its own file or kept nested in `VisualizerPipeline.swift`? | 1 | Extract to own file | Both work; extraction is cleaner if Phase 4 grows the type's dependencies. |
| `VideoDSP/` module name — `VideoDSP/` vs `VideoTap/` vs `Video/` subdir? | 2 | `VideoDSP/` | Audio-side processing for the video path; orthogonal to the `Audio/` umbrella that owns engine-side work. |
| Visualizer disable for video — should there be a per-tap toggle, or is the visualizer always on? | 4 | Always on (matches engine path; toggle is an app-wide preference orthogonal to per-path) | Decided at Phase 4 implementation; plan as a no-op for now. |

---

## 14. Oracle iteration log

| Date | Round | Score | Findings | Action |
|---|---|---|---|---|
| (pending) | 1 | TBD | TBD | |

---

## 15. References

- `tasks/avplayer-native-video-dsp/research.md` — full research package (10/10 Oracle, commit `46bb6af`)
- `tasks/avplayer-native-video-dsp/research-notes/spike-findings.md` — Phase 0 spike empirical results + production-translation hazards
- `tasks/avplayer-native-video-dsp/research-notes/apple-docs.md` — TN2249 + SDK-header citations
- `tasks/avplayer-native-video-dsp/research-notes/eq-numerical-match.md` — RBJ cookbook + Apple parametric EQ design
- `tasks/avplayer-native-video-dsp/research-notes/saved-branch-retrospective.md` — allowlist/denylist with file:line citations
- `tasks/avplayer-native-video-dsp/research-notes/visualizer-feed.md` — `VisualizerPipeline` mapping
- `tasks/_context/s3-2-pivot.md` — strategic decision log
- `tasks/_context/principles.md` — 7 decomposition principles
- `tasks/done/stream-pause-tail/plan.md` — recent S3 plan exemplar
- `spike/avplayer-inplace-tap-dsp` — throwaway spike branch (kept locally)
