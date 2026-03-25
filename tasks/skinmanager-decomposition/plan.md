# Plan: SkinManager Decomposition

> **Description:** Implementation plan for decomposing `SkinManager.swift` (783 lines) into focused files.
> **Updated:** 2026-03-24 (Oracle review v2 — added Phase 2a dedup, fixed visibility design)

---

## Objective

Reduce `SkinManager.swift` from 783 to ~250 lines by first deduplicating intra-file logic, then extracting self-contained types and utilities into neighboring files within `ViewModels/`.

## Phase 2a: Intra-File Dedup BEFORE Extraction

Per Oracle + Gemini hybrid guidance: deduplicate highly localized code while it's still visible side-by-side in the same file. These are easier to consolidate now than after they're scattered across files.

### Dedup 1: Playlist Style Parsing (ALSO investigate possible bug)

`parseDefaultSkinFully` (lines 177-188) and `applySkinPayload` (lines 744-753) both parse `pledit.txt` into `PlaylistStyle` with **different defaults**:
- `parseDefaultSkinFully`: `Color.green` / `Color.white` / `Color.black` / `Color.blue`
- `applySkinPayload`: `.white` / `.white` / `.black` / `Color(red:0, green:0, blue:0.776)`

**Action:** Add characterization test for default skin vs missing-pledit behavior. Then extract shared `parsePlaylistStyle(from:fallbackNormal:fallbackCurrent:fallbackBackground:fallbackHighlight:) -> PlaylistStyle` helper method. Resolve the color inconsistency (decide which defaults are correct).

### Dedup 2: Visualizer Color Parsing

`parseDefaultSkinFully` (lines 190-195) and `applySkinPayload` (lines 755-758) both parse `viscolor.txt` with different fallbacks (24 green colors vs empty array).

**Action:** Extract shared `parseVisualizerColors(from:fallbackColors:) -> [Color]` helper method. Keep fallback differences intentional if they serve different purposes.

### Dedup 3: Remove dead import

Remove `import Combine` (line 2) — zero usage.

## Phase 2b: Structural Extraction

### Step 1: Extract `SkinArchiveLoader.swift` (Safe, ~70 lines)

Move `SkinArchivePayload` struct (lines 10-14) and `SkinArchiveLoader` enum (lines 16-80) together.

- Change access from `private` to `internal`
- Already fully self-contained (caseless enum namespace pattern)

### Step 2: Extract `SkinImporter.swift` as extension file (Safe, ~186 lines)

File: `ViewModels/SkinManager+Import.swift` (extension on SkinManager)

Move ALL import-related code together:
- `SkinImportError` enum
- `importSkin(from:)`, `validateImportURL`, `ensureDestination`
- All alert/notification presentation methods

Extension approach: these methods call `self.scanAvailableSkins()` and `self.switchToSkin()` — they need `self`. Extension files on the same type can access `internal` members.

### Step 3: Extract `SkinBackgroundPreprocessor.swift` (Safe, ~49 lines)

Move `preprocessMainBackground(_:)`. Pure image transformation — free function or static enum method. Zero state dependencies.

### Step 4: Extract `SkinFallbackResolver.swift` as extension file (Moderate, ~77 lines)

File: `ViewModels/SkinManager+Fallback.swift` (extension on SkinManager)

**Oracle finding addressed:** These methods mutate `defaultSkinSpriteCache` and `defaultSkinExtractedSheets` which are `private`. Two options:
- **Option A (preferred):** Use extension-file pattern. Change cache properties from `private` to `internal` since they're `@ObservationIgnored` (not observable state, just internal caches). This is the minimum visibility change.
- **Option B:** Pass caches as `inout` parameters. Rejected — adds API complexity for no safety benefit since these caches are only used within SkinManager methods.

### Step 5: Slim residual SkinManager

SkinManager retains: observable state, `loadDefaultSkinIfNeeded`, `parseDefaultSkinFully` (simplified after dedup), `scanAvailableSkins`, `switchToSkin`, `loadInitialSkin`, `loadSkin`, `applySkinPayload` (simplified after dedup), `describeLoadError`, shared parsing helpers (from dedup). ~250 lines.

## New Files Created

| File | Lines | Source |
|------|-------|--------|
| `ViewModels/SkinArchiveLoader.swift` | ~70 | SkinArchivePayload + SkinArchiveLoader |
| `ViewModels/SkinManager+Import.swift` | ~186 | SkinImportError + import/validation/alert methods |
| `ViewModels/SkinBackgroundPreprocessor.swift` | ~49 | preprocessMainBackground |
| `ViewModels/SkinManager+Fallback.swift` | ~77 | Fallback sprite generation methods |

**Total new files: 4**
**Residual SkinManager.swift: ~250 lines**

## Visibility Changes

| Property | Current | After | Justification |
|----------|---------|-------|---------------|
| `defaultSkinSpriteCache` | `private` (`@ObservationIgnored`) | `internal` | Accessed by SkinManager+Fallback.swift extension |
| `defaultSkinExtractedSheets` | `private` (`@ObservationIgnored`) | `internal` | Accessed by SkinManager+Fallback.swift extension |
| `defaultSkinPayload` | `private` (`@ObservationIgnored`) | `internal` | Accessed by SkinManager+Fallback.swift extension |
| `SkinArchiveLoader` | `private` | `internal` | Own file |
| `SkinArchivePayload` | (none) | stays `internal` | Already `internal` |

These are all `@ObservationIgnored` internal caches, not observable published state. Widening to `internal` does not leak observable state.

## Constraints

- Preserve current skin behavior and fallback semantics
- Do not turn this into a skin-system rewrite
- Decompose in place within `ViewModels/` — no moves to `Features/Skins/` (post-S3)
- Phase 2a dedup: add characterization tests before changing parsing defaults
- Remove trivially dead code during decomposition (Combine import)
- Flag-but-defer: NUMS_EX sprites, sprite extraction loop dedup

## Verification

- Skin discovery lists bundled and imported skins correctly
- Switching skins updates active skin correctly
- Skin import and replacement prompts work
- Default Winamp fallback behavior works when sprites are missing
- NUMS_EX extended font digits render correctly
- Playlist colors correct for default skin AND skins with missing pledit.txt
- `xcodegen generate` + XcodeBuildMCP build + test pass
