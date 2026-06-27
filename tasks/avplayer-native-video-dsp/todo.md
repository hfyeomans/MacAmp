# Todo: AVPlayer-Native Video DSP

> **Plan:** `tasks/avplayer-native-video-dsp/plan.md` (Oracle 9.8/10 final, commit `fdce0ed`)
> **Branch:** `feat/avplayer-native-video-dsp`
> **Status:** 🔧 IMPLEMENTING — Phase 1 ✅, Phase 2 ✅, Phase 3 NEXT.
> **Updated:** 2026-05-02

Numbering: `<Phase>.<Item>`. `[x]` complete, `[~]` in-progress, `[!]` blocked.

---

## Step 1 — Mechanical pivot ✅ COMPLETE (2026-05-01)

- [x] 1.1 Push `feat/video-audio-engine-routing` to origin as backup (preserved-as-reference)
- [x] 1.2 Cut `feat/avplayer-native-video-dsp` from `main` (`9cca40a`)
- [x] 1.3 Cherry-pick 13 Phase 1 commits (`3ed4356` → `2aa2f18`) — engine config observer
- [x] 1.4 Drop `wasVideoBridge` field from `PreReconfigureSnapshot` (commit `ffd77c1`)
- [x] 1.5 Build + TSan green (72/72)
- [x] 1.6 Scaffold `tasks/avplayer-native-video-dsp/` with 6 canonical files
- [x] 1.7 Create `tasks/_context/s3-2-pivot.md` three-step tracker
- [x] 1.8 Cross-reference pivot tracker from `_context/state.md`, `tasks_index.md`, `resume-prompt.md`
- [x] 1.9 Mark old branch + old task PAUSED-AS-REFERENCE

## Step 2 — Research phase ✅ COMPLETE (2026-05-01, Oracle 10/10 after 5 rounds)

- [x] 2.1 Phase 0 spike — `MTAudioProcessingTap` in-place buffer modification feasibility on `spike/avplayer-inplace-tap-dsp` (audible -20 dB A/B confirmed; programmatic write-verify; commit `dd53d64`)
- [x] 2.2 Apple docs deep research (sub-agent) — TN2249, `MTAudioProcessingTap.h` SDK header verbatim, `_PreEffects` flag selected (`research-notes/apple-docs.md`)
- [x] 2.3 Reference-branch retrospective (sub-agent) — 5-item ALLOWLIST + 11-item DENYLIST with file:line citations (`research-notes/saved-branch-retrospective.md`)
- [x] 2.4 `AVAudioUnitEQ` numerical-match research (sub-agent) — RBJ cookbook + Butterworth/octave-BW per Apple SDK header; ≤0.5 dB tolerance (`research-notes/eq-numerical-match.md`)
- [x] 2.5 Render-thread CPU budget (estimated; empirical benchmark gate landed in plan.md Phase 8)
- [x] 2.6 Channel-count / sample-rate handling — clapperboard corpus enumerated (4×stereo + 1×5.1, 44.1+48 kHz, 4 containers)
- [x] 2.7 `VisualizerFeed` extraction approach (sub-agent) — single-slot SPSC carrying pre-computed arrays (not raw PCM); rename + visibility-promote (`research-notes/visualizer-feed.md`)
- [x] 2.8 Synthesis to `research.md` — Architecture diagram + Topology deltas + Reuse policy + Tooling constraints + Step 2 findings (Q1-Q6) + Spike scope decision + plan.md prerequisites + Tap Lifecycle Contract + Concurrency Decision Record + Evidence Ledger
- [x] 2.9 Oracle research-pass review — 5 rounds (7.8 → 8.9 → 9.1 → 9.5 → 10/10), commits `4a80bf9` → `46bb6af`
- [x] 2.10 Phase 0 spike findings + production-translation hazards checklist landed in `research-notes/spike-findings.md`

## Step 3 — Plan phase ✅ COMPLETE (2026-05-02, Oracle 9.8/10 after 5 rounds)

- [x] 3.1 Draft `plan.md` from research synthesis (15 sections, 11 ADRs, 9 phases)
- [x] 3.2 Oracle round 1 — 8.3/10, 2 BLOCKER + 6 ACTIONABLE + 2 NIT (commit `dcb00d0`)
- [x] 3.3 Oracle round 2 — 8.9/10, 2 partial residuals (commit `a92d692`)
- [x] 3.4 Oracle round 3 — **10/10**, ready for implementation (commit `20c7ef1`)
- [x] 3.5 User architectural concern surfaced — `@unchecked Sendable` containment ("we should do this right instead of punting")
- [x] 3.6 Add ADR-3a Containment of `@unchecked Sendable` drift — header contract + `RenderThreadSafe` marker + DEBUG Mirror+source-level tests (commit `277e8f8`)
- [x] 3.7 Oracle round 4 — 9.2/10, 1 BLOCKER (Mirror can't see `let` vs `var`) + 2 ACTIONABLE + 1 NIT
- [x] 3.8 Round 4 fixes — Gate 3 split into 3a (Mirror) + 3b (source-level regex); Gate 2 conformance-centralization rule; primitive blanket conformances removed; Phase 9 docs spec distinguishes implicit vs explicit-gated; commit `ba5a64e`
- [x] 3.9 Oracle round 5 — **9.8/10**, ready for implementation (commit `fdce0ed`)
- [x] 3.10 User sign-off received 2026-05-02
- [x] 3.11 Audit + update stale `_context/` and task-level `.md` files (state, tasks_index, resume-prompt, s3-2-pivot, task state.md, research.md banner, plan.md status)
- [x] 3.12 Derive `todo.md` (this file) from plan.md §6 phases

---

## Phase 1 — `VisualizerFeed` + `VisualizerScratchBuffers` extraction

**Goal.** Promote two private nested types in `VisualizerPipeline.swift` to module-internal so the future video-tap render function can reuse them. Engine path: byte-for-byte identical.
**Plan ref:** plan.md §6 Phase 1.
**Files:** `MacAmpApp/Audio/VisualizerPipeline.swift` (modify), `MacAmpApp/Audio/VisualizerFeed.swift` (new), `MacAmpApp/Audio/VisualizerScratchBuffers.swift` (new — extract per §13 default).

- [x] 1.1 Re-read `MacAmpApp/Audio/VisualizerPipeline.swift` at HEAD — confirmed L36, L169, L330, L390, L451, L565-567, L657
- [x] 1.2 Create `MacAmpApp/Audio/VisualizerFeed.swift` — extracted `VisualizerSharedBuffer` body, renamed to `VisualizerFeed`, module-internal (~110 LOC)
- [x] 1.3 Create `MacAmpApp/Audio/VisualizerScratchBuffers.swift` — extracted `VisualizerScratchBuffers` + `GoertzelCoefficients` (intrinsic dependency), module-internal (~195 LOC)
- [x] 1.4 Updated `VisualizerPipeline.swift`: removed L29-310 (3 MARK sections — Shared Buffer, Goertzel Coefficients, Scratch Buffers)
- [x] 1.5 Field rename: `sharedBuffer = VisualizerSharedBuffer()` → `feed = VisualizerFeed()`
- [x] 1.6 `makeTapHandler` signature: `sharedBuffer: VisualizerSharedBuffer` → `feed: VisualizerFeed`
- [x] 1.7 Tap closure body call site: `sharedBuffer.tryPublish(...)` → `feed.tryPublish(...)`; `pollVisualizerData` `sharedBuffer.consume()` → `feed.consume()`
- [x] 1.8 `xcodegen generate` — clean
- [x] 1.9 `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — succeeded
- [x] 1.10 `xcodebuildmcp macos test  --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — **72/72 green, zero new failures**
- [ ] 1.11 Manual UI smoke (deferred to Phase 8 verification tier-3 lifecycle + signed-bundle smoke; engine-path test surface covers the regression risk)
- [x] 1.12 Commit: `Phase 1 (s3-2): extract VisualizerFeed + VisualizerScratchBuffers` (commit `146a8b4`)

---

## Phase 2 — Production tap scaffold + ADR-3a containment (pass-through DSP)

**Goal.** Build the production tap end-to-end with C-callback machinery, `Unmanaged` lifetime, ASBD format guard, tap-create failure release, AND ADR-3a's three containment gates — but NO biquad math yet (pass-through DSP).
**Plan ref:** plan.md §6 Phase 2 + ADR-3, ADR-3a, ADR-7, ADR-10, ADR-11.
**Files:** `MacAmpApp/Audio/RenderThreadSafe.swift` (new), `MacAmpApp/Audio/VideoDSP/VideoTapContext.swift` (new), `MacAmpApp/Audio/VideoDSP/VideoTap.swift` (new), `Tests/MacAmpTests/VideoTapSendableContractTests.swift` (new), `MacAmpApp/Audio/AudioPlayer.swift` (modify).

### Phase 2a — `RenderThreadSafe` marker protocol (ADR-3a Gate 2)

- [x] 2.1 Create `MacAmpApp/Audio/RenderThreadSafe.swift` with `internal protocol RenderThreadSafe: ~Copyable {}` (the `~Copyable` marker is required so `Synchronization.Atomic`/`Mutex` can conform — Swift 6 makes them `~Copyable` by design)
- [x] 2.2 Add documentation comment specifying conformance contract + the centralization rule (all conformances live in this file)
- [x] 2.3 Add `extension Atomic: RenderThreadSafe`
- [x] 2.4 Add `extension Mutex: RenderThreadSafe`
- [x] 2.5 Add `extension Optional: RenderThreadSafe where Wrapped: RenderThreadSafe`
- [x] 2.6 Add `extension UnsafePointer: RenderThreadSafe`, `extension UnsafeMutablePointer: RenderThreadSafe`, `extension UnsafeRawPointer: RenderThreadSafe`, `extension UnsafeMutableRawPointer: RenderThreadSafe`
- [x] 2.7 Add `extension AudioStreamBasicDescription: RenderThreadSafe` (POD C struct)
- [x] 2.8 Add `extension VisualizerFeed: RenderThreadSafe` and `extension VisualizerScratchBuffers: RenderThreadSafe` (Phase 1 outputs)
- [x] 2.9 Note: do NOT conform stdlib primitive value types (Bool, Int, Float, Double, etc.); per Phase 4-finding decision, primitives must be Atomic-wrapped

### Phase 2b — `VideoTapContext` with ADR-3a Gate 1 header contract

- [x] 2.10 Create `MacAmpApp/Audio/VideoDSP/` directory
- [x] 2.11 Create `MacAmpApp/Audio/VideoDSP/VideoTapContext.swift` with **ADR-3a Gate 1 header contract block** at the top of the file
- [x] 2.12 Implement `final class VideoTapContext: @unchecked Sendable` with stored fields:
   - [x] 2.12.1 `coefficientSetPointer: Atomic<UnsafePointer<BiquadCoefficientSet>?>` (ADR-4; nil during pass-through)
   - [x] 2.12.2 `balance: Atomic<UInt32>` (Float bit-pattern, default 0.5 = `Float(0.5).bitPattern`)
   - [x] 2.12.3 `isEqOn: Atomic<Bool>` (default false until Phase 5 wires the real state)
   - [x] 2.12.4 `preampLinearGainBits: Atomic<UInt32>` (Float bit-pattern, default 1.0)
   - [x] 2.12.5 `processingFormatTag: Atomic<UInt32>` (`formatTagUnknown`/`formatTagSupportedFloat32LPCM`/`formatTagUnsupported`)
   - [x] 2.12.6 `pendingSampleRate: Atomic<UInt64>` (Double bit-pattern, set by `tapPrepare`)
   - [x] 2.12.7 `processCallCount: Atomic<UInt64>` (telemetry)
   - [x] 2.12.8 `frameCount: Atomic<UInt64>` (telemetry)
   - [x] 2.12.9 `isActive: Atomic<Bool>`
- [x] 2.13 Implement `init` with double-buffer `BiquadCoefficientSet` block allocation (placeholder `BiquadCoefficientSet` empty-struct stub created at `MacAmpApp/Audio/VideoDSP/BiquadCoefficientSet.swift`; Phase 3 fills in the bands per `placeholder.md` P-1)
- [x] 2.14 Implement `deinit` to `deinitialize(count: 1).deallocate()` the two coefficient blocks
- [x] 2.15 ~~Implement `installCoefficientSet(_:)`~~ — **WITHDRAWN before Phase 2 close per Oracle BLOCKER finding (placeholder P-4); Phase 3 must redesign the hand-off scheme.** Initial implementation landed in commit `ac7e0d5`, removed in Revisions 1-6. Two pre-allocated coefficient blocks remain for alloc/dealloc lifecycle exercise.
- [x] 2.16 Add `#if DEBUG` `static func _makeForContractTest() -> VideoTapContext` factory

### Phase 2c — `VideoTap` C-callbacks + lifecycle

- [x] 2.17 Create `MacAmpApp/Audio/VideoDSP/VideoTap.swift`
- [x] 2.18 Declare `enum VideoTapError: Error` with `createFailed(OSStatus)` + `noAudioTrack` cases
- [x] 2.19 Define file-scope `private let tapInit: MTAudioProcessingTapInitCallback`
- [x] 2.20 Define file-scope `private let tapFinalize: MTAudioProcessingTapFinalizeCallback` — `Unmanaged<VideoTapContext>.fromOpaque(storage).release()` exactly once
- [x] 2.21 Define file-scope `private let tapPrepare: MTAudioProcessingTapPrepareCallback` — read ASBD, write `processingFormatTag` (`formatTagSupportedFloat32LPCM` if `kAudioFormatLinearPCM && IsFloat && 32-bit`, else `formatTagUnsupported`); store `pendingSampleRate`; mark `isActive = true`
- [x] 2.22 Define file-scope `private let tapUnprepare: MTAudioProcessingTapUnprepareCallback` — mark `isActive = false`
- [x] 2.23 Define file-scope `private let tapProcess: MTAudioProcessingTapProcessCallback` — Phase 2 body: `MTAudioProcessingTapGetSourceAudio` + telemetry counters + format-tag gate; return after gate (pass-through, no DSP yet)
- [x] 2.24 Implement `static func attach(to:context:) async throws` — `@MainActor`-isolated; loads audio tracks via `await playerItem.asset.loadTracks(...)`; ADR-10 release-on-failure pattern via `Unmanaged.passRetained` + `retained.release()` on `MTAudioProcessingTapCreate` failure
- [x] 2.25 Build `AVMutableAudioMixInputParameters(track:)` + `AVMutableAudioMix`; assign `playerItem.audioMix` (per ADR-7, set ONCE)
- [x] 2.26 Implement `static func detach(from playerItem:)` `@MainActor` — set `playerItem.audioMix = nil`

### Phase 2d — `AudioPlayer` facade

- [x] 2.27 Add `@ObservationIgnored private var videoTapContext: VideoTapContext?` to `AudioPlayer`
- [x] 2.28 ~~Add facade `func attachVideoTap(to playerItem: AVPlayerItem)`~~ — **REPLACED by `startVideoLoad(track:)` orchestrator per Oracle BLOCKER finding (Option C structural fix).** Initial facade landed in commit `ac7e0d5`, removed in Revisions 1-6. The orchestrator + `audioMixBuilder` closure pattern installs `audioMix` during AVPlayerItem construction (before AVPlayer adopts the item) per ADR-7 amendment.
- [x] 2.29 Add facade `func detachVideoTap(_:from:)` and private helper `detachVideoTapIfNeeded()`
- [x] 2.30 Wire detach + attach into `AudioPlayer.playTrack` (line 397 — video case, between `loadVideo` and `transition(to: .playing)`); detach also wired into media-type-switch (line 383) and `stop()` (line 502)

### Phase 2e — ADR-3a Gate 3 contract test

- [x] 2.31 Create `Tests/MacAmpTests/VideoTapSendableContractTests.swift`
- [x] 2.32 Add `#if DEBUG` `@Suite("VideoTapContext @unchecked Sendable contract", .tags(.audio, .concurrency))`
- [x] 2.33 Implement Test 3a: `func allStoredFieldsConformToRenderThreadSafe()` — Mirror reflection over `VideoTapContext._makeForContractTest()`. **Documented coverage gap:** `~Copyable` `Atomic`/`Mutex` fields reflect as `Void` (`Mirror.Child.value: Any` requires `Copyable`); the test skips Void-typed children with an inline comment. Atomic/Mutex are safe by construction. See `placeholder.md` P-2.
- [x] 2.34 Implement Test 3b: `func allStoredVarsAreAtomicOrMutex()` — read `VideoTapContext.swift` source via `SRCROOT` (or `#filePath` fallback for SPM), regex-match `var name: Type` storage decls (excludes computed properties via `[^={\n]` exclusion), assert type begins with `Atomic<` or `Mutex<`

### Phase 2f — Verification

- [x] 2.35 `xcodegen generate` — clean
- [x] 2.36 `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — succeeded
- [x] 2.37 `xcodebuildmcp macos test  --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — **74/74 green** (72 baseline + 2 new contract tests). Test 3a + 3b green.
- [ ] 2.38 Unit test: `VideoTap.attach` with synthetic `AVPlayerItem` succeeds; `detach` releases. Inject create-failure (corrupted callbacks struct) — assert `Unmanaged` is released. **DEFERRED to Phase 7 lifecycle tests** per plan §6 Phase 7 §7.3 (more cohesive with the rest of the lifecycle suite; Phase 2's pass-through tap doesn't add lifecycle-specific risk beyond what Phase 7 covers)
- [x] 2.39 Manual smoke on all 5 clapperboard clips ✅ DONE 2026-05-02. All 5 clips (mp4 44.1/48 stereo + mov 48 stereo + m4v 44.1 stereo + mp4 48 5.1 surround) played with audio + video. New orchestration logs (`Cleanup complete` → `Time observer setup` → `Loading video file` → `Play` → metadata) fired in correct order on each. No `Video tap audio mix build failed` errors → tap attached successfully on all 5. Caught and fixed mid-test: P-5 video display regression (`@ObservationIgnored` on `VideoPlaybackController.player` masking async player assignment from view re-render — fix commit `c040e76`).
- [x] 2.40 Leak check ✅ DONE 2026-05-28 via Xcode Memory Graph Debugger (NOT Allocations Instruments — pure Swift classes like `VideoTapContext` bucket under `malloc<size>` in Allocations and never appear by class name; MGD shows them by name). Real-playback path: clip loaded+paused → `VideoTapContext` (1) + `VideoTapContext.coefficientBlockA` (1) + `VideoTapContext.coefficientBlockB` (1); then switch to an audio track (forces `.video→.audio` at AudioPlayer.swift:490 → `pauseAndDetachVideoTapIfNeeded` + `cleanup()` → AVPlayerItem drop → `tapFinalize`) → all three = 0. `Unmanaged.passRetained` (+1) balanced by `tapFinalize` (release); Context's owned coefficient buffers die with it. No leak, Phase-2-attributable (no Phase 3 code yet). Redundant with the 6 automated `VideoTapLifecycleTests` (synthetic path, green under TSan). Workflow doc: `tasks/_context/instruments-allocations-workflow.md`.
- [x] 2.41 Commit: `chore(s3-2): Phase 2 — production tap scaffold + ADR-3a containment` — pending

---

## Phase 3 — `BiquadCascade` + balance + numerical match

**Goal.** Implement full audible DSP: 10-band biquad cascade (RBJ cookbook) + balance gain. Add numerical-equivalence test vs `AVAudioUnitEQ`.
**Plan ref:** plan.md §6 Phase 3 + ADR-4, ADR-5, ADR-8, ADR-9.

- [x] 3.1 Create `MacAmpApp/Audio/VideoDSP/BiquadCoefficientSet.swift` ✅ — `BiquadCoefs` + `struct BiquadCoefficientSet` with fixed-size 10-tuple (heap-free, `Sendable`; manual `Equatable` since tuples block synthesis) + `withBands` contiguous accessor + `.flat`/`.identity`.
- [x] 3.2 Implement `static func compute(for:sampleRate:)` ✅ — RBJ octave-BW peaking (bands 1-8), RBJ low/high shelf S=1 (bands 0/9), `A=10^(dB/40)`; Double arithmetic, Float storage; band freqs coupled to `configureEQ` (drift guarded by 3.11).
- [x] 3.3 Add `EqualizerState: Sendable, Equatable` ✅ — top-level internal in `EqualizerController.swift` (`internal`, not `private nested`: forced by cross-file `compute` consumption) `{ isEqOn, preampLinearGain (10^(dB/20)), bandGainsDB: [Float] }` + `EqualizerController.equalizerState` projection for Phase 5.
- [x] 3.4 Create `BiquadCascade.swift` ✅ — `final class` (render-confined) with per-(band,channel) z1/z2 in manually-allocated buffers (no Array/CoW in the inner loop) + render-owned `currentCoefficients` cache.
- [x] 3.5 Implement `process(_:frameCount:channel:stride:)` ✅ — Transposed Direct-Form-II, 10 bands cascaded; per-channel with `stride` (handles non-interleaved stride=1 + interleaved stride=channels); reads `currentCoefficients`; skips `.identity` bands (zeroing their state).
- [x] 3.6 Implement `reset()` ✅ — zero z1/z2 (ADR-9).
- [x] 3.7 `extension BiquadCascade: RenderThreadSafe` ✅ ADDED — decision: BiquadCascade is a `let cascade` field on `VideoTapContext` (reached through a RenderThreadSafe-gated field), render-confined story. (NOT tap-storage; keeps it inside the already-retained Context → no new Unmanaged.)
- [x] 3.8 Refactor `VideoTapContext.swift` ✅ — removed `coefficientSetPointer` + `coefficientBlockA/B` + their alloc/dealloc (deinit now trivial); added `let coefficients: Mutex<BiquadCoefficientSet?>` (init `Mutex(nil)`) + `installCoefficients(_:)` (`withLock`); added `let cascade: BiquadCascade` (maxChannels 8); updated Gate-1 header contract field list. **BiquadCascade ownership = Context field (no separate retain) → 2.40 leak balance unchanged** (no re-verify trigger hit).
- [x] 3.9 Update `VideoTap.swift` `tapProcess` body ✅ — steps 2-6 implemented:
   - [x] 3.9.1 Step 2: reset on `kMTAudioProcessingTapFlag_StartOfStream` (bitwise — `MTAudioProcessingTapFlags` is a `UInt32` typealias, not an OptionSet) → `context.cascade.reset()`
   - [x] 3.9.2 Step 3: preamp — `Float(bitPattern: preampLinearGainBits)`; flat multiply over each buffer if !=1.0
   - [x] 3.9.3 Step 4: EQ gate — `if eqOn { … }`
   - [x] 3.9.4 Step 5: refresh cache via `coefficients.withLockIfAvailable { $0 }` with three-case double-optional handling; `cascade.process` per channel via `UnsafeMutableAudioBufferListPointer` iteration
   - [x] 3.9.5 Step 6: balance — `Float(bitPattern: balance)`; **[-1,1]/0.0-center law** (`VideoTap.balanceGains`, matches `AudioPlayer.balance`/`AVAudioNode.pan`; revised from [0,1]/0.5 per Oracle review), L/R gain multiplies, skip if center
- [x] 3.10 Create `Tests/MacAmpTests/BiquadNumericalMatchTests.swift` ✅ (**7 tests** + steady-state-RMS gain helpers + offline `AVAudioUnitEQ` render via `manualRenderingMode` with throw-on-incomplete).
- [x] 3.11 Test 1 — full-EQ magnitude match ✅ PASSED first try: 5 presets × 40 log-spaced freqs 20Hz–20kHz, worst-case ≤0.5 dB vs `AVAudioUnitEQ`. RBJ octave-BW peaking + S=1 shelves matched Apple with NO tuning.
- [x] 3.12 Test 2 — bypass parity ✅: cascade with nil coefficients AND with flat (all-0 dB → all `.identity`) coefficients are both bit-identical pass-through.
- [x] 3.13 Test 3 — preamp parity ✅: `EqualizerController.equalizerState.preampLinearGain` = `10^(dB/20)` for dB ∈ {-12,-6,0,+6,+12}; applied gain within 0.1 dB.
- [x] 3.14 Test 4 — balance law ✅ (now [-1,1]/0.0-center + clamp checks): center unity, full pan mutes far channel, half pans halve it. **Deviation from plan:** verifies the tap's balance law for *correctness*, NOT bit-parity vs `AVAudioPlayerNode.pan` (engine pan gain law is undocumented). Convention now matches the app so Phase 5 writes through; exact curve parity, if needed, is a Phase 5 concern.
- [x] 3.14b Added tests (Oracle review): `strideEquivalence` (interleaved stride-2 channel == non-interleaved stride-1), `resetClearsState` (post-reset == fresh cascade), `computeFailsClosed` (sampleRate≤0 / band≥Nyquist → `.flat`, else finite).
- [x] 3.15 `xcodegen generate` ✅
- [x] 3.16 Build + TSan green ✅ — **92/92 tests pass with TSan, no data races** (85 baseline + 7 numerical-match). `BiquadNumericalMatchTests` ≤0.5 dB.
- [x] 3.16b Codex Oracle code review ✅ — round 1 7/10 REVISE → 6 items fixed (balance convention, EQ-off reset, compute guards, maxChannels 16, shared freq constant, withBands assertion; declined full >16ch all-or-none as over-engineering); re-review 8.5/10 → Nyquist fail-closed added. Commits `84b9964` + `e2eba05`.
- [ ] 3.17 Manual smoke (audible EQ on video) — **DEFERRED to Phase 5.** Requires the EQ-state→tap fanout (`EqualizerController`/`AudioPlayer` → `Context.installCoefficients` + `isEqOn`/`preamp`/`balance` atomics) which Phase 5 builds; until then the tap's coefficients Mutex is never populated and EQ sliders don't reach the video tap. The DSP machinery itself is verified by the automated numerical-match tests. Audible smoke moves to Phase 5 acceptance.
- [x] 3.18 Commit ✅ — Phase 3 landed across `24f8a12` (core) + `4feec43` (tests) + `84b9964`/`e2eba05` (review fixes) + `6b8d24c` (docs).

---

## Phase 4 — Visualizer DSP integration (video-tap render path)

**Goal.** Add parallel `videoTapVisualizerRender` function consuming `AudioBufferList` (vs engine's `AVAudioPCMBuffer`); spectrum bars + Butterchurn animate from video audio.
**Plan ref:** plan.md §6 Phase 4 + ADR-6.

- [x] 4.1 Create `VideoTapVisualizerRender.swift` ✅
- [x] 4.2 Implement `videoTapVisualizerRender(bufferList:frames:sampleRate:scratch:feed:)` ✅
- [x] 4.3 Mono downmix N channels (non-interleaved + interleaved), per-buffer capped by `mDataByteSize`. **Deviation:** equal-weight average (NOT layout-aware surround coefficients) — matches the engine producer; the visualizer isn't the audible path. Oracle accepted; layout-aware downmix noted as a future refinement.
- [x] 4.4 20-bar RMS bucket — duplicated from `VisualizerPipeline.makeTapHandler` per ADR-6 (parallel producers; in-sync drift note in source). Oracle endorsed keeping the duplication (engine path untested; don't refactor it).
- [x] 4.5 20-bar Goertzel spectrum (first 1024 mono frames) ✅
- [x] 4.6 2048-pt Hann FFT via shared `scratch.processButterchurnFFT` ✅
- [x] 4.7 `feed.tryPublish(...)` (drop on contention) ✅
- [x] 4.8 `VideoTapContext` holds `feed: VisualizerFeed` (injected) + `scratch: VisualizerScratchBuffers` (owned per-tap); init → `init(feed:)`; Gate-1 contract updated; both `RenderThreadSafe`. Leak balance preserved (scratch Context-owned, no new Unmanaged). ✅
- [x] 4.9 `VideoTap.tapProcess` step 7 (after balance) calls `videoTapVisualizerRender` on the post-DSP buffer ✅
- [x] 4.10 ~~`VideoTap.attach` signature~~ — N/A (Phase 2 uses `buildAudioMix`, no `attach`); the feed reaches the tap via the Context (`init(feed:)`), not a builder param.
- [x] 4.11 `AudioPlayer.startVideoLoad` audioMixBuilder builds `VideoTapContext(feed: visualizerPipeline.sharedFeed)`; exposed `VisualizerPipeline.sharedFeed` ✅
- [x] 4.12 `RenderThreadSafe.swift` — no new types (feed/scratch already conform) ✅
- [x] **4.x CONSUMER WIRING (Oracle blockers, not in original plan):** the producer published but nothing consumed it for video. Added `VisualizerPipeline.start/stopVideoVisualization` (drive the 30 Hz poll timer for video, independent of the engine tap) + `AudioPlayer.isVisualizerRendering` (engine OR video) routing `getFrequencyData`, ungating `snapshotButterchurnFrame`, and `VisualizerView` spectrum + oscilloscope; hooked into playTrack .video / video→audio / stop / onPlaybackEnded / repeat-one `.restartCurrent`. ✅
- [x] 4.13 `xcodegen generate` ✅
- [x] 4.14 Build + TSan green — **98/98, no data races, no VisualizerFeed contention** ✅
- [x] 4.15 Manual smoke ✅ user-verified 2026-05-28 — video clip plays AND spectrum bars animate from video audio.
- [x] 4.16 Manual smoke ✅ user-verified 2026-05-28 — Butterchurn mode patterns react to video audio.
- [x] 4.17 Manual smoke ✅ user-verified 2026-05-28 — 5.1 surround clip: visualizer animates (equal-weight downmix).
- [x] 4.18 Engine-path regression ✅ user-verified 2026-05-28 — music file: spectrum + Butterchurn animate identically (engine path untouched). Plus oscilloscope-for-video + shaded-main playlist-window visualizer confirmed (todo 4.21).
- [x] 4.19 Commit ✅ — `92d0079` (impl) + `2884033` (consumer blockers) + `d475374` (completion/oscilloscope) + `1634dbd` (repeat-one).
- [x] 4.20 Codex Oracle review ✅ — arc 6 → 8 → 9.0 → **9.6/10 APPROVED** (2 blockers fixed: consumer poll-timer + UI ungating; lifecycle holes fixed: completion + repeat-one). Remaining 0.4 = diminishing-returns polish.
- [x] 4.21 Dual-window verification ✅ (user-reported, 2026-05-28) — confirmed the playlist-window mini-visualizer (shown when the main window is shaded) reuses the SAME `VisualizerView()` + shared `@Environment(AudioPlayer.self)` as the main window (instantiated in both `MainWindowFullLayer` + `WinampPlaylistWindow`), so all `isVisualizerRendering` gating flows to both — no separate path. Audited ALL `isEngineRendering` consumers; fixed one stray (the min-bar-height visibility floor in `VisualizerView.updateBars`, `VisualizerView.swift:102`) → now `isVisualizerRendering`. Commit `ea95f10`. User smoke tests 1-6 pass.

---

## Phase 5 — EQ + balance state fanout (parallel from `EqualizerController` + `AudioPlayer`)

**Goal.** Wire two canonical owners' fanout: EQ from `EqualizerController`, balance from `AudioPlayer`. Both push to engine + tap.
**Plan ref:** plan.md §6 Phase 5 + ADR-5.

- [x] 5.1 ✅ `WeakBox<T: AnyObject>` — shared internal in `MacAmpApp/Utilities/WeakBox.swift` (not duplicated per-file; used by both registries).
- [x] 5.2 ✅ `registeredVideoTapContexts: [WeakBox<VideoTapContext>]` on `EqualizerController` (`@ObservationIgnored`).
- [x] 5.3 ✅ `registerVideoTapContext(_:)` — append weak ref + immediately `pushEQState` (isEqOn + preamp atomics + compute+`installCoefficients` at the Context's `pendingSampleRate`).
- [x] 5.4 ✅ `unregisterVideoTapContext(_:)` — remove by identity + drop the last-rate record.
- [x] 5.5 ✅ `handleSampleRateChange(_:newSampleRate:)` — recompute + reinstall at the new rate.
- [x] 5.6 ✅ `fanOutToVideoTaps()` hooked into `preamp`/`eqBands`/`isEqOn` didSets (covers slider/preamp/toggle/preset). Now actually computes + installs coefficients via `installCoefficients` (P-4 closed in Phase 3). Fast-path no-op when no taps registered (engine/audio path unchanged).
- [x] 5.7 ✅ `WeakBox` shared (see 5.1) — not duplicated in AudioPlayer.
- [x] 5.8 ✅ `registeredVideoTapContexts` on `AudioPlayer` (`@ObservationIgnored`, separate balance registry).
- [x] 5.9 ✅ `balance.didSet` → `fanOutBalanceToVideoTaps()` writes Float bit-pattern ([-1,1]) to each Context's `balance` atomic.
- [x] 5.10 ✅ `startVideoLoad` audioMixBuilder registers the Context with BOTH owners (after `buildAudioMix`); `pauseAndDetachVideoTapIfNeeded` unregisters from both.
- [x] 5.11 ✅ Unregister routed through `pauseAndDetachVideoTapIfNeeded` (the single detach path; reached by stop / video→audio / video→video / completion).
- [x] 5.12 ✅ Sample-rate poll: `VisualizerPipeline.onPollTick` (decoupled hook) → `AudioPlayer` wires it to `equalizer.pollVideoTapSampleRates()`; recomputes when `pendingSampleRate` changes (catches EQ-on-at-video-start). last-rate dict avoids redundant recompute; poll compacts dead refs.
- [x] 5.13 ✅ `VideoTapFanoutTests`: register pushes state; EQ change fans out new coefficients (== RBJ compute); sample-rate poll recomputes flat→real; unregister stops fanout.
- [x] 5.14 ✅ `balanceFanout` test — `AudioPlayer.balance` updates a registered Context's atomic across {0.5,-1,0,1,-0.25}; stops after unregister. (register/unregister made `internal` as the test seam.)
- [x] 5.15 Build + TSan green ✅ — **103/103, no data races** (incl. cascade-confinement gate).
- [x] 5.16 Manual smoke ✅ user-verified 2026-05-28 — all 4 video scenarios pass: (1) drag EQ slider during video → audio changes real-time; (2) toggle EQ on/off → processed↔flat; (3) drag balance → audio pans L/R; (4) EQ-on-before-video applies on playback start (sample-rate poll). This is the deferred audible-EQ-on-video (was todo 3.17) — now LIVE and confirmed.
- [x] 5.17 Engine-path regression ✅ user-verified 2026-05-28 — EQ on a regular music file unchanged from before Phase 5 (the fanout fast-paths to no-op when no video tap is registered). Phase 5 fully verified.
- [x] 5.18 Commit ✅ — `e1f8a4e` (impl + tests + ADR-5 reconcile) + `252d3bc` (Oracle round-1 remediation).
- [x] 5.19 Codex Oracle review ✅ — round 1 **9/10 APPROVED** (1 ACTIONABLE balance test + 3 NITs) → all fixed → round 2 **10/10 APPROVED, no findings** (duplicate-path sweep clean). Two canonical owners (state ownership per ADR-5); render-confinement preserved (writes only Mutex/atomics).

---

## Phase 6 — Production telemetry (deadline-miss instrumentation)

**Goal.** Sample-and-alarm tap-callback wall-clock time; budget-violation counters for Phase 8 CPU benchmark gate.
**Plan ref:** plan.md §6 Phase 6 + spike-findings hardening item 3.

- [x] 6.1 ✅ `VideoTapContext` telemetry atomics: `budgetOverrunCount`, `deadlineRiskCount`, `lastDeadlineRiskHostTime` (renamed from `lastLoggedHostTime` per Oracle — logging was deliberately removed). All `Atomic<UInt64>`; Gate-1 header contract updated.
- [x] 6.2 ✅ `struct VideoTapDiagnostics: Sendable, Equatable` (snapshot of all counters).
- [x] 6.3 ✅ `var diagnosticSnapshot: VideoTapDiagnostics` (main-thread accessor, independent `.relaxed` loads — advisory snapshot).
- [x] 6.4 ✅ `tapProcess` samples every 64th callback (`callIndex & 63 == 0`, callIndex = pre-increment `processCallCount`); `mach_absolute_time` entry/exit over the full DSP+visualizer work — timing runs ONLY on sampled callbacks.
- [x] 6.5 ✅ ticks→nanos via cached `mach_timebase` (`videoTapMachTimebase` static let, prewarmed off the render thread in `buildAudioMix` per Oracle A1; 1:1 fast-path).
- [x] 6.6 ✅ budget = `frames / sampleRate * 1e9` (`sampleRate.isFinite && > 0` guarded).
- [x] 6.7 ✅ `recordProcessingDeadline` bumps `budgetOverrunCount` when `elapsed*10 > budget` (integer ratio, no float on render path).
- [x] 6.8 ✅ bumps `deadlineRiskCount` + stores host time when `elapsed*2 > budget`. **Deviation:** NO render-thread `os_log` (RT-safety) — counters surface via `diagnosticSnapshot` on the main thread instead. Oracle-endorsed.
- [x] 6.9 ✅ `VideoTapTelemetryTests` (7) — calls the pure `recordProcessingDeadline` seam with synthetic timings (cleaner than injecting a render-thread delay): under-budget, overrun-only, risk, accumulation+zero-budget, exact 10%/50% boundaries, second-risk host-time, fresh-zero.
- [x] 6.x **Oracle A2 (real ordering bug fixed):** `tapPrepare` now stores `pendingSampleRate`/`isActive` BEFORE the `.releasing` store of `processingFormatTag` (the render acquire-loads the tag as the gate; the rate read by the budget AND the Phase 4 visualizer must publish first).
- [ ] 6.10 Manual stress test: all 10 EQ bands at +24 dB over 30 s video playback → observe counts (expect 0 overruns) — **READY FOR USER** (the `diagnosticSnapshot` counters are the readout; can also defer to Phase 8's CPU benchmark).
- [x] 6.11 Commit ✅ — `82365c7` (impl) + `3fd157c` (Oracle remediation).
- [x] 6.12 Codex Oracle review ✅ — round 1 8/10 REVISE (A1 timebase prewarm, A2 store ordering, A3 advisory-sampling doc + NITs) → all fixed → round 2 **9/10 APPROVED, no must-fix**. 110/110 TSan.

---

## Phase 7 — Lifecycle + production tests (TSan, signed-bundle smoke)

**Goal.** Exhaustive lifecycle test coverage per Tap Lifecycle Contract. Catches rapid skip / create-failure / pause-resume / seek / item-replacement edge cases.
**Plan ref:** plan.md §6 Phase 7 + ADR-7 + spike-findings hardening items 1+4.

- [ ] 7.1 Create `Tests/MacAmpTests/VideoTapLifecycleTests.swift`
- [ ] 7.2 Test: 10 tap create/attach/play/replace cycles in 1 s → no leak (assert via `_test*` Unmanaged-balance accounting seam)
- [ ] 7.3 Test: tap-create injected failure path (via `_testForceTapCreateFailure` seam) → Context released, no leak
- [ ] 7.4 Test: attach + immediate stop before any `tapProcess` invocation → `tapFinalize` still fires
- [ ] 7.5 Test: pause + resume cycle → Context state preserved (atomic counters increment monotonically)
- [ ] 7.6 Test: seek mid-playback → `BiquadCascade.reset()` invoked (verified via `_testFilterStateZero` seam)
- [ ] 7.7 Test: `replaceCurrentItem(with: nil)` during active `tapProcess` → no UAF (TSan + asan)
- [ ] 7.8 Build + TSan green
- [ ] 7.9 Build + sign Debug `.app` per `docs/RELEASE_BUILD_GUIDE.md` (no notarization for Debug)
- [ ] 7.10 Manual: launch signed `.app`, play video, verify EQ audible, no leak in Allocations Instruments over 1-min playback
- [ ] 7.11 Commit: `chore(s3-2): Phase 7 — lifecycle + production tests`

---

## Phase 8 — Verification matrix execution

**Goal.** Execute every gate from research.md "Verification gate matrix." 15 gates tiered Static / Dynamic / Lifecycle. Document pass/fail in state.md.
**Plan ref:** plan.md §6 Phase 8 + §7 (matrix).

### Static gates (one-time)

- [ ] 8.1 CPU benchmark — Apple Silicon (M-series), 3 clip configs (44.1 stereo, 48 stereo, 48 5.1), baseline (pass-through tap) vs full chain over ≥30 s. Assert 99th-percentile `tapProcess` wall-clock ≤10% buffer budget. Reject if any single sample >50%
- [ ] 8.2 CPU benchmark — Intel build target (run on Intel Mac if available, else simulated/forced-arch run), same gate
- [ ] 8.3 Numerical EQ match — re-run `BiquadNumericalMatchTests` (Phase 3) — confirm ≤0.5 dB
- [ ] 8.4 TSan — full `MacAmpApp` test suite green with `-enableThreadSanitizer YES`

### Dynamic transition gates

- [ ] 8.5 Long-playback drift — ≥10 min continuous video playback (loop short clip if needed); A/V sync within ±40 ms
- [ ] 8.6 Route-change AirPods 1st-gen — connect mid-playback / disconnect mid-playback. Tap callbacks resume within 500 ms; no DSP-state loss; no silent output
- [ ] 8.7 Route-change AirPods Pro — same gate
- [ ] 8.8 Route-change AirPlay-1 receiver — same gate
- [ ] 8.9 Route-change AirPlay-2 receiver — same gate
- [ ] 8.10 System default-output change — Settings → Sound → switch internal speakers ↔ HDMI display speakers. Same gate
- [ ] 8.11 Bluetooth codec switch — AAC ↔ SBC (forced via `Bluetooth Explorer` or CLI). Tap callback continuity, no audio drop > 200 ms
- [ ] 8.12 Mid-playback format re-prepare — AVPlayerItem audio-track swap (constructed multi-track item). `tapPrepare` re-fires; coefficient recompute fires
- [ ] 8.13 Surround handling — 5.1 clip plays through native AVPlayer downmix; visualizer mono-downmix non-clipping; EQ uniform across 6 channels
- [ ] 8.14 Item replacement during playback — `player.replaceCurrentItem(with: nextItem)` for video → audio file (and reverse). Outgoing item's `tapFinalize` fires; no leak; ≤200 ms audio gap

### Lifecycle gates (covered by Phase 7 tests)

- [ ] 8.15 (Already covered by Phase 7) — Rapid track skip, tap-create failure, pause/resume, seek, signed-bundle smoke

### Documentation

- [ ] 8.16 Document each gate's pass/fail signal + date + commit SHA in `state.md` (or new `verification.md` section)
- [ ] 8.17 Any gate failure → ADR amendment + Phase 7/3/etc. retry, NOT a soft-skip
- [ ] 8.18 Commit: `chore(s3-2): Phase 8 — verification matrix execution`

---

## Phase 9 — UI integration polish + final smoke + docs

**Goal.** Audit + wire video-window UI surfaces; mandatory documentation updates; pre-PR Oracle review; PR creation.
**Plan ref:** plan.md §6 Phase 9.

### UI audit

- [ ] 9.1 Audit `MacAmpApp/Windows/WinampVideoWindowController.swift` for EQ + balance + visualizer-mode UI surface wiring
- [ ] 9.2 Audit `MacAmpApp/Views/WinampVideoWindow.swift` and `MacAmpApp/Views/Windows/VideoWindowChromeView.swift`
- [ ] 9.3 Add menu items / wiring as needed (likely minimal — video window already shares EQ + balance UI with audio window via `AppSettings` / `EqualizerController` / `AudioPlayer`)

### Mandatory documentation updates

- [ ] 9.4 Add **"Audio Mechanism Concurrency Contract"** subsection to `docs/MACAMP_ARCHITECTURE_GUIDE.md` distinguishing:
   - `@unchecked Sendable` as **implicit shortcut (AVOID)** — bare annotation without atomic discipline + contract gating
   - `@unchecked Sendable` as **explicitly-gated exception (ACCEPTABLE)** — when boundary is necessary AND gated by ADR-3a's three gates
   - Pattern reference: `RenderThreadSafe.swift` + header contract on `VideoTapContext.swift` + DEBUG Mirror+source-level tests
   - Enumerated types: `VideoTapContext`, `VisualizerFeed`, `VisualizerScratchBuffers`, `BiquadCascade`
   - Follow-up retrofit candidate: `StreamDecodePipeline.DecodeContext`
- [ ] 9.5 Update existing scattered `@unchecked Sendable` guidance in `docs/MACAMP_ARCHITECTURE_GUIDE.md` (lines around 826, 1354 from current state) to **point at** the new canonical subsection rather than restate rationale
- [ ] 9.6 Add **"Audio DSP Architecture"** section to `docs/VIDEO_WINDOW.md` describing the in-place tap DSP topology (replaces any prior engine-routing description); reference research.md and ADRs 1-11

### Final verification + PR

- [ ] 9.7 End-to-end: launch app, open video window, load video, toggle EQ, drag bands, drag balance, switch visualizer mode (spectrum ↔ Butterchurn) — all work
- [ ] 9.8 Full TSan-on test suite green (including `VideoTapSendableContractTests` + `VideoTapLifecycleTests` + `BiquadNumericalMatchTests`)
- [ ] 9.9 Pre-PR Codex Oracle review (per `feedback_sprint_workflow.md` memory)
- [ ] 9.10 Apply Oracle feedback if any
- [ ] 9.11 Commit if any final fixes: `chore(s3-2): Phase 9 — UI polish + docs`
- [ ] 9.12 Push branch: `git push -u origin feat/avplayer-native-video-dsp`
- [ ] 9.13 `gh pr create` with PR description summarizing the 5-round research + 5-round plan + 9-phase implementation
- [ ] 9.14 Wait for human review

---

## Post-merge close-out (after PR #C merges)

- [ ] 10.1 Update task `state.md` to MERGED with PR link + merge commit
- [ ] 10.2 `git mv tasks/avplayer-native-video-dsp/ tasks/done/avplayer-native-video-dsp/`
- [ ] 10.3 Delete throwaway `spike/avplayer-inplace-tap-dsp` branch (locally)
- [ ] 10.4 Update `tasks/_context/state.md` Quick Reference + sprint table
- [ ] 10.5 Update `tasks/_context/tasks_index.md` (move row to "Completed Sprints" section)
- [ ] 10.6 Update `tasks/_context/resume-prompt.md` Active Work Queue (advance to S3-3)
- [ ] 10.7 Mark `tasks/_context/s3-2-pivot.md` as RESOLVED
- [ ] 10.8 Single `chore: close out avplayer-native-video-dsp (PR #C)` commit
