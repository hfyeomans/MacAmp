# State: Milkdrop Chrome Alignment

- Updated `MilkdropWindowChromeView` to use `.position()` for every 25 px titlebar slice (columns 0–10) and for the 125/25/125 bottom assembly. Each center is `tileWidth * (column + 0.5)` with `tileWidth = 25`, yielding the same math as `VideoWindowChromeView`.
- Bottom bar now derives `bottomCenterY = 225` (because `bottomY = 218` and height is 14), so `GEN_BOTTOM_LEFT/RIGHT` centers sit at `62.5` and `212.5`, while the `GEN_BOTTOM_FILL` center is `137.5`. This removes the cyan delimiter line that appeared when the center tile drifted.
- Manual verification needed in-app: inspect the Milkdrop window’s top-left gold rails (should be seamless) and the bottom tri-part joint (no cyan). Since sprites remain the same and only positioning changed, no asset updates are required.
