# Plan: Playlist List Operations

> **Purpose:** Implementation plan for playlist LIST OPTS buttons (NEW LIST, LOAD LIST, SAVE LIST).

**Status:** Ready for implementation (2026-03-22)

---

## Scope

Implement the 3 LIST OPTS operations in `PlaylistWindowActions.swift`. The UI (buttons, menus, sprites) is already wired — only the action method bodies need real code.

## Changes

### 1. `newList(_:)` — Clear playlist (Trivial)

Replace alert with `audioPlayer.clearPlaylist()`. Classic Winamp has no confirmation dialog.

### 2. `loadList(_:)` — Load M3U playlist (Small)

Replace alert with:
1. `NSOpenPanel` configured for `.m3u` / `.m3u8` file types
2. On OK: clear current playlist first (LOAD LIST replaces, per Winamp behavior)
3. Call existing `loadM3UPlaylist()` to parse and add entries

### 3. `saveList(_:)` — Save M3U playlist (Small-Medium)

Replace alert with:
1. `NSSavePanel` configured for `.m3u` default extension
2. On OK: write current playlist as `#EXTM3U` format
3. New static method `M3UWriter.write(tracks:to:)` in `M3UParser.swift` (co-locate with parser)

### M3U Writer Format

```
#EXTM3U
#EXTINF:234,Artist - Title
/path/to/file.mp3
#EXTINF:-1,Station Name
http://stream.example.com/radio
```

- Duration in seconds for local files, -1 for streams (unknown duration)
- Title from `Track.title` (optionally prefixed with `Track.artist` if available)
- URL as absolute path for local files, full URL for streams

## Non-Changes

- No new UI elements (all already wired)
- No changes to M3UParser (read path unchanged)
- No changes to PlaylistController or AudioPlayer APIs
- No sprite changes
