# M3U File Support Implementation Plan

## Goal

Enable MacAmp to open and parse M3U/M3U8 playlist files for both local track lists and internet radio streams.

---

## Phase 1: Fix File Selection (Critical) ⚡

**Priority:** P0 (Blocker)
**Time:** 30 minutes
**Files:** 1 file

### Tasks

#### 1.1 Update NSOpenPanel Configuration
**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

**Current Code:**
```swift
private func openFileDialog() {
    let openPanel = NSOpenPanel()
    openPanel.allowedContentTypes = [.audio]  // ❌ Problem
    // ...
}
```

**Change To:**
```swift
private func openFileDialog() {
    let openPanel = NSOpenPanel()
    openPanel.allowedContentTypes = [.audio, .m3uPlaylist]  // ✅ Solution
    // ...
}
```

**Testing:**
- [ ] Build and run app
- [ ] Open file dialog
- [ ] Verify M3U files are no longer grayed out
- [ ] Verify M3U files are selectable

---

## Phase 2: Add UTI Import Declaration (Recommended) 📋

**Priority:** P1 (High)
**Time:** 15 minutes
**Files:** 1 file

### Tasks

#### 2.1 Add UTImportedTypeDeclarations
**File:** `MacAmpApp/Info.plist`

**Add Before CFBundleDocumentTypes:**
```xml
<key>UTImportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeIdentifier</key>
        <string>public.m3u-playlist</string>
        <key>UTTypeDescription</key>
        <string>M3U Playlist</string>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.text</string>
            <string>public.playlist</string>
        </array>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>m3u</string>
                <string>m3u8</string>
            </array>
            <key>public.mime-type</key>
            <array>
                <string>audio/x-mpegurl</string>
                <string>audio/mpegurl</string>
            </array>
        </dict>
    </dict>
</array>
```

**Testing:**
- [ ] Clean build folder
- [ ] Rebuild app
- [ ] Verify system recognizes M3U files for MacAmp
- [ ] Check Finder "Open With" shows MacAmp for .m3u files

---

## Phase 3: Implement M3U Parser (Core Feature) 🔧

**Priority:** P1 (High)
**Time:** 2-3 hours
**Files:** 2-3 new files

### Tasks

#### 3.1 Create M3UEntry Model
**File:** `MacAmpApp/Models/M3UEntry.swift` (new)

```swift
import Foundation

struct M3UEntry {
    let url: URL
    let title: String?
    let duration: Int?  // -1 for live streams, seconds for tracks
    let isRemoteStream: Bool

    init(url: URL, title: String? = nil, duration: Int? = nil) {
        self.url = url
        self.title = title
        self.duration = duration
        self.isRemoteStream = url.scheme == "http" || url.scheme == "https"
    }
}
```

#### 3.2 Create M3UParser
**File:** `MacAmpApp/Parsers/M3UParser.swift` (new)

**Methods:**
- `static func parse(fileURL: URL) throws -> [M3UEntry]`
- `static func parse(content: String) -> [M3UEntry]`
- `private static func parseLine(_ line: String) -> M3UEntry?`

**Error Handling:**
- Invalid file encoding
- Malformed EXTINF lines
- Invalid URLs
- Empty playlists

#### 3.3 Handle Relative Paths
**Consideration:** M3U files may contain relative paths

```swift
func resolveURL(_ urlString: String, relativeTo baseURL: URL) -> URL? {
    // If it's already a full URL, use it
    if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
        return URL(string: urlString)
    }

    // If it's an absolute file path
    if urlString.hasPrefix("/") {
        return URL(fileURLWithPath: urlString)
    }

    // Relative path - resolve from M3U location
    let baseDir = baseURL.deletingLastPathComponent()
    return URL(fileURLWithPath: urlString, relativeTo: baseDir)
}
```

**Testing:**
- [ ] Parse simple M3U (no metadata)
- [ ] Parse extended M3U (#EXTM3U with #EXTINF)
- [ ] Parse internet radio M3U (URLs)
- [ ] Handle relative paths correctly
- [ ] Handle absolute paths
- [ ] Handle Windows paths (C:\ format)
- [ ] Handle UTF-8 encoding (M3U8)

---

## Phase 4: Integrate M3U Loading (Integration) 🔗

**Priority:** P1 (High)
**Time:** 1-2 hours
**Files:** 2 files

### Tasks

#### 4.1 Update PlaylistWindow File Handling
**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

**Add M3U Detection:**
```swift
private func openFileDialog() {
    let openPanel = NSOpenPanel()
    openPanel.allowedContentTypes = [.audio, .m3uPlaylist]
    openPanel.allowsMultipleSelection = true

    if openPanel.runModal() == .OK {
        for url in openPanel.urls {
            if url.pathExtension.lowercased() == "m3u" ||
               url.pathExtension.lowercased() == "m3u8" {
                loadM3UPlaylist(url)
            } else {
                // Existing audio file handling
                appState.addTrack(url: url)
            }
        }
    }
}

private func loadM3UPlaylist(_ url: URL) {
    do {
        let entries = try M3UParser.parse(fileURL: url)
        for entry in entries {
            if entry.isRemoteStream {
                // Add to radio stations (future P5 feature)
                print("Radio stream: \(entry.title ?? entry.url.absoluteString)")
            } else {
                // Add local track
                appState.addTrack(url: entry.url)
            }
        }
    } catch {
        // Show error dialog
        print("Failed to parse M3U: \(error)")
    }
}
```

#### 4.2 Update AudioPlayer
**File:** `MacAmpApp/Audio/AudioPlayer.swift`

**Add URL Type Detection:**
```swift
func loadTrack(url: URL) {
    if url.scheme == "http" || url.scheme == "https" {
        // Internet stream - use AVPlayer directly
        loadInternetStream(url)
    } else {
        // Local file - existing logic
        loadLocalFile(url)
    }
}

private func loadInternetStream(_ url: URL) {
    // For Phase 5 (Internet Radio Streaming)
    // For now, just print
    print("Stream URL: \(url)")
}
```

**Testing:**
- [ ] Load M3U with local files
- [ ] Files added to playlist correctly
- [ ] Playback works for loaded tracks
- [ ] Relative paths resolve correctly
- [ ] Internet radio URLs detected (logged, not played yet)

---

## Phase 5: Connect to Internet Radio (Future) 🌐

**Priority:** P5 (Linked to existing P5 task)
**Time:** Handled by P5: Internet Radio Streaming
**Dependencies:** Requires P5 implementation

### Tasks

**This phase connects to existing P5 task: Internet Radio Streaming**

#### 5.1 Radio Station Management
- Extract internet radio URLs from M3U
- Store in RadioStationLibrary
- Display in UI (station browser)

#### 5.2 Stream Playback
- Use InternetRadioPlayer (from P5)
- Handle buffering
- Display "Now Playing" info

**Integration Point:**
```swift
// In loadM3UPlaylist():
if entry.isRemoteStream {
    // Add to radio station library
    RadioStationLibrary.shared.addStation(
        name: entry.title ?? "Unknown Station",
        streamURL: entry.url
    )
}
```

**Note:** This will be implemented as part of P5: Internet Radio Streaming task.

---

## Phase 6: M3U Export/Save (Optional) 💾

**Priority:** P3 (Nice to Have)
**Time:** 1-2 hours
**Files:** 1-2 files

### Tasks

#### 6.1 Implement M3U Writer
**File:** `MacAmpApp/Parsers/M3UWriter.swift` (new)

**Methods:**
- `static func write(entries: [M3UEntry], to url: URL) throws`
- `static func generate(entries: [M3UEntry]) -> String`

**Format:**
```swift
func generate(entries: [M3UEntry]) -> String {
    var output = "#EXTM3U\n"

    for entry in entries {
        if let title = entry.title, let duration = entry.duration {
            output += "#EXTINF:\(duration),\(title)\n"
        }
        output += "\(entry.url.absoluteString)\n"
    }

    return output
}
```

#### 6.2 Add Save Playlist Menu
**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

**Add Menu Item:**
- File → Save Playlist...
- NSSavePanel with .m3u extension
- Convert current playlist to M3U format
- Write to selected location

**Testing:**
- [ ] Save playlist with local files
- [ ] Save playlist with internet streams
- [ ] Reload saved playlist
- [ ] Verify metadata preserved

---

## Testing Plan

### Unit Tests

**File:** `MacAmpAppTests/M3UParserTests.swift` (new)

**Test Cases:**
- [ ] Parse simple M3U (no metadata)
- [ ] Parse extended M3U with #EXTINF
- [ ] Parse internet radio M3U
- [ ] Handle empty playlist
- [ ] Handle comments (#)
- [ ] Handle Windows line endings (\r\n)
- [ ] Handle UTF-8 characters (M3U8)
- [ ] Handle malformed EXTINF lines
- [ ] Handle invalid URLs
- [ ] Resolve relative paths

### Integration Tests

**Manual Testing:**
- [ ] Open M3U with local files → Adds to playlist
- [ ] Open M3U with URLs → Detects as streams
- [ ] Open M3U8 (UTF-8) → Handles encoding
- [ ] Open empty M3U → Shows appropriate message
- [ ] Open corrupted M3U → Shows error dialog
- [ ] Double-click M3U in Finder → Opens in MacAmp
- [ ] Drag-drop M3U to MacAmp → Loads playlist

### Test Data

Create test M3U files:

**`test-local.m3u`:**
```m3u
../Music/song1.mp3
/Users/test/Music/song2.mp3
```

**`test-extended.m3u`:**
```m3u
#EXTM3U
#EXTINF:211,Artist - Title 1
song1.mp3
#EXTINF:321,Artist - Title 2
song2.mp3
```

**`test-radio.m3u`:**
```m3u
#EXTM3U
#EXTINF:-1,SomaFM: Groove Salad
http://ice1.somafm.com/groovesalad-256-mp3
#EXTINF:-1,Radio Paradise
http://stream.radioparadise.com/mp3-192
```

---

## File Structure

```
MacAmpApp/
├── Models/
│   └── M3UEntry.swift (new)
├── Parsers/
│   ├── M3UParser.swift (new)
│   └── M3UWriter.swift (new, optional)
├── Views/
│   └── WinampPlaylistWindow.swift (modify)
├── Audio/
│   └── AudioPlayer.swift (modify)
└── Info.plist (modify)

MacAmpAppTests/
└── M3UParserTests.swift (new)
```

---

## Implementation Order

1. **Phase 1** (30 min) - Fix NSOpenPanel ⚡
   - Users can immediately select M3U files
   - Quick win, unblocks testing

2. **Phase 2** (15 min) - Add UTI declaration 📋
   - Robust system integration
   - Finder integration

3. **Phase 3** (2-3 hours) - Implement parser 🔧
   - Core functionality
   - Handle all M3U formats

4. **Phase 4** (1-2 hours) - Integrate loading 🔗
   - End-to-end functionality
   - Local playlists work

5. **Phase 6** (optional) - Export/Save 💾
   - User can create playlists
   - Full Winamp parity

6. **Phase 5** (future) - Internet radio 🌐
   - Part of P5 task
   - Stream playback

---

## Success Criteria

**Minimum Viable (Phases 1-4):**
- [x] M3U files are selectable in file dialogs
- [ ] M3U files can be opened and parsed
- [ ] Local files from M3U are added to playlist
- [ ] Playback works for loaded tracks
- [ ] Relative paths resolve correctly
- [ ] Basic error handling

**Complete (All Phases):**
- [ ] Extended M3U metadata preserved
- [ ] Internet radio URLs detected and stored
- [ ] M3U export/save functionality
- [ ] Full integration with P5 (radio streaming)
- [ ] Drag-and-drop M3U files
- [ ] Finder integration (double-click)

---

## Estimated Time

| Phase | Time | Priority |
|-------|------|----------|
| Phase 1: Fix Selection | 30 min | P0 |
| Phase 2: UTI Declaration | 15 min | P1 |
| Phase 3: Parser | 2-3 hours | P1 |
| Phase 4: Integration | 1-2 hours | P1 |
| Phase 5: Radio (P5 link) | (P5 task) | P5 |
| Phase 6: Export (optional) | 1-2 hours | P3 |

**Total Critical Path:** 4-6 hours (Phases 1-4)

**Total with Optional:** 5-8 hours (Phases 1-4, 6)

---

## Dependencies

**External:**
- None (uses standard Swift/Foundation APIs)

**Internal:**
- **P5 Task:** Internet Radio Streaming (for stream playback)
- **Existing:** AudioPlayer (for local file playback)
- **Existing:** AppState (for playlist management)

---

## Risks and Mitigation

**Risk 1:** Malformed M3U files crash parser
- **Mitigation:** Comprehensive error handling, try-catch blocks
- **Testing:** Create test cases with invalid M3U files

**Risk 2:** Relative paths don't resolve correctly
- **Mitigation:** Test with M3U files from various locations
- **Testing:** Create test M3U with relative paths at different directory levels

**Risk 3:** UTF-8 encoding issues (M3U8)
- **Mitigation:** Always use UTF-8 encoding when reading files
- **Testing:** Create M3U8 with international characters

**Risk 4:** Large playlists cause performance issues
- **Mitigation:** Load playlists asynchronously, show progress indicator
- **Testing:** Create M3U with 1000+ entries

**Risk 5:** Users expect immediate streaming of radio URLs
- **Mitigation:** Clear messaging that streaming requires P5 implementation
- **Testing:** Document expected behavior in UI

---

## Notes

- **Quick Win:** Phase 1 can be done immediately (30 minutes)
- **Standard Compliance:** Follow M3U specification exactly
- **Winamp Parity:** Reference classic Winamp behavior
- **Future-Proof:** Design parser to support future extensions
- **No Code Yet:** This is planning only, implementation happens after approval
