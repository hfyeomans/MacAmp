# Research: Milkdrop Chrome Alignment

## Follow-up considerations
- Do we need to standardize on `.position()` like the video window, or is there still value in keeping `.at()` for parity with main/playlist chrome?
- Are the GEN bottom sprites sized/aligned exactly at 125/25 px segments (per `SkinSprites.swift`) or do we need to account for delimiter pixels from `GEN.png`?
- Assumption going forward: only the Milkdrop window needs adjustments; other GEN consumers (e.g., generic utility windows) are unaffected.

## Codebase findings
1. `SimpleSpriteImage.at(x:y:)` (MacAmpApp/Views/Components/SimpleSpriteImage.swift:87) is a thin wrapper over `.offset`. Within `ZStack(alignment: .topLeading)` this yields a top-left origin coordinate system. `.position()` instead places the sprite relative to its center; both can be equivalent if coordinates are derived carefully.
2. `WinampTitlebarDragHandle` (MacAmpApp/Views/Shared/WinampTitlebarDragHandle.swift) clamps its content to a top-leading 275×20 frame, so the titlebar sprites inherit an explicit origin. There is no hidden padding—any gap is due to sprite placement.
3. `SkinSprites.swift` defines the GEN slices explicitly: `GEN_TOP_*` tiles are 25×20 each, `GEN_BOTTOM_LEFT/RIGHT` are 125×14, and `GEN_BOTTOM_FILL` is a 25×14 repeating tile taken from `(x:127, y:72)` which is surrounded by cyan delimiter pixels in the PNG (must not include them in the frame).
4. `MilkdropWindowChromeView` currently offsets the left gold bar tiles to `x=50` and `x=75` using `.at`, while `VideoWindowChromeView` positions equivalent 25px tiles via `.position` at center coordinates (12.5, 37.5, …). Video’s chrome does not exhibit seams, so the reference math there (centers spaced every 25px) is a trustworthy template.
5. Bottom assembly currently anchors `GEN_BOTTOM_LEFT` at `.at(x:0,y:218)`, tiles one `GEN_BOTTOM_FILL` at `.at(x:125,y:218)`, and anchors `GEN_BOTTOM_RIGHT` at `.at(x:150,y:218)`. Because both corner sprites are 125px wide, the center segment should cover only the middle 25px (x:125–150). Any cyan bleed implies the wrong slice or the coordinates include the delimiter row.

## References
- Previous GEN layout analysis lives in `tasks/milkdrop-window-layout/research.md` and `tasks/milkdrop-window-layout/state.md`; they confirm the intended sprites and that cyan is the sheet delimiter.
- Titlebar/bottom precision fixes tracked in `tasks/milkdrop-window-precision-fixes/state.md`, noting that `.at()` was specifically chosen to avoid half-pixel center math.
