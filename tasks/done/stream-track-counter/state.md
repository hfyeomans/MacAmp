# State: Stream Track Counter

> **Purpose:** Add stream elapsed time counter and playlist track position display
> **Created:** 2026-03-14
> **Sprint:** S2 (MEDIUM)
> **Status:** COMPLETE

---

## Current Status

**Phase:** COMPLETE
**Status:** ✅ COMPLETE — PR #68 merged (2026-03-23)
**Branch:** `feature/stream-track-counter` (merged to main)
**Oracle Score:** 8/10 (final comprehensive review)
**Last Updated:** 2026-03-23

## Changes Summary

### Core Feature
- **Stream elapsed timer:** Anchor-based (ContinuousClock), counts from play, pauses on buffer/pause, preserves through reconnect, resets on new play/stop. No ICY metadata reset (Winamp classic verified from source code).
- **Playlist position:** "3/15. Title" format in displayTitle. PlaylistController.currentPosition (1-based), coordinator-owned trackPositionString with nil guard.
- **Unified time display:** Views read from PlaybackCoordinator.displayTime/displayDuration instead of AudioPlayer directly. Remaining mode suppressed for streams.

### Bugfixes (Pre-existing, discovered during implementation)
- **Auto-play bypass:** `addTrack()` auto-played via `playTrack()` bypassing coordinator — removed. All auto-play now routes through `PlaybackCoordinator.play(track:)`.
- **PlaylistWindowActions consolidation:** Eliminated 4-way auto-play duplication. `autoPlayFirstTrack()` single source of truth. `handleSelectedURLs()` async (awaits M3U parsing). `addEntries()` shared. `parseAndAddM3U()` awaitable.
- **loadAudioFile crash guard:** File open failure now clears engine + transitions to stopped. Prevents crash on unreachable files (e.g., remote storage not mounted).
- **Dead code removal:** `PlaybackCoordinator.play(url:)` removed (unused in production).

## Oracle Review History

| Round | Score | Focus |
|-------|-------|-------|
| Plan review | 7/10 → 9/10 | Anchor timing, coordinator position, ICY normalization |
| Stream timer implementation | 9/10 | Timer lifecycle, Winamp behavior correction |
| Auto-play migration (initial) | 4/10 | Incomplete migration — 4 callers missed |
| Auto-play migration (complete) | 7/10 | M3U async path still had dual trigger |
| Auto-play refactor (consolidated) | 9/10 | Clean, one low finding (stale wasEmpty across await) |
| Final comprehensive | 8/10 | Stale wasEmpty + no test coverage for new paths |

## Lessons Learned

1. **Winamp classic does NOT reset elapsed on ICY metadata change.** `decode_pos_ms` counts continuously from Play until Stop. Verified from actual Winamp source code (in_mp3/DecodeThread.cpp, giofile.cpp). Initial plan was wrong.

2. **Auto-play should never be a side effect of addTrack().** Playlist mutation and playback orchestration are different concerns. Having `addTrack()` call `playTrack()` internally bypassed the coordinator and broke the three-layer pattern.

3. **Anchor-based timing > accumulator timing.** `elapsedTime += 0.1` drifts when the main run loop stalls. `accumulated + (now - startedAt)` using ContinuousClock is monotonically correct regardless of timer delivery jitter.

4. **Mixed async + sync file operations need a single await boundary.** `handleSelectedURLs` processing both plain files (sync) and M3U files (async parse) caused dual auto-play triggers when both had their own auto-play logic. Making the whole method async and awaiting M3U parsing inline eliminated the issue.

---
