# Tasks Index

> **Purpose:** Index of the open tasks in `tasks/` plus the merged rows that gate them. Each entry notes the task name, purpose, and current status. Not exhaustive: 12 one-shot review-scratch folders are listed separately under "Unindexed Review-Scratch Folders".
>
> **Updated:** 2026-09-05 (synced to HEAD `056c69a` — `avplayer-native-video-dsp` Phases 1-7 ✅, Phase 8 automated gates ✅ / manual hardware gates pending user, **Phase 9 NEXT**; branch pushed to origin at `056c69a`, unmerged, PR #C not yet opened; folder + `done/` counts corrected; fired file-growth triggers recorded; 12 unindexed review-scratch folders listed. **Later the same day:** the Post-Structure-Sprint (S4) section was reshaped and both of its task folders were scaffolded — `swift64-macos27-readiness` (S4-1) and `github-issues-triage` (S4-2, renamed from the placeholder `github-issues-sprint`) — active folder count 26 → 28.)
> **Excludes:** `tasks/stale/`, `tasks/depreciated/`. Merged `done/` rows are retained where they gate an open task (S3-1A, S3-1B, `timer-runloop-mode-audit`).

---

## Legend

| Status | Meaning |
|--------|---------|
| 🟡 DEFERRED | Postponed to future milestone |
| 📋 QUEUED | Roadmap task with a scaffolded folder; gated on a predecessor, research not started |
| 📄 REFERENCE | Documentation/analysis artifact, not an implementation task |
| ✅ MERGED | Shipped to `main` via a PR; folder lives in `tasks/done/` |
| ✅ READY | Plan + todo Oracle-gated; implementation not started (may be gated on a predecessor) |
| 🔧 IMPLEMENTING | Implementation in progress on a branch |
| ⏸ PAUSED-AS-REFERENCE | Superseded approach; branch preserved for reference, not resumed |

---

## Sprint S3: LOW-MEDIUM Priority — Edge Cases + Optimization + Video Routing

> **Status (2026-04-27):** All 5 tasks Oracle-validated through plan + todo phases (≥ 9/10). Implementation-ready. Locked execution order in `_context/state.md`.
>
> **Status (2026-09-05):** S3-1A ✅ + S3-1B ✅ merged. S3-2 (pivot) is at Phase 8 — automated gates ✅, manual/hardware gates pending user, Phase 9 next — on branch `feat/avplayer-native-video-dsp`, 73 commits ahead of `main`, **pushed to origin at `056c69a`; unmerged; PR #C not yet opened**. S3-3 is blocked behind it; S3-4 is blocked behind S3-3. Branch idle since 2026-06-27.

| Step | Task | Purpose | Size | Status | Oracle Score |
|------|------|---------|------|--------|:---:|
| S3-1A | `done/mainwindow-visualizer-isolation` | Visualizer freeze fix (run-loop-mode mismatch in producer) | Small | ✅ **MERGED** PR #80 (2026-04-28) | 9.4/10 plan + 9.3/10 pre-PR |
| S3-1B | `done/stream-pause-tail` | Fix 0.7s pause tail (silence gate + producer quiesce) + latent reconnect-during-pause bug | Small-Medium | ✅ **MERGED** PR #82 (2026-04-30, merge `b60fd57`) | 9.1/10 plan; 9/10 final impl |
| ~~S3-2~~ | ~~`video-audio-engine-routing`~~ | ~~Route video audio through AVAudioEngine~~ | — | ⏸ **PAUSED-AS-REFERENCE** 2026-05-01 — see `_context/s3-2-pivot.md`. Branch `feat/video-audio-engine-routing` preserved at `5af91eb`, pushed to origin. | — |
| S3-2 (pivot) | `avplayer-native-video-dsp` | Bring EQ + Balance + Milkdrop to video via AVPlayer-native in-place tap DSP (replaces S3-2 engine-routing approach) | Medium-High | 🔧 **IMPLEMENTING** 2026-06-27 (HEAD `056c69a`, 73 commits ahead of `main`; **pushed to origin at `056c69a`; unmerged; PR #C not yet opened**) — Steps 1+2+3 ✅; **Phases 1-7 ✅** (Ph2-7 Oracle-approved; Ph1 had no Oracle round); **Phase 8 automated gates ✅** (8.3 EQ ≤ 0.5 dB, 8.4 TSan 116/116, 8.15 lifecycle, 8.1 CPU) with manual/hardware gates **pending user** per task `verification.md`. CPU position, uncompressed: **8.1 PASSED as a Debug `-Onone` DSP-core regression guard** (p99 ≈ 11% / max ≈ 13% of the 21,333 µs deadline); **8.1b (tapProcess 99p ≤ 10% on Release under Instruments) is UNVERIFIED** — and cannot literally yield a 99p (Time Profiler reports an aggregate share; `VideoTap.swift:112` samples 1-in-64 with only two bucket counters), so expect a PARTIAL result. **Phase 9 NEXT** (UI audit + docs + pre-PR Oracle + PR #C); PR #C must follow the user's manual verification. See `_context/s3-2-pivot.md`. | research 10/10, plan **9.8/10**; impl Ph2 9.0 / Ph3 9.6 / Ph4 9.6 / Ph5 10 / Ph6 9 / Ph7 9; Ph8 round 1 7/10 → fixes in `944795a`, no re-score recorded |
| S3-3  | `hls-streaming-support` | Audio-only HLS (M3U8 + AAC ADTS, live + VOD) | Large | ✅ READY (gated on S3-2 pivot merge) | 9.0/10 |
| S3-4  | `ogg-vorbis-support` | OGG Vorbis (libvorbis), local + Icecast streams; chained-format gap fix | Medium-Large | ✅ READY (Phase 0a/0b spikes first) | 9.3/10 |

---

## Post-S3-1A Follow-Ups

| Task | Purpose | Size | Status |
|------|---------|------|--------|
| `done/timer-runloop-mode-audit` | Normalized all 6 non-Pattern-A timer-on-RunLoop callsites onto Pattern A; 2 Butterchurn bugs fixed as side-effect; codebase now uniform on `Timer(...)` + `RunLoop.main.add(.common)` | Small | ✅ **MERGED** PR #81 (2026-04-29, merge `ac09dd4`) |
| `timer-scheduled-on-common-extension` | Extract `Timer.scheduledOnMainCommon` helper, migrate all 7 timer-on-RunLoop callsites to use it; `@Sendable` closure migration warrants per-site review | Small-Medium | 🟡 **DEFERRED** — discovered during `timer-runloop-mode-audit`; predecessor merged ✅; task folder not yet created |

---

## Deferred Decomposition (Re-evaluate during/after S3)

| Task | Purpose | Size | Status |
|------|---------|------|--------|
| `streamdecodepipeline-decomposition` | DecodeContext extraction from `Audio/Streaming/StreamDecodePipeline.swift` (**825 lines** at HEAD *and* on `main`; row previously said 697) | Medium | 🟡 DEFERRED — One responsibility, architecturally sound. **Growth trigger has FIRED (697 → 825)**, independently of the S3-2 branch; re-evaluate during Structure Sprint mapping. |
| `audioplayer-seek-extraction` | Extract seek state machine from `AudioPlayer.swift` (**1,079 lines** at HEAD; 763 on `main`; row previously said 734) | Medium | 🟡 DEFERRED (Option C) — **The 800-line Option B trigger has FIRED at HEAD** (S3-2 video-path growth); re-evaluate during Structure Sprint mapping. |
| `visualizerpipeline-decomposition` | VisualizerPipeline.swift decomposition | Medium | 🟡 NO-GO — Cancelled. Private @unchecked Sendable surface risk. **Superseded in practice, not merely cancelled:** S3-2 Phase 1 already performed the extraction (`VisualizerFeed` + `VisualizerScratchBuffers`), taking `VisualizerPipeline.swift` 699 → **416 lines** at HEAD. |

---

## Post-S3: Structure Sprint

| Task | Purpose | Size | Status |
|------|---------|------|--------|
| `windowing-structure-consolidation` | Move window infrastructure under `Windowing/` | Medium | 🟡 DEFERRED to post-S3 |
| `milkdrop-feature-consolidation` | Move Milkdrop/Butterchurn under `Features/Milkdrop/` | Medium | 🟡 DEFERRED to post-S3 |
| *(not yet created)* | `Features/` consolidation (Video, EQ, Playlist) | Medium | NOT CREATED |
| *(not yet created)* | `Audio/` consolidation (ownership boundaries) | Medium | NOT CREATED |
| *(not yet created)* | `App/`, `Core/`, `Shared/` consolidation | Medium | NOT CREATED |

> Followed by Post-Structure-Sprint (S4) — see section below (added 2026-09-05).

---

## Post-Structure-Sprint (S4)

> Added 2026-09-05 (user request). Sequenced **after** the Post-S3 Structure Sprint above, which itself starts only after S3-4 `ogg-vorbis-support` merges. Both folders were scaffolded 2026-09-05 with the 5-file canonical layout (`state.md`, `research.md`, `todo.md`, `placeholder.md`, `depreciated.md`); no research has started in either. S4-2 was previously listed here as the placeholder name `github-issues-sprint`.

| Step | Task | Purpose | Size | Status | Predecessors |
|------|------|---------|------|--------|--------------|
| S4-1 | `swift64-macos27-readiness` | Research-first readiness pass for **Swift 6.4 language mode + macOS 27**: reconcile the installed toolchain (Xcode 27.0 `27A5194q`, Swift 6.4, host macOS 27.0 `26A5425a`) against the project's pins (`SWIFT_VERSION` 6.2, swift-tools-version 6.2, macOS 15.0 deployment target, cosmetic `project.yml` `xcodeVersion: 26.0`). Four research questions: (a) what flips at `SWIFT_VERSION` 6.4 and what it means for the ADR-3a `@unchecked Sendable` containment + `Synchronization.Atomic`/`Mutex` use in VideoDSP; (b) new SwiftUI on macOS 26/27; (c) macOS 27 AppKit (Liquid Glass) / toolbars / WebKit-in-SwiftUI (Butterchurn) / AVFoundation + `MTAudioProcessingTap` / AVAudioEngine deltas; (d) whether to raise the deployment target (15 → 26 or 27). Key deliverable is a deployment-target ADR. | Medium | 📋 **QUEUED** — folder scaffolded 2026-09-05; research not started | Post-S3 Structure Sprint (implementation half only — the research half is ungated, see the allowance below) |
| S4-2 | `github-issues-triage` | Triage + fix the issues other users filed on `hfyeomans/MacAmp`, landing the fixes in the post-Structure-Sprint layout: **#84** Nucleo NLog v2G rendering defects, **#79** can't drag files / open by double-click, **#78** windows can't be permanently joined + no minimization + no state persistence, **#47** Cmd+Shift+1-3 shortcut conflict — plus internal **P-6** (video→audio transition does not auto-play) folded in from `avplayer-native-video-dsp/placeholder.md`. One branch/PR per issue, each Oracle-gated. | Medium-Large | 📋 **QUEUED** — folder scaffolded 2026-09-05; research not started | Post-S3 Structure Sprint (user mandate) + S4-1 (**assumption**, see note) |

> **Ordering assumption — pending user confirmation.** The user mandated only that the GitHub-issue fixes come *after* the `.swift` rearrangement. Putting **S4-1 before S4-2** is our inference: S4-1's deprecation findings may change how the S4-2 issues are fixed, so doing it second would risk reworking fresh fixes.
> **Allowance:** S4-1's **research half touches no code**, so it may run opportunistically earlier (even during S3 or the Structure Sprint); only its implementation half is gated on the Structure Sprint landing. S4-2 stays hard-gated behind the Structure Sprint — #78 in particular touches windowing and benefits most from the moves having landed.

---

## Backlog / Research

| Task | Purpose | Status |
|------|---------|--------|
| `ios-port-feasibility-research` | Research feasibility of iOS/iPadOS port | 📄 REFERENCE |

---

## Active References

| Task | Purpose | Status |
|------|---------|--------|
| `audioplayer-decomposition` | Ph1-4 COMPLETE (PR #52 + #60). Phase 5 (seek) tracked by `audioplayer-seek-extraction`. | 📄 REFERENCE |
| `lock-free-ring-buffer` | COMPLETE. Deferred: benchmarks, flaky high-throughput test (`withKnownIssue`). | 📄 REFERENCE |
| `swift-project-structure-research` | Approved placement-policy reference for S1-S3 and Structure Sprint. | 📄 REFERENCE |
| `agent-docs-history-search` | One-shot research: located prior agent-doc / `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` work across `done/` and `stale/`. | 📄 REFERENCE |

---

## Unindexed Review-Scratch Folders (12)

> Never indexed. Eleven were committed to this branch on 2026-05-26 (`95ebc06`, parallel-agent review scratch), after this index last changed on 2026-05-02 (`1f7a0a0`); `pr81-gemini-timer-feedback` predates it (added 2026-04-30) and was simply skipped. All are one-shot Oracle-review / verification scratch folders, **not open work** — each holds only `plan.md` / `research.md` / `state.md`. Eleven belong to the paused `feat/video-audio-engine-routing` (vaer) branch and exist **only on `feat/avplayer-native-video-dsp`, not on `main`**; one belongs to merged PR #81. **Recommendations only — nothing has been moved.**

| Folder | Subject | Recommendation |
|--------|---------|----------------|
| `airpods-route-gate-validation` | vaer Phase 7 — proved `AVAudioEngineConfigurationChange` is not a general macOS route-change signal; the evidentiary root of the S3-2 pivot | → `stale/` (Phase 7 arc) — **highest-value survivor**; it holds the Apple SDK header citations (`AVAudioEngine.h`, `AudioHardware.h`) that justify pivot reason #1, and `_context/s3-2-pivot.md` should point at it before any archiving |
| `a-b-implementation-review` | vaer Phase 7 — review of `617622b` (HAL default-output listener + 3 s stall threshold) | → `stale/` (Phase 7 arc) |
| `phase-7-watchdog-gate-v2-rereview` | vaer Phase 7 — gate v2 review chain, link 1 of 3 | → `stale/` (Phase 7 arc; archive the 3-folder chain together) |
| `phase-7-watchdog-gate-v2-final-pass` | vaer Phase 7 — gate v2 chain, link 2 of 3 (drove `9825b4f`) | → `stale/` (Phase 7 arc) |
| `phase-7-watchdog-gate-v2-score-confirm` | vaer Phase 7 — gate v2 chain, link 3 of 3 | → `stale/` (Phase 7 arc) — log its **unowned order-sensitive TSan flake in `VideoTapFallbackTests`** as a deferred item in `_context/` first |
| `video-gate-bf13572-re-review` | vaer Phase 7 — final review on the branch (`bf13572`) | → `stale/` (Phase 7 arc) |
| `video-audio-tap-phase2-rereview` | vaer Phase 2 — `VideoAudioTap` surround downmix + AAC layouts | → `stale/` — richest technical artifact; keep intact |
| `video-audio-engine-routing-pass2-review` | vaer Phase 3 — race/cancellation pass-2 review | → `stale/` (Phase 3 arc) — settled, not an open thread |
| `review-f41418a-video-regressions` | vaer Phase 3 regression arc, pass 1 | → `stale/` (Phase 3 arc; archive the 3-folder arc together) |
| `video-regression-f18c518-pass2-verification` | vaer Phase 3 regression arc, pass 2 | → `stale/` (Phase 3 arc) |
| `video-load-task-pass3-verification` | vaer Phase 3 regression arc, pass 3 (clean close) | → `stale/` (Phase 3 arc) |
| `pr81-gemini-timer-feedback` | PR #81 `fix/timer-runloop-mode-audit` — the only one whose code shipped; the fix reached `main` via the PR #83 merge (`1d24258`) | → `done/`, beside `done/timer-runloop-mode-audit`. Only outstanding item is the GitHub reply/resolve of PR #81 threads #2 and #3 (`./scripts/resolve-pr-comments.sh 81 list`) |

---

## Summary Statistics

| Category | Count |
|---------|-------|
| Total active task folders in `tasks/` (excl. `_context/`, `done/`, `stale/`, `depreciated/`) | **28** — 16 indexed in the tables above (14 + the 2 S4 folders scaffolded 2026-09-05) + 12 unindexed review-scratch (closed; see "Unindexed Review-Scratch Folders") |
| ✅ READY to implement (S3-3 blocked on S3-2 merge; S3-4 blocked behind S3-3) | 2 rows |
| 🔧 IMPLEMENTING (S3-2 pivot `avplayer-native-video-dsp`) | 1 row |
| ⏸ PAUSED-AS-REFERENCE (`video-audio-engine-routing`) | 1 row |
| 📋 QUEUED (S4-1 `swift64-macos27-readiness`, S4-2 `github-issues-triage`) | 2 rows — both folders scaffolded 2026-09-05, research not started |
| 🟡 DEFERRED / NO-GO | 6 rows (5 have task folders; `timer-scheduled-on-common-extension` has none) |
| 📄 REFERENCE | 5 rows (4 under Active References + `ios-port-feasibility-research`) |
| Backlog | 1 |
| In `tasks/done/` | 79 entries (77 folders + 2 files) |
| In `tasks/stale/` | 69 folders + 8 standalone files |

---

## Completed Sprints

### Sprint S2 (COMPLETE — 2026-03-24)

| Task | Result |
|------|--------|
| `os-workgroup-integration` | PR #66 — Oracle 8.5/10 |
| `stream-track-counter` | PR #68 — Oracle 8/10 |
| `playlist-list-operations` | PR #67 — Oracle 9/10 |
| `airplay-integration` | PR #69 — Now Playing + remote commands. AirPlay triggers DEFUNCT. |

### Post-S2 Decomposition (COMPLETE — 2026-03-26)

| Task | Result |
|------|--------|
| `intra-file-dedup-simplification` | PR #71 — First-pass dedup across 4 files |
| `codebase-wide-simplification` | PR #72 — -732 lines, 6 files deleted, 4 utilities created |
| `responsibility-sweep` | PR #74 — 109 files audited: 76 Clean, 26 Justified, 7 Actionable |
| `skinmanager-decomposition` | PR #75 — 766→454 lines. ArchiveLoader, Import extracted. Preprocessor removed. |
| `winamp-equalizer-window-decomposition` | PR #76 — 616→354 lines. WinampVerticalSlider + EQPresetPickerView extracted. |

### Sprint S1 (COMPLETE — 2026-03-22)

See `_context/state.md` for full scorecard. 4 tasks + 1 hotfix, 4 PRs merged (#60-#64).

### Sprint S0 (COMPLETE — 2026-03-14)

`docs-implementation-patterns-update` — PR #59.
