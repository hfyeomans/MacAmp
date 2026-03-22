# State: AudioPlayer Seek Extraction

> **Description:** Extract the seek state machine and seeking methods from AudioPlayer.swift into a dedicated controller.
> **Purpose:** Reduce AudioPlayer below swiftlint thresholds (file_length 600, type_body_length 600) and remove the remaining inline suppressions.

## Status

📋 PLANNED — Post-S2 / pre-S3 architecture follow-on.

**Sprint:** Post-S2 / pre-S3
**Created:** 2026-03-22
**Last Updated:** 2026-03-22

## Context

AudioPlayer.swift is currently 719 lines after Phase 4 extraction (PR #60). Two swiftlint suppressions remain:
- `// swiftlint:disable file_length` (719 > 600 warning)
- `// swiftlint:disable:this type_body_length` (~705 > 600 error)

Phase 4 extracted engine wiring, stream bridge, transport, and visualizer tap into AudioEngineController (413 lines). The Oracle (gpt-5.3-codex xhigh) recommended **deferring seek extraction** because the seek state machine (`currentSeekID`, `seekGuardActive`, `isHandlingCompletion`, `shouldIgnoreCompletion`) is tightly coupled to `onPlaybackEnded`, `playTrack`, `stop`, and playlist navigation. Partial move splits one state machine across two owners.

## What Would Move

| Section | Lines | What |
|---------|-------|------|
| Seeking/Scrubbing | ~111 | `seekToPercent`, `seek` |
| Seek state machine | ~35 | `currentSeekID`, `seekGuardActive`, `isHandlingCompletion`, `shouldIgnoreCompletion` |
| `onPlaybackEnded` | ~40 | Completion filtering (uses seek guards) |

**Total:** ~186 lines → AudioPlayer drops from ~719 to ~533 (below both thresholds)

## Prerequisites

- Seek state machine unit tests must be comprehensive before extraction (13 characterization tests exist from Phase 4, but they test through observable state only — seek guards are private)
- S2 tasks (`os-workgroup-integration`, `video-audio-engine-routing`) may modify AudioPlayer — wait until those stabilize

## Dependency

Follows `audioplayer-decomposition` Phase 4 (PR #60, S1). Continues the same facade pattern with AudioEngineController.

## Architecture Alignment

- Decompose in place: new files in `MacAmpApp/Audio/`
- Folder moves to `Audio/Playback/` deferred to post-S3 Structure Sprint (D-STRUCTURE decision)
