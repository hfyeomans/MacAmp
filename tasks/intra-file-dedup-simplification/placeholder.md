# Placeholder Tracking: Intra-File Dedup & Simplification

> **Description:** Tracks deferred cleanup discovered during the dedup pass that belongs in later phases.
> **Purpose:** Ensure Phase 2c (cross-file dedup after extraction) has a clear checklist.

---

## Deferred to Phase 2c (Cross-File Dedup After Extraction)

| Location | Issue | Why Deferred |
|----------|-------|-------------|
| SkinManager sprite extraction loops (3 locations) | Similar sheet iteration + cropping + autoreleasepool pattern in `parseDefaultSkinFully`, `applySkinPayload`, and `fallbackSpritesFromDefaultSkin` | Too behavior-coupled to fallback/preprocess/cache paths. Oracle recommended deferring to after extraction when the three paths are in separate files and can be analyzed side-by-side with clear ownership. |
| NUMS_EX sprite definitions (SkinManager lines 634-647) | Inline `Sprite` array that belongs with other sprite definitions in `SkinSprites.swift` | Cross-file move, not intra-file dedup. Belongs in Phase 2c or Structure Sprint. |
