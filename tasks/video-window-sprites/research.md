# Research: VIDEO.bmp vs PLEDIT.bmp sprite flow

## 1. How Playlist window loads PLEDIT.bmp sprites
- Sprite coordinates live in `MacAmpApp/Models/SkinSprites.swift:234-319`. The `"PLEDIT"` sheet enumerates every playlist sprite (top/bottom tiles, borders, scroll handle, button variants, transport buttons) via `Sprite(name:x:y:width:height)`. These coordinates already exclude cyan delimiter pixels because they were copied from Webamp's canonical table.
- `SkinManager.loadSkin` (`MacAmpApp/ViewModels/SkinManager.swift:480-506`) adds all sheet keys from `SkinSprites.defaultSprites` into `expectedSheets`, so `SkinArchiveLoader` pulls `PLEDIT.bmp` out of the skin archive.
- `applySkinPayload` (`MacAmpApp/ViewModels/SkinManager.swift:520-620`) loops over each `(sheetName, sprites)` pair. For every sprite in `sprites`, it crops the sheet with `sheetImage.cropped(to: sprite.rect)` and writes the resulting `NSImage` into `extractedImages[sprite.name]`. There is no manual math per component—`Sprite.rect` is the single source of truth.
- Because `PLEDIT` lives in `SkinSprites.defaultSprites`, its pieces are cropped in that first pass, right before fallback aliasing and playlist color parsing run. No extra registration step is necessary, and `SimpleSpriteImage` can look up any `PLAYLIST_*` key directly from `currentSkin.images`.

## 2. How Playlist window renders those sprites
- `WinampPlaylistWindow.body` (`MacAmpApp/Views/WinampPlaylistWindow.swift:330-360`) hosts a `GeometryReader` and a `ZStack`. When the window is not shaded it calls `buildCompleteBackground()` first, then overlays `buildContentOverlay()`.
- `buildCompleteBackground()` (`WinampPlaylistWindow.swift:365-407`) recreates the chrome entirely from the `PLEDIT` sprite set:
  - Places the 25px top-left corner, then repeats the `PLAYLIST_TOP_TILE` 10 times to span the center, adds the draggable title bar, and finally the 25px top-right corner—all using `.position(x:y:)` with absolute coordinates.
  - Builds left/right vertical borders by repeating the `*_TILE` sprites down the side, and anchors the 125px/154px bottom corner sprites inside an `HStack` positioned at y=213 (windowHeight-19).
- `buildContentOverlay()` (`WinampPlaylistWindow.swift:410-430`) draws the scrollable playlist content, then overlays controls: `buildBottomControls()`, `buildPlaylistTransportButtons()`, `buildTimeDisplays()`, `buildTitleBarButtons()`, and finally the scroll handle sprite. The layering order is: chrome background (from `PLEDIT`), playlist panel fill, interactive controls, then the draggable buttons.
- Every `SimpleSpriteImage` call takes an explicit width/height that matches the rect dimensions declared in `SkinSprites` (e.g., 25×20, 100×20, etc.), so no scaling artifacts occur.

## 3. How VIDEO.bmp is handled today
- `SkinManager.applySkinPayload()` merely stores the raw VIDEO sheet (`extractedImages["video"] = videoSheet`) without slicing (`SkinManager.swift:572-584`).
- After all standard sheets are processed, `registerVideoSpritesInSkin()` (`SkinManager.swift:632-915`) manually parses VIDEO.bmp by instantiating a throwaway `Skin` so that `loadVideoWindowSprites()` can call `videoBmp.cropped(...)` for each region.
- The `VideoWindowSprites` struct uses a custom coordinate scheme with a top-down→bottom-up flip (`flipY`) and hard-coded widths: 24px left cap, 99px center, 24px "stretchy" tile, 81px right cap, etc. (SkinManager.swift:712-807). These widths do *not* match the 25 / 100 / 125 / 25 pixel layout that `VideoWindowChromeView` expects.
- Those dynamically-cropped images are then registered under `VIDEO_*` keys via `registerVideoSpritesInSkin()`, but many of them are single 24px or 99px samples that later get stretched to fill 25–125px frames.

## 4. How VIDEO.bmp sprites are rendered today
- `VideoWindowChromeView` (`MacAmpApp/Views/Windows/VideoWindowChromeView.swift`) tries to mimic playlist layering but differs in critical ways:
  - The view fabricates the entire title bar with just four sprites (left, center, "stretchy", right), assuming widths of 25/100/125/25 and lining them up with `.position()` similar to playlist.
  - Side borders and bottom bar are single-sprite placements using `.at(...)`, not repeated tiling loops. The bottom center calls `SimpleSpriteImage("VIDEO_BOTTOM_STRETCHY", width: stretchyWidth, ...)`, so whatever 25px slice was registered is stretched across ~25–150px.
  - Because `SimpleSpriteImage` applies `.resizable().aspectRatio(.fill)` to whatever `NSImage` it receives, the mismatched widths (24→25, 99→100, 24→125) force the renderer to scale cyan delimiter columns into the visible area, which is why blue pixels show up along seams even though `.position()` matches playlist.

## 5. Fundamental differences
- **Definition source**: Playlist uses declarative metadata (`SkinSprites`) so the core extraction loop handles cropping consistently. VIDEO sprites bypass that system entirely and re-implement slicing logic later.
- **Coordinate math**: Playlist sprites inherit the exact rects measured from Webamp (bottom-up coordinates already baked in). VIDEO sprites depend on runtime `flipY` conversion and custom widths, increasing the chance of off-by-one or delimiter bleed.
- **Rendering contract**: Playlist code requests sprites whose pixel dimensions match the frames they occupy. VIDEO view requests 25/100/125/25 widths but receives 24/99/24/81 crops, so SwiftUI stretches them, exposing cyan separators and producing misaligned seams.
- **Tiling**: Playlist top/bottom edges tile smaller sprites (top tile repeated 10 times). VIDEO view attempts to emulate a 4-piece layout without tiling, so even perfectly cropped slices would still differ from Winamp's actual tiling strategy.

These differences explain why "all sprites are registering" yet the video chrome draws with cyan bleed and mis-sized segments.
