# Research: Playlist List Operations

> **Purpose:** Research Winamp playlist LIST OPTS button behavior, M3U/PLS format support, and existing MacAmp M3U parsing capabilities.

**Status:** Complete (2026-03-22)

---

## Existing Infrastructure (Already Wired)

The entire UI chain is already in place — only the 3 action method bodies need implementation:

| Component | File | Status |
|-----------|------|--------|
| LIST OPTS button | `Views/PlaylistWindow/PlaylistBottomControlsView.swift:77` | Wired to `menuPresenter.showListMenu()` |
| Popup menu | `Views/PlaylistWindow/PlaylistMenuPresenter.swift:160` | 3 sprite menu items (NEW, SAVE, LOAD) |
| Sprite definitions | `Models/SkinSprites.swift:356-361` | All 6 sprites defined (normal + selected) |
| Action stubs | `Views/PlaylistWindowActions.swift:226-236` | 3 `@objc` methods showing "Not supported yet" alerts |
| M3U Parser | `Models/M3UParser.swift` | Full read support (EXTINF, streams, relative paths) |
| M3U Loader | `PlaylistWindowActions.loadM3UPlaylist()` | Already handles local files + streams from M3U |
| Playlist API | `AudioPlayer` | `clearPlaylist()`, `replacePlaylist(with:)`, `addTrack(url:)`, `addStreamTrack()` |

## Winamp Classic Behavior (from webamp_clone)

| Operation | Behavior |
|-----------|----------|
| **NEW LIST** | Stops playback, clears entire playlist. No confirmation dialog. |
| **LOAD LIST** | Opens file dialog for `.m3u`/`.m3u8`/`.pls`. **Replaces** playlist (clears first, then loads). Does NOT append. |
| **SAVE LIST** | Opens save dialog, defaults to `.m3u`. Exports `#EXTM3U` format with `#EXTINF` metadata. |

Key insight from webamp: LOAD LIST **replaces** the playlist, not appends.

## What Needs to Be Built

1. **NEW LIST** — One-liner: `audioPlayer.clearPlaylist()`. No dialog in classic Winamp.
2. **LOAD LIST** — `NSOpenPanel` for `.m3u`/`.m3u8` → clear playlist → use existing `loadM3UPlaylist()`.
3. **SAVE LIST** — `NSSavePanel` for `.m3u` + new M3U writer function (~25 lines).

No M3U writer exists today. Writer generates `#EXTM3U` header + `#EXTINF:duration,title` + URL lines.
