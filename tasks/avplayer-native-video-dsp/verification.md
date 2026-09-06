# S3-2 Phase 8 — Verification Matrix

> **Purpose:** Record the pass/fail of every gate in the research.md "Verification gate matrix" (15 gates, tiered Static / Dynamic / Lifecycle). Automated gates are run by Claude; **Dynamic gates are HARDWARE-MANUAL — the user runs them and records the result here.** Per todo 8.17, any gate FAILURE → ADR amendment + retry, NOT a soft-skip.
>
> **Branch:** `feat/avplayer-native-video-dsp` (pushed to origin at `5fe8c3c` (docs sync; code unchanged since `944795a`); unmerged, PR #C not yet opened) · **Toolchain:** Xcode 27 / Swift 6.4 · **Hardware:** Apple Silicon (M-series) · *(checklist corrected 2026-09-05; manual run IN PROGRESS from 2026-09-05 — live results in the runbook artifact https://claude.ai/code/artifact/1b5d48d1-5b5c-49ff-bff0-eb23beb8caf8; this file is transcribed at the end)*

---

## Static gates (automated) ✅

| # | Gate | Result | Evidence (date / commit) |
|---|---|---|---|
| 8.1 | CPU benchmark — Apple Silicon, worst-case DSP core (preamp + all 10 EQ bands + balance + visualizer), 1024-frame stereo @ 48 kHz | ✅ **PASS (automated Debug regression guard only)** | `VideoTapCPUBenchmarkTests` (2026-06-27). **Debug (`-Onone`):** budget 21,333 µs, **p99 ≈ 11% / max ≈ 13%** of the deadline. Proves the DSP **fits the audio deadline with margin even unoptimized** (p99 ≤ 50% hard gate). **Scope/caveats (Oracle):** this is a synthetic dense microbenchmark of the DSP CORE — it does NOT replicate the plan's full gate (no real playback, no baseline-vs-full-chain delta, no 44.1/48/5.1 corpus, no `MTAudioProcessingTapGetSourceAudio`, omits the Mutex refresh; the test build is Debug not Release). It is a regression guard, NOT proof of the production figure. |
| 8.1b | CPU benchmark — **production `tapProcess` 99p ≤10%** via Instruments Time Profiler on the **Release** signed `.app` | ⏳ **MANUAL — required for the real gate** | The Debug guard does NOT prove the Release ≤10% figure (Release is faster, but by an unmeasured factor on this code). Run Time Profiler on the Release build over the 44.1/48/5.1 corpus and record actual `tapProcess` 99p here. Until then the production CPU gate is UNVERIFIED. **best outcome PARTIAL (aggregate `tapProcess` share of the render thread + the step-3 telemetry counters as combined evidence); literal 99p not producible** — Time Profiler reports an aggregate CPU share per symbol, `VideoTap.swift:112` samples 1-in-64 into two bucket counters, and the every-callback benchmark mode named in todo 8.1 was never built (2026-09-05). |
| 8.2 | CPU benchmark — Intel build target | ⛔ **NOT ABLE TO COMPLETE** — no Intel Mac; DSP identical scalar; Apple-Silicon result is the primary gate (2026-09-05) | Build targets `arm64` + `x86_64`; Intel perf can't be measured without an Intel Mac. A universal binary can be built (`ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO`) if Intel hardware appears. |
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
| 8.5 | Long-playback A/V drift | Play ONE user-supplied video ≥10 min long with visible lip-sync content (no in-repo clip qualifies — all five clapperboard clips are 3.000 s). Do NOT loop a short clip: each loop restarts the AVPlayerItem, re-fires tapPrepare/StartOfStream and resets accumulated drift. | A/V stays in sync within ~±40 ms (lips match); no growing drift (judged perceptually — no drift harness exists for the in-place tap) | ☐ | pending user-supplied ≥10-min lip-sync video |
| 8.6 | Route change — **AirPods (1st gen)** | Mid-video: connect AirPods, then disconnect | Resumes ≤500 ms, EQ still applied, no silence | ☐ | |
| 8.7 | Route change — **AirPods Pro** | Same | Same | ☐ | |
| 8.8 | Route change — **AirPlay receiver (v1)** | Mid-video: select an AirPlay-1 target, then back | Same | ☐ | |
| 8.9 | Route change — **AirPlay-2 receiver** | Same with an AirPlay-2 target | Same | ☐ | |
| 8.10 | **System output switch** | System Settings → Sound → switch internal speakers ↔ HDMI/display speakers mid-video | Same (≤500 ms, EQ intact) | ☐ | |
| 8.11 | **Bluetooth codec switch** (AAC ↔ SBC) | Force via a BT device / Bluetooth Explorer mid-video | Tap continuity, no audio drop >200 ms | ⛔ **NOT ABLE AS WRITTEN** — no supported AAC↔SBC forcing path on macOS 15/27 (Bluetooth Explorer not installed/shipped; debug menu removed macOS 12+); optional device-substitution fallback → PARTIAL if run (2026-09-05) | Fallback = device substitution (AAC-capable device → SBC-only device); that tests a device change, not a renegotiation → record PARTIAL if done. User decides. |
| 8.12 | Mid-playback format re-prepare | Multi-track item / track swap (advanced — skip if not easily reproducible) | `tapPrepare` re-fires, coefficients recompute (EQ stays correct) | ⛔ **NOT ABLE TO COMPLETE** — no in-app trigger (no track picker; audioMix set once per item, ADR-7); optional gate, skip sanctioned (2026-09-05) | optional; `VideoTap.buildAudioMix` attaches to `audioTracks.first` |
| 8.13 | **5.1 surround** | Play `clapperboard-videos/5_mp4_480_surround.mp4` with EQ on | Plays (native downmix), visualizer animates (no clipping), EQ audible across channels | ☐ | (visualizer side already user-verified in Phase 4 todo 4.17) |
| 8.14 | **Item replacement** (video → audio and back) | Play video, then load a music track (and reverse) | No leak, no crash, audio gap ≤~200 ms. **Known issue: video→audio doesn't auto-play (P-6) — hit Next; that's the tracked finding, not a new failure.** | ☐ | |
| 8.5b | **Live EQ/preamp/balance change during video** | While a video plays, drag EQ bands, preamp, and balance | Audio changes in real time, no glitch/dropout on each change (user already verified the *function* in todo 5.16; this is the no-glitch-under-stress confirmation) | ☐ | |
| 8.5c | **Seek/scrub with EQ active** | Seek/scrub repeatedly while EQ is on | No stale-filter artifact (clean audio right after each seek — `StartOfStream` reset), no crash | ☐ | |
| 8.5d | **Visualizer mode switch during video** | Cycle spectrum → oscilloscope → Butterchurn while video plays | All modes animate from the video audio; no glitch on switch (covers Phase 4 in stress) | ☐ | |
| 8.5e | **Telemetry counters** | After ~1 min of heavy-EQ video, read `VideoTapContext.diagnosticSnapshot` over LLDB (no Console/log path exists; counters are 1-in-64 sampled). **Release re-signed with `get-task-allow` first; Debug fallback; record which build produced the numbers.** Sequence via the xcodebuildmcp CLI debugging workflow: `xcodebuildmcp debugging attach --pid <pid> --make-current` → `lldb-command --command "breakpoint set --file EqualizerController.swift --line 106 --one-shot true"` → `continue` → `po context.diagnosticSnapshot` (inside `pollVideoTapSampleRates`) → if the optimised frame hides `context`, `po self.registeredVideoTapContexts.compactMap { $0.value }.map { $0.diagnosticSnapshot }` → `detach`. Attach needs `com.apple.security.get-task-allow`: the Debug app has it, the Developer-ID Release app does not (hardened runtime; `MacAmp.entitlements` sets `allow-dyld-environment-variables=false`), so re-sign the Release app with the Apple Development identity (`A5V7U473GS`) after 7.9/8.1b. | `budgetOverrunCount` and `deadlineRiskCount` are 0 (or near-0) on Apple Silicon | ☐ | (Phase 6 counters; needs a debug readout — note Release-re-signed vs Debug) |

### Signed-bundle smoke (Phase 7 gates 7.9 / 7.10, also part of Phase 8 manual)

| # | Gate | How | Pass criteria | Result |
|---|---|---|---|---|
| 7.9 + 8.1b | Signed **Release** .app + Time Profiler | Build Release with CONFIGURATION_BUILD_DIR redirected (see runbook) so dist/ is not clobbered; codesign --verify --strict; play video; xcrun xctrace record --template 'Time Profiler' --attach MacAmp --time-limit 60s per corpus file (44.1 stereo / 48 stereo / 5.1) | EQ audible on video; tapProcess self time ≤10% of the render thread (AGGREGATE share — Time Profiler cannot give a per-callback 99p; record PARTIAL unless an every-callback timing mode is added) | ☐ |
| 7.10 (leak) | **Debug** .app + Memory Graph / Allocations (or `xcrun heap` census) | Debug build carries get-task-allow; the Developer-ID Release app does not and MacAmp.entitlements blocks dyld env vars, so Allocations cannot attach to it. Filter Recorded Types on `MacAmp.VideoTapContext` (module is MacAmp) | VideoTapContext live count returns to 0 after stop; Created & Destroyed == clips played | ☐ |

---

## Summary

- **Automated gates ✅ PASS:** 8.3 (EQ ≤0.5 dB), 8.4 (TSan 116/116, no races), 8.15 (lifecycle), and 8.1's **Debug regression guard** (DSP fits the deadline with margin even unoptimized). The DSP is numerically correct, thread-safe, and lifecycle-bulletproof.
- **The production CPU gate (8.1b) is NOT yet verified** — it requires a Release/Instruments `tapProcess` measurement. The Debug guard is a regression net, not the production figure.
- **Manual / hardware gates ⏳ IN PROGRESS (user, from 2026-09-05):** 8.1b (Release Instruments), 8.5–8.10/8.13/8.14 + 8.5b–8.5e (route changes, live EQ stress, seek, surround, replacement, telemetry), 7.9/7.10 (signed-bundle). Live PASS/PARTIAL/FAIL/NOT ABLE + notes are kept in the runbook artifact (https://claude.ai/code/artifact/1b5d48d1-5b5c-49ff-bff0-eb23beb8caf8) and transcribed into the Result columns here at the end. 8.2/8.11/8.12 are dispositioned below.
- **Gate dispositions (2026-09-05):**
  - **8.2 — ⛔ NOT ABLE TO COMPLETE.** No Intel Mac available. The DSP is identical scalar code, so the Apple Silicon result is the primary gate (already the accepted disposition above). A universal binary can be built (`ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO`) if Intel hardware appears.
  - **8.12 — ⛔ NOT ABLE TO COMPLETE.** No in-app trigger: MacAmp has no audio-track picker, and `VideoTap.buildAudioMix` attaches to `audioTracks.first` with `audioMix` set once per item per ADR-7. The gate is optional; the skip is sanctioned.
  - **8.11 — ⛔ NOT ABLE AS WRITTEN.** There is no supported way to force a codec renegotiation on macOS 15/27: Bluetooth Explorer is not installed and is no longer shipped in Additional Tools for Xcode, and the Option+Shift Bluetooth debug menu was removed in macOS 12+. Optional fallback = device substitution (AAC-capable device → SBC-only device), which tests a device change rather than a renegotiation → record **PARTIAL** if run; the user decides.
  - **8.1b — PARTIAL is the best available outcome.** A per-callback 99p cannot literally be produced: Time Profiler reports an aggregate CPU share per symbol, `VideoTap.swift:112` samples 1-in-64 with only two bucket counters, and the every-callback benchmark mode named in todo 8.1 was never built. Best outcome = aggregate `tapProcess` share ≤10% of the render thread + the step-3 telemetry counters as combined evidence. The production CPU figure stays **UNVERIFIED** until then.
  - **8.5 — CONDITIONAL, not "not able."** Needs a user-supplied ≥10-minute lip-sync video (every in-repo clip is 3.000 s; looping resets drift). Pending the user's video.
  - **8.6–8.9 — hardware-dependent** (AirPods 1st gen, AirPods Pro, AirPlay-1, AirPlay-2). Any the user cannot source → record NOT ABLE with the reason.
  - Per 8.17: NOT ABLE / NOT RUN with a stated reason is acceptable; a silent soft-skip is not.
- **Telemetry readout path + build order (2026-09-05):** the LLDB path is the **xcodebuildmcp CLI debugging workflow** (`attach --pid <pid> --make-current`, `lldb-command`, `continue`, `detach`; also add-breakpoint/stack/variables) — run it from a **user terminal**: the xcodebuildmcp daemon does not auto-start inside Claude's sandboxed shell. Attach requires `com.apple.security.get-task-allow`, which the Debug app carries and the Developer-ID Release app does not. **RELEASE FIRST:** run 7.9 (signed smoke) and 8.1b (Time Profiler) on the Developer-ID Release build, THEN re-sign that same app with `get-task-allow` using the Apple Development identity (`A5V7U473GS`) for the 8.5e telemetry read; **DEBUG FALLBACK** if attach or the expression fails. Instruments Allocations (the 7.10 thorough path) is Debug-only regardless — dylib injection is blocked on every hardened build — while `xcrun heap` works on any get-task-allow build. Record which build produced the 8.5e numbers. Xcode's own MCP server (`mcp__xcode__*`, reconnected 2026-09-05) **IS an LLDB path** — `RunProject` (attachDebugger) + `InvokeDebuggerCommand` + `GetConsoleOutput` + `StopProject`; an Xcode Run injects `get-task-allow` at build time, so the 8.5e read on Release needs no re-sign (set the scheme's Run action to Release in Edit Scheme; Debug is the default and the fallback) — **PATH A** in the runbook, driven by Claude; `xcodebuildmcp debugging attach --pid` is **PATH B**.
- Any FAILURE → record it, then ADR amendment + targeted retry (todo 8.17). Do NOT soft-skip.
