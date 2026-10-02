# Research

## Scope
- Pass-2 review of Phase 3 video-audio-engine-routing race/cancellation changes.
- Files reviewed:
  - `MacAmpApp/Audio/AudioPlayer.swift`
  - `MacAmpApp/Audio/VideoPlaybackController.swift`
  - `MacAmpApp/Audio/AudioEngineController.swift`

## Focus Areas
1. Same-URL replay race in `startVideoTrack`.
2. Stop/deinit/playTrack-switch behavior while `loadVideo` is awaiting tap attach.
3. Placement and sufficiency of `videoLoadTask` cancellation.
4. Reconfigure local-audio reschedule gating.

## Evidence Collected
- `git show 7e953bd -- MacAmpApp/Audio/AudioPlayer.swift`
- Line-level inspection of:
  - `startVideoTrack`, `tearDownVideoBridge`, `stop`, `playTrack`, `deinit`, `handleEngineDidReconfigure` in `AudioPlayer`
  - `loadVideo`, `cleanup`, `detachAudioTap`, `deinit` in `VideoPlaybackController`
  - `activateVideoBridge`, `deactivateVideoBridge`, `shutdown`, `handleEngineDidReconfigure` in `AudioEngineController`
  - `VideoAudioTap.attach/detach` lifecycle

## Key Observations
- Stale guard now uses tap identity (`videoAudioTap === tap`) plus `!Task.isCancelled`.
- `videoLoadTask` is canceled/nil'd in `tearDownVideoBridge`.
- `playTrack` video path always executes `tearDownVideoBridge()` before creating a new tap/task.
- `VideoPlaybackController.loadVideo` protects against stale player mutation with `guard self.player === newPlayer` after await.
- Local-audio reschedule in `handleEngineDidReconfigure` now gated by `currentMediaType == .audio`.
