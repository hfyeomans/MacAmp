# State: SkinManager Decomposition

> **Description:** Tracks readiness and progress for the `SkinManager.swift` decomposition task.
> **Updated:** 2026-03-25 (line numbers refreshed post-Phase 2.5 cleanup; Phase 2a COMPLETE)

---

## Status

READY TO START. Phase 2a dedup complete. Plans refreshed with current line numbers.

## Scheduling

- Phase 2a complete (PR #71 + PR #72): parsing helpers, dead imports, color bug all handled.
- Execution order: **Task 4 of 5** (largest file, some duplication deferred to Phase 2c)

## Current Line Count

766 lines (down from 783 — Phase 2a/2.5 removed dead imports + extracted parsing helpers)

## Key Decision

- Decompose in place within `ViewModels/` — no moves to `Features/Skins/` (post-S3)
- Extract 4 new files: SkinArchiveLoader, SkinImporter (extension), SkinBackgroundPreprocessor, SkinFallbackResolver (extension)
- Residual SkinManager: ~392 lines (revised from ~250 — core loading + orchestration larger than estimated)
- Use extension-file pattern for methods that need `self` (SkinImporter, SkinFallbackResolver)
- New shared parsing helpers section (lines 734-755) moves with residual or into a separate parsing file
