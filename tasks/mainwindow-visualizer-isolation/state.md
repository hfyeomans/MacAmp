# State: MainWindow Visualizer Isolation

> **Purpose:** Eliminate spectrum-analyzer freeze during volume / balance slider drag (and click-and-hold without motion).
> **Created:** 2026-03-14
> **Sprint:** S3, Wave S3-1 Worktree A (parallel with `stream-pause-tail` Worktree B)
> **Status:** IMPLEMENTATION COMPLETE — V.1 PASS — pending Oracle code-review gate + PR

---

## Current Status

**Phase:** Implementation complete on `feat/mainwindow-visualizer-isolation`. V.1 Path A retest #3 passed (V1–V4 all show continuous spectrum animation during gesture). Pending pre-PR Oracle gate.
**Last Updated:** 2026-04-28.

### Implementation Summary

The PR is **3 commits** on top of `main`:

| SHA | Subject | Files |
|---|---|---|
| `f806465` | `fix(audio-player): commit volume/balance UserDefaults persistence on drag-end` | AudioPlayer.swift, PlaybackCoordinator.swift, WinampVolumeSlider.swift, MainWindowSlidersLayer.swift, AudioPlayerStateTests.swift |
| `309a02f` | `fix(audio-player): idempotent volume/balance routing, dead-write removal, slider pixel-step coalescing` | AudioPlayer→ unchanged this commit; PlaybackCoordinator.swift, StreamPlayer.swift, WinampVolumeSlider.swift |
| `6a6bbf2` | **`fix(visualizer-pipeline): poll timer in .common run-loop mode`** ← the actual freeze fix | VisualizerPipeline.swift |

The first two commits removed real defects (gesture-rate `UserDefaults` writes, duplicate `videoPlaybackController.volume` route, dead `StreamPlayer.volume`/`.balance` writes) but did not move the freeze meaningfully. The freeze fix turned out to be one upstream change: `VisualizerPipeline.startPollTimer` was using `Timer.scheduledTimer` (which adds the timer to the run loop in `.default` mode and pauses during `.eventTracking` while a gesture is active). Switching to `Timer(...)` + `RunLoop.main.add(timer, forMode: .common)` eliminates the freeze.

Phase 1A extraction was **intentionally skipped** because Phase 0 ruled out Mechanism A. Phase 1C `@State` timer promotion was **not needed** because the consumer-side timer was already on `.common` mode.

### Artifacts

| File | Status |
|------|--------|
| `research.md` | ✅ Complete; appended "Phase 0 — Spike Results" section (commit `5d693c0`) |
| `plan.md` | ✅ Oracle iter 4: 9.4/10 APPROVED (pre-implementation; the actual root cause was off-plan — see Lessons below) |
| `todo.md` | ✅ Phase 0 + Phase 1B (with Phase 1B+ extension) checked off; documentation/PR steps pending |
| `depreciated.md` | Empty |
| `placeholder.md` | Empty |

### Oracle Iterations

| # | Score | Verdict | Phase |
|---|------:|---------|---|
| 1 | 8.4/10 | CONDITIONAL | plan |
| 2 | 9.0/10 | CONDITIONAL | plan |
| 3 | 8.8/10 | CONDITIONAL | plan |
| 4 | **9.4/10** | **APPROVED** | plan |
| 5 | 8.0/10 | OK with stop-criterion | post-Phase-1B V.1 partial-pass diagnosis |

### V.1 Verification Trace (Path A — qualitative)

| Trace | Action | Result |
|---|---|---|
| V1 | Volume slider drag ~10 s | ✅ Spectrum animates throughout |
| V2 | Volume slider click-and-hold without motion ~5 s | ✅ Spectrum animates throughout |
| V3 | Balance slider drag ~10 s | ✅ Spectrum animates throughout |
| V4 | Balance slider click-and-hold without motion ~5 s | ✅ Spectrum animates throughout |

Build clean with TSan ON; all 57 tests pass.

---

## Lessons Learned (the off-plan part)

The Phase 0 instrumentation was incomplete: it measured the **consumer side** (`VisualizerView.body`, `MainWindowFullLayer.body`, `MainWindowSlidersLayer.body`) at high fidelity, but did not measure the **producer side** (`VisualizerPipeline.pollVisualizerData`). The decision rule reached an internally-consistent verdict (Mechanism B) on incomplete data. Two rounds of Mechanism-B fixes (Phase 1B + Phase 1B+) removed real defects but did not address the actual root cause, which was upstream pipeline pause due to a hidden run-loop-mode default. Gemini deep research caught it on second-opinion review.

The lesson — *symptoms manifest at the consumer; root causes often live at the producer* — is captured as a development principle in `~/.claude/projects/-Users-hank-dev-src-MacAmp/memory/feedback_pipeline_end_to_end_diagnosis.md` and is being added to `BUILDING_RETRO_MACOS_APPS_SKILL.md` as a project-specific lesson.

---

## Branch + Wave

- **Branch:** `feat/mainwindow-visualizer-isolation`
- **Commits:** 3 (`f806465`, `309a02f`, `6a6bbf2`) plus the prior `5d693c0` Phase 0 results doc commit and `89a5c8a` chore refresh
- **Wave:** S3-1 Worktree A (parallel start with spt Worktree B; sequential merge: A first)
- **PR target:** PR #A
- **Predecessors:** none
- **Successors:** S3-1B (`stream-pause-tail`) merges after A; subsequent waves S3-2 → S3-4

---

## Next Steps (post-implementation)

1. Documentation sweep: refresh `state.md` (this file ✅), `todo.md`, shared `tasks/_context/state.md`.
2. Update `docs/IMPLEMENTATION_PATTERNS.md` — `Timer.scheduledTimer` example in the VisualizerPipeline pattern needs the `.common`-mode correction.
3. Update `docs/MILKDROP_WINDOW.md` — `audioTimer` example currently shows the buggy pattern.
4. Update `BUILDING_RETRO_MACOS_APPS_SKILL.md` — add lesson on RunLoop mode mismatch in feeding pipelines.
5. Run Codex Oracle code-review gate against the 3-commit diff `main..feat/mainwindow-visualizer-isolation`.
6. Apply ACTIONABLE Oracle feedback (if any).
7. Push branch and open PR #A.
8. Track follow-up: codebase-wide audit of the other 6 `Timer.scheduledTimer` callsites (deferred item in shared `_context/state.md`).
