# State: Playlist List Operations

> **Purpose:** Implement playlist LIST OPTS buttons: NEW LIST, LOAD LIST, SAVE LIST
> **Created:** 2026-03-14
> **Sprint:** S2 (MEDIUM)
> **Status:** IN PROGRESS

---

## Current Status

**Phase:** Implementation complete — awaiting manual testing + PR
**Status:** IN PROGRESS
**Branch:** `feature/playlist-list-operations`
**Oracle Score:** 8.5/10
**Last Updated:** 2026-03-22

## Oracle Review (2026-03-22)

**Initial score:** 5/10 (4 findings)
**Revised score:** 8.5/10 (3 fixed, 1 pre-existing accepted)

| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| 1 | HIGH | Open panel `.playlist` UTType doesn't match `.m3u`/`.m3u8` | Fixed — explicit `UTType(filenameExtension:)` |
| 2 | HIGH | `loadList` clears playlist before parse (data loss on failure) | Fixed — parse first, clear only on success |
| 3 | MEDIUM-HIGH | Stale metadata tasks after clear | Accepted — pre-existing behavior, not in scope |
| 4 | MEDIUM | `radioLibrary` nil fallback is dead code | Fixed — loadList handles parsing directly |

Bonus fix: `presentAddFilesPanel` also used `.playlist` — fixed for consistency.

---
