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
- ✅ M3U remote streams load into station library
- ✅ Save/load favorite stations
- ✅ Display stream metadata (title, artist)
- ✅ Handle network errors gracefully

### Polish (Phase 3)
- ✅ Buffering indicators
- ✅ Stream quality selection
- ✅ Station categories/genres
- ✅ Export station library as M3U

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

## Phase 2: M3U Integration (2 hours)

### 2.1 Update M3U Loading

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
1. `MacAmpApp/Views/WinampPlaylistWindow.swift` - M3U integration (Line 503-506)
2. `MacAmpApp/MacAmpApp.swift` - Inject RadioStationLibrary
3. `MacAmpApp/Audio/AudioPlayer.swift` - Optional: Playback mode detection

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
- [ ] Load DarkAmbientRadio.m3u
- [ ] Verify station added to library
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

### Day 2: M3U Integration (2 hours)
- Update WinampPlaylistWindow M3U loading
- Inject RadioStationLibrary
- Test loading stations from M3U
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
ORACLE_REVIEW.md
echo "✅ Created ORACLE_REVIEW.md"