# State: AudioPlayer Seek Extraction

> **Description:** Extract the seek state machine from AudioPlayer.swift into SeekController.
> **Updated:** 2026-03-24 (S2 complete, responsibility map done, plan implementation-ready)

## Status

READY TO START. Responsibility map and implementation plan complete.

**Sprint:** Post-S2 / pre-S3
**Created:** 2026-03-22
**Last Updated:** 2026-03-24

## Scheduling

- S2 dependencies resolved: `os-workgroup-integration` (PR #66), `stream-track-counter` (PR #68), `airplay-integration` (PR #69) all merged
- `video-audio-engine-routing` deferred to S3 — no further AudioPlayer changes expected
- Execution order: **Task 5 of 5** (highest risk — seek state machine coupling)
- Tests expanded BEFORE extraction (risk mitigation)

## Current Line Count

740 lines (grew from 719 due to S2: stream-track-counter + Now Playing hooks)

## Expected Result

- AudioPlayer.swift: 740 -> ~554 lines (below 600 warning and error thresholds)
- New SeekController.swift: ~186 lines
- Both swiftlint suppressions removed
- Zero behavioral changes

## Key Decision

- New `SeekController` in `Audio/` (not expanding AudioEngineController — distinct responsibilities)
- Atomic extraction: all 3 guards + shouldIgnoreCompletion + seek + seekToPercent + onPlaybackEnded move together
- AudioPlayer calls through SeekController for guard management (invalidateSeekID, clearSeekGuard, activateSeekGuard)
- Callback pattern for playlist advancement (SeekController doesn't know about playlists)
- Decompose in place within `Audio/` — folder moves to `Audio/Playback/` deferred to post-S3
