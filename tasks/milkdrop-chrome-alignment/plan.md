# Plan: Milkdrop Chrome Alignment

## Goal
Eliminate the visual seams that QA still sees on the Milkdrop window (titlebar gap + cyan line) by adopting the same coordinate math as the known-good Video window and by double-checking the bottom sprite placement.

## Steps
1. **Coordinate decision:** Standardize Milkdrop’s chrome sprites on `.position()` instead of `.at()`. `.at()` is merely `.offset`, so every sprite still inherits the same alignment guides, which can leave 1 px seams between adjacent tiles. `.position()` gives each sprite its own anchor in the parent coordinate space (same approach as `VideoWindowChromeView`), guaranteeing contiguous coverage when we provide the right centers.
2. **Titlebar centers:** Introduce a helper (e.g., `func columnCenter(_ column: Int) -> CGFloat`) that returns `tileWidth * (column + 0.5)` so we can describe every 25 px slice by column index 0…10. Update each `SimpleSpriteImage` in the titlebar to use `.position(x: columnCenter(column), y: titlebarHeight / 2)`, mirroring the Video window’s math. This removes the 1 px gap between the two left gold tiles because their centers will fall at 62.5 and 87.5 instead of relying on chained `.offset`s.
3. **Bottom plate alignment:** Keep using the 125/25/125 slices but place them with `.position()`:
   - Bottom Y coordinate should be `bottomCenterY = bottomY + bottomBarHeight / 2 = 225`.
   - Left/right 125 px sections centers at `62.5` and `212.5`.
   - Middle 25 px tile center at `137.5`.
   This ensures the filler tile sits flush without revealing the cyan delimiter.
4. **State update + verification:** Document the changes plus assumptions in `state.md`. Since we can’t run UI previews, outline manual verification steps for QA (check top-left gold area + bottom center). Optionally describe how to confirm sprite slices by referencing `tmp/Winamp/GEN.png`.
