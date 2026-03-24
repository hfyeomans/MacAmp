# Tasks Index

> **Purpose:** Index of all currently open (non-done) tasks in `tasks/`. Each entry notes the task name, purpose, and current status.
>
> **Updated:** 2026-03-22
> **Excludes:** `tasks/done/`, `tasks/stale/`, `tasks/depreciated/`
>
> **Housekeeping (2026-03-22):** 69 stale tasks moved to `tasks/stale/` for later review. 1 completed task (`docs-implementation-patterns-update`) moved to `tasks/done/`. 2 duplicates (`oscilloscope-toggle`, `oi-button-bugfix-review`) removed (already in `done/`).

---

## Legend

| Status | Meaning |
|--------|---------|
| 🔄 IN PROGRESS | Active implementation underway |
| 📋 PLANNED | Research/planning done, awaiting implementation |
| 🟡 DEFERRED | Postponed to future milestone |
| 📄 REFERENCE | Documentation/analysis artifact, not an implementation task |

---

## Sprint S2: MEDIUM Priority — Features + Polish

| Task | Purpose | Size | Status |
|------|---------|------|--------|
| `os-workgroup-integration` | Apple Silicon os_workgroup for audio render thread | Small | ✅ COMPLETE — PR #66 merged. Oracle 8.5/10. |
| `stream-track-counter` | Stream elapsed timer + playlist position + auto-play fix + crash guard | Medium | ✅ COMPLETE — PR #68 merged. Oracle 8/10. |
| `playlist-list-operations` | NEW LIST, LOAD LIST, SAVE LIST buttons in playlist window | Medium | ✅ COMPLETE — PR #67 merged. Oracle 9/10. |
| `airplay-integration` | ~~AirPlay routing~~ + Now Playing + remote commands | Medium | ✅ COMPLETE — PR #69 merged. Phase 1 (AirPlay triggers) DEFUNCT. Phase 2 (Now Playing + remote commands) Oracle 9/10. |

---

## Sprint S3: LOW-MEDIUM Priority — Edge Cases + Optimization + Video Routing

| Task | Purpose | Size | Status |
|------|---------|------|--------|
| `mainwindow-visualizer-isolation` | SwiftUI recomposition boundary for visualizer during slider drag | Small | 📋 PLANNED |
| `stream-pause-tail` | Fix ~0.7s audio tail after pausing stream (ring buffer flush) | Small | 📋 PLANNED |
| `video-audio-engine-routing` | Route video audio through AVAudioEngine (MTAudioProcessingTap) | Medium-High | 📋 PLANNED — Deferred from S2. Gemini deep research pending. |
| `hls-streaming-support` | Add HLS protocol to stream decode pipeline | Large | 📋 PLANNED |
| `ogg-vorbis-support` | Add OGG Vorbis codec to stream decode pipeline | Medium | 📋 PLANNED |

---

## Post-S2 / Pre-S3: Architecture Decomposition

| Task | Purpose | Size | Status |
|------|---------|------|--------|
| `skinmanager-decomposition` | Decompose `SkinManager.swift` into smaller pieces | Medium | 📋 PLANNED |
| `visualizerpipeline-decomposition` | Decompose `VisualizerPipeline.swift` | Medium | 📋 PLANNED |
| `streamdecodepipeline-decomposition` | Decompose `StreamDecodePipeline.swift` | Medium | 📋 PLANNED |
| `winamp-equalizer-window-decomposition` | Decompose `WinampEqualizerWindow.swift` | Medium | 📋 PLANNED |
| `audioplayer-seek-extraction` | Extract seek state machine from AudioPlayer.swift (Phase 5) | Medium | 📋 PLANNED |

---

## Post-S3: Structure Sprint

| Task | Purpose | Size | Status |
|------|---------|------|--------|
| `windowing-structure-consolidation` | Move window infrastructure under `Windowing/` | Medium | 🟡 DEFERRED |
| `milkdrop-feature-consolidation` | Move Milkdrop/Butterchurn under `Features/Milkdrop/` | Medium | 🟡 DEFERRED |

---

## Active References + Backlog

| Task | Purpose | Status |
|------|---------|--------|
| `audioplayer-decomposition` | Ph1-4 COMPLETE. Phase 5 (seek) tracked by `audioplayer-seek-extraction`. Historical context for decomposition patterns. | 📄 REFERENCE |
| `lock-free-ring-buffer` | COMPLETE. Deferred: benchmarks, flaky high-throughput test (`withKnownIssue`). | 📄 REFERENCE |
| `swift-project-structure-research` | Approved placement-policy reference for S1-S3. Not an implementation task. | 📄 REFERENCE |
| `branded-dmg-installer` | Professional branded DMG installer with MacAmp logo. Not sprinted. | 📋 PLANNED |

---

## Summary Statistics

| Category | Count |
|---------|-------|
| Total active task folders | 20 |
| 📋 PLANNED (ready to implement) | 16 |
| 🟡 DEFERRED | 2 |
| 📄 REFERENCE | 3 |
| In `tasks/stale/` (for later review) | 69 folders + 8 standalone files |
| In `tasks/done/` | ~55 completed tasks |

---

## Sprint S1 (COMPLETE — 2026-03-22)

All S1 tasks done. See `_context/state.md` for full scorecard.

| Task | Result |
|------|--------|
| `spm-multiple-producers-fix` | Resolved by Wave 3 |
| `audioplayer-decomposition` Ph4 | PR #60 — AudioPlayer 1,143→705 lines |
| `network-auto-reconnect` | PR #61 — Exponential backoff, typed errors |
| `xcode-butterchurn-webcontent-diagnosis` | PR #63 — XcodeGen resource gap |
| Hotfix: VBR duration | PR #62 |
| Test suite hygiene | PR #64 |
| v1.2 Release + docs | PR #65, tag v1.2, DMG uploaded |
