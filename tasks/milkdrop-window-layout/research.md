# Research: Milkdrop GEN.png Layout Issues

## Sprite sheet review (`tmp/Winamp/GEN.png`)
- Dimensions verified via `sips`: 194×109 px with top-to-bottom ordering matching Webamp definitions.
- Row 1 (`y=0`): Active title bar slices in order `GEN_TOP_LEFT`, `GEN_TOP_LEFT_END`, `GEN_TOP_CENTER_FILL`, `GEN_TOP_RIGHT_END`, `GEN_TOP_LEFT_RIGHT_FILL`, `GEN_TOP_RIGHT`. Only `GEN_TOP_LEFT_RIGHT_FILL` contains the double gold rails (tileable bar), while `GEN_TOP_CENTER_FILL` is the grey text plateau. `GEN_TOP_RIGHT` already ships with the close "X", so no additional button sprite is required.
- Row 2 (`y=21`): Inactive versions of the same slices (used when window loses focus).
- Row 3 (`y≈42-71`): Side walls (`GEN_MIDDLE_LEFT/RIGHT` plus their bottom trims) and the small square `GEN_CLOSE_SELECTED` (9×9). These vertical slices are not intended for bottom corners.
- Row 4 (`y=42` and `y=57`): Large 125×14 plates `GEN_BOTTOM_LEFT` and `GEN_BOTTOM_RIGHT`, which provide the true bottom corners. The small `GEN_MIDDLE_*_BOTTOM` pieces are only for extending side walls downward, not for the base.

## Current `MilkdropWindowChromeView`
- Titlebar uses hard-coded six sections but only tiles `GEN_TOP_LEFT_RIGHT_FILL` on the **right** (`ForEach(0..<2)`), leaving the left side without matching gold bars. Center grey area (`GEN_TOP_CENTER_FILL`) uses five tiles (125px). Total width still hits 275px, but gold distribution is asymmetric.
- `GEN_CLOSE_SELECTED` sprite is rendered on top of `GEN_TOP_RIGHT`. Because the close "X" already lives inside `GEN_TOP_RIGHT`, this extra sprite shows up as an unwanted bullseye graphic just below the button.
- Bottom assembly draws `GEN_BOTTOM_LEFT`, `GEN_BOTTOM_FILL`, `GEN_BOTTOM_RIGHT`, but then stacks `GEN_MIDDLE_LEFT_BOTTOM`/`GEN_MIDDLE_RIGHT_BOTTOM` at the absolute corners, causing the wrong vertical strip art to appear where the gold bases should meet the side walls.

## Desired fixes (from user request)
1. Mirror the gold bar sections: add left-side `GEN_TOP_LEFT_RIGHT_FILL` tiles so the number of gold segments matches the right side while keeping total width 275px (suggested approach: reduce center grey count and allocate tiles to the left gold block).
2. Remove the unwanted sprite under the close button by eliminating the redundant `GEN_CLOSE_SELECTED` overlay.
3. Use the proper bottom corner sprites (`GEN_BOTTOM_LEFT`/`GEN_BOTTOM_RIGHT`) without overlaying the sidewall trims in that region.
