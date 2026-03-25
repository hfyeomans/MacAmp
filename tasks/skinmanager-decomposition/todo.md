# Todo: SkinManager Decomposition

> **Description:** Checklist for executing the `SkinManager.swift` decomposition.
> **Updated:** 2026-03-24 (Oracle review v2 — Phase 2a dedup added)

---

## Phase 2a: Intra-File Dedup — COMPLETE (PR #71 + PR #72)

- [x] Produce a responsibility map for `SkinManager.swift`
- [x] Add characterization tests (fontName=="Arial", count==24)
- [x] Investigate color inconsistency — resolved: `.winampDefault` vs `.pleditParserDefault`
- [x] Extract shared `parsePlaylistStyle(from:fallback:)` helper (line 741)
- [x] Extract shared `parseVisualizerColors(from:fallback:)` helper (line 750)
- [x] Remove dead `import Combine` + `import CoreGraphics`

## Phase 2b: Structural Extraction

- [ ] Create branch `refactor/skinmanager-decomposition`
- [ ] Update state.md to IN PROGRESS

- [ ] Change `defaultSkinPayload`, `defaultSkinSpriteCache`, `defaultSkinExtractedSheets` from `private` to `internal`
- [ ] Extract `SkinArchivePayload` + `SkinArchiveLoader` to `ViewModels/SkinArchiveLoader.swift`
- [ ] Extract import methods + SkinImportError + alerts to `ViewModels/SkinManager+Import.swift` (extension)
- [ ] Extract `preprocessMainBackground` to `ViewModels/SkinBackgroundPreprocessor.swift`
- [ ] Extract fallback sprite methods to `ViewModels/SkinManager+Fallback.swift` (extension)
- [ ] Flag NUMS_EX inline sprites for move to SkinSprites.swift in placeholder.md
- [ ] Flag sprite extraction loop dedup for Phase 2c in placeholder.md
- [ ] Run `xcodegen generate`
- [ ] XcodeBuildMCP build (Thread Sanitizer enabled)
- [ ] XcodeBuildMCP test
- [ ] Oracle review on extraction
- [ ] Manual test: switch skins, import skin, verify fallback behavior, check playlist colors
- [ ] Push branch -> create PR for user review
- [ ] Update state.md and shared _context/ on completion
