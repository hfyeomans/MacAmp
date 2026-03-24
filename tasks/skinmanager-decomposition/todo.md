# Todo: SkinManager Decomposition

> **Description:** Checklist for executing the `SkinManager.swift` decomposition.
> **Updated:** 2026-03-24 (Oracle review v2 — Phase 2a dedup added)

---

## Phase 2a: Intra-File Dedup (before extraction)

- [x] Produce a responsibility map for `SkinManager.swift`
- [ ] Create branch `refactor/skinmanager-decomposition`
- [ ] Update state.md to IN PROGRESS
- [ ] Add characterization test for playlist style defaults (default skin vs missing pledit.txt)
- [ ] Investigate color inconsistency (green vs blue) — determine correct defaults
- [ ] Extract shared `parsePlaylistStyle(from:...)` helper (consolidate 2 duplicate blocks)
- [ ] Extract shared `parseVisualizerColors(from:...)` helper (consolidate 2 duplicate blocks)
- [ ] Remove dead `import Combine`
- [ ] Build + test after dedup (verify no behavior change)

## Phase 2b: Structural Extraction

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
