# Research: AudioPlayer Seek Extraction

> **Description:** Document findings on seek state machine coupling and extraction strategy.
> **Purpose:** Inform the extraction plan with dependency analysis and risk assessment.

---

## Prior Research (from audioplayer-decomposition Phase 4)

The Phase 4 Oracle review (gpt-5.3-codex xhigh, 2026-03-22) analyzed the seek state machine:

### Coupling Points

`currentSeekID`, `seekGuardActive`, `isHandlingCompletion` are accessed in:
- `AudioPlayer.swift:58-60` — property declarations
- `AudioPlayer.swift:215` — `shouldIgnoreCompletion(from:)`
- `AudioPlayer.swift:320` — `playTrack` sets `seekGuardActive = true`, `currentSeekID = UUID()`
- `AudioPlayer.swift:493` — `stop()` resets `currentSeekID`
- `AudioPlayer.swift:619+` — `onPlaybackEnded` checks all three guards

### Oracle Recommendation

> "Keep seek state machine in AudioPlayer for this phase, unless you also move onPlaybackEnded completion filtering as one atomic unit. Partial move is the risky path."

### Extraction must be atomic

All of these must move together:
1. `currentSeekID`, `seekGuardActive`, `isHandlingCompletion` (state)
2. `shouldIgnoreCompletion(from:)` (guard logic)
3. `seekToPercent(_:resume:)` (entry point)
4. `seek(to:resume:)` (core implementation)
5. `onPlaybackEnded(fromSeekID:)` (completion handler)

`playTrack` and `stop` would need to call through the controller for seek guard management instead of directly setting the properties.

## Pending Research

- How S2 tasks affect AudioPlayer's seek path (wait for S2 to stabilize)
- Whether expanding AudioEngineController is cleaner than a new SeekController
- Whether `onPlaybackEnded`'s playlist navigation coupling can be cleanly separated
