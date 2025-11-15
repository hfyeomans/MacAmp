# State

- Added `test.html` to the app's resource build phase so Butterchurn assets are actually packaged with the app.
- Updated `ButterchurnWebView.makeNSView` to search for `test.html` first, fall back to `index.html`, and log whichever file is loaded (or the exact path searched on failure).
- Remaining: no runtime verification yet (requires running the app), but project files now reference the HTML entrypoint and the loader can no longer silently fail when `test.html` is missing.
- Reconfirmed that `WindowCoordinator` constructs `WinampMilkdropWindowController` during app launch (MacAmpApp/ViewModels/WindowCoordinator.swift:147), so the purple controller logs and green SwiftUI `onAppear` logs only fire once during startup; toggling the window later reuses the already-created controller and therefore produces no additional logs.
