# State: audio-video playback bug

- Research complete — see `research.md` for call-chain analysis that shows `playerNode.stop()` fires an old completion handler whose seek ID still matches `currentSeekID`.
- Awaiting implementation of guard logic in `playTrack(track:)` following the plan.
- No code changes have been made yet; repo still reproduces the bug.
