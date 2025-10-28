# Internet Radio File Types - M3U Remote Stream Integration

**Task ID:** `internet-radio-file-types`
**Priority:** P5 (Part of Internet Radio Streaming)
**Status:** 📋 Planned - Blocked by P5 Internet Radio Player
**Estimated Time:** 2-3 hours
**Dependencies:** P5 Internet Radio Streaming task

---

## Problem Statement

M3U playlist files can contain **remote stream URLs** (internet radio stations), but the current implementation only handles **local audio files**.

### Current Behavior

**What Works ✅:**
- M3U file selection in file picker
- M3U parsing with metadata extraction
- Loading local MP3/audio files from M3U playlists

**What's Missing ❌:**
- Playing remote streams (HTTP/HTTPS URLs) from M3U files
- Adding internet radio stations to a station library
- Buffering and streaming audio from URLs

### Example M3U File (Dark Ambient Radio)

```m3u
#EXTM3U
#EXTINF:-1,Dark Ambient Radio
http://streaming.radio.co/s8a3405e94/listen
```

**Current Log Output:**
```
M3U: Loaded 1 entries from DarkAmbientRadio.m3u
M3U: Found stream: Dark Ambient Radio
AudioPlayer: No track loaded to play.
```

**Issue:** The stream is detected but skipped (line 503-506 in WinampPlaylistWindow.swift)

---

## Solution Overview

### Phase 1-4: M3U File Support (COMPLETED ✅)

**Implemented:**
- M3U file type recognition (UTType.playlist)
- M3U/M3U8 parser with EXTINF metadata
- Local file path resolution (absolute, relative, Windows)
- Remote stream URL detection (`entry.isRemoteStream`)

**Code Locations:**
- `MacAmpApp/Models/M3UEntry.swift` - Data model
- `MacAmpApp/Models/M3UParser.swift` - Parsing logic
- `MacAmpApp/Views/WinampPlaylistWindow.swift` - File picker integration

### Phase 5: Internet Radio Integration (TO DO ⏸️)

**Requires:** P5 Internet Radio Player implementation

**Integration Steps:**

1. **Create Internet Radio Player** (P5)
   - AVPlayer-based streaming
   - HTTP/HTTPS stream support
   - Buffering and metadata handling
   - See: `tasks/distribution-setup/internet-radio-streaming.md`

2. **Create Radio Station Library** (P5)
   - Store favorite stations
   - Organize by genre/category
   - Persist to UserDefaults or file

3. **Update M3U Loading Logic** (THIS TASK)
   - Detect remote streams from M3U
   - Add stations to radio library
   - Enable playback through Internet Radio Player

4. **UI Integration**
   - Add "Radio Stations" view/section
   - Display loaded stations from M3U
   - Play button for each station

---

## Technical Details

### Current Code (WinampPlaylistWindow.swift:497-521)

```swift
private func loadM3UPlaylist(_ url: URL) {
    do {
        let entries = try M3UParser.parse(fileURL: url)
        print("M3U: Loaded \(entries.count) entries from \(url.lastPathComponent)")

        for entry in entries {
            if entry.isRemoteStream {
                // ⏸️ BLOCKED: Needs P5 Internet Radio Player
                print("M3U: Found stream: \(entry.title ?? entry.url.absoluteString)")
                // TODO: Add to internet radio library when P5 is implemented
            } else {
                // ✅ WORKS: Local files
                audioPlayer.addTrack(url: entry.url)
            }
        }
    } catch {
        // Error handling...
    }
}
```

### Proposed Code (After P5)

```swift
private func loadM3UPlaylist(_ url: URL) {
    do {
        let entries = try M3UParser.parse(fileURL: url)
        print("M3U: Loaded \(entries.count) entries from \(url.lastPathComponent)")

        for entry in entries {
            if entry.isRemoteStream {
                // ✅ NEW: Add to radio station library
                let station = RadioStation(
                    name: entry.title ?? "Unknown Station",
                    streamURL: entry.url,
                    source: .m3uPlaylist(url)
                )
                radioLibrary.addStation(station)
                print("M3U: Added station: \(station.name)")
            } else {
                // ✅ EXISTING: Local files
                audioPlayer.addTrack(url: entry.url)
            }
        }
    } catch {
        // Error handling...
    }
}
```

---

## Implementation Plan

### Prerequisites (P5 - Internet Radio Streaming)

**Must be completed first:**

1. ✅ ATS configuration in Info.plist (already done)
2. ⏸️ Create `InternetRadioPlayer` class
3. ⏸️ Create `RadioStation` model
4. ⏸️ Create `RadioStationLibrary` for persistence
5. ⏸️ UI for browsing/playing stations

**Reference:** `tasks/distribution-setup/internet-radio-streaming.md`

### This Task (internet-radio-file-types)

**Once P5 is complete:**

1. **Update WinampPlaylistWindow.swift**
   - Replace TODO comment with actual implementation
   - Add stations to RadioStationLibrary
   - Show user feedback when stations are added

2. **Create RadioStation Model**
   ```swift
   struct RadioStation: Identifiable {
       let id = UUID()
       let name: String
       let streamURL: URL
       let genre: String?
       let source: Source

       enum Source {
           case m3uPlaylist(URL)
           case manual
           case directory
       }
   }
   ```

3. **Create RadioStationLibrary**
   ```swift
   class RadioStationLibrary: ObservableObject {
       @Published var stations: [RadioStation] = []

       func addStation(_ station: RadioStation) {
           stations.append(station)
           saveToUserDefaults()
       }

       func removeStation(_ id: UUID) { ... }
       func saveToUserDefaults() { ... }
       func loadFromUserDefaults() { ... }
   }
   ```

4. **Testing**
   - Test with DarkAmbientRadio.m3u
   - Test with SomaFM M3U files
   - Test with mixed playlists (local + remote)

---

## Files to Create

1. `MacAmpApp/Models/RadioStation.swift`
2. `MacAmpApp/Audio/RadioStationLibrary.swift`
3. `MacAmpApp/Views/RadioStationView.swift` (optional)

## Files to Modify

1. `MacAmpApp/Views/WinampPlaylistWindow.swift`
   - Line 503-506: Replace TODO with actual implementation
   - Line 8-17: Implement `PlaylistWindowActions.addURL()` with URL input dialog
     - Currently shows placeholder: "URL/Internet Radio support coming in P5"
     - Need NSAlert with text input field for stream URL
     - Validate URL format
     - Add to RadioStationLibrary and playlist

---

## Success Criteria

**Must Have:**
- [ ] M3U remote streams detected and parsed ✅ (DONE)
- [ ] Remote streams added to RadioStationLibrary
- [ ] Stations playable through InternetRadioPlayer
- [ ] User can load M3U files with radio stations
- [ ] Mixed M3U files work (local files + remote streams)

**Should Have:**
- [ ] Station metadata preserved (title from EXTINF)
- [ ] Source tracking (which M3U file added the station)
- [ ] Duplicate detection (same stream URL)

**Nice to Have:**
- [ ] Auto-categorization by M3U filename
- [ ] Export radio library as M3U
- [ ] Update station metadata from stream

---

## Testing Files

**Test M3U files available:**
- `/Users/hank/Downloads/DarkAmbientRadio.m3u` (1 remote stream)
- Can create more test files from SomaFM directory

**SomaFM Test Stations:**
```m3u
#EXTM3U
#EXTINF:-1,SomaFM: Groove Salad
http://ice1.somafm.com/groovesalad-256-mp3
#EXTINF:-1,SomaFM: DEF CON Radio
http://ice1.somafm.com/defcon-128-mp3
#EXTINF:-1,SomaFM: Secret Agent
http://ice1.somafm.com/secretagent-128-mp3
```

---

## Dependencies

**Blocking This Task:**
- P5: Internet Radio Streaming (must be implemented first)
- InternetRadioPlayer class
- RadioStationLibrary class

**Blocked By This Task:**
- None (optional feature)

**Enables:**
- Easy radio station discovery via M3U files
- Importing station lists from internet
- Sharing station lists between users

---

## Timeline

**P5 Completion:** TBD
**This Task:** 2-3 hours after P5
**Total Time:** Part of P5 sprint

---

## Notes

- M3U parsing infrastructure is **ready** ✅
- Remote stream detection is **working** ✅
- Only integration with P5 player remains
- No breaking changes to existing code
- Backward compatible with local-only M3U files

**Status:** Ready to implement when P5 Internet Radio Player is available.

---

**Created:** 2025-10-24
**Last Updated:** 2025-10-24
**Author:** Claude Code
**Related Tasks:** P5 Internet Radio Streaming
