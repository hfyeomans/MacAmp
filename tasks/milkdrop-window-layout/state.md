# State: Milkdrop GEN Layout Fixes

## Completed
- Added left-side `GEN_TOP_LEFT_RIGHT_FILL` tiles and reduced `GEN_TOP_CENTER_FILL` to three tiles so gold rails are symmetric (275px total width maintained).
- Removed the redundant `GEN_CLOSE_SELECTED` overlay; the close "X" now relies solely on `GEN_TOP_RIGHT`.
- Dropped the `GEN_MIDDLE_LEFT_BOTTOM`/`GEN_MIDDLE_RIGHT_BOTTOM` sprites so the 125×14 `GEN_BOTTOM_LEFT/RIGHT` plates form the true bottom corners without sidewall strips bleeding into them.

## Next
- Validate window rendering (visual pass when simulator run) to confirm no gaps or overlaps were introduced.
