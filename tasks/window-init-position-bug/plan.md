# Plan — window-init-position-bug

1. **Expose window-position logging in all builds**
   - Extend `AppSettings` with a persisted boolean (default `true`) that controls whether verbose window logs are emitted.
   - Remove the `#if DEBUG` guards around `debugLogWindowPositions` and `logDoubleSizeDebug`, and instead early-return if the new flag is `false`. Wire every existing call site to the runtime check so QA can flip the logging via UserDefaults even in Release builds.

2. **Deterministic initial sizing**
   - Update `resizeMainAndEQWindows` to accept an `animated` flag (default `true`). Use non-animated `setFrame` calls for the bootstrap invocation so Main/EQ sizes are correct *before* we compute their starting positions. Keep the animation path for user-triggered toggles.

3. **Persist and restore window geometry**
   - Add a small persistence helper inside `WindowCoordinator` that serializes window frames to `UserDefaults` (one entry per `WindowKind`).
   - Create a delegate (added to the existing `WindowDelegateMultiplexer`) that listens for `windowDidMove`/`windowDidResize` and debounces writes (e.g., 150 ms) so dragging doesn’t spam disk.
   - Maintain a suppression counter so programmatic layout changes (double-size animation, default reset, restore) don’t fight with persistence mid-operation; explicitly persist after those sequences finish.

4. **Restore saved layout or fall back to defaults**
   - During `WindowCoordinator.init`, after windows are created and resized, attempt to apply the persisted origins (and playlist height). For Main/EQ, combine stored origins with the freshly computed sizes so they respect the current double-size state; for Playlist, reuse the full stored frame so user-resized heights come back.
   - If no saved state exists, call the existing `setDefaultPositions()`; ensure this helper runs inside the suppression/adjustment block and writes the initial frames to storage once complete.

5. **Keep docking + persistence in sync**
   - Whenever we perform a coordinated move (`resizeMainAndEQWindows`, `resetToDefaultStack`, playlist docking adjustments), wrap the block with the suppression helper and persist once at the end. This keeps `WindowSnapManager`’s cluster math intact and guarantees the stored layout always matches what the user sees.

6. **Verification hooks**
   - After wiring everything, capture startup logs (now visible even in Release) to confirm we see the expected steps.
   - Manually reason that frames saved via the delegate will be loaded on next launch, keeping playlist docked when double-size toggles.
