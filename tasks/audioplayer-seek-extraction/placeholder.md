# Placeholders: AudioPlayer Seek Extraction

> **Description:** Tracks deferred cleanup and deduplication targets discovered during extraction.
> **Purpose:** Checklist for the future simplification/dedup pass (Phase 2.5, after file moves).

---

## Deduplication Targets (For future Phase 2.5 simplification pass)

| Location | Issue | Suggested Fix |
|----------|-------|---------------|
| SeekController seek guard delays (50ms, 100ms, 200ms) | Three different delay values for `Task.sleep` guard clearing. These were established through debugging across multiple PRs and are timing-sensitive. | Evaluate whether a single configurable delay or a more structured guard-clearing mechanism would be cleaner. Only change after comprehensive seek tests are in place. |

## Architecture Notes (For future consideration)

| Item | Context |
|------|---------|
| SeekController vs AudioEngineController expansion | The Oracle recommended a new SeekController rather than expanding AudioEngineController. AudioEngineController owns engine transport (play/pause/stop/volume/balance). SeekController owns seek state machine (guards, completion filtering, playlist advancement). These are distinct responsibilities. |
| onPlaybackEnded playlist coupling | `onPlaybackEnded` calls `nextTrack()` which returns `PlaylistAdvanceAction`. This couples seek completion to playlist navigation. The callback pattern preserves this coupling cleanly — SeekController doesn't need to know about playlists, it just fires the callback. |
