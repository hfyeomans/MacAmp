# State: Intra-File Deduplication & Simplification

> **Description:** First-pass cleanup of duplicated logic and dead code within the 5 decomposition target files, performed BEFORE structural extraction.
> **Purpose:** Reduce cognitive risk during decomposition by consolidating obvious duplicates while they're still visible side-by-side in the same file.

---

## Status

IN PROGRESS. Branch `refactor/intra-file-dedup-simplification` created 2026-03-24.

**Sprint:** Post-S2 / pre-S3
**Created:** 2026-03-24
**Last Updated:** 2026-03-24

## Context

Gemini research + Oracle review (2026-03-24) recommended a hybrid dedup approach:
- **Phase 2a (THIS TASK):** Intra-file dedup — consolidate duplicates within each large file
- **Phase 2b:** Structural extraction — the 5 decomposition tasks
- **Phase 2c:** Cross-file dedup — after extraction, deduplicate between newly created files

The rationale: if you split duplicated code into separate files first, you lose the visual relationship and may never notice the duplication again. Fix it while it's visible.

## Scope

Two files have intra-file duplications worth fixing before extraction:
1. **SkinManager.swift** (783 lines) — 2 dedup targets + 1 dead import
2. **VisualizerPipeline.swift** (699 lines) — 2 dedup targets + 1 dead code block

Three files have only trivially dead code to remove:
3. **StreamDecodePipeline.swift** — 1 dead function
4. **WinampEqualizerWindow.swift** — 1 dead constant
5. **AudioPlayer.swift** — no dedup or dead code (seek extraction is Phase 2b)

## Execution Order

This task runs as **Task 0 of 6** in the post-S2/pre-S3 work. After completion, the 5 decomposition task plans must be refreshed (line numbers and code shape will have changed).

## Key Decision

- All changes are behavior-preserving refactors (extract helper, remove dead code)
- Add characterization tests BEFORE changing SkinManager parsing defaults
- The SkinManager color inconsistency (green vs blue playlist defaults) is investigated and resolved in this task
- Dead code is removed outright (not flagged) per Oracle guidance
- Single branch, single PR for the entire first pass
