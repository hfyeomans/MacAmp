# Plan — Video Window Startup Bug

## Objective
Ensure the VIDEO window never becomes visible before the main trio, and that it only opens when requested after the initial coordinated presentation finishes.

## Proposed Steps

1. **Gate the observer until windows are presented**  
   - Delay `setupVideoWindowObserver()` until after `presentInitialWindows()` runs, or add a guard in `showVideo()` that queues the action until `hasPresentedInitialWindows` is `true`.  
   - Preserve the existing observation loop so toggling the `V` button still works after launch.

2. **Honor initial user preference without forcing visibility**  
   - Replace the eager `if settings.showVideoWindow { showVideo() }` block with logic that stores a pending flag.  
   - When `presentInitialWindows()` fires, read the stored value and call `showVideo()` in the same pass that shows Main/EQ/Playlist if the flag is `true`.

3. **Maintain startup parity with Main/EQ/Playlist**  
   - Keep creating `WinampVideoWindowController` up front for docking/layout math, but keep the window ordered out until either (a) the user toggles VIDEO or (b) the pending flag from step 2 is applied after the main presentation.  
   - Double-check that `focusAllWindows()` no longer iterates the hidden VIDEO window to avoid side effects.

4. **Regression coverage**  
   - Add debug logging (guarded by `windowDebugLoggingEnabled`) to show when VIDEO is queued vs actually ordered front.  
   - Verify that `settings.showVideoWindow = true` during launch results in VIDEO appearing *after* the other windows (or at the same time) with chrome intact, and that the default `false` keeps it hidden.

This sequencing mirrors the pattern the main trio follow—construct windows immediately but defer `orderFront` until the application is ready—removing the blank chrome flash and respecting the expectation that VIDEO never auto-opens before Main/EQ/Playlist.
