# Plan: AudioPlayer Seek Extraction

> **Description:** Implementation plan for extracting the seek state machine from AudioPlayer.swift.
> **Purpose:** Complete the AudioPlayer decomposition — remove remaining swiftlint suppressions.

---

## Planning Constraint

This task is backlog-ready but not implementation-ready. The detailed extraction plan should be written when S2 stabilizes, because S2 tasks may modify AudioPlayer's seek path.

## Key Design Decision (Oracle, 2026-03-22)

The Oracle recommended keeping seek in AudioPlayer during Phase 4 because:
1. `currentSeekID`, `seekGuardActive`, `isHandlingCompletion` are mutated/checked outside seek paths (in `playTrack`, `stop`, `onPlaybackEnded`)
2. Partial move splits one state machine across two owners
3. `onPlaybackEnded` bridges seek guards, playlist navigation, and state transitions

## Likely Approach

Extract a `SeekController` or expand `AudioEngineController` with seek methods. The seek state machine must move as an **atomic unit** — all three guards + `shouldIgnoreCompletion` + `seek` + `seekToPercent` + `onPlaybackEnded` together.

AudioPlayer's `playTrack` and `stop` would call through the controller for seek guard management.

## Expected Result

AudioPlayer.swift: ~719 → ~533 lines (below 600 warning and 600 error thresholds)
Both swiftlint suppressions removed.
