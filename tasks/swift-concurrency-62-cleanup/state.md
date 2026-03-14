# State: Swift 6.2 Concurrency Cleanup

> **Purpose:** Track current task state, active phase, blockers, and decisions made during implementation.
>
> **Created:** 2026-03-13
> **Branch:** `feature/swift-concurrency-62-cleanup` (PR 1)
> **Cross-task:** Coordinated with `unified-audio-pipeline` (T7). See `_context/state.md`.

---

## Current Status

**Phase:** PR 2 complete (PR #58) — awaiting merge
**Status:** ✅ COMPLETE (pending merge)
**Branch:** `feature/swift-concurrency-62-cleanup-pr2`
**Last Updated:** 2026-03-14
**PR Structure:** Split into PR 1 (pre-pipeline) + PR 2 (post-pipeline)

---

## Cross-Task Execution Order

```text
PR 1 (T8): Phase 0 + Phase 2 + Phase 1 partial → merge to main
    ↓
T7: unified-audio-pipeline (all phases) → merge to main
    ↓
PR 2 (T8): Phase 1d (AudioPlayer) + Phase 4 → merge to main
```

**Why split:** AudioPlayer.swift and StreamPlayer.swift are modified by both tasks.
- AudioPlayer: Pipeline adds ~8 properties → `isolated deinit` must cover final shape
- StreamPlayer: Pipeline completely rewrites → Phase 3 (@preconcurrency) is wasted work

---

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-13 | Split into PR 1 + PR 2 | AudioPlayer/StreamPlayer file conflicts with pipeline task |
| 2026-03-13 | Phase 3 DROPPED | StreamPlayer completely rewritten by pipeline — no AVFoundation, no delegate |
| 2026-03-13 | Phase 1d deferred to PR 2 | AudioPlayer gains streamSourceNode/bridge from pipeline; deinit needs final shape |
| 2026-03-13 | Phase 4 deferred to PR 2 | Can include pipeline's new code if applicable |
| 2026-03-13 | All 4 `@unchecked Sendable` usages legitimate | Lock-based or immutable — no changes |
| 2026-03-13 | Phase 5 DEFERRED | Removes ~30 `@MainActor` but adds ~37-41 `nonisolated`. Questionable ROI. |
| 2026-03-13 | Phase 0 added: SWIFT_VERSION 6.0 → 6.2 | All Swift 6.2 features require 6.2 language mode |
| 2026-03-13 | ZIPFoundation blocker: `@preconcurrency import` | Research confirmed no ZIP library is Swift 6.2 compliant |
| 2026-03-13 | `@concurrent` must be nonisolated static, NOT @MainActor instance methods | Oracle: isolation mismatch |
| 2026-03-13 | WindowCoordinator added as isolated deinit candidate | Oracle: settingsObserver.stop() unreachable from nonisolated deinit |
| 2026-03-13 | Pipeline plan updated with 10 Swift 6.2 findings | Oracle (gpt-5.3-codex, xhigh) validated all changes |

---

## Blockers

| Blocker | Impact | Resolution |
|---------|--------|------------|
| `SWIFT_VERSION` is 6.0 | Blocks Phases 1, 4 | Phase 0 in PR 1 |
| ZIPFoundation globals | Blocks Phase 0 build | RESOLVED: `@preconcurrency import` |
| LockFreeRingBuffer warnings | New warnings under 6.2 | Phase 0d fixes |
| Pipeline not yet merged | Blocks PR 2 (Phase 1d, 4) | Execute pipeline after PR 1 merges |

---

## Phase Progress

| Phase | PR | Description | Status | Depends On |
|-------|----|-------------|--------|------------|
| 0 | PR 1 | SWIFT_VERSION 6.0 → 6.2 | ✅ Merged | — |
| 2 | PR 1 | DispatchQueue → Swift Concurrency | ✅ Merged | Independent |
| 1 partial | PR 1 | `isolated deinit` (VPC, VisPipeline, WinCoord) | ✅ Merged | Phase 0 |
| — | — | **PR 1 MERGED** (PR #56, 2026-03-14) | ✅ | Phases 0, 2, 1 partial |
| — | — | **unified-audio-pipeline executes** | — | PR 1 merged |
| 1d | PR 2 | AudioPlayer `isolated deinit` (final shape) | ✅ Complete | Pipeline merged |
| 4 | PR 2 | `@concurrent` static functions | ✅ Complete | Pipeline merged |
| 3 | — | ~~@preconcurrency audit~~ | DROPPED | StreamPlayer rewritten |
| 5 | — | Default MainActor isolation | DEFERRED | — |

---

## Architecture Notes

1. **VisualizerPipeline.removeTap()** becomes MainActor-isolated after Phase 1b. This is a
   behavioral change — callers must be on MainActor. Currently only called from AudioPlayer
   (already @MainActor) and AudioPlayer.deinit (will be `isolated deinit`). Pipeline task
   doesn't modify VisualizerPipeline, so no conflict.

2. **VideoPlaybackController `isolated deinit`** eliminates the `_playerForCleanup` shadow
   property pattern. Future code should NOT replicate this pattern — use `isolated deinit` instead.

3. **Phase 0 nonisolated-async change** may surface MetadataLoader issues at build time.
   If MetadataLoader's async methods do significant synchronous work before their first
   `await`, that work would now run on MainActor. Monitor for UI stutter during track loading.
