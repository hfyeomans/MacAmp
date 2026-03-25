# State: AudioPlayer Seek Extraction

> **Description:** Extract the seek state machine from AudioPlayer.swift into SeekController.
> **Updated:** 2026-03-25 (DEFERRED — Option C per responsibility sweep)

## Status

DEFERRED (Option C). Responsibility sweep confirmed AudioPlayer has one cohesive responsibility (local audio playback orchestration facade). 734 lines with swiftlint suppressions accepted as threshold mismatches, not architecture signals.

The 6-callback SeekController pattern would create pass-through indirection (Principle 6). Seek state (`currentSeekID`, `seekGuardActive`, `isHandlingCompletion`) is tightly coupled to play/stop/onPlaybackEnded (Principle 3: state ownership).

## Fallback (Option B)

If AudioPlayer grows past 800 lines during S3 (e.g., `video-audio-engine-routing`) or gains a genuinely new responsibility, revisit with a lean SeekController design:
- Give SeekController direct references to `engine` and `videoPlaybackController`
- Reduce to ~2 callbacks (`onRequestNextTrack`, `onPlaylistAdvanceRequest`)
- Kill switch: cancel if state ownership would still be fragmented

## Re-evaluation Criteria

- File grows past 800 lines
- New responsibility added (not just more facade forwarding)
- Seek logic becomes independently testable requirement
