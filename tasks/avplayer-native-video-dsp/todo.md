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
   - [x] 3.9.5 Step 6: balance — `Float(bitPattern: balance)`; standard [0,1]/0.5-center law, L/R gain multiplies, skip if center
- [ ] 3.10 Create `Tests/MacAmpTests/BiquadNumericalMatchTests.swift`
- [ ] 3.11 Test 1 — full EQ active: 5 presets × log sweep 20 Hz – 20 kHz × ≤0.5 dB worst-case vs `AVAudioUnitEQ` (offline render via `AVAudioEngine.manualRenderingMode`)
- [ ] 3.12 Test 2 — EQ-toggle bypass parity: `isEqOn=false` → BiquadCascade output bit-identical to input modulo preamp+balance
- [ ] 3.13 Test 3 — preamp parity: 1 kHz at 0 dBFS, preamp ∈ {-12, -6, 0, +6, +12} dB, BiquadCascade ≈ input × 10^(preamp/20) within ≤0.1 dB
- [ ] 3.14 Test 4 — balance parity: stereo white noise, balance ∈ {0.0, 0.25, 0.5, 0.75, 1.0}, channel-by-channel ≤0.1 dB vs engine balance node
- [ ] 3.15 `xcodegen generate`
- [ ] 3.16 Build + TSan green; `BiquadNumericalMatchTests` ≤0.5 dB pass
- [ ] 3.17 Manual smoke: video plays with EQ "bass boost" — audible bass increase. "treble boost" — audible treble. EQ off — clean passthrough
- [ ] 3.18 Commit: `chore(s3-2): Phase 3 — BiquadCascade + balance + numerical match`

---

## Phase 4 — Visualizer DSP integration (video-tap render path)

**Goal.** Add parallel `videoTapVisualizerRender` function consuming `AudioBufferList` (vs engine's `AVAudioPCMBuffer`); spectrum bars + Butterchurn animate from video audio.
**Plan ref:** plan.md §6 Phase 4 + ADR-6.

- [ ] 4.1 Create `MacAmpApp/Audio/VideoDSP/VideoTapVisualizerRender.swift`
- [ ] 4.2 Implement `func videoTapVisualizerRender(bufferList:frames:sampleRate:scratch:feed:)`
- [ ] 4.3 Mono mix N channels (1/2/5.1/7.1) — surround uses `inferredSurroundChannelLayoutTag` downmix coefficients (saved-branch allowlist pattern)
- [ ] 4.4 20-bar RMS bucket (matches engine `VisualizerPipeline.swift:579-658` byte-for-byte)
- [ ] 4.5 20-bar Goertzel spectrum on first 1024 mono frames
- [ ] 4.6 2048-pt Hann-windowed vDSP FFT for Butterchurn spectrum + waveform
- [ ] 4.7 Call `feed.tryPublish(from: scratch, oscilloscopeSamples: 76, validFrameCount: frames)` (drop on contention)
- [ ] 4.8 Update `VideoTapContext.swift` to hold:
   - [ ] 4.8.1 `feed: VisualizerFeed` (shared with engine path; injected at init)
   - [ ] 4.8.2 `scratch: VisualizerScratchBuffers` (per-tap; allocated at init)
- [ ] 4.9 Update `VideoTap.swift` `tapProcess` step 7 (after balance): call `videoTapVisualizerRender(...)`
- [ ] 4.10 Update `VideoTap.attach(to:context:)` factory signature: accept `VisualizerFeed` parameter; allocate `VisualizerScratchBuffers` + pass into Context init
- [ ] 4.11 Update `AudioPlayer.startVideoLoad(...)`'s `audioMixBuilder` closure to resolve `VisualizerFeed` (via `VisualizerPipeline`) and pass it (plus a freshly-allocated `VisualizerScratchBuffers`) to `VideoTap.buildAudioMix(...)` so the per-tap render path can publish to the shared feed.
- [ ] 4.12 Update `RenderThreadSafe.swift` extensions if any new types appear (likely none)
- [ ] 4.13 `xcodegen generate`
- [ ] 4.14 Build + TSan green; no contention warning on `VisualizerFeed` lock
- [ ] 4.15 Manual smoke: video clip plays AND spectrum bars animate from video audio
- [ ] 4.16 Manual smoke: Butterchurn mode — patterns react to video audio
- [ ] 4.17 Manual smoke: 5.1 surround clip — visualizer mono-downmix correct, no clipping; bars animate
- [ ] 4.18 Engine-path regression: load music file, verify spectrum + Butterchurn animate identically (Phase 1 invariant)
- [ ] 4.19 Commit: `chore(s3-2): Phase 4 — visualizer DSP integration (video-tap render)`

---

## Phase 5 — EQ + balance state fanout (parallel from `EqualizerController` + `AudioPlayer`)

**Goal.** Wire two canonical owners' fanout: EQ from `EqualizerController`, balance from `AudioPlayer`. Both push to engine + tap.
**Plan ref:** plan.md §6 Phase 5 + ADR-5.

- [ ] 5.1 Add `private final class WeakBox<T: AnyObject>` to `EqualizerController.swift`
- [ ] 5.2 Add `private var registeredVideoTapContexts: [WeakBox<VideoTapContext>] = []` to `EqualizerController`
- [ ] 5.3 Implement `func registerVideoTapContext(_:sampleRate:)` — append weak ref; immediately compute + push `BiquadCoefficientSet`; push `isEqOn` and `preampLinearGain` atomics
- [ ] 5.4 Implement `func unregisterVideoTapContext(_:)` — remove ref by identity
- [ ] 5.5 Implement `func handleSampleRateChange(_:newSampleRate:)` — recompute coefficient set + push
- [ ] 5.6 Modify existing EQ slider / preset / preamp change handlers — after writing to engine `AVAudioUnitEQ`, iterate `registeredVideoTapContexts` (skip nil), call the Phase-3-redesigned coefficient install entry point (per P-4) + atomic writes for `isEqOn` and `preampLinearGain`. (Phase 5 cannot land before Phase 3 closes P-4 — see plan.md Phase 5 amendment.)
- [ ] 5.7 Add `private final class WeakBox<T: AnyObject>` to `AudioPlayer.swift` (or extract to shared file if extension surface justifies it)
- [ ] 5.8 Add `private var registeredVideoTapContexts: [WeakBox<VideoTapContext>] = []` to `AudioPlayer`
- [ ] 5.9 Modify `AudioPlayer.balance.didSet` — after writing to engine balance node, iterate registry, write Float bit-pattern to each Context's `balance` atomic
- [ ] 5.10 Update `AudioPlayer.startVideoLoad(...)`'s `audioMixBuilder` closure — after `VideoTapContext()` construction (just before `VideoTap.buildAudioMix`), register the new Context with both `equalizerController.registerVideoTapContext(context, sampleRate: 0)` (sample rate 0; updated by `handleSampleRateChange` on first `tapPrepare`) and `self.registeredVideoTapContexts`. Also add unregister in `pauseAndDetachVideoTapIfNeeded` and `invalidateInFlightVideoLoad`.
- [ ] 5.11 Update `AudioPlayer.detachVideoTap(...)` — unregister from both registries before letting Context go out of scope
- [ ] 5.12 Implement polled-atomic sample-rate handling: piggyback on `VisualizerPipeline` 30 Hz `Timer`. Add small per-Context check: if `pendingSampleRate` differs from last-seen, call `equalizerController.handleSampleRateChange(...)`
- [ ] 5.13 Unit test: register Context at 44.1 kHz; setBandGain → assert pointer changed AND coefficients match RBJ at 44.1 kHz
- [ ] 5.14 Unit test: change `AudioPlayer.balance` → assert all registered Contexts' `balance` atomics updated
- [ ] 5.15 Build + TSan green
- [ ] 5.16 Manual smoke: drag EQ slider during video playback → audio changes real-time; drag balance → audio pans real-time
- [ ] 5.17 Engine-path regression: drag EQ during AUDIO file playback — existing behavior unchanged
- [ ] 5.18 Commit: `chore(s3-2): Phase 5 — EQ + balance state fanout`

---

## Phase 6 — Production telemetry (deadline-miss instrumentation)

**Goal.** Sample-and-alarm tap-callback wall-clock time; budget-violation counters for Phase 8 CPU benchmark gate.
**Plan ref:** plan.md §6 Phase 6 + spike-findings hardening item 3.

- [ ] 6.1 Add to `VideoTapContext.swift`:
   - [ ] 6.1.1 `let budgetOverrunCount: Atomic<UInt64>(0)`
   - [ ] 6.1.2 `let deadlineRiskCount: Atomic<UInt64>(0)`
   - [ ] 6.1.3 `let lastLoggedHostTime: Atomic<UInt64>(0)`
- [ ] 6.2 Add `struct VideoTapDiagnostics: Sendable` (snapshot type with all telemetry counters)
- [ ] 6.3 Add `var diagnosticSnapshot: VideoTapDiagnostics { ... }` computed property on `VideoTapContext` (main-thread accessor)
- [ ] 6.4 Modify `VideoTap.swift` `tapProcess` — every Nth callback (N=64), capture `mach_absolute_time()` at entry/exit
- [ ] 6.5 Compute delta in nanoseconds via `mach_timebase_info_data_t`
- [ ] 6.6 Compare to buffer wall-clock budget (`framesToProcess / sampleRate * 1e9`)
- [ ] 6.7 If delta > 10% of budget → atomically increment `budgetOverrunCount`
- [ ] 6.8 If delta > 50% → increment `deadlineRiskCount` + log once-per-second (rate-limited via `lastLoggedHostTime` gate)
- [ ] 6.9 Unit test: inject synthetic delay (debug-only `_test` seam) → assert `budgetOverrunCount` increments
- [ ] 6.10 Manual stress test: all 10 EQ bands at +24 dB on Apple Silicon over 30 s playback — observe counts (expect 0 overruns)
- [ ] 6.11 Commit: `chore(s3-2): Phase 6 — deadline-miss telemetry`

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
