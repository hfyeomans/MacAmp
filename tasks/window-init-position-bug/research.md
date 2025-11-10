# Research — window-init-position-bug

## What we inspected
- `MacAmpApp/ViewModels/WindowCoordinator.swift`
- `MacAmpApp/Models/AppSettings.swift`
- `MacAmpApp/Windows/*WindowController.swift`
- `MacAmpApp/Utilities/WindowSnapManager.swift`

## Findings
1. **Window positions are always hard-coded on launch.** `WindowCoordinator.setDefaultPositions()` (lines ~420-455) sets the three NSWindows to `(x: 100, y: 500)` stack regardless of any previous session. There is no lookup against UserDefaults or any persistence helper. None of the window controllers or `WindowSnapManager` persist origins either, so the only values available on cold start are these constants.
2. **Double-size state *is* persisted and applied before positioning.** `AppSettings` loads `isDoubleSizeMode` from UserDefaults during init (lines 49-70). `WindowCoordinator.init` immediately calls `resizeMainAndEQWindows(doubled: settings.isDoubleSizeMode)` (lines 64-88) before positioning, so if the last session ended in double-size mode the new windows are already 550×232 before they ever get placed.
3. **`debugLogWindowPositions` only compiles in DEBUG builds.** Every call site inside `WindowCoordinator.init` is wrapped in `#if DEBUG`. The helper itself is also inside a DEBUG block (~lines 330-360). Any Release build (the one QA is running for Phase 4) will strip these calls entirely, which explains why the expected eight log blocks never appear even though other `print` statements (not wrapped) still show up.
4. **`logDoubleSizeDebug` shares the same DEBUG guard.** When double-size toggles it logs frame sizes. That means QA was previously validating via a debug configuration; their latest release build simply omits *all* debug logging, so no window-position breadcrumbs exist at startup.
5. **No built-in AppKit restoration is happening.** Every window controller uses the custom `BorderlessWindow` with `window.isRestorable = false` (`WinampWindowConfigurator.apply`). We never call `setFrameAutosaveName`, so the system cannot restore frames. User-reported “restoration” is likely just the hard-coded defaults being applied after the persisted double-size resize, which makes them look offset because the playlist height stays at 232 regardless of main/EQ height.

## Conclusions
- Startup logs are missing because we explicitly compile them out in non-DEBUG builds.
- Window positions are not stored anywhere, so they cannot reflect “where the user left them.” The current symptoms (mismatched stack, gap fixed at 116 px even when doubled) match the code path where we position playlist at a fixed offset that assumes main/EQ are still 1× tall.
- To meet the request we need: (a) a persistence layer for window frames so they reopen where the user left them, (b) a way to emit the window-position logs even in release builds (likely behind a new runtime flag), and (c) to ensure the double-size bootstrap uses persisted positions without reintroducing the zero-spacing regression.
