# Docs Update Needed: Playlist List Operations

> **Purpose:** Track documentation updates needed for this task's architectural changes.
> **When:** During next docs sweep or before a release.

---

## MACAMP_ARCHITECTURE_GUIDE.md

### Playlist Management Section

Document the three LIST OPTS operations and their Winamp-faithful behavior:
- **NEW LIST:** `audioPlayer.clearPlaylist()` — no confirmation dialog (Winamp behavior)
- **LOAD LIST:** Replaces playlist (clears first, then loads) — NOT append (Winamp behavior)
- **SAVE LIST:** Exports `#EXTM3U` format via `M3UWriter`

### File Structure

Add M3UWriter to the Models section — co-located with M3UParser in `M3UParser.swift`.

## IMPLEMENTATION_PATTERNS.md

### New Pattern: Playlist Generation Token (Stale Task Guard)

```swift
// AudioPlayer.swift
@ObservationIgnored private var playlistGeneration: UInt64 = 0

func clearPlaylist() {
    playlistGeneration &+= 1  // Invalidate in-flight metadata tasks
    playlistController.clear()
}

func addTrack(url: URL) {
    let generation = playlistGeneration
    Task { @MainActor in
        let metadata = await MetadataLoader.loadTrackMetadata(from: url)
        // Reject if playlist was cleared/replaced while loading
        guard self.playlistGeneration == generation else { return }
        // ... add track
    }
}
```

**Why:** `clearPlaylist()` clears state synchronously, but in-flight `Task` blocks from `addTrack()` can complete after the clear and re-add tracks. The generation token lets the task detect that the playlist changed and discard stale results.

**Where used:** `clearPlaylist()`, `replacePlaylist(with:)`, `eject()` all increment generation.

### New Pattern: Background File I/O from Panel Callbacks

```swift
// NSSavePanel/NSOpenPanel callbacks dispatch to main actor by default.
// Move file I/O off main actor to avoid blocking UI.
savePanel.begin { response in
    if response == .OK, let url = savePanel.url {
        let tracks = audioPlayer.playlist  // Capture on main
        Task.detached(priority: .userInitiated) {
            try M3UWriter.write(tracks: tracks, to: url)  // Off main
        }
    }
}
```

### Lesson: UTType.playlist Doesn't Match .m3u

`UTType.playlist` is a system type that does NOT conform to `.m3u`/`.m3u8` dynamic types on macOS. Always use explicit `UTType(filenameExtension: "m3u")` for M3U file dialogs. This affects both `NSOpenPanel.allowedContentTypes` and `NSSavePanel.allowedContentTypes`.

## PLAYLIST_WINDOW.md

### LIST OPTS Section

Add documentation for the LIST OPTS button behavior:
- Button location: bottom-right of playlist window
- Menu: 3 sprite items (NEW LIST, SAVE LIST, LOAD LIST)
- Sprite definitions: `PLAYLIST_NEW_LIST`, `PLAYLIST_SAVE_LIST`, `PLAYLIST_LOAD_LIST` (+ `_SELECTED` variants)
- Action methods: `PlaylistWindowActions.newList(_:)`, `.saveList(_:)`, `.loadList(_:)`

### M3U Export Format

```
#EXTM3U
#EXTINF:234,Artist - Title
/path/to/file.mp3
#EXTINF:-1,Station Name
http://stream.example.com/radio
```

- Duration: seconds for local files, `-1` for streams
- Title: `Artist - Title` if artist available, else just title
- Path: absolute filesystem path for local files, full URL for streams
