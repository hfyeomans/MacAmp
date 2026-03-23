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
- [x] Use `ast-grep` to check for duplicate M3U write patterns — clean

## Build & Test

- [x] XcodeBuildMCP build with Thread Sanitizer — no warnings
- [x] XcodeBuildMCP test — all 53 tests pass

## Manual Testing

- [ ] NEW LIST — clears playlist, stops playback
- [ ] LOAD LIST — opens file dialog, replaces playlist with M3U contents
- [ ] SAVE LIST — opens save dialog, exports valid M3U file
- [ ] Round-trip: SAVE LIST → NEW LIST → LOAD LIST (saved file) — same tracks

## Review & PR

- [x] Oracle review — 8.5/10 after fixes (3 findings fixed, 1 pre-existing accepted)
- [ ] Create PR for user review
