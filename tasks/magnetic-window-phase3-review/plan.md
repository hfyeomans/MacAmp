# Magnetic Window Phase 3 Review — Plan

1. **Concurrency + Actor Audit**
   - Re-read `WindowSnapManager`, `WindowCoordinator`, and the three window controllers to make sure every UI touchpoint is `@MainActor`-constrained and long-lived `Task`s cancel correctly.
   - Verify helper views (`TitlebarDragCaptureView`, playlist helpers) do not violate Sendable rules or leave main-actor contexts.

2. **SwiftUI & Gesture Pass**
   - Inspect `WinampMainWindow`, `WinampEqualizerWindow`, `WinampPlaylistWindow`, and `WinampTitlebarDragHandle` for state explosion, idle timers, gesture composition, and unnecessary re-renders.
   - Confirm drag hit areas align with sprites and that inactive-window gestures behave like classic Winamp (single-click drag).

3. **macOS 15+/26 Architecture Review**
   - Trace NSWindow creation/configuration (controllers, configurator, multiplexer) to ensure borderless windows behave with modern APIs (activation, spaces, multi-monitor, `NSScreen` handling) and that screen-space math handles multi-monitor layouts.

4. **Code Quality & Edge Cases**
   - Sweep the focused files for debug code, dead code, or duplicated logic.
   - Stress-test algorithms conceptually for multi-monitor bounds, off-screen prevention, drag cancellation, and event cleanup.

5. **Synthesis & Grading**
   - Collate any issues into P0–P3 buckets with file/line callouts.
   - Assign grades for Swift 6 compliance, SwiftUI practices, macOS architecture, code quality, and overall architecture, then decide whether Phase 4 can start or needs fixes first.
