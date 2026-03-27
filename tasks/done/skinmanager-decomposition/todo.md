# Todo: SkinManager Decomposition

> **Description:** Checklist for executing the `SkinManager.swift` decomposition.
> **Updated:** 2026-03-25 (COMPLETE — PR #75 merged)

---

## Phase 2a: Intra-File Dedup — COMPLETE (PR #71 + PR #72)

- [x] Produce a responsibility map for `SkinManager.swift`
- [x] Add characterization tests (fontName=="Arial", count==24)
- [x] Investigate color inconsistency — resolved: `.winampDefault` vs `.pleditParserDefault`
- [x] Extract shared `parsePlaylistStyle(from:fallback:)` helper (line 741)
- [x] Extract shared `parseVisualizerColors(from:fallback:)` helper (line 750)
- [x] Remove dead `import Combine` + `import CoreGraphics`

## Phase 2b: Structural Extraction — COMPLETE (PR #75)

- [x] Extract `SkinArchivePayload` + `SkinArchiveLoader` to `ViewModels/SkinArchiveLoader.swift`
- [x] Extract import methods + SkinImportError + alerts to `ViewModels/SkinManager+Import.swift` (extension)
- [x] ~~Extract `preprocessMainBackground` to `ViewModels/SkinBackgroundPreprocessor.swift`~~ — extracted then DELETED (caused skin artifacts, unnecessary workaround)
- [x] ~~Extract fallback sprite methods to `ViewModels/SkinManager+Fallback.swift`~~ — CANCELLED (Principle 5: private→internal for mutable caches)
- [x] ~~Change cache properties from `private` to `internal`~~ — NOT NEEDED (Step 4 cancelled)
- [x] Run `xcodegen generate`
- [x] XcodeBuildMCP build (Thread Sanitizer enabled)
- [x] XcodeBuildMCP test — 55/55 pass
- [x] Oracle review — 8.5/10
- [x] Manual test: switch skins, verify no artifacts on non-black skins
- [x] Push branch → PR #75 → user review → merged
- [x] Fix Gemini/CodeRabbit comments (validationFailed, int64Value, Phase 2b scope)
- [x] Update state.md and shared _context/ on completion
