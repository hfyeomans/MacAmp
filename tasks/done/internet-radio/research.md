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

---

# Post-Implementation Gap Analysis (2025-10-31)

## User-Reported Issue: Architecture vs Winamp Behavior

**Date:** 2025-10-31
**Reporter:** User (after implementation complete)
**Issue:** Implementation doesn't match actual Winamp UX behavior

### The Gap Discovered

**What We Built:**
- M3U loading: Local files → playlist, Remote streams → RadioStationLibrary (separate)
- Streams NOT visible in playlist
- No UI to play streams yet

**Actual Winamp Behavior (from user):**
- M3U loading: ALL entries → playlist (local + remote both visible)
- Streams appear as playlist items
- Click stream → plays immediately
- Shows "Connecting..." then buffering status

### Winamp Details Provided by User

**1. Adding Stream URLs:**
- Ctrl+L opens "Open/Play location" dialog
- Paste URL → adds to playlist AS A PLAYLIST ITEM
- Streams are playlist items, not separate storage
- Can save, move, select like any track

**2. M3U File Loading:**
- Populates Playlist Editor with ALL entries
- Both local files AND remote streams
- Default: replaces playlist (or appends based on prefs)

**3. Buffering Display:**
- Initial: "Connecting..." in song title area
- Pre-buffer: Silent delay (no percentage)
- Underrun: Blinking "buffer 0%" message
- Not a progress bar - a status alert

### Architecture Impact Analysis

**Current Infrastructure (Correct):**
- ✅ StreamPlayer (AVPlayer backend) - solid
- ✅ PlaybackCoordinator - prevents conflicts
- ✅ RadioStation model - good
- ✅ M3U parser - works perfectly
- ✅ Metadata extraction - correct

**Gap (UX Integration):**
- ⚠️ Playlist doesn't support stream URLs
- ⚠️ PlaybackCoordinator not wired to playlist
- ⚠️ No metadata/buffering display

**Is Architecture Wrong?**
- **NO** - Infrastructure is sound
- **YES** - Integration strategy needs adjustment
- **VERDICT:** Incomplete, not incorrect

### Three Path Options

**Option A: DEFER (Original Plan)**
- Merge infrastructure as-is
- Phase 4: Add playlist integration later
- Effort: 0 now, +4-6 hours later

**Option B: EXTEND CURRENT TASK** ⭐ (User Selected)
- Add Phase 4 planning now
- Implement playlist integration
- Follow same commit strategy
- Effort: +3-4 hours (8-12 hours total)

**Option C: FULL PARITY**
- Everything including buffering UI
- Effort: +8-12 hours
- Not recommended (scope creep)

### User Decision: OPTION B (Extend with Phase 4)

**Requirements:**
1. Add Phase 4 to plan.md (proper planning)
2. Update state.md (current status)
3. Update todo.md (new commits, following strategy)
4. Oracle review of Phase 4 plan
5. Implement with same commit discipline
6. Can defer buffering messages (check with Oracle if easy)

### Phase 4 Core Requirements (User-Driven)

**Must Have:**
1. Streams appear in playlist as items
2. Click stream in playlist → plays
3. M3U populates playlist with local + remote
4. PlaybackCoordinator wired to playlist selection

**Nice to Have (Oracle to advise):**
5. "Connecting..." / buffering status display
   - Uses same sprites/methods as track scrolling
   - Just inserting message instead of track info
   - Oracle: Is this trivial or complex?

### Technical Approach (To Be Planned)

**Extend Track Model:**
```swift
// Option 1: Track supports any URL
struct Track {
    let url: URL  // file://, http://, https://
    var isStream: Bool { !url.isFileURL }
}

// Option 2: Playlist item enum
enum PlaylistItem {
    case track(Track)
    case stream(RadioStation)
}
```

**M3U Integration:**
```swift
// Add streams to BOTH playlist AND library
if entry.isRemoteStream {
    audioPlayer.addTrack(url: entry.url)  // Playlist
    radioLibrary.addStation(station)      // Library (favorites)
}
```

**Playlist Selection:**
```swift
// Wire to PlaybackCoordinator
if track.isStream {
    await playbackCoordinator.play(url: track.url)
} else {
    audioPlayer.playTrack(track: track)
}
```

### Oracle Consultation Needed

**Questions for Oracle:**
1. Best way to extend Track model for streams?
2. Should RadioStationLibrary still exist (for favorites)?
3. Buffering message - trivial or complex to add?
4. Estimated effort for Phase 4 accurate (4-6 hours)?
5. Any architectural concerns with playlist integration?

---

**Status:** Gap identified, Option B selected, planning Phase 4
**Next:** Commit bug fix, plan Phase 4, Oracle review, implement

---

# Oracle Phase 4 Review (2025-10-31)

**Reviewer:** Oracle (Codex)
**Scope:** Phase 4 architecture and implementation plan review
**Status:** ⚠️ SIGNIFICANT CORRECTIONS NEEDED

## Oracle Findings: Phase 4 More Complex Than Estimated

### 🛑 Critical Issues Found (5)

#### 1. Playlist Click Will Crash for Streams
**Location:** `WinampPlaylistWindow.swift:409`
**Problem:**
```swift
// Double-click → audioPlayer.playTrack(track:)
//   → Opens AVAudioFile (AudioPlayer.swift:272)
//   → CRASHES on HTTP URLs (can't open as file)
```

**Fix Required:**
- Playlist click MUST route through PlaybackCoordinator
- NOT just for new functionality - prevents crashes

#### 2. Transport Controls Bypass Coordinator
**Locations:**
- Next/Previous: `AudioPlayer.swift:1208, 1244`
- Buttons: `WinampMainWindow.swift:351, 379, 485`
- All call `AudioPlayer` methods directly

**Problem:**
- Next/Previous will fail on stream tracks
- Shuffle/Repeat will break
- Keyboard shortcuts bypass coordinator

**Fix Required:**
- PlaybackCoordinator needs `next()`, `previous()` methods
- ALL transport controls route through coordinator
- More extensive than just playlist click

#### 3. UI Bindings Wrong
**Locations:**
- Title display: `WinampMainWindow.swift:565, 577`
- Reads `audioPlayer.currentTitle` directly

**Problem:**
- Won't show stream metadata
- Won't show "Connecting..." buffering
- Wrong state source

**Fix Required:**
- ALL UI must read from PlaybackCoordinator
- Not just buffering display - fundamental binding change

#### 4. StreamPlayer Only Accepts RadioStation
**Location:** `StreamPlayer.swift:46`
```swift
func play(station: RadioStation) async
```

**Problem:**
- Playlist tracks are just URLs
- Don't have RadioStation objects
- Creates synthetic stations loses metadata

**Fix Required:**
- Add `play(url: URL)` overload to StreamPlayer
- Extract metadata from URL, not RadioStation

#### 5. PlaybackCoordinator Loses Metadata
**Location:** `PlaybackCoordinator.swift:67`
```swift
// Creates synthetic RadioStation from URL
let station = RadioStation(name: url.lastPathComponent, streamURL: url)
```

**Problem:**
- Throws away playlist Track metadata (title/artist)
- Recreates from URL (loses info)

**Fix Required:**
- Add `play(track: Track)` overload
- Preserve Track metadata for streams

---

## Oracle Revised Estimates

| Component | My Estimate | Oracle Estimate | Why |
|-----------|-------------|-----------------|-----|
| Track extension | 15 min | 30 min | Need guards in AudioPlayer |
| M3U/ADD URL fix | 45 min | 1 hour | Remove library, test thoroughly |
| Coordinator wiring | 1.5 hours | 2-3 hours | ALL transport controls |
| UI bindings | 45 min | 1.5 hours | ALL views, not just one |
| Buffering display | 45 min | 1 hour | Coordinate with state |
| Testing/regression | - | 1-2 hours | Extensive testing needed |
| **TOTAL** | **3.75 hours** | **6-8 hours** | Much more extensive |

---

## Oracle Recommended Approach

### Phase 4 Revised Commit Strategy (6-7 commits)

**Commit 13:** Extend Track + add guards (30 min)
- Add `Track.isStream` computed property
- Add guards in `AudioPlayer.playTrack()` to prevent stream URLs
- Fail gracefully if stream attempted

**Commit 14:** Fix M3U + ADD URL (1 hour)
- Remove all `radioLibrary.addStation()` calls
- Streams append to `audioPlayer.playlist` as Tracks
- Test with mixed M3U

**Commit 15:** Add StreamPlayer.play(url:) (30 min)
- Overload for URL (not just RadioStation)
- Extract metadata from URL or use defaults
- Support playlist-driven playback

**Commit 16:** Extend PlaybackCoordinator (1 hour)
- Add `play(track: Track)` overload
- Add `next()`, `previous()` methods
- Add unified state properties (displayTitle, etc.)

**Commit 17:** Wire playlist + transport controls (2-3 hours)
- Update playlist click handler
- Update Next/Previous buttons
- Update Play/Pause/Stop buttons
- Update keyboard shortcuts
- Wire through coordinator

**Commit 18:** Update UI bindings (1.5 hours)
- WinampMainWindow: Use coordinator.displayTitle
- WinampMainWindow: Use coordinator state
- Update all state observers
- Test metadata display

**Commit 19:** Buffering display + polish (1 hour)
- Add "Connecting..." logic
- Add "buffer 0%" error display
- Final testing and regression checks

**Total:** 6-8 hours, 7 commits

---

## Oracle Architectural Concerns

### Swift 6 / Concurrency
**Concern:** Playlist taps launch Task blocks
**Requirement:** PlaybackCoordinator methods MUST be @MainActor safe
**Status:** ✅ Already @MainActor

### State Management
**Concern:** Multiple views read playback state
**Requirement:** Coordinator must expose ALL state (not partial)
**Status:** ⚠️ Need to add next/previous, playlist position, etc.

### Metadata Updates
**Concern:** ICY metadata updates while UI is rendering
**Requirement:** Cancel metadata observers on track change
**Status:** ✅ Already implemented in StreamPlayer

---

## Oracle Specific Corrections to Plan

### 1. PlaybackCoordinator Must Be Primary
**Original Plan:** Just add play(url:) and play(station:)
**Oracle Plan:** Become THE transport interface

```swift
@MainActor
@Observable
final class PlaybackCoordinator {
    // Unified transport controls
    func play(track: Track) async
    func play(url: URL) async
    func play(station: RadioStation) async  // For favorites menu
    func next() async
    func previous() async
    func pause()
    func stop()
    func togglePlayPause()

    // Unified state
    var displayTitle: String
    var displayArtist: String
    var isPlaying: Bool
    var isPaused: Bool
    var isBuffering: Bool
    var currentTrack: Track?  // For playlist position
}
```

### 2. StreamPlayer Needs URL Method
```swift
// Add this overload
func play(url: URL, title: String? = nil, artist: String? = nil) async {
    let station = RadioStation(
        name: title ?? url.host ?? "Stream",
        streamURL: url
    )
    await play(station: station)
}
```

### 3. AudioPlayer Needs Guards
```swift
func playTrack(track: Track) {
    guard !track.isStream else {
        print("ERROR: Cannot play stream via AudioPlayer - use PlaybackCoordinator")
        return
    }
    // ... existing code
}
```

### 4. All UI Must Switch to Coordinator
**Files to Update:**
- WinampMainWindow.swift (title display, buttons)
- WinampPlaylistWindow.swift (playlist, shade mode)
- AppCommands.swift (keyboard shortcuts)
- Any other view reading audioPlayer state

---

## Oracle Recommendation Summary

✅ **Track URL Extension:** Correct approach, just add guards
✅ **Keep RadioStationLibrary:** For favorites menu (Phase 5+)
⚠️ **Buffering Display:** Not trivial - requires full UI binding update
🛑 **Effort Estimate:** 6-8 hours (not 3.75) - full coordinator integration
🛑 **Scope:** Much larger than initially planned

**Oracle Verdict:** Phase 4 is a **full coordinator migration**, not just playlist integration.

**Proceed:** Yes, but with corrected scope and timeline
**Commits:** 7 commits (not 4)
**Effort:** 6-8 hours (full day, not half)

---

**Status:** Oracle review complete, plan needs major revision
**Next:** Update plan.md, todo.md, state.md with Oracle corrections

