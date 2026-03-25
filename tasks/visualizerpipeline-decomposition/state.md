# State: VisualizerPipeline Decomposition

> **Description:** Tracks readiness and progress for the `VisualizerPipeline.swift` decomposition task.
> **Updated:** 2026-03-25 (line numbers refreshed post-Phase 2.5 cleanup; Phase 2a COMPLETE)

---

## Status

READY TO START. Phase 2a dedup complete. Plans refreshed with current line numbers.

## Scheduling

- Phase 2a complete (PR #71 + PR #72): resample, copyFloatBuffer, dead guards, onDataUpdate all handled.
- Execution order: **Task 3 of 5** (clean section boundaries, well-understood threading)

## Current Line Count

645 lines (down from 699 — Phase 2a/2.5 removed ~54 lines)

## Key Decision

- Decompose in place within `Audio/` — no moves to `Audio/Visualization/` (post-S3)
- Extract 4 new files: VisualizerTypes, VisualizerScratchBuffers, VisualizerSharedBuffer, VisualizerTapHandler
- Residual pipeline: ~231 lines
- Private types become internal (minimum required visibility)
