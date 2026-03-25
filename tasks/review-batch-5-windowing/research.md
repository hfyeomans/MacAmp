# Batch 5 Review Research

- Scope: review Batch 5 windowing changes for correctness and behavior preservation.
- Commit reviewed: `bbc2654` (`refactor: DRY consolidation — alerts, visibility, window config (batch 5)`).
- Compared `bbc2654` against `bbc2654^` for the requested files.

## Findings

1. `WinampAlertHelper.promptText(...)` returns `nil` for any modal response other than `.alertFirstButtonReturn`, including Cancel.
2. `WindowVisibilityController.showEQWindow(makeKey:)` and `showPlaylistWindow(makeKey:)` preserve the two prior behaviors:
   - `makeKey: false` -> `orderFront(nil)` (old `showEQWindow()` / `showPlaylistWindow()` behavior)
   - `makeKey: true` -> `makeKeyAndOrderFront(nil)` (old `showEqualizer()` / `showPlaylist()` behavior)
3. `WindowCoordinator.showEqualizer()/showPlaylist()` forward with `makeKey: true`, so the old menu-command-style key-window behavior is preserved.
4. Removing `window.isOpaque = false` and `window.backgroundColor = .clear` from the five window controllers is behavior-preserving because `WinampWindowConfigurator.installHitSurface(on:)` still sets both before it touches `contentView`.
5. Removing title-bar styling from `WindowSnapManager.register(window:kind:)` is safe in the current call graph because all registered windows are constructed via the Winamp window controllers, which call `WinampWindowConfigurator.apply(to:)` before registration occurs in `WindowDelegateWiring.wire(...)`.
6. `WindowResizeController.topLeftAnchoredFrame(from:newSize:)` is textually equivalent to the three inlined top-left-anchor resize calculations it replaced.

## Non-blocking Notes

- `WinampAlertHelper.promptText(...)` is named like a generic prompt API but hard-codes `"Save"` / `"Cancel"` button titles. That is not a runtime regression today because the helper is currently unused, but the API is narrower than its name suggests.
- No direct unit coverage was found for these specific window helper methods; confidence comes from code equivalence review plus a successful macOS build/test run.
