# Placeholder Tracking: SkinManager Decomposition

> **Description:** Tracks deferred cleanup, dead code, and deduplication targets discovered during decomposition.
> **Purpose:** Checklist for the future simplification/dedup pass (Phase 2.5, after file moves).

---

## Dead Code (Removed during decomposition)

| Symbol | File:Line | Issue | Status |
|--------|-----------|-------|--------|
| ~~`import Combine`~~ | ~~SkinManager.swift:2~~ | ~~never used~~ | **REMOVED in Phase 2.5** |
| ~~`import CoreGraphics`~~ | ~~SkinManager.swift~~ | ~~re-exported by AppKit~~ | **REMOVED in Phase 2.5** |

## Deduplication Targets (For future Phase 2.5 simplification pass)

| Location 1 | Location 2 | Pattern | Suggested Fix | Status |
|---|---|---|---|---|
| `parseDefaultSkinFully` playlist parsing (lines 177-188) | `applySkinPayload` playlist parsing (lines 744-753) | Duplicate playlist style parsing with **different defaults** (green vs blue) — possible bug | Extract shared `parsePlaylistStyle(from:)` helper; investigate color inconsistency | **RESOLVED in Phase 2a** |
| `parseDefaultSkinFully` viscolor parsing (lines 190-195) | `applySkinPayload` viscolor parsing (lines 755-758) | Duplicate visualizer color parsing with **different fallbacks** (24 green colors vs empty array) | Extract shared `parseVisualizerColors(from:)` helper | **RESOLVED in Phase 2a** |
| `parseDefaultSkinFully` sprite extraction loop | `applySkinPayload` sprite extraction loop | 3 identical autoreleasepool+crop loops | Extract shared `extractSprites(from:sprites:)` helper | **RESOLVED** — PR #76. Helper extracts loops 1+2; loop 3 keeps error handling. |
| NUMS_EX sprite definitions (was inline in SkinManager) | `SkinSprites.swift` sprite definitions | Inline `Sprite` array that belongs with other sprite definitions | Move to `SkinSprites.numsExSprites` static property | **RESOLVED** — PR #76. Moved to SkinSprites.swift. |

## Possible Bug (Investigate during dedup pass)

| Location | Issue | Status |
|----------|-------|--------|
| `parseDefaultSkinFully` vs `applySkinPayload` | Playlist style defaults differ: `parseDefaultSkinFully` uses `Color.green`/`Color.white`/`Color.black`/`Color.blue` while `applySkinPayload` uses `.white`/`.white`/`.black`/`Color(red:0, green:0, blue:0.776)`. This may cause different playlist colors when loading the default skin vs a custom skin with missing `pledit.txt`. Needs investigation. | **RESOLVED in Phase 2a** — color inconsistency investigated and consolidated |
