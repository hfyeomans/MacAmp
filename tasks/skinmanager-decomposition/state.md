# State: SkinManager Decomposition

> **Description:** Tracks readiness and progress for the `SkinManager.swift` decomposition task.
> **Updated:** 2026-03-24 (S2 complete, responsibility map done, plan implementation-ready)

---

## Status

READY TO START. Responsibility map and implementation plan complete.

## Scheduling

- No S2 dependencies on this file — unchanged at 783 lines.
- Execution order: **Task 4 of 5** (largest reduction, some duplication to flag)

## Current Line Count

783 lines (unchanged from planning time)

## Key Decision

- Decompose in place within `ViewModels/` — no moves to `Features/Skins/` (post-S3)
- Extract 4 new files: SkinArchiveLoader, SkinImporter, SkinBackgroundPreprocessor, SkinFallbackResolver
- Residual SkinManager: ~250 lines
- Use extension-file pattern for methods that need `self` (SkinImporter, SkinFallbackResolver)
- Consolidate small types into related files (SkinImportError into SkinImporter, SkinArchivePayload into SkinArchiveLoader)
- Flag-but-don't-fix duplication (playlist parsing, viscolor parsing, sprite extraction loops)
- Flag possible color inconsistency bug for investigation in dedup pass
