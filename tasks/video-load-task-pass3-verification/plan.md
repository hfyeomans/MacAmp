# Pass-3 Video Load Task Verification Plan

1. Inspect commit `d112e1b` and the exact `AudioPlayer.swift` diff.
2. Trace the video load task lifecycle from `playTrack` through `startVideoTrack`, `play`, `pause`, and teardown.
3. Trace coordinator and remote-command resume paths into `audioPlayer.play()`.
4. Check whether stale/cancelled tasks can clear a newer task slot.
5. Run fresh tests, including TSan if supported by the local harness.
6. Score gate readiness and document any residual risk.
