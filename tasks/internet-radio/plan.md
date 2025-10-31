# Internet Radio Streaming - Implementation Plan

**Date:** 2025-10-31
**Objective:** Add HTTP/HTTPS internet radio streaming to MacAmp
**Approach:** Dual backend (AVAudioEngine for local, AVPlayer for streams)

---

## Success Criteria

### MVP (Phase 1)
- ✅ Can play single HTTP stream URL
- ✅ Basic playback controls (play/pause/stop)
- ✅ Switching between local files and streams works
- ✅ No crashes or audio conflicts

### Full Feature (Phase 2)
- ✅ M3U/M3U8 remote streams load into station library
- ✅ Save/load favorite stations
- ✅ Display stream metadata (title, artist)
- ✅ Handle network errors gracefully

### Polish (Phase 3)
- ✅ Buffering indicators
- ✅ Stream quality selection
- ✅ Station categories/genres
- ✅ Export station library as M3U/M3U8

---

## Architecture Decision

### Dual Audio Backend

**Local Files (Current):**
```
AVAudioPlayerNode → AVAudioUnitEQ → mainMixerNode → outputNode
(10-band EQ works)
```

**Streaming (New):**
```
AVPlayer → System Audio Output
(No EQ - AVPlayer limitation)
```

**Why Dual Backend:**
- AVAudioEngine cannot stream HTTP
- AVPlayer cannot use AVAudioUnitEQ
- Must use both for different sources

---

## Phase 1: Core Streaming (4-6 hours)

### 1.1 Create StreamPlayer Class

**File:** `MacAmpApp/Audio/StreamPlayer.swift` (new)

```swift
import AVFoundation
import Observation
import Combine

@MainActor
@Observable
final class StreamPlayer {
    // MARK: - State

    private(set) var isPlaying: Bool = false
    private(set) var isBuffering: Bool = false
    private(set) var currentStation: RadioStation?
    private(set) var streamTitle: String?
    private(set) var streamArtist: String?

    // MARK: - AVPlayer

    private let player = AVPlayer()
    private var statusObserver: AnyCancellable?
    private var timeObserver: Any?
    private var metadataObserver: AnyCancellable?

    // MARK: - Initialization

    init() {
        setupObservers()
    }

    // MARK: - Playback Control

    func play(station: RadioStation) async {
        currentStation = station

        let playerItem = AVPlayerItem(url: station.streamURL)
        player.replaceCurrentItem(with: playerItem)

        setupMetadataObserver(for: playerItem)

        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        currentStation = nil
        streamTitle = nil
        streamArtist = nil
    }

    // MARK: - Observers

    private func setupObservers() {
        // Observe playback status
        statusObserver = player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleStatusChange(status)
            }
    }

    private func handleStatusChange(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            isPlaying = true
            isBuffering = false
        case .paused:
            isPlaying = false
            isBuffering = false
        case .waitingToPlayAtSpecifiedRate:
            isBuffering = true
        @unknown default:
            break
        }
    }

    private func setupMetadataObserver(for item: AVPlayerItem) {
        // Observe timed metadata (ICY info from SHOUTcast)
        metadataObserver = item.publisher(for: \.timedMetadata)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metadata in
                self?.extractStreamMetadata(metadata)
            }
    }

    private func extractStreamMetadata(_ metadata: [AVMetadataItem]?) {
        guard let items = metadata else { return }

        for item in items {
            if let title = item.value(forKey: AVMetadataKey.commonKeyTitle.rawValue) as? String {
                streamTitle = title
            }
            if let artist = item.value(forKey: AVMetadataKey.commonKeyArtist.rawValue) as? String {
                streamArtist = artist
            }
        }
    }

    deinit {
        player.pause()
        statusObserver?.cancel()
        metadataObserver?.cancel()
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
    }
}
```

### 1.2 Create RadioStation Model

**File:** `MacAmpApp/Models/RadioStation.swift` (new)

```swift
import Foundation

struct RadioStation: Identifiable, Codable {
    let id: UUID
    let name: String
    let streamURL: URL
    let genre: String?
    let source: Source

    enum Source: Codable {
        case m3uPlaylist(String)  // From M3U file
        case manual              // User-added
        case directory           // From radio directory
    }

    init(id: UUID = UUID(), name: String, streamURL: URL, genre: String? = nil, source: Source = .manual) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.genre = genre
        self.source = source
    }
}
```

### 1.3 Create RadioStationLibrary

**File:** `MacAmpApp/Models/RadioStationLibrary.swift` (new)

```swift
import Foundation
import Observation

@MainActor
@Observable
final class RadioStationLibrary {
    private(set) var stations: [RadioStation] = []

    private let userDefaultsKey = "MacAmp.RadioStations"

    init() {
        loadStations()
    }

    func addStation(_ station: RadioStation) {
        // Check for duplicates
        if stations.contains(where: { $0.streamURL == station.streamURL }) {
            return
        }

        stations.append(station)
        saveStations()
    }

    func removeStation(id: UUID) {
        stations.removeAll { $0.id == id }
        saveStations()
    }

    func removeAll() {
        stations.removeAll()
        saveStations()
    }

    // MARK: - Persistence

    private func saveStations() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(stations)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save radio stations: \(error)")
        }
    }

    private func loadStations() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }

        do {
            let decoder = JSONDecoder()
            stations = try decoder.decode([RadioStation].self, from: data)
        } catch {
            print("Failed to load radio stations: \(error)")
            stations = []
        }
    }
}
```

### 1.4 Update AudioPlayer for Mode Switching

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

**Add properties:**
```swift
enum PlaybackSource {
    case localFile
    case stream
}

private(set) var playbackSource: PlaybackSource = .localFile
```

**Add method to detect source:**
```swift
private func sourceType(for url: URL) -> PlaybackSource {
    if url.isFileURL {
        return .localFile
    } else if url.scheme == "http" || url.scheme == "https" {
        return .stream
    }
    return .localFile
}
```

---

## Phase 2: M3U/M3U8 Integration (3 hours)

### 2.1 Update M3U/M3U8 Loading

**Note:** M3UParser already supports both .m3u and .m3u8 playlist files, plus .m3u8 HLS stream URLs (handled by AVPlayer).

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

**Replace Lines 503-506:**
```swift
// OLD:
if entry.isRemoteStream {
    print("M3U: Found stream: \(entry.title ?? entry.url.absoluteString)")
    // TODO: Add to internet radio library when P5 is implemented
}

// NEW:
if entry.isRemoteStream {
    let station = RadioStation(
        name: entry.title ?? "Unknown Station",
        streamURL: entry.url,
        genre: nil,
        source: .m3uPlaylist(url.lastPathComponent)
    )
    radioLibrary.addStation(station)
    print("M3U: Added station: \(station.name)")
}
```

### 2.2 Inject RadioStationLibrary

**File:** `MacAmpApp/MacAmpApp.swift`

```swift
@main
struct MacAmpApp: App {
    @State private var skinManager = SkinManager()
    @State private var audioPlayer = AudioPlayer()
    @State private var dockingController = DockingController()
    @State private var settings = AppSettings.instance()
    @State private var radioLibrary = RadioStationLibrary()  // Add this

    var body: some Scene {
        WindowGroup {
            UnifiedDockView()
                .environment(skinManager)
                .environment(audioPlayer)
                .environment(dockingController)
                .environment(settings)
                .environment(radioLibrary)  // Add this
        }
        // ...
    }
}
```

---

## Phase 3: UI Integration (3 hours)

### 3.1 Station Selection UI

**Option A: Separate Radio Window**
- New window for radio stations
- Browse/play from station list
- Separate from playlist

**Option B: Mixed Playlist**
- Radio stations appear in playlist
- Mixed with local tracks
- Icon to distinguish streams

**Option C: Add Menu**
- ADD button menu includes "Add Stream URL"
- Paste URL dialog
- Adds to both library and playlist

**Recommendation:** Start with Option C (simplest)

### 3.2 Add Stream URL Dialog

**In WinampPlaylistWindow.swift:**
```swift
private func presentAddStreamDialog() {
    let alert = NSAlert()
    alert.messageText = "Add Internet Radio Station"
    alert.informativeText = "Enter the stream URL:"

    let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
    input.placeholderString = "http://stream.example.com/radio.mp3"
    alert.accessoryView = input

    alert.addButton(withTitle: "Add")
    alert.addButton(withTitle: "Cancel")

    if alert.runModal() == .alertFirstButtonReturn {
        if let urlString = input.stringValue.isEmpty ? nil : input.stringValue,
           let url = URL(string: urlString),
           url.scheme == "http" || url.scheme == "https" {
            let station = RadioStation(name: urlString, streamURL: url)
            radioLibrary.addStation(station)
        }
    }
}
```

---

## Implementation Files

### Files to Create (4)
1. `MacAmpApp/Audio/StreamPlayer.swift` - AVPlayer wrapper (~150 lines)
2. `MacAmpApp/Models/RadioStation.swift` - Data model (~30 lines)
3. `MacAmpApp/Models/RadioStationLibrary.swift` - Persistence (~80 lines)
4. `MacAmpApp/Views/RadioStationView.swift` - Optional UI (~100 lines)

### Files to Modify (3)
1. `MacAmpApp/Views/WinampPlaylistWindow.swift` - M3U/M3U8 integration (Line 503-506)
2. `MacAmpApp/MacAmpApp.swift` - Inject RadioStationLibrary
3. `MacAmpApp/Audio/AudioPlayer.swift` - Optional: Playback mode detection

**Note:** M3UParser (MacAmpApp/Models/M3UParser.swift) already supports both .m3u and .m3u8 playlist files.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| No EQ for streams | Certain | Medium | Document limitation, acceptable trade-off |
| Buffering issues | Medium | High | AVPlayer handles automatically, test various streams |
| Mode switching bugs | Medium | High | Clear state management, thorough testing |
| Metadata not available | Low | Low | Not all streams have metadata, graceful fallback |
| Network errors | High | Medium | Comprehensive error handling, user feedback |

---

## Testing Strategy

### Phase 1 Testing
- [ ] Play SomaFM Groove Salad stream
- [ ] Verify audio plays
- [ ] Test play/pause/stop
- [ ] Switch to local file and back
- [ ] Check for audio conflicts

### Phase 2 Testing
- [ ] Load DarkAmbientRadio.m3u (playlist file)
- [ ] Load .m3u8 playlist file (UTF-8 encoded)
- [ ] Test .m3u8 HLS stream URL (e.g., SomaFM)
- [ ] Verify stations added to library
- [ ] Play station from library
- [ ] Test mixed M3U (local + remote)
- [ ] Verify persistence (quit/relaunch)

### Phase 3 Testing
- [ ] Add stream via URL dialog
- [ ] Test invalid URLs
- [ ] Test network interruption
- [ ] Test metadata display
- [ ] Test buffering indicator

---

## Rollout Plan

### Day 1: Core Streaming (4-6 hours)
- Create StreamPlayer class
- Create RadioStation model
- Create RadioStationLibrary
- Basic play/pause functionality
- Test with SomaFM streams

### Day 2: M3U/M3U8 Integration (3 hours)
- Update WinampPlaylistWindow M3U/M3U8 loading
- Inject RadioStationLibrary
- Test loading stations from M3U/M3U8 playlists
- Test M3U8 HLS stream URLs
- Verify persistence

### Day 3: UI Polish (3 hours)
- Add Stream URL dialog
- Station selection UI
- Metadata display
- Error handling
- Buffering indicators

---

## Dependencies

### System Requirements
- macOS 15+ (already targeting)
- Swift 6 (already using)
- AVFoundation (already have)

### Entitlements
- ✅ com.apple.security.network.client (already have)

### Info.plist
- ✅ NSAllowsArbitraryLoadsInMedia (already configured per docs)

### Framework Imports
```swift
import AVFoundation  // Already using
import Combine       // For KVO publishers
```

---

## Success Metrics

- [ ] Can play 10+ different radio stations
- [ ] Stream starts within 2 seconds
- [ ] No audio glitches when switching modes
- [ ] Metadata updates in real-time
- [ ] Network errors handled gracefully
- [ ] State persists across restarts

---

## References

- Research: tasks/internet-radio/research.md
- Existing: tasks/internet-radio-file-types/
- M3U Parser: MacAmpApp/Models/M3UParser.swift
- Current Player: MacAmpApp/Audio/AudioPlayer.swift

---

## ORACLE CRITICAL ADDITION: PlaybackCoordinator

### Why Needed (Oracle)

**Problem without coordinator:**
- StreamPlayer and AudioPlayer operate independently
- Could play both simultaneously (audio chaos!)
- No unified playback state
- UI talks to 2 separate players

**Solution: PlaybackCoordinator**

**File:** `MacAmpApp/Audio/PlaybackCoordinator.swift` (new, REQUIRED)

```swift
import Foundation
import Observation

@MainActor
@Observable
final class PlaybackCoordinator {
    // MARK: - Dependencies

    private let audioPlayer: AudioPlayer       // Local files with EQ
    private let streamPlayer: StreamPlayer     // Internet radio

    // MARK: - Unified State

    private(set) var isPlaying: Bool = false
    private(set) var isPaused: Bool = false
    private(set) var currentSource: PlaybackSource?
    private(set) var currentTitle: String?

    enum PlaybackSource {
        case localTrack(URL)
        case radioStation(RadioStation)
    }

    // MARK: - Initialization

    init(audioPlayer: AudioPlayer, streamPlayer: StreamPlayer) {
        self.audioPlayer = audioPlayer
        self.streamPlayer = streamPlayer
    }

    // MARK: - Unified Playback Control

    func play(url: URL) async {
        if url.isFileURL {
            // Stop stream if playing
            streamPlayer.stop()

            // Play local file with EQ
            audioPlayer.play(url: url)
            currentSource = .localTrack(url)
            currentTitle = url.deletingPathExtension().lastPathComponent
        } else {
            // Stop local file if playing
            audioPlayer.stop()

            // Play stream (no EQ)
            let station = RadioStation(name: url.lastPathComponent, streamURL: url)
            await streamPlayer.play(station: station)
            currentSource = .radioStation(station)
            currentTitle = streamPlayer.streamTitle ?? station.name
        }

        isPlaying = true
        isPaused = false
    }

    func pause() {
        switch currentSource {
        case .localTrack:
            audioPlayer.pause()
        case .radioStation:
            streamPlayer.pause()
        case .none:
            break
        }

        isPlaying = false
        isPaused = true
    }

    func stop() {
        audioPlayer.stop()
        streamPlayer.stop()
        isPlaying = false
        isPaused = false
        currentSource = nil
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if isPaused {
            resume()
        }
    }

    private func resume() {
        switch currentSource {
        case .localTrack:
            audioPlayer.play()
        case .radioStation:
            // Stream resumes automatically
            break
        case .none:
            break
        }

        isPlaying = true
        isPaused = false
    }

    // MARK: - State Observers

    func observePlaybackState() {
        // Observe both players and update unified state
        // Details in implementation phase
    }
}
```

**Integration:**
- UI talks ONLY to PlaybackCoordinator
- Coordinator owns both players
- Prevents conflicts
- Clean API

**Effort:** +2-3 hours (Oracle estimate)

---

## Oracle-Corrected Time Estimates

| Phase | Original | Oracle-Corrected | Reason |
|-------|----------|------------------|--------|
| Phase 1 | 4-6 hours | 6-8 hours | +PlaybackCoordinator, +observer fixes |
| Phase 2 | 2 hours | 3 hours | +Library injection, +playlist integration |
| Phase 3 | 3 hours | 3 hours | Same |
| **Total** | **9-11 hours** | **12-15 hours** | More realistic with coordinator |

---

## Oracle-Required Code Corrections

### StreamPlayer Observer Cleanup

```swift
// Oracle: Cancel old observer before new one
private func setupMetadataObserver(for item: AVPlayerItem) {
    metadataObserver?.cancel()  // ← Add this!

    metadataObserver = item.publisher(for: \.timedMetadata)
        .receive(on: RunLoop.main)  // ← Changed from DispatchQueue.main
        .sink { [weak self] metadata in
            self?.extractStreamMetadata(metadata)
        }
}
```

### Metadata Extraction

```swift
// Oracle: Use commonKey and stringValue, not KVC
private func extractStreamMetadata(_ metadata: [AVMetadataItem]?) {
    guard let items = metadata else { return }

    for item in items {
        if item.commonKey == .commonKeyTitle,
           let title = item.stringValue {  // ← stringValue not value(forKey:)
            streamTitle = title
        }
        if item.commonKey == .commonKeyArtist,
           let artist = item.stringValue {
            streamArtist = artist
        }
    }
}
```

### Add Status Observer

```swift
// Oracle: Observe status for error detection
private func setupObservers() {
    // Existing: timeControlStatus

    // ADD: Status observer for errors
    player.publisher(for: \.currentItem?.status)
        .receive(on: RunLoop.main)
        .sink { [weak self] status in
            if status == .failed {
                self?.handlePlaybackError()
            }
        }
}
```

---

## Oracle Recommendations Summary

1. **MUST ADD:** PlaybackCoordinator (critical)
2. **FIX:** Observer cleanup in StreamPlayer
3. **FIX:** Metadata extraction method
4. **ADD:** Status observer for errors
5. **UPDATE:** Time estimates (12-15 hours)
6. **VERIFY:** Info.plist (already has NSAllowsArbitraryLoadsInMedia)
7. **CONSIDER:** Streams in playlist order (UX improvement)

---

**Oracle Approval Status:** ✅ Architecture valid, implement with corrections
**Blocking Issues:** None (corrections can be done during implementation)
**Ready:** For user approval and implementation

---
---

# Phase 4: Playlist Integration & Playback UI (Added 2025-10-31)

**Status:** 📋 Planning (User-Requested Extension)
**Trigger:** Gap discovered - streams not in playlist like Winamp
**Effort:** 3-4 hours estimated (3-4 commits)

---

## Why Phase 4 is Needed

### User-Reported Gap

**Winamp Actual Behavior:**
- Streams appear in playlist alongside local files
- Click stream in playlist → plays immediately
- M3U populates playlist with ALL entries (local + remote)
- Shows "Connecting..." / buffering status in track display

**Our Implementation (Phases 1-3):**
- Streams go to RadioStationLibrary (separate storage)
- NOT visible in playlist
- M3U: local files → playlist, streams → library
- No way to play streams from UI

**Gap:** UX integration, not architecture

---

## Phase 4 Objectives

### Must Have
1. ✅ Streams appear as playlist items
2. ✅ Click stream in playlist → plays via PlaybackCoordinator
3. ✅ M3U populates playlist with both local + remote
4. ✅ ADD URL adds stream to playlist (not just library)

### Nice to Have (defer if complex)
5. ⏸️ "Connecting..." message during stream buffering
6. ⏸️ "buffer 0%" message on network issues

---

## Phase 4: Technical Approach

### 4.1 Extend Track Model for Streams

**Current Track** (AudioPlayer.swift:68-78):
```swift
struct Track: Identifiable, Equatable {
    let id = UUID()
    let url: URL          // Currently file:// only
    var title: String     // Mutable (good for metadata updates)
    var artist: String    // Mutable (good for metadata updates)
    var duration: Double  // Used for position slider
}
```

**Phase 4: Allow http/https URLs** (Option A - Simple):

```swift
struct Track: Identifiable, Equatable {
    let id = UUID()
    let url: URL          // NOW: file://, http://, https://
    var title: String     // Stream: station name or streamPlayer.streamTitle
    var artist: String    // Stream: streamPlayer.streamArtist
    var duration: Double  // Stream: 0.0 (infinity) or -1.0 (unknown)

    // Add computed property
    var isStream: Bool {
        !url.isFileURL && (url.scheme == "http" || url.scheme == "https")
    }
}
```

**Why Option A (not enum):**
- Minimal changes to existing code
- Track already has mutable title/artist (perfect for live metadata)
- Playlist UI already renders Track items
- Duration 0.0 for streams (no position slider needed)

**Alternative (Oracle to confirm):** Enum approach would require changing:
- `playlist: [Track]` → `playlist: [PlaylistItem]`
- All playlist iteration code
- UI rendering logic
- More invasive changes

**Oracle Question:** Is Option A (simple URL extension) acceptable?

---

### 4.2 Update M3U/M3U8 Loading

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

**Current (Phase 3):**
```swift
if entry.isRemoteStream {
    // Only adds to library
    radioLibrary.addStation(station)
    addedStations += 1
} else {
    audioPlayer.addTrack(url: entry.url)
}
```

**Phase 4: Add to Playlist ONLY:**
```swift
if entry.isRemoteStream {
    // Add to playlist as Track (Winamp behavior)
    // RadioStationLibrary is ONLY for favorites menu (future feature)
    let streamTrack = Track(
        url: entry.url,
        title: entry.title ?? "Unknown Station",
        artist: "Internet Radio",
        duration: 0.0  // Infinite stream
    )
    audioPlayer.playlist.append(streamTrack)
    addedStreams += 1
} else {
    // Local file - add to playlist via AudioPlayer
    audioPlayer.addTrack(url: entry.url)
}
```

**Result:** Mixed M3U shows ALL items in playlist (like Winamp)

**Architecture Note:** RadioStationLibrary reserved for favorites menu (Phase 5+)

---

### 4.3 Wire Playlist Selection to PlaybackCoordinator

**Current:** Playlist click → `audioPlayer.playTrack(track:)`

**Phase 4:** Route through PlaybackCoordinator

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

**Add method:**
```swift
private func playSelectedTrack(_ track: Track) async {
    if track.isStream {
        // Play via StreamPlayer (no EQ)
        await playbackCoordinator.play(url: track.url)

        // Update track metadata from stream (async)
        // title/artist will update from streamPlayer observers
    } else {
        // Play via AudioPlayer (with EQ)
        audioPlayer.playTrack(track: track)
    }
}
```

**Find:** Where playlist items are clicked
**Update:** Replace `audioPlayer.playTrack()` with `playSelectedTrack()`

**Challenges:**
- PlaybackCoordinator needs to be injected
- Need to handle async calls from UI
- Track metadata updates from StreamPlayer

**Oracle Question:** Best way to wire this? Environment injection or pass through?

---

### 4.4 ADD URL: Add to Playlist ONLY

**Current (Commit 6):**
```swift
// Only adds to RadioStationLibrary (WRONG for Winamp behavior)
radioLibrary.addStation(station)
showAlert("Station Added", "Added to your radio library...")
```

**Phase 4 (Corrected):**
```swift
// Add to playlist as Track (Winamp behavior)
// RadioStationLibrary is ONLY for favorites menu (future)
let streamTrack = Track(
    url: url,
    title: stationName,
    artist: "Internet Radio",
    duration: 0.0
)
audioPlayer.playlist.append(streamTrack)

showAlert("Stream Added", "Added to playlist. Click to play!")
```

**Result:** User sees stream in playlist immediately (like Winamp)

**Note:** "Add to Favorites" would be separate menu option (Phase 5+)

---

### 4.5 Buffering Message Display (Optional)

**User Context:**
> "Using same sprites/methods as track scrolling - just inserting message instead of track"

**Current Display** (WinampMainWindow.swift:565):
```swift
let trackText = audioPlayer.currentTitle.isEmpty ? "MacAmp" : audioPlayer.currentTitle
// This scrolls using buildTextSprites()
```

**Phase 4 Approach (Trivial):**

**Option 1: Computed Property**
```swift
// In PlaybackCoordinator or AudioPlayer
var displayTitle: String {
    if streamPlayer.isBuffering {
        return "Connecting..."
    }
    if let error = streamPlayer.error {
        return "buffer 0%"  // Or error message
    }
    return currentTitle
}
```

**Option 2: Direct Update**
```swift
// When stream starts buffering
if streamPlayer.isBuffering {
    audioPlayer.currentTitle = "Connecting..."
}

// When stream plays
if streamPlayer.isPlaying {
    audioPlayer.currentTitle = streamPlayer.streamTitle ?? station.name
}
```

**Assessment:** TRIVIAL - it's just string replacement

**Oracle Question:** Which option is cleaner? Should we defer or include?

---

## Phase 4: Implementation Plan

### Step 1: Extend Track for Streams (Commit 8)

**Files to Modify:**
- `MacAmpApp/Audio/AudioPlayer.swift` - Add `Track.isStream` computed property

**Changes:**
```swift
struct Track: Identifiable, Equatable {
    // ... existing properties ...

    /// Returns true if this track is an internet radio stream
    var isStream: Bool {
        !url.isFileURL && (url.scheme == "http" || url.scheme == "https")
    }
}
```

**Test:** Build, ensure no regressions

**Effort:** 15 minutes

---

### Step 2: Update M3U Loading (Commit 9)

**Files to Modify:**
- `MacAmpApp/Views/WinampPlaylistWindow.swift` - loadM3UPlaylist()

**Changes:**
1. When `entry.isRemoteStream`:
   - Add to RadioStationLibrary (favorites)
   - Create Track with stream URL
   - Append to audioPlayer.playlist
2. Update user feedback message

**Test:** Load M3U with streams, verify all items in playlist

**Effort:** 30-45 minutes

---

### Step 3: Wire Playlist Selection (Commit 10)

**Files to Modify:**
- `MacAmpApp/MacAmpApp.swift` - Create and inject PlaybackCoordinator
- `MacAmpApp/Views/WinampPlaylistWindow.swift` - Wire playlist click

**Changes:**
1. Create PlaybackCoordinator in MacAmpApp
2. Inject via environment
3. Update playlist item click handler
4. Route streams through PlaybackCoordinator

**Test:** Click stream in playlist, verify plays

**Effort:** 1-1.5 hours

---

### Step 4: Buffering Status Display (Commit 11 - Optional)

**Files to Modify:**
- `MacAmpApp/Audio/PlaybackCoordinator.swift` - Add displayTitle computed property
- `MacAmpApp/Views/WinampMainWindow.swift` - Use displayTitle

**Changes:**
1. Add `displayTitle` that returns "Connecting..." when buffering
2. Update track display to use displayTitle
3. Handle error state ("buffer 0%")

**Test:** Play stream, verify "Connecting..." shows, then track title

**Effort:** 30-45 minutes

---

### Step 5: ADD URL to Playlist (Commit 11 or 12)

**Files to Modify:**
- `MacAmpApp/Views/WinampPlaylistWindow.swift` - addURL()

**Changes:**
1. Add stream to RadioStationLibrary (existing)
2. ALSO add as Track to playlist
3. Update user feedback

**Test:** ADD URL, verify appears in playlist

**Effort:** 15-30 minutes

---

## Phase 4: Oracle-Corrected Effort Estimate

**Oracle Review:** ⚠️ Phase 4 is FULL coordinator migration, not just playlist integration

| Step | Task | My Estimate | Oracle | Why |
|------|------|-------------|--------|-----|
| 1 | Track + guards | 15 min | 30 min | Guards in AudioPlayer |
| 2 | M3U/ADD URL fix | 45 min | 1 hour | Remove library, thorough test |
| 3 | StreamPlayer URL method | - | 30 min | New overload needed |
| 4 | Coordinator methods | 1.5 hours | 1 hour | next/previous/play(track) |
| 5 | Wire ALL controls | - | 2-3 hours | Playlist + transport + shortcuts |
| 6 | Update ALL UI bindings | 45 min | 1.5 hours | Every view using audioPlayer |
| 7 | Buffering + testing | 45 min | 1-2 hours | Display + regression |

**Total:** ~~3.75 hours~~ → **6-8 hours** (Oracle corrected)

**Commits:** ~~4~~ → **7 commits** (more extensive)

---

## Phase 4: Oracle-Corrected Commit Strategy

**Oracle:** This is a full coordinator migration - 7 commits, 6-8 hours

**Commit 13:** Extend Track + add AudioPlayer guards (30 min)
- Add `Track.isStream` computed property
- Add guard in `AudioPlayer.playTrack()` to prevent crashes
- Fail gracefully if stream URL attempted

**Commit 14:** Fix M3U + ADD URL (playlist ONLY) (1 hour)
- **REMOVE** all `radioLibrary.addStation()` calls
- Streams append to `audioPlayer.playlist` as Tracks
- Update user feedback messages
- Test with mixed M3U

**Commit 15:** Add StreamPlayer.play(url:) overload (30 min)
- Add URL-based play method (not just RadioStation)
- Support playlist-driven playback
- Preserve metadata from Track

**Commit 16:** Extend PlaybackCoordinator transport (1 hour)
- Add `play(track: Track)` overload
- Add `next()`, `previous()` methods
- Add `displayTitle`, `displayArtist` properties
- Add `currentTrack` property

**Commit 17:** Wire ALL playback controls (2-3 hours)
- Playlist double-click → coordinator
- Next/Previous buttons → coordinator
- Play/Pause/Stop buttons → coordinator
- Keyboard shortcuts → coordinator
- AppCommands → coordinator

**Commit 18:** Update ALL UI bindings (1.5 hours)
- WinampMainWindow: Use `coordinator.displayTitle`
- WinampMainWindow: Use coordinator state
- WinampPlaylistWindow shade mode: Use coordinator
- Test all UI updates

**Commit 19:** Buffering display + final testing (1 hour)
- Add "Connecting..." / "buffer 0%" logic
- Comprehensive regression testing
- Verify Winamp parity

**Total:** 6-8 hours, 7 commits (Oracle approved)

---

## Phase 4: Success Criteria

### Functional Requirements
- [x] Click stream in playlist → plays audio
- [x] M3U files populate playlist with local + remote
- [x] ADD URL adds stream to playlist (visible immediately)
- [x] Stream metadata updates in real-time
- [x] Switching local ↔ stream works smoothly
- [x] No audio conflicts or crashes

### Winamp Parity
- [x] Streams are playlist items (not separate)
- [x] Mixed playlists work correctly
- [x] (Optional) Buffering status display

### Technical Quality
- [x] Swift 6 compliant
- [x] No force unwraps
- [x] Proper error handling
- [x] Observable state updates
- [x] Builds successfully

---

## Phase 4: Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Track model changes break existing code | Low | High | Thorough testing, computed property only |
| Playlist rendering issues with streams | Medium | Medium | Test with mixed playlists |
| PlaybackCoordinator wiring complex | Low | Medium | Clear injection pattern |
| Metadata updates cause UI flicker | Low | Low | Use @Observable properly |
| Buffering message implementation complex | Very Low | Low | Oracle says trivial, just string |

---

## Phase 4: Testing Strategy

### Build Testing
- [ ] Extend Track → Build succeeds
- [ ] M3U changes → Build succeeds
- [ ] Coordinator wiring → Build succeeds
- [ ] Final build with all changes

### Functional Testing
- [ ] Load M3U with 2 local + 2 remote → See all 4 in playlist
- [ ] Click local file → Plays via AudioPlayer
- [ ] Click stream → Plays via StreamPlayer
- [ ] Verify metadata updates
- [ ] Test buffering status display
- [ ] Verify no audio conflicts

### Regression Testing
- [ ] Local file playback still works
- [ ] EQ still works for local files
- [ ] Playlist operations work (add/remove/reorder)
- [ ] M3U local-only files still work

---

## Phase 4: Oracle Review Points

**Pending Oracle Consultation on:**

1. **Track Extension Strategy** - Simple URL extension vs enum?
2. **Buffering Message** - Confirm it's trivial (just string replacement)?
3. **Effort Estimate** - 3-4 hours realistic?
4. **Storage Strategy** - Keep RadioStationLibrary for favorites?
5. **Any architectural concerns** with playlist integration?

**Status:** Awaiting Oracle response before implementation

---

---

## Phase 4: Oracle-Corrected Implementation Steps

### Commit 13: Extend Track Model + Add Guards (30 min)

**Files to Modify:**
- `MacAmpApp/Audio/AudioPlayer.swift`

**Changes:**
1. Add to Track struct:
```swift
/// Returns true if this track is an internet radio stream
var isStream: Bool {
    !url.isFileURL && (url.scheme == "http" || url.scheme == "https")
}
```

2. Add guard in playTrack():
```swift
func playTrack(track: Track) {
    guard !track.isStream else {
        print("ERROR: Cannot play stream via AudioPlayer - use PlaybackCoordinator")
        return
    }
    // ... existing code
}
```

**Testing:**
- [ ] Build succeeds
- [ ] isStream returns correct value
- [ ] Attempting to play stream via AudioPlayer fails gracefully

**Effort:** 30 minutes (Oracle)

---

### Commit 14: Fix M3U + ADD URL (Playlist ONLY) (1 hour)

**CRITICAL:** Streams go to **playlist ONLY**, NOT RadioStationLibrary

**Files to Modify:**
- `MacAmpApp/Views/WinampPlaylistWindow.swift`

**loadM3UPlaylist() Changes:**
```swift
if entry.isRemoteStream {
    // Add to playlist as Track (Winamp behavior)
    let streamTrack = Track(
        url: entry.url,
        title: entry.title ?? "Unknown Station",
        artist: "Internet Radio",
        duration: 0.0  // Infinite stream
    )
    audioPlayer.playlist.append(streamTrack)
    addedStreams += 1
} else {
    // Local file to playlist
    audioPlayer.addTrack(url: entry.url)
}
```

**addURL() Changes:**
```swift
// Add to playlist as Track (NOT RadioStationLibrary)
let streamTrack = Track(
    url: url,
    title: stationName,
    artist: "Internet Radio",
    duration: 0.0
)
audioPlayer.playlist.append(streamTrack)

showAlert("Stream Added", "Added to playlist. Click to play!")
```

**Note:** RadioStationLibrary is for **favorites menu only** (future feature)

**Testing:**
- [ ] Load M3U → All items in playlist
- [ ] ADD URL → Stream in playlist
- [ ] Streams visible in UI

**Effort:** 1 hour (Oracle)

---

### Commit 15: Add StreamPlayer.play(url:) Overload (30 min)

**Files to Modify:**
- `MacAmpApp/Audio/StreamPlayer.swift`

**Changes:**
```swift
// Add URL-based play method for playlist tracks
func play(url: URL, title: String? = nil, artist: String? = nil) async {
    // Create internal RadioStation
    let station = RadioStation(
        name: title ?? url.host ?? "Internet Radio",
        streamURL: url
    )
    await play(station: station)
}
```

**Testing:**
- [ ] Can play stream from URL
- [ ] Metadata preserved if provided
- [ ] Falls back to URL host for title

**Effort:** 30 minutes (Oracle)

---

### Commit 16: Extend PlaybackCoordinator Transport (1 hour)

**Files to Modify:**
- `MacAmpApp/Audio/PlaybackCoordinator.swift`

**Changes:**
1. Add `play(track: Track)` overload:
```swift
func play(track: Track) async {
    if track.isStream {
        streamPlayer.stop()
        await streamPlayer.play(url: track.url, title: track.title, artist: track.artist)
        currentSource = .radioStation(/* temp */)
        currentTrack = track
    } else {
        audioPlayer.stop()
        audioPlayer.playTrack(track: track)
        currentSource = .localTrack(track.url)
        currentTrack = track
    }
}
```

2. Add transport methods:
```swift
func next() async {
    // Delegate to audioPlayer for playlist navigation
    audioPlayer.nextTrack()
}

func previous() async {
    audioPlayer.previousTrack()
}
```

3. Add unified state:
```swift
var displayTitle: String {
    switch currentSource {
    case .radioStation:
        if streamPlayer.isBuffering { return "Connecting..." }
        if streamPlayer.error != nil { return "buffer 0%" }
        return streamPlayer.streamTitle ?? currentTrack?.title ?? "Internet Radio"
    case .localTrack:
        return currentTrack?.title ?? currentTitle ?? "Unknown"
    case .none:
        return "MacAmp"
    }
}

var displayArtist: String {
    streamPlayer.streamArtist ?? currentTrack?.artist ?? ""
}

var currentTrack: Track?
```

**Testing:**
- [ ] play(track:) works for both types
- [ ] next/previous delegate correctly
- [ ] displayTitle shows correct state

**Effort:** 1 hour (Oracle)

---

### Commit 17: Wire ALL Playback Controls (2-3 hours)

**ORACLE CRITICAL:** Not just playlist - ALL controls must route through coordinator

**Files to Modify:**
- `MacAmpApp/MacAmpApp.swift`
- `MacAmpApp/Views/WinampMainWindow.swift`
- `MacAmpApp/Views/WinampPlaylistWindow.swift`
- `MacAmpApp/AppCommands.swift` (if exists)

**MacAmpApp.swift:**
```swift
@State private var streamPlayer = StreamPlayer()

var playbackCoordinator: PlaybackCoordinator {
    PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)
}

.environment(playbackCoordinator)
```

**WinampPlaylistWindow.swift:**
```swift
@Environment(PlaybackCoordinator.self) var playbackCoordinator

// Playlist double-click (find existing handler):
Task {
    await playbackCoordinator.play(track: track)
}
```

**WinampMainWindow.swift - Transport Buttons:**
```swift
// Next button:
Button { Task { await playbackCoordinator.next() } }

// Previous button:
Button { Task { await playbackCoordinator.previous() } }

// Play/Pause button:
Button { playbackCoordinator.togglePlayPause() }

// Stop button:
Button { playbackCoordinator.stop() }
```

**Keyboard Shortcuts** (find existing):
- Space → `playbackCoordinator.togglePlayPause()`
- Z → `await playbackCoordinator.previous()`
- B → `await playbackCoordinator.next()`
- V → `playbackCoordinator.stop()`

**Testing:**
- [ ] Playlist click works for both types
- [ ] Next/Previous buttons work
- [ ] Play/Pause works
- [ ] Keyboard shortcuts work
- [ ] No audio conflicts during transitions

**Effort:** 2-3 hours (Oracle) - Many control points to wire

---

### Commit 18: Update ALL UI Bindings (1.5 hours)

**ORACLE:** Every view reading audioPlayer state must switch to coordinator

**Files to Modify:**
- `MacAmpApp/Views/WinampMainWindow.swift`
- `MacAmpApp/Views/WinampPlaylistWindow.swift`

**WinampMainWindow.swift Changes:**

1. Add environment:
```swift
@Environment(PlaybackCoordinator.self) var playbackCoordinator
```

2. Update title display (line ~565):
```swift
// OLD: let trackText = audioPlayer.currentTitle
// NEW: let trackText = playbackCoordinator.displayTitle
```

3. Update onChange observer (line ~577):
```swift
// OLD: .onChange(of: audioPlayer.currentTitle)
// NEW: .onChange(of: playbackCoordinator.displayTitle)
```

4. Update any other audioPlayer.currentTrack references

**WinampPlaylistWindow.swift Changes:**

1. Shade mode display:
```swift
// Use coordinator state for current track info
if let currentTrack = playbackCoordinator.currentTrack {
    Text("\(currentTrack.title) - \(currentTrack.artist)")
}
```

**Testing:**
- [ ] Title scrolls correctly for local files
- [ ] Title shows stream metadata
- [ ] "Connecting..." shows during buffering
- [ ] Shade mode displays correctly
- [ ] No UI glitches or flickers

**Effort:** 1.5 hours (Oracle) - Multiple UI surfaces

---

### Commit 19: Buffering Display + Final Testing (1 hour)

**Files to Modify:**
- Final polish and regression testing

**Changes:**
- Verify "Connecting..." displays correctly
- Verify "buffer 0%" on network issues
- Comprehensive regression testing:
  - [ ] Local files still work
  - [ ] Streams work from playlist
  - [ ] Next/Previous works for mixed playlists
  - [ ] Transport controls all functional
  - [ ] No audio conflicts
  - [ ] Metadata updates live
  - [ ] UI responds correctly

**Effort:** 1 hour (Oracle)

---

**Phase 4 Total:** 6-8 hours, 7 commits (Oracle corrected)

**Oracle Verdict:** ✅ Approved with corrections
**Scope:** Full coordinator migration (not just playlist integration)
**Complexity:** High - extensive refactoring of control flow and UI bindings
**Ready to Implement:** Yes, with Oracle-corrected scope and timeline