# Plan: SkinManager Decomposition

> **Description:** Implementation plan for decomposing `SkinManager.swift` (766 lines) into focused files.
> **Updated:** 2026-03-25 (line numbers refreshed post-Phase 2.5 cleanup; Phase 2a items COMPLETE)

---

## Objective

Reduce `SkinManager.swift` from 766 to ~392 lines by extracting self-contained types and utilities into neighboring files within `ViewModels/`.

**Note:** Original estimate of ~250 residual was too optimistic. Core loading section (~190 lines) + state/init/discovery/switching (~200 lines) account for more than anticipated.

## Phase 2a: Intra-File Dedup — COMPLETE (PR #71 + PR #72)

All Phase 2a items completed in prior sprints:
- **parsePlaylistStyle(from:fallback:)** extracted (line 741) — with `.winampDefault` and `.pleditParserDefault` in Skin.swift
- **parseVisualizerColors(from:fallback:)** extracted (line 750) — with intentional fallback differences preserved
- **Dead imports removed**: `import Combine` + `import CoreGraphics` both gone
- **Color inconsistency resolved**: Canonical `PlaylistStyle.winampDefault` (green text) for default skin, `.pleditParserDefault` (white text) for custom skins missing pledit.txt
- **Characterization tests added**: `SkinManagerTests.swift` (fontName=="Arial", count==24)

## Phase 2b: Structural Extraction

### Step 1: Extract `SkinArchiveLoader.swift` (Safe, ~70 lines)

Move `SkinArchivePayload` struct (lines 8-12) and `SkinArchiveLoader` enum (lines 14-78) together.

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
**Residual SkinManager.swift: ~392 lines** (revised — core loading + orchestration larger than originally estimated)

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
- ~~Phase 2a dedup~~ — COMPLETE (parsePlaylistStyle, parseVisualizerColors, dead imports, color bug)
- Flag-but-defer: NUMS_EX sprites, sprite extraction loop dedup

## Verification

- Skin discovery lists bundled and imported skins correctly
- Switching skins updates active skin correctly
- Skin import and replacement prompts work
- Default Winamp fallback behavior works when sprites are missing
- NUMS_EX extended font digits render correctly
- Playlist colors correct for default skin AND skins with missing pledit.txt
- `xcodegen generate` + XcodeBuildMCP build + test pass
