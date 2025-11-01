# Task State

- Implementation complete: added formatted local-title helper in `PlaybackCoordinator`, used when updating `currentTitle`, and updated `displayTitle` to rely on the formatted value with filename fallback.
- Stream handling path untouched; helper only runs for `.localTrack` sources.
- Verification: manually reasoned through `WinampMainWindow.buildTrackInfoDisplay` which now receives a non-empty `displayTitle` for local tracks (falls back to filename if metadata blank), so the UI no longer collapses to the "MacAmp" placeholder during playback.
