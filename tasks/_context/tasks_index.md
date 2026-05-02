# Tasks Index

> **Purpose:** Index of all currently open (non-done) tasks in `tasks/`. Each entry notes the task name, purpose, and current status.
>
> **Updated:** 2026-05-02 (S3-2 pivot Step 2 ✅ + Step 3 ✅; `avplayer-native-video-dsp` implementation Phase 1 NEXT — research Oracle 10/10, plan Oracle 9.8/10 including ADR-3a containment cycle)
> **Excludes:** `tasks/done/`, `tasks/stale/`, `tasks/depreciated/`

---

## Legend

| Status | Meaning |
|--------|---------|
| 📋 PLANNED | Research/planning done, awaiting implementation |
| 🟡 DEFERRED | Postponed to future milestone |
| 📄 REFERENCE | Documentation/analysis artifact, not an implementation task |

---

## Sprint S3: LOW-MEDIUM Priority — Edge Cases + Optimization + Video Routing

> **Status (2026-04-27):** All 5 tasks Oracle-validated through plan + todo phases (≥ 9/10). Implementation-ready. Locked execution order in `_context/state.md`.

| Step | Task | Purpose | Size | Status | Oracle Score |
|------|------|---------|------|--------|:---:|
| S3-1A | `done/mainwindow-visualizer-isolation` | Visualizer freeze fix (run-loop-mode mismatch in producer) | Small | ✅ **MERGED** PR #80 (2026-04-28) | 9.4/10 plan + 9.3/10 pre-PR |
| S3-1B | `done/stream-pause-tail` | Fix 0.7s pause tail (silence gate + producer quiesce) + latent reconnect-during-pause bug | Small-Medium | ✅ **MERGED** PR #82 (2026-04-30, merge `b60fd57`) | 9.1/10 plan; 9/10 final impl |
| ~~S3-2~~ | ~~`video-audio-engine-routing`~~ | ~~Route video audio through AVAudioEngine~~ | — | ⏸ **PAUSED-AS-REFERENCE** 2026-05-01 — see `_context/s3-2-pivot.md`. Branch `feat/video-audio-engine-routing` preserved at `5af91eb`, pushed to origin. | — |
| S3-2 (pivot) | `avplayer-native-video-dsp` | Bring EQ + Balance + Milkdrop to video via AVPlayer-native in-place tap DSP (replaces S3-2 engine-routing approach) | Medium-High | 🔧 **IMPLEMENTING** 2026-05-02 — Steps 1+2+3 ✅; Phase 1 (VisualizerFeed extraction) NEXT. See `_context/s3-2-pivot.md`. | research 10/10, plan **9.8/10** |
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
| `streamdecodepipeline-decomposition` | DecodeContext extraction from StreamDecodePipeline.swift (697 lines) | Medium | 🟡 DEFERRED — One responsibility, architecturally sound. Revisit if file grows or gains new responsibility. |
| `audioplayer-seek-extraction` | Extract seek state machine from AudioPlayer.swift (734 lines) | Medium | 🟡 DEFERRED (Option C) — One responsibility (facade). Revisit as Option B only if AudioPlayer grows past 800 lines or gains new responsibility. |
| `visualizerpipeline-decomposition` | VisualizerPipeline.swift decomposition | Medium | 🟡 NO-GO — Cancelled. Private @unchecked Sendable surface risk. |

---

## Post-S3: Structure Sprint

| Task | Purpose | Size | Status |
|------|---------|------|--------|
| `windowing-structure-consolidation` | Move window infrastructure under `Windowing/` | Medium | 🟡 DEFERRED to post-S3 |
| `milkdrop-feature-consolidation` | Move Milkdrop/Butterchurn under `Features/Milkdrop/` | Medium | 🟡 DEFERRED to post-S3 |
| *(not yet created)* | `Features/` consolidation (Video, EQ, Playlist) | Medium | NOT CREATED |
| *(not yet created)* | `Audio/` consolidation (ownership boundaries) | Medium | NOT CREATED |
| *(not yet created)* | `App/`, `Core/`, `Shared/` consolidation | Medium | NOT CREATED |

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

## Summary Statistics

| Category | Count |
|---------|-------|
| Total active task folders | 13 |
| 📋 PLANNED (ready to implement) | 3 |
| 🟡 DEFERRED / NO-GO | 5 |
| 📄 REFERENCE | 4 |
| Backlog | 1 |
| In `tasks/done/` | ~75 completed tasks |
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
