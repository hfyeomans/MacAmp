# Internet Radio File Types - Current State

**Last Updated:** 2025-10-24
**Status:** 📋 Planned (Blocked by P5)

---

## Current Implementation Status

### ✅ COMPLETED - M3U File Support (Phases 1-4)

**What's Working:**

1. **File Type Recognition**
   - M3U/M3U8 files selectable in file picker
   - Uses `UTType.playlist` for broad compatibility
   - No greyed-out files in NSOpenPanel

2. **M3U Parser**
   - File: `MacAmpApp/Models/M3UParser.swift`
   - Parses #EXTM3U extended format
   - Extracts #EXTINF metadata (duration, title)
   - Handles multiple path types:
     - HTTP/HTTPS URLs (remote streams)
     - Absolute file paths (Unix)
     - Relative file paths (from M3U location)
     - Windows paths (basic conversion)

3. **M3U Entry Model**
   - File: `MacAmpApp/Models/M3UEntry.swift`
   - Properties: `url`, `title`, `duration`
   - Computed: `isRemoteStream` (HTTP/HTTPS detection)

4. **File Picker Integration**
   - File: `MacAmpApp/Views/WinampPlaylistWindow.swift`
   - Lines 471-495: `openFileDialog()` method
   - Accepts audio files AND playlists
   - Routes M3U files to `loadM3UPlaylist()`

### ⏸️ BLOCKED - Remote Stream Playback

**What's Pending:**

**Current Code (WinampPlaylistWindow.swift:503-506):**
```swift
if entry.isRemoteStream {
    // Log remote streams for now - will be handled by P5 (Internet Radio)
    print("M3U: Found stream: \(entry.title ?? entry.url.absoluteString)")
    // TODO: Add to internet radio library when P5 is implemented
}
```

**Current Behavior:**
- Remote streams are detected ✅
- Metadata is extracted ✅
- Streams are logged to console ✅
- **Streams are NOT added to playlist** ❌
- **Streams are NOT playable** ❌

**Example Output:**
```
M3U: Loaded 1 entries from DarkAmbientRadio.m3u
M3U: Found stream: Dark Ambient Radio
AudioPlayer: No track loaded to play.
```

---

## File Locations

### Existing Files (Completed)

```
MacAmpApp/
├── Models/
│   ├── M3UEntry.swift          ✅ Data model for M3U entries
│   └── M3UParser.swift         ✅ Parser with remote stream detection
└── Views/
    └── WinampPlaylistWindow.swift  ✅ Integration (TODO on line 506)
```

### Files to Create (P5 + This Task)

```
MacAmpApp/
├── Models/
│   └── RadioStation.swift      ⏸️ Radio station data model
├── Audio/
│   ├── InternetRadioPlayer.swift   ⏸️ P5 - Stream playback
│   └── RadioStationLibrary.swift   ⏸️ Station storage/management
└── Views/
    └── RadioStationView.swift      ⏸️ Optional UI for stations
```

---

## Dependencies

### Blocking This Task (Must Complete First)

**P5: Internet Radio Streaming**
- Location: `tasks/distribution-setup/internet-radio-streaming.md`
- Requirements:
  1. InternetRadioPlayer class (AVPlayer-based)
  2. RadioStation model
  3. RadioStationLibrary for persistence
  4. Basic UI for playing stations

**Info.plist Configuration**
- ✅ Already done: NSAppTransportSecurity with NSAllowsArbitraryLoadsInMedia
- Allows HTTP radio streams

**Entitlements**
- ✅ Already have: com.apple.security.network.client
- Supports all streaming protocols

### Dependent Tasks (Blocked By This)

None - this is an optional enhancement

---

## Test Files Available

**Location:** `/Users/hank/Downloads/`

**DarkAmbientRadio.m3u:**
```m3u
#EXTM3U
#EXTINF:-1,Dark Ambient Radio
http://streaming.radio.co/s8a3405e94/listen
```

**Additional Test Stations (SomaFM):**
- Groove Salad: http://ice1.somafm.com/groovesalad-256-mp3
- DEF CON Radio: http://ice1.somafm.com/defcon-128-mp3
- Secret Agent: http://ice1.somafm.com/secretagent-128-mp3

---

## Integration Points

### Current Code Hook (Ready for P5)

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`
**Line:** 503-506

**Placeholder:**
```swift
// TODO: Add to internet radio library when P5 is implemented
```

**Will Become:**
```swift
let station = RadioStation(
    name: entry.title ?? "Unknown Station",
    streamURL: entry.url,
    source: .m3uPlaylist(url)
)
radioLibrary.addStation(station)
```

---

## Technical Notes

### Parser Implementation Details

**M3UParser.resolveURL() Logic:**
1. Check for HTTP/HTTPS prefix → Remote stream
2. Check for absolute path (/) → Local file
3. Check for Windows path (C:\) → Convert and load
4. Default: Relative path from M3U location

**isRemoteStream Property:**
```swift
var isRemoteStream: Bool {
    let scheme = url.scheme?.lowercased()
    return scheme == "http" || scheme == "https"
}
```

### Thread Safety

**Current Issue:** None
**Future Consideration:** RadioStationLibrary should use @MainActor

---

## Next Steps (When P5 Ready)

1. **Review P5 Implementation**
   - Check InternetRadioPlayer API
   - Check RadioStationLibrary API
   - Ensure compatibility with M3UEntry data

2. **Update WinampPlaylistWindow.swift**
   - Replace TODO with actual integration
   - Add user feedback (toast/alert)
   - Handle errors gracefully

3. **Testing**
   - Load DarkAmbientRadio.m3u
   - Verify station added to library
   - Play stream through P5 player
   - Test mixed playlists (local + remote)

4. **Documentation**
   - Update this state.md
   - Document user workflow
   - Add to main README

---

## Git Status

**Branch:** `feature/m3u-file-support`
**Recent Commits:**
- `4e72a84` - M3U parser implementation (Phases 1-4)
- `e7b2b13` - Remove M3U from CFBundleDocumentTypes
- `e5a180c` - Use .playlist UTType for file picker

**Ready for:** Merge to main (M3U local files fully working)
**Waiting for:** P5 Internet Radio Streaming task

---

## Questions for P5 Implementation

1. **API Design:** How should M3U integration call RadioStationLibrary?
2. **User Feedback:** Toast notification when stations added?
3. **Duplicate Handling:** Check if stream URL already exists?
4. **Categorization:** Auto-categorize by M3U filename?
5. **Metadata Updates:** Refresh station info from stream?

---

**Status Summary:**
- ✅ M3U file parsing: Complete
- ✅ Remote stream detection: Complete
- ⏸️ Remote stream playback: Blocked by P5
- ⏸️ Station library integration: Blocked by P5
- 📋 Task documented and ready for P5
