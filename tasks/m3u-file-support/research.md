# M3U File Support Research

## Problem Statement

M3U playlist files appear **grayed out** and are **not selectable** in MacAmp's file open dialog, despite being registered in Info.plist. This prevents users from:
- Loading internet radio station playlists
- Importing existing Winamp playlists
- Opening M3U files from other sources

## Root Cause Analysis

### Issue #1: NSOpenPanel Configuration ❌

**Location:** `MacAmpApp/Views/WinampPlaylistWindow.swift:openFileDialog()`

**Current Code:**
```swift
private func openFileDialog() {
    let openPanel = NSOpenPanel()
    openPanel.allowedContentTypes = [.audio]  // ❌ PROBLEM: Only allows audio files
    openPanel.allowsMultipleSelection = true
    openPanel.canChooseDirectories = false
    // ...
}
```

**Problem:**
- `allowedContentTypes` is set to `[.audio]` only
- M3U files are playlists, not audio files
- They conform to `UTType.m3uPlaylist`, not `UTType.audio`
- Therefore, M3U files are grayed out as "unselectable"

### Issue #2: Missing UTI Import Declaration ⚠️

**Location:** `MacAmpApp/Info.plist`

**Current Configuration:**
```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>M3U Playlist</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.m3u-playlist</string>
        </array>
        <!-- ... -->
    </dict>
</array>
```

**Problem:**
- `CFBundleDocumentTypes` declares support for M3U files ✅
- BUT: Missing `UTImportedTypeDeclarations` entry
- Without this, the system doesn't fully recognize the UTI
- Weak association between app and file type

**What's Missing:**
- No `UTImportedTypeDeclarations` section
- No explicit declaration of conformance to `public.text` and `public.playlist`
- No file extension specification (`.m3u`, `.m3u8`)

---

## M3U File Format Research

### 1. Standard M3U Format

**Description:** Plain text file with media file paths, one per line.

**Example:**
```m3u
C:\Music\Song1.mp3
../Music/Song2.mp3
/Users/username/Music/Song3.mp3
```

**Characteristics:**
- No header
- Paths can be absolute, relative, or URLs
- No metadata
- Simple but limited

### 2. Extended M3U Format (#EXTM3U)

**Description:** Enhanced format with metadata support.

**Header:** `#EXTM3U`

**Directive:** `#EXTINF:<duration>,<title>`
- `<duration>`: Length in seconds (-1 for unknown/streams)
- `<title>`: Display name for track

**Example:**
```m3u
#EXTM3U
#EXTINF:211,Artist Name - Track Title
C:\Music\Song1.mp3
#EXTINF:321,Another Artist - Another Title
../Music/Song2.mp3
```

**Characteristics:**
- Starts with `#EXTM3U` header
- Metadata line (`#EXTINF`) applies to **next** line
- Track duration and title included
- Standard for modern playlists

### 3. Internet Radio M3U Format

**Description:** M3U files containing URLs to live audio streams.

**Example (SomaFM):**
```m3u
#EXTM3U
#EXTINF:-1,SomaFM: Groove Salad - A nicely chilled plate of ambient/downtempo beats
http://ice1.somafm.com/groovesalad-128-aac
#EXTINF:-1,SomaFM: Drone Zone - Atmospheric textures with minimal beats
http://ice1.somafm.com/dronezone-128-aac
#EXTINF:-1,SomaFM: DEF CON Radio - Music for Hacking
http://ice1.somafm.com/defcon-128-mp3
```

**Characteristics:**
- Duration is `-1` (infinite/live stream)
- URLs point to streaming servers (HTTP/HTTPS)
- Title includes station name and description
- Common for internet radio distribution

**Real-World Sources:**
- **SomaFM:** Provides M3U files for each station
- **Radio Paradise:** Offers M3U/PLS downloads
- **TuneIn:** Generates M3U playlists
- **Icecast/SHOUTcast directories:** Export M3U files

### 4. M3U vs M3U8

| Feature | M3U | M3U8 |
|---------|-----|------|
| **Encoding** | System default | UTF-8 |
| **Extension** | `.m3u` | `.m3u8` |
| **Use Case** | Local playlists | Web streaming (HLS) |
| **International Characters** | May not render | Fully supported |
| **Compatibility** | Universal | Modern players |

**HLS (HTTP Live Streaming) M3U8:**
```m3u8
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXTINF:10.0,
segment1.ts
#EXTINF:10.0,
segment2.ts
#EXTINF:10.0,
segment3.ts
#EXT-X-ENDLIST
```

**Note:** HLS M3U8 is different from playlist M3U8:
- HLS: Apple's adaptive bitrate streaming protocol
- Playlist: Standard M3U with UTF-8 encoding

---

## M3U Parsing Algorithm

### Basic Parser Structure

```swift
struct M3UEntry {
    let url: URL
    let title: String?
    let duration: Int?  // -1 for streams
}

func parseM3U(content: String) -> [M3UEntry] {
    var entries: [M3UEntry] = []
    var currentTitle: String?
    var currentDuration: Int?

    let lines = content.components(separatedBy: .newlines)

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip empty lines
        if trimmed.isEmpty { continue }

        // Check for extended M3U header
        if trimmed == "#EXTM3U" { continue }

        // Parse EXTINF metadata
        if trimmed.hasPrefix("#EXTINF:") {
            // Format: #EXTINF:<duration>,<title>
            let parts = trimmed.dropFirst(8).split(separator: ",", maxSplits: 1)
            if parts.count == 2 {
                currentDuration = Int(parts[0])
                currentTitle = String(parts[1])
            }
            continue
        }

        // Skip other comments
        if trimmed.hasPrefix("#") { continue }

        // This is a URL or file path
        if let url = URL(string: trimmed) {
            let entry = M3UEntry(
                url: url,
                title: currentTitle,
                duration: currentDuration
            )
            entries.append(entry)

            // Reset metadata for next entry
            currentTitle = nil
            currentDuration = nil
        }
    }

    return entries
}
```

### Parsing Logic

1. **Read line by line**
2. **Check for `#EXTM3U` header** → Indicates extended format
3. **If line starts with `#EXTINF:`** → Parse metadata
   - Extract duration (before comma)
   - Extract title (after comma)
   - Store for next URL line
4. **If line starts with `#`** → Skip (comment)
5. **Otherwise** → Treat as URL/path
   - Create entry with stored metadata
   - Reset metadata for next entry

### Handling Internet Radio Streams

```swift
func isInternetRadioStream(_ url: URL) -> Bool {
    return url.scheme == "http" || url.scheme == "https"
}

func loadM3UPlaylist(url: URL) {
    guard let content = try? String(contentsOf: url) else { return }
    let entries = parseM3U(content: content)

    for entry in entries {
        if isInternetRadioStream(entry.url) {
            // Add to radio stations list
            addRadioStation(
                name: entry.title ?? "Unknown Station",
                streamURL: entry.url
            )
        } else {
            // Add to local playlist
            addLocalTrack(url: entry.url)
        }
    }
}
```

---

## Winamp/Webamp Behavior

### Winamp (Desktop)

**M3U File Handling:**
1. User selects File → Open → Playlist
2. File dialog allows `.m3u`, `.m3u8`, `.pls` files
3. Winamp reads and parses the file
4. For local paths:
   - Resolves relative paths from M3U location
   - Adds tracks to playlist window
5. For URLs:
   - Displays as "URL: <stream URL>"
   - Connects to stream when played

**M3U Creation:**
- File → Save Playlist
- Saves with `#EXTM3U` header
- Uses `#EXTINF` for metadata
- Stores relative paths when possible

### Webamp (JavaScript Clone)

**Implementation:**
```javascript
// Webamp's M3U handling (JavaScript)
async function parseM3u(text) {
    const lines = text.split('\n');
    const entries = [];
    let currentMetadata = null;

    for (const line of lines) {
        const trimmed = line.trim();

        if (trimmed === '#EXTM3U') continue;

        if (trimmed.startsWith('#EXTINF:')) {
            const parts = trimmed.substring(8).split(',');
            currentMetadata = {
                duration: parseInt(parts[0]),
                title: parts[1]
            };
            continue;
        }

        if (trimmed.startsWith('#')) continue;

        if (trimmed) {
            entries.push({
                url: trimmed,
                ...currentMetadata
            });
            currentMetadata = null;
        }
    }

    return entries;
}

// File drop handling
dropzone.addEventListener('drop', async (e) => {
    const file = e.dataTransfer.files[0];
    if (file.name.endsWith('.m3u') || file.name.endsWith('.m3u8')) {
        const text = await file.text();
        const entries = await parseM3u(text);
        webamp.loadPlaylist(entries);
    }
});
```

**Key Features:**
- Drag-and-drop M3U files
- FileReader API to read content
- Parse URLs and metadata
- Add to internal playlist
- Handle both local and remote URLs

---

## UTI (Uniform Type Identifier) System

### What is UTI?

**UTI:** macOS's unified way to identify file types, replacing MIME types and file extensions.

**Hierarchy:**
```
public.item
  └── public.content
      └── public.data
          └── public.text
              └── public.playlist
                  └── public.m3u-playlist
```

### System-Declared UTI: `public.m3u-playlist`

**Properties:**
- **Identifier:** `public.m3u-playlist`
- **Conforms To:** `public.text`, `public.playlist`
- **Extensions:** `.m3u`, `.m3u8`
- **MIME Types:** `audio/x-mpegurl`, `audio/mpegurl`

**Note:** This is a **public** UTI declared by Apple, not a custom type.

### Swift UTType Access

```swift
import UniformTypeIdentifiers

// Access M3U playlist type
let m3uType = UTType.m3uPlaylist

// Check if URL is M3U
let url = URL(fileURLWithPath: "/path/to/playlist.m3u")
if let type = UTType(filenameExtension: url.pathExtension) {
    if type.conforms(to: .m3uPlaylist) {
        print("This is an M3U playlist")
    }
}

// Use in NSOpenPanel
let openPanel = NSOpenPanel()
openPanel.allowedContentTypes = [.audio, .m3uPlaylist]
```

---

## Info.plist Configuration

### Current Configuration (Incomplete)

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>M3U Playlist</string>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSHandlerRank</key>
        <string>Default</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.m3u-playlist</string>
        </array>
        <key>NSDocumentClass</key>
        <string>NSDocument</string>
    </dict>
</array>
```

**What's Missing:**
- No `UTImportedTypeDeclarations`
- No explicit file extension mapping
- No conformance declaration

### Complete Configuration (Recommended)

```xml
<!-- 1. Import Type Declaration -->
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

<!-- 2. Document Type (already present, no changes) -->
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>M3U Playlist</string>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSHandlerRank</key>
        <string>Default</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.m3u-playlist</string>
        </array>
        <key>NSDocumentClass</key>
        <string>NSDocument</string>
    </dict>
</array>
```

### Why Both Are Needed

**`UTImportedTypeDeclarations`:**
- Declares that your app understands this file type
- Maps extensions (`.m3u`, `.m3u8`) to the UTI
- Establishes conformance hierarchy
- Makes the UTI "real" for your app

**`CFBundleDocumentTypes`:**
- Declares your app can **open** these files
- Links to handler code (NSDocument)
- Sets role (Viewer, Editor, etc.)
- Determines priority (LSHandlerRank)

---

## Summary of Findings

### Root Causes

1. **NSOpenPanel Restriction** (Primary Issue)
   - `allowedContentTypes = [.audio]` excludes playlists
   - Must add `.m3uPlaylist` to array
   - **Impact:** Immediate - files become selectable

2. **Missing UTI Import** (Secondary Issue)
   - No `UTImportedTypeDeclarations` in Info.plist
   - Weak system recognition of M3U support
   - **Impact:** Robustness - full system integration

### Solution Requirements

**Minimum (Fix the Bug):**
- Add `.m3uPlaylist` to `NSOpenPanel.allowedContentTypes`

**Complete (Best Practice):**
- Add `.m3uPlaylist` to NSOpenPanel
- Add `UTImportedTypeDeclarations` to Info.plist
- Implement M3U parser
- Handle both local files and internet radio URLs

---

## References

**Apple Documentation:**
- [Uniform Type Identifiers](https://developer.apple.com/documentation/uniformtypeidentifiers)
- [UTType](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype)
- [Declaring New Uniform Type Identifiers](https://developer.apple.com/documentation/uniformtypeidentifiers/defining_file_and_data_types_for_your_app)

**M3U Format:**
- [M3U Wikipedia](https://en.wikipedia.org/wiki/M3U)
- [M3U Specification](http://gonze.com/playlists/playlist-format-survey.html#M3U)

**Webamp Reference:**
- [Webamp GitHub](https://github.com/captbaritone/webamp)
- Webamp M3U Parser: `packages/webamp/js/parseM3u.js`

**Example M3U Files:**
- [SomaFM Playlists](https://somafm.com/listen/)
- [Radio Paradise Streams](https://radioparadise.com/listen)
