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
# Oracle Review - Internet Radio Streaming Task

**Date:** 2025-10-31
**Reviewer:** Oracle (Codex)
**Scope:** Complete architecture and implementation review

---

## ✅ Architecture Validation

### Dual Backend Approach: APPROVED with Recommendations

**Oracle Verdict:**
> "Dual backend is the pragmatic choice. AVAudioEngine cannot consume live HTTP streams, while AVPlayer refuses custom node graphs, so you lose the 10-band EQ when streaming."

**Validated:**
- ✅ AVAudioEngine for local files (with EQ)
- ✅ AVPlayer for streams (no EQ)
- ✅ This is the correct approach

**Critical Addition Required:**
- ⚠️ **MUST add PlaybackCoordinator** to manage both players
- Prevents both engines playing simultaneously
- Unified API for UI
- Single source of truth for playback state

---

## Critical Issues Found (6)

### 1. ❌ CRITICAL: Missing PlaybackCoordinator

**Oracle:**
> "Without it you risk starting a stream while the engine is still playing, and you have no unified source for play state, progress, volume, etc."

**Problem:**
- UI would need to talk to 2 separate players
- No coordination between AudioPlayer and StreamPlayer
- Could play both simultaneously (audio chaos!)
- Duplicate state management

**Solution:**
```swift
@MainActor
@Observable
class PlaybackCoordinator {
    private let audioPlayer: AudioPlayer       // Local files
    private let streamPlayer: StreamPlayer     // Streams

    private(set) var isPlaying: Bool = false
    private(set) var currentSource: PlaybackSource?

    enum PlaybackSource {
        case localTrack(URL)
        case radioStation(RadioStation)
    }

    func play(url: URL) {
        if url.isFileURL {
            streamPlayer.stop()  // Stop stream if playing
            audioPlayer.play(url: url)
            currentSource = .localTrack(url)
        } else {
            audioPlayer.stop()   // Stop file if playing
            Task {
                await streamPlayer.play(station: /* ... */)
            }
            currentSource = .radioStation(/* ... */)
        }
        isPlaying = true
    }

    // Unified controls
    func pause() { /* delegate to active player */ }
    func stop() { /* stop both */ }
}
```

**Impact:** ALL phases - core architecture
**Effort:** +2-3 hours

### 2. ❌ HIGH: RadioStationLibrary Not Accessible

**Oracle:**
> "PlaylistWindowActions has no access to RadioStationLibrary. You'll need to pass the library in before that compile step succeeds."

**Problem:**
```swift
// In WinampPlaylistWindow.swift Line 503
radioLibrary.addStation(station)  // ❌ radioLibrary doesn't exist!
```

**Solution:**
- Pass RadioStationLibrary to PlaylistWindowActions
- Or make it a singleton
- Or inject via environment to WinampPlaylistWindow

**Impact:** Phase 2 (M3U integration)

### 3. ⚠️ MEDIUM: Observer Cleanup Missing

**Oracle:**
> "StreamPlayer needs defensive cleanup: cancel previous metadataObserver before attaching new one, remove timeObserver when replacing items."

**Missing in plan:**
```swift
private func setupMetadataObserver(for item: AVPlayerItem) {
    // ❌ MISSING: Cancel old observer first!
    metadataObserver?.cancel()  // Add this

    metadataObserver = item.publisher(for: \.timedMetadata)
        .sink { [weak self] metadata in
            self?.extractStreamMetadata(metadata)
        }
}
```

**Also need:**
- Observe playerItem.status for errors
- Remove timeObserver before replacing item

**Impact:** Phase 1 (StreamPlayer reliability)

### 4. ⚠️ MEDIUM: Metadata Extraction Incorrect

**Oracle:**
> "Using value(forKey:) with raw AVMetadataKey. Prefer item.commonKey / item.stringValue to avoid KVC failures."

**Wrong (in plan):**
```swift
// ❌ WRONG:
if let title = item.value(forKey: AVMetadataKey.commonKeyTitle.rawValue) as? String {
    streamTitle = title
}
```

**Correct:**
```swift
// ✅ CORRECT:
for item in items {
    if item.commonKey == .commonKeyTitle,
       let title = item.stringValue {
        streamTitle = title
    }
    if item.commonKey == .commonKeyArtist,
       let artist = item.stringValue {
        streamArtist = artist
    }
}
```

**Impact:** Phase 1 (metadata display)

### 5. ⚠️ MEDIUM: Streams Not in Playlist Order

**Oracle:**
> "Loading a playlist that mixes locals and streams will only populate local tracks. Users won't see streams in the playlist order they expect."

**Problem:**
- M3U file: Track1.mp3, RadioStream, Track2.mp3
- Result: Playlist shows Track1, Track2 (radio missing!)
- Users expect to see all entries in order

**Solution:**
- Add lightweight placeholder Track for streams
- Delegates playback to StreamPlayer
- OR: Show both in playlist with different icon

**Impact:** Phase 2 (UX)

### 6. ⚠️ LOW: Swift 6 Combine Pattern

**Oracle:**
> "Marked @MainActor but uses .receive(on: DispatchQueue.main). Swap to RunLoop.main or wrap sink in MainActor.run."

**Cleanup:**
```swift
// Better for @MainActor:
statusObserver = player.publisher(for: \.timeControlStatus)
    .receive(on: RunLoop.main)  // Or MainActor.run
    .sink { [weak self] status in
        self?.handleStatusChange(status)
    }
```

**Impact:** Code quality

---

## Oracle Recommendations

### 1. Add PlaybackCoordinator (Required)

**Priority:** HIGH - do this first
**Effort:** +2-3 hours
**Why:** Prevents dual playback, unified API

### 2. Update Time Estimates

**Original:** 9-11 hours
**Oracle Adjusted:** 12-15 hours
- +2-3 hours for PlaybackCoordinator
- +1 hour for observer cleanup
- +1 hour for playlist integration complexity

### 3. Phase Ordering

**Suggested Order:**
1. Create models (RadioStation, Library) - 1 hour
2. Create StreamPlayer with proper observers - 3 hours
3. Create PlaybackCoordinator - 2-3 hours
4. Test coordination works - 1 hour
5. M3U integration - 2 hours
6. UI polish - 3 hours

**Total:** 12-14 hours

### 4. Already Have

**Oracle Found:**
> "NSAllowsArbitraryLoadsInMedia is already present (MacAmpApp/Info.plist:22-26)"

**Update state.md and todo.md:** Mark this as ✅ complete, not pending!

---

## Specific Answers from Oracle

**Q: Can we EQ AVPlayer output?**
A: Only via MTAudioProcessingTap (custom DSP, major project). Not worth it for MVP.

**Q: Way to avoid dual backend?**
A: No. Re-implementing streaming with AVAudioEngine = decoder + buffer + feed pipeline. Far too complex.

**Q: StreamPlayer wrap AudioPlayer or separate?**
A: Separate, but both owned by PlaybackCoordinator.

**Q: iOS/web patterns that don't apply?**
A: Web Audio can pipe `<audio>` into AudioContext. macOS AVPlayer can't feed AVAudioEngine.

**Q: Missing Info.plist keys?**
A: No. NSAllowsArbitraryLoadsInMedia is all you need (already have it).

---

## Required Plan Updates

**Before Implementation:**

1. ✅ Add PlaybackCoordinator to plan.md
2. ✅ Fix StreamPlayer observer cleanup
3. ✅ Fix metadata extraction code
4. ✅ Address RadioStationLibrary injection
5. ✅ Update time estimates
6. ✅ Mark NSAllowsArbitraryLoadsInMedia as complete
7. ✅ Add playlist integration strategy

---

## Oracle Final Assessment

**Feasibility:** ✅ YES (with PlaybackCoordinator)
**Complexity:** HIGH (dual backend, coordination)
**Time:** 12-15 hours (not 9-11)
**Priority:** MEDIUM (after clutter bar I/O buttons)

**Blocking Issues:** None (can implement when ready)

**Recommendation:**
1. Add PlaybackCoordinator design to plan
2. Fix code examples per Oracle feedback
3. Update estimates
4. Then implement in phases

---

**Status:** Architecture validated, corrections needed before implementation
