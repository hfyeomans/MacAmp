# Internet Radio Streaming Configuration

## Executive Summary ✅

**Good News:** Your existing entitlements already support ALL internet radio streaming protocols!

**Critical Addition:** App Transport Security configuration in Info.plist to allow HTTP streams.

---

## Entitlement Analysis

### ✅ Already Configured (No Changes Needed)

#### 1. `com.apple.security.network.client` = true

**This single entitlement covers ALL streaming protocols:**

- ✅ HTTP/HTTPS connections
- ✅ TCP socket connections
- ✅ UDP socket connections (for RTP/RTSP if needed)
- ✅ DNS resolution
- ✅ WebSocket connections
- ✅ Custom TCP protocols
- ✅ Outgoing connections on any port

**Supports these radio streaming protocols:**
- **HLS (HTTP Live Streaming)** - .m3u8 playlists (Apple's standard)
- **Icecast/SHOUTcast** - ICY protocol over HTTP
- **Direct MP3/AAC/OGG streams** - Raw audio over HTTP/HTTPS
- **RTSP (Real-Time Streaming Protocol)** - Rare but supported
- **MMS (Microsoft Media Server)** - Legacy protocol
- **DASH (Dynamic Adaptive Streaming)** - Modern alternative to HLS

#### 2. `com.apple.security.device.audio-output` = true

**Enables audio playback:**
- ✅ AVAudioEngine
- ✅ AVPlayer
- ✅ AudioQueue
- ✅ Core Audio output
- ✅ System audio device access

---

## Info.plist Configuration

### App Transport Security (CRITICAL ⚠️)

**Problem:** 90% of internet radio stations use HTTP (not HTTPS)

**Examples of HTTP-only stations:**
```
http://stream.radioparadise.com:8000/mp3-128
http://icecast.somafm.com/groovesalad-256-mp3
http://ice1.somafm.com/defcon-128-mp3
```

**Without ATS configuration, these will all FAIL!**

**Solution Added:**
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoadsInMedia</key>
    <true/>
</dict>
```

**Why this specific setting:**
- ✅ **App Store approved** for media apps
- ✅ Allows HTTP for AVFoundation media loading only
- ✅ Does NOT allow HTTP for general web views or data loading
- ✅ More secure than `NSAllowsArbitraryLoads`

---

## Supported Streaming Protocols

### 1. Direct HTTP Streaming (Most Common)

**Format:**
```
http://server.com:8000/stream.mp3
```

**How it works:**
1. MacAmp makes HTTP GET request
2. Server responds with `Content-Type: audio/mpeg`
3. Server sends continuous MP3 data
4. AVPlayer buffers and decodes in real-time
5. Audio plays seamlessly

**Requires:**
- ✅ `com.apple.security.network.client`
- ✅ `NSAllowsArbitraryLoadsInMedia` (for HTTP)

### 2. HLS (HTTP Live Streaming)

**Format:**
```
http://server.com/playlist.m3u8
```

**How it works:**
1. MacAmp requests .m3u8 playlist file
2. Playlist contains URLs to .ts (transport stream) segments
3. MacAmp downloads segments sequentially
4. AVPlayer handles buffering automatically
5. Adaptive bitrate selection based on bandwidth

**Bonus:** AVPlayer handles HLS natively - zero extra code needed!

### 3. Icecast/SHOUTcast (ICY Protocol)

**Format:**
```
http://icecast.server.com/stream
```

**Special features:**
- Sends metadata in headers (`ICY-MetaInt`)
- Current song/artist info embedded in stream
- Stream title updates in real-time

---

## Testing Internet Radio Streams

### Popular Test Stations

**SomaFM (Free, high-quality, HTTP):**
```
http://ice1.somafm.com/groovesalad-256-mp3  # Groove Salad
http://ice1.somafm.com/defcon-128-mp3       # DEF CON Radio
http://ice1.somafm.com/secretagent-128-mp3  # Secret Agent
```

**Radio Paradise (Free, excellent quality):**
```
http://stream.radioparadise.com/mp3-192
http://stream.radioparadise.com/aac-320
```

---

## Implementation Guide

### Basic Stream Player

```swift
import AVFoundation

class InternetRadioPlayer {
    private var player: AVPlayer?
    private var currentStation: RadioStation?

    struct RadioStation {
        let name: String
        let streamURL: URL
        let genre: String?
    }

    func play(station: RadioStation) {
        currentStation = station

        let playerItem = AVPlayerItem(url: station.streamURL)
        player = AVPlayer(playerItem: playerItem)

        // Configure for streaming
        player?.automaticallyWaitsToMinimizeStalling = true

        // Start playback
        player?.play()
    }

    func stop() {
        player?.pause()
        player = nil
    }

    var isPlaying: Bool {
        return player?.rate != 0
    }
}
```

### Loading M3U Playlists

```swift
func parseM3U(from url: URL) throws -> [RadioStation] {
    let content = try String(contentsOf: url, encoding: .utf8)
    var stations: [RadioStation] = []

    var currentTitle: String?

    for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("#EXTINF:") {
            // Extract title from: #EXTINF:-1,Station Name
            if let titleRange = trimmed.range(of: ",") {
                currentTitle = String(trimmed[titleRange.upperBound...])
            }
        } else if trimmed.hasPrefix("http") {
            if let streamURL = URL(string: trimmed) {
                let station = RadioStation(
                    name: currentTitle ?? "Unknown Station",
                    streamURL: streamURL,
                    genre: nil
                )
                stations.append(station)
                currentTitle = nil
            }
        }
    }

    return stations
}
```

### Loading PLS Playlists

```swift
func parsePLS(from url: URL) throws -> [RadioStation] {
    let content = try String(contentsOf: url, encoding: .utf8)
    var stations: [RadioStation] = []
    var entries: [Int: (url: String?, title: String?)] = [:]

    for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("File") {
            // File1=http://...
            let parts = trimmed.components(separatedBy: "=")
            if parts.count == 2,
               let number = Int(parts[0].replacingOccurrences(of: "File", with: "")) {
                entries[number, default: (nil, nil)].url = parts[1]
            }
        } else if trimmed.hasPrefix("Title") {
            // Title1=Station Name
            let parts = trimmed.components(separatedBy: "=")
            if parts.count == 2,
               let number = Int(parts[0].replacingOccurrences(of: "Title", with: "")) {
                entries[number, default: (nil, nil)].title = parts[1]
            }
        }
    }

    for (_, entry) in entries.sorted(by: { $0.key < $1.key }) {
        if let urlString = entry.url, let streamURL = URL(string: urlString) {
            let station = RadioStation(
                name: entry.title ?? "Unknown Station",
                streamURL: streamURL,
                genre: nil
            )
            stations.append(station)
        }
    }

    return stations
}
```

---

## Summary: What You Have vs What You Need

### Entitlements (MacAmp.entitlements)

| Entitlement | Status | Purpose |
|------------|--------|---------|
| `com.apple.security.network.client` | ✅ **Have it** | All network streaming |
| `com.apple.security.device.audio-output` | ✅ **Have it** | Audio playback |
| `com.apple.security.files.user-selected.*` | ✅ **Have it** | Open playlist files |
| `com.apple.security.files.downloads.*` | ✅ **Have it** | Save downloaded playlists |

**Result:** ✅ **No additional entitlements needed!**

### Info.plist Configuration

| Setting | Status | Purpose |
|---------|--------|---------|
| `NSAppTransportSecurity` | ✅ **Added** | Allow HTTP radio streams |
| `LSApplicationCategoryType` | ✅ **Added** | Music app category |
| `CFBundleDocumentTypes` | ✅ **Added** | M3U/PLS file support |
| `CFBundleURLTypes` | ✅ **Added** | macamp:// URL scheme |
| `NSSupportsAutomaticTermination` | ✅ **Added** | Prevent termination during playback |

**Result:** ✅ **Fully configured for internet radio!**

---

## Resources

**Internet Radio Directories:**
- [SHOUTcast Directory](https://directory.shoutcast.com/)
- [TuneIn](https://tunein.com/)
- [Radio Browser](https://www.radio-browser.info/)

**Streaming Protocols:**
- [HLS Specification](https://datatracker.ietf.org/doc/html/rfc8216)
- [Icecast Protocol](https://www.icecast.org/docs/)

**Apple Documentation:**
- [AVFoundation HTTP Live Streaming](https://developer.apple.com/streaming/)
- [App Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)
