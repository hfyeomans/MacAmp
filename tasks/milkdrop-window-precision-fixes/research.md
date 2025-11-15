# Research: Milkdrop Window Precision Fixes

## Files reviewed
- `MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift`
- `MacAmpApp/Views/Components/SimpleSpriteImage.swift`
- `MacAmpApp/Models/SkinSprites.swift`
- `tmp/Winamp/GEN.png` (sampled with Pillow to inspect sprite boundaries)

## Titlebar layout observations
- Current layout uses `.position` with center-based coordinates (e.g. 12.5, 37.5, …) for every 25 px slice.
- Center-based positioning forces half-point coordinates for odd-width sprites; on non-Retina or when Core Animation snaps to whole pixels this introduces a subtle 1 px seam between Section 3 (gold tiles) and Section 4 (center fill) even though the math sums to 275 px.
- We already have a `.at(x:y:)` helper that offsets sprites from the top-left origin (integer coordinates) which avoids half-point rounding altogether but this titlebar still uses `.position`.
- Active/inactive sprites share the same widths (`GEN_TOP_*` definitions in `SkinSprites` confirm every slice is exactly 25×20). We just need deterministic, integer-aligned origins.

## Bottom bar observations
- `GEN_BOTTOM_LEFT` and `GEN_BOTTOM_RIGHT` are defined as 125×14 each; `GEN_BOTTOM_FILL` is 25×14 (per `SkinSprites`).
- Window height is 232, so the top of the bottom rail should sit at `232 − 14 = 218` (center 225). Using `.position` with half-point center coordinates again introduces fractional placement.
- Sampling `tmp/Winamp/GEN.png` for the `GEN_BOTTOM_FILL` region (x=127, y=72, 25×14) shows no cyan pixels inside the tile, which means the cyan/blue bleed reported by QA is almost certainly from a 1 px gap that reveals the BMP delimiter color around the sprite rather than intrinsic sprite data.
- Consistent integer-aligned placement for the left/right 125 px chunks and the center filler tile (with top-left origin at y=218) will close that seam and hide the cyan delimiter row.

## Supporting helpers
- `SimpleSpriteImage` already exposes `.at(x:y:)` via a `View` extension that offsets sprites relative to the top-left origin (matching Winamp’s coordinate system). Other chrome views (main/playlist) already use `.at` for pixel-perfect placement.
- The Milkdrop chrome view is still on `.position`, so the fix should reuse `.at` for all chrome slices (titlebar + bottom) and ensure the drag handle wrapper is anchored at `(0, 0)` rather than centered with fractional coordinates.
