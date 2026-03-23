# State: Playlist List Operations

> **Purpose:** Implement playlist LIST OPTS buttons: NEW LIST, LOAD LIST, SAVE LIST
> **Created:** 2026-03-14
> **Sprint:** S2 (MEDIUM)
> **Status:** COMPLETE

---

## Current Status

**Phase:** COMPLETE
**Status:** ✅ COMPLETE — PR #67 merged (2026-03-22)
**Branch:** `feature/playlist-list-operations` (merged to main)
**Oracle Score:** 9/10 final
**Last Updated:** 2026-03-22

## Oracle Review History (2026-03-22)

| Round | Score | Key Change |
|-------|-------|------------|
| 1 | 5/10 | UTType, parse-before-clear, radioLibrary fallback, stale metadata |
| 2 | 8.5/10 | Fixed 3 of 4; pre-existing stale metadata accepted |
| 3 | 8/10 | New: eject() missing generation bump + Add Files M3U on main |
| 4 | 7/10 | Fixed eject + Add Files background I/O; new: radioLibrary gate + force unwrap |
| 5 | 9/10 | All findings addressed |

## Changes Summary

- **NEW LIST:** `audioPlayer.clearPlaylist()` (no confirmation, Winamp behavior)
- **LOAD LIST:** NSOpenPanel → parse off main actor → clear on success → add entries
- **SAVE LIST:** NSSavePanel → `M3UWriter.write()` off main actor
- **M3UWriter:** New struct in `M3UParser.swift` — `#EXTM3U` format export
- **playlistGeneration token:** Guards stale metadata tasks in `addTrack()`, incremented by `clearPlaylist()`, `replacePlaylist()`, `eject()`
- **UTType fix:** Explicit `m3u`/`m3u8` types in `loadList` + `presentAddFilesPanel`
- **Track.isStream:** Case-insensitive scheme comparison
- **Background I/O:** All M3U parse/write via `Task.detached`

---
