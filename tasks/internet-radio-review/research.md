## Context

- Feature adds internet radio streaming alongside local playback.
- `PlaybackCoordinator` mediates between `AudioPlayer` (local files) and new `StreamPlayer` (AVPlayer-based).
- Views depend on coordinator for transport commands and title display, while retaining `AudioPlayer` for playlist data, EQ, timers, and track metadata.

## File Walkthrough

- `AudioPlayer.swift`
  - `Track.isStream` identifies non-file HTTP(S) URLs.
  - `playTrack` now guards against streams, expecting coordinator to route them.
  - Playlist navigation (`nextTrack`, `previousTrack`) still assumes playable tracks.
- `StreamPlayer.swift`
  - Handles AVPlayer playback, buffering, metadata, and error state.
  - `play(url:title:artist:)` wraps bare URLs into `RadioStation`.
- `PlaybackCoordinator.swift`
  - Maintains unified state (`currentSource`, `currentTitle`, `currentTrack`).
  - `play(track:)` branches on `track.isStream` and forwards to proper backend.
  - `displayTitle` covers buffering/errors/metadata fallbacks.
  - `next`/`previous` delegate to `AudioPlayer.nextTrack/previousTrack` then re-call `play(track:)`.
- `WinampMainWindow.swift`
  - Transport buttons call coordinator, track display reads `coordinator.displayTitle`.
  - Still references `audioPlayer` for playback progress, shuffle/repeat toggles, and metadata displays.
- `WinampPlaylistWindow.swift`
  - Playlist double-click uses coordinator.
  - Mini transport buttons route through coordinator.
  - M3U parser and ADD URL append streams to `audioPlayer.playlist`.
- `MacAmpApp.swift`
  - Initializes shared `PlaybackCoordinator` in `@State` and injects into environment.

## Emerging Risks / Questions

- `AudioPlayer.nextTrack()` still attempts to `playTrack` on every entry; when the next item is a stream the guard exits early, leaving `audioPlayer.currentTrack` unchanged. Coordinator’s `next()` then replays the previous local track instead of advancing to the stream or skipping it.
- Similar issue for `previousTrack()` when current item is a stream: coordinator delegates to `AudioPlayer.previousTrack()`, which operates on its `currentTrack` (last local track), so the navigation context differs from coordinator’s `currentTrack`.
- Coordinator toggles `currentSource` but does not observe `StreamPlayer` updates; `currentTitle` for radio falls back to track title until metadata arrives, which is expected but worth verifying during review.
- `displayTitle` returns `currentTrack?.title` for locals; ensure Track titles are populated for local metadata reload to satisfy “MacAmp shows track title” fix.
