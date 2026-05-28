# S3-2 Architectural Pivot Tracker

> **Date:** 2026-05-01 (created), 2026-05-28 (last update)
> **Status:** Steps 1-3 ✅. Implementation: **Phase 1 ✅, Phase 2 ✅ FULLY CLOSED** (85/85 TSan; todo 2.39 smoke ✅ + todo 2.40 leak check ✅ 2026-05-28 via Memory Graph Debugger — no leak). **Phase 3 NEXT, GATED on P-4** (race-safe coefficient hand-off redesign + plan.md ADR-4 amendment + Oracle re-review BEFORE any render-thread coefficient code). Phases 4-9 remain.
> **Purpose:** Track the architectural pivot of S3-2 from engine-routing to AVPlayer-native DSP. Authoritative source for current S3-2 status — the existing `state.md` / `tasks_index.md` / `resume-prompt.md` files reflect the PRE-pivot state of the engine-routing branch (preserved for historical accuracy of that branch's work) and cross-reference this file for current status.

---

## Strategic decision

S3-2 (`video-audio-engine-routing`) reached Phase 7 testing and revealed the engine-routing approach for video audio fights the macOS platform too hard. The architecture extracts video audio from AVPlayer via `MTAudioProcessingTap`, writes it to a `LockFreeRingBuffer`, has `AVAudioSourceNode` consume from the ring on the engine side, and applies engine processing (EQ, balance, visualizer tap). Three structural problems emerged:

1. **`AVAudioEngineConfigurationChange` unreliable for AirPlay/AirPods route changes.** Apple's notification only fires when the engine's effective configuration actually changes (sample rate, channel count, etc.). AirPods on macOS route through the AirPlay subsystem and don't always trigger it. Proven by missing `Engine will reconfigure` log line in user traces during Phase 7 testing — the watchdog gate never armed for the bug case.

2. **Master-clock-coupled video stalls.** AVPlayer's audio queue is the master clock for video on macOS. Any ring under-run on the engine consumer side stalls the master clock, which stalls the video frame. Mitigated but not eliminated by larger ring (16 K frames vs original 4 K).

3. **Dual-clock-domain drift.** Engine output clock vs AVPlayer master clock are unsynchronized. Drift accumulates on long playback (>5–10 min) and resets on pause/resume. Phase 7 fixes (Mastering SRC + 16 K ring) reduced perceived drift but the topology guarantees some residue.

**Plus tinning artifacts** from the second SRC stage that AudioConverter introduces — required raising AudioConverter's quality tier to Mastering / Max to match what AVPlayer's native pipeline does internally. Net fidelity tax remained.

**The contrarian solve:** don't drag video audio out of AVPlayer. Apply DSP in-place inside the same `MTAudioProcessingTap`, modifying the source buffer that AVPlayer's native pipeline plays. No ring, no engine clock for video, no second SRC stage, no master-clock coupling. AVPlayer keeps full ownership of its clock and route handling; tap-side DSP brings EQ + balance + Milkdrop to where the audio already is.

The cost is a small WET duplication: EQ math lives twice (engine path uses `AVAudioUnitEQ`; tap path uses new `BiquadCascade`). Per Principle 4 (AHA Rule of Three) this is the right kind of WET — different threading, different parameter-update paths, different ownership models. Sharing would create a flag-driven abstraction that conflates two genuinely different scenarios.

---

## Saved reference branch

The engine-routing branch is preserved as a reference (NOT being merged):

- **Branch:** `feat/video-audio-engine-routing`
- **Last commit:** `5af91eb` (`docs(vaer): mark branch paused for S3-2 architectural pivot`)
- **Push status:** ✅ Pushed to origin (off-machine backup)
- **Total commits ahead of `main`:** 44 (43 implementation + 1 pause-doc commit)
- **Phases shipped:** Phase 0 ✅ + Phase 1 ✅ + Phase 2 ✅ + Phase 3 ✅ + Phase 5 ✅ + Phase 6 ✅ + Phase 7 partial (gate v2 + HAL listener + 3 s threshold + edge cases — Oracle 9.2/10 final pass, but real-hardware testing showed the gate v2 still failed because the engine notification didn't fire for the bug case)
- **Tests on saved branch:** 110/110 with TSan
- **Task folder:** `tasks/video-audio-engine-routing/` (`state.md` carries the PAUSED-AS-REFERENCE banner)

The saved branch is the canonical record of the engine-routing approach's most-developed state. Useful as research reference for: channel-mapping / surround-downmix logic, C-side `MTAudioProcessingTap` callback patterns, atomics-driven cross-thread state, TSan test patterns, Oracle review history, the Phase 7 quality investigation findings.

---

## Three-step plan

### Step 1 — Mechanical pivot ✅ DONE (2026-05-01)

| Task | Status | Notes |
|------|--------|-------|
| Push `feat/video-audio-engine-routing` to origin (backup) | ✅ | Tracking set up |
| Cut `feat/avplayer-native-video-dsp` from `main` | ✅ | Branched at main commit `9cca40a` |
| Cherry-pick 13 Phase 1 commits (`3ed4356` → `2aa2f18`) | ✅ | Engine config observer (stream-side resilience). Clean cherry-pick, no conflicts. |
| Drop `wasVideoBridge` field from `PreReconfigureSnapshot` | ✅ | Phase 1 had the field as forward-looking; this branch has no engine video bridge so it's removed. Commit `ffd77c1`. |
| Build + TSan green | ✅ | 72/72 with TSan |
| Scaffold `tasks/avplayer-native-video-dsp/` with 6 canonical files | ✅ | All skeletons created |
| Create this tracker | ✅ | This file |
| Cross-reference from `_context/state.md`, `tasks_index.md`, `resume-prompt.md` | ✅ | All three updated |
| Mark old branch + old task PAUSED | ✅ | `5af91eb` on saved branch |

### Step 2 — Research phase ✅ DONE (2026-05-01)

Oracle 10/10 final after 5 rounds (7.8 → 8.9 → 9.1 → 9.5 → 10). Commits `4a80bf9` → `46bb6af`. See `tasks/avplayer-native-video-dsp/research.md` for the full synthesis + Evidence Ledger. Summary:

| Activity | Status | Kill switch outcome |
|----------|--------|---------------------|
| Phase 0 spike — `MTAudioProcessingTap` in-place buffer modification feasibility | ✅ | ✅ EMPIRICALLY CONFIRMED — audible -20 dB attenuation A/B vs control on macOS 15+ Swift 6.2; programmatic write-verify (pre × gain == post). Architecture green. |
| Apple docs review — TN2249, `AVMutableAudioMix`, AU reference, WWDC archive | ✅ | SDK header documents in-place modification verbatim. `_PreEffects` flag selected. |
| Reference-branch retrospective — read `feat/video-audio-engine-routing` end-to-end | ✅ | 5-item ALLOWLIST + 11-item DENYLIST with file:line citations. 1 modernization gap (`ManagedAtomic` → `Synchronization.Atomic`). |
| `AVAudioUnitEQ` numerical-match research | ✅ | HIGH confidence — Apple uses RBJ cookbook (Butterworth/octave-BW per `AudioUnitParameters.h`). Tolerance ≤0.5 dB / hard reject ≤1 dB. |
| Render-thread CPU budget measurement | Estimated, NOT validated | Empirical benchmark gate landed in plan.md Phase 8 (AS + Intel × 44.1/48 × stereo/5.1). |
| Channel-count / sample-rate handling | ✅ | Audible path leaves layout untouched; visualizer-feed downmixes surround → mono. |
| `VisualizerFeed` extraction approach | ✅ | Rename + visibility-promotion of `VisualizerSharedBuffer` + `VisualizerScratchBuffers`; ~100-150 LOC; engine-path byte-for-byte identical. |
| Findings written to `research.md`; Oracle research-pass review | ✅ | 17-row Evidence Ledger; 11-gate verification matrix; Concurrency Decision Record; Tap Lifecycle Contract; Tooling Constraints. |

### Step 3 — Plan phase ✅ DONE (2026-05-02)

Oracle 9.8/10 final after 5 rounds (8.3 → 8.9 → 10 → 9.2 → 9.8). Commits `1ae8e80` → `fdce0ed`. The 0.2 below 10 reflects added scope from ADR-3a (Containment of `@unchecked Sendable` drift), added at user request 2026-05-02 with 3 durable gates (header contract / `RenderThreadSafe` marker / DEBUG Mirror+source tests).

| Activity | Status |
|----------|--------|
| Write `plan.md` from research | ✅ |
| Iterate with Oracle until ≥9/10 APPROVED | ✅ (final 9.8/10 — exceeds bar) |
| Get user sign-off | ✅ 2026-05-02 |
| Derive concrete `todo.md` phases from plan | ✅ 2026-05-02 |
| Begin implementation phases (9 phases per plan §6) | 🔧 Phase 1 ✅ + Phase 2 ✅ (fully closed incl. todo 2.40 leak check 2026-05-28); **Phase 3 NEXT, gated on P-4** |

---

## File index

- **`tasks/avplayer-native-video-dsp/`** — new task folder
  - `state.md` — task-internal status (Step 1 done, Step 2 next)
  - `research.md` — research questions + Phase 0 spike kill-switch criteria
  - `plan.md` — skeleton (populated in Step 3)
  - `todo.md` — skeleton (populated in Step 3)
  - `placeholder.md` — empty
  - `depreciated.md` — empty
- **`tasks/video-audio-engine-routing/`** — saved task folder, `state.md` carries PAUSED banner
- **`tasks/_context/s3-2-pivot.md`** — this file
- **`tasks/_context/state.md`** — top-of-file pivot banner; sprint table reflects pivot
- **`tasks/_context/tasks_index.md`** — `video-audio-engine-routing` row marked PAUSED-AS-REFERENCE; new task added
- **`tasks/_context/resume-prompt.md`** — Active Work Queue updated; First Action points at this file

---

## Decision log (key moments)

- **2026-04-30** — Phase 7 quality investigation on `feat/video-audio-engine-routing`: SRC artifacts, ring under-runs causing video stalls, drift over long playback. Several iterations fixed each symptom but the topology kept producing new edge cases.
- **2026-04-30** — Phase 7 watchdog gate v2 + HAL listener (Oracle 9.2/10). Real-hardware testing reproduced the route-change bug because `AVAudioEngineConfigurationChange` doesn't fire for AirPlay route changes — proven by missing log line.
- **2026-05-01** — User raised the contrarian framing: instead of dragging video audio out of AVPlayer, apply processing in-place via the same tap. Architecture sketch laid out in conversation. User chose to pivot.
- **2026-05-01** — Step 1 mechanical pivot executed.
- **2026-05-02** — Phase 1 (VisualizerFeed extraction) ✅ + Phase 2 (production tap scaffold, Option C audioMix-on-construction, ADR-3a containment) ✅ landed; 7 Oracle rounds → 9.0/10 APPROVED; 85/85 TSan. ADR-4 A/B-swap install withdrawn as race-unsafe → P-4 gates Phase 3.
- **2026-05-28** — Phase 2 fully closed: todo 2.40 leak check ✅ via Memory Graph Debugger on the real playback path (`VideoTapContext` + both coefficient blocks 1→0 across clip load→teardown, no leak). Found that Allocations Instruments can't show pure-Swift classes by name (→ `_context/instruments-allocations-workflow.md`). Non-blocking finding P-6 logged (video→audio no auto-play). Next real work: P-4 coefficient hand-off redesign.
