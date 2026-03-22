## Status (Initial Review Pass)

- Research + plan captured under `tasks/video-window-review/{research,plan}.md`.
- Completed code reading for WindowCoordinator, WindowFocus*, Winamp* window controllers/views, and AudioPlayer video-flow sections.
- Ran mandated `sg`/`rg` queries (NSWindow usage inside `MacAmpApp/Views`, `@MainActor` coverage, timer patterns).
- Ready to document findings (AppKit/SwiftUI separation breaches, missing `@MainActor`, timer actor violations, and verification of video playback observer/volume sync).
