# Track Title Regression Research

## Key Files Reviewed
- `MacAmpApp/MacAmpApp.swift`
- `MacAmpApp/Audio/PlaybackCoordinator.swift`
- `MacAmpApp/Audio/AudioPlayer.swift`
- `MacAmpApp/Views/WinampMainWindow.swift`

## Findings
- `MacAmpApp` now stores `PlaybackCoordinator` in `@State` (`@State private var playbackCoordinator: PlaybackCoordinator`) and injects it via `.environment(playbackCoordinator)`, so the coordinator is no longer recreated on every render.
- `PlaybackCoordinator.play(track:)` sets:
  - `currentTrack = track`
  - `currentSource = .localTrack(track.url)` for local files
  - `currentTitle = "\(track.title) - \(track.artist)"`
- `PlaybackCoordinator.displayTitle` currently returns `currentTrack?.title ?? currentTitle ?? "Unknown"` when `currentSource` is `.localTrack`.
  - `currentTrack?.title` can be an empty string when metadata lacks a title (e.g. blank ID3 tag). In that case `displayTitle` yields an empty string because `??` only checks for `nil`.
  - In `WinampMainWindow.buildTrackInfoDisplay`, `trackText` becomes `"MacAmp"` whenever `displayTitle.isEmpty`, so blank titles surface as the "MacAmp" fallback.
- `AudioPlayer.loadTrackMetadata(url:)` populates `Track` values. When metadata fields are present but empty, the resulting `track.title` or `track.artist` can be `""`.
- For local playback the previous UI logic used `AudioPlayer.currentTitle`, which was always formatted as `"Title - Artist"` (falling back to filename when metadata missing). The new coordinator path lost that formatting.

## Hypothesis
`displayTitle` should prioritize the coordinator's formatted `currentTitle` (and fall back to filename) instead of trusting `currentTrack?.title` directly. Doing so restores the "Title - Artist" output and prevents empty metadata from collapsing to "MacAmp".

## Open Questions
- None identified; behavior is well specified in the bug report.
