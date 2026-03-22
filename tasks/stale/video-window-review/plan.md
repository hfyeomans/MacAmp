## Goal
Perform an architecture-focused code review of the `feature/video-milkdrop-windows` branch with emphasis on:

1. AppKit/SwiftUI separation.
2. `@MainActor` coverage for UI types and async callbacks.
3. Memory management / retain-cycle risks.
4. `@Observable` usage consistency in new models.
5. Video playback plumbing (volume sync, seeking, timers, cleanup).
6. Window focus tracking correctness.

## Plan

1. **Scan for AppKit usage inside SwiftUI views**
   - Use `sg`/`rg` to locate `NSWindow`, `NSApp`, `orderFront/orderOut`, etc., in `MacAmpApp/Views`.
   - Identify any SwiftUI surface that manipulates `NSWindow` directly instead of delegating through coordinator/models.

2. **Audit `@MainActor` annotations**
   - Enumerate controllers, delegates, and state models in Windows/AppKit layer to ensure UI-facing classes are annotated.
   - Check async timer/observer closures hop back to main actor.

3. **Inspect memory management edges**
   - Verify delegates stored strongly where necessary (WindowCoordinator) but weak references used for NSWindow delegate callbacks.
   - Review closure captures (Timers in `VideoWindowChromeView`, `AudioPlayer` periodic observers) for potential retain cycles or leaks.

4. **Validate `@Observable` adoption**
   - Confirm new state types (`WindowFocusState`, `VideoWindowSizeState`, etc.) use `@Observable` (not `ObservableObject`) and mark non-reactive members with `@ObservationIgnored`.

5. **Review video playback integration**
   - Read `AudioPlayer` sections covering `volume`, `seekToPercent`, `seek`, `setupVideoTimeObserver`, and cleanup flow to ensure requirements (volume sync, seek guard, observer teardown) are met.

6. **Evaluate window focus tracking + chrome integration**
   - Trace `WindowFocusDelegate` updates into views to ensure no reliance on `NSWindow.isKeyWindow`.
   - Check that sprites swap based on `WindowFocusState` booleans only.

7. **Synthesize findings**
   - Grade architecture (A–F), list critical issues, warnings, recommendations, and map lines/files needing fixes.
