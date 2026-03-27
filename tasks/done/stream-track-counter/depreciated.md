# Deprecated/Legacy Code: Stream Track Counter

> **Purpose:** Track any deprecated or legacy code removed during this task.

---

## Removed: AudioPlayer.addTrack() Auto-Play Side Effect

```swift
// BEFORE (removed from addTrack):
let shouldAutoplay = currentTrack == nil
playlistController.addPlaceholder(placeholder)
if shouldAutoplay {
    playTrack(track: placeholder)  // Bypassed PlaybackCoordinator entirely
}
```

**Why removed:** `playTrack()` called directly from `addTrack()` bypassed the coordinator. This meant `currentSource` was never set, `displayTime` returned 0, and coordinator-level pause/stop didn't affect the audio. All auto-play now routes through `PlaybackCoordinator.play(track:)`.

## Removed: PlaybackCoordinator.play(url:)

```swift
// BEFORE (removed):
func play(url: URL) async {
    if url.isFileURL {
        audioPlayer.addTrack(url: url)
        audioPlayer.play()
        currentSource = .localTrack(url)
        // ...
    } else {
        let station = RadioStation(name: url.lastPathComponent, streamURL: url)
        await streamPlayer.play(station: station)
        currentSource = .radioStation(station)
        // ...
    }
}
```

**Why removed:** Dead code — never called in production. All playback routes through `play(track:)` or `play(station:)`. Method didn't set `currentTrack`, causing stale playlist position display.

## Removed: ICY Metadata Elapsed Reset

```swift
// BEFORE (removed from StreamPlayer):
@ObservationIgnored private var lastNowPlayingIdentity: (String, String)?

// In metadata callback:
let identity = (title.trimmed.lowercased(), artist.trimmed.lowercased())
if isNewTrack {
    elapsedAccumulated = 0
    elapsedTime = 0
}
```

**Why removed:** Winamp classic does NOT reset `decode_pos_ms` on ICY metadata change. Timer counts continuously from Play until Stop. Verified from Winamp source code (in_mp3/DecodeThread.cpp, giofile.cpp).

## Replaced: Duplicated Auto-Play Logic (4 locations)

Previously duplicated auto-play pattern in:
- `presentAddFilesPanel()` — inline check
- `AppCommands.presentOpenPanel()` — inline check
- `loadList()` — inline check
- `loadM3UPlaylist()` — separate autoplay flag + inline check

**Replaced by:** Single `autoPlayFirstTrack(audioPlayer:coordinator:wasEmpty:)` method. All callers use this one method.

## Replaced: Fire-and-Forget M3U Loading

```swift
// BEFORE: loadM3UPlaylist was fire-and-forget (Task.detached, no await)
// Caused dual auto-play triggers when mixed M3U + plain files were selected
private func loadM3UPlaylist(...) {
    Task.detached { ... }  // Caller couldn't await this
}
```

**Replaced by:** `parseAndAddM3U()` which is awaitable. `handleSelectedURLs()` is now async and awaits M3U parsing inline, so the caller's auto-play check runs after ALL files are added.
