# Plan: Winamp Titlebar Regression Analysis

1. **Validate Layout Mechanics**
   - Trace how `WinampTitlebarDragHandle` is composed and how `.at()` offsets change once content sits inside a center-aligned `ZStack` with no explicit frame/alignment.
   - Confirm whether the wrapper requires `.frame(width:height:)` and `.alignmentGuide` adjustments or if `.at()` should instead be applied to the wrapper itself.

2. **Confirm Hit Testing Surface**
   - Determine the effective frame of `TitlebarDragCaptureView` and whether it must size itself (e.g., via `frame(width:height:)` or `NSView` constraints) to cover the title bar sprite so drags are intercepted.

3. **Investigate Clustering Behavior**
   - Walk through `WindowSnapManager`'s `connectedCluster` + `SnapUtils` logic to explain why windows never decouple mid-drag.
   - Identify changes needed so dragging one window can peel it out of the cluster (e.g., recompute clusters once spacing exceeds `SNAP_DISTANCE` or only translate the active window until a new snap occurs).

4. **Document Corrected Pattern**
   - Summarize root causes and propose a safe implementation pattern for `WinampTitlebarDragHandle` (alignment, explicit frame, where to apply `.at()`), plus recommendations for cluster detection thresholds/updates.
