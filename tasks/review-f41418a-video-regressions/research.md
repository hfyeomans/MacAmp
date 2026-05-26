# Review f41418a Video Regressions Research

## Scope

- Review commit `f41418a` on `feat/video-audio-engine-routing`.
- Focus on Swift Observation for `VideoPlaybackController.player` and audio-path routing while the video bridge is active or attaching.

## Initial Context

- User reports Phase 3 real-video regressions: blank video display and double audio.
- Phase 3 spec references attach-before-play ordering in plan section 8.4 and Phase 6 tap-fallback volume gating in section 11.6.

## Findings

- Removing `@ObservationIgnored` from `VideoPlaybackController.player` is consistent with the SwiftUI dependency in `WinampVideoWindow`: the view reads `audioPlayer.videoPlayer`, which forwards to `videoPlaybackController.player`. Swift Observation tracks the stored property write, not AVPlayer's internal KVO state.
- `AudioPlayer.volume.didSet` gating on `engine.isVideoBridgeActive` avoids unmuting AVPlayer during active bridge playback. The in-flight attach window is not itself an audible slider race because `loadVideo(autoPlay: false)` does not start playback until after attach success/failure is returned to `AudioPlayer`.
- `tearDownVideoBridge()` now always writes `videoPlaybackController.volume = volume` after clearing the bridge and detaching the tap. That helper is used by normal stop/switch/deinit paths, not only by tap fallback. For normal teardown, the old AVPlayer should remain silent or be paused/nilled before volume restore.
- Video-to-video switch is the clearest risk: `playTrack` calls `tearDownVideoBridge()` and then schedules the next `loadVideo` asynchronously. The old player may remain alive until the next task's `cleanup()`, and the teardown re-sync can unmute it after `audioMix` is removed.
