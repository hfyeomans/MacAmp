# Internet Radio Streaming - Research

**Date:** 2025-10-31
**Objective:** Add internet radio streaming capability to MacAmp
**Sources:** Existing documentation, webamp_clone analysis, technical research

---

## Executive Summary

**Current Status:**
- ✅ M3U parser exists (detects remote streams)
- ✅ Entitlements configured (network.client)
- ✅ Info.plist ready (NSAllowsArbitraryLoadsInMedia)
- ❌ No streaming playback implementation

**Architecture Decision:**
- **Local Files:** AVAudioEngine (keeps EQ)
- **Streaming:** AVPlayer (native HTTP streaming)
- **Dual Backend:** Switch based on source type

**Complexity:** High - requires dual audio pipeline

---

## Research Findings

### 1. AVPlayer vs AVAudioEngine for Streaming

**Question:** Can AVAudioEngine stream HTTP audio?

**Answer:** NO - AVAudioEngine requires local files (AVAudioFile)

**AVAudioEngine:**
- ✅ Perfect for local files
- ✅ Supports custom audio processing (EQ)
- ✅ Low-level control
- ❌ Cannot stream HTTP/HTTPS URLs
- ❌ Requires AVAudioFile (file on disk)

**AVPlayer:**
- ✅ Native HTTP/HTTPS streaming
- ✅ Handles buffering automatically
- ✅ HLS support built-in
- ✅ Metadata extraction
- ❌ No custom audio processing (no EQ)
- ❌ High-level player (less control)

**Conclusion:** MUST use dual backend approach

### 2. Dual-Mode Architecture

**Pattern:**
```swift
enum PlaybackMode {
    case localFile    // Use AVAudioEngine (with EQ)
    case stream       // Use AVPlayer (no EQ)
}

class AudioPlayer {
    private let audioEngine: AVAudioEngine      // Local files
    private let streamPlayer: AVPlayer          // Internet radio
    private var currentMode: PlaybackMode = .localFile

    func play(url: URL) {
        if url.isFileURL {
            playLocalFile(url)   // Use AVAudioEngine
        } else {
            playStream(url)      // Use AVPlayer
        }
    }
}
```

**Trade-off:** EQ not available for streams (AVPlayer limitation)

### 3. Webamp Implementation Analysis

**Webamp uses Web Audio API:**
- `<audio>` element for playback
- Connected to AudioContext for processing
- EQ via BiquadFilterNodes
- Works for BOTH local files AND streams

**Architecture (webamp_clone/packages/webamp/js/media/index.ts):**
```typescript
// Web Audio graph:
<audio element> → <source> → <preamp> → <eq filters> → <balance> → <analyser> → <gain> → <output>
```

**Key Insight:** Web can EQ streams because HTML5 `<audio>` handles streaming, then feeds Web Audio API

**macOS Limitation:** No equivalent - AVPlayer doesn't feed AVAudioEngine

### 4. Stream Types and Protocols

**From existing docs (internet-radio-streaming.md):**

**Supported by AVPlayer:**
1. **Direct HTTP Streaming** - http://server.com/stream.mp3
2. **HLS (HTTP Live Streaming)** - http://server.com/playlist.m3u8
3. **Icecast/SHOUTcast** - http://icecast.server.com/stream

**All use HTTP/HTTPS** - covered by network.client entitlement

### 5. M3U Integration (Already Implemented)

**Existing Code (WinampPlaylistWindow.swift:503-506):**
```swift
if entry.isRemoteStream {
    print("M3U: Found stream: \(entry.title ?? entry.url.absoluteString)")
    // TODO: Add to internet radio library when P5 is implemented
}
```

**Parser Works:**
- ✅ Detects HTTP/HTTPS URLs
- ✅ Extracts EXTINF metadata
- ✅ Ready for integration

### 6. Metadata Extraction

**AVPlayer Built-in Metadata:**
```swift
// Observe AVPlayerItem metadata
playerItem.asset.commonMetadata  // Title, artist, album art

// ICY metadata from SHOUTcast streams
// AVPlayer extracts automatically from HTTP headers
// Available in timedMetadata
```

**Real-time Updates:**
```swift
playerItem.publisher(for: \.timedMetadata)
    .sink { metadata in
        // Update "Now Playing" from stream
    }
```

### 7. Swift 6 Patterns for Streaming

**State Management:**
```swift
@MainActor
@Observable
class StreamPlayer {
    var isPlaying: Bool = false
    var isBuffering: Bool = false
    var currentStation: RadioStation?
    var streamTitle: String?

    private let player = AVPlayer()

    func play(station: RadioStation) async {
        // Async streaming operations
    }
}
```

**KVO Observations (Swift 6):**
```swift
// Observe player status
player.publisher(for: \.timeControlStatus)
    .receive(on: DispatchQueue.main)
    .sink { [weak self] status in
        self?.handlePlaybackStatus(status)
    }
```

---

## Architecture Recommendation

### Dual Backend Approach

**When to use each:**
- **Local File (.mp3, .flac, .m4a):** AVAudioEngine + EQ
- **Stream URL (http://, https://):** AVPlayer (no EQ)

**Benefits:**
- ✅ Keep existing local playback (EQ works)
- ✅ Add streaming capability
- ✅ Clear separation of concerns

**Trade-offs:**
- ⚠️ No EQ for streams (AVPlayer limitation)
- ⚠️ More complex codebase (2 backends)
- ⚠️ State management for both modes

### Integration Strategy

**Option A: Separate StreamPlayer Class**
- Create new StreamPlayer for radio
- Keep AudioPlayer for local files
- UI switches between them

**Option B: Unified Player with Mode Switching**
- Extend AudioPlayer with streaming
- Internal mode switching
- Single API for UI

**Recommendation:** Option A (cleaner separation)

---

## Technical Requirements

### Already Have ✅
- com.apple.security.network.client entitlement
- NSAllowsArbitraryLoadsInMedia in Info.plist
- M3U parser with remote detection
- M3UEntry.isRemoteStream property

### Need to Implement
- StreamPlayer class (AVPlayer wrapper)
- RadioStation model
- RadioStationLibrary (persistence)
- UI for station selection
- Metadata display
- Error handling (network issues)

---

## References

- Existing: tasks/internet-radio-file-types/README.md
- Existing: tasks/internet-radio-file-types/internet-radio-streaming.md
- Webamp: webamp_clone/packages/webamp/js/media/index.ts
- MacAmp: MacAmpApp/Audio/AudioPlayer.swift
- M3U: MacAmpApp/Models/M3UParser.swift

---

**Status:** Research complete - ready for plan.md
