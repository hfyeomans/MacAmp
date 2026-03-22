# Plan — Window Default Position Regression

Context from research: `setDefaultPositions()` stacks the three windows correctly, but `resizeMainAndEQWindows(doubled:)` runs afterwards and re-anchors the Main/EQ frames so their *top* edges stay fixed. When the current heights are taller than the canonical Winamp sizes (as observed in the debug logs), that resize call raises the origins by ~211 px, knocking the playlist out of alignment. We need to (a) capture definitive evidence about which init stage mutates the frames, and (b) ensure the initializer no longer undoes the default stack.

## Steps
1. **Add DEBUG logging helper**
   - Implement a small `debugLogWindowPositions(step:)` method inside `WindowCoordinator` that prints `frame.origin.y` + heights for each window when compiled with `DEBUG`.
   - Call it immediately after `setDefaultPositions()` and after every subsequent initializer stage identified in the user report (present, window levels, always-on-top observer setup, resize, double-size observer, snap registration, delegate setup). This mirrors the requested instrumentation so we can pinpoint future regressions quickly.

2. **Reorder initialization**
   - Move the initial `resizeMainAndEQWindows(doubled: settings.isDoubleSizeMode)` invocation so it executes *before* `setDefaultPositions()`. That way the windows have their definitive sizes (1x or 2x) before positioning, eliminating the unwanted repositioning later.
   - Keep `setupDoubleSizeObserver()` where it currently lives so runtime toggles still reuse the same resizing path.

3. **Document state**
   - Update `tasks/window-default-position-regression/state.md` after implementation to capture the fix, logging coverage, and any remaining questions.

4. **Verification**
   - Reason through the initializer order to show that after the move there are no frame mutations post `setDefaultPositions()` other than snap callbacks, satisfying the request for corrected ordering and permanent fix.
