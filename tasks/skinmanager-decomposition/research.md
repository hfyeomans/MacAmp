# Research: SkinManager Decomposition

> **Description:** Responsibility map for decomposing `SkinManager.swift` into smaller, focused files.
> **Updated:** 2026-03-25 (line numbers refreshed post-Phase 2.5 cleanup; Phase 2a COMPLETE)

---

## File Overview

**File:** `MacAmpApp/ViewModels/SkinManager.swift`
**Lines:** 766 (down from 783 — Phase 2a/2.5 removed dead imports, extracted parsing helpers)
**Class:** `SkinManager` (lines 109-766) — `@Observable @MainActor final class`
**Supporting types:** `SkinArchivePayload` (lines 8-12), `SkinArchiveLoader` (lines 14-78), `SkinImportError` (lines 80-101)

## Imports

```swift
Foundation, @preconcurrency ZIPFoundation, AppKit, SwiftUI, UserNotifications, Observation
```

**Phase 2.5:** Dead `Combine` and `CoreGraphics` imports removed.

---

## Section-by-Section Responsibility Map

### Section 1a: SkinArchivePayload (lines 8-12) — 5 lines
- **Responsibility:** DTO for raw ZIP extraction results
- **Key symbols:** `SkinArchivePayload` struct — `sheets: [String: Data]`, `pledit: Data?`, `viscolor: Data?`
- **Internal coupling:** Consumed by SkinArchiveLoader, SkinManager methods
- **External coupling:** None (pure data struct)
- **Extractability:** **Safe**

### Section 1b: SkinArchiveLoader (lines 14-78) — 65 lines
- **Responsibility:** ZIP archive extraction — reads .wsz/.zip skin files
- **Key symbols:** `SkinArchiveLoader` (private enum), `loadAsync(from:expectedSheets:)`, `load(from:expectedSheets:)`, `extract(entry:from:)`, `normalize(_:)`, `sheetBaseName(from:)`
- **Internal coupling:** Produces `SkinArchivePayload`
- **External coupling:** `ZIPFoundation` (Archive, Entry)
- **Extractability:** **Safe** — already fully self-contained

### Section 1c: SkinImportError (lines 80-101) — 22 lines
- **Responsibility:** Error type for skin import validation
- **Key symbols:** `SkinImportError` enum — `unsupportedExtension`, `remoteURL`, `oversizedFile`, `directoryCreationFailed`, `copyFailed`
- **Internal coupling:** Thrown by `validateImportURL`, `ensureDestination`, `importSkin`
- **External coupling:** None
- **Extractability:** **Safe**

### Section 2: State & Initialization (lines 106-145) — 40 lines
- **Responsibility:** Observable state properties, default skin caching
- **Key symbols:** `currentSkin: Skin?`, `isLoading: Bool`, `availableSkins: [SkinMetadata]`, `loadingError: String?`, `defaultSkinPayload`, `defaultSkinSpriteCache`, `defaultSkinExtractedSheets`, `init()`, `loadDefaultSkinIfNeeded()`, `loadGeneration: UUID`
- **Internal coupling:** Referenced by nearly every other section
- **Extractability:** **Risky** — core state, must remain on SkinManager

### Section 3: Default Skin Full Parse (lines 149-185) — 37 lines
- **Responsibility:** Parse default skin payload into complete `Skin` object
- **Key symbols:** `parseDefaultSkinFully(payload:)`
- **Internal coupling:** Reads/writes `defaultSkinSpriteCache`, `defaultSkinExtractedSheets`
- **Extractability:** **Moderate** — side-effects on cache state create coupling
- **Duplication:** Playlist/viscolor parsing logic duplicated in `applySkinPayload` (Section 9)

### Section 4: Skin Discovery (lines 191-241) — 51 lines
- **Responsibility:** Scans bundled + user skins directory to build `availableSkins` list
- **Key symbols:** `scanAvailableSkins()`
- **Internal coupling:** Writes `self.availableSkins`, `self.loadingError`
- **External coupling:** `SkinMetadata.bundledSkins`, `AppSettings.userSkinsDirectory()`, `FileManager`
- **Extractability:** **Safe**

### Section 5: Skin Switching & Initial Load (lines 243-282) — 40 lines
- **Responsibility:** Switching skins by identifier, persisting selection, initial load orchestration
- **Key symbols:** `switchToSkin(identifier:)`, `loadInitialSkin()`
- **Internal coupling:** Calls loadSkin, loadDefaultSkinIfNeeded, scanAvailableSkins, parseDefaultSkinFully
- **Extractability:** **Moderate** — orchestration layer

### Section 6: Skin Import (lines 284-447) — 164 lines
- **Responsibility:** Import external skin files (validate, copy, re-scan, switch) + UI alerts/notifications
- **Key symbols:** `importSkin(from:)`, `validateImportURL(_:)`, `ensureDestination(_:isWithin:)`, `presentReplacementPrompt(for:)`, `presentImportFailureAlert(for:message:)`, `presentAlert(title:message:style:)`, `showNotification(title:message:)`, `showNotificationAlert(title:message:)`
- **Internal coupling:** Calls scanAvailableSkins, switchToSkin
- **External coupling:** FileManager, NSAlert, UNUserNotificationCenter
- **Extractability:** **Safe** — highly self-contained

### Section 7: Background Preprocessing (lines 449-497) — 49 lines
- **Responsibility:** Preprocesses MAIN_WINDOW_BACKGROUND sprite to black out baked-in digit positions
- **Key symbols:** `preprocessMainBackground(_:)`
- **Internal coupling:** Called from `applySkinPayload`
- **External coupling:** NSImage, NSColor
- **Extractability:** **Safe** — pure image transformation

### Section 8: Fallback Sprite Generation (lines 499-575) — 77 lines
- **Responsibility:** Provides fallback sprites from default skin or generates transparent placeholders
- **Key symbols:** `fallbackSpritesFromDefaultSkin(sheet:sprites:)`, `createFallbackSprite(named:)`, `createFallbackSprites(forSheet:sprites:)`
- **Internal coupling:** Reads/writes `defaultSkinPayload`, `defaultSkinSpriteCache`, `defaultSkinExtractedSheets`
- **Extractability:** **Moderate** — `fallbackSpritesFromDefaultSkin` mutates cached state

### Section 9: Core Skin Loading & Application (lines 577-766) — 190 lines
- **Responsibility:** Async skin loading orchestration, sprite extraction, aliasing, parsing, Skin construction
- **Key symbols:** `loadSkin(from:)`, `applySkinPayload(_:sourceURL:)`, `describeLoadError(_:url:)`, shared parsing helpers
- **Internal coupling:** Calls sections 7 and 8; reads/writes loadGeneration, currentSkin, isLoading
- **Extractability:** **Moderate** — `applySkinPayload` has swiftlint suppressions for complexity/length
- **Sub-extractable:** NUMS_EX sprites (lines 615-628), sprite aliasing (lines 695-713), parsing helpers (lines 734-755)

---

## Duplicated Logic — Phase 2a Status

1. ~~**Playlist style parsing**~~ — **RESOLVED in Phase 2a**: shared `parsePlaylistStyle(from:fallback:)` at line 741
2. ~~**Visualizer color parsing**~~ — **RESOLVED in Phase 2a**: shared `parseVisualizerColors(from:fallback:)` at line 750
3. **Sprite extraction loop** (iterating sheets, cropping, autoreleasepool) at lines 154-169 and 664-680 — still duplicated (deferred to Phase 2c)

## Dead Code — Partially Resolved in Phase 2.5

- ~~`Combine` import~~ — **REMOVED**
- ~~`CoreGraphics` import~~ — **REMOVED** (AppKit re-exports)

## Deferred Items (Not Dead Code)

- NUMS_EX sprites hard-coded inline (lines 615-628) — deferred to Phase 2c (move to `SkinSprites.swift`)

---

## Recommended Extraction Units

| # | Target File | Sections | Est. Lines | Risk |
|---|-------------|----------|------------|------|
| 1 | `SkinArchiveLoader.swift` | 1a + 1b | ~70 | Safe |
| 2 | `SkinImportError.swift` | 1c | ~22 | Safe |
| 3 | `SkinImporter.swift` | 6 (import + validation + alerts) | ~164 | Safe |
| 4 | `SkinFallbackResolver.swift` | 8 + related cache state | ~77 | Moderate |
| 5 | `SkinPayloadParser.swift` | Shared playlist/viscolor/sprite extraction helpers | ~50 | Moderate |
| 6 | `MainBackgroundPreprocessor.swift` | 7 | ~49 | Safe |
| 7 | Move NUMS_EX to `SkinSprites.swift` | Part of 9 | ~14 | Safe |

**Post-extraction SkinManager.swift estimate:** ~392 lines (revised — state, orchestration, core loading, applySkinPayload, shared parsing helpers)

## External Consumers

28 files reference SkinManager. All access the public API: `currentSkin`, `isLoading`, `availableSkins`, `loadingError`, `switchToSkin`, `loadInitialSkin`, `scanAvailableSkins`, `importSkin`.
