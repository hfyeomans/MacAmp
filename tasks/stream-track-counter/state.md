# State: Stream Track Counter

> **Purpose:** Add stream elapsed time counter and playlist track position display
> **Created:** 2026-03-14
> **Sprint:** S2 (MEDIUM)
> **Status:** IN PROGRESS

---

## Current Status

**Phase:** Plan revised, ready for implementation
**Status:** IN PROGRESS
**Branch:** `feature/stream-track-counter` (not yet created)
**Last Updated:** 2026-03-23

## Oracle Plan Review (2026-03-23)

**Initial score:** 7/10 (3 findings)
**Revised score:** 9/10 (all 3 addressed, 2 low remaining)

| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| 1 | HIGH | Playlist position on AudioPlayer leaks stale values during non-playlist playback | Fixed — moved to PlaybackCoordinator with nil guard |
| 2 | MEDIUM | `elapsedTime += 0.1` drifts when main run loop stalls | Fixed — anchor-based: `accumulated + (now - startedAt)` with ContinuousClock |
| 3 | MEDIUM | ICY title-only reset too noisy and narrow | Fixed — normalized `(title, artist)` pair, ignore empty/duplicate |
| 4 | LOW | ICY identity should trim/case-fold to avoid whitespace churn | Address in implementation |
| 5 | LOW | Position guard should explicitly check currentTrack/localTrack | Address in implementation |

---
