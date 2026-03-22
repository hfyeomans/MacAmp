# Research: audio-video playback bug

## Context
- File: `MacAmpApp/Audio/AudioPlayer.swift`
- Scenario: double-clicking a video track while an audio track is currently playing keeps the audio stream alive, so audio and video run simultaneously.

## Observations
1. `playTrack(track:)` (MacAmpApp/Audio/AudioPlayer.swift:327-378) stops the `AVAudioPlayerNode`, but it never mutates `currentSeekID` or transitions through `.stopped(.manual)` before calling `playerNode.stop()`.
2. Each scheduled segment is created in `scheduleFrom(time:seekID:)` (MacAmpApp/Audio/AudioPlayer.swift:1008-1040). Its completion handler captures the seek identifier and calls `onPlaybackEnded(fromSeekID:)` with that UUID when playback finishes.
3. `shouldIgnoreCompletion(from:)` (MacAmpApp/Audio/AudioPlayer.swift:189-209) ignores completions only when the supplied ID differs from the current `currentSeekID`, when `seekGuardActive` is true, or when playback is already `.stopped(.manual/.ejected)`.
4. Because `currentSeekID` is not updated in `playTrack` during an audio→video transition, `playerNode.stop()` fires the existing completion handler with what still looks like the active seek ID. The guard therefore lets `onPlaybackEnded` run.
5. `onPlaybackEnded` transitions to `.stopped(.completed)` and immediately calls `nextTrack()`, which reschedules audio playback and restarts the progress timer even while the video pipeline is being created.
6. The `seek(to:)` path (MacAmpApp/Audio/AudioPlayer.swift:1251-1322) already includes the correct mitigation: it generates a new `currentSeekID` and enables `seekGuardActive` before triggering the stop/reschedule, which prevents stale completions from mutating state.

## Conclusion
The lingering audio is not due to `playerNode.stop()` failing; the completion handler still appears “current” because `currentSeekID` is unchanged. Bumping `currentSeekID` (and optionally setting a short `seekGuardActive` window) before stopping the node during manual transitions will make `shouldIgnoreCompletion` discard that completion so audio cannot restart under the new video playback.

