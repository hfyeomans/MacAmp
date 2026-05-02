# Research: AVPlayer-Native Video DSP

> **Task:** `tasks/avplayer-native-video-dsp/`
> **Status:** ✅ COMPLETE — Step 2 closed 2026-05-01. Five-round Oracle review converged 7.8 → 8.9 → 9.1 → 9.5 → **10/10** (commit `46bb6af`). Phase 0 spike empirical kill-switch ✅; full research package + synthesis below.
> **Reference:** `tasks/video-audio-engine-routing/research.md` (saved branch's research, kept as historical context — much of it remains relevant for surround-downmix and channel-mapping patterns).

---

## Goal

Validate the architecture's load-bearing assumptions before writing `plan.md`. Per project workflow: research informs plan, plan goes through Oracle ≥9/10 gate, only then does implementation begin.

---

## Architecture (proposed end-state)

User-aligned 2026-05-01. This is the topology research must validate; if Phase 0 spike fails the kill-switch (Q1), this section is rewritten before plan.md.

```
═══════════════════════════════════════════════════════════════════════════════
  ENGINE PATH — UNCHANGED  (audio files + streams + future HLS-audio)
═══════════════════════════════════════════════════════════════════════════════

  AVAudioPlayerNode  ──┐
  (local files)        │
                       ├──► AVAudioUnitEQ ──► balance ──► main mixer ──► output
  AVAudioSourceNode  ──┘                                       │
  (stream pipeline →                                           │
   ring → source node)                              installTap (bus 0)
                                                               │
                                                               ▼
                                                      VisualizerFeed.write()  (1)


═══════════════════════════════════════════════════════════════════════════════
  VIDEO PATH — NEW  (local video, future HLS-video)
═══════════════════════════════════════════════════════════════════════════════

  AVAsset (video file)                       Main thread:                 Render thread:
       │                                     ─────────────                ──────────────
       ▼                                     EQ params ───────atomic────►
  AVPlayerItem                               Balance ─────────atomic────►
       │                                     Active flag ─────atomic────►
       │ .audioMix = AVMutableAudioMix
       │
       ├── AVMutableAudioMixInputParameters (per audio track)
       │      .audioTapProcessor = MTAudioProcessingTap  [flag: _PreEffects]
       │
       ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  tapProcess (render thread, in-band — NEVER blocks, NEVER allocs)    │
  │                                                                      │
  │   1.  MTAudioProcessingTapGetSourceAudio  →  bufferList              │
  │                                                                      │
  │   2.  BiquadCascade.process(bufferList)        ── modifies in place  │
  │       • 10-band, IIR, fresh impl matched to AVAudioUnitEQ            │
  │       • coefficient table updated atomically from main               │
  │                                                                      │
  │   3.  Balance.applyL/R(bufferList)             ── modifies in place  │
  │                                                                      │
  │   4.  Run visualizer DSP into scratch (matches engine-tap today):    │
  │       • mono mix (downmix surround→mono if needed)                   │
  │       • 20-bar RMS                                                   │
  │       • 20-bar Goertzel spectrum                                     │
  │       • 2048-pt Hann-windowed vDSP FFT (Butterchurn)                 │
  │       VisualizerFeed.tryPublish(from: scratch) ──► (1)               │
  │       • single-slot, last-write-wins, trylock-drop on contention     │
  │       • slot carries pre-computed arrays, not raw PCM                │
  │                                                                      │
  │   5.  return  ── AVPlayer reads bufferList downstream as-modified    │
  │                                                                      │
  └────────────────────────────┬─────────────────────────────────────────┘
                               │
                               ▼
                  AVPlayer native audio output
                  (master clock for video frames — owned by AVPlayer,
                   never coupled to engine, never under-runs because the
                   tap is the producer's own thread)
                               │
                               ▼
                          🔊 Speakers


═══════════════════════════════════════════════════════════════════════════════
  VISUALIZER (single consumer, both paths feed it)
═══════════════════════════════════════════════════════════════════════════════

  VisualizerFeed (single-slot SPSC, last-write-wins, pre-computed arrays:
                  RMS×20 + spectrum×20 + scope×76 + FFT spectrum×1024 + FFT waveform×1024)
       │
       ▼
  VisualizerPipeline (Timer @ 30 Hz on .common run-loop) ─►  Spectrum bars  |  Butterchurn snapshot
```

### Topological deltas vs the saved branch

| Concern | Saved branch (FAILED) | New arch |
|---|---|---|
| Where video audio leaves AVPlayer | Drained out via tap → ring → source node | Never leaves — tap modifies in place |
| Clock domains | Two (engine output + AVPlayer master) | One (AVPlayer native) |
| Sample-rate conversion stages | Two (asset→48 k for ring, then 48 k→hw) | One (AVPlayer's native, untouched) |
| Failure mode if DSP is slow | Ring underrun → master-clock stall + drift accumulation → persistent video freeze, requires fallback machinery | Render-thread overrun → transient audio glitch + transient video stall, bounded per render cycle, no drift accumulation, no fallback needed |
| Route-change handling | Engine reconfigure observer (unreliable for AirPods — proven by missing log line in Phase 7 traces) | AVPlayer handles natively (assumed; plan.md verification matrix must validate AirPods + AirPlay route switches end-to-end before S3-2 merge) |
| Capability flag | `videoTapFallbackActive` (could flip false) | Always true; no fallback path |

---

## Reuse policy from `feat/video-audio-engine-routing`

The saved branch's failures were topology-bound. Some structural plumbing is platform-API-level and topology-agnostic; the rest is failure-bound and **must not** be carried forward. This policy is the contract for any retrospective work — Phase 0 spike, sub-agent extraction, plan.md authoring.

### ALLOWLIST — safe to study & adapt (platform-API plumbing)

- C-callback shape for `tapInit / tapFinalize / tapPrepare / tapUnprepare / tapProcess`
- `Unmanaged<Context>` handoff via `MTAudioProcessingTapGetStorage` (lifetime pattern)
- `AudioStreamBasicDescription` inspection in `tapPrepare` (sample-format detection)
- Surround → mono downmix coefficients **for the visualizer feed only** (the audible path leaves channel layout untouched; the visualizer's existing engine-side tap mixes to mono — the canonical contract for the new tap path matches it)
- TSan test scaffolding patterns + `_test*` API seams (deferred to implementation phase, not Phase 0)

### DENYLIST — do NOT carry forward (failure-bound or topology-coupled)

- `LockFreeRingBuffer` for video — there is no transport ring on this path
- `AVAudioSourceNode` + engine bridge wiring for video — there is no engine path
- `AudioConverter` + Mastering quality tier — DSP runs at asset-native rate, no conversion
- `configureChannelMapping` shaped around the AudioConverter input contract — re-derive cleanly for visualizer-feed downmix only
- Watchdog / fallback machinery — nothing to fall back from
- HAL property listener for AirPlay routes — AVPlayer's domain
- `AVAudioEngineConfigurationChange` observer for the video path — engine isn't on this path
- `videoTapFallbackActive` capability branch — collapses to constant `true`
- Phase 7 watchdog gate v2 / 3 s threshold logic — engine-side concept
- `wasVideoBridge` snapshot field — already dropped on this branch
- `swift-atomics` `ManagedAtomic` usage — superseded by `Synchronization.Atomic` (see Tooling constraints below)

**Rule of thumb:** if the pattern existed *because* of the engine-routing topology, leave it. If it existed because `MTAudioProcessingTap` is a C API with C lifetime semantics, study it.

---

## Step 2 findings (synthesis 2026-05-01)

Four parallel research streams + clip enumeration completed. Detailed source documents in `research-notes/`; this section is the canonical synthesis for plan.md inputs.

### Evidence ledger

Single source of truth for what is empirically verified vs. inferred vs. deferred. plan.md gates derive from the **Deferred** rows; the **Estimated** rows tell plan.md what to confirm during implementation; the **Measured** rows are settled.

| Claim | Evidence | Status |
|---|---|---|
| In-place buffer modification works (Q1 kill-switch) | Apple SDK header verbatim + Apple AudioTapProcessor sample + Phase 0 spike audible A/B + programmatic write-verify (`pre × gain == post`) | **Measured** |
| `_PreEffects` is the right flag for source-side DSP | Apple SDK header verbatim (`MTAudioProcessingTap.h`) | **Measured (docs-binding)** |
| `Synchronization.Atomic<UInt32>` for Float bit-pattern works in Swift 6.2 + macOS 15+ | Phase 0 spike compiles + runs end-to-end | **Measured** |
| `Unmanaged<Context>` lifetime through C callbacks works in Swift 6.2 | Phase 0 spike: `tapInit/Prepare/Process/Finalize` callbacks fire as expected | **Measured** |
| `AVAudioUnitEQ` uses RBJ-cookbook octave-BW peaking-EQ | Apple SDK header verbatim (`AudioUnitParameters.h`, `kAUNBandEQFilterType_Parametric`) | **Measured (docs-binding)** |
| Per-band parameters (frequencies + bandwidth) | Read from current `MacAmpApp/Audio/EqualizerController.swift` | **Measured** |
| ≤0.5 dB `BiquadCascade` vs `AVAudioUnitEQ` tolerance achievable | Inferred from RBJ algorithm precision; no implementation yet | **Estimated** |
| 10-band biquad + balance + visualizer DSP within render budget on Apple Silicon | Calculated from op-count × sample rate; engine path runs equivalent visualizer DSP today | **Estimated** |
| Same on Intel build target | Calculated; no Intel hardware measurement on either branch | **Estimated** |
| AVPlayer handles AirPods/AirPlay routes natively, no DSP-state loss | Inferred from architecture (no engine bridge to break); not validated for new tap topology | **Deferred** |
| Long-playback drift bounded (single-clock-domain) | Inferred from architecture; spike was 3 s | **Deferred** |
| 5.1 surround correct in audible + visualizer paths | Spike tested stereo only; surround clip exists but unused | **Deferred** |
| `MTAudioProcessingTap` survives `replaceCurrentItem(with:)` | Not investigated | **Deferred** |
| Mid-playback format re-prepare (track switch, codec change) | Not investigated | **Deferred** |
| Bluetooth codec/profile switch mid-playback (AAC ↔ SBC ↔ aptX) | Not investigated | **Deferred** |
| AirPlay 1 vs AirPlay 2 behavioral differences | Not investigated | **Deferred** |
| Tap behavior under signed-bundle entitlements (CLI spike has none) | Not investigated | **Deferred** |

`Measured` = empirically validated or cited verbatim from Apple authoritative source. `Estimated` = derived from calculation or analogy; not directly observed. `Deferred` = explicit plan.md verification gate.

### Q1 — In-place buffer modification: ✅ RESOLVED (docs + empirical spike)

**Empirical confirmation (2026-05-01):** Phase 0 spike on `spike/avplayer-inplace-tap-dsp` produced audible attenuation when applying `sample *= 0.1` in `tapProcess` — programmatic verification (`pre=-0.0695 → post=-0.00695`, exact match to expected `pre × gain`) plus user-confirmed auditory A/B between gain=1.0 and gain=0.1 runs of the same clip. Full findings in `research-notes/spike-findings.md`. Toolchain validation: Swift 6.2 + `Synchronization.Atomic<UInt32>` for Float bit-pattern + `@unchecked Sendable` Context + `Unmanaged.passRetained` lifetime through C callbacks all clean.

Apple's MediaToolbox SDK header (`MTAudioProcessingTap.h`, `MTAudioProcessingTapProcessCallback` doc block) states verbatim:

> "The processing tap may operate on the provided source data in place ('in-place processing') and return pointers to that buffer, rather than its own. This is similar to audio unit render operations."

Apple's archived **AudioTapProcessor** sample (`developer.apple.com/library/archive/samplecode/AudioTapProcessor/`) independently confirms runtime behavior — an `AUBandpassFilter` applied via tap is audible. The architectural kill-switch is **closed by the docs alone**; `tapProcess` writes are what AVPlayer's downstream pipeline plays.

**Flag selection:** `kMTAudioProcessingTapCreationFlag_PreEffects`. Saved branch used `_PostEffects` because it was draining for a downstream consumer; we're modifying for AVPlayer's own downstream chain (AVPlayer's spatial audio / mixing / hardware effects layer on top of our DSP). `_PostEffects` would suit a later observation/metering tap (e.g. Milkdrop-only mode).

**Concurrency pattern (Swift 6.2 + macOS 15+ — single contract):**
- Context class: non-actor `final class Context: @unchecked Sendable` — silences C-callback FFI checking on the envelope. The Context is not `@MainActor`-isolated; the render thread accesses it directly via `Unmanaged`.
- Cross-thread fields: `Synchronization.Atomic<T>` / `Synchronization.Mutex<T>` (Swift 6.0 stdlib). `Atomic<T>` is `Sendable` by stdlib design, so individual atomic fields do NOT need `nonisolated(unsafe)` markers.
- `nonisolated(unsafe)` is reserved for the rare case of an actor-isolated context holding a non-`Sendable` stored property that must cross to the render thread. **Not applicable on this branch** — the Context is non-isolated by construction.
- Render thread reads atomics with `.load(.relaxed)`; main thread writes with `.store(.relaxed)` (or `.sequentiallyConsistent` on activate/deactivate flags where ordering matters)
- `Unmanaged<Context>.passRetained()` at tap-build time; **release on tap-create failure to prevent leak** (see spike-findings.md "Production-translation hazards"); `MTAudioProcessingTapGetStorage` retrieves opaque pointer in callbacks (`takeUnretainedValue()`); `Unmanaged.fromOpaque(...).release()` in `tapFinalize` (exactly once)

Spike's residual role narrows from "discover" to "validate runtime behavior on macOS 15+ + Swift 6.2 toolchain in our codebase." See "Spike scope decision" below.

### Q2 — AVAudioUnitEQ numerical match: ✅ HIGH confidence

Apple SDK header (`AudioUnitParameters.h`, `kAUNBandEQFilterType_Parametric`) — verbatim:

> "Parametric filter based on Butterworth analog prototype. Uses parameterisation where the bandwidth is specified as the relationship of the upper bandedge frequency to the lower bandedge frequency in octaves, where the upper and lower bandedge frequencies are the respective frequencies above and below the center frequency at which the gain is equal to half the peak gain."

Maps exactly to **Robert Bristow-Johnson Audio EQ Cookbook**'s octave-BW peaking formula:

```
ω₀ = 2π · f / sampleRate
α  = sin(ω₀) · sinh((ln 2 / 2) · BW · ω₀ / sin(ω₀))
A  = 10^(dBgain / 40)
b0 = 1 + α·A    b1 = -2·cos(ω₀)    b2 = 1 - α·A
a0 = 1 + α/A    a1 = -2·cos(ω₀)    a2 = 1 - α/A
```

Bands 0 and 9 use the analogous RBJ low/high-shelf formulas (no bandwidth parameter — frequency is shelf midpoint at half-gain).

**Per-band parameters** (from current `EqualizerController.swift`):

| Band | Frequency (Hz) | Type | BW (oct) | Gain range (dB) |
|------|---|---|---|---|
| 0 | 70 | Low shelf | n/a | −96 → +24 |
| 1 | 180 | Parametric | 1.0 | −96 → +24 |
| 2 | 320 | Parametric | 1.0 | −96 → +24 |
| 3 | 600 | Parametric | 1.0 | −96 → +24 |
| 4 | 1 000 | Parametric | 1.0 | −96 → +24 |
| 5 | 3 000 | Parametric | 1.0 | −96 → +24 |
| 6 | 6 000 | Parametric | 1.0 | −96 → +24 |
| 7 | 12 000 | Parametric | 1.0 | −96 → +24 |
| 8 | 14 000 | Parametric | 1.0 | −96 → +24 |
| 9 | 16 000 | High shelf | n/a | −96 → +24 |

Note: Winamp's actual internal frequencies, not ISO 10-band.

**Acceptance criterion:** ≤0.5 dB worst-case magnitude error vs `AVAudioUnitEQ` across 20 Hz – 20 kHz (well below the ~1 dB psychoacoustic JND). ≤1 dB is the hard reject. Verified by offline-rendering a 0 dBFS log sine sweep through both implementations and comparing per-bin magnitude.

### Q3 — Render-thread CPU budget

Per-tap-callback DSP cost at 48 kHz stereo:

- 10-band biquad cascade: ~180 ops/sample × 48 000 Hz = ~8.6 Mops/sec
- Balance: ~96 K ops/sec
- Visualizer pre-publish DSP (mono mix + 20-bar RMS + 20-bar Goertzel + 2048-pt vDSP FFT): proven feasible — engine path runs identical DSP on its render thread today

**Net new cost on the video tap thread vs today's engine tap (estimated, NOT validated):** ~9 Mops/sec (biquad + balance only). Apple Silicon: estimated ≪1% of a core. Intel: estimated ≪2%.

**The Phase 0 spike applied only `*= gain` (trivial cost); the full BiquadCascade + balance + visualizer DSP cost was not measured.** plan.md must include a pre-implementation benchmark gate as a hard prerequisite:

- **Hardware:** Apple Silicon (M1+) **AND** Intel build target
- **Corpus:** the full clapperboard variety — 44.1 kHz stereo, 48 kHz stereo, 48 kHz 5.1 surround
- **Comparison:** baseline (no DSP, pass-through tap) vs full chain (10-band biquad + balance + visualizer DSP)
- **Measurement:** average + 99th-percentile wall-clock time spent in `tapProcess` per buffer, sampled over ≥30 s of playback per configuration
- **Pass criterion:** 99th-percentile ≤ 10 % of the buffer's wall-clock budget (4.6 ms at 2048 frames @ 44.1 kHz; 4.3 ms at 48 kHz)
- **Hard reject:** any single sample > 50 % of buffer budget (deadline-miss risk indicator)

If the benchmark fails, plan.md must include a fallback strategy (lower-order biquad, fewer bands, drop visualizer for video, or push DSP cost to a different stage).

### Q4 — Channel/SR variety in test corpus

Five 3-second clips in `clapperboard-videos/`:

| File | Container | Sample rate | Channels | Layout |
|---|---|---|---|---|
| `1_mp4_441_stereo.mp4` | MP4 | 44 100 | 2 | stereo |
| `2_mp4_480_stereo.mp4` | MP4 | 48 000 | 2 | stereo |
| `3_mov_480_stereo.mov` | MOV | 48 000 | 2 | stereo |
| `4_m4v_441_stereo.m4v` | M4V | 44 100 | 2 | stereo |
| `5_mp4_480_surround.mp4` | MP4 | 48 000 | 6 | 5.1 |

Coverage: both common SRs, four containers, stereo + 5.1. Sufficient. Surround clip exercises the visualizer-feed mono-downmix path; stereo clips bypass it.

### Q5 — Saved-branch reuse audit

ALLOWLIST (5 platform-API plumbing patterns — file:line cited in `research-notes/saved-branch-retrospective.md`):
- C-callback shape (`tapInit/Finalize/Prepare/Unprepare/Process` typealiases)
- `Unmanaged<Context>` lifetime via `MTAudioProcessingTapGetStorage`
- `AudioStreamBasicDescription` inspection in `tapPrepare`
- `inferredSurroundChannelLayoutTag` (AAC layout tags for 3–8 ch) — **for visualizer-feed downmix only**
- `_test*` debug seam pattern under `#if DEBUG`

**Modernization deltas (non-negotiable on this branch):**
- Drop `import Atomics` + `ManagedAtomic` → `Synchronization.Atomic<T>`
- Keep `@unchecked Sendable` envelope on Context (necessary at the C-callback FFI boundary). **No per-field `nonisolated(unsafe)` markers needed:** `Synchronization.Atomic<T>` is itself `Sendable`, so atomic-disciplined fields don't require localized unsafety markers. (See Q1 "Concurrency pattern" above for the canonical single-contract description.)

DENYLIST (11 engine-routing-bound patterns confirmed at file:line on saved branch — all explicitly NOT carried forward): `LockFreeRingBuffer` for video, `AVAudioSourceNode` + engine bridge wiring, `AudioConverter` + Mastering quality, `AudioConverterSetProperty`-shaped channel mapping, watchdog/fallback machinery, HAL property listener, video-side `AVAudioEngineConfigurationChange` observer, `videoTapFallbackActive` capability branch, Phase 7 watchdog gate v2 + 3 s threshold, `wasVideoBridge` snapshot field, `swift-atomics` `ManagedAtomic`.

### Q6 — VisualizerFeed extraction (architecture diagram corrected)

**Correction to the diagram above:** the original sketch labelled the visualizer hand-off as "SPSC ring of stereo Float32 frames." This is wrong. The existing hand-off (`VisualizerSharedBuffer` in `MacAmpApp/Audio/VisualizerPipeline.swift`) is a **single-slot, last-write-wins** structure carrying **pre-computed arrays** (RMS×20, Goertzel spectrum×20, oscilloscope waveform×76, Butterchurn FFT spectrum×1024, Butterchurn FFT waveform×1024) — not raw PCM. `os_unfair_lock`, trylock-drop on the render thread, blocking-consume on main at 30 Hz.

**Implication for the video tap:** `tapProcess` step 4 must run the same DSP as today's engine tap (mono mix → 20-bar RMS → Goertzel → 2048-pt vDSP FFT into pre-allocated `VisualizerScratchBuffers`), then call `feed.tryPublish(from: scratch, ...)`. Same cost shape, same drop-on-contention semantics, same data shape. The diagram (above) has been updated.

**Extraction scope (revised after Oracle review — original "rename + visibility only" understatement corrected):**

The actual changes touch three nested types in `VisualizerPipeline.swift`, not just one:

1. **`VisualizerSharedBuffer` → `VisualizerFeed`** (`VisualizerPipeline.swift:36`): rename + promote from `private final class` to module-internal visibility, move to its own file. ~60 LOC.

2. **`VisualizerScratchBuffers`** (`VisualizerPipeline.swift:169`): also currently `private final class`. The video tap needs its own instance (render-thread isolation per producer), so visibility must be promoted at minimum to module-internal. Either keep nested-but-non-private or extract to its own file. ~30 LOC visibility audit + minor signature work.

3. **`makeTapHandler` (`VisualizerPipeline.swift:565`)** signature currently takes the private nested types and is engine-tap-specific (consumes `AVAudioPCMBuffer`). The video tap path needs a parallel render function that consumes `AudioBufferList` + reads ASBD from `tapPrepare`. Two options:
   - (a) Keep `makeTapHandler` engine-only; write a parallel `videoTapRender` that uses the same `VisualizerFeed` + `VisualizerScratchBuffers`. **Preferred** — different threading contract (engine `nonisolated static @Sendable` closure vs C-callback) + different buffer shape; flag-driven generalization would be the wrong abstraction (Principle 4 / AHA Rule of Three: 2 callers ≠ extract).
   - (b) Generalize `makeTapHandler` to accept any source-buffer type. Rejected pending plan.md review — fits AHA's "wrong abstraction" warning sign.

**Net scope estimate:** ~100–150 LOC across `VisualizerPipeline.swift` + 1–2 new files (`VisualizerFeed.swift`, optionally `VisualizerScratchBuffers.swift`). **Engine path: byte-for-byte identical behavior.** `xcodegen generate` once. plan.md Phase 1 work item.

### Spike scope decision: option (A) — executed

User selected option (A) reduced-scope spike on 2026-05-01. Executed: `spike/avplayer-inplace-tap-dsp` throwaway branch, ~170-line Swift 6.2 CLI tool, single `_PreEffects` tap, `*= gain` in-place modification, play stereo clip, A/B auditory comparison vs control. ✅ Both programmatic and auditory verification passed. Full findings in `research-notes/spike-findings.md`. Spike branch retained locally as reference for the implementation phase.

### Plan.md prerequisites (from Oracle review 2026-05-01, score 7.8/10 → 9+/10 after edits)

Oracle review of the Step 2 package surfaced three open architectural decisions that plan.md must answer concretely (not defer to implementation). These are not research gaps — they are design choices the research has framed but not pinned down.

1. **Single source-of-truth fanout for EQ + balance state.** Both engine `AVAudioUnitEQ` and the new tap-side `BiquadCascade` consume the same user-facing EQ/balance values (preamp, 10-band gains, balance L/R). plan.md must specify: where the canonical user state lives (likely the existing `EqualizerController`), how it fans out to two consumers (engine path + tap-side Context), and how state changes propagate (push to both atomically vs each consumer pulls on its own schedule). Avoid duplicating user state — the math is duplicated, the values are not.

2. **Coefficient hand-off model from main thread to render thread.** Three candidates:
   - (a) Per-coefficient `Atomic<UInt32>` (Float bit-pattern). 100 atomics for 10 bands × 5 coefs × 2 channels. Lock-free; coefficient sets can tear (e.g., render thread reads 4-of-5 new + 1-of-5 old) — usually inaudible at user-EQ-update rate but theoretically possible.
   - (b) Atomic-pointer double-buffer snapshot. Two pre-allocated `BiquadCoefficientSet` blocks; main thread writes inactive block, atomically swaps pointer; render thread reads via pointer. Zero teardown risk; one indirect load per buffer. **Oracle's preference.**
   - (c) `Synchronization.Mutex<BiquadCoefficientSet>` with `withLockIfAvailable`. Render thread skips coefficient update on contention (uses old set); main thread blocks. Acceptable if coefficient updates are rare. Not preferred — adds a contention path.
   
   plan.md picks one with explicit rationale.

3. **Verification gate matrix for plan.md sign-off.** Lock down the empirical gates BEFORE implementation, not as a post-hoc afterthought. Each row produces a pass/fail signal recorded in plan.md:

   **Static gates (run once during implementation):**
   - **CPU benchmark** (Q3): 99th-percentile `tapProcess` wall-clock ≤ 10 % of buffer budget across Apple Silicon + Intel × 44.1 / 48 kHz × stereo / 5.1 surround
   - **Numerical EQ match** (Q2): ≤0.5 dB worst-case magnitude error vs `AVAudioUnitEQ` across 20 Hz – 20 kHz, log sine sweep
   - **TSan**: full test suite green with `-enableThreadSanitizer YES` (project-standard prerequisite for any audio-path PR)

   **Dynamic transition gates (run with active video playback):**
   - **Long-playback drift** (Q3 / pivot): ≥10 minutes continuous video playback, no perceptible drift, A/V sync within ±40 ms
   - **Route-change** (Q1 / pivot motivation): AirPods 1st-gen + AirPods Pro + AirPlay-1 receiver + AirPlay-2 receiver. For each: connect mid-playback / disconnect mid-playback. Pass/fail: tap callbacks resume within 500 ms, no DSP-state loss, no silent output, no stale-Context UAF
   - **System default-output change**: Settings → Sound → Output device switch mid-playback. Pass/fail: same as route-change.
   - **Bluetooth codec switch**: AAC ↔ SBC ↔ aptX (forced via Settings or `defaults write`) mid-playback. Pass/fail: tap-callback continuity, no audio drop, no DSP-state loss.
   - **Mid-playback format re-prepare** (`AVPlayerItem` track-set change, audio asset variant): tap callback continuity (`tapPrepare` re-fires; `tapProcess` invocations resume with new ASBD).
   - **Surround handling** (Q4): 5.1 source plays through native AVPlayer downmix correctly, visualizer feed downmix to mono is non-clipping, EQ applies to all 6 channels uniformly.
   - **Item replacement during playback**: `player.replaceCurrentItem(with: nextItem)` for video → audio file (and vice versa) at random points. Pass/fail: `tapFinalize` fires for the outgoing item before its Context is released; no leak; no UAF; no audio drop > 200 ms.

   **Lifecycle integrity gates** (see "Tap lifecycle contract" below):
   - Rapid track skip (10 items in 1 s): no leak, no crash
   - Tap-create failure path (force-injected): Context released, no leak
   - Pause/resume cycle: Context state preserved
   - Seek mid-playback: filter state behavior matches spec (flush-on-StartOfStream or accept transient)
   - Signed-bundle smoke test: build + sign + run a Debug `.app`; confirm tap behavior matches the unsigned CLI spike

These plan.md prerequisites are tracked separately from the Q1-Q6 research findings — they belong to plan.md authoring, not Step 2 research.

### Tap lifecycle contract

The MTAudioProcessingTap is a C-lifetime resource attached to an `AVPlayerItem`'s `audioMix.inputParameters[…].audioTapProcessor`. plan.md must specify the full state machine — defer nothing here:

- **One-tap-per-item invariant.** Each `AVPlayerItem` for a video file gets its own freshly-built tap + Context pair. Sharing a tap across items is forbidden.
- **Attach.** Tap is built when the AVPlayerItem is prepared. The `audioMix` is set once, before `play()`. **`audioMix` is NOT mutated during that item's playback** (the spike sets it once at construction and never touches it again — match this in production).
- **Detach (item replacement / stop).**
  1. `player.pause()` halts decode within ≤1 buffer of frames; no new `tapProcess` invocations
  2. `player.replaceCurrentItem(with: …)` drops the outgoing AVPlayerItem reference
  3. AVPlayer's deallocation chain calls `tapFinalize` once the tap's last reference is dropped (timing: not guaranteed sync — may happen on a background queue)
  4. `tapFinalize` releases the `Unmanaged<Context>` exactly once
  
  `Unmanaged` balance: +1 from `passRetained` at attach, -1 from `release` at finalize.
- **Pause/resume.** Stops/restarts `tapProcess` invocations from the current playback time. The Context survives across pause/resume — no special handling required.
- **Seek.** `player.seek(to:)` causes a flush at the AV layer. The tap may receive `kMTAudioProcessingTapFlag_StartOfStream` on the next `tapProcess`. **plan.md decides:** flush `BiquadCascade` filter state on every StartOfStream (eliminates transient artifacts; resets EQ behavior briefly), or accept the transient (smaller code, slight audible artifact at seek points).

**Open implementation questions for plan.md** (not research gaps — design decisions):
- Does `tapFinalize` fire synchronously on `replaceCurrentItem` or async? Determines whether tear-down can wait synchronously for finalize.
- Do we need a "tap is alive" atomic on the Context to short-circuit `tapProcess` if we want to pre-emptively disable DSP without waiting for finalize? (Useful for fast item switches.)
- How does the tap interact with `AVQueuePlayer` (if MacAmp ever adopts it for video)? Currently uses single-item `AVPlayer` per video.

### Concurrency decision record (S3-2)

**Decision (2026-05-01).** Tap Context is a non-actor `final class` declared `@unchecked Sendable`. All cross-thread state uses `Synchronization.Atomic<T>` (or `Synchronization.Mutex<T>` for non-trivially-atomic state like `BiquadCoefficientSet`). No `nonisolated(unsafe)` markers on individual fields.

**Rationale.** `Synchronization.Atomic<T>` is `Sendable` by stdlib design (Swift 6.0). Atomic-disciplined fields don't require localized unsafety markers — the `Atomic` value type carries the safety guarantee. The class envelope's `@unchecked Sendable` exists solely to silence the C-callback FFI boundary check (`Unmanaged` requires Sendable conformance for the Context type to cross the C-callback boundary in Swift 6.2 strict mode).

**Rejected alternatives.**
- *Per-field `nonisolated(unsafe)` markers.* Unnecessary noise; `Atomic<T>` already carries the safety contract.
- *Actor-isolated Context with `nonisolated(unsafe)` carve-outs on individual stored properties.* More complexity than needed; the Context is fundamentally non-isolated (render thread accesses it via `Unmanaged`, not via actor messaging).
- *`swift-atomics` `ManagedAtomic<T>`.* External package dependency we don't need; `Synchronization` ships in stdlib at our deployment target.
- *Mutex-only state (no atomics).* Render thread blocking on a Mutex is a correctness hazard at the audio render deadline; only acceptable for state that updates rarely AND non-trivially (e.g., `BiquadCoefficientSet` with `tryLock`/skip-update semantics).

**Supersedes.** Prior `saved-branch-retrospective.md` recommendations to use `nonisolated(unsafe)` on render-thread-confined stored properties (those notes assumed pre-`Synchronization.Atomic` workarounds were necessary; they are not on the new branch).

---

## Tooling constraints

This task targets Swift 6.2 strict concurrency on macOS 15+. No deprecated APIs, no pre-Swift-6 patterns. Specifically:

| Subject | Use | Do NOT use |
|---|---|---|
| Atomics | `Synchronization.Atomic<T>` / `Synchronization.Mutex<T>` (Swift 6.0, macOS 15+) | `swift-atomics` `ManagedAtomic` |
| AVAsset loading | `await asset.load(.tracks, .duration, …)` | `loadValuesAsynchronously(forKeys:)` |
| State holders | `@Observable` | `ObservableObject` (legacy only) |
| Threading isolation | `@MainActor` on UI bridges; explicit `Sendable` on cross-boundary types | Implicit `@unchecked Sendable` shortcuts |
| Render-thread FFI | `nonisolated(unsafe)` carve-out at the C-callback boundary | Swift-isolated callbacks (impossible — render thread is non-cooperative) |
| Async patterns | Structured concurrency (`async let`, `TaskGroup`) | Manual `DispatchQueue` chains except at FFI boundaries |
| AVPlayer-side DSP | `MTAudioProcessingTap` (C API — platform-mandated; only acceptable C surface) | Engine bridge / source-node drain |

The render-thread C callback is the **only** anachronism we accept, and it's Apple-platform-mandated for tap-side DSP. Everything Swift-side is modern.

---

## Research questions (to be answered in Step 2)

### Q1 — Does `MTAudioProcessingTap` actually support in-place buffer modification?

**Why it matters:** This is the *load-bearing* assumption of the entire architecture. If the answer is no, the approach pivots.

**What "yes" looks like:** A tap created with `kMTAudioProcessingTapCreationFlag_PreEffects` (resolved post-Step-2: `_PreEffects` for source-side DSP) can modify the source buffer in `tapProcess`, and AVPlayer plays the modified buffer. EQ-effected audio is audible. AVPlayer owns its master clock end-to-end. Tap-thread overruns can transiently stall both audio and video clocks (bounded per render cycle, no drift accumulation) — but the architecture removes the engine-routing topology's ring-underrun + dual-clock-domain failure classes that required watchdog/fallback machinery. (See topology deltas table above for the canonical comparison.)

**What "no" looks like:** AVPlayer treats the modified buffer specially / re-reads source / ignores modifications. Modifications are read-only by design. Tap mode forces drain semantics regardless of flag.

**Validation method:** Phase 0 spike on throwaway branch. Pseudocode:
```swift
// In tapProcess:
let getStatus = MTAudioProcessingTapGetSourceAudio(tap, framesToProcess, bufferList, ...)
guard getStatus == noErr else { return }
// Modify in place — apply gain reduction (simplest possible DSP, easy to hear)
let frames = Int(framesOut.pointee)
let dataPtr = bufferList.pointee.mBuffers.mData!.bindMemory(to: Float.self, capacity: frames * 2)
for i in 0..<(frames * 2) { dataPtr[i] *= 0.1 }
// Don't write to a ring. Don't mute AVPlayer. AVPlayer should play the modified buffer.
```

If the audio is audibly attenuated, in-place modification works. If volume is unchanged, AVPlayer is reading source elsewhere.

**Apple docs to consult:** TN2249, `AVMutableAudioMix` reference, `MTAudioProcessingTap` SDK header (read flag semantics carefully — `_PreEffects` vs `_PostEffects` may differ in modify-vs-read contract).

**Kill switch:** If in-place modification doesn't work, abandon this architecture. Possible fallbacks (much more complex): apply DSP via `AVAudioMixInputParameters.setVolumeRamp` (only volume, no EQ); intercept via `AVPlayerItem.audioMix` with custom audio processing tap that drains+rewrites (back to ring-buffer territory); accept that video gets no EQ/balance/Milkdrop and remove the UI surface.

---

### Q2 — Numerical equivalence target for `AVAudioUnitEQ` matching

**Why it matters:** EQ math lives twice in the dual architecture (engine path uses `AVAudioUnitEQ`; tap path uses new `BiquadCascade`). Both must produce subjectively identical EQ effects across the 10 bands. If `BiquadCascade` is significantly different, users will hear inconsistency.

**What needs answering:**
- What biquad design does `AVAudioUnitEQ` use internally? (constant-Q vs constant-bandwidth, Robert Bristow-Johnson cookbook formulas vs Apple's own derivation)
- What gain shape (asymmetric vs symmetric)?
- What Q values per band?
- Frequency response curves at typical settings (flat, bass boost, treble boost, mid scoop)?

**Validation method:** Render a known input (white noise, sine sweep, music sample) through `AVAudioUnitEQ` at various preset settings. Capture output. Compare against `BiquadCascade` output during spike. Tolerance: TBD — start with -40 dBFS or better magnitude error per frequency bin, refine empirically.

**Apple docs to consult:** `AVAudioUnitEQ` reference (likely scant on internals), Audio Unit framework docs, possibly WWDC sessions on AU.

---

### Q3 — Render-thread CPU budget for tap-side DSP

**Why it matters:** All DSP runs on the AVPlayer audio render thread. Too much work → render thread misses its deadline → audio glitches → AVPlayer master clock stalls → video stalls. Worse than the ring-buffer architecture's failure mode (which at least had the watchdog).

**Budget components (per `tapProcess` invocation; see Q3 in synthesis above for the authoritative numbers):**
- 10-band biquad cascade: ~5 mults + 4 adds per sample per band per channel = ~180 ops/sample stereo
- Balance: 2 mults per sample stereo
- Visualizer DSP (mono mix + 20-bar RMS + 20-bar Goertzel + 2048-pt vDSP FFT) + single-slot `feed.tryPublish` (drop on contention) — same shape as today's engine tap, proven feasible

**Total at 48 kHz stereo:** ~9 M ops/sec. Apple Silicon can do this several times over per core. Intel is the constraint — particularly older Intel Macs in MacAmp's support matrix.

**Validation method:** Phase 0 spike includes CPU measurement on Apple Silicon AND Intel build targets. Target: <2% of one core for the full DSP chain at 48 kHz stereo.

---

### Q4 — Channel-count / sample-rate handling

**Source variety:** Real video files have 1/2/5.1/7.1 channel counts, 44.1/48/96 kHz sample rates. The tap callback receives whatever the asset's audio track is decoded to.

**Approach (informed by reference-branch lessons + Step 2 reading of `VisualizerPipeline.swift`):**
- For visualizer feed: **mono** Float32 (canonical — the existing engine-side tap mixes N channels → mono; new tap path matches that contract). Surround sources downmix surround → mono.
- For audible path: leave channel layout untouched. `_PreEffects` flag means tap receives the asset's native channel layout (stereo, 5.1, etc.) and writes it back unchanged for AVPlayer's downstream mixing.
- Sample rate: tap delivers audio at the asset's native rate. AVPlayer handles SRC to hardware. We don't need a converter at all — DSP applies in-place at native rate.

**Compare to reference branch:** The engine-routing approach REQUIRED an `AudioConverter` because the engine consumer ran at a different rate (48 kHz fixed) than the tap source (varies). New architecture DROPS the converter entirely — DSP runs at whatever rate AVPlayer is decoding. This is one of the architecture's key fidelity wins.

---

### Q5 — Reference-branch patterns reusable as code

**From `feat/video-audio-engine-routing` (saved):**

Reusable patterns (informed re-implementation, not cherry-pick):
- C-side tap callback structure (`Unmanaged<Context>` handoff in `tapInit` / `tapFinalize`, `MTAudioProcessingTapGetStorage`)
- Channel-map / surround-downmix recipes (`configureChannelMapping`, `inferredSurroundChannelLayoutTag`) — useful for visualizer-feed downmix even though we don't use AudioConverter for the audible path
- Atomics-driven cross-thread state (`ManagedAtomic<UInt64>` for host-time, `ManagedAtomic<Bool>` for flags)
- TSan-on test patterns (driving real bridge in tests, sleeping past tick windows for assertion timing)
- `_test*` seam pattern for production-API exposure to tests

Not reusable (engine-routing-specific):
- `LockFreeRingBuffer` instantiation for video — DSP is in-place, no transport ring
- `AVAudioSourceNode` + engine graph for video — there is no engine bridge for video
- Watchdog + fallback machinery — nothing to fall back from
- HAL property listener + reconfigure gate — AVPlayer handles its own routes
- `videoTapFallbackActive` capability flag branch — capability flag for video becomes simply `true`

---

### Q6 — Existing visualizer-feed extraction

**Today's code:** `VisualizerPipeline` reads from `AVAudioEngine.installTap(onBus:)` on the main mixer node. That feeds the spectrum analyzer + Butterchurn snapshot.

**New architecture (corrected after Step 2 reading — see Q6 in the synthesis above for detail):** Both engine path and tap path need to feed the visualizer. The existing `VisualizerSharedBuffer` is already a single-slot SPSC hand-off carrying **pre-computed visualizer arrays** (RMS×20 + Goertzel×20 + oscilloscope×76 + Butterchurn FFT×1024+1024) — not raw PCM. Extraction = rename + visibility promotion of `VisualizerSharedBuffer` and `VisualizerScratchBuffers`; video tap runs the same engine-side DSP into its own per-tap scratch buffers and calls `feed.tryPublish`.

**Original "question for research" resolved by `research-notes/visualizer-feed.md`** — see that file for full producer/consumer mapping and synthesis Q6 above for the corrected scope.

---

## Reference materials

- **`tasks/video-audio-engine-routing/`** (saved task folder) — Phase 0 spike findings, Phase 1 engine-config-observer plan, Phase 2 `MTAudioProcessingTap` plan (the *spec* is reusable; the implementation choice differs), Phase 7 quality-investigation findings (the route-change + clock-domain learnings that prompted the pivot)
- **`feat/video-audio-engine-routing`** branch (paused, pushed to origin) — full implementation of the engine-routing approach. Read end-to-end during Step 2 retrospective.
- **`tasks/_context/s3-2-pivot.md`** — three-step pivot tracker
- **Apple docs:** TN2249 ("Using `MTAudioProcessingTap` to process audio data tapped from `AVPlayer`"), `AVMutableAudioMix`, `AVAudioUnitEQ`, `MTAudioProcessingTap` framework reference

---

## Out of scope

- Audio-path changes (local files, streams) — engine path stays intact
- HLS audio (S3-3) — that's a separate task
- HLS video — different platform constraint (`MTAudioProcessingTap` doesn't fire reliably for streaming AVPlayerItems per QA1716; documented in `_context/state.md`)
- Visualizer mode changes (spectrum vs Butterchurn selection) — UI/preference work, not part of pipeline
