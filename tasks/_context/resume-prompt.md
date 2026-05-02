# S3 Resume Prompt

> **Purpose:** One-stop pickup file for resuming MacAmp Sprint S3 work in a fresh Claude Code session. Update this file's "Current State" + "Active Work Queue" + "First Action" sections after each phase completion or PR merge so it always reflects HEAD.
>
> **How to use:** In a new session, paste:
> *"Read `tasks/_context/resume-prompt.md` and follow it. Start with the next active task."*

---

## Current State (update after each phase completion or PR merge)

> ⚠️ **S3-2 ARCHITECTURAL PIVOT — IMPLEMENTATION IN PROGRESS (2026-05-02).** `feat/video-audio-engine-routing` is **PAUSED-AS-REFERENCE** (preserved at `5af91eb`, pushed to origin). S3-2 re-attempted as **`avplayer-native-video-dsp`** on branch `feat/avplayer-native-video-dsp`. **Steps 1+2+3 ✅ + Phase 1 ✅ + Phase 2 ✅ done. Phase 3 implementation NEXT.** See `tasks/_context/s3-2-pivot.md` for the strategic decision log + step-by-step status — that file is authoritative.

**Last update:** 2026-05-02 (Phase 2 — production tap scaffold + ADR-3a containment + Oracle-driven Option C revision — landed; 7 Oracle review rounds (final 9.0/10 APPROVED). Final architecture: `audioMix` configured during `AVPlayerItem` CONSTRUCTION via `VideoTap.buildAudioMix(audioTrack:context:)` + `VideoPlaybackController.loadVideo`'s `audioMixBuilder`/`isStillRelevant` parameters + `AudioPlayer.startVideoLoad(track:)` orchestrator. NOT `attachVideoTap`/`detachVideoTap` facades — those were withdrawn during revision. Pass-through DSP only (no biquad math). 85/85 TSan green. Four plan deviations documented in `placeholder.md` P-1/P-2/P-3/P-4 + task `state.md`. Phase 3 (`BiquadCascade` + balance + numerical match) NEXT, gated on P-4 race-safe coefficient hand-off redesign.)
**Main HEAD:** `9cca40a` — `docs(_context): close out Phase 2; advance vaer to Phase 3-next` (this is the OLD vaer message; main hasn't advanced).
**`feat/avplayer-native-video-dsp` HEAD:** latest on branch — run `git log -1 --oneline` to confirm. **31 commits ahead of main** (run `git rev-list --count main..HEAD`):
- 13 cherry-picked Phase-1 commits (engine config observer for stream-side resilience, range ending at `2aa2f18`)
- 1 mechanical-pivot cleanup (`ffd77c1`)
- 1 task-folder scaffold (`a3c9aba`)
- 5 Step-2 research commits (`4a80bf9` → `46bb6af`) — Oracle 10/10
- 5 Step-3 plan commits (`1ae8e80` → `fdce0ed`) — Oracle 9.8/10 (incl. ADR-3a containment cycle)
- 1 docs cleanup + todo derivation (`1f7a0a0`)
- 1 Phase 1 implementation (`146a8b4`)
- 1 Phase 1 todo update (`3c4f40c`)
- 1 resume-prompt rewrite for Phase 2 pickup (`445a051`)
- Plus subsequent self-updates (this verification fix + future) — `git log` is authoritative
**`spike/avplayer-inplace-tap-dsp` HEAD (throwaway, retained locally):** `dd53d64` — Phase 0 spike. Kill-switch resolved: in-place tap DSP works on macOS 15+ with Swift 6.2 toolchain.
**`feat/video-audio-engine-routing` HEAD (paused-as-reference):** `5af91eb`. 44 commits ahead of main, pushed to origin.
**Tests:** 85/85 with TSan ON (72 baseline + 2 `VideoTapSendableContractTests` + 6 `VideoTapLifecycleTests` + 5 `VideoSeekStateMatrixTests`). Target by S3-2 close: 110+/110+ (Phase 3 BiquadNumericalMatch ~4 tests, Phase 7 additional lifecycle ~6 tests).
**PRs merged total:** 80. No PR opened on either S3-2 branch yet (single PR at S3-2 close).

**Most recent docs commits on main:**
- `07a3ee8` HLS video future-work doc (S3-2 vs S3-3 naming clarification + 3 options for hypothetical HLS-video work)
- `9fa0238` `*.m4v` gitignore
- `5dea7d3` Phase 0 status sweep
- `1d4eca1` Phase 0 spike findings — Path NONE selected (these are OLD-vaer-branch artifacts, kept on main)

**Most recent task closed:** `tasks/done/stream-pause-tail/` (S3-1B, PR #82, merged 2026-04-30, merge commit `b60fd57`). See `tasks/_context/state.md` for the full S3-1B closeout summary.

---

## Active Work Queue (ordered — start at the top)

### 1. IMPLEMENTING — `tasks/avplayer-native-video-dsp/` (S3-2 PIVOT)

**Status:** Steps 1+2+3 ✅ + Phase 1 ✅ + Phase 2 ✅ done. **Phase 3 (`BiquadCascade` + balance + numerical match) NEXT** — see `tasks/avplayer-native-video-dsp/todo.md` for the per-phase work breakdown.

**Why pivoted:** The original S3-2 (`feat/video-audio-engine-routing`) reached Phase 7 testing and revealed structural issues with the engine-routing approach: `AVAudioEngineConfigurationChange` unreliable for AirPlay/AirPods routes (proven by missing log line), master-clock-coupled video stalls, dual-clock-domain drift, tinning artifacts from a second SRC stage. Contrarian solve: don't drag video audio out of AVPlayer — apply DSP in-place inside the same `MTAudioProcessingTap` so AVPlayer's native pipeline plays the modified buffer. No ring, no engine clock for video, no master-clock coupling. Full strategic decision in `tasks/_context/s3-2-pivot.md`.

**Step 1 — Mechanical pivot ✅ DONE 2026-05-01.** Branch + cherry-pick + scaffold. 72/72 tests with TSan.

**Step 2 — Research ✅ DONE 2026-05-01 (Oracle 10/10 after 5 rounds).** Commits `4a80bf9` → `46bb6af`. Phase 0 spike empirically confirmed in-place tap DSP works (audible -20 dB attenuation A/B vs control on macOS 15+ Swift 6.2). Apple SDK header documents the contract verbatim. Full research package: `research.md` + 5 `research-notes/*.md` + 17-row Evidence Ledger + Tap Lifecycle Contract + Concurrency Decision Record + Tooling Constraints.

**Step 3 — Plan ✅ DONE 2026-05-02 (Oracle 9.8/10 after 5 rounds).** Commits `1ae8e80` → `fdce0ed`. The 0.2 below 10 reflects added scope from ADR-3a (Containment of `@unchecked Sendable` drift) added at user request 2026-05-02 with three durable gates: header contract block + `RenderThreadSafe` marker protocol + DEBUG Mirror+source-level reflection tests. User signed off 2026-05-02. 11+1 ADRs, 9 implementation phases, 15-gate verification matrix.

**Phase 1 — `VisualizerFeed` + `VisualizerScratchBuffers` extraction ✅ DONE 2026-05-02.** Commit `146a8b4`. Two private nested types in `VisualizerPipeline.swift` promoted to module-internal across new files (`VisualizerFeed.swift` ~110 LOC + `VisualizerScratchBuffers.swift` ~195 LOC, latter includes `GoertzelCoefficients` as cohesive unit). 5 type renames + 5 field renames in `VisualizerPipeline.swift` (661 → 378 lines). Engine path byte-for-byte identical. 72/72 tests TSan green.

**Phase 2 — production tap scaffold + ADR-3a containment + Oracle-driven Option C revision ✅ DONE 2026-05-02.** Initial commit `ac7e0d5` then 18 revisions across 7 Oracle review rounds (final 9.0/10 APPROVED). Final architecture: `audioMix` is configured during `AVPlayerItem` CONSTRUCTION (before `AVPlayer` adopts the item) via `VideoTap.buildAudioMix(audioTrack:context:)` (sync) + `VideoPlaybackController.loadVideo` (async, takes `audioMixBuilder` + `isStillRelevant` parameters + identity-guarded observers + seek state matrix) + `AudioPlayer.startVideoLoad(track:)` (private orchestrator with generation counter that short-circuits superseded loads BEFORE any AVPlayer/observer mutation; gates auto-play on `playbackState == .playing` so user pause-during-load is honoured). New files: `RenderThreadSafe.swift`, `VideoDSP/VideoTapContext.swift`, `VideoDSP/VideoTap.swift`, `VideoDSP/BiquadCoefficientSet.swift` (empty stub), `Tests/VideoTapSendableContractTests.swift` (Gate 3a Mirror + Gate 3b regex), `Tests/VideoTapLifecycleTests.swift` (6 lifecycle + race tests), `Tests/VideoSeekStateMatrixTests.swift` (5 seek state matrix tests). `AudioPlayer.swift` + `VideoPlaybackController.swift` modified. Pass-through DSP only. **85/85 TSan green** (72 baseline + 2 contract + 6 lifecycle + 5 seek-state-matrix). **Four plan deviations** documented in task `placeholder.md` P-1/P-2/P-3/P-4 + `state.md` "Phase 2 implementation findings": (1) `RenderThreadSafe: ~Copyable`; (2) Mirror reflection gap on `~Copyable`; (3) `@preconcurrency import AVFoundation`; (4) **ADR-4 install method withdrawn — Phase 3 MUST design a race-safe coefficient hand-off scheme before tapProcess reads coefficients.**

**Phase 3 (`BiquadCascade` + balance + numerical match) NEXT.** **GATING prerequisite:** P-4 redesign of the coefficient hand-off scheme (ADR-4 amendment in plan.md). Three candidates: triple-buffer + atomic in-use counter, RCU/epoch reclamation, `Mutex<BiquadCoefficientSet>` with `withLockIfAvailable`. Update plan.md ADR-4 with the chosen scheme + rationale; re-run Oracle review BEFORE implementation. After P-4 lands: replace empty `BiquadCoefficientSet.swift` stub with real type; add `BiquadCascade.swift` + tests; wire `tapProcess` render-path steps 2-6 from ADR-5; ≤0.5 dB numerical match vs `AVAudioUnitEQ` over 5 EQ presets × log sweep 20 Hz – 20 kHz.

**Remaining phases (per plan.md §6):**
- Phase 3: `BiquadCascade` + balance + numerical match (≤0.5 dB tolerance vs `AVAudioUnitEQ`)
- Phase 4: visualizer DSP integration (video-tap render path)
- Phase 5: EQ + balance state fanout (parallel from `EqualizerController` + `AudioPlayer`)
- Phase 6: production telemetry (deadline-miss instrumentation)
- Phase 7: lifecycle + production tests (TSan, signed-bundle smoke)
- Phase 8: verification matrix execution (15 gates: Static / Dynamic / Lifecycle)
- Phase 9: UI integration polish + final smoke + mandatory docs (`docs/MACAMP_ARCHITECTURE_GUIDE.md` "Audio Mechanism Concurrency Contract" subsection)

See `tasks/avplayer-native-video-dsp/todo.md` for the full work-item checklist (90+ items).

### 2. PAUSED-AS-REFERENCE — `tasks/video-audio-engine-routing/`

Original S3-2 attempt. Branch `feat/video-audio-engine-routing` preserved at `5af91eb` (44 commits ahead of main, pushed to origin). NOT being merged. Useful as research reference for: channel-mapping/surround-downmix logic, C-side `MTAudioProcessingTap` callback patterns, atomics-driven cross-thread state, TSan test patterns, Oracle review history (9 implementation phases, all ≥9/10), Phase 7 quality investigation findings (which informed the pivot).

The task's `state.md` carries a PAUSED-AS-REFERENCE banner pointing here.

### 3. DEFERRED — `timer-scheduled-on-common-extension`

Sub-follow-up of `timer-runloop-mode-audit` (now merged). Extract a `Timer.scheduledOnMainCommon(every:repeats:_:)` helper into `MacAmpApp/Utilities/Timer+CommonMode.swift` and migrate all 7 timer-on-RunLoop callsites in `MacAmpApp/` to use it.

**Predecessor:** `timer-runloop-mode-audit` PR #81 ✅ merged 2026-04-29.
**Task folder:** not yet created (centrally tracked in `tasks/_context/state.md` "Post-S3-1A `timer-runloop-mode-audit` Follow-Ups" section).
**Risk:** `@Sendable` closure migration may surface concurrency-checker edge cases at callsites using `[weak self]` + `MainActor.assumeIsolated` — warrants per-site review.
**When to start:** any time; not blocking any S3 wave.

---

## S3 work map (current state — refresh on each merge)

```
S3-1A mwvi  ✅ MERGED (PR #80, merge commit 7f3d76f, 2026-04-28)
     │
     ├──► S3-1B spt                              ←── PR #82  ✅ MERGED (b60fd57, 2026-04-30)
     │       │
     │       ▼
     │    S3-2 avplayer-native-video-dsp         ←── PR #C   🔧 IMPLEMENTING
     │       │                                                  Step 1+2+3 ✅; Phase 1 ✅;
     │       │                                                  Phase 2 NEXT (8 phases remain)
     │       │
     │       ▼
     │    S3-3 hls                               ←── PR #D
     │       │
     │       ▼
     │    S3-4 ogg                               ←── PR #E
     │           └── runs spike/ogg-build-wiring (0a) + spike/ogg-local-playback (0b) FIRST
     │
     └──► timer-runloop-mode-audit                ←── PR #81  ✅ MERGED (ac09dd4, 2026-04-29)
              │
              ▼
          timer-scheduled-on-common-extension    ←── PR #H   ⏸ DEFERRED
```

**Spike policy (default — do NOT deviate without explicit reason):** each Phase 0 spike runs at its parent task's pickup time on a throwaway branch, findings written to that task's `research.md`, branch deleted. S3-2's spike (`spike/avplayer-inplace-tap-dsp`) ran 2026-05-01 and is **retained locally** until S3-2 close as implementation reference.

**Post-S3:** Structure Sprint (file-move consolidation per `_context/state.md` D-STRUCTURE decision 2026-03-15). Don't start it until S3 closes.

---

## Standard Pickup Process (apply per task)

Every S3 task — main task or spike — follows this sequence:

1. **Read `tasks/_context/state.md`** for cross-task coordination state, file-conflict matrix, and current sprint status.
2. **Read `tasks/_context/principles.md`** — the 7 decomposition principles (Problem-First, Cohesion>LOC, State Ownership, AHA Rule of Three, API Surface, No Pass-Through, ADR + Kill Switch).
3. **Read all 6 canonical files** in the task folder: `research.md`, `plan.md`, `todo.md`, `state.md`, `placeholder.md`, `depreciated.md`.
4. **Re-read every "Files Affected" source at HEAD** to reconcile line-number drift since the plan was written. Verify the plan/todo references still match the code.
5. **Confirm `git status` is clean.** If pending changes exist, commit them as a `chore:` before continuing.
6. **Execute `todo.md` phases in order.** TSan-on builds + tests after each phase (per `feedback_xcodebuildmcp_workflow.md` memory):
   ```bash
   xcodegen generate
   xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'
   xcodebuildmcp macos test  --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'
   ```
   Note: TSan is per-invocation only — no session-default works (see `feedback_tsan_xcodebuildmcp_cli.md`).
7. **Use `ast-grep` (`sg --lang swift -p '<pattern>'`)** before editing setter chains, call graphs, or member-access patterns. `rg` text search alone misses duplicates and dead writes (see `feedback_ast_grep_structural_search.md`).
8. **For diagnostic work on pipelines** (producer → transport → consumer): instrument at least two stages, not just the symptom site (see `feedback_pipeline_end_to_end_diagnosis.md`).
9. **Run Codex Oracle pre-PR code-review gate** (`mcp__codex-cli__codex`, model `gpt-5.3-codex`, `reasoningEffort: xhigh`). Apply ACTIONABLE feedback. Consider NITs case-by-case.
10. **Push + `gh pr create`.** Wait for human review before merging.
11. **Post-merge close-out** (model after the mwvi close-out commit `0358a25`):
    - Update task `state.md` to MERGED with PR link + merge commit.
    - `git mv tasks/<task>/ tasks/done/<task>/` (preserves history).
    - Update `tasks/_context/state.md` (Quick Reference, sprint table, follow-up section if any).
    - Update `tasks/_context/tasks_index.md`.
    - **Update this file** (`tasks/_context/resume-prompt.md`) — bump "Current State" section, advance "Active Work Queue" by removing the merged task and promoting the next task in line, update "First Action".
    - Single `chore: close out <task> (PR #X)` commit.

---

## Persistent Project Memories (auto-loaded by session start hook)

Index lives at `~/.claude/projects/-Users-hank-dev-src-MacAmp/memory/MEMORY.md`. Notable memories that apply directly to S3 work:

- **`feedback_pipeline_end_to_end_diagnosis.md`** — Symptoms manifest at the consumer; root causes often live at the producer. Instrument both ends of any data pipeline before diagnosing.
- **`feedback_ast_grep_structural_search.md`** — Use `sg --lang swift -p` for structural enumeration before edits; `rg` text search misses duplicates / dead writes / pass-through middlemen.
- **`feedback_xcodebuildmcp_workflow.md`** — Always xcodegen + XcodeBuildMCP build AND test (not just `swift build`/`test`) after adding/moving files. TSan must be passed per-invocation.
- **`feedback_sprint_workflow.md`** — Every sprint task gets Oracle review + PR for user review before merge, regardless of size.
- **`feedback_architecture_principles.md`** — The 7 decomposition principles (project-canonical at `tasks/_context/principles.md` and `.ai-shared/principles.md`).
- **`feedback_no_review_trail_in_comments.md`** — Production source comments must describe the invariant, not cite Oracle iters / ADR-IDs / PR numbers.
- **`feedback_oracle_exhaustive_pass.md`** — Run Oracle exhaustively in one pass over full files instead of iter-by-iter rounds.
- **`feedback_comment_verbosity.md`** — Default to zero comments; when needed, one short line max.

---

## Project-Specific Lessons Reference

`BUILDING_RETRO_MACOS_APPS_SKILL.md` is the canonical lessons-learned doc. Most relevant for current work:

- **Part 21 — Video/Milkdrop Window Patterns** (Pattern 3: `Task { @MainActor in }` for Timer/Observer Closures) — relevant whenever modifying timer closures.
- **Part 23 — Lesson: RunLoop Mode Discipline in Feeding Pipelines (April 2026)** — historical context for the merged `timer-runloop-mode-audit` (PR #81) and direct guidance for the deferred follow-up `timer-scheduled-on-common-extension`.

---

## First Action for the Resuming Agent

You are picking up `avplayer-native-video-dsp` mid-implementation. Steps 1+2+3 ✅ + Phase 1 ✅ + Phase 2 ✅ are done. **Phase 3 (`BiquadCascade` + balance + numerical match) is the active work.**

### Pickup checklist

1. **Switch to the work branch:**
   ```bash
   git checkout feat/avplayer-native-video-dsp
   git status   # should be clean; run `git log -1 --oneline` for the actual HEAD
   ```

2. **Read these files in order** (they describe the architecture, the contract, and the work):
   - `tasks/_context/s3-2-pivot.md` — strategic decision log (3 steps + phase ownership)
   - `tasks/avplayer-native-video-dsp/state.md` — current status + dual-architecture topology
   - `tasks/avplayer-native-video-dsp/research.md` — full Step 2 synthesis (Oracle 10/10), Evidence Ledger, Architecture diagram, Reuse policy, Tap Lifecycle Contract, Concurrency Decision Record, Tooling Constraints
   - `tasks/avplayer-native-video-dsp/research-notes/spike-findings.md` — Phase 0 empirical confirmation + 6-item production-translation hazards checklist
   - `tasks/avplayer-native-video-dsp/plan.md` — full 9-phase plan (Oracle 9.8/10), 11+1 ADRs, especially **ADR-3 + ADR-3a** (concurrency contract + `@unchecked Sendable` containment), ADR-4 (atomic-pointer double-buffer), ADR-7 (tap lifecycle), ADR-10 (release-on-fail), ADR-11 (ASBD format guard)
   - `tasks/avplayer-native-video-dsp/todo.md` — Phase 2 work-item checklist (items 2.1 through 2.41, split into sub-phases 2a Marker Protocol → 2b Context → 2c VideoTap → 2d AudioPlayer facade → 2e Contract Test → 2f Verification)
   - `tasks/avplayer-native-video-dsp/research-notes/saved-branch-retrospective.md` — ALLOWLIST/DENYLIST scoping for what to study from the saved engine-routing branch (file:line citations)

3. **Re-read at HEAD** the files Phase 3 will touch (line numbers may have shifted from plan.md authoring):
   - `MacAmpApp/Audio/VideoDSP/VideoTapContext.swift` (NEW from Phase 2 — note ADR-3a Gate 1 header contract block; Phase 3 init/deinit uses real `BiquadCoefficientSet` stride)
   - `MacAmpApp/Audio/VideoDSP/VideoTap.swift` (NEW from Phase 2 — Phase 3 fills `tapProcess` body steps 2-6 per ADR-5)
   - `MacAmpApp/Audio/VideoDSP/BiquadCoefficientSet.swift` (Phase 2 created an empty struct stub; Phase 3 replaces it with the real RBJ-cookbook implementation)
   - `MacAmpApp/Audio/RenderThreadSafe.swift` (NEW from Phase 2 — Phase 3 adds `extension BiquadCascade: RenderThreadSafe`)
   - `MacAmpApp/Audio/EqualizerController.swift` — Phase 3 adds private nested `struct EqualizerState: Sendable, Equatable` (consumed by `BiquadCoefficientSet.compute(for:sampleRate:)`); Phase 5 adds the registry + fanout
   - `MacAmpApp/Audio/AudioPlayer.swift` — note the Phase 2 `startVideoLoad(track:)` orchestration pattern (with generation counter + isStillRelevant short-circuit); Phase 5 wires the registry registration into the `audioMixBuilder` closure inside `startVideoLoad` and into `pauseAndDetachVideoTapIfNeeded`/`invalidateInFlightVideoLoad`

4. **Spike code reference** (kept locally, throwaway branch):
   ```bash
   git show spike/avplayer-inplace-tap-dsp:spikes/avplayer-inplace-tap-dsp/Sources/InPlaceTapSpike/main.swift
   ```
   Phase 2 production tap is the spike's pattern HARDENED per ADR-10 + ADR-11 + ADR-3a. The spike's specific shortcuts (per `spike-findings.md` Production-Translation Hazards section) MUST NOT carry forward.

5. **Saved-branch reference** (paused-as-reference, NOT for cherry-picking):
   ```bash
   git show feat/video-audio-engine-routing:MacAmpApp/Audio/VideoAudioTap.swift
   ```
   Read with the ALLOWLIST/DENYLIST in `research-notes/saved-branch-retrospective.md` open. C-callback shape, `Unmanaged` lifetime, ASBD inspection, surround-channel layout knowledge are reusable as patterns. Ring buffer, AudioConverter, watchdog, HAL listener, fallback flag, `swift-atomics` are explicitly NOT carried forward.

6. **Then execute Phase 3** per `todo.md` items 3.1 – 3.18.

   **Phase 3 GATING prerequisite (must land FIRST):** Address `placeholder.md` P-4 — redesign the coefficient hand-off scheme. ADR-4's original A/B-swap is not race-safe (Oracle finding from Phase 2; main can swap A→B→A while render still holds A's pointer, leaving render reading partially-overwritten A). Choose ONE of:
   - (1) Triple-buffer + atomic in-use counter to mark which slot the render thread is currently reading.
   - (2) RCU-style allocate-fresh-each-install + deferred free of retired buffers (Hazard Pointers, epoch-based reclamation).
   - (3) `Synchronization.Mutex<BiquadCoefficientSet>` with `withLockIfAvailable` on the render thread (skip-update on contention).

   Update plan.md ADR-4 with the chosen scheme + rationale; re-run Oracle review on the redesign BEFORE implementation. Implement the install method on `VideoTapContext` per the new design.

   After P-4 lands, the rest of Phase 3:
   - Replace the empty `BiquadCoefficientSet.swift` stub with the real `struct BiquadCoefficientSet { let bands: (BiquadCoefs ×10) }` + `static func compute(for:sampleRate:)` factory (RBJ-cookbook formulas per ADR-8 — Butterworth/octave-BW per `AudioUnitParameters.h`'s parametric EQ documentation). Closes P-1.
   - Add private nested `struct EqualizerState: Sendable, Equatable` to `EqualizerController.swift`.
   - Create `MacAmpApp/Audio/VideoDSP/BiquadCascade.swift` — direct-form-II biquad with per-channel filter history (`z1`, `z2` per band per channel); `process(buffer:channels:frames:coefficients:)` + `reset()`.
   - Add `extension BiquadCascade: RenderThreadSafe` to `RenderThreadSafe.swift`.
   - Update `VideoTapContext.swift` init/deinit to allocate against the real (non-zero-stride) `BiquadCoefficientSet`.
   - Implement `tapProcess` render-path steps 2-6 per ADR-5: filter reset on `flagsOut.pointee.contains(.startOfStream)` (ADR-9), preamp multiply, `isEqOn` gate, BiquadCascade.process via the chosen P-4 hand-off scheme, balance L/R multiplies.
   - Create `Tests/MacAmpTests/BiquadNumericalMatchTests.swift` with 4 tests: (1) full-EQ-active sweep ≤0.5 dB worst-case vs `AVAudioUnitEQ` over 5 presets × 20 Hz – 20 kHz log sweep (offline render via `AVAudioEngine.manualRenderingMode`); (2) EQ-toggle bypass parity; (3) preamp parity (1 kHz at preamp ∈ {-12,-6,0,+6,+12} dB); (4) balance parity (stereo white noise at balance ∈ {0.0, 0.25, 0.5, 0.75, 1.0}).
   - TSan-on build + test green.
   - Manual smoke: video plays with EQ presets producing audible differences.

7. **Commit at end of Phase 3:**
   ```
   chore(s3-2): Phase 3 — BiquadCascade + balance + numerical match
   ```
   Then mark all Phase 3 todo items `[x]` and update this file's "Current State" + "Active Work Queue" to reflect Phase 3 done / Phase 4 next.

### Critical reminders

- **Engine path must remain byte-for-byte identical.** Phase 1 verified this for the visualizer extraction. Phase 2 introduces a NEW path (video tap) — do not modify the engine path.
- **No `swift-atomics` `ManagedAtomic`.** Use `Synchronization.Atomic<T>` (Swift 6.0 stdlib, macOS 15+) per ADR-3 + saved-branch retrospective modernization gap.
- **No `nonisolated(unsafe)` on Context fields.** ADR-3 settled this — `Atomic<T>` is `Sendable`, the class envelope's `@unchecked Sendable` is sufficient at the FFI boundary.
- **Float not `AtomicRepresentable`.** Use `Atomic<UInt32>` storing `Float.bitPattern` (verified pattern in spike code).
- **One tap per `AVPlayerItem`.** Per ADR-7. `audioMix` set ONCE before `play()`, never mutated during playback.
- **`MTAudioProcessingTapCallbacks.init` parameter:** label is `init:` (no backticks). Compiler warns if escaped (verified in spike).
- **`MTAudioProcessingTapCreate` last parameter:** Swift bridges as `MTAudioProcessingTap?` (NOT `Unmanaged<MTAudioProcessingTap>?`).
- **TSan after every phase boundary.** Per project convention.
- **No `// TODO` in production code.** Anything stubbed goes in `tasks/avplayer-native-video-dsp/placeholder.md`.

### After Phase 3

Phase 4 (visualizer DSP integration on the video tap render path) wires `videoTapVisualizerRender` so spectrum + Butterchurn animate from video audio. Phase 5 wires the EQ + balance state fanout (parallel from `EqualizerController` + `AudioPlayer`). Phase 6 adds deadline-miss telemetry. Phase 7 is the lifecycle test suite + signed-bundle smoke. Phase 8 executes the 15-gate verification matrix. Phase 9 is UI integration polish + mandatory docs (`docs/MACAMP_ARCHITECTURE_GUIDE.md` "Audio Mechanism Concurrency Contract" subsection) + pre-PR Oracle review + `gh pr create`.

### Optional sub-track

`timer-scheduled-on-common-extension` — extract a `Timer.scheduledOnMainCommon` helper, migrate all 7 Pattern-A timer callsites. Predecessor `timer-runloop-mode-audit` (PR #81) is merged ✅; this task does not block any S3 wave. Task folder doesn't exist yet — create it on pickup using the same 6-file canonical layout.
