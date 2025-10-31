# Building Retro macOS Apps - Skills & Lessons Learned

**Source:** Internet Radio Streaming Implementation (MacAmp)
**Date:** October 2025
**Context:** Adding HTTP/HTTPS streaming to a Winamp clone for macOS 15+

---

## Table of Contents

1. [Architecture Patterns](#architecture-patterns)
2. [Swift 6 / Modern macOS](#swift-6--modern-macos)
3. [AVFoundation Dual-Backend](#avfoundation-dual-backend)
4. [Common Bug Patterns](#common-bug-patterns)
5. [API Migration](#api-migration)
6. [Testing & Validation](#testing--validation)
7. [Development Process](#development-process)
8. [Retro App Specifics](#retro-app-specifics)

---

## Architecture Patterns

### Dual-Backend Audio Systems

**Problem:** Need both EQ (local files) and streaming (HTTP/HTTPS)

**Why Dual Backend is Necessary:**

```swift
// Local Files: AVAudioEngine
AVAudioPlayerNode → AVAudioUnitEQ → mainMixerNode → [audio tap] → outputNode
✅ 10-band EQ
✅ Visualizers (spectrum, oscilloscope)
❌ Cannot stream HTTP

// Internet Radio: AVPlayer
AVPlayer → System Audio Output
✅ HTTP/HTTPS streaming
✅ HLS adaptive streaming
❌ No EQ (cannot use AVAudioUnitEQ)
❌ No visualizers (no audio tap)
```

**Cannot Merge:** AVPlayer cannot feed AVAudioEngine. They are separate systems.

**Solution Pattern:**
```swift
PlaybackCoordinator
├── AudioPlayer (local files)
└── StreamPlayer (internet radio)
```

**Key Insight:** Coordinator prevents both from playing simultaneously (would cause audio chaos).

---

### PlaybackCoordinator Pattern

**Purpose:** Single source of truth for playback state when using multiple audio backends.

**Responsibilities:**
1. Route playback to appropriate backend
2. Prevent simultaneous playback
3. Expose unified state for UI
4. Handle transport controls (play/pause/next/previous)

**Critical Implementation Details:**

```swift
@MainActor
@Observable
final class PlaybackCoordinator {
    private let audioPlayer: AudioPlayer
    private let streamPlayer: StreamPlayer

    func play(track: Track) async {
        if track.isStream {
            audioPlayer.stop()  // Prevent dual playback
            await streamPlayer.play(url: track.url)
        } else {
            streamPlayer.stop()  // Prevent dual playback
            audioPlayer.playTrack(track: track)
        }
    }
}
```

**Common Mistake:** Making coordinator a computed property:
```swift
// ❌ WRONG - creates new instance every render
var playbackCoordinator: PlaybackCoordinator {
    PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)
}

// ✅ CORRECT - persistent instance
@State private var playbackCoordinator: PlaybackCoordinator

init() {
    let ap = AudioPlayer()
    let sp = StreamPlayer()
    let coord = PlaybackCoordinator(audioPlayer: ap, streamPlayer: sp)
    _playbackCoordinator = State(initialValue: coord)
}
```

**Why It Matters:** Computed property resets state on every SwiftUI render → currentSource becomes .none → UI shows wrong info.

---

## Swift 6 / Modern macOS

### @MainActor @Observable Pattern

**Best Practice for State Management:**

```swift
@MainActor
@Observable
final class StreamPlayer {
    private(set) var isPlaying: Bool = false
    private(set) var streamTitle: String?
}
```

**Why:**
- `@MainActor` ensures all property updates on main thread
- `@Observable` provides fine-grained SwiftUI reactivity
- `private(set)` prevents external mutation

**Observer Pattern:**
```swift
// ✅ Use RunLoop.main (not DispatchQueue.main) for @MainActor
player.publisher(for: \.timeControlStatus)
    .receive(on: RunLoop.main)  // ← RunLoop.main for @MainActor
    .sink { [weak self] status in
        self?.handleStatusChange(status)
    }
```

---

### @preconcurrency for Non-Sendable Frameworks

**Problem:** AVFoundation types aren't Sendable in Swift 6

**Solution:**
```swift
@preconcurrency import AVFoundation

final class StreamPlayer: NSObject, @preconcurrency AVPlayerItemMetadataOutputPushDelegate {
    // ...
}
```

**Why Needed:**
- AVFoundation predates Swift 6 Sendable
- `@preconcurrency` bridges old frameworks to new concurrency model
- Tells compiler to trust you that it's safe

**Delegate Pattern:**
```swift
nonisolated func metadataOutput(...groups: [AVTimedMetadataGroup]...) {
    // Delegate called on DispatchQueue.main (set in setDelegate)
    MainActor.assumeIsolated {
        for group in groups {
            // Process on main actor
        }
    }
}
```

---

### Environment Injection for Multi-Instance Components

**Pattern for components that need initialization:**

```swift
@main
struct MacAmpApp: App {
    @State private var audioPlayer: AudioPlayer
    @State private var streamPlayer: StreamPlayer
    @State private var playbackCoordinator: PlaybackCoordinator

    init() {
        let ap = AudioPlayer()
        let sp = StreamPlayer()
        let coord = PlaybackCoordinator(audioPlayer: ap, streamPlayer: sp)

        _audioPlayer = State(initialValue: ap)
        _streamPlayer = State(initialValue: sp)
        _playbackCoordinator = State(initialValue: coord)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(audioPlayer)
                .environment(playbackCoordinator)
        }
    }
}
```

**Why This Pattern:**
- Components need each other during initialization
- Can't use other @State properties in init
- Create locals, initialize dependencies, then assign to _property

---

## AVFoundation Dual-Backend

### When to Use AVAudioEngine vs AVPlayer

**AVAudioEngine (Local Files):**
- ✅ Full control over audio processing
- ✅ Can add audio units (EQ, reverb, etc.)
- ✅ Audio tap for visualizers
- ✅ Precise sample-level control
- ❌ Requires AVAudioFile (local files only)
- ❌ Cannot stream HTTP/HTTPS

**AVPlayer (Streaming):**
- ✅ Native HTTP/HTTPS streaming
- ✅ HLS adaptive streaming
- ✅ Automatic buffering
- ✅ ICY metadata extraction
- ❌ No custom audio processing (no EQ)
- ❌ No audio tap (no visualizers)
- ❌ High-level only (less control)

**Decision Matrix:**
- Need EQ or visualizers? → AVAudioEngine
- Need HTTP streaming? → AVPlayer
- Need both? → Dual backend with coordinator

---

### Metadata Extraction (Modern API)

**Deprecated Pattern (macOS 10.15):**
```swift
// ❌ DEPRECATED
item.publisher(for: \.timedMetadata)
    .sink { metadata in
        if let title = item.stringValue { // Also deprecated
            streamTitle = title
        }
    }
```

**Modern Pattern (macOS 15+):**
```swift
// ✅ MODERN
private var currentMetadataOutput: AVPlayerItemMetadataOutput?

func setupMetadataObserver(for item: AVPlayerItem) {
    let output = AVPlayerItemMetadataOutput(identifiers: nil)
    output.setDelegate(self, queue: DispatchQueue.main)
    item.add(output)
    currentMetadataOutput = output
}

// Delegate method
nonisolated func metadataOutput(
    _ output: AVPlayerItemMetadataOutput,
    didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
    from track: AVPlayerItemTrack?
) {
    MainActor.assumeIsolated {
        for group in groups {
            for item in group.items {
                if item.commonKey == .commonKeyTitle {
                    Task { @MainActor in
                        streamTitle = try? await item.load(.stringValue)
                    }
                }
            }
        }
    }
}
```

**Key Changes:**
1. Use `AVPlayerItemMetadataOutput` delegate (not publisher)
2. Use `await item.load(.stringValue)` (not sync `stringValue`)
3. `@preconcurrency` on protocol conformance
4. `MainActor.assumeIsolated` in delegate (queue is main)

---

## Common Bug Patterns

### Bug 1: Computed Property Recreating State

**Symptom:** State resets unexpectedly, UI shows wrong info

**Cause:**
```swift
// ❌ BAD - Creates new instance every render
var playbackCoordinator: PlaybackCoordinator {
    PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)
}
```

Every time SwiftUI re-evaluates body → new coordinator → state resets

**Fix:**
```swift
// ✅ GOOD - Persistent instance
@State private var playbackCoordinator: PlaybackCoordinator
```

**How to Detect:** State properties are nil when they shouldn't be, or reset to default values unexpectedly.

---

### Bug 2: ID vs URL Matching

**Symptom:** Metadata updates don't work, "Loading..." stuck in display

**Cause:**
```swift
// Track creation creates new ID each time
let placeholder = Track(url: url, title: "File", artist: "Loading...")  // ID1
let realTrack = Track(url: url, title: "Real", artist: "Artist")  // ID2

// Later: trying to match
if placeholder.id == realTrack.id { ... }  // ❌ FALSE - different IDs
```

**Fix:**
```swift
// ✅ Match by URL (stable identifier)
if placeholder.url == realTrack.url { ... }  // ✅ TRUE - same file
```

**Lesson:** When checking if tracks are "the same", use URL (stable) not ID (changes on recreation).

---

### Bug 3: Handler Clobbering

**Symptom:** Callbacks stop working after certain actions

**Cause:**
```swift
// First: coordinator sets handler
audioPlayer.externalPlaybackHandler = { track in
    coordinator.handleAdvance(track)
}

// Later: view overwrites it
audioPlayer.externalPlaybackHandler = { track in  // ❌ Overwrites!
    coordinator.updateMetadata(track)
}

// Now: advance notifications lost!
```

**Fix:**
```swift
// ✅ Set handler ONCE in initialization
init() {
    audioPlayer.externalPlaybackHandler = { track in
        coordinator.updateMetadata(track)
    }
}

// ✅ Never set it in views
```

**Lesson:** Callbacks should be set once during initialization, not in response to user actions.

---

### Bug 4: Next/Previous with Mixed Types

**Symptom:** Navigation gets stuck when playlist has different item types

**Cause:**
```swift
// AudioPlayer.nextTrack() tries to play next track
func nextTrack() {
    let next = playlist[nextIndex]
    playTrack(track: next)  // ❌ Fails if next is stream!
}

func playTrack(track: Track) {
    guard !track.isStream else { return }  // Guard exits!
    // Never plays stream, currentTrack unchanged
}
```

**Fix:** Return action enum, let coordinator route:
```swift
enum PlaylistAdvanceAction {
    case playLocally(Track)              // AudioPlayer handles
    case requestCoordinatorPlayback(Track)  // Coordinator routes to StreamPlayer
    case restartCurrent
    case none
}

func nextTrack() -> PlaylistAdvanceAction {
    let next = playlist[nextIndex]
    if next.isStream {
        return .requestCoordinatorPlayback(next)  // ✅ Coordinator will route
    } else {
        playTrack(track: next)
        return .playLocally(next)
    }
}
```

**Lesson:** When different item types need different handling, use action enums to communicate intent.

---

## API Migration

### Migrating from Deprecated AVFoundation APIs

**Scenario:** Need to extract stream metadata (song title/artist)

#### Step 1: Identify Deprecations

Build warnings show:
```
'timedMetadata' was deprecated in macOS 10.15
'stringValue' was deprecated in macOS 13.0
```

#### Step 2: Find Modern Replacement

**Old API:**
- `AVPlayerItem.timedMetadata` (KVO publisher)
- `AVMetadataItem.stringValue` (synchronous property)

**New API:**
- `AVPlayerItemMetadataOutput` (delegate pattern)
- `await AVMetadataItem.load(.stringValue)` (async method)

#### Step 3: Implement Modern Pattern

**Setup:**
```swift
let output = AVPlayerItemMetadataOutput(identifiers: nil)
output.setDelegate(self, queue: DispatchQueue.main)
item.add(output)
```

**Delegate:**
```swift
final class StreamPlayer: NSObject, @preconcurrency AVPlayerItemMetadataOutputPushDelegate {

    nonisolated func metadataOutput(...) {
        MainActor.assumeIsolated {
            // Process metadata
        }
    }
}
```

**Extract Values:**
```swift
// Modern async API
if item.commonKey == .commonKeyTitle {
    Task { @MainActor in
        streamTitle = try? await item.load(.stringValue)
    }
}
```

#### Step 4: Handle Swift 6 Concurrency

**Issue:** Non-Sendable types crossing actor boundaries

**Solutions:**
1. `@preconcurrency import AVFoundation` - suppress warnings
2. `@preconcurrency` on protocol conformance
3. `MainActor.assumeIsolated` when delegate queue is main

---

## Testing & Validation

### User Testing Reveals UX Issues Code Reviews Miss

**Lesson:** Technical correctness ≠ user expectations

**Example from Internet Radio:**

**What We Built Initially:**
- M3U loading: Local files → playlist, Streams → separate library
- Technically correct, but...

**User Tested:**
- "Streams not in playlist like Winamp"
- Expected: Streams ARE playlist items (mixed with local files)

**Oracle Validated Architecture but Missed UX Gap**

**Takeaway:**
1. Build infrastructure first (correct)
2. User test early (reveals UX issues)
3. Iterate on integration (Phase 4)
4. Technical review + user testing = complete validation

---

### Reference Implementation Behavior

**Pattern:** Study original app behavior before implementing

**Winamp Behavior Research:**
1. Ctrl+L adds URL to playlist (not separate storage)
2. Streams appear as playlist items
3. M3U populates playlist with ALL entries
4. Buffering shows "Connecting..." in track display

**Our Implementation Journey:**
1. Phase 1-3: Built separate RadioStationLibrary (wrong model)
2. User tested: "This isn't how Winamp works"
3. Phase 4: Pivot to streams-as-playlist-items
4. Result: Matches Winamp behavior

**Lesson:** Reference implementation beats assumptions. Test against original when building retro apps.

---

## Development Process

### Oracle (Codex) Architectural Reviews

**When to Use Oracle:**
1. **Before implementation** - validate architecture
2. **During complex refactors** - catch issues early
3. **After implementation** - comprehensive review
4. **When stuck** - get unstuck with expert guidance

**Oracle Review Types:**

**1. Architecture Validation:**
```
Oracle confirmed dual-backend is correct approach
Identified need for PlaybackCoordinator
Prevented architectural dead-ends
```

**2. Bug Diagnosis:**
```
Found: Handler clobbering breaks playlist advance
Found: Computed property recreating coordinator
Found: ID vs URL matching bug
```

**3. API Guidance:**
```
Proper Swift 6 patterns
Modern AVFoundation APIs
Concurrency best practices
```

**Lesson:** Oracle catches issues humans miss. Use liberally during complex implementations.

---

### Commit Discipline

**Pattern from Internet Radio (35 commits):**

**Phases 1-3:** Infrastructure (12 commits)
- Small, focused commits
- One component per commit
- ~1 commit per 1-2 hours work

**Phase 4:** Integration (7 commits)
- Logical groupings (extend model, wire controls, update UI)
- Each commit builds successfully
- Clear progression

**Bug Fixes:** Individual commits per bug
- Easy to revert if needed
- Clear what each fix addresses

**Documentation:** Separate commits
- Planning updates separate from code
- Easy to review

**Anti-Pattern to Avoid:**
- Giant commits mixing features
- "WIP" or "fixes" commit messages
- Batching multiple unrelated changes

---

### When to Slow Down

**Signs You're Moving Too Fast:**
1. Multiple attempts at same fix
2. Build errors accumulating
3. Making mistakes in "simple" changes
4. Oracle suggestions not working

**What to Do:**
1. **STOP** - Don't make more changes
2. **Read full files** - understand current state
3. **Ask Oracle** - get expert diagnosis
4. **Test one thing** - verify before continuing

**Quote from User:** *"I'm worried that you aren't taking the time to think about the problem and moving too fast and making more mistakes."*

**Lesson Applied:** Slow down, use ultrathink, get Oracle review of build errors.

---

## Retro App Specifics

### Matching Original Behavior

**Critical Pattern:** Retro apps must match expected behavior

**Example: Winamp Playlist Behavior**

**Research Phase:**
```
- Studied Webamp (browser implementation)
- User provided actual Winamp behavior details
- Ctrl+L adds URL to playlist (not separate library)
- Streams are ephemeral playlist items
```

**Implementation Phase:**
```
- Initially: Used separate RadioStationLibrary
- User testing: Doesn't match Winamp
- Pivot: Streams → playlist directly
- RadioStationLibrary → favorites menu (Phase 5+)
```

**Lesson:** For retro apps, the reference implementation IS the spec. Match behavior exactly, even if your "better" idea makes technical sense.

---

### Transport Control Wiring

**Challenge:** Retro apps have many control entry points

**MacAmp Transport Controls:**
- Main window buttons (5 buttons)
- Shade mode buttons (5 buttons)
- Playlist mini transport (5 buttons)
- Keyboard shortcuts
- Menu commands
- Playlist double-click

**All Must Route Through Coordinator:**

```swift
// ❌ WRONG - Bypasses coordinator
Button { audioPlayer.nextTrack() }

// ✅ CORRECT - Routes through coordinator
Button { Task { await playbackCoordinator.next() } }
```

**Oracle Found Missing Wiring:**
- Playlist mini transport still using audioPlayer
- Some keyboard shortcuts bypassed
- Comprehensive check needed

**Lesson:** In retro apps with multiple UI surfaces, verify ALL control paths are wired. Use grep to find stragglers.

---

### Visualizer Limitations

**Problem:** Can't get spectrum/oscilloscope data from AVPlayer

**Why:**
```
AVAudioEngine: mixer.installTap(onBus: 0) → captures PCM data → visualizer
AVPlayer: No tap capability → no PCM access → no visualizer data
```

**Potential Solution:** MTAudioProcessingTap
- Intercept AVPlayer audio output
- Process raw samples
- Feed to visualizer
- Complexity: High (10-20+ hours)
- Effort: Significant Core Audio expertise

**For MVP:** Document as known limitation
- Most users understand radio streams work differently
- Can enhance in Phase 5+ if important

**Lesson:** Some limitations are fundamental to technology choice. Document them, plan future enhancement, ship MVP.

---

## Key Takeaways

### Architecture
1. Dual backends needed when single system can't do everything
2. Coordinator pattern prevents conflicts and unifies state
3. Persistent @State, not computed properties
4. Environment injection for complex initialization

### Swift 6 / macOS 15+
1. @MainActor @Observable for state management
2. RunLoop.main (not DispatchQueue.main) with @MainActor
3. @preconcurrency for non-Sendable frameworks
4. Modern async/await for AVFoundation APIs

### Bug Avoidance
1. URL matching (not ID) for track updates
2. Set callbacks once (don't override)
3. Action enums for multi-type navigation
4. Verify ALL control paths wired

### Process
1. Oracle reviews catch architectural issues
2. User testing finds UX gaps
3. Reference implementation defines behavior
4. Slow down when making mistakes
5. Clean, granular commits

### Quality
1. Zero deprecation warnings required
2. Swift 6 strict concurrency compliance
3. Thread Sanitizer enabled
4. Remove unused/debug code before PR

---

## Project Stats

**Internet Radio Implementation:**
- 35 commits
- ~15-16 hours
- 4 Oracle reviews
- 7 critical bugs fixed
- Zero deprecations
- Grade: A- (production ready)

**Files Changed:**
- 8 implementation files
- 4 new components
- Comprehensive documentation
- Modern patterns throughout

**Complexity:** High
- Dual audio backends
- Swift 6 concurrency
- API migrations
- Full coordinator integration

**Result:** Production-quality internet radio streaming for retro macOS app

---

**Last Updated:** October 31, 2025
**Project:** MacAmp (Winamp Clone for macOS)
**Implementation:** Internet Radio Streaming Feature
