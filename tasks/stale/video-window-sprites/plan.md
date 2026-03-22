# Plan: Align VIDEO.bmp pipeline with PLEDIT pattern

## Goals
1. Match Playlist window's sprite extraction flow so VIDEO.bmp slices never include cyan delimiters.
2. Ensure VideoWindowChromeView consumes sprites at their native pixel dimensions (no stretching hacks).

## Steps
1. **Add VIDEO sheet metadata to `SkinSprites.defaultSprites`.**
   - Mirror the PLEDIT structure: define sprites for titlebar pieces (active/inactive), side tiles, bottom corners/tile, scroll/transport buttons if applicable.
   - Use exact widths captured from Winamp's VIDEO.bmp reference so they sum to 275px horizontally and align with playlist-style tiling.

2. **Let `applySkinPayload` crop VIDEO sprites automatically.**
   - Remove the bespoke `VideoWindowSprites` struct, manual `flipY`, and `registerVideoSpritesInSkin()` logic.
   - Keep a simple `if payload.sheets.keys.contains("video")` flag to mark availability (e.g., by storing a boolean or leaving the sheet entry for detection).

3. **Update detection + rendering contract.**
   - Change `Skin.hasVideoSprites` to look for one of the newly registered `VIDEO_*` keys rather than the raw sheet.
   - Rework `VideoWindowChromeView` to reuse the same background-building pattern as `buildCompleteBackground()` in the playlist window (repeat top tiles, tile side borders, etc.), so we rely on the same sprite set semantics.

4. **Verification and docs.**
   - Load bundled Winamp skin, open video window, confirm no cyan bleed and that sprite seams align.
   - Document the VIDEO.bmp sprite contract inside `docs/SPRITE_SYSTEM_COMPLETE.md` or a dedicated note so future contributors know it mirrors PLEDIT.
