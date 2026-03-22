# Plan

1. **Document BUG 1 diagnosis**
   - Trace eject button flow through `WinampMainWindow.openFileDialog` and `PlaylistWindowActions.presentAddFilesPanel`
   - Explain why relying solely on `AudioPlayer.addTrack` leaves `PlaybackCoordinator` unaware of the active track
   - Recommend updating eject/add-file pipeline to inform the coordinator (e.g., pass coordinator into actions, or trigger `PlaybackCoordinator.play(url:)` once selection completes)

2. **Propose BUG 1 fix**
   - Outline code changes ensuring metadata and playback state propagate immediately
   - Consider how `AudioPlayer.addTrack` autoplay interacts with coordinator updates
   - Highlight any UI/UX decisions (autoplay first selection vs. only queue) and needed adjustments

3. **Analyze BUG 2 navigation**
   - Review `AudioPlayer.PlaylistAdvanceAction` and coordinator handling for sequential and shuffle modes
   - Confirm repeat/end-of-list behavior and stream hand-off logic
   - Identify remaining edge cases (empty playlist, restart current, auto-advance)

4. **Provide concrete implementation guidance**
   - Share recommended updated implementations for `next()`/`previous()` in coordinator and the helper flow in `AudioPlayer`
   - Include pseudocode or exact Swift snippets adhering to project standards
   - Call out any further tests or verifications engineers should run
