# Research: Winamp Titlebar Regression

## Inputs & Questions
- User-reported regressions after swapping `WindowDragGesture()` for `WinampTitlebarDragHandle`.
- Need to explain layout shift, hit testing loss, and clustering behavior.

## Code Observations
1. **WinampTitlebarDragHandle** (`MacAmpApp/Views/Shared/WinampTitlebarDragHandle.swift:5-23`)
   - Wraps content in a `ZStack` with default center alignment and no explicit `frame`.
   - Adds `TitlebarDragCaptureView` (transparent NSView) and overlays provided content with `.allowsHitTesting(false)`.
   - Because the wrapper view has no size/alignment metadata, the container collapses to center-based layout, so relative `.at()` offsets no longer reference the top-left window origin.

2. **TitlebarDragCaptureView** (`MacAmpApp/Views/Shared/TitlebarDragCaptureView.swift:6-73`)
   - `TitlebarDragCaptureNSView` is initialized with `.zero` frame and never resized.
   - SwiftUI wrapper also never applies `.frame(width:height:)`, so the capture layer ends up with zero intrinsic size, meaning touches fall through to the NSWindow rather than the desired 275×14 band.

3. **`.at()` modifier behavior** (`MacAmpApp/Views/Components/SimpleSpriteImage.swift:87-97`)
   - `.at()` is a thin wrapper around `.offset`, so coordinates are always relative to the parent view's alignment origin.
   - When content is moved inside a nested center-aligned `ZStack`, the origin shifts to the center of the 275×14 sprite, making `.at(x:0,y:0)` land halfway down the main window instead of at y=0.

4. **Cluster locking** (`MacAmpApp/Utilities/WindowSnapManager.swift:130-210` + `SnapUtils.swift:26-41`)
   - `beginCustomDrag` captures the entire cluster via `connectedCluster` once, using `boxesAreConnected` with the same 15px `SNAP_DISTANCE` threshold that is used for snapping.
   - `updateCustomDrag` replays the drag delta to **every** box in `clusterIDs` (lines 244-254) so their relative offsets never change while the drag is in progress.
   - Because `boxesAreConnected` only needs edges to be within 15px, and the delta is applied uniformly, there is no way to increase spacing beyond the threshold inside a single drag. That makes clustered windows permanently welded until the drag ends.

## Implications
- Layout regression occurs because the drag handle wrapper introduces a new coordinate origin and collapses hit-testing bounds.
- Titlebar sprite appears displaced or missing since offsets are now relative to the interior `ZStack` (center origin) and the capture view contributes no size/alignment hints.
- Hit testing fails because the NSView capture layer stays at zero size and never intercepts mouse events across the title bar.
- Cluster separation is impossible during a drag because cluster membership is frozen at drag start while `SnapUtils.near` (15px) continues to report "connected", so the algorithm never lets a single window diverge.
