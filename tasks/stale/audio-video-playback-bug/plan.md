# Plan: audio-video playback bug

## Goal
Prevent the audio engine from re-triggering `onPlaybackEnded` (and thus restarting audio) when we manually switch from an audio track to a video track inside `AudioPlayer.playTrack(track:)`.

## Steps
1. **Guard manual stop**  
   - Inside `playTrack`, before calling `playerNode.stop()`, generate a fresh `currentSeekID = UUID()` and set `seekGuardActive = true`.  
   - This mirrors the protective pattern already used in `seek(to:)`.

2. **Tear down progress timer safely**  
   - After invalidating the timer, schedule a brief async task to clear `seekGuardActive` once the old completion handler has had a chance to fire and be ignored. (Reuse the delay values from `seek` for consistency.)

3. **Verify completion suppression**  
   - Confirm that `shouldIgnoreCompletion` now returns `true` for the completion triggered by `playerNode.stop()`, preventing `onPlaybackEnded` from running.  
   - Inspect logs (if available) to ensure `nextTrack()` is no longer invoked when switching to video.

4. **Regression check**  
   - Switch video→audio to confirm the existing video cleanup still works.  
   - Seek within an audio track to confirm the shared guard logic does not interfere with normal seeking.

