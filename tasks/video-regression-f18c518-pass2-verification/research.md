# Research

## Scope

- Pass-2 verification of commit `f18c518`.
- Focus files:
  - `MacAmpApp/Audio/AudioPlayer.swift`
  - `MacAmpApp/Audio/PlaybackCoordinator.swift`

## Evidence

- `f18c518` is current `HEAD` on `feat/video-audio-engine-routing`.
- The target files have no uncommitted local diff.
- Compared `f18c518^..f18c518` for the two focus files.
- Inspected `AudioPlayer.startVideoTrack`, `tearDownVideoBridge`, `play`, `pause`, `stop`, and `PlaybackCoordinator.resume`.
- Ran `rg` and `ast-grep` inventories for `videoPlaybackController.play()`, `videoPlaybackController.volume`, `videoLoadTask`, and `Task { @MainActor in ... }`.

## Findings

- The over-broad teardown volume restore is removed from `tearDownVideoBridge`.
- Volume restore now occurs only in the tap attach-failure branch of `startVideoTrack`, after the stale-task identity guard passes.
- The direct video `play()` path now returns while `videoLoadTask` is non-nil, preventing remote/media-key play from calling `AVPlayer.play()` before tap attach/bridge activation completes.
- New regression risk: `videoLoadTask` is not cleared when the load task completes successfully or via attach-failure. After initial video load, pause/resume still sees a non-nil completed task and `AudioPlayer.play()` returns early.

