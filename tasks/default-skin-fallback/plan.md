# Plan: Default Winamp skin fallback for missing sheets

## Goals
1. Ship an always-available "default skin" extracted from the bundled Winamp archive and keep it resident for fallback sprites.
2. Whenever a sheet is missing from the active skin (`VIDEO.bmp` or any other BMP), pull sprites from the default skin instead of generating transparent placeholders.
3. Preserve existing APIs (`Skin`, `SimpleSpriteImage`) so the rest of the UI automatically benefits.

## Steps
1. **Default skin preparation**
   - Add `DefaultSkinProvider` (or an internal helper on `SkinManager`) that locates `Winamp.wsz`, extracts it to `AppSettings.fallbackSkinsDirectory`, and loads it through the same pipeline as normal skins.
   - Cache the resulting `Skin` instance (`defaultSkin`) in memory; expose `loadedSheets`/`images` for lookups.
   - Run this preparation at app launch (`loadInitialSkin`) before loading the user-selected skin and re-run lazily if caches were cleared.

2. **Shared skin-building helper**
   - Factor the sprite extraction logic inside `applySkinPayload` into `buildSkin(from payload:) -> SkinExtractionResult`, so both the normal load and the default-skin bootstrap can reuse identical processing (aliases, playlist styles, etc.).
   - The helper should accept an optional flag telling it to skip fallback substitution so that we can detect which sheets truly exist inside the default skin.

3. **Fallback sprite resolution**
   - Replace `createFallbackSprites` usage: when a sheet is missing/invalid, try `defaultSkinSprites(for:sheetName)` first. That helper iterates the sheet's sprite list and copies references from `defaultSkin.images`. Only if the default skin lacks those sprites should we synthesize transparent images.
   - Record via logging when default sprites rescue a sheet to aid debugging.

4. **State tracking + recovery**
   - Extend `Skin` or `SkinManager` state with a boolean like `isDefaultFallbackAvailable`. If the default skin fails to load, keep the transparent fallback path but surface a single warning.
   - Optionally expose `defaultSkinLocation` (the extracted directory) for debugging/inspecting the cached files.

5. **Verification**
   - Unit/manual test matrix: user skin without `VIDEO.bmp`, without `PLEDIT.bmp`, and a broken BMP file. Confirm UI pulls from default skin rather than transparent placeholders and logs which sheets fell back.
   - Measure launch timing to ensure default-skin preparation doesn’t regress UI availability (should happen in parallel with initial skin load via detached task).
