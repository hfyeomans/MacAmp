# Internet Radio Architecture

## Overview

MacAmp supports internet radio streaming alongside local file playback using a dual-backend architecture.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PlaybackCoordinator                       │
│  (Prevents simultaneous playback, unified API for UI)       │
└────────────────────┬───────────────────┬────────────────────┘
                     │                   │
         ┌───────────▼──────────┐   ┌───▼──────────────────┐
         │    AudioPlayer       │   │   StreamPlayer       │
         │  (AVAudioEngine)     │   │   (AVPlayer)         │
         │                      │   │                      │
         │  ✓ 10-band EQ        │   │  ✓ HTTP/HTTPS       │
         │  ✓ Local files       │   │  ✓ HLS (.m3u8)      │
         │  ✓ Precise control   │   │  ✓ ICY metadata     │
         │  ✗ No streaming      │   │  ✗ No EQ            │
         └──────────────────────┘   └─────────────────────┘
```

## Components

### 1. RadioStation (Model)
- Represents a radio station
- Properties: name, streamURL, genre, source
- Source types: `.m3uPlaylist`, `.manual`, `.directory`
- Codable for persistence

### 2. RadioStationLibrary (Model)
- Manages saved radio stations
- UserDefaults persistence
- Automatic duplicate detection by URL
- Observable for SwiftUI reactivity

### 3. StreamPlayer (Audio Backend)
- AVPlayer-based streaming
- KVO observers for:
  - Playback status (playing/paused/buffering)
  - Stream metadata (title/artist)
  - Error detection
- RunLoop.main integration for @MainActor compatibility

### 4. PlaybackCoordinator (Orchestration)
- **CRITICAL**: Prevents AudioPlayer and StreamPlayer from playing simultaneously
- Unified API: `play(url:)`, `play(station:)`, `pause()`, `stop()`
- State management: `isPlaying`, `isPaused`, `currentSource`
- Metadata queries: `streamTitle`, `streamArtist`, `isBuffering`, `error`

## Data Flow

### Loading Stations from M3U/M3U8
```
1. User opens M3U/M3U8 file
2. M3UParser.parse() extracts entries
3. For each entry:
   - If isRemoteStream → Add to RadioStationLibrary
   - If local file → Add to AudioPlayer playlist
4. User sees notification: "Added X radio stations"
5. Stations persist in UserDefaults
```

### Manual URL Entry
```
1. User clicks ADD → ADD URL
2. NSAlert prompts for URL
3. Validate http:// or https://
4. Create RadioStation with .manual source
5. Add to RadioStationLibrary
6. Station persists immediately
```

### Playback
```
1. User selects station (future: from menu/UI)
2. Call: await coordinator.play(station: station)
3. PlaybackCoordinator:
   - Stops AudioPlayer if playing
   - Calls StreamPlayer.play(station:)
   - Updates currentSource = .radioStation
4. StreamPlayer:
   - Creates AVPlayerItem
   - Sets up metadata observers
   - Calls player.play()
5. UI observes:
   - coordinator.streamTitle (live metadata)
   - coordinator.isBuffering (network state)
   - coordinator.error (if fails)
```

## File Organization

```
MacAmpApp/
├── Audio/
│   ├── AudioPlayer.swift           # Local files with EQ
│   ├── StreamPlayer.swift          # Internet radio
│   └── PlaybackCoordinator.swift   # Orchestration
├── Models/
│   ├── RadioStation.swift          # Station data model
│   ├── RadioStationLibrary.swift   # Station persistence
│   └── M3UParser.swift             # Existing M3U parser
└── Views/
    └── WinampPlaylistWindow.swift  # M3U loading, ADD URL
```

## Supported Formats

### Stream URLs
- **Direct Streams**: `http://stream.example.com/radio.mp3`
- **HLS Streams**: `http://stream.example.com/playlist.m3u8`
- **SHOUTcast/Icecast**: Automatic ICY metadata extraction

### Playlist Files
- **.m3u**: Standard M3U playlists
- **.m3u8**: UTF-8 encoded M3U (also HLS playlists)
- **Mixed**: Can contain both local files and remote streams

## Metadata

### ICY Metadata (SHOUTcast/Icecast)
- Extracted via `AVPlayerItem.timedMetadata`
- Updates in real-time as songs change
- Available in `streamTitle` and `streamArtist`

### Common Metadata Keys
- `.commonKeyTitle` → Song title
- `.commonKeyArtist` → Artist name
- Falls back to station name if not available

## Error Handling

### Network Errors
- Detected via `AVPlayerItem.status == .failed`
- Exposed in `StreamPlayer.error`
- UI can display error messages

### Invalid URLs
- Validated before creating RadioStation
- Must be `http://` or `https://`
- User shown error alert

### Buffer Stalls
- Detected via `AVPlayer.timeControlStatus == .waitingToPlayAtSpecifiedRate`
- Exposed in `isBuffering` state
- UI can show buffering indicator

## Future Enhancements

### Planned (Phase 3 - Not Yet Implemented)
- [ ] Radio stations menu/picker UI
- [ ] Stream metadata display in main window
- [ ] Buffering indicator in visualizer area
- [ ] Station management UI (edit/delete)
- [ ] Export station library as M3U
- [ ] Station categories/genres
- [ ] Search/browse radio directory

### Possible (Future)
- [ ] EQ for streams (via MTAudioProcessingTap - complex)
- [ ] Favorite/rating system
- [ ] Recently played stations
- [ ] Auto-reconnect on network failure
- [ ] Stream quality selection

## Oracle Review Notes

✅ **Approved Architecture**
- Dual backend approach is correct (AVAudioEngine can't stream HTTP)
- PlaybackCoordinator prevents audio conflicts
- Observer cleanup follows Swift 6 best practices

⚠️ **Oracle Corrections Applied**
- Use `RunLoop.main` not `DispatchQueue.main` for @MainActor
- Use `item.commonKey` and `item.stringValue` for metadata
- Cancel observers before creating new ones
- Removed deinit (Combine cancellables auto-cleanup)

## Testing

### Manual Testing
1. Load `.m3u` with internet radio URLs → Stations added to library
2. Load `.m3u8` playlist → Stations added
3. ADD → ADD URL → Enter stream URL → Station added
4. Test with real streams:
   - `http://ice1.somafm.com/groovesalad-256-mp3` (SomaFM)
   - `http://stream.radioparadise.com/mp3-192` (Radio Paradise)
5. Verify persistence: Quit app, relaunch, check library

### Expected Behavior
- ✅ Stations persist across restarts
- ✅ Duplicate URLs rejected
- ✅ Mixed M3U (local + remote) works
- ✅ User feedback on success
- ✅ Validation errors shown clearly

## Implementation Status

**Phase 1: Core Streaming** ✅ Complete
- StreamPlayer with AVPlayer backend
- RadioStation and RadioStationLibrary models
- PlaybackCoordinator orchestration

**Phase 2: M3U/M3U8 Integration** ✅ Complete
- M3U/M3U8 remote stream loading
- RadioStationLibrary injection
- Persistence via UserDefaults

**Phase 3: UI** ✅ Basic Complete
- ADD URL dialog functional
- User feedback on actions
- Full UI integration pending (future work)

---

**Task:** tasks/internet-radio/
**Commits:** 7 commits (1-7)
**Oracle Reviewed:** ✅ Architecture validated
**Ready for:** User testing and UI integration
