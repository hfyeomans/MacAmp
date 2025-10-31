# Phase 4: Playlist Integration - Implementation Checklist

**Date:** 2025-10-31
**Status:** Planning Complete - Ready for Oracle Review
**Estimated Effort:** 3-4 hours (3-4 commits)

---

## Commit 8: Extend Track Model for Stream URLs

### Files to Modify
- [x] `MacAmpApp/Audio/AudioPlayer.swift`

### Changes
- [ ] Add `isStream` computed property to Track struct
  ```swift
  var isStream: Bool {
      !url.isFileURL && (url.scheme == "http" || url.scheme == "https")
  }
  ```
- [ ] Add documentation for stream support
- [ ] No other Track changes needed (URL already supports any scheme)

### Testing
- [ ] Build succeeds
- [ ] No regressions in existing code
- [ ] isStream returns correct value for test URLs

**Effort:** 15 minutes

---

## Commit 9: M3U Loading & ADD URL to Playlist

### Files to Modify
- [x] `MacAmpApp/Views/WinampPlaylistWindow.swift`

### Changes to loadM3UPlaylist()
- [ ] When `entry.isRemoteStream`:
  - [ ] Add to RadioStationLibrary (existing - keep for favorites)
  - [ ] Create Track with stream URL:
    ```swift
    let streamTrack = Track(
        url: entry.url,
        title: entry.title ?? "Unknown Station",
        artist: "Internet Radio",
        duration: 0.0
    )
    ```
  - [ ] Append to `audioPlayer.playlist`
- [ ] Update user feedback to mention playlist

### Changes to addURL()
- [ ] Keep RadioStationLibrary.addStation() (for favorites)
- [ ] ALSO create Track and add to playlist
- [ ] Update alert message: "Added to playlist. Click to play!"

### Testing
- [ ] Load M3U with 2 local + 2 remote → See all 4 in playlist UI
- [ ] ADD URL → Stream appears in playlist
- [ ] Streams have duration = 0.0
- [ ] No position slider for streams

**Effort:** 30-45 minutes

---

## Commit 10: Wire Playlist Selection to PlaybackCoordinator

### Files to Modify
- [x] `MacAmpApp/MacAmpApp.swift`
- [x] `MacAmpApp/Views/WinampPlaylistWindow.swift`

### Changes to MacAmpApp.swift
- [ ] Create StreamPlayer instance: `@State private var streamPlayer = StreamPlayer()`
- [ ] Create PlaybackCoordinator:
  ```swift
  var playbackCoordinator: PlaybackCoordinator {
      PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)
  }
  ```
- [ ] Inject via environment: `.environment(playbackCoordinator)`

### Changes to WinampPlaylistWindow.swift
- [ ] Add: `@Environment(PlaybackCoordinator.self) var playbackCoordinator`
- [ ] Find playlist item click handler
- [ ] Create new playback method:
  ```swift
  private func playTrack(_ track: Track) async {
      if track.isStream {
          await playbackCoordinator.play(url: track.url)
          // Metadata will update from streamPlayer
      } else {
          audioPlayer.playTrack(track: track)
      }
  }
  ```
- [ ] Replace direct `audioPlayer.playTrack()` calls

### Testing
- [ ] Click local file → Plays via AudioPlayer (EQ works)
- [ ] Click stream → Plays via StreamPlayer
- [ ] Verify no audio conflicts
- [ ] Switch between local and stream
- [ ] Pause/stop works for both types

**Effort:** 1-1.5 hours

---

## Commit 11 (Optional): Buffering Status Display

### Files to Modify
- [x] `MacAmpApp/Audio/PlaybackCoordinator.swift`
- [x] `MacAmpApp/Views/WinampMainWindow.swift`

### Changes to PlaybackCoordinator
- [ ] Add computed property:
  ```swift
  var displayTitle: String {
      switch currentSource {
      case .radioStation:
          if streamPlayer.isBuffering {
              return "Connecting..."
          }
          if streamPlayer.error != nil {
              return "buffer 0%"
          }
          return streamPlayer.streamTitle ?? currentTitle ?? "Internet Radio"
      case .localTrack:
          return currentTitle ?? "Unknown"
      case .none:
          return "MacAmp"
      }
  }
  ```

### Changes to WinampMainWindow.swift
- [ ] Find: `audioPlayer.currentTitle` in buildTrackInfoDisplay()
- [ ] Replace with: `playbackCoordinator.displayTitle`
- [ ] Ensure scrolling still works

### Testing
- [ ] Play stream → Shows "Connecting..." briefly
- [ ] Stream starts → Shows station name
- [ ] Metadata updates → Shows song title
- [ ] Network issue → Shows "buffer 0%"
- [ ] Local file → Shows track title (no change)

**Effort:** 30-45 minutes

---

## Phase 4 Completion Criteria

### Functional
- [ ] Streams visible in playlist UI
- [ ] Click stream in playlist → plays audio
- [ ] M3U shows local + remote items together
- [ ] ADD URL adds to playlist (visible immediately)
- [ ] Stream metadata updates in real-time
- [ ] Buffering status displays (optional)

### Winamp Parity
- [ ] Streams are playlist items (not separate)
- [ ] Mixed playlists work correctly
- [ ] Behavior matches Winamp description

### Technical
- [ ] All builds succeed
- [ ] No force unwraps added
- [ ] Swift 6 compliant
- [ ] Observable state works
- [ ] No audio conflicts

---

## Testing Checklist

### Build Tests
- [ ] After Commit 8: Build succeeds
- [ ] After Commit 9: Build succeeds
- [ ] After Commit 10: Build succeeds
- [ ] After Commit 11: Build succeeds

### Functional Tests
- [ ] Load DarkAmbientRadio.m3u → All items in playlist
- [ ] Click stream item → Plays audio
- [ ] Click local item → Plays with EQ
- [ ] ADD URL → Appears in playlist
- [ ] Stream metadata updates live
- [ ] Buffering message shows
- [ ] Switch local ↔ stream smoothly

### Regression Tests
- [ ] Local file playback unchanged
- [ ] EQ still works for local files
- [ ] Playlist add/remove/reorder works
- [ ] M3U with only local files works

---

## Oracle Review Questions

**Awaiting Oracle guidance on:**

1. **Track Extension:** Is simple URL extension approach OK? Or need enum?
2. **Buffering Display:** Confirmed trivial (just string)? Include or defer?
3. **Storage Strategy:** Keep RadioStationLibrary for favorites? Or remove?
4. **Effort Estimate:** 3-4 hours realistic for Phase 4?
5. **Wiring Pattern:** Environment injection for PlaybackCoordinator?

**Status:** Awaiting Oracle response before starting implementation

---

**Phase 4 Ready:** Plan complete, checklist prepared
**Next:** Oracle review → Implement → Test → PR
