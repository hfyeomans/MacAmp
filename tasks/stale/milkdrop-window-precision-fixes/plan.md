# Plan: Milkdrop Window Precision Fixes

## Goal
Eliminate the 1 px seams seen in the Milkdrop window gold titlebar band and bottom rail by anchoring every sprite on integer, top-left Winamp coordinates and ensuring the bottom filler tile shares the same y-origin as its neighbors.

## Steps
1. **Normalize coordinate helpers**
   - Keep the parent titlebar `ZStack` aligned `.topLeading` and use the `.at(x:y:)` helper (top-left offsets) for every sprite rather than `.position`.
   - Remove the 137.5/10 center placement on `WinampTitlebarDragHandle`; anchor it at `.at(x: 0, y: 0)` so the drag region lines up with the sprites.

2. **Rebuild titlebar layout using integer offsets**
   - Compute explicit `CGFloat` offsets for each section based on sprite widths (cap and tiles are all 25 px wide).
   - Place sections sequentially: cap (0), left end (25), two gold tiles (50/75), three center fills (100/125/150), right end (175), two gold tiles (200/225), right cap (250).
   - Keep the existing `suffix` selection logic but ensure all `SimpleSpriteImage` calls use `.at(...)` with top-left coordinates and integer values only.

3. **Realign bottom rail**
   - Derive `bottomY = windowHeight - bottomBarHeight` (218) and reuse this for all bottom sprites.
   - Replace center `.position` call with `.at(x: leftWidth + tileIndex * 25, y: bottomY)` so every chunk lines up with integer positions.
   - Ensure the left/right 125 px chunks also rely on `.at` instead of `.position` to keep their y origin identical to the filler tile.

4. **Run through layout constants/side borders**
   - No sprite changes needed for the vertical borders or content, but confirm they already use integer `.position` (centering is fine there because widths are even). Document any reason conversions were skipped.

5. **Self-review**
   - Re-read the updated SwiftUI view to verify no `.position` remains on titlebar/bottom sprites.
   - Confirm math: sum of segment widths still equals 275, bottom y offset equals 218, and there are no remaining fractional coordinates that could cause seams.
