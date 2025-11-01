# TODO

- [x] Harden `onPlaybackEnded` guard so completions whose `seekID` no longer matches `currentSeekID` are ignored even after the delay window
- [x] Serialize `addTrack(url:)` so duplicate checks and playlist appends happen atomically (e.g. placeholder entry or actor)
- [x] Run with Thread Sanitizer after making fixes to confirm no outstanding races
