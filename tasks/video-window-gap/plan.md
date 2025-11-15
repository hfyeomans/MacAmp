# Plan: Video window left gap, metadata growth, resize jitter

1. **Diagnose left-edge gap**
   - Revisit `VideoWindowChromeView` / `WinampVideoWindow` layout math and verify how `.position` and `.frame(alignment: .topLeading)` interact with the NSWindow’s coordinate space.
   - Inspect `WindowCoordinator.updateVideoWindowSize` to understand whether NSWindow origins are clamped to integers; document how fractional origins could keep the SwiftUI chrome at a +0.5 offset (leading to a visible seam) even when sprite math is correct.
   - Confirm no extra padding enters via `SimpleSpriteImage` (resizable fill) or `NSHostingController`. Summarize hypotheses for what still produces the screenshot gap so QA knows where to probe next.

2. **Define a metadata growth strategy**
   - Use `VideoWindowSizeState.centerWidth` / `centerTileCount` to compute how much extra width the window currently has.
   - Propose a rule that hands some or all of that width to the metadata block before emitting additional center tiles (e.g., grow metadata until `centerWidth` exceeds a threshold, then resume tiling).
   - Call out the concrete code touch points: new derived properties in `VideoWindowSizeState` and updated layout math in `buildDynamicBottomBar` + `buildVideoMetadataText`.

3. **Address resize jitter complaints**
   - Map the drag pipeline (`DragGesture` → `sizeState` → SwiftUI layout → `WindowCoordinator` → `NSWindow`) and explain how it can still oscillate.
   - Recommend mitigations (snap frame origins to integers, add hysteresis to gesture rounding, or debounce NSWindow updates) along with their pros/cons so we can pick an approach without further guesswork.

4. **Document state**
   - Capture findings plus unanswered questions in `state.md` so future implementors know what to test (e.g., instrumenting window origins, verifying metadata width at each preset size, measuring drag tick frequency).
