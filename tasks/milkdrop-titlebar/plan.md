# Plan: Fix Milkdrop Titlebar Gaps

1. **Recalculate tile distribution**
   - Confirm total width (275px) vs. fixed segments (4 × 25px).
   - Deduce center + stretch tiles count (7 tiles total) and choose split (center area 5 tiles = 125px, stretch 2 tiles = 50px) to keep MILKDROP text centered.

2. **Update `MilkdropWindowChromeView` titlebar sections**
   - Change Section 3 `ForEach` to 5 tiles and keep formula `62.5 + i * 25` (start at 50px + half width).
   - Reposition Section 4 center to `187.5` (after 5 center tiles).
   - Shift Section 5 start to `212.5` and keep 2 tiles with formula `212.5 + i * 25` to cover x=200–250.
   - Verify Section 6 remains at `262.5` (covering x=250–275).

3. **State + verification**
   - Document updated width math in `state.md`.
   - Manual verification: ensure coverage spans entire width without overlaps/gaps by re-running calculations (no runtime tests needed).
