# Research: Critical Video Window Resize Bugs

## Inputs & Clarifications
- User provided precise bug descriptions for titlebar centering and resize drag jitter, so no additional clarifying questions were required before investigating.

## Code References
1. `MacAmpApp/Views/Windows/VideoWindowChromeView.swift`
   - `buildDynamicTitlebar()` currently appends all stretchy tiles **before** the 100px `WINAMP VIDEO` sprite, so center text is offset whenever the window grows.
   - Titlebar drag handle is wrapped in `WinampTitlebarDragHandle` but layout logic does not split tiles on both sides of the center.
   - `buildResizeHandle()` declares `@State var startSize` inside a `@ViewBuilder`, making it a per-render local property; gesture deltas quantize within `onChanged`, immediately mutating `sizeState.size` so snapping happens mid-drag.

2. `MacAmpApp/Models/VideoWindowSizeState.swift`
   - Provides computed `pixelSize`, `stretchyTitleTileCount` (based on width minus 150px fixed content), `centerTileCount`, and helper `resize` API. Size persistence uses `Size2D` segments.

3. `MacAmpApp/Models/Size2D.swift`
   - Defines quantization logic: each width segment is 25px, height segment 29px. Exposes presets for default/min/2x.

4. `MacAmpApp/Views/WinampVideoWindow.swift`
   - Hosts `VideoWindowChromeView` and stores `@State private var sizeState = VideoWindowSizeState()`. Frame is fixed to `sizeState.pixelSize`, so SwiftUI layout expects deterministic geometry during drags.

## External Behavior Notes
- Expected titlebar: Left cap (25) + N left tiles + centered 100px text + N right tiles + right cap (25). The text must stay at `pixelSize.width / 2`, requiring leftover width to be split evenly before/after text.
- Resize jitter likely due to:
  - Local `@State` being reinitialized on body recalculation, so `startSize` resets during drag.
  - Quantizing during `onChanged` causing window to jump between snapped sizes mid-drag, amplifying jitter when NSWindow size updates feed back into SwiftUI layout.
  - Potential need to call `WindowSnapManager.beginProgrammaticAdjustment()` (pattern seen elsewhere) or similar to avoid interfering snap logic.

## Open Questions
- Confirm if other windows implement smoother resizing (playlist/main) that we can mirror.
- Determine if `VideoWindowSizeState.resize(byWidthSegments:heightSegments:)` should be used instead of manual `Size2D` mutation inside gesture.
- Identify whether `WindowCoordinator` or `WindowSnapManager` utilities exist elsewhere for reference (search next in planning).
