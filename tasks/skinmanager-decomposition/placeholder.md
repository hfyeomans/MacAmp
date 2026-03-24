# Placeholder Tracking: SkinManager Decomposition

> **Description:** Tracks deferred cleanup, dead code, and deduplication targets discovered during decomposition.
> **Purpose:** Checklist for the future simplification/dedup pass (Phase 2.5, after file moves).

---

## Dead Code (Removed during decomposition)

| Symbol | File:Line | Issue | Action |
|--------|-----------|-------|--------|
| `import Combine` | SkinManager.swift:2 | Imported but never used anywhere in file | **Remove during decomposition** |

## Deduplication Targets (For future Phase 2.5 simplification pass)

| Location 1 | Location 2 | Pattern | Suggested Fix |
|---|---|---|---|
| `parseDefaultSkinFully` playlist parsing (lines 177-188) | `applySkinPayload` playlist parsing (lines 744-753) | Duplicate playlist style parsing with **different defaults** (green vs blue) — possible bug | Extract shared `parsePlaylistStyle(from:)` helper; investigate color inconsistency |
| `parseDefaultSkinFully` viscolor parsing (lines 190-195) | `applySkinPayload` viscolor parsing (lines 755-758) | Duplicate visualizer color parsing with **different fallbacks** (24 green colors vs empty array) | Extract shared `parseVisualizerColors(from:)` helper |
| `parseDefaultSkinFully` sprite extraction loop (lines 156-171) | `applySkinPayload` sprite extraction loop (lines 654-708) | Similar sheet iteration + cropping + autoreleasepool pattern | Extract shared `extractSpritesFromSheets(_:)` helper |
| NUMS_EX sprite definitions (lines 634-647) | `SkinSprites.swift` sprite definitions | Inline `Sprite` array that belongs with other sprite definitions | Move to `SkinSprites.swift` as a static property |

## Possible Bug (Investigate during dedup pass)

| Location | Issue |
|----------|-------|
| `parseDefaultSkinFully` vs `applySkinPayload` | Playlist style defaults differ: `parseDefaultSkinFully` uses `Color.green`/`Color.white`/`Color.black`/`Color.blue` while `applySkinPayload` uses `.white`/`.white`/`.black`/`Color(red:0, green:0, blue:0.776)`. This may cause different playlist colors when loading the default skin vs a custom skin with missing `pledit.txt`. Needs investigation. |
