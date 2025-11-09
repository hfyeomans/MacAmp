# Plan: Restore Slider Input in Borderless Windows

## Goal
Bring back reliable drag/gesture handling for all Winamp controls (volume, balance, seek bar, EQ sliders) now that we host the UI inside custom `NSWindowController`s.

## Approach

1. **Embed SwiftUI via NSHostingController (not bare NSHostingView)**
   - Create a helper (e.g., `WinampHostingFactory.makeController(rootView:)`) that returns an `NSHostingController` configured with the shared environments (skin, audio player, docking, settings, radio, playback coordinator).
   - In each window controller (`WinampMainWindowController`, `WinampEqualizerWindowController`, `WinampPlaylistWindowController`) instantiate that controller, assign it to `window.contentViewController`, and use `controller.view` as the content view so AppKit/SwiftUI lifecycle hooks (viewWillAppear, responder chain, gesture recognizers) mirror the original `WindowGroup` setup.

2. **Ensure windows capture drag events**
   - Extend `WinampWindowConfigurator.apply` (or add a new helper) to set `window.acceptsMouseMovedEvents = true`, `window.ignoresMouseEvents = false`, and `window.isRestorable = false` after the hosting controller has been wired up.
   - Keep borderless visual tweaks (style mask, transparent title bar, etc.) but add a dedicated method to run *after* the SwiftUI view is attached so the hosting view is in place when we call `window.makeFirstResponder`.
   - Optionally, have `BorderlessWindow` override `sendEvent(_:)` to forward `.leftMouseDragged` and `.otherMouseDragged` events immediately when the window is activating, preventing the first drag from being swallowed.

3. **Focus + verification wiring**
   - Update `WindowCoordinator` to keep a reference to each hosting controller (or expose a `focusContentView()` helper) so `focusAllWindows()` can call `window.makeFirstResponder(hostingController.view)` after we swap out the content view implementation.
   - Add QA notes to `tasks/nonfunctional-sliders/state.md` describing the manual verification steps (drag each slider, confirm audio volume/balance changes, confirm EQ sliders move, ensure first click works while app inactive).

## Validation
- Rebuild, launch, and manually drag the position, volume, balance, and EQ sliders; confirm the knob follows the pointer and the bound value updates without needing two clicks.
- Toggle always-on-top (Ctrl+A) to ensure the new focus/hosting logic didn’t reintroduce activation bugs.
