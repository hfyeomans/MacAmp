# Plan

1. **Choose navigation architecture**
   - Keep shuffle/repeat behavior centralized in `AudioPlayer`
   - Expose helpers that return the next or previous `Track` without triggering playback, so the coordinator can route to the proper backend
   - Ensure `AudioPlayer` still tracks the active playlist item even when playback goes through `StreamPlayer`

2. **Refactor `AudioPlayer` navigation**
   - Add methods like `nextTrackCandidate()` / `previousTrackCandidate()` (or a unified helper) that compute playlist traversal, honoring shuffle/repeat and reporting end-of-list conditions
   - Update existing `nextTrack()` / `previousTrack()` to leverage the new helpers for local playback, maintaining backward compatibility where needed
   - Provide a way for the coordinator to update `AudioPlayer.currentTrack` when a stream item becomes active

3. **Update `PlaybackCoordinator` navigation**
   - Replace direct calls to `audioPlayer.nextTrack()` / `previousTrack()` with the new candidate helpers
   - Decide playback path (local vs. stream) based on the returned track and call into the appropriate player
   - Keep coordinator state (`currentTrack`, `currentSource`, `currentTitle`) consistent for UI updates

4. **Handle edge cases**
   - Ensure shuffle picks a stream or file and hands control to the correct player
   - Confirm repeat loops through the playlist regardless of source type
   - Handle empty playlists, single-item playlists, and scenarios where `previous` at the start seeks instead of wrapping (matching existing behavior)
   - Document the behavior and any follow-up considerations in `state.md`

