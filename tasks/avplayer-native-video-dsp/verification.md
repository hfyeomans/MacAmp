# S3-2 Phase 8 — Verification Matrix

> **Purpose:** Record the pass/fail of every gate in the research.md "Verification gate matrix" (15 gates, tiered Static / Dynamic / Lifecycle). Automated gates are run by Claude; **Dynamic gates are HARDWARE-MANUAL — the user runs them and records the result here.** Per todo 8.17, any gate FAILURE → ADR amendment + retry, NOT a soft-skip.
>
> **Branch:** `feat/avplayer-native-video-dsp` · **Toolchain:** Xcode 27 / Swift 6.4 · **Hardware:** Apple Silicon (M-series)

---

## Static gates (automated) ✅

| # | Gate | Result | Evidence (date / commit) |
|---|---|---|---|
| 8.1 | CPU benchmark — Apple Silicon, worst-case DSP core (preamp + all 10 EQ bands + balance + visualizer), 1024-frame stereo @ 48 kHz | ✅ **PASS (automated Debug regression guard only)** | `VideoTapCPUBenchmarkTests` (2026-06-27). **Debug (`-Onone`):** budget 21,333 µs, **p99 ≈ 11% / max ≈ 13%** of the deadline. Proves the DSP **fits the audio deadline with margin even unoptimized** (p99 ≤ 50% hard gate). **Scope/caveats (Oracle):** this is a synthetic dense microbenchmark of the DSP CORE — it does NOT replicate the plan's full gate (no real playback, no baseline-vs-full-chain delta, no 44.1/48/5.1 corpus, no `MTAudioProcessingTapGetSourceAudio`, omits the Mutex refresh; the test build is Debug not Release). It is a regression guard, NOT proof of the production figure. |
| 8.1b | CPU benchmark — **production `tapProcess` 99p ≤10%** via Instruments Time Profiler on the **Release** signed `.app` | ⏳ **MANUAL — required for the real gate** | The Debug guard does NOT prove the Release ≤10% figure (Release is faster, but by an unmeasured factor on this code). Run Time Profiler on the Release build over the 44.1/48/5.1 corpus and record actual `tapProcess` 99p here. Until then the production CPU gate is UNVERIFIED. |
| 8.2 | CPU benchmark — Intel build target | ⏳ **MANUAL / N/A on this hardware** | Build targets `arm64` + `x86_64`; Intel perf can't be measured without an Intel Mac. Defer to an Intel Mac run or accept the Apple-Silicon result as the primary gate (DSP is identical, scalar). |
| 8.3 | Numerical EQ match — `BiquadCascade` vs `AVAudioUnitEQ` ≤0.5 dB | ✅ **PASS** | `BiquadNumericalMatchTests` (7 tests) green, 2026-06-27, HEAD post-`11bcd8a`. 5 presets × 40 log freqs 20 Hz–20 kHz, worst-case ≤0.5 dB. |
| 8.4 | TSan — full `MacAmpApp` suite with `-enableThreadSanitizer YES` | ✅ **PASS** | **116/116 green, no data races**, 2026-06-27. |

---

## Lifecycle gates (covered by Phase 7 automated tests) ✅

| # | Gate | Result | Evidence |
|---|---|---|---|
| 8.15 | Rapid track skip, tap-create failure, pause/resume, item replacement | ✅ **PASS** | `VideoTapLifecycleTests` (11 tests): `tenRapidCyclesNoLeak`, `tapCreateFailureReleasesContext` (ADR-10), `pauseResumePreservesContext`, `replaceCurrentItemWithNilReleasesContext`, etc. TSan-green. Seek→reset CORRECTNESS via `resetClearsState`. |

---

## Dynamic transition gates — HARDWARE-MANUAL CHECKLIST (user runs)

> **How to run:** Build + launch the app (Debug is fine; Release for 8.1b). Play a local **video** file with **EQ ON** and a couple of bands boosted so you can hear the effect. Then perform each transition and record PASS/FAIL + notes below. These are the failure modes that killed the *original* engine-routing approach, so they matter.
>
> **Universal pass criteria for route changes (8.6–8.11):** after the transition — (a) audio resumes within ~500 ms, (b) **no permanent silence**, (c) EQ is **still applied** (the boosted bands still sound boosted), (d) video keeps playing / re-syncs, (e) no crash.

| # | Gate | How to test | Pass criteria | Result | Notes |
|---|---|---|---|---|---|
| 8.5 | Long-playback A/V drift | Play a video (loop a short clip) for **≥10 min** continuous | A/V stays in sync within ~±40 ms (lips match); no growing drift | ☐ | |
| 8.6 | Route change — **AirPods (1st gen)** | Mid-video: connect AirPods, then disconnect | Resumes ≤500 ms, EQ still applied, no silence | ☐ | |
| 8.7 | Route change — **AirPods Pro** | Same | Same | ☐ | |
| 8.8 | Route change — **AirPlay receiver (v1)** | Mid-video: select an AirPlay-1 target, then back | Same | ☐ | |
| 8.9 | Route change — **AirPlay-2 receiver** | Same with an AirPlay-2 target | Same | ☐ | |
| 8.10 | **System output switch** | System Settings → Sound → switch internal speakers ↔ HDMI/display speakers mid-video | Same (≤500 ms, EQ intact) | ☐ | |
| 8.11 | **Bluetooth codec switch** (AAC ↔ SBC) | Force via a BT device / Bluetooth Explorer mid-video | Tap continuity, no audio drop >200 ms | ☐ | |
| 8.12 | Mid-playback format re-prepare | Multi-track item / track swap (advanced — skip if not easily reproducible) | `tapPrepare` re-fires, coefficients recompute (EQ stays correct) | ☐ | optional |
| 8.13 | **5.1 surround** | Play `clapperboard-videos/5_mp4_480_surround.mp4` with EQ on | Plays (native downmix), visualizer animates (no clipping), EQ audible across channels | ☐ | (visualizer side already user-verified in Phase 4 todo 4.17) |
| 8.14 | **Item replacement** (video → audio and back) | Play video, then load a music track (and reverse) | No leak, no crash, audio gap ≤~200 ms. **Known issue: video→audio doesn't auto-play (P-6) — hit Next; that's the tracked finding, not a new failure.** | ☐ | |
| 8.5b | **Live EQ/preamp/balance change during video** | While a video plays, drag EQ bands, preamp, and balance | Audio changes in real time, no glitch/dropout on each change (user already verified the *function* in todo 5.16; this is the no-glitch-under-stress confirmation) | ☐ | |
| 8.5c | **Seek/scrub with EQ active** | Seek/scrub repeatedly while EQ is on | No stale-filter artifact (clean audio right after each seek — `StartOfStream` reset), no crash | ☐ | |
| 8.5d | **Visualizer mode switch during video** | Cycle spectrum → oscilloscope → Butterchurn while video plays | All modes animate from the video audio; no glitch on switch (covers Phase 4 in stress) | ☐ | |
| 8.5e | **Telemetry counters** | After ~1 min of heavy-EQ video, check `VideoTapContext.diagnosticSnapshot` (debugger/Console) | `budgetOverrunCount` and `deadlineRiskCount` are 0 (or near-0) on Apple Silicon | ☐ | (Phase 6 counters; needs a debug readout) |

### Signed-bundle smoke (Phase 7 gates 7.9 / 7.10, also part of Phase 8 manual)

| # | Gate | How | Pass criteria | Result |
|---|---|---|---|---|
| 7.9/7.10 + 8.1b | Signed `.app` smoke + Instruments | Build + sign Debug `.app` (per `docs/RELEASE_BUILD_GUIDE.md`, no notarization needed); play video; run Instruments **Time Profiler** (8.1b) + **Memory Graph** (leak) over ~1 min | EQ audible on video; `VideoTapContext` count returns to 0 after stop (no leak); `tapProcess` 99p ≤10% in Release | ☐ |

---

## Summary

- **Automated gates ✅ PASS:** 8.3 (EQ ≤0.5 dB), 8.4 (TSan 116/116, no races), 8.15 (lifecycle), and 8.1's **Debug regression guard** (DSP fits the deadline with margin even unoptimized). The DSP is numerically correct, thread-safe, and lifecycle-bulletproof.
- **The production CPU gate (8.1b) is NOT yet verified** — it requires a Release/Instruments `tapProcess` measurement. The Debug guard is a regression net, not the production figure.
- **Manual / hardware gates ⏳ pending user:** 8.1b (Release Instruments), 8.2 (Intel), 8.5–8.14 + 8.5b–8.5e (route changes, live EQ stress, seek, surround, replacement, telemetry), 7.9/7.10 (signed-bundle). Fill in the Result columns.
- Any FAILURE → record it, then ADR amendment + targeted retry (todo 8.17). Do NOT soft-skip.
