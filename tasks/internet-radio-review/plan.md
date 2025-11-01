## Review Plan

1. Validate PlaybackCoordinator wiring
   - Confirm all transport controls (main window, playlist window, keyboard) invoke coordinator APIs.
   - Ensure no views call `AudioPlayer.play/pause/stop/next/previous` directly after migration.
2. Audit UI bindings
   - Verify track title displays use `PlaybackCoordinator.displayTitle` and `currentTrack`.
   - Reproduce logic for buffering, errors, and default “MacAmp” states.
3. Inspect stream support flow
   - Follow playlist ingestion (ADD URL, M3U) to ensure streams enter playlist but avoid `AudioPlayer.playTrack`.
   - Trace `PlaybackCoordinator.play(track:)`, `next()`, `previous()` for mixed playlists.
4. Identify risks and remaining issues
   - Focus on navigation edge cases, state persistence, and regression of “MacAmp” title bug.
   - Summarize findings against verification checklist for final report.
