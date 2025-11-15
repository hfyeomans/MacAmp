# Plan: Milkdrop GEN Layout Fixes

## Goal
Match Winamp's GEN.bmp layout for the Milkdrop window chrome by eliminating the stray sprite, balancing the titlebar gold sections, and using the correct bottom corner plates.

## Steps
1. **Titlebar symmetry**
   - Define constants for tile width (25px) and counts: `leftGoldCount = 2`, `centerFillCount = 3`, `rightGoldCount = 2` to keep total width at 275px.
   - Insert a new `ForEach` for left-side `GEN_TOP_LEFT_RIGHT_FILL` tiles between the left end and the grey center fill, mirroring the right side count.
   - Update the center fill loop to use the reduced tile count and recompute its starting X offset.
   - Recompute X positions for the right end/right gold/right cap based on the new layout so every section abuts the next without gaps.

2. **Remove stray close sprite**
   - Delete the `GEN_CLOSE_SELECTED` sprite overlay since `GEN_TOP_RIGHT` already contains the close button art.

3. **Bottom corner correction**
   - Replace the `GEN_MIDDLE_LEFT_BOTTOM`/`GEN_MIDDLE_RIGHT_BOTTOM` placements with nothing (or, if required, ensure only the 125×14 `GEN_BOTTOM_LEFT/RIGHT` pieces remain at the base). This prevents side-wall strips from being rendered over the corners.

4. **State update & verification**
   - Note the completion in `tasks/milkdrop-window-layout/state.md`.
   - Visually verify by running the Milkdrop window (or rely on sprite math if simulator not run) to ensure counts match 275px.
