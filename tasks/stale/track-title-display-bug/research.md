## Goal
- Investigate why `playbackCoordinator.displayTitle` falls back to `MacAmp` while local tracks are playing.

## Findings
- `WinampMainWindow` renders the scrolling title using `playbackCoordinator.displayTitle`, falling back to the literal `"MacAmp"` only when the computed title is empty.
- `PlaybackCoordinator.displayTitle` returns `"MacAmp"` exclusively when `currentSource` is `nil`.
- `play(track:)` sets `currentSource = .localTrack(track.url)`, so `currentSource` should not be `nil` during local playback.
- `MacAmpApp` defines `playbackCoordinator` as a computed property returning `PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)`. Each evaluation creates a brand-new coordinator instance with default state (`currentSource == nil`).
- SwiftUI re-evaluates view bodies frequently, so `environment(playbackCoordinator)` injects a fresh `PlaybackCoordinator` repeatedly. UI reads from this new instance (with `currentSource == nil`), hence `displayTitle` resolves to `"MacAmp"` even though playback is active in the old instance.

## Conclusion
- The coordinator must be held as stable state (e.g., `@State` or `@StateObject`) so the same instance is shared across updates. The current computed property recreates it, resetting state and breaking the UI binding.
