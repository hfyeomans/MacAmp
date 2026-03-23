# Todo: Playlist List Operations

> **Purpose:** Track implementation tasks for playlist NEW LIST, LOAD LIST, SAVE LIST buttons.

---

## Implementation

- [x] Implement `newList(_:)` — clear playlist (one-liner)
- [x] Implement `loadList(_:)` — NSOpenPanel + parse-before-clear + add entries
- [x] Add M3U writer method to `M3UParser.swift`
- [x] Implement `saveList(_:)` — NSSavePanel + M3U writer
- [x] Fix UTType: explicit `m3u`/`m3u8` instead of `.playlist` (Oracle finding)
- [x] Fix loadList: parse before clear to avoid data loss (Oracle finding)
- [x] Fix loadList: remove dead `radioLibrary` fallback (Oracle finding)
- [x] Fix presentAddFilesPanel: same UTType fix for consistency (Oracle low finding)
- [x] Fix stale metadata: playlistGeneration token in AudioPlayer (Oracle finding)
- [x] Fix file I/O: move M3U parse/write off main actor (Oracle finding)
- [x] Fix eject(): bump playlistGeneration before clear (Oracle finding)
- [x] Fix Track.isStream: case-insensitive scheme check (Oracle finding)
- [x] Remove radioLibrary gate from Add Files M3U path (Oracle finding)
- [x] Safe UTType unwrap in saveList (Oracle finding)
- [x] Use `ast-grep` to check for duplicate M3U write patterns — clean

## Build & Test

- [x] XcodeBuildMCP build with Thread Sanitizer — no warnings
- [x] XcodeBuildMCP test — all 53 tests pass

## Manual Testing

- [x] NEW LIST — clears playlist, stops playback
- [x] LOAD LIST — opens file dialog, replaces playlist with M3U contents
- [x] SAVE LIST — opens save dialog, exports valid M3U file
- [x] Round-trip: SAVE LIST → NEW LIST → LOAD LIST (saved file) — same tracks

## Review & PR

- [x] Oracle review — 9/10 final (4 rounds: 5→8.5→8→7→9)
- [x] Create PR #67 — merged (2026-03-22)
