## Context

- Branch `feature/video-milkdrop-windows` adds dedicated VIDEO and Milkdrop windows plus shared focus tracking/state coordination across all five Winamp-style windows.
- `WindowCoordinator` (MacAmpApp/ViewModels/WindowCoordinator.swift) now owns five `NSWindowController`s and new helper tasks for observing settings, video window state, and focus delegates (via `WindowDelegateMultiplexer`).
- Focus is bridged through `WindowFocusState` (`@Observable @MainActor`) and fed by `WindowFocusDelegate` (AppKit `NSWindowDelegate`) so SwiftUI titlebars can react without touching `NSWindow`.
- SwiftUI chrome views (`WinampVideoWindow`, `VideoWindowChromeView`, `WinampMilkdropWindow`, etc.) render the Winamp skins and rely on observable models (`VideoWindowSizeState`, `WindowFocusState`, `SkinManager`, etc.) instead of AppKit primitives.
- `VideoWindowChromeView` supplies quantized resize (25×29 grid) and uses an AppKit overlay (`WindowResizePreviewOverlay`) plus callbacks into `WindowCoordinator.updateVideoWindowSize(to:)` after drag gestures or 1×/2× buttons.
- `AudioPlayer` implements dual backend (AVAudioEngine + AVPlayer). Volume setter syncs `playerNode` + `videoPlayer`. Video playback uses `setupVideoTimeObserver`, `seekToPercent` with media-type branching, and `cleanupVideoPlayer` to tear timers/observers down.
- Model helpers: `Size2D` encodes quantized widths/heights, while `VideoWindowSizeState` is `@Observable @MainActor` storing `Size2D` with UserDefaults persistence and computed layout helpers for chrome tiling.

## Relevant Patterns Observed

1. **AppKit lifecycle**
   - Window controllers (`Winamp*WindowController`) construct `BorderlessWindow`, apply `WinampWindowConfigurator`, embed SwiftUI `NSHostingController`, and install translucent hit layers.
   - Controllers are not annotated with `@MainActor`; initialization occurs from `MacAmpApp` on main thread implicitly.

2. **Focus tracking**
   - `WindowCoordinator` instantiates focus delegates per window and injects them into multiplexer to forward `windowDidBecomeKey`/`windowDidResignKey`.
   - Views consume `@Environment(WindowFocusState.self)` and render active/inactive sprites accordingly (Video/Milkdrop chrome, Main/EQ/Playlist windows).

3. **SwiftUI ↔ NSWindow interaction**
   - `WinampVideoWindow` and chrome view call `WindowCoordinator.shared` helpers (e.g., `updateVideoWindowSize`) rather than owning `NSWindow`.
   - Some legacy UI buttons (Main window window-toggle buttons, playlist menus) still call `NSWindow`/`NSApp` directly once they fetch handles via `WindowCoordinator`.

4. **Video playback unification (AudioPlayer)**
   - `currentMediaType` toggles between `.audio`/`.video`; `seek()`/`seekToPercent()` branch accordingly.
   - `videoTimeObserver` uses `AVPlayer.addPeriodicTimeObserver` on main queue to update `currentTime/currentDuration/playbackProgress`.
   - `cleanupVideoPlayer()` removes observers and nils `videoPlayer`.

5. **Window sizing**
   - `WindowCoordinator.updateVideoWindowSize` clamps to integral top-left coordinates before calling `NSWindow.setFrame`.
   - SwiftUI components track drag start state, show overlay preview, and only commit on `.onEnded` to avoid jitter.

6. **Entry points**
   - `MacAmpApp` bootstraps `WindowCoordinator.shared` with dependencies, while `AppCommands` defines high-level keyboard shortcuts (not yet inspected for new windows).

