# MacAmp Implementation Patterns

**Version:** 2.3.0
**Date:** 2026-09-25
**Purpose:** How to write code in MacAmp's style: each pattern gives a snippet from the real code, when to use it, and pitfalls. What the system is and why it is built that way is in [MACAMP_ARCHITECTURE_GUIDE.md](MACAMP_ARCHITECTURE_GUIDE.md).

## Table of Contents

1. [Pattern Overview](#pattern-overview)
2. [State Management Patterns](#state-management-patterns)
   - [@Observable with @MainActor](#pattern-observable-with-mainactor)
   - [Dependency Injection via Environment](#pattern-dependency-injection-via-environment)
   - [Computed Properties with Dependency Tracking](#pattern-computed-properties-with-dependency-tracking)
   - [Computed Forwarding for API Compatibility](#pattern-computed-forwarding-for-api-compatibility)
   - [Enum State with Persistence](#pattern-enum-state-with-persistence-repeatmode-pattern)
   - [UserDefaults Persistence with Centralized Keys](#pattern-userdefaults-persistence-with-centralized-keys)
   - [Window Focus State Tracking](#pattern-window-focus-state-tracking)
   - [Action-Based Bridge Pattern](#pattern-action-based-bridge-pattern)
   - [Coordinator Volume Routing](#pattern-coordinator-volume-routing)
   - [Asymmetric Binding for Coordinator Routing](#pattern-asymmetric-binding-for-coordinator-routing)
   - [Capability Flag Pattern](#pattern-capability-flag-pattern)
   - [Display Title Provider Closure](#pattern-display-title-provider-closure)
   - [Task.sleep with Cancellation](#pattern-tasksleep-with-cancellation)
   - [NSMenu Presenter Isolation](#pattern-nsmenu-presenter-isolation)
3. [UI Component Patterns](#ui-component-patterns)
   - [Sprite-Based Button Component](#pattern-sprite-based-button-component)
   - [Absolute Positioning Extension](#pattern-absolute-positioning-extension)
   - [Skinned Slider](#pattern-skinned-slider)
   - [Segment-Sized Window Chrome (VIDEO.bmp / GEN.bmp)](#pattern-segment-sized-window-chrome-videobmp--genbmp)
   - [Video Playback Embedding](#pattern-video-playback-embedding)
   - [View Layer Decomposition (MainWindow)](#pattern-view-layer-decomposition-mainwindow)
4. [Audio Processing Patterns](#audio-processing-patterns)
   - [Real-Time Buffer Processing](#pattern-real-time-buffer-processing)
   - [isolated deinit for @MainActor Cleanup](#pattern-isolated-deinit-for-mainactor-cleanup-swift-62)
   - [SPSC Shared Buffer for Audio-to-Main Thread Transfer](#pattern-spsc-shared-buffer-for-audio-to-main-thread-transfer)
   - [Stream Decode Pipeline (Unified Audio)](#pattern-stream-decode-pipeline-unified-audio)
   - [AudioConverter Input Buffer Lifecycle](#pattern-audioconverter-input-buffer-lifecycle)
   - [Engine Graph Explicit Format](#pattern-engine-graph-explicit-format)
   - [Engine File Duration as Authoritative Source](#pattern-engine-file-duration-as-authoritative-source-vbr)
   - [MTAudioProcessingTap with Unmanaged Context](#pattern-mtaudioprocessingtap-with-unmanaged-context)
   - [Render-Thread-Safe Shared State](#pattern-render-thread-safe-shared-state)
   - [Pinned Tap Format and Build-Time audioMix](#pattern-pinned-tap-format-and-build-time-audiomix)
   - [Parallel DSP Fan-Out via WeakBox Registries](#pattern-parallel-dsp-fan-out-via-weakbox-registries)
   - [Dual-Producer Visualizer Feed](#pattern-dual-producer-visualizer-feed)
   - [Sampled Deadline Telemetry](#pattern-sampled-deadline-telemetry)
5. [Async/Await Patterns](#asyncawait-patterns)
   - [Background I/O with @concurrent Static Functions](#pattern-background-io-with-concurrent-static-functions-swift-62)
   - [Callback Synchronization for Cross-Component Communication](#pattern-callback-synchronization-for-cross-component-communication)
   - [Stream Bridge Lifecycle Callbacks](#pattern-stream-bridge-lifecycle-callbacks)
   - [Exponential Backoff Reconnect with Bridge Tear-Down](#pattern-exponential-backoff-reconnect-with-bridge-tear-down)
   - [Generation Token Guards Across await](#pattern-generation-token-guards-across-await)
   - [Debounced Will/Did Notification Bursts](#pattern-debounced-willdid-notification-bursts)
6. [Error Handling Patterns](#error-handling-patterns)
   - [Typed Stream Termination Reasons](#pattern-typed-stream-termination-reasons)
7. [Testing Patterns](#testing-patterns)
   - [Polling for Asynchronous Release](#pattern-polling-for-asynchronous-release)
   - [Wall-Clock Benchmarks Disabled Under TSan](#pattern-wall-clock-benchmarks-disabled-under-tsan)
   - [Numerical Match Against the Apple Reference Unit](#pattern-numerical-match-against-the-apple-reference-unit)
8. [Migration Guides](#migration-guides)
9. [Anti-Patterns to Avoid](#anti-patterns-to-avoid)
10. [Quick Reference](#quick-reference)

---

## Pattern Overview

This document captures the proven patterns used throughout MacAmp's codebase. Each pattern includes:
- **When to use it**: The problem it solves
- **Implementation**: Complete code example
- **Real usage**: Where it's used in MacAmp
- **Pitfalls**: Common mistakes to avoid

---

## State Management Patterns

### Pattern: @Observable with @MainActor

**When to use**: Any UI-bound state class (all new state in MacAmp)

**Implementation**:
```swift
// File: MacAmpApp/Models/RadioStationLibrary.swift (excerpt)
@MainActor
@Observable
final class RadioStationLibrary {
    private(set) var stations: [RadioStation] = []   // observed: views re-render on change

    private let userDefaultsKey = "MacAmp.RadioStations"

    init() {
        loadStations()
    }

    func addStation(_ station: RadioStation) {
        if stations.contains(where: { $0.streamURL == station.streamURL }) { return }
        stations.append(station)
        saveStations()
    }
}
```

Mark non-UI storage (timers, tasks, registries, caches) `@ObservationIgnored`, e.g. `@ObservationIgnored private var saveTask: Task<Void, Never>?` in `EQPresetStore`.

**Real usage**: `AudioPlayer.swift`, `StreamPlayer.swift`, `PlaybackCoordinator.swift`, `AppSettings.swift`, `SkinManager.swift`, `WindowFocusState.swift`

**Note**: PlaybackCoordinator's `isPlaying`/`isPaused` are computed from the active backend (see [Computed Properties with Dependency Tracking](#pattern-computed-properties-with-dependency-tracking)), not stored. AudioPlayer and StreamPlayer store theirs as `private(set) var`.

**Pitfalls**:
- Don't forget `@MainActor` for UI state
- Use `private(set)` for read-only properties
- Remember `@ObservationIgnored` for non-UI properties
- Timers that feed UI must capture `[weak self]` and run in `.common` run-loop mode (see [Display Title Provider Closure](#pattern-display-title-provider-closure))

### Pattern: Dependency Injection via Environment

**When to use**: Sharing app-wide services with every view in every window

**Implementation**: create each service once in `MacAmpApp.init()`, hold it in `@State`, and inject it into each window's hosting controller (the Winamp windows are `NSWindow`s, not SwiftUI scenes):
```swift
// File: MacAmpApp/Windows/WinampVideoWindowController.swift (same shape in every window controller)
let rootView = WinampVideoWindow()
    .environment(skinManager)
    .environment(audioPlayer)
    .environment(dockingController)
    .environment(settings)
    .environment(radioLibrary)
    .environment(playbackCoordinator)
    .environment(windowFocusState)

let hostingController = NSHostingController(rootView: rootView)
window.contentViewController = hostingController   // never set contentView

// Consumer (any child view)
struct MainWindowTransportLayer: View {
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator
}
```

**Real usage**: `MacAmpApp.swift` creates the services; the five `Winamp*WindowController`s inject them. Details: [MACAMP_ARCHITECTURE_GUIDE.md → Environment Injection Pattern](MACAMP_ARCHITECTURE_GUIDE.md#environment-injection-pattern)

**Pitfalls**:
- Must use `@State` at the creation point, not a computed property
- Setting `window.contentView` instead of `contentViewController` releases the hosting controller and breaks the SwiftUI lifecycle
- A view that reads an environment type nobody injected crashes at runtime; add new services to every window controller

### Pattern: Computed Properties with Dependency Tracking

**When to use**: Derived state that must never drift from its sources

**Implementation**:
```swift
// File: MacAmpApp/Audio/PlaybackCoordinator.swift (excerpt)
var isPlaying: Bool {
    switch currentSource {
    case .localTrack: return audioPlayer.isPlaying
    case .radioStation: return streamPlayer.isPlaying && !streamPlayer.isBuffering
    case .none: return false
    }
}

/// Duration for display: 0 for streams (unknown/infinite)
var displayDuration: Double {
    switch currentSource {
    case .radioStation: return 0
    case .localTrack: return audioPlayer.currentDuration
    case nil: return 0
    }
}

/// "3/15", nil when no playlist track is active
var trackPositionString: String? {
    guard currentTrack != nil,
          let position = audioPlayer.playlistPosition else { return nil }
    return "\(position)/\(audioPlayer.playlistCount)"
}
```

Observation tracks every `@Observable` property read inside the getter, so views that read `isPlaying` update when either backend changes.

**Real usage**: `PlaybackCoordinator.swift` (`isPlaying`, `isPaused`, `displayTitle`, `displayTime`, `displayDuration`, `trackPositionString`, `supportsAudioProcessing`)

**Pitfalls**:
- Don't mirror derived state into a stored `var`; stored play flags drifted during buffering stalls and error recovery before these became computed

### Pattern: Computed Forwarding for API Compatibility

**When to use**: Keeping a stable facade API after extracting functionality into sub-components

**Implementation**:
```swift
// File: MacAmpApp/Audio/AudioPlayer.swift (excerpt)
@Observable
@MainActor
final class AudioPlayer {
    private let equalizer = EqualizerController()        // owns EQPresetStore
    private let visualizerPipeline = VisualizerPipeline()
    let playlistController = PlaylistController()
    let videoPlaybackController = VideoPlaybackController()

    // Read-only forwarding
    var playlist: [Track] { playlistController.playlist }
    var userPresets: [EQPreset] { equalizer.userPresets }
    var videoPlayer: AVPlayer? { videoPlaybackController.player }
    var videoMetadataString: String { videoPlaybackController.metadataString }
    var visualizerLevels: [Float] { visualizerPipeline.levels }

    // Read-write forwarding
    var shuffleEnabled: Bool {
        get { playlistController.shuffleEnabled }
        set { playlistController.shuffleEnabled = newValue }
    }
    var preamp: Float {
        get { equalizer.preamp }
        set { equalizer.preamp = newValue }
    }
    var visualizerSmoothing: Float {
        get { visualizerPipeline.smoothing }
        set { visualizerPipeline.smoothing = newValue }
    }

    // Settings-backed forwarding (AppSettings is the single source of truth)
    var repeatMode: AppSettings.RepeatMode {
        get { AppSettings.instance().repeatMode }
        set { AppSettings.instance().repeatMode = newValue }
    }
}
```

**When NOT to use**:
- Views should use the facade (AudioPlayer), not reach into sub-components
- Don't forward every property; only those needed by external callers

**Real usage**: `AudioPlayer.swift` forwards to `PlaylistController`, `EqualizerController` (EQ bands, preamp, presets, auto-EQ), `VideoPlaybackController`, `VisualizerPipeline` and `AudioEngineController` (engine graph, stream bridge, progress timer)

**Pitfalls**:
- Don't duplicate state; always delegate to the source component
- Update forwarding when a component's API changes
- Avoid deep forwarding chains (A forwards to B forwards to C)
- Keep forwarding properties grouped together for discoverability

### Pattern: Enum State with Persistence (RepeatMode Pattern)

**When to use**: Multi-state UI controls that need to persist across app launches

**Implementation**:
```swift
// File: MacAmpApp/Models/AppSettings.swift
// Purpose: Three-state repeat mode matching Winamp 5 Modern skins
// Context: Replaces boolean repeatEnabled with richer state model

enum RepeatMode: String, Codable, CaseIterable {
    case off = "off"
    case all = "all"  // Loop playlist
    case one = "one"  // Repeat current track

    /// Cycle to next mode (UI button behavior)
    func next() -> RepeatMode {
        let cases = Self.allCases
        guard let index = cases.firstIndex(of: self) else { return self }
        let nextIndex = (index + 1) % cases.count
        return cases[nextIndex]
    }

    /// UI display label for tooltips and menus
    var label: String {
        switch self {
        case .off: return "Repeat: Off"
        case .all: return "Repeat: All"
        case .one: return "Repeat: One"
        }
    }

    /// Button state - lit when active
    var isActive: Bool {
        self != .off
    }
}

// In AppSettings class (persistence layer)
@Observable
@MainActor
final class AppSettings {
    var repeatMode: RepeatMode = .off {
        didSet {
            UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
        }
    }

    init() {
        // Migration from old boolean key
        if let savedMode = UserDefaults.standard.string(forKey: "repeatMode"),
           let mode = RepeatMode(rawValue: savedMode) {
            self.repeatMode = mode
        } else {
            // Migrate: preserve user preference
            let oldRepeat = UserDefaults.standard.bool(forKey: "audioPlayerRepeatEnabled")
            self.repeatMode = oldRepeat ? .all : .off
        }
    }
}

// In AudioPlayer (computed property for single source of truth)
var repeatMode: AppSettings.RepeatMode {
    get { AppSettings.instance().repeatMode }
    set { AppSettings.instance().repeatMode = newValue }
}
```

**Real usage**: `AppSettings.swift` RepeatMode, TimeDisplayMode, VisualizerMode

**Pitfalls**:
- Don't duplicate state (use computed property in AudioPlayer)
- Remember migration logic for existing users
- Use CaseIterable for future-proof cycling

### Pattern: UserDefaults Persistence with Centralized Keys

**When to use**: Persisting scalar properties (Float, Int, Bool) across app launches with organized key management

**Implementation**:
```swift
// File: MacAmpApp/Audio/AudioPlayer.swift
// Purpose: Persist volume and balance settings across launches
// Context: Keys enum centralizes string literals. didSet applies the value to every
//   backend; persistence is call-site-driven (drag end), keeping UserDefaults writes
//   off the slider's per-tick path. See "Coordinator Volume Routing" below.

@Observable
@MainActor
final class AudioPlayer {
    private enum Keys {
        static let volume = "volume"
        static let balance = "balance"
    }

    var volume: Float = 0.75 {  // Default 0.75 when no saved preference
        didSet {
            engine?.setVolume(volume)                  // playerNode + streamSourceNode
            videoPlaybackController.volume = volume    // AVPlayer volume
        }
    }

    var balance: Float = 0.0 {  // -1.0 (left) to 1.0 (right)
        didSet {
            engine?.setBalance(balance)                // playerNode.pan + streamSourceNode.pan
            fanOutBalanceToVideoTaps()                 // video MTAudioProcessingTap contexts
        }
    }

    // Persistence is call-site-driven (slider drag end via PlaybackCoordinator).
    internal func commitVolumeToDefaults() {
        UserDefaults.standard.set(volume, forKey: Keys.volume)
    }
    internal func commitBalanceToDefaults() {
        UserDefaults.standard.set(balance, forKey: Keys.balance)
    }

    init() {
        // Restore saved values; use object(forKey:) to distinguish
        // "not set" from "set to 0"
        if let saved = UserDefaults.standard.object(forKey: Keys.volume) as? Float {
            self.volume = saved
        }
        if let saved = UserDefaults.standard.object(forKey: Keys.balance) as? Float {
            self.balance = saved
        }
    }
}
```

**Real usage**: `AudioPlayer.swift` volume/balance, `EQPresetStore.swift` preset data

**Pitfalls**:
- Use `object(forKey:) as? Float` instead of `float(forKey:)` to distinguish "never set" (nil) from "set to 0.0"
- Keep the `Keys` enum `private` to prevent external key access
- The default property value (e.g., 0.75) acts as the first-launch default
- Place persistence in the mechanism layer (AudioPlayer) not the settings layer (AppSettings) when the value drives hardware state directly
- Don't write UserDefaults from `didSet` for values driven by a slider: every drag tick would hit disk. Commit on drag end (`commitVolumeToDefaults()` / `commitBalanceToDefaults()`)

### Pattern: Window Focus State Tracking

**When to use**: Drawing active/inactive chrome for a window. The model and delegate are described in [MACAMP_ARCHITECTURE_GUIDE.md → Window Focus State Management](MACAMP_ARCHITECTURE_GUIDE.md#window-focus-state-management).

**Implementation**:
```swift
// File: MacAmpApp/Views/Windows/VideoWindowChromeView.swift
@Environment(WindowFocusState.self) private var windowFocusState

// ALWAYS a computed property, so the view re-renders on focus change
private var isWindowActive: Bool {
    windowFocusState.isVideoKey
}

// in the titlebar builder
let suffix = isWindowActive ? "ACTIVE" : "INACTIVE"
SimpleSpriteImage("VIDEO_TITLEBAR_TOP_LEFT_\(suffix)", width: 25, height: 20)
```

**Real usage**: `WinampMainWindow.swift` (`isMainKey`), `VideoWindowChromeView.swift` (`isVideoKey`), `MilkdropWindowChromeView.swift` (`isMilkdropKey`, `_SELECTED` suffix)

**Integration steps** (for a new window):
1. Add an `is<Kind>Key` flag to `WindowFocusState` and a case to `WindowKind`
2. Add the window to the list in `WindowDelegateWiring.wire(...)`, which creates its `WindowFocusDelegate` and adds it to the window's `WindowDelegateMultiplexer`
3. Inject `WindowFocusState` through the window controller's environment
4. Read the flag through a computed property in the view

**Pitfalls**:
- Must ensure a single `WindowFocusState` instance app-wide
- Add the delegate to the multiplexer; never replace `window.delegate`
- Don't cache `isWindowActive` in `@State`; it breaks reactivity
- Sprite suffixes differ by sheet: VIDEO.bmp uses `_ACTIVE`/`_INACTIVE`, GEN.bmp and MAIN use `_SELECTED`

### Pattern: Action-Based Bridge Pattern

**When to use**: Separating navigation logic from playback side effects for testability and clarity

**Swift 6 Relevance**: Enables pure unit testing of logic without mocking playback infrastructure

**Implementation**:
```swift
// File: MacAmpApp/Audio/PlaylistController.swift
// Purpose: Return navigation actions instead of directly triggering playback
// Context: PlaylistController computes what to play; AudioPlayer handles how

/// PlaylistController - Pure navigation logic (no side effects)
@MainActor
@Observable
final class PlaylistController {
    /// Action to be performed after playlist navigation
    enum AdvanceAction: Equatable {
        case none                               // No change needed
        case restartCurrent                     // Repeat-one: restart current track
        case playTrack(Track)                   // Play local file
        case requestCoordinatorPlayback(Track)  // Stream: delegate to coordinator
        case endOfPlaylist                      // Playlist exhausted (repeat off)
    }

    /// Compute the next track to play (pure logic, no side effects)
    /// - Parameter isManualSkip: Whether this is a user-initiated skip
    /// - Returns: The action to perform (caller handles playback)
    func nextTrack(isManualSkip: Bool = false) -> AdvanceAction {
        guard !playlist.isEmpty else { return .none }

        // Repeat-one: Only auto-restart on track end, allow manual skips
        if repeatMode == .one && !isManualSkip {
            guard let track = currentTrack else { return .none }
            return track.isStream ? .requestCoordinatorPlayback(track) : .restartCurrent
        }

        // ... navigation logic ...
        return .playTrack(nextTrack)
    }
}

// File: MacAmpApp/Audio/AudioPlayer.swift
// Purpose: Bridge method translates actions to actual playback operations

/// AudioPlayer - Bridges actions to playback
@Observable
@MainActor
final class AudioPlayer {
    /// Handle action returned from PlaylistController
    private func handlePlaylistAction(_ action: PlaylistController.AdvanceAction) -> PlaylistAdvanceAction {
        switch action {
        case .none:
            return .none

        case .restartCurrent:
            // Always resume: repeat-one at end-of-track means "restart and play"
            // (isPlaying is already false after onPlaybackEnded transition)
            seek(to: 0, resume: true)
            // Bypasses playTrack, so re-arm the video visualizer poll timer
            if currentMediaType == .video {
                visualizerPipeline.startVideoVisualization()
            }
            return .restartCurrent

        case .playTrack(let track):
            playTrack(track: track)
            return .playLocally(track)

        case .requestCoordinatorPlayback(let track):
            return .requestCoordinatorPlayback(track)

        case .endOfPlaylist:
            return .none
        }
    }

    /// Go to next track in playlist
    @discardableResult
    func nextTrack(isManualSkip: Bool = false) -> PlaylistAdvanceAction {
        playlistController.updatePosition(with: currentTrack)
        let action = playlistController.nextTrack(isManualSkip: isManualSkip)
        return handlePlaylistAction(action)
    }
}
```

**Benefits**:
1. **Testability**: PlaylistController can be unit tested with mock data
2. **Clarity**: Navigation logic is separate from playback mechanics
3. **Flexibility**: Actions can be logged, intercepted, or transformed
4. **Type safety**: Enum ensures all cases are handled

**Real usage**: `PlaylistController.swift` for playlist navigation, `AudioPlayer.swift` for bridge method

**Pitfalls**:
- Ensure the bridge method handles ALL action cases
- Action state may be stale - check preconditions before executing
- Don't add side effects to the logic component (PlaylistController)
- The bridge method must handle edge cases (e.g., isPlaying already false)

### Pattern: Coordinator Volume Routing

**When to use**: Routing volume/balance changes from the UI through one coordinator entry point that is idempotent, while the owning mechanism class applies the value to every backend

**Implementation**:
```swift
// File: MacAmpApp/Audio/PlaybackCoordinator.swift
// Purpose: Single entry point for volume/balance changes from UI

    func setVolume(_ vol: Float) {
        guard audioPlayer.volume != vol else { return }
        audioPlayer.volume = vol
    }

    func setBalance(_ bal: Float) {
        guard audioPlayer.balance != bal else { return }
        audioPlayer.balance = bal
    }

    /// Drag-end forwarders — persistence stays off the gesture-tick path.
    func commitVolume() { audioPlayer.commitVolumeToDefaults() }
    func commitBalance() { audioPlayer.commitBalanceToDefaults() }
```

**Why route through AudioPlayer**: `AudioPlayer` owns the canonical value, and its `didSet` reaches every backend: the AVAudioEngine graph (local files and streams share it, so `playerNode` and `streamSourceNode` both update) and video (`videoPlaybackController.volume` for volume; the registered video-tap contexts for balance). The coordinator only adds the same-value short-circuit, which keeps a slider drag from re-applying identical values on every tick.

**Data flow**:
```
UI Slider → PlaybackCoordinator.setVolume() → AudioPlayer.volume didSet → engine.setVolume (playerNode + streamSourceNode)
                                                                        → VideoPlaybackController.volume (AVPlayer)
UI Slider → PlaybackCoordinator.setBalance() → AudioPlayer.balance didSet → engine.setBalance (pan)
                                                                          → video tap contexts (in-tap L/R balance)
Drag end  → PlaybackCoordinator.commitVolume()/commitBalance() → UserDefaults
```

**Real usage**: `PlaybackCoordinator.swift` setVolume/setBalance/commitVolume/commitBalance, called from asymmetric bindings in `MainWindowSlidersLayer.swift`

**Pitfalls**:
- Keep the idempotent guard: SwiftUI sliders emit many same-value writes during a drag
- Persist on drag end, not in `didSet`
- `StreamPlayer` does not need its own volume/balance: streams play through the same AVAudioEngine graph as local files

### Pattern: Asymmetric Binding for Coordinator Routing

**When to use**: When a SwiftUI slider needs to read from one source of truth (the mechanism layer) but write through a different path (the coordinator)

**Implementation**:
```swift
// File: MacAmpApp/Views/MainWindow/MainWindowSlidersLayer.swift
// Purpose: Volume slider reads from AudioPlayer but writes through PlaybackCoordinator
// Context: Ensures all backends receive volume changes, not just AudioPlayer

@ViewBuilder
private func buildVolumeSlider() -> some View {
    let volumeBinding = Binding<Float>(
        get: { audioPlayer.volume },               // Read: source of truth
        set: { playbackCoordinator.setVolume($0) }  // Write: fan-out to all backends
    )
    WinampVolumeSlider(volume: volumeBinding)
        .at(Layout.volumeSlider)
}

// Balance slider follows the same asymmetric pattern.
// It also applies capability-flag dimming -- see "Capability Flag Pattern" below.
```

**Why asymmetric**: The `get` path reads from `audioPlayer.volume` because AudioPlayer is the single source of truth for volume state (it persists to UserDefaults, drives playerNode). The `set` path goes through `playbackCoordinator.setVolume()`, which short-circuits same-value writes before `AudioPlayer.volume`'s `didSet` applies the value to the engine and video. A symmetric `@Bindable` binding would bypass that guard and the coordinator's drag-end persistence.

Don't bind the slider straight to `$player.volume`; see [Direct Backend Volume/Balance Binding](#anti-pattern-direct-backend-volumebalance-binding).

**Real usage**: `MainWindowSlidersLayer.swift` buildVolumeSlider(), buildBalanceSlider()

**Pitfalls**:
- The `get` closure accesses `audioPlayer.volume` directly -- this is fine because `@Observable` tracks the access for SwiftUI view updates
- Do not use `@Bindable` for properties that need coordinator routing
- The binding captures `audioPlayer` and `playbackCoordinator` from the view's environment -- ensure both are injected
- Balance slider also applies capability-flag-based dimming (see "Capability Flag Pattern" below)

### Pattern: Capability Flag Pattern

**When to use**: Exposing a computed boolean flag from the coordinator to indicate whether audio-processing features (EQ, balance, visualizer) are available for the current playback mode, and using it to dim/disable UI controls

One flag covers EQ, balance and the visualizer because all three become available at the same moment (stream bridge active).

**Implementation**:
```swift
// File: MacAmpApp/Audio/PlaybackCoordinator.swift
// Purpose: Single flag for all audio-processing feature availability
// Context: UI dims controls only during stream prebuffering or error states

@Observable
@MainActor
final class PlaybackCoordinator {
    /// True when streams are active AND not in an error state.
    /// Error state returns false (controls re-enabled) so user isn't stuck with dimmed UI.
    private var isStreamBackendActive: Bool {
        guard case .radioStation = currentSource else { return false }
        return streamPlayer.error == nil  // Error → inactive → re-enable controls
    }

    /// EQ, balance, and other audio-processing features are available when not streaming,
    /// OR when the stream bridge is active (stream decoded through AVAudioEngine).
    /// Dimmed only during stream error or before bridge activates (prebuffering).
    var supportsAudioProcessing: Bool { !isStreamBackendActive || audioPlayer.isBridgeActive }
}
```

**UI consumption pattern** (dim + disable):
```swift
// File: MacAmpApp/Views/MainWindow/MainWindowSlidersLayer.swift
// File: MacAmpApp/Views/WinampEqualizerWindow.swift
// Pattern: opacity(0.5) + allowsHitTesting(false) for unsupported features

// Balance slider
WinampBalanceSlider(balance: balanceBinding)
    .opacity(playbackCoordinator.supportsAudioProcessing ? 1.0 : 0.5)
    .allowsHitTesting(playbackCoordinator.supportsAudioProcessing)
    .help(playbackCoordinator.supportsAudioProcessing
          ? "Balance"
          : "Balance unavailable during streaming")

// EQ window content
buildEQSliders()
    .opacity(playbackCoordinator.supportsAudioProcessing ? 1.0 : 0.5)
    .allowsHitTesting(playbackCoordinator.supportsAudioProcessing)
```

**Error state recovery**: When a stream enters an error state (`streamPlayer.error != nil`), `isStreamBackendActive` returns `false`, which flips `supportsAudioProcessing` back to `true`. This ensures the user is never stuck with permanently dimmed controls after a stream failure.

**Real usage**: `PlaybackCoordinator.supportsAudioProcessing`, `MainWindowSlidersLayer.swift` balance dimming, `WinampEqualizerWindow.swift` EQ dimming

**Pitfalls**:
- Controls dim briefly during stream prebuffering (before bridge activates) and re-enable once `onFormatReady` fires and the bridge is active
- Use `opacity(0.5)` (not `0.0`) to indicate "unavailable" rather than "hidden" -- users should see the control exists but cannot be used
- Always pair `.opacity()` with `.allowsHitTesting(false)` to prevent interaction with dimmed controls
- Optional `.help()` tooltip explains why the control is disabled

### Pattern: Display Title Provider Closure

**When to use**: When a Timer or periodic callback needs to read the current value of an external property, but the callback's closure would capture a stale value at creation time

**Why**: a scroll timer that captured `displayTitle` when it was created never picked up track changes.

**Implementation**:
```swift
// File: MacAmpApp/Views/MainWindow/WinampMainWindowInteractionState.swift
// Purpose: Timer reads live title value instead of stale capture
// Context: Scroll timer runs at 0.15s intervals, must track title changes

@MainActor
@Observable
final class WinampMainWindowInteractionState {
    /// Closure that returns the current display title. Set by the view layer so the timer
    /// always reads the live value instead of a stale capture.
    var displayTitleProvider: () -> String = { "MacAmp" }

    func startScrolling() {
        guard scrollTimer == nil else { return }
        // .common run-loop mode keeps this firing during user gestures (.eventTracking)
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // CORRECT: Calls closure which reads live value from PlaybackCoordinator
                let trackText = self.displayTitleProvider()
                // ... scroll logic using trackText ...
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        scrollTimer = timer
    }
}

// File: MacAmpApp/Views/MainWindow/WinampMainWindow.swift
// Purpose: Wire the closure to read from PlaybackCoordinator at call time

.onAppear {
    interactionState.displayTitleProvider = { [playbackCoordinator] in
        playbackCoordinator.displayTitle.isEmpty ? "MacAmp" : playbackCoordinator.displayTitle
    }
}
```

**Why a closure instead of passing the string directly**:
- Passing `playbackCoordinator.displayTitle` directly to the interaction state would capture the value at assignment time
- Timer closures capture values at creation, not at invocation
- The closure indirection ensures the timer always reads the **current** value from the coordinator

**Real usage**: `WinampMainWindowInteractionState.swift` `displayTitleProvider`, wired in `WinampMainWindow.swift` `.onAppear`

**Pitfalls**:
- The closure must capture the coordinator weakly or as unowned to avoid retain cycles
- The closure is set in `.onAppear` and must be updated if the coordinator changes (unlikely with environment injection)
- Prefer this pattern over storing a reference to the coordinator in the interaction state (keeps the state class view-agnostic)

### Pattern: Task.sleep with Cancellation

**When to use**: Replacing `DispatchQueue.main.asyncAfter` with structured concurrency for delayed state changes that may need cancellation

**Why**: cancelling a stored `Task` prevents the delayed action from firing; cancelling a `DispatchQueue.main.asyncAfter` requires tracking `DispatchWorkItem` references. Used for scroll restart and scrub reset delays in the main window interaction state.

**Implementation**:
```swift
// File: MacAmpApp/Views/MainWindow/WinampMainWindowInteractionState.swift
// Purpose: Delayed scroll restart after title change, cancellable on new title change

private var scrollRestartTask: Task<Void, Never>?
private var scrubResetTask: Task<Void, Never>?

func resetScrolling() {
    scrollTimer?.invalidate()
    scrollTimer = nil
    scrollOffset = 0
    scrollRestartTask?.cancel()  // Cancel any pending restart

    scrollRestartTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .seconds(1))      // Cancellable delay
        guard !Task.isCancelled else { return }       // Bail if cancelled
        guard let self, self.isViewVisible else { return }
        self.startScrolling()
    }
}

// Scrub reset: prevents isScrubbing from flipping mid-drag
func handlePositionDragEnd(...) {
    // ... seek logic ...

    scrubResetTask?.cancel()  // Cancel prior reset if drag restarts
    scrubResetTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .seconds(0.3))
        guard !Task.isCancelled else { return }
        self?.isScrubbing = false
    }
}

func handlePositionDrag(...) {
    scrubResetTask?.cancel()  // CRITICAL: Cancel reset on new drag start
    if !isScrubbing {
        isScrubbing = true
        // ... pause logic ...
    }
    // ... update progress ...
}
```

**Why Task.sleep over DispatchQueue.main.asyncAfter**:
- `Task.cancel()` is a single call vs. tracking `DispatchWorkItem` references
- `Task.isCancelled` provides a clear guard before executing the delayed action
- `try? await Task.sleep` throws `CancellationError` on cancel, which `try?` absorbs cleanly
- Tasks are `@MainActor`-isolated, so no need for dispatch to main queue

**The scrubResetTask cancellation pattern** deserves special attention: when the user starts a new drag, `handlePositionDrag` cancels any pending `scrubResetTask`. Without this, a previous drag-end's reset task could flip `isScrubbing = false` in the middle of a new drag, causing the slider thumb to jump.

**Real usage**: `WinampMainWindowInteractionState.swift` for `scrollRestartTask` and `scrubResetTask`

**Pitfalls**:
- Always check `Task.isCancelled` after `Task.sleep` returns -- the sleep can complete before cancellation is checked
- Store the `Task` reference to enable cancellation; anonymous `Task { }` blocks cannot be cancelled
- Cancel in `cleanup()` / `onDisappear` to prevent orphaned tasks from executing on deallocated state
- Use `[weak self]` in the task closure to prevent retain cycles during the sleep period

### Pattern: NSMenu Presenter Isolation

**When to use**: When a SwiftUI view needs to present an `NSMenu` (AppKit menu) and the menu lifecycle (construction, item targets, popup positioning) is complex enough to warrant its own class

The Options (O button) menu is **not** interaction state -- it is a presentation concern that bridges AppKit to SwiftUI.

**Implementation**:
```swift
// File: MacAmpApp/Views/MainWindow/MainWindowOptionsMenuPresenter.swift
// Purpose: Bridges AppKit NSMenu to SwiftUI for the Options (O) button menu
// Context: Uses shared MenuActionTarget + MenuItemFactory from Utilities/

@MainActor
final class MainWindowOptionsMenuPresenter {
    private var activeMenu: NSMenu?  // Retains menu during display

    func showOptionsMenu(from buttonPosition: CGPoint, settings: AppSettings,
                         audioPlayer: AudioPlayer, isDoubleSizeMode: Bool) {
        let menu = NSMenu()
        activeMenu = menu  // CRITICAL: retain menu

        // Items via shared MenuItemFactory (MacAmpApp/Utilities/MenuActionTarget.swift), e.g.
        // MenuItemFactory.createMenuItem(title: "Time: Elapsed",
        //     isChecked: settings.timeDisplayMode == .elapsed,
        //     action: { [weak settings] in ... })
        buildOptionsMenuItems(menu: menu, settings: settings, audioPlayer: audioPlayer)

        // Position calculation accounting for double-size mode
        // (mainWindow: the visible 275- or 550-wide window, else NSApp.keyWindow)
        if let window = mainWindow {
            let scale: CGFloat = isDoubleSizeMode ? 2.0 : 1.0
            let screenPoint = NSPoint(
                x: window.frame.minX + (buttonPosition.x * scale),
                y: window.frame.maxY - ((buttonPosition.y + 8) * scale)
            )
            menu.popUp(positioning: nil, at: screenPoint, in: nil)
        }
    }
}

// Shared utility: MacAmpApp/Utilities/MenuActionTarget.swift
// MenuActionTarget bridges closures to NSMenuItem @objc action selectors.
// MenuItemFactory creates NSMenuItems with closure-based actions.
// Both are used by MainWindowOptionsMenuPresenter, WinampMilkdropWindow, and other menus.

// In WinampMainWindow.swift -- owned as @State, not part of interaction state
@State private var optionsPresenter = MainWindowOptionsMenuPresenter()
```

**Why a separate class (not in interaction state)**:
- `WinampMainWindowInteractionState` manages drag state, scroll offsets, timers -- **user interaction state**
- Menu presentation is a **presentation concern** that bridges AppKit APIs
- The menu must retain `NSMenu` and `MenuActionTarget` objects during display -- this lifecycle is orthogonal to interaction state
- Separating them keeps both classes focused and testable

**Real usage**: `MainWindowOptionsMenuPresenter.swift`, instantiated in `WinampMainWindow.swift` as `@State`

**Pitfalls**:
- `activeMenu` must be retained as an instance property -- if the NSMenu is only a local variable, it is deallocated before `popUp` returns (menu items stop working)
- `MenuActionTarget` must be stored in `representedObject` -- the `target` property is a weak reference, so without `representedObject` the target is released before the user clicks (`MenuItemFactory` handles this automatically)
- Menu items use `[weak settings]` / `[weak audioPlayer]` in action closures to avoid retaining environment objects beyond the menu's lifetime

---

## UI Component Patterns

### Pattern: Sprite-Based Button Component

**When to use**: Creating interactive skinned buttons

**Implementation**: a plain SwiftUI `Button` whose label is a `SimpleSpriteImage`; state is shown by choosing the sprite name:
```swift
// File: MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift (buildClutterBarDV)
let vSprite = settings.showVideoWindow ? "MAIN_CLUTTER_BAR_BUTTON_V_SELECTED" : "MAIN_CLUTTER_BAR_BUTTON_V"
Button(action: { settings.showVideoWindow.toggle() }, label: {
    SimpleSpriteImage(vSprite, width: 8, height: 7)
})
.buttonStyle(.plain)      // no system bezel
.focusable(false)         // no focus ring
.help("Video Window (Ctrl+V)")
.at(Layout.clutterButtonV)
```

`SimpleSpriteImage` (`Views/Components/SimpleSpriteImage.swift`) takes either a legacy sprite name or a `SemanticSprite`, resolves it against `skinManager.currentSkin`, and renders it with `.interpolation(.none)`, `.antialiased(false)`, `.resizable()`, `.aspectRatio(contentMode: .fill)`, the given frame and `.clipped()`. A missing sprite renders as a purple "?" placeholder.

**Real usage**: All buttons in `MainWindow/MainWindowFullLayer.swift`, `MainWindow/MainWindowTransportLayer.swift`, `WinampEqualizerWindow.swift`

**Pitfalls**:
- Omitting `.buttonStyle(.plain)` draws a system bezel around the sprite
- Omitting `.focusable(false)` shows a focus ring
- `SimpleSpriteImage` has no action or pressed state of its own; interaction belongs to the enclosing `Button`

### Pattern: Absolute Positioning Extension

**When to use**: Placing elements at exact pixel coordinates

**Implementation**:
```swift
// File: MacAmpApp/Views/Components/SimpleSpriteImage.swift
// Purpose: Absolute positioning using top-left origin like Winamp
// Context: Critical for pixel-perfect layout matching original Winamp

extension View {
    /// Position view at exact coordinates (top-left origin like Winamp)
    func at(x: CGFloat, y: CGFloat) -> some View {
        self.offset(x: x, y: y)
    }
}

// Usage examples from actual code:
// File: MacAmpApp/Views/MainWindow/MainWindowTransportLayer.swift
// Coordinates are defined in WinampMainWindowLayout enum
Button(action: { playbackCoordinator.togglePlayPause() }, label: {
    SimpleSpriteImage("MAIN_PLAY_BUTTON", width: 23, height: 18)
})
.at(Layout.playButton)  // CGPoint(x: 39, y: 88)

// File: MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift
// Time display positioning via Layout constants
buildTimeDisplay()
    .at(Layout.timeDisplay)  // CGPoint(x: 39, y: 26)

// Visualizer positioning
VisualizerView()
    .at(Layout.spectrumAnalyzer)  // CGPoint(x: 24, y: 43)
```

**Real usage**: Every component placement in window views

### Pattern: Skinned Slider

**When to use**: Draggable sliders drawn from skin sprite strips (volume, balance, EQ bands, position)

**Implementation**: a `@Binding` value, a `DragGesture(minimumDistance: 0)` over the track that maps location to value, the background frame chosen by offsetting a sprite strip, and an `onDragEnded` hook for persistence:
```swift
// File: MacAmpApp/Views/Components/WinampVolumeSlider.swift (shape)
struct WinampBalanceSlider: View {
    @Binding var balance: Float          // -1.0 to 1.0
    var onDragEnded: (() -> Void)?       // PlaybackCoordinator.commitBalance()
    // body: BALANCE.BMP strip offset by calculateBalanceFrameOffset(), thumb sprite,
    // DragGesture(minimumDistance: 0) → handleDrag(_:in:) → balance; .onEnded → onDragEnded?()
}
```

**Real usage**: `WinampVolumeSlider` / `WinampBalanceSlider` (`WinampVolumeSlider.swift`), `WinampVerticalSlider` (EQ bands), `PlaylistScrollSlider`

**Pitfalls**:
- Persist in `onDragEnded`, never per `onChanged` tick (see [Coordinator Volume Routing](#pattern-coordinator-volume-routing))
- SwiftUI re-fires `onChanged` every run-loop tick even without motion; route writes through an idempotent setter

#### Balance Slider Gradient Mapping

The balance slider maps `abs(balance)` (0.0-1.0) to BALANCE.BMP sprite frames using webamp-compatible linear mapping:

```swift
// File: MacAmpApp/Views/Components/WinampVolumeSlider.swift
// BALANCE.BMP: 28 frames (15px each), frame 0 = green, frame 27 = red
// Matches webamp: Math.floor(Math.abs(balance) / 100 * 27) * 15
private func calculateBalanceFrameOffset() -> CGFloat {
    let percent = min(max(CGFloat(abs(balance)), 0), 1)
    let sprite = Int(floor(percent * 27.0))
    let offset = CGFloat(sprite) * 15.0
    return -offset
}
```

**Frame mapping**: balance=0 -> frame 0 (green), balance=+/-0.5 -> frame 13 (mid), balance=+/-1.0 -> frame 27 (red)

#### Haptic Snap-to-Center

The balance slider uses haptic feedback (`NSHapticFeedbackManager`) when the thumb enters the center snap zone:
- **Threshold**: 12% of slider range
- **Trigger**: Fires once on entry into snap zone, not on every frame
- **Implementation**: Track previous snap state to detect entry vs. continued presence

### Pattern: Segment-Sized Window Chrome (VIDEO.bmp / GEN.bmp)

**When to use**: Building chrome for a resizable Winamp window from sprite pieces (the video and Milkdrop windows). Sprite names and layouts: [VIDEO_WINDOW.md](VIDEO_WINDOW.md), [MILKDROP_WINDOW.md](MILKDROP_WINDOW.md).

**Implementation**: a size-state object measured in 25×29px segments, fixed-width caps, and tiled fillers whose counts come from the size state:
```swift
// File: MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift (excerpt)
struct MilkdropWindowChromeView<Content: View>: View {
    let sizeState: MilkdropWindowSizeState
    @ViewBuilder let content: Content
    @Environment(WindowFocusState.self) private var windowFocusState

    private var isWindowActive: Bool { windowFocusState.isMilkdropKey }
    private var pixelSize: CGSize { sizeState.pixelSize }
    private var contentSize: CGSize { sizeState.contentSize }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.frame(width: pixelSize.width, height: pixelSize.height)
            buildDynamicTitlebar()      // caps + n × filler + center, "_SELECTED" suffix when focused
            buildDynamicBorders()       // GEN_MIDDLE_LEFT (11px) / GEN_MIDDLE_RIGHT (8px), tiled per 29px row
            content
                .frame(width: contentSize.width, height: contentSize.height)
                .position(x: pixelSize.width / 2, y: 20 + contentSize.height / 2)
            buildDynamicBottomBar()     // 125px caps + tiled 25px center
            buildResizeHandle()         // drag → new segment size, preview overlay while dragging
        }
        .frame(width: pixelSize.width, height: pixelSize.height, alignment: .topLeading)
        .fixedSize()
    }
}
```

`VideoWindowChromeView` has the same structure with VIDEO.bmp pieces (20px titlebar, 11px/8px borders, 38px bottom bar) and a `CHARACTER_*` sprite ticker for metadata.

**Real usage**: `VideoWindowChromeView.swift` + `VideoWindowSizeState.swift`, `MilkdropWindowChromeView.swift` + `MilkdropWindowSizeState.swift`

**Pitfalls**:
- VIDEO.bmp may be missing from a skin: check `Skin.hasVideoSprites` and fall back (`VideoWindowFallbackChrome`)
- Focus suffixes differ: VIDEO.bmp `_ACTIVE`/`_INACTIVE`, GEN.bmp `_SELECTED`
- GEN.bmp letters are two discontiguous pieces separated by a 1px cyan boundary: draw `GEN_TEXT_<L>_TOP` (6px) over `GEN_TEXT_<L>_BOTTOM` (1px, or 2px when selected)
- Derive tile counts from the size state; don't hard-code pixel widths
- Resize previews use an AppKit overlay window (`WindowResizePreviewOverlay`); the NSWindow is resized once at drag end

### Pattern: Video Playback Embedding

**When to use**: Embedding an `AVPlayer` in a SwiftUI view when the app, not AVKit, owns transport and remote commands

**Implementation**:
```swift
// File: MacAmpApp/Views/Windows/AVPlayerViewRepresentable.swift
// Purpose: Bridge AVPlayerView (AppKit) into SwiftUI with all AVKit chrome and system integration off
// Context: Rendered inside VideoWindowChromeView; transport comes from VIDEO.bmp controls

struct AVPlayerViewRepresentable: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none  // Use our VIDEO.bmp controls instead
        view.videoGravity = .resizeAspect  // Maintain aspect ratio
        view.showsFullScreenToggleButton = false  // No native fullscreen button
        view.showsSharingServiceButton = false  // No sharing button
        view.allowsPictureInPicturePlayback = false  // No PiP for now
        view.updatesNowPlayingInfoCenter = false  // PlaybackCoordinator owns remote commands; AVKit's would pause the player behind it
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // Update player if it changes
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

// File: MacAmpApp/Views/WinampVideoWindow.swift
// Show the player only when a video is current AND its AVPlayer exists
if audioPlayer.currentMediaType == .video,
   let player = audioPlayer.videoPlayer {
    AVPlayerViewRepresentable(player: player)
} else {
    ZStack {
        Color.black
        Text("No video loaded")
            .font(.system(size: 10))
            .foregroundColor(.gray)
    }
}
```

**Player ownership**: `AudioPlayer.videoPlayer` forwards `VideoPlaybackController.player`. That property is **observed** (not `@ObservationIgnored`) because `loadVideo` is `async`: the `AVPlayer` is assigned after the tap's `audioMix` is built, which is after the `currentMediaType` change that re-rendered the window. The view must observe `player` directly to pick up the instance once it exists.

**Media type detection** is by extension only (`AudioPlayer.detectMediaType`: `mp4`, `mov`, `m4v`, `avi` → `.video`, everything else → `.audio`).

**Why `updatesNowPlayingInfoCenter = false`**: with the default `true`, AVKit registers its own Now Playing / remote-command handler alongside `PlaybackCoordinator`'s. System pause commands (AirPods removed, Bluetooth route loss, media keys) then pause `AVPlayer` directly, and `VideoPlaybackController` keeps reporting "playing" — the UI desyncs and the next Play press pauses instead of resuming. With it off, every remote command arrives as an `MPRemoteCommandEvent` at `PlaybackCoordinator`.

**Real usage**: `AVPlayerViewRepresentable.swift`, `WinampVideoWindow.swift`

**Pitfalls**:
- Any `AVPlayerView` in an app that registers its own `MPRemoteCommandCenter` handlers must set `updatesNowPlayingInfoCenter = false`
- Don't create new `AVPlayer` instances in `updateNSView`; only swap when the identity changes
- Don't mark an async-assigned `player` property `@ObservationIgnored` — the view will show the placeholder forever
- Video audio does get EQ, balance and visualization: an `MTAudioProcessingTap` on the `AVPlayerItem` runs the DSP in place (see [MTAudioProcessingTap with Unmanaged Context](#pattern-mtaudioprocessingtap-with-unmanaged-context)); the audio never enters `AVAudioEngine`

### Pattern: View Layer Decomposition (MainWindow)

**When to use**: Decomposing a monolithic SwiftUI view (500+ lines) into child view structs that create independent recomposition boundaries

`MacAmpApp/Views/MainWindow/` is the canonical example: the main window split into 10 focused files. `MacAmpApp/Views/PlaylistWindow/` follows the same pattern.

**Directory structure**:
```
MacAmpApp/Views/MainWindow/
  WinampMainWindow.swift              # Root composition
  WinampMainWindowInteractionState.swift  # @Observable interaction state
  WinampMainWindowLayout.swift        # Coordinate constants enum
  MainWindowOptionsMenuPresenter.swift # NSMenu bridge (presentation)
  MainWindowFullLayer.swift           # Full-mode composition
  MainWindowShadeLayer.swift          # Shade-mode composition
  MainWindowTransportLayer.swift      # Prev/Play/Pause/Stop/Next/Eject
  MainWindowSlidersLayer.swift        # Volume/Balance/Position sliders
  MainWindowIndicatorsLayer.swift     # Play state, mono/stereo, bitrate
  MainWindowTrackInfoLayer.swift      # Scrolling track title
```

**Key architectural decisions**:

1. **Root view is thin**: `WinampMainWindow.swift` owns `@State` for interaction state and presenter, switches between full/shade mode, and wires lifecycle callbacks. No UI building logic.

2. **Interaction state is a class, not scattered @State vars**: All scrubbing, scrolling, and blinking state lives in `WinampMainWindowInteractionState` -- a single `@Observable` class owned via `@State` in the root and passed to children.

3. **Layout constants are a separate enum**: `WinampMainWindowLayout` centralizes all pixel coordinates, preventing magic numbers in child views. Children use `typealias Layout = WinampMainWindowLayout`.

4. **NSMenu presenter is separate from interaction state**: Menu presentation is a bridge concern (AppKit ↔ SwiftUI), not interaction state. See [NSMenu Presenter Isolation](#pattern-nsmenu-presenter-isolation).

5. **Each child view is a recomposition boundary**: When `audioPlayer.volume` changes, only `MainWindowSlidersLayer` re-evaluates -- transport buttons, indicators, and track info are untouched.

**Implementation pattern for child layers**:
```swift
// File: MacAmpApp/Views/MainWindow/MainWindowTransportLayer.swift
// Each child: environment deps + passed state + typealias Layout

struct MainWindowTransportLayer: View {
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator
    let openFileDialog: () -> Void  // Injected action, not environment

    private typealias Layout = WinampMainWindowLayout

    var body: some View {
        Button(action: { playbackCoordinator.togglePlayPause() }, label: {
            SimpleSpriteImage("MAIN_PLAY_BUTTON", width: 23, height: 18)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .at(Layout.playButton)

        // ... other buttons ...
    }
}
```

**Real usage**: `MacAmpApp/Views/MainWindow/` (all 10 files), following the same pattern established in `MacAmpApp/Views/PlaylistWindow/`

**Known optimization opportunity**: `VisualizerView` is currently inlined in `MainWindowFullLayer` via `buildSpectrumAnalyzer()`. This means the spectrum analyzer shares `MainWindowFullLayer`'s recomposition scope -- a volume drag causes the visualizer to re-evaluate even though its data has not changed. Extracting a `MainWindowVisualizerLayer` struct would create an independent recomposition boundary.

**Pitfalls**:
- Children should declare `@Environment` for only the services they actually read -- avoid pulling in unused environments
- The `interactionState` is passed as a plain property (not environment) because it is view-local, not app-wide
- `MainWindowFullLayer` still contains several `@ViewBuilder` helper methods (time digits, shuffle/repeat, clutter bar) that could become separate child views for further recomposition isolation
- When adding new UI elements, add them to the appropriate child layer, not to the root `WinampMainWindow`

---

## Audio Processing Patterns

### Pattern: Real-Time Buffer Processing

**When to use**: Reading audio buffers on a render thread (engine tap block, `MTAudioProcessingTap` callback)

**Implementation**: work in place on pre-allocated scratch storage; never build a new `[Float]` per callback:
```swift
// File: MacAmpApp/Audio/VisualizerPipeline.swift (makeTapHandler, excerpt)
let channelCount = Int(buffer.format.channelCount)
guard channelCount > 0, let ptr = buffer.floatChannelData else { return }
let frameCount = Int(buffer.frameLength)
if frameCount == 0 { return }

// prepare() clamps to pre-allocated capacity (no allocation on the audio thread)
let cappedFrameCount = scratch.prepare(frameCount: frameCount, bars: 20,
                                       sampleRate: Float(buffer.format.sampleRate))

scratch.withMono { mono in
    let invCount = 1.0 / Float(channelCount)
    for frame in 0..<cappedFrameCount {
        var sum: Float = 0
        for channel in 0..<channelCount { sum += ptr[channel][frame] }
        mono[frame] = sum * invCount
    }
}
```

**Real usage**: mono downmix in the two visualizer producers: `VisualizerPipeline.makeTapHandler` (`AVAudioPCMBuffer.floatChannelData`) and `videoTapVisualizerRender` (`AudioBufferList`, interleaved or not), both writing into `VisualizerScratchBuffers`

**Pitfalls**:
- No `Array` creation, `map`, `Task`, logging or locks that can block on a render thread
- Guard against zero channels, zero frames and missing channel data before touching pointers
- Clamp to the scratch capacity (4096 frames) rather than growing buffers
- An `actor` is not an option for render-thread data: the render thread cannot `await`. Use [SPSC Shared Buffer](#pattern-spsc-shared-buffer-for-audio-to-main-thread-transfer) for data out and [Render-Thread-Safe Shared State](#pattern-render-thread-safe-shared-state) for parameters in

### Pattern: isolated deinit for @MainActor Cleanup (Swift 6.2)

**When to use**: A `@MainActor` class must release observers, timers, tasks or players when it deallocates

**Implementation**:
```swift
// File: MacAmpApp/Audio/VideoPlaybackController.swift
@MainActor
@Observable
final class VideoPlaybackController {
    private(set) var player: AVPlayer?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var timeObserver: Any?

    isolated deinit {
        // Runs on @MainActor: safe to touch every property directly
        metadataTask?.cancel()
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        player?.pause()
    }
}
```

**Real usage**: 7 classes; list in [MACAMP_ARCHITECTURE_GUIDE.md → isolated deinit](MACAMP_ARCHITECTURE_GUIDE.md#isolated-deinit-swift-62)

**Pitfalls**:
- Treat `isolated deinit` as a backstop; normal teardown still goes through an explicit `cleanup()` / `removeTap()` / `stop()`
- Don't reintroduce `nonisolated(unsafe)` shadow copies of properties just so a plain `deinit` can reach them; that was the pre-6.2 workaround

### Pattern: SPSC Shared Buffer for Audio-to-Main Thread Transfer

**When to use**: Transferring real-time audio data (visualizer, spectrum, waveform) from the audio thread to the main thread without any heap allocations on the audio thread.

**Why**: Audio tap callbacks run on a real-time thread where heap allocations (Array creation, ARC reference counting, Task dispatch) can take locks and cause buffer underruns (audible skips). The earlier `Task { @MainActor }` hand-off allocated 7-8 times per callback. `VisualizerFeed` (`MacAmpApp/Audio/VisualizerFeed.swift`) uses pre-allocated storage and `os_unfair_lock_trylock` for non-blocking publishing; scratch buffers live in `VisualizerScratchBuffers.swift`. The feed has two producers, the engine tap and the video tap, and only one is active at a time, so it is single-producer at any instant (see [Dual-Producer Visualizer Feed](#pattern-dual-producer-visualizer-feed)).

**Data flow**:
```
Audio Thread (21.5 Hz)              Main Thread (30 Hz poll timer, .common mode)
─────────────────────               ──────────────────────────────
1. scratch.prepare(buffer)          1. feed.consume()
2. FFT + Goertzel computation          ├─ os_unfair_lock_lock()
3. feed.tryPublish(scratch)            ├─ check generation > lastConsumed
   ├─ os_unfair_lock_trylock()         ├─ copy data (Array creation OK here)
   ├─ memcpy into pre-allocated arrays └─ unlock, return VisualizerData
   ├─ generation += 1              2. pipeline.visualizerData = data
   └─ unlock                          (triggers @Observable)
   └─ if contention: drop frame
      (imperceptible at 21.5 Hz)
```

**Implementation (shared buffer)**:
```swift
// File: MacAmpApp/Audio/VisualizerFeed.swift
// Purpose: Lock-protected single-slot storage for audio-to-main thread data transfer
// Context: Audio thread writes via tryPublish(), main thread reads via consume()

final class VisualizerFeed: @unchecked Sendable {
    // Pre-allocated arrays - sizes match visualization requirements
    private var rms = [Float](repeating: 0, count: 20)
    private var spectrum = [Float](repeating: 0, count: 20)
    private var waveform = [Float](repeating: 0, count: 76)
    private var bcSpectrum = [Float](repeating: 0, count: 1024)
    private var bcWaveform = [Float](repeating: 0, count: 1024)
    private var waveformCount: Int = 0
    private var rmsCount: Int = 0
    private var spectrumCount: Int = 0

    private var lock = os_unfair_lock()
    private var generation: UInt64 = 0
    private var lastConsumed: UInt64 = 0

    /// Copy Float elements via memcpy. Audio-thread safe (no allocation).
    private func copyFloatBuffer(from source: [Float], to destination: inout [Float], count: Int? = nil) {
        let limit = min(source.count, destination.count)
        let n = min(count ?? limit, limit)
        guard n > 0 else { return }
        source.withUnsafeBufferPointer { src in
            destination.withUnsafeMutableBufferPointer { dst in
                guard let s = src.baseAddress, let d = dst.baseAddress else { return }
                memcpy(d, s, n * MemoryLayout<Float>.stride)
            }
        }
    }

    /// Audio thread: try to publish data (non-blocking).
    /// Returns false if lock is contended (frame is dropped).
    func tryPublish(from scratch: VisualizerScratchBuffers, oscilloscopeSamples: Int, validFrameCount: Int) -> Bool {
        guard os_unfair_lock_trylock(&lock) else { return false }
        defer { os_unfair_lock_unlock(&lock) }

        let rCount = min(scratch.rms.count, rms.count)
        copyFloatBuffer(from: scratch.rms, to: &rms, count: rCount)
        rmsCount = rCount

        // ... spectrum, downsampled waveform, bcSpectrum, bcWaveform the same way ...

        generation &+= 1
        return true
    }

    /// Main thread: consume latest data (blocking lock, safe for main thread).
    func consume() -> VisualizerData? {
        os_unfair_lock_lock(&lock)

        guard generation != lastConsumed else {
            os_unfair_lock_unlock(&lock)
            return nil
        }
        lastConsumed = generation

        // Copy raw data under lock (memcpy only, no construction)
        let localRms = Array(rms.prefix(rmsCount))
        let localSpec = Array(spectrum.prefix(spectrumCount))
        let localWave = Array(waveform.prefix(waveformCount))
        let localBcSpec = Array(bcSpectrum)
        let localBcWave = Array(bcWaveform)

        os_unfair_lock_unlock(&lock)

        // Construct VisualizerData after releasing lock
        return VisualizerData(
            rms: localRms,
            spectrum: localSpec,
            waveform: localWave,
            butterchurnSpectrum: localBcSpec,
            butterchurnWaveform: localBcWave
        )
    }
}
```

**Implementation (poll timer and tap handler)**:
```swift
// File: MacAmpApp/Audio/VisualizerPipeline.swift
// Purpose: Connect the feed to the engine tap and the UI

@MainActor
@Observable
final class VisualizerPipeline {
    @ObservationIgnored private var tapInstalled = false
    @ObservationIgnored private weak var mixerNode: AVAudioMixerNode?
    @ObservationIgnored private let feed = VisualizerFeed()
    @ObservationIgnored private var pollTimer: Timer?

    isolated deinit {
        pollTimer?.invalidate()
    }

    func installTap(on mixer: AVAudioMixerNode) {
        guard !tapInstalled else { return }
        mixerNode = mixer
        mixer.removeTap(onBus: 0)

        let scratch = VisualizerScratchBuffers()
        let handler = Self.makeTapHandler(feed: feed, scratch: scratch)

        // Buffer size 2048 for Butterchurn FFT - provides 1024 frequency bins
        mixer.installTap(onBus: 0, bufferSize: 2048, format: nil, block: handler)
        tapInstalled = true
        startPollTimer()
    }

    func removeTap() {
        guard tapInstalled else { return }
        pollTimer?.invalidate()
        pollTimer = nil
        if let mixer = mixerNode {
            mixer.removeTap(onBus: 0)
        }
        tapInstalled = false
        mixerNode = nil
    }

    private func startPollTimer() {
        pollTimer?.invalidate()
        // Add to .common run-loop mode so polling continues during user
        // gestures. Timer.scheduledTimer defaults to .default mode, which
        // pauses while the main run loop is in .eventTracking (active
        // DragGesture). That stalled the data pipeline and made the
        // visualizer appear frozen during slider interaction even though
        // VisualizerView's own .common-mode display timer kept firing.
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            dispatchPrecondition(condition: .onQueue(.main))
            MainActor.assumeIsolated {
                self?.pollVisualizerData()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func pollVisualizerData() {
        onPollTick?()  // fire regardless of data availability (sample-rate poll)
        guard let data = feed.consume() else { return }
        updateLevels(with: data, useSpectrum: useSpectrum)
    }

    // Tap handler: runs on audio thread, zero allocations
    private nonisolated static func makeTapHandler(
        feed: VisualizerFeed,
        scratch: VisualizerScratchBuffers
    ) -> @Sendable (AVAudioPCMBuffer, AVAudioTime?) -> Void {
        { buffer, _ in
            // ... mix to mono, compute RMS/spectrum/FFT in scratch buffers ...

            // Publish to feed (non-blocking: drops frame on contention)
            _ = feed.tryPublish(from: scratch, oscilloscopeSamples: 76, validFrameCount: cappedFrameCount)
        }
    }
}
```

**Key design decisions**:
1. **`os_unfair_lock_trylock`** on audio thread: Non-blocking. If the main thread holds the lock, the audio thread drops that frame (imperceptible at 21.5 Hz producer rate with 30 Hz consumer rate).
2. **`os_unfair_lock_lock`** on main thread: Blocking is safe here. Lock hold time is bounded (5 small memcpy operations).
3. **Generation counter**: Consumer skips `consume()` when no new data has been published, avoiding unnecessary Array allocation.
4. **Pre-allocated arrays**: All storage in `VisualizerFeed` is allocated once at init. `tryPublish()` only performs `memcpy` into existing buffers.
5. **30 Hz poll timer**: Decouples UI update rate from audio callback rate. Timer runs on main run loop, so `MainActor.assumeIsolated` is safe (with `dispatchPrecondition` safety net).

**Pause tap policy**: The visualizer tap is removed on pause (not just stop), saving CPU when paused:
```
play()  -> installTap() + startPollTimer()
pause() -> removeTap()  (includes timer cleanup)
stop()  -> removeTap()  (includes timer cleanup)
```

**Real usage**: `VisualizerFeed.swift` (transport), `VisualizerScratchBuffers.swift` (per-producer DSP working set), `VisualizerPipeline.swift` (engine producer + 30 Hz consumer), `VideoTapVisualizerRender.swift` (video producer)

**Pitfalls**:
- `VisualizerFeed` is `@unchecked Sendable` — safety relies on the `os_unfair_lock` discipline (it is listed in `RenderThreadSafe.swift` so it can be stored in `VideoTapContext`)
- `removeTap()` must clean up the poll timer (runs on main run loop, must invalidate from main thread)
- `tryPublish()` must never allocate — use only `memcpy` / `withUnsafeBufferPointer` patterns
- `consume()` creates Arrays under lock — keep lock hold time minimal by copying raw data only
- Pre-allocated buffer sizes must match or exceed what the audio tap produces (4096 frame cap in scratch buffers)
- Test with Thread Sanitizer to verify no data races

### Pattern: Stream Decode Pipeline (Unified Audio)

**When to use**: Decoding internet radio streams (SHOUTcast/Icecast) into PCM for playback through AVAudioEngine, enabling EQ, visualization, and balance for streams — feature parity with local files.

**Why**: AVPlayer exposes no decoded PCM, so it cannot provide EQ, visualization or balance for streams. The custom decode pipeline feeds PCM into AVAudioEngine through an `AVAudioSourceNode`. Architecture: [MACAMP_ARCHITECTURE_GUIDE.md → Unified Audio Pipeline](MACAMP_ARCHITECTURE_GUIDE.md#unified-audio-pipeline-architecture).

**Architecture**:
```
URLSession (delegate queue)
    → SessionDelegateProxy (onResponse configures framer on decode queue)
    → SessionDelegateProxy (onData dispatches to DecodeContext)

DecodeContext (serial decode queue, @unchecked Sendable)
    → ICYFramer.consume() → .audio/.metadata chunks
    → AudioFileStreamParser.parse() → onPackets callback
    → handlePackets: split batch → individual enqueue
    → AudioConverterDecoder.decode() → Float32 PCM
    → LockFreeRingBuffer.write()

AVAudioSourceNode (real-time audio thread)
    → render block reads from LockFreeRingBuffer
    → interleaved Float32 at detected stream sample rate (44.1kHz is common, not fixed)
    → engine handles SRC to device rate (for example 48kHz)
```

**Buffer sizing**: the ring buffer is 32768 frames, so its duration depends on the stream's sample rate; see [StreamPlayer Architecture](MACAMP_ARCHITECTURE_GUIDE.md#streamplayer-architecture-unified-pipeline).

**Key component — DecodeContext**:
```swift
// File: MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift
// Purpose: Queue-confined mutable state for the decode pipeline
// Context: @unchecked Sendable because all access is on the serial decode queue

private final class DecodeContext: @unchecked Sendable {
    private let decodeQueue: DispatchQueue
    private let ringBuffer: LockFreeRingBuffer
    private let generation: UInt64            // stale-callback guard

    private var framer = ICYFramer()
    private var parser: AudioFileStreamParser?
    private var decoder: AudioConverterDecoder?
    private var magicCookie: Data?

    // All mutation happens on decodeQueue — no locks needed
}
```

**Key component — StreamDecodePipeline**:
```swift
// File: MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift
// Purpose: @MainActor orchestrator that owns the decode queue and DecodeContext
// Context: Observable state (playing/buffering/error) published to UI

@MainActor final class StreamDecodePipeline {
    private let decodeQueue = DispatchQueue(label: "...", qos: .userInitiated)
    private var decodeContext: DecodeContext?  // @unchecked Sendable, queue-confined

    // Callbacks to StreamPlayer (run on MainActor)
    var onStateChange: (@MainActor @Sendable (StreamState) -> Void)?
    var onFormatReady: (@MainActor @Sendable (Float64) -> Void)?
    var onMetadata: (@MainActor @Sendable (ICYFramer.ICYMetadata) -> Void)?
    var onTermination: (@MainActor @Sendable (StreamTerminationReason) -> Void)?
    var onPrebufferReady: (@MainActor @Sendable () -> Void)?
}
```

**Packet splitting for batch callbacks**:
```swift
// AudioFileStream delivers multiple packets in one callback (concatenated buffer).
// Each packet must be enqueued individually to prevent data loss when the
// AudioConverter's output buffer fills mid-batch.
for desc in descriptions {
    let packetData = data[offset..<(offset + size)]
    decoder.enqueue(data: Data(packetData), descriptions: [singleDesc])
}
```

**Real usage**: `StreamDecodePipeline.swift`, `StreamPlayer.swift`, `DecodeContext` (internal to pipeline)

**Pitfalls**:
- ICYFramer must be configured EXACTLY ONCE per stream (from the delegate queue, NOT MainActor) — see `tasks/unified-audio-pipeline/lessons-learned.md` Lesson 2
- M3U/PLS playlist URLs must be resolved before streaming (download and parse first)
- Diagnostic code (file I/O on decode queue) can mask timing bugs by adding latency

**Reference**: See `BUILDING_RETRO_MACOS_APPS_SKILL.md` Lesson #27 for the complete pipeline architecture, debugging methodology, and implementation checklist.

### Pattern: AudioConverter Input Buffer Lifecycle

**When to use**: Implementing the input callback for `AudioConverterFillComplexBuffer` when decoding compressed audio (MP3, AAC) to PCM.

**Why**: AudioConverter's input callback has a strict contract: the buffer provided to the converter must remain valid until the NEXT callback invocation.

**Implementation**:
```swift
// File: MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift
// Purpose: Manage packet queue and buffer lifetime for AudioConverter input callback
// Context: The input callback is called repeatedly within one FillComplexBuffer invocation

// WRONG: Free previous buffer at START of decode()
func decode() {
    prepareInputBuffer()  // Frees previous — but converter may still be using it!
    AudioConverterFillComplexBuffer(converter, inputCallback, ...)
}

// RIGHT: Free previous buffer inside the callback itself
let inputCallback: AudioConverterComplexInputDataProc = { ..., context in
    let decoder = context.decoder
    decoder.advanceToNextPacket()  // Frees PREVIOUS buffer (converter is done with it)
    // Provide NEXT packet's data pointer
    bufferList.pointee.mBuffers.mData = decoder.currentPacketData
    return noErr
}
```

**Key insight**: `AudioConverterFillComplexBuffer` calls the input callback repeatedly within a single invocation. The callback must manage its own packet queue — advancing to the next packet frees the previous one (safe because the converter is requesting new data = done with old data).

**Real usage**: `AudioConverterDecoder.swift` input callback

**Pitfalls**:
- Never free the input buffer outside the callback — the converter may still reference it
- The output buffer size limits how many input packets are consumed per call; remaining packets stay queued
- Test with various MP3 frame sizes (128kbps = ~417 bytes/frame, 320kbps = ~1044 bytes/frame)

### Pattern: Engine Graph Explicit Format

**When to use**: Reconnecting AVAudioEngine nodes after the stream bridge has been active, or any time graph topology changes between different audio source formats.

**Why**: After the stream bridge sets an explicit non-interleaved format on graph connections, reconnecting with `format: nil` causes EQ node format stickiness (error -10868). Always use explicit `AVAudioFormat` for all graph connections.

**Implementation**:
```swift
// File: MacAmpApp/Audio/AudioEngineController.swift (rewireForFile)
// Purpose: Prevent format stickiness when rewiring between stream and local playback
// Context: format: nil means "use previously negotiated format" — wrong after bridge

// WRONG: Relies on implicit format negotiation
engine.connect(playerNode, to: eqNode, format: nil)  // Uses stale stream format!

// RIGHT: Always specify explicit format
let graphFormat = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: outputNode.inputFormat(forBus: 0).sampleRate,
    channels: fileChannels,
    interleaved: false
)!
engine.connect(playerNode, to: eqNode, format: graphFormat)
```

**Key rules**:
1. **Never use `format: nil`** after a stream bridge has been active
2. **Disconnect inputs explicitly**: `disconnectNodeInput(eqNode, bus: 0)` clears stale input format cache; `disconnectNodeOutput` alone is insufficient
3. **Don't use `audioEngine.reset()`** for format cleanup — it does not scrub cached formats
4. **`deactivateStreamBridge()` in `rewireForFile(_:)`** — this is the single choke point for ALL local file playback paths (drag-and-drop, playlist double-click, etc.)

**Real usage**: `AudioEngineController.swift` `rewireForFile(_:)`, `activateStreamBridge(ringBuffer:sampleRate:)`, `deactivateStreamBridge()`

**Pitfalls**:
- Error -10868 (`kAudioUnitErr_FormatNotSupported`) almost always means a stale format from a previous graph configuration
- Direct playback paths that bypass PlaybackCoordinator must still deactivate the bridge — guard this in `rewireForFile(_:)`
- Engine start must be a hard gate: if `audioEngine.start()` fails, abort immediately (don't install taps or call `playerNode.play()`)

### Pattern: Engine File Duration as Authoritative Source (VBR)

**When to use**: Computing playback progress and seek targets for local audio files. The engine's `AVAudioFile.length / sampleRate` is the authoritative duration for runtime progress, NOT metadata duration from `AVAsset.duration`.

**Why**: VBR (Variable Bit Rate) MP3 files made the seek bar drift. `AVAsset.duration` uses the file's metadata header (which estimates duration from average bitrate), while `AVAudioFile.length` counts actual audio frames. These diverge on VBR files, causing the seek bar to jump at end-of-track when the two sources disagree.

**Implementation**:
```swift
// File: MacAmpApp/Audio/AudioEngineController.swift
// Purpose: Compute duration from actual audio frames, not metadata

var currentFileDuration: Double {
    guard let file = audioFile else { return 0 }
    let sampleRate = file.processingFormat.sampleRate
    guard sampleRate > 0 else { return 0 }
    return Double(file.length) / sampleRate  // Frame-accurate
}

// File: MacAmpApp/Audio/AudioPlayer.swift
// Purpose: Prefer engine duration over metadata duration for audio playback

// On track load: sync duration from file (not metadata)
let fileDuration = engine.currentFileDuration
if fileDuration.isFinite && fileDuration > 0 {
    currentDuration = fileDuration
}

// On track metadata arrival: only use metadata duration for non-audio or before file loads
if self.currentMediaType != .audio || self.engine.currentFileDuration <= 0 {
    self.currentDuration = track.duration  // Metadata fallback only
}

// On playback completion: use engine duration for final time display
if self.currentMediaType == .audio, self.engine.currentFileDuration > 0 {
    self.currentTime = self.engine.currentFileDuration
} else {
    self.currentTime = self.currentDuration  // Video: use metadata
}
```

**Why metadata duration is unreliable for VBR**:
- `AVAsset.duration` reads the XING/VBRI header or estimates from file size / average bitrate
- VBR files have sections with different bitrates — the estimate can be off by seconds
- `AVAudioFile.length` is the actual number of audio sample frames decoded — always accurate
- The difference causes the seek bar to show 3:42 while the engine says 3:38, creating a visible jump at track end

**When to use metadata duration**:
- Video files (engine may not have an audioFile loaded)
- Before the audio file is opened (initial display from playlist metadata)
- Non-audio media types where `AVAudioFile` is not applicable

**Real usage**: `AudioEngineController.swift` `currentFileDuration`, `AudioPlayer.swift` progress tracking and completion

**Pitfalls**:
- Do not cache metadata duration and use it for seek calculations after the engine file is loaded
- When the engine file is swapped (track change), `currentFileDuration` changes immediately — update `currentDuration` at the same point
- For video files, `engine.currentFileDuration` may return 0 (no audio file loaded) — always fall back to metadata duration in that case

### Pattern: MTAudioProcessingTap with Unmanaged Context

**When to use**: Carrying Swift state into a C-callback API that runs on a real-time thread and hands back an opaque `void *` — here, an `MTAudioProcessingTap` on a video `AVPlayerItem` that runs EQ, preamp, balance and the visualizer in place.

Video audio (played by `AVPlayer`, never routed through `AVAudioEngine`) gets the same DSP as local files this way. Architecture: [MACAMP_ARCHITECTURE_GUIDE.md → AVPlayer-Native Video DSP](MACAMP_ARCHITECTURE_GUIDE.md#avplayer-native-video-dsp); design rationale: `tasks/done/avplayer-native-video-dsp/plan.md` ADR-1, ADR-3, ADR-7, ADR-10.

**Implementation**:
```swift
// File: MacAmpApp/Audio/VideoDSP/VideoTap.swift
// Purpose: Balanced +1/-1 retain of the Context across the C boundary
// Context: Callbacks are file-scope `let` constants typed to the C typealias — nothing captured

private let tapInit: MTAudioProcessingTapInitCallback = { _, clientInfo, tapStorageOut in
    tapStorageOut.pointee = clientInfo
}

private let tapFinalize: MTAudioProcessingTapFinalizeCallback = { tap in
    let storage = MTAudioProcessingTapGetStorage(tap)
    Unmanaged<VideoTapContext>.fromOpaque(storage).release()        // -1, exactly once
}

private let tapProcess: MTAudioProcessingTapProcessCallback = { tap, framesToProcess, _, bufferList, framesOut, flagsOut in
    let storage = MTAudioProcessingTapGetStorage(tap)
    let context = Unmanaged<VideoTapContext>.fromOpaque(storage).takeUnretainedValue()  // borrow: no ARC on the render thread

    let status = MTAudioProcessingTapGetSourceAudio(tap, framesToProcess, bufferList, flagsOut, nil, framesOut)
    guard status == noErr else { return }
    // ... atomics + non-blocking trylock only; DSP in place on bufferList ...
}

enum VideoTap {
    @MainActor
    static func buildAudioMix(
        audioTrack: AVAssetTrack,
        context: VideoTapContext,
        preferredFormat: CMAudioFormatDescription? = nil
    ) throws -> AVMutableAudioMix {
        prewarmVideoTapTimebase()  // init the Mach timebase off the render thread
        let retained = Unmanaged.passRetained(context)               // +1 for the tap's lifetime
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(retained.toOpaque()),
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: tapUnprepare,
            process: tapProcess
        )

        var tapOut: MTAudioProcessingTap?
        let status: OSStatus
        // (DEBUG builds route through a failure-injection seam here)
        status = createTap(&callbacks, preferredFormat: preferredFormat, tapOut: &tapOut)
        guard status == noErr, let tap = tapOut else {
            retained.release()                                        // tapInit never ran → finalize never will
            throw VideoTapError.createFailed(status)
        }

        let inputParams = AVMutableAudioMixInputParameters(track: audioTrack)
        inputParams.audioTapProcessor = tap

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = [inputParams]
        return audioMix
    }
}
```

**Retain accounting**:

| Event | Count | Where |
|---|---|---|
| `Unmanaged.passRetained(context)` | +1 | `buildAudioMix`, before create |
| `MTAudioProcessingTapCreate…` fails | -1 | `retained.release()` on the failure branch |
| Last reference to the tap drops (item/player/mix deallocated, or `audioMix = nil`) | -1 | `tapFinalize` |
| `tapPrepare` / `tapProcess` / `tapUnprepare` | 0 | `takeUnretainedValue()` only |

**Real usage**: `VideoTap.swift` (callbacks + builder), `VideoTapContext.swift` (the state), called from `AudioPlayer.startVideoLoad(track:)`. Lifecycle coverage: `Tests/MacAmpTests/VideoTapLifecycleTests.swift`.

**Pitfalls**:
- The render callbacks must not allocate, block on a lock, log, touch `@MainActor` state, or retain/release — read atomics and use `withLockIfAvailable` only (see [Render-Thread-Safe Shared State](#pattern-render-thread-safe-shared-state))
- `tapFinalize` may run asynchronously on a background queue after the last reference drops. Teardown must not wait for it; tests poll for release (see [Polling for Asynchronous Release](#pattern-polling-for-asynchronous-release))
- Keep all render-owned state (`BiquadCascade`, `VisualizerScratchBuffers`) as fields of the one retained Context. A second retained wrapper would need its own balance proof
- `tapUnprepare` only flips `isActive`; releasing there would double-release when `tapFinalize` runs
- The DEBUG seam `VideoTap._testForceTapCreateFailure` must skip the real create entirely — a real tap that is also "failed" would release twice (once on the failure branch, once in `tapFinalize`)
- Detach by pausing first, then `VideoTap.detach(from:)` (`playerItem.audioMix = nil`) — see `AudioPlayer.pauseAndDetachVideoTapIfNeeded()`

### Pattern: Render-Thread-Safe Shared State

**When to use**: State written by `@MainActor` code and read by an audio render thread, where an actor is not an option (the render thread cannot `await` or hop executors).

The `VideoTapContext` envelope is `@unchecked Sendable` to cross the C boundary. The unsafety is contained by restricting every stored property to a thread-safe storage shape and enforcing that with tests. Rationale: plan ADR-3, ADR-3a, ADR-4 amendment #2.

**Implementation (storage shape)**:
```swift
// File: MacAmpApp/Audio/VideoDSP/VideoTapContext.swift
// Purpose: Every stored property is Atomic, Mutex, immutable, or RenderThreadSafe

final class VideoTapContext: @unchecked Sendable {
    let coefficients: Mutex<BiquadCoefficientSet?>   // main → render hand-off (rare, non-trivial)
    let cascade: BiquadCascade                        // render-confined filter state
    let feed: VisualizerFeed                          // shared SPSC visualizer feed
    let scratch: VisualizerScratchBuffers             // render-confined visualizer working set
    let balance: Atomic<UInt32>                       // Float.bitPattern, [-1, 1]
    let isEqOn: Atomic<Bool>
    let preampLinearGainBits: Atomic<UInt32>          // Float.bitPattern
    let processingFormatTag: Atomic<UInt32>           // ASBD gate set by tapPrepare
    let pendingSampleRate: Atomic<UInt64>             // Double.bitPattern
    // ... Atomic<UInt64> telemetry counters ...

    func installCoefficients(_ newSet: BiquadCoefficientSet) {
        coefficients.withLock { $0 = newSet }         // main thread may block briefly
    }
}
```

**Implementation (render-side non-blocking read)**:
```swift
// File: MacAmpApp/Audio/VideoDSP/VideoTap.swift (tapProcess)
// Double optional: outer nil = contended, .some(nil) = nothing installed yet
switch context.coefficients.withLockIfAvailable({ $0 }) {
case .some(.some(let set)): context.cascade.currentCoefficients = set   // copy into render-owned cache
case .some(.none): context.cascade.currentCoefficients = nil            // bypass the cascade
case .none: break                                                       // reuse the last cache
}
```

**Implementation (publish order for a gate)**:
```swift
// File: MacAmpApp/Audio/VideoDSP/VideoTap.swift (tapPrepare)
// Everything the render path reads alongside the gate is stored BEFORE the releasing store
context.pendingSampleRate.store(asbd.mSampleRate.bitPattern, ordering: .relaxed)
context.isActive.store(true, ordering: .relaxed)
context.processingFormatTag.store(tag, ordering: .releasing)

// tapProcess pairs it with an acquiring load before trusting pendingSampleRate
let formatTag = context.processingFormatTag.load(ordering: .acquiring)
```

**Implementation (containment marker)**:
```swift
// File: MacAmpApp/Audio/RenderThreadSafe.swift
// All conformances live in this one file so the audit surface is one file.
internal protocol RenderThreadSafe: ~Copyable {}

extension Atomic: RenderThreadSafe {}
extension Mutex: RenderThreadSafe {}
extension VisualizerFeed: RenderThreadSafe {}
extension VisualizerScratchBuffers: RenderThreadSafe {}

// Render-confined: created on the main thread in `VideoTapContext.init`, then
// touched only by the render thread inside `tapProcess`. Main never accesses it.
extension BiquadCascade: RenderThreadSafe {}
```

The permitted/forbidden storage rules, memory ordering and the contract tests (`VideoTapSendableContractTests`) are in [MACAMP_ARCHITECTURE_GUIDE.md → Audio Mechanism Concurrency Contract](MACAMP_ARCHITECTURE_GUIDE.md#audio-mechanism-concurrency-contract).

**Real usage**: `VideoTapContext.swift`, `RenderThreadSafe.swift`, `VideoTap.swift` (`tapPrepare`, `tapProcess`)

**Pitfalls**:
- Don't collapse the `withLockIfAvailable` result with `??` or `if let` — "contended" (keep the cache) and "nothing installed" (bypass) need different handling
- Hold the Mutex only to copy the value out; run the DSP lock-free against the render-owned copy
- Store `Float`/`Double` through atomics as `bitPattern` (`Atomic<UInt32>` / `Atomic<UInt64>`)
- Main-thread writers (fan-out) write only the Mutex and atomics, never a render-confined field — the contract test that limits `.cascade` to `VideoTapContext.swift` and `VideoTap.swift` catches this
- The contract test's `Mirror` pass skips `~Copyable` fields (`Atomic`/`Mutex` reflect as `Void`); a future non-atomic `~Copyable` `let` is caught only by review against the header contract
- Adding a field means updating the header contract comment and, if needed, adding a conformance in `RenderThreadSafe.swift`

### Pattern: Pinned Tap Format and Build-Time audioMix

**When to use**: Installing an `MTAudioProcessingTap` on an `AVPlayerItem` so its processing format is stable and it is never added to an item that is already playing.

Rationale: plan ADR-7 (+ amendment) and ADR-12.

**Implementation (pin the format)**:
```swift
// File: MacAmpApp/Audio/VideoDSP/VideoTap.swift
// Stereo Float32 non-interleaved at the source rate; nil → fall back to the default create

@MainActor
static func preferredProcessingFormat(for audioTrack: AVAssetTrack) async -> CMAudioFormatDescription? {
    guard let source = try? await audioTrack.load(.formatDescriptions).first,
          let sampleRate = AVAudioFormat(formatDescription: source)?.sampleRate else { return nil }
    return AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)?.formatDescription
}

private static func createTap(
    _ callbacks: inout MTAudioProcessingTapCallbacks,
    preferredFormat: CMAudioFormatDescription?,
    tapOut: inout MTAudioProcessingTap?
) -> OSStatus {
    if let preferredFormat {
        return MTAudioProcessingTapCreateWithPreferredFormat(
            kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, preferredFormat, &tapOut)
    }
    return MTAudioProcessingTapCreate(
        kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tapOut)
}
```

**Implementation (audioMix set once, before the AVPlayer exists)**:
```swift
// File: MacAmpApp/Audio/VideoPlaybackController.swift (loadVideo)
let asset = AVURLAsset(url: url)

let audioMix: AVMutableAudioMix?
if let audioMixBuilder {
    audioMix = await audioMixBuilder(asset)
} else {
    audioMix = nil
}

if let isStillRelevant, !isStillRelevant() {
    AppLog.debug(.audio, "VideoPlaybackController: load aborted (stale)")
    return
}

let playerItem = AVPlayerItem(asset: asset)
if let audioMix {
    playerItem.audioMix = audioMix
}

let newPlayer = AVPlayer(playerItem: playerItem)
```

**Why pin**: an unpinned tap follows the output device's format, which caused audible pumping over AirPlay 2; pinning to **stereo** keeps channels 0/1 as L/R for balance. Details: [Processing Format](MACAMP_ARCHITECTURE_GUIDE.md#processing-format).

**Real usage**: `VideoTap.preferredProcessingFormat(for:)` / `createTap`, `VideoPlaybackController.loadVideo(url:autoPlay:audioMixBuilder:isStillRelevant:)`, orchestrated by `AudioPlayer.startVideoLoad(track:)`

**Pitfalls**:
- Never assign `audioMix` to an item an `AVPlayer` already owns, or while playing; to detach, pause first
- One tap + one Context per `AVPlayerItem`; a new item gets a freshly built pair
- `tapPrepare` still validates the negotiated format (Float32 LPCM gate) — the preferred format is a request, not a guarantee
- 5.1+ sources play as stereo while the pin is in place, including on multichannel outputs

### Pattern: Parallel DSP Fan-Out via WeakBox Registries

**When to use**: One `@MainActor` owner of a setting must drive several DSP sinks with independent lifetimes (the engine node plus zero or more per-video-item taps), without the owner keeping the sinks alive.

EQ is owned by `EqualizerController`, balance by `AudioPlayer`. Each fans out to its engine node and to registered `VideoTapContext`s through its own registry. Rationale: plan ADR-5. (Contrast [Coordinator Volume Routing](#pattern-coordinator-volume-routing), where a coordinator fans one value out to whole playback backends.) State/owner table: [EQ and Balance Fanout](MACAMP_ARCHITECTURE_GUIDE.md#eq-and-balance-fanout).

**Implementation**:
```swift
// File: MacAmpApp/Utilities/WeakBox.swift
final class WeakBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}

// File: MacAmpApp/Audio/EqualizerController.swift
var isEqOn: Bool = false {
    didSet {
        eqNode.bypass = !isEqOn                              // sink 1: engine AVAudioUnitEQ
        UserDefaults.standard.set(isEqOn, forKey: "isEqOn")
        fanOutToVideoTaps()                                  // sinks 2…n: registered video taps
    }
}

@ObservationIgnored private var registeredVideoTapContexts: [WeakBox<VideoTapContext>] = []
@ObservationIgnored private var lastFannedSampleRate: [ObjectIdentifier: Double] = [:]

func registerVideoTapContext(_ context: VideoTapContext) {
    registeredVideoTapContexts.removeAll { $0.value == nil || $0.value === context }
    registeredVideoTapContexts.append(WeakBox(context))
    pushEQState(to: context)                                 // current before its first render
}

func unregisterVideoTapContext(_ context: VideoTapContext) {
    registeredVideoTapContexts.removeAll { $0.value == nil || $0.value === context }
    lastFannedSampleRate.removeValue(forKey: ObjectIdentifier(context))
}

private func fanOutToVideoTaps() {
    guard !registeredVideoTapContexts.isEmpty else { return } // fast path: audio-only
    registeredVideoTapContexts.removeAll { $0.value == nil }
    for box in registeredVideoTapContexts {
        guard let context = box.value else { continue }
        pushEQState(to: context)
    }
}

private func pushEQState(to context: VideoTapContext, sampleRate: Double? = nil) {
    let state = equalizerState
    let rate = sampleRate ?? Double(bitPattern: context.pendingSampleRate.load(ordering: .relaxed))
    context.isEqOn.store(state.isEqOn, ordering: .relaxed)
    context.preampLinearGainBits.store(state.preampLinearGain.bitPattern, ordering: .relaxed)
    context.installCoefficients(BiquadCoefficientSet.compute(for: state, sampleRate: rate))
    lastFannedSampleRate[ObjectIdentifier(context)] = rate
}
```

**Balance uses the same shape with its own registry**:
```swift
// File: MacAmpApp/Audio/AudioPlayer.swift
var balance: Float = 0.0 {
    didSet {
        engine?.setBalance(balance)
        fanOutBalanceToVideoTaps()
    }
}
```

**Input that arrives after registration**: coefficients depend on the sample rate, which only the render thread learns (`tapPrepare` → `pendingSampleRate`). The owner polls it on the visualizer's 30 Hz main-thread tick and recomputes only when it changes:
```swift
// File: MacAmpApp/Audio/AudioPlayer.swift (init)
visualizerPipeline.onPollTick = { [weak self] in
    self?.equalizer.pollVideoTapSampleRates()
}
```

**Real usage**: `EqualizerController.swift` (EQ + preamp), `AudioPlayer.swift` (balance), registration in `AudioPlayer.startVideoLoad(track:)`, unregistration in `pauseAndDetachVideoTapIfNeeded()`. Tests: `Tests/MacAmpTests/VideoTapFanoutTests.swift`.

**Pitfalls**:
- Registries hold `WeakBox`, never the Context — the tap owns the Context's lifetime; prune `nil` boxes on each pass
- Register pushes current state immediately; otherwise the first buffers render with defaults
- Dedupe by identity (`===`) on register; drop `ObjectIdentifier`-keyed bookkeeping on unregister, since identifiers can be reused after deallocation
- Keep one owner per setting and one registry per owner; don't route balance through the EQ controller or vice versa
- Engine and tap must share constants so they can't drift: `BiquadCoefficientSet.frequencies` is read by both `EqualizerController.configureEQ()` and the cascade

### Pattern: Dual-Producer Visualizer Feed

**When to use**: Two mutually exclusive real-time sources (engine tap for audio, `MTAudioProcessingTap` for video) must drive the same visualizer UI.

Rationale: plan ADR-6.

**Implementation (producers share the feed, each owns its scratch)**:
```swift
// File: MacAmpApp/Audio/VisualizerPipeline.swift
// The feed is exposed so the video producer publishes to the same single slot
var sharedFeed: VisualizerFeed { feed }

// Engine producer (AVAudioEngine tap block, AVAudioPCMBuffer input)
_ = feed.tryPublish(from: scratch, oscilloscopeSamples: 76, validFrameCount: cappedFrameCount)

// File: MacAmpApp/Audio/AudioPlayer.swift (startVideoLoad)
let context = VideoTapContext(feed: self.visualizerPipeline.sharedFeed)

// File: MacAmpApp/Audio/VideoDSP/VideoTap.swift (tapProcess, after EQ/balance)
let sampleRate = Double(bitPattern: context.pendingSampleRate.load(ordering: .relaxed))
videoTapVisualizerRender(bufferList: bufferList, frames: frames, sampleRate: sampleRate,
                         scratch: context.scratch, feed: context.feed)
```

**Implementation (consumer lifecycle for video)**: the engine tap normally starts the 30 Hz poll timer; during video the engine tap is not installed, so `AudioPlayer` starts and stops it explicitly.
```swift
// File: MacAmpApp/Audio/AudioPlayer.swift (playTrack)
case .video:
    pauseAndDetachVideoTapIfNeeded()
    startVideoLoad(track: track)
    visualizerPipeline.startVideoVisualization()
    transition(to: .playing)

// UI consumers gate on this instead of isEngineRendering
var isVisualizerRendering: Bool {
    isEngineRendering || (currentMediaType == .video && videoPlaybackController.isPlaying)
}
```

**No flag-driven generalization**: the two producers take different buffer types (`AVAudioPCMBuffer` vs `AudioBufferList`) under different threading contracts, so they stay two parallel functions rather than one function with a mode flag. The Butterchurn FFT is already shared (`VisualizerScratchBuffers.processButterchurnFFT`); the RMS and Goertzel loops are duplicated with a "MUST match" comment in both.

**Real usage**: `VisualizerPipeline.swift` (`makeTapHandler`, `sharedFeed`, `startVideoVisualization`/`stopVideoVisualization`, `onPollTick`), `VideoTapVisualizerRender.swift`, `AudioPlayer.swift` (`isVisualizerRendering`), `VisualizerView.swift`. Tests: `Tests/MacAmpTests/VideoTapVisualizerRenderTests.swift`.

**Pitfalls**:
- Changing the RMS or Goertzel math in one producer means changing it in the other
- The single slot is last-write-wins and correct only because one producer is active at a time; a design that runs both concurrently needs per-producer feeds
- Stop the video poll timer on every exit path — video→audio switch, `stop()`, and natural completion in `onPlaybackEnded` (otherwise the 30 Hz timer leaks); repeat-one restart bypasses `playTrack` and must re-arm it
- `stopVideoVisualization()` also clears cached data so bars don't freeze on the last frame
- Visualizer views and Butterchurn snapshots must check `isVisualizerRendering`; `isEngineRendering` is false for all of video

### Pattern: Sampled Deadline Telemetry

**When to use**: Production visibility into whether a real-time callback fits its buffer deadline, without logging or timing every callback on the render thread.

Used in `tapProcess`. Rationale: `tasks/done/avplayer-native-video-dsp/plan.md` Phase 6.

**Implementation**:
```swift
// File: MacAmpApp/Audio/VideoDSP/VideoTap.swift (tapProcess)
let callIndex = context.processCallCount.add(1, ordering: .relaxed).oldValue  // pre-increment value
// ...
let sampleTiming = (callIndex & 63) == 0                                      // callbacks 0, 64, 128, …
let startTicks = sampleTiming ? mach_absolute_time() : 0
// ... full DSP + visualizer work ...
if sampleTiming, sampleRate.isFinite, sampleRate > 0 {
    let endTicks = mach_absolute_time()
    let elapsedNanos = videoTapHostTicksToNanos(endTicks &- startTicks)
    let budgetNanos = UInt64(Double(frames) / sampleRate * 1_000_000_000)
    context.recordProcessingDeadline(elapsedNanos: elapsedNanos, budgetNanos: budgetNanos, nowHostTime: endTicks)
}

// File: MacAmpApp/Audio/VideoDSP/VideoTapContext.swift
// Render-thread-safe and allocation-free: atomics only, integer-ratio comparisons
func recordProcessingDeadline(elapsedNanos: UInt64, budgetNanos: UInt64, nowHostTime: UInt64) {
    guard budgetNanos > 0 else { return }
    if elapsedNanos * 10 > budgetNanos {          // > 10% of budget → overrun
        _ = budgetOverrunCount.add(1, ordering: .relaxed)
    }
    if elapsedNanos * 2 > budgetNanos {           // > 50% of budget → deadline risk
        _ = deadlineRiskCount.add(1, ordering: .relaxed)
        lastDeadlineRiskHostTime.store(nowHostTime, ordering: .relaxed)
    }
}
```

**Readout**: there is no log path — counters are read on the main thread via `VideoTapContext.diagnosticSnapshot` (an immutable `Sendable` `VideoTapDiagnostics`). In practice they are read from LLDB with a breakpoint in `EqualizerController.pollVideoTapSampleRates()`, which fires at 30 Hz during video. In optimized builds the computed `diagnosticSnapshot` getter is stripped; load the atomics directly instead (`expr -l swift -- import Synchronization`, then `….registeredVideoTapContexts[0].value!.budgetOverrunCount.load(ordering: .relaxed)`). Procedure: `tasks/done/avplayer-native-video-dsp/verification.md` gate 8.5e.

**Real usage**: `VideoTap.swift` (`tapProcess`, cached `videoTapMachTimebase`, `prewarmVideoTapTimebase()`), `VideoTapContext.swift` (`recordProcessingDeadline`, `diagnosticSnapshot`). Tests: `Tests/MacAmpTests/VideoTapTelemetryTests.swift` call `recordProcessingDeadline` directly with synthetic values.

**Pitfalls**:
- 1-in-64 sampling is advisory observability, not a CPU gate — use the dense benchmark (see [Wall-Clock Benchmarks Disabled Under TSan](#pattern-wall-clock-benchmarks-disabled-under-tsan)) for pass/fail
- Query `mach_timebase_info` once and prewarm it from the main thread, so the first sampled callback doesn't pay the lazy-init once-token
- No `os_log`/`print` on the render thread, even on the sampled path
- `diagnosticSnapshot` does independent relaxed loads; fields may be from slightly different instants

---

## Async/Await Patterns

### Pattern: Background I/O with @concurrent Static Functions (Swift 6.2)

**When to use**: File I/O operations that should run off the calling actor's executor

**Why `@concurrent`**: in Swift 6.2 a nonisolated `async` function inherits the caller's executor by default, so file I/O called from `@MainActor` code would run on the main actor. `@concurrent` on a static function explicitly runs it off the caller's actor, replacing the `Task.detached` escape hatch while keeping actor boundaries explicit. The surrounding `Task {}` stays unstructured, so the caller owns it (and can cancel it); it inherits the caller's priority, so no `priority:` argument is needed.

**Implementation**:
```swift
// File: MacAmpApp/Audio/EQPresetStore.swift
// Purpose: Perform file writes off main thread without blocking UI
// Context: Per-track preset persistence - writes happen on every EQ change

@MainActor
@Observable
final class EQPresetStore {
    @ObservationIgnored var perTrackPresets: [String: EqfPreset] = [:]
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    /// Save per-track presets to JSON file (serialized, off-actor)
    /// State is captured before dispatch to prevent race conditions
    func savePerTrackPresets() {
        guard let url = presetsFileURL() else { return }

        // CRITICAL: Capture current state BEFORE dispatching
        let presetsToSave = perTrackPresets
        let previousTask = saveTask
        saveTask = Task {
            _ = await previousTask?.result  // serialize: wait for previous write to complete
            await Self.savePresetsToDisk(presets: presetsToSave, url: url)
        }
    }

    // MARK: - @concurrent Static I/O Functions (Swift 6.2)
    // These run off the caller's actor to avoid blocking MainActor with file I/O.

    @concurrent
    private static func savePresetsToDisk(presets: [String: EqfPreset], url: URL) async {
        do {
            let data = try JSONEncoder().encode(presets)
            try data.write(to: url, options: .atomic)
            AppLog.debug(.audio, "Saved \(presets.count) per-track presets")
        } catch {
            AppLog.warn(.audio, "Failed to save per-track presets: \(error)")
        }
    }
}
```

**Key elements**:
1. **State snapshot**: Capture state before dispatching to avoid Sendable violations
2. **Serialized writes**: Task chaining via `previousTask?.result` ensures writes complete in order
3. **`@concurrent` static func**: Runs off the MainActor executor without `Task.detached`
4. **Error logging**: Use `AppLog` for errors since we can't propagate them

**When to use**:
- Periodic auto-saves (preference changes, EQ adjustments)
- Non-critical persistence (cache files, recent items)
- High-frequency updates where blocking would cause UI lag

**When NOT to use**:
- Operations where success confirmation is needed (use `await` on the task)
- Writes that must complete before app terminates (use synchronous I/O or `await`)
- Operations with complex error recovery requirements

**Migrating from `Task.detached`**: replace `Task.detached(priority: .utility) { await doWork(snapshot) }` with an owned `saveTask = Task { _ = await previousTask?.result; await Self.doWork(snapshot) }` calling a `@concurrent private static func doWork(_:) async`.

**Real usage**: `EQPresetStore` (`savePresetsToDisk`, `loadPresetsFromDisk`, `parseEqfFile`), `SkinArchiveLoader.loadAsync(from:expectedSheets:)`

**Pitfalls**:
- Always capture state BEFORE creating the Task
- The captured type must be `Sendable` (value types or explicitly marked)
- Task chaining serializes writes, preventing out-of-order persistence
- Fire-and-forget loses error propagation - ensure adequate logging

### Pattern: Callback Synchronization for Cross-Component Communication

**When to use**: Coordinating state updates between extracted components without tight coupling

**Swift 6 Relevance**: Closures must be marked `@Sendable` when crossing actor boundaries

**Implementation**:
```swift
// File: MacAmpApp/Audio/VideoPlaybackController.swift
// Purpose: Notify AudioPlayer of video events without direct reference
// Context: VideoPlaybackController extracted but needs to sync UI state

@MainActor
@Observable
final class VideoPlaybackController {
    // MARK: - Callbacks

    /// Called when video playback reaches end
    var onPlaybackEnded: (() -> Void)?

    /// Called periodically during playback with time updates (for UI sync)
    /// Parameters: currentTime, duration, progress
    var onTimeUpdate: ((Double, Double, Double) -> Void)?

    // ... playback methods set up time observer ...

    private func setupTimeObserver() {
        tearDownTimeObserver()  // Clean first
        guard let player else { return }

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self, weak player] time in
            Task { @MainActor in
                guard let self, let player else { return }
                // Identity guard: a superseding loadVideo may have
                // replaced `self.player` while this periodic tick was
                // queued. Ignore the stale callback.
                guard self.player === player else { return }
                // ... compute time values ...

                // Notify AudioPlayer to sync its UI-bound properties
                self.onTimeUpdate?(seconds, dur, self.progress)
            }
        }
    }
}

// File: MacAmpApp/Audio/AudioPlayer.swift
// Purpose: Wire up callbacks during initialization

init() {
    // ... other setup ...

    // Setup video playback callbacks
    videoPlaybackController.onPlaybackEnded = { [weak self] in
        Task { @MainActor in
            self?.onPlaybackEnded()
        }
    }
    videoPlaybackController.onTimeUpdate = { [weak self] time, duration, progress in
        guard let self else { return }
        // Sync UI-bound properties during video playback
        self.currentTime = time
        self.currentDuration = duration
        self.playbackProgress = progress
    }
}
```

**Benefits**:
1. **Loose coupling**: VideoPlaybackController doesn't import or reference AudioPlayer
2. **Testability**: Callbacks can be mocked or replaced in tests
3. **Flexibility**: Multiple listeners possible (though currently 1:1)
4. **Clear data flow**: Explicit about what data crosses component boundaries

**Real usage**:
- `VideoPlaybackController.swift` for `onPlaybackEnded`, `onTimeUpdate` callbacks
- `AudioPlayer.swift` for `onTrackMetadataUpdate`, `onPlaylistAdvanceRequest` callbacks

**AudioPlayer callbacks**: two purpose-specific callbacks rather than one generic handler:
```swift
// File: MacAmpApp/Audio/AudioPlayer.swift
// Two distinct callbacks replace the ambiguous single handler

/// Called when a placeholder track is replaced with loaded metadata (title/artist arrived)
var onTrackMetadataUpdate: ((Track) -> Void)?

/// Called when end-of-track auto-advance produces a track for the coordinator to play
var onPlaylistAdvanceRequest: ((Track) -> Void)?
```

These are wired in `PlaybackCoordinator.init(audioPlayer:streamPlayer:)`:
```swift
// File: MacAmpApp/Audio/PlaybackCoordinator.swift (init)
self.audioPlayer.onTrackMetadataUpdate = { [weak self] track in
    guard let self else { return }
    self.updateTrackMetadata(track)
}

self.audioPlayer.onPlaylistAdvanceRequest = { [weak self] track in
    guard let self else { return }
    Task { @MainActor in
        await self.handleExternalPlaylistAdvance(track: track)
    }
}
```

**Pitfalls**:
- Always use `[weak self]` in callbacks to prevent retain cycles
- Mark closures `@Sendable` if they cross actor boundaries
- Don't pass non-Sendable types through callbacks in Swift 6
- Consider using `AsyncStream` for high-frequency events
- **Don't conflate unrelated events in a single callback** -- the `externalPlaybackHandler` anti-pattern made it ambiguous whether the coordinator should refresh metadata or advance the playlist

#### AudioEngineController Callback Wiring

**Context**: `AudioEngineController` owns the progress timer, audio scheduling completion and bridge state, but `AudioPlayer` owns the observable state that drives the UI. Three callbacks bridge this gap:

```swift
// File: MacAmpApp/Audio/AudioEngineController.swift
// Purpose: Expose engine-level events to AudioPlayer without back-reference

@MainActor
final class AudioEngineController {
    /// Called on every progress timer tick with (currentTime, progress).
    var onProgressUpdate: ((_ currentTime: Double, _ progress: Double) -> Void)?

    /// Called when a scheduled audio segment completes. The UUID identifies the seek
    /// operation that scheduled the segment, allowing AudioPlayer to filter stale completions.
    var onPlaybackEnded: ((_ fromSeekID: UUID?) -> Void)?

    /// Called when isBridgeActive changes so AudioPlayer can update its observable property.
    var onBridgeStateChanged: ((_ isActive: Bool) -> Void)?
}

// File: MacAmpApp/Audio/AudioPlayer.swift
// Purpose: Wire engine callbacks during init

init() {
    // ... volume/balance restore, engine creation ...

    engine.onProgressUpdate = { [weak self] currentTime, progress in
        guard let self else { return }
        self.currentTime = currentTime
        if self.currentDuration > 0 {
            self.playbackProgress = progress
        } else {
            self.playbackProgress = 0
        }
    }
    engine.onPlaybackEnded = { [weak self] seekID in
        self?.onPlaybackEnded(fromSeekID: seekID)
    }
    engine.onBridgeStateChanged = { [weak self] isActive in
        self?.isBridgeActive = isActive
    }
}
```

**Why three separate callbacks (not a delegate protocol)**:
- Each callback has a distinct signature and firing frequency (progress fires at 10 Hz, bridge state fires rarely)
- Closures allow `[weak self]` without requiring a formal protocol conformance
- Consistent with the existing VideoPlaybackController callback pattern

**Real usage**: `AudioEngineController.swift` declares the callbacks, `AudioPlayer.swift` wires them in `init()`

### Pattern: Stream Bridge Lifecycle Callbacks

**When to use**: Coordinating stream decode pipeline state with AVAudioEngine graph topology changes. The stream bridge (AVAudioSourceNode reading from LockFreeRingBuffer) must be activated when audio format is detected and deactivated when the stream terminates.

StreamPlayer produces PCM into a ring buffer and AudioPlayer consumes it via `AVAudioSourceNode`, so the bridge needs an explicit lifecycle.

**Implementation**:
```swift
// File: MacAmpApp/Audio/StreamPlayer.swift
// Purpose: Expose lifecycle events to PlaybackCoordinator

@MainActor @Observable
final class StreamPlayer {
    /// Called when audio format is detected and prebuffering is complete.
    /// PlaybackCoordinator uses this to activate the engine bridge.
    var onFormatReady: (@MainActor (Float64) -> Void)?

    /// Called when stream reaches a terminal state (idle or error).
    /// PlaybackCoordinator uses this to deactivate the engine bridge.
    var onStreamTerminated: (@MainActor () -> Void)?
}

// File: MacAmpApp/Audio/PlaybackCoordinator.swift
// Purpose: Wire callbacks during init to manage bridge lifecycle

init(audioPlayer: AudioPlayer, streamPlayer: StreamPlayer) {
    // ... other setup ...

    // Wire stream pipeline format-ready callback to activate engine bridge
    self.streamPlayer.onFormatReady = { [weak self] sampleRate in
        guard let self,
              let ringBuffer = self.streamPlayer.currentRingBuffer else { return }
        self.audioPlayer.activateStreamBridge(ringBuffer: ringBuffer, sampleRate: sampleRate)
        self.audioPlayer.setStreamSilenced(false)
        // Share the audio IO workgroup with the decode thread (real-time scheduling group)
        self.streamPlayer.setAudioWorkgroup(self.audioPlayer.audioWorkgroup)
    }

    // Wire stream terminal state callback for bridge teardown
    self.streamPlayer.onStreamTerminated = { [weak self] in
        guard let self else { return }
        if self.audioPlayer.isBridgeActive {
            self.audioPlayer.deactivateStreamBridge()
        }
    }
}
```

**ICY framer race prevention**:
```swift
// WRONG: Configure framer from MainActor (delayed, races with incoming data)
func handleHTTPResponse(_ response: HTTPURLResponse) {  // @MainActor
    configureFramer(response)  // Too late — data already arriving
}

// RIGHT: Configure framer from URLSession delegate queue (immediate)
sessionDelegate.onResponse = { [weak self] response in  // delegate queue
    self?.decodeQueue.async {
        self?.decodeContext?.framer.configure(from: response)  // Before any data
    }
}
```

**Key invariants**:
- `onFormatReady` fires ONCE per stream, after the prebuffer threshold is reached (16384 frames, ~371 ms at 44.1 kHz; 8192 frames when resuming)
- `onStreamTerminated` fires on idle or error states — PlaybackCoordinator checks `isBridgeActive` before deactivating
- ICYFramer.configure() must be called EXACTLY ONCE per stream, from the delegate queue (NOT MainActor)
- Bridge deactivation must occur in ALL playback transition paths (stream-to-local, stream-to-stream, stop)

**Real usage**: `StreamPlayer.swift` callbacks, `PlaybackCoordinator.swift` init wiring

**Pitfalls**:
- Calling `configureFramer` from both delegate queue AND MainActor causes double-configure — the second call resets `audioByteCount`, corrupting ICY metadata alignment for the entire stream
- When adding an "early" call to fix a race, ALWAYS search for and remove the "late" call (`grep -r "configureFramer"`)
- Diagnostic code (file I/O) on the decode queue can mask this timing bug by adding latency

### Pattern: Exponential Backoff Reconnect with Bridge Tear-Down

**When to use**: Automatically reconnecting internet radio streams after transient network failures while maintaining AVAudioEngine bridge integrity.

**Implementation**:
```swift
// File: MacAmpApp/Audio/StreamPlayer.swift
// Purpose: Reconnect with exponential backoff, tearing down and re-creating the bridge each attempt
// (simplified: the real method also resets isBuffering/error and fires onStreamStateChanged)
// Context: Each reconnect needs a fresh ring buffer and fresh bridge activation

private static let maxReconnectAttempts = 10
private static let maxBackoffSeconds: Double = 16.0

private func attemptReconnect() {
    reconnectAttempt += 1
    guard reconnectAttempt <= Self.maxReconnectAttempts else {
        // Terminal: give up after max attempts
        isReconnecting = false
        error = "Connection lost after \(Self.maxReconnectAttempts) attempts"
        onStreamTerminated?()
        return
    }

    isReconnecting = true

    // CRITICAL: Tear down bridge — new ring buffer needs new bridge activation
    onStreamTerminated?()

    let attempt = reconnectAttempt
    reconnectTask = Task { @MainActor [weak self] in
        guard let self else { return }

        let delay = min(Self.maxBackoffSeconds, pow(2.0, Double(attempt - 1)))
        // Backoff: 1s, 2s, 4s, 8s, 16s, 16s, 16s, ...

        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled, let station = self.currentStation else { return }

        // Fresh ring buffer for new stream connection
        let rb = LockFreeRingBuffer(capacity: 32768, channelCount: 2)
        self.ringBuffer = rb
        self.pipeline.start(url: station.streamURL, ringBuffer: rb)
    }
}
```

**Stable-playback counter reset**:
```swift
// File: MacAmpApp/Audio/StreamPlayer.swift
// Purpose: Reset reconnect counter after sustained playback proves the connection is healthy

private func startPlaybackStableTimer() {
    playbackStableTask?.cancel()
    playbackStableTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .seconds(5))
        guard let self, self.isPlaying else { return }
        // Stream has been stable for 5 seconds — reset reconnect counter
        self.reconnectAttempt = 0
    }
}
```

**Reconnect lifecycle**:
```
Stream playing → network error → handleTermination()
  → isReconnectable(reason)? → YES
  → attemptReconnect()
    → onStreamTerminated() → PlaybackCoordinator tears down bridge
    → Task.sleep(backoff)
    → pipeline.start() with fresh ring buffer
    → onFormatReady() → PlaybackCoordinator activates new bridge
    → isPlaying = true → startPlaybackStableTimer()
    → 5 seconds stable → reconnectAttempt = 0
```

**Why bridge tear-down is required per attempt**: Each reconnect creates a new `LockFreeRingBuffer` because the old one may contain stale PCM data from the previous connection. The `AVAudioSourceNode` render block captures the ring buffer reference, so a new bridge must be activated to pick up the new buffer.

**Real usage**: `StreamPlayer.swift` reconnect logic, wired to `PlaybackCoordinator` via `onStreamTerminated` callback

**Pitfalls**:
- Bridge tear-down (`onStreamTerminated`) must fire BEFORE starting the new pipeline — otherwise the old bridge's render block reads stale data
- `cancelReconnect()` must be called on explicit `stop()` and on new `play()` calls to prevent orphaned reconnect tasks
- The stable-playback timer must be cancelled when stopping or reconnecting to prevent false resets
- `wasActivelyPlaying` guard prevents reconnect attempts for streams that never successfully played (avoids infinite retry on initial connection failure)

### Pattern: Generation Token Guards Across await

**When to use**: An async builder on the main actor (load, then construct) can be superseded while it is suspended — the user skips to the next video, switches to audio, or stops — and the stale run must not install anything.

`AudioPlayer.startVideoLoad(track:)` awaits track loading and format loading before building the tap and the `AVPlayer`. Main-actor code is reentrant across `await`, so every suspension point is a place where the world may have changed. Rationale: plan ADR-7 amendment.

**Implementation**:
```swift
// File: MacAmpApp/Audio/AudioPlayer.swift
@ObservationIgnored private var videoLoadGeneration: UInt64 = 0
@ObservationIgnored private var inFlightVideoLoadTask: Task<Void, Never>?

/// Bumped on every new video load, video→audio switch, and stop.
private func invalidateInFlightVideoLoad() {
    inFlightVideoLoadTask?.cancel()
    inFlightVideoLoadTask = nil
    videoLoadGeneration &+= 1
}

private func startVideoLoad(track: Track) {
    invalidateInFlightVideoLoad()
    let gen = videoLoadGeneration
    let url = track.url

    inFlightVideoLoadTask = Task { @MainActor [weak self] in
        guard let self, gen == self.videoLoadGeneration else { return }

        await self.videoPlaybackController.loadVideo(
            url: url,
            autoPlay: false,
            audioMixBuilder: { [weak self] asset in
                guard let self, gen == self.videoLoadGeneration else { return nil }
                do {
                    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                    guard gen == self.videoLoadGeneration else { return nil }
                    guard let audioTrack = audioTracks.first else { return nil }
                    let preferredFormat = await VideoTap.preferredProcessingFormat(for: audioTrack)
                    guard gen == self.videoLoadGeneration else { return nil }
                    // ... build Context + audioMix, register fan-out, return mix ...
                } catch {
                    AppLog.error(.audio, "Video tap audio mix build failed: \(error)")
                    return nil
                }
            },
            isStillRelevant: { [weak self] in
                guard let self else { return false }
                return gen == self.videoLoadGeneration
            }
        )

        guard gen == self.videoLoadGeneration else { return }
        guard case .playing = self.playbackState else { return }
        self.videoPlaybackController.play()
    }
}
```

**Companion: identity guards on callbacks from a replaceable object**. `AVPlayer` time-observer, seek-completion and end-of-item callbacks can arrive after a newer `loadVideo` replaced the player. Capture the source weakly and compare identity before mutating state:
```swift
// File: MacAmpApp/Audio/VideoPlaybackController.swift (seek)
player.seek(to: targetTime) { [weak self, weak player] finished in
    Task { @MainActor in
        guard let self, let player, finished else { return }
        guard self.player === player else { return }   // superseded — ignore
        // ... update transport state ...
    }
}
```

**Key elements**:
1. **Capture the token before the first `await`** (`let gen = videoLoadGeneration`) and re-check it after **every** `await`, not just at the end
2. **Bump on every supersession path** — new load, media-type switch, stop — via one helper
3. **Separate "stale" from "nothing to build"**: the builder returns `nil` for "no audio track, build a player without a tap"; `isStillRelevant` returning `false` aborts the whole load before any player, item or observer is created
4. **Re-check intent before side effects**: auto-play only if `playbackState` is still `.playing`
5. **`Task.cancel()` is advisory**: `AVURLAsset.loadTracks` ignores cancellation, so the token is the load-bearing signal

**Real usage**: `AudioPlayer.startVideoLoad(track:)` / `invalidateInFlightVideoLoad()`, `VideoPlaybackController.loadVideo` (`isStillRelevant`), identity guards in `VideoPlaybackController` seek completion, time observer and end-of-item observer. Same idea as the `currentSeekID` UUID used to filter stale `playerNode` completions. Tests: `VideoTapLifecycleTests` ("loadVideo bails when isStillRelevant returns false…", "Stale loadVideo drops the built audioMix without leaking the Context"), `VideoSeekStateMatrixTests`.

**Pitfalls**:
- A check only after the last `await` still lets a stale run do work (and retain resources) in between
- `resume: nil` on seek means "keep the user's current intent" — evaluate it inside the completion, not when the seek is issued, or a pause during the seek is lost (`VideoSeekStateMatrixTests` covers the matrix)
- An abandoned build may already have created a Context; it is released through the tap's normal finalize chain when the unused `audioMix` is dropped, not by the stale path

### Pattern: Debounced Will/Did Notification Bursts

**When to use**: A system notification arrives in bursts (2–3 within ~100 ms) and consumers need one "about to change" signal at the start and one "settled" signal at the end.

Used for output-route changes (Control Center, AirPlay, HDMI, sleep/wake), which fire several `AVAudioEngineConfigurationChange` notifications. The reconfigure flow it drives: [Output Route Changes](MACAMP_ARCHITECTURE_GUIDE.md#output-route-changes-engine-reconfiguration).

**Implementation**:
```swift
// File: MacAmpApp/Audio/AudioEngineConfigurationObserver.swift
@MainActor
final class AudioEngineConfigurationObserver {
    private var watchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private static let debounceWindow: Duration = .milliseconds(150)

    var onWillReconfigure: (@MainActor () -> Void)?
    var onDidReconfigure: (@MainActor () -> Void)?

    func start() {
        guard watchTask == nil else { return }
        let stream = NotificationCenter.default.notifications(
            named: .AVAudioEngineConfigurationChange,
            object: engine
        )
        watchTask = Task { @MainActor [weak self] in
            for await _ in stream {
                self?.handleConfigurationChange()
            }
        }
    }

    private func handleConfigurationChange() {
        if debounceTask == nil {
            onWillReconfigure?()                       // first notification of a burst
        }
        guard watchTask != nil else { return }         // `will` handler may have called stop()
        debounceTask?.cancel()                         // each arrival restarts the quiet window
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.debounceWindow)
            guard let self, !Task.isCancelled else { return }
            self.debounceTask = nil
            self.onDidReconfigure?()
        }
    }
}
```

**Consumer side — user intent cancels a pending `did`**:
```swift
// File: MacAmpApp/Audio/AudioPlayer.swift
// Called from play/stop/seek/playTrack (pause rewrites the snapshot to paused instead)
private func cancelPendingReconfigure() {
    pendingReconfigureSnapshot = nil
    seekGuardActive = false
    isHandlingCompletion = false
}
```

**Key elements**:
1. `NotificationCenter.notifications(named:object:)` consumed in a `@MainActor` task — no manual `Task { @MainActor in }` hop per notification
2. `will` fires immediately so guards are armed before the engine restart fires a stale completion; `did` fires once after 150 ms of quiet
3. `did` is **not** guaranteed after `will` if `stop()`/`deinit` interrupts the window — consumers clear what `will` armed in their own teardown and user-intent paths
4. The `did` handler early-returns when the snapshot is `nil`, so user intent during the window wins over the automatic resume

**Real usage**: `AudioEngineConfigurationObserver.swift`, owned by `AudioEngineController` (forwards `onEngineWillReconfigure(PreReconfigureSnapshot)` / `onEngineDidReconfigure`), consumed by `AudioPlayer.handleEngineWillReconfigure` / `handleEngineDidReconfigure`, and `PlaybackCoordinator` (`onEngineReconfigured` refreshes the stream-decode audio workgroup). Tests: `Tests/MacAmpTests/EngineConfigObserverTests.swift` post synthetic notifications against a real `AVAudioEngine`.

**Pitfalls**:
- The snapshot the engine captures at notification time is unreliable (the system has already stopped the engine); `AudioPlayer` overrides `wasPlaying`/`currentTime` with its own transition-managed state
- Anything armed in `will` needs a release path that doesn't depend on `did` running
- Keep `start()`/`stop()` idempotent; tests cycle them

---

## Error Handling Patterns

### Pattern: Typed Stream Termination Reasons

**When to use**: Classifying stream failure modes to determine reconnect eligibility, replacing string-based error matching with exhaustive enum pattern matching.

**Why**: matching on `error.localizedDescription` strings is fragile; a typed enum makes every failure mode a compile-time case and the reconnect policy explicit. Case table with user messages: [Auto-Reconnect State Machine](MACAMP_ARCHITECTURE_GUIDE.md#auto-reconnect-state-machine).

**Implementation**:
```swift
// File: MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift
// Purpose: Typed enum for all stream termination modes
// Context: Produced by StreamDecodePipeline, consumed by StreamPlayer for reconnect decisions
// Nested type: StreamDecodePipeline.StreamTerminationReason

enum StreamTerminationReason: Sendable {
    case networkError(String, Int)          // URLSession error (message + NSURLError code)
    case serverClosed                       // Server closed connection
    case httpClientError(Int)               // 4xx status
    case httpServerError(Int)               // 5xx status
    case decodeError(String)                // Format/codec error
    case invalidResponse                    // Not HTTP
    case playlistResolutionFailed(String)   // M3U/PLS failure
    case userStopped                        // Explicit stop()
}

// File: MacAmpApp/Audio/StreamPlayer.swift
// Purpose: Classify which terminations warrant reconnect vs. terminal failure

private func isReconnectable(_ reason: StreamDecodePipeline.StreamTerminationReason) -> Bool {
    switch reason {
    case .networkError(_, let code):
        // DNS resolution failure, bad URL — terminal (will never succeed on retry)
        let terminalCodes = [
            NSURLErrorCannotFindHost,     // -1003
            NSURLErrorUnsupportedURL,     // -1002
            NSURLErrorBadURL,             // -1000
        ]
        return !terminalCodes.contains(code)
    case .serverClosed, .httpServerError, .playlistResolutionFailed:
        return true   // Transient — reconnect
    case .httpClientError, .decodeError, .invalidResponse, .userStopped:
        return false  // Permanent or user-initiated — terminal
    }
}
```

**Design rationale**:
- **Sendable**: The enum crosses from the decode queue (via `@MainActor @Sendable` closure) to MainActor, so it must be `Sendable`
- **Associated values**: `networkError` carries the NSURLError code for fine-grained reconnect logic; `httpServerError`/`httpClientError` carry the HTTP status code for logging
- **Exhaustive switch**: Adding a new case forces handling at all call sites — no silent fallthrough

**Real usage**: `StreamDecodePipeline.swift` produces the reason via `onTermination`, `StreamPlayer.swift` consumes it in `handleTermination()` / `isReconnectable()`

**Pitfalls**:
- `networkError` codes overlap between truly transient (timeout, connection reset) and permanent (bad host) — the `terminalCodes` list must be curated carefully
- `playlistResolutionFailed` is reconnectable because M3U/PLS download failure may be a transient DNS issue, even though the error looks permanent
- `userStopped` must never trigger reconnect — always check this case first in any reconnect logic

---

## Testing Patterns

### Test Plan Quick Reference

**Test target**: `MacAmpTests` (`Tests/MacAmpTests`)
**Project spec**: `project.yml` (XcodeGen — run `xcodegen generate` to create xcodeproj)

**Configuration**: Single "All" configuration running the full `MacAmpTests` target.

**CLI**:
```bash
xcodegen generate  # if xcodeproj is stale or missing
xcodebuild test -scheme MacAmpApp -destination 'platform=macOS'
```

**Thread Sanitizer run** (required before committing): add `-enableThreadSanitizer YES`. Wall-clock benchmarks skip themselves under TSan (see [Wall-Clock Benchmarks Disabled Under TSan](#pattern-wall-clock-benchmarks-disabled-under-tsan)), so run the suite once without TSan as well.

**Video fixtures**: `VideoTapLifecycleTests` and `VideoSeekStateMatrixTests` load clips from `clapperboard-videos/` at the project root (resolved via `SRCROOT`, falling back to `#filePath`).

### Pattern: Polling for Asynchronous Release

**When to use**: Asserting that an object is deallocated when the release happens on another queue at an unspecified time — e.g. `tapFinalize` releasing a `VideoTapContext` after the last `AVPlayer`/`AVPlayerItem` reference drops.

**Implementation**:
```swift
// File: Tests/MacAmpTests/VideoTapLifecycleTests.swift

@Test("Single attach lifecycle: Context released after AVPlayer drop")
func singleAttachLifecycle() async throws {
    let url = try Self.clipURL("1_mp4_441_stereo.mp4")
    let asset = AVURLAsset(url: url)
    let tracks = try await asset.loadTracks(withMediaType: .audio)
    let audioTrack = try #require(tracks.first)

    weak var weakContext: VideoTapContext?

    try {
        let context = VideoTapContext(feed: VisualizerFeed())
        weakContext = context
        let mix = try VideoTap.buildAudioMix(audioTrack: audioTrack, context: context)
        let item = AVPlayerItem(asset: asset)
        item.audioMix = mix
        let player = AVPlayer(playerItem: item)
        _ = player  // strong refs alive only inside this scope
    }()

    try await Self.waitUntilNil(weakContext)
    #expect(weakContext == nil, "VideoTapContext should be released after the surrounding AVPlayer is dropped")
}

/// Poll a weak reference until it goes nil or the deadline expires.
/// `tapFinalize` may fire on a background queue, so a fixed sleep
/// would be flaky.
private static func waitUntilNil<T: AnyObject>(
    _ ref: @autoclosure () -> T?,
    timeoutMs: UInt64 = 5_000,
    pollMs: UInt64 = 50
) async throws {
    let pollNs = pollMs * 1_000_000
    let maxIterations = timeoutMs / pollMs
    for _ in 0..<maxIterations {
        if ref() == nil { return }
        try await Task.sleep(nanoseconds: pollNs)
    }
}
```

**Key elements**:
1. Create the strong references inside an immediately-invoked closure so they provably go out of scope before the wait
2. Poll with a generous deadline (returns as soon as the condition holds) instead of a fixed sleep
3. `waitUntilNil` returns silently on timeout — the `#expect` after it is the assertion. `VideoSeekStateMatrixTests.waitUntil(_:)` is the variant that throws on timeout for arbitrary conditions
4. Reset DEBUG test seams (e.g. `VideoTap._testForceTapCreateFailure`) with `defer` **before** the first `await`, so no other test observes them

**Real usage**: `VideoTapLifecycleTests.swift` (single/rapid-double attach, detach, create failure, `replaceCurrentItem(nil)`, stale load), `VideoSeekStateMatrixTests.swift`

**Pitfalls**:
- A fixed `Task.sleep` passes locally and flakes under load or TSan
- Holding the object in a test-scope `let` keeps it alive and makes the test meaningless
- Proving release is not proving the absence of a render-time use-after-free; that still needs a TSan/ASan run with playback

### Pattern: Wall-Clock Benchmarks Disabled Under TSan

**When to use**: A test asserts a timing budget (real-time deadline, p99 latency) and the suite is also run with Thread Sanitizer, whose instrumentation makes wall-clock numbers meaningless.

**Implementation**:
```swift
// File: Tests/MacAmpTests/VideoTapCPUBenchmarkTests.swift

static let threadSanitizerActive = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "__tsan_init") != nil  // -2 = RTLD_DEFAULT

@Test(
    "per-callback DSP fits the deadline even in Debug (99p ≤ 50%, max ≤ 75%)",
    .disabled(if: threadSanitizerActive, "wall-clock timing is meaningless under TSan instrumentation; runs in non-TSan test runs")
)
func dspWithinBudget() {
    let tb = Self.timebase()
    let budgetNanos = Double(Self.frames) / Self.sampleRate * 1_000_000_000
    // ...
    for _ in 0..<Self.iterations {
        memcpy(left, srcL, byteCount); memcpy(right, srcR, byteCount)  // refresh input (untimed)
        let start = mach_absolute_time()
        // ... full per-callback DSP chain ...
        samples.append(Self.nanos(mach_absolute_time() &- start, tb))
    }
    // ...
    #expect(p99 <= budgetNanos * 0.50, "99p exceeded 50% of budget even allowing for Debug — \(summary)")
    #expect(maxNs <= budgetNanos, "a single sample exceeded the full buffer deadline (hung?) — \(summary)")
}
```

**Key elements**:
1. Detect TSan at runtime by looking up the `__tsan_init` symbol, and use `.disabled(if:)` so the test reports as skipped (not passed) in TSan runs
2. Time every iteration and assert a percentile against the real buffer budget; keep the `max` bound loose (single samples include scheduler stalls)
3. Restore the input buffers **outside** the timed region so processed output never feeds the next iteration
4. Thresholds are set for the Debug (`-Onone`) test build; the tighter Release target is verified separately with Instruments

**Real usage**: `VideoTapCPUBenchmarkTests.swift`. Runs in a plain `xcodebuild test -scheme MacAmpApp -destination 'platform=macOS'`; skipped in the TSan run.

**Pitfalls**:
- Don't gate on `#if DEBUG` or a build setting — TSan is enabled per invocation (`-enableThreadSanitizer YES`), not per configuration
- Printing the summary in the test output makes regressions diagnosable without re-running

### Pattern: Numerical Match Against the Apple Reference Unit

**When to use**: Re-implementing an Apple DSP unit (here the 10-band `AVAudioUnitEQ`) and needing proof the re-implementation sounds the same.

**Implementation**:
```swift
// File: Tests/MacAmpTests/BiquadNumericalMatchTests.swift

@Test("Full-EQ magnitude match: BiquadCascade vs AVAudioUnitEQ ≤0.5 dB over 20Hz–20kHz")
func fullEqMagnitudeMatch() throws {
    var worst = 0.0
    var worstInfo = ""
    for (name, gains) in Self.presets {
        for f in Self.probeFrequencies {
            let eqDB = try Self.eqMagnitudeDB(frequency: f, gains: gains)
            let cascadeDB = Self.cascadeMagnitudeDB(frequency: f, gains: gains)
            let err = abs(eqDB - cascadeDB)
            if err > worst {
                worst = err
                worstInfo = "preset=\(name) f=\(Int(f))Hz eq=\(String(format: "%.3f", eqDB))dB cascade=\(String(format: "%.3f", cascadeDB))dB"
            }
        }
    }
    #expect(worst <= 0.5, "Worst-case magnitude error \(String(format: "%.3f", worst)) dB > 0.5 dB at \(worstInfo)")
}

// Reference side: render a sine through a real AVAudioUnitEQ offline
let source = AVAudioSourceNode(format: format) { _, _, frameCount, ablPtr in /* sine */ }
engine.attach(source)
engine.connect(source, to: eq, format: format)
engine.connect(eq, to: engine.mainMixerNode, format: format)
try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4_096)
try engine.start()
// ... renderOffline until `total` frames, then steady-state RMS gain in dB ...

/// Configure an `AVAudioUnitEQ` identically to `EqualizerController.configureEQ`.
static func configure(_ eq: AVAudioUnitEQ, gains: [Float]) {
    let freqs = BiquadCoefficientSet.frequencies
    // ...
}
```

**Key elements**:
1. Compare **magnitude** as steady-state RMS gain of a pure sine (skip the first 8,192 samples); this equals |H(f)| regardless of filter phase or latency, so no alignment is needed
2. Sweep log-spaced probes (40 from 20 Hz to 20 kHz) × several EQ shapes and report the worst case with its location
3. Configure the reference from the same shared constants as production (`BiquadCoefficientSet.frequencies`) so the test can't drift from `EqualizerController`
4. `AVAudioEngine` manual rendering (`.offline`) makes the reference deterministic and hardware-independent
5. Separate tests cover bypass (exact pass-through), preamp dB→linear, the balance law, fail-closed coefficients (invalid rate, band above Nyquist), interleaved-vs-planar stride, and `reset()`

**Real usage**: `BiquadNumericalMatchTests.swift` (acceptance criterion from plan ADR-8)

**Pitfalls**:
- Comparing sample-by-sample output fails on phase differences even when the response matches
- Measuring during the filter's transient overstates the error — skip it

---

## Migration Guides

Bool-to-enum settings migration is covered by [Enum State with Persistence](#pattern-enum-state-with-persistence-repeatmode-pattern); `Task.detached` → `@concurrent` by [Background I/O with @concurrent](#pattern-background-io-with-concurrent-static-functions-swift-62).

### Migrating from ObservableObject to @Observable

**Step 1**: Remove ObservableObject conformance
```swift
// Before
class MyModel: ObservableObject {
    @Published var value = 0
}

// After
@Observable
final class MyModel {
    var value = 0
}
```

**Step 2**: Update view bindings
```swift
// Before
struct MyView: View {
    @StateObject private var model = MyModel()
    // or
    @ObservedObject var model: MyModel
    // or
    @EnvironmentObject var model: MyModel
}

// After
struct MyView: View {
    @State private var model = MyModel()
    // or
    @Environment(MyModel.self) var model
}
```

**Step 3**: Remove Combine imports
```swift
// Before
import Combine

class MyModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
}

// After
// No Combine needed
@Observable
final class MyModel {
    // No cancellables needed
}
```

---

## Anti-Patterns to Avoid

### Anti-Pattern: Computed @State

**Wrong**:
```swift
struct BadView: View {
    // ❌ Recomputed on every view update!
    var viewModel: ViewModel {
        ViewModel(data: loadData())
    }
}
```

**Correct**:
```swift
struct GoodView: View {
    // ✅ Created once, persists across updates
    @State private var viewModel = ViewModel(data: loadData())
}
```

### Anti-Pattern: Force Unwrapping

**Wrong**:
```swift
// ❌ Will crash if nil
let track = playlist.tracks[index]!
let image = NSImage(named: spriteName)!
```

**Correct**:
```swift
// ✅ Safe handling
guard playlist.indices.contains(index) else { return }
let track = playlist[index]
let image = NSImage(named: spriteName) ?? fallbackImage
```

### Anti-Pattern: Synchronous I/O on Main Thread

**Wrong**:
```swift
struct BadView: View {
    var body: some View {
        // ❌ Blocks UI
        let data = try! Data(contentsOf: largeFileURL)
        Image(nsImage: NSImage(data: data)!)
    }
}
```

**Correct**:
```swift
struct GoodView: View {
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
            } else {
                ProgressView()
            }
        }
        .task {
            image = await loadImage(from: largeFileURL)
        }
    }
}
```

### Anti-Pattern: Cross-File SwiftUI Extensions as View Decomposition

**Context**: Splitting a large view into `View+Something.swift` extension files looks like decomposition but isn't. Both the main and playlist windows went through this and were then rebuilt as child views.

**Why this is an anti-pattern** (not just tactical debt):
1. **Forces access widening**: Properties that should be `private` must become `internal` so the extension file can reach them
2. **No SwiftUI recomposition boundaries**: Extensions share the parent view's `body` evaluation scope, so changes to any state invalidate the entire view
3. **No real isolation**: Extensions have full access to all properties — they move code but do not reduce coupling

```swift
// ❌ ANTI-PATTERN: Extensions in separate files widen access and share body scope
extension WinampPlaylistWindow {
    // All properties must be internal (not private) for this to compile
    // No SwiftUI recomposition boundary — entire parent body re-evaluates
    func helperMethod() { ... }
}
```

**The correct approach** (implemented for both windows):
```swift
// ✅ CORRECT: @Observable interaction state + child View structs with explicit deps

// 1. Extract interaction state into a dedicated @Observable class
// File: MacAmpApp/Views/PlaylistWindow/PlaylistWindowInteractionState.swift
@MainActor @Observable
final class PlaylistWindowInteractionState {
    var selectedIndices: Set<Int> = []
    var isShadeMode: Bool = false
    var scrollOffset: Int = 0
    // ...
}

// 2. Child views declare only the inputs they need
// File: MacAmpApp/Views/PlaylistWindow/PlaylistTitleBarButtons.swift
struct PlaylistTitleBarButtons: View {
    let windowWidth: CGFloat
    let onMinimize: () -> Void
    let onShadeToggle: () -> Void
    let onClose: () -> Void
    // body re-evaluates only when these inputs change
}
```

**Why the correct pattern is better**:
- `private` stays `private` — no access widening
- Each child view is an independent SwiftUI recomposition boundary
- Explicit dependency lists make data flow visible and testable
- `@Observable` interaction state classes are unit-testable without views

`PlaylistWindowActions.swift` is a separate case and stays: it holds the playlist's NEW/LOAD/SAVE and ADD/REM operations as standalone `@objc` action methods (the sprite-menu targets), not view code.

See Lesson #25 in BUILDING_RETRO_MACOS_APPS_SKILL.md for the complete architecture pattern.
See [View Layer Decomposition (MainWindow)](#pattern-view-layer-decomposition-mainwindow) in the UI Component Patterns section for the MainWindow-specific implementation.

### Anti-Pattern: Direct Backend Volume/Balance Binding

**Context**: Binding sliders straight to `audioPlayer.volume` via `@Bindable` skips the coordinator's same-value guard and its drag-end persistence.

**Wrong**:
```swift
@Bindable var player = audioPlayer
WinampVolumeSlider(volume: $player.volume)      // No idempotent guard, no drag-end commit
WinampBalanceSlider(balance: $player.balance)
```

Also wrong -- writing UserDefaults from the `didSet` of a slider-driven value (a disk write on every drag tick):
```swift
var volume: Float = 0.75 {
    didSet {
        engine?.setVolume(volume)
        UserDefaults.standard.set(volume, forKey: Keys.volume)  // Per-tick persistence!
    }
}
```

**Correct**: Use asymmetric bindings through `PlaybackCoordinator` and commit on drag end. See [Coordinator Volume Routing](#pattern-coordinator-volume-routing) and [Asymmetric Binding for Coordinator Routing](#pattern-asymmetric-binding-for-coordinator-routing) in State Management Patterns.

---

## Quick Reference

| Problem | Pattern |
|---|---|
| New UI state class | [@Observable with @MainActor](#pattern-observable-with-mainactor) |
| Setting that persists | [Enum State with Persistence](#pattern-enum-state-with-persistence-repeatmode-pattern), [UserDefaults Persistence](#pattern-userdefaults-persistence-with-centralized-keys) |
| Slider-driven value | [Coordinator Volume Routing](#pattern-coordinator-volume-routing), [Asymmetric Binding](#pattern-asymmetric-binding-for-coordinator-routing) |
| Dim controls that don't apply | [Capability Flag Pattern](#pattern-capability-flag-pattern) |
| Timer reads live state | [Display Title Provider Closure](#pattern-display-title-provider-closure) |
| Delayed, cancellable action | [Task.sleep with Cancellation](#pattern-tasksleep-with-cancellation) |
| Skinned button / chrome | [Sprite-Based Button](#pattern-sprite-based-button-component), [Segment-Sized Window Chrome](#pattern-segment-sized-window-chrome-videobmp--genbmp) |
| Big view body | [View Layer Decomposition](#pattern-view-layer-decomposition-mainwindow) |
| Data from a render thread | [SPSC Shared Buffer](#pattern-spsc-shared-buffer-for-audio-to-main-thread-transfer) |
| Parameters into a render thread | [Render-Thread-Safe Shared State](#pattern-render-thread-safe-shared-state) |
| One setting, many DSP sinks | [Parallel DSP Fan-Out](#pattern-parallel-dsp-fan-out-via-weakbox-registries) |
| Async build that can be superseded | [Generation Token Guards Across await](#pattern-generation-token-guards-across-await) |
| Bursty system notification | [Debounced Will/Did Notification Bursts](#pattern-debounced-willdid-notification-bursts) |
| File I/O from @MainActor code | [Background I/O with @concurrent](#pattern-background-io-with-concurrent-static-functions-swift-62) |
| Cleanup on deallocation | [isolated deinit](#pattern-isolated-deinit-for-mainactor-cleanup-swift-62) |
| Test async deallocation | [Polling for Asynchronous Release](#pattern-polling-for-asynchronous-release) |

---

## Conclusion

These patterns represent the collective wisdom gained from building MacAmp. They emphasize:
- **Safety**: Prevent crashes through optional handling and error recovery
- **Performance**: Efficient audio processing and UI updates
- **Maintainability**: Clear separation of concerns and testability
- **Modernization**: Embrace Swift 6 features while maintaining stability

When implementing new features, prefer these established patterns. When you discover new patterns, document them here for the team.

---

*Document Version: 2.3.0 | Last Updated: 2026-09-25*

**Recent updates** (full history in git):
- **2.3.0 (2026-09-25):** Pruned: snippets checked against the code, invented examples replaced or removed, architecture explanations moved to MACAMP_ARCHITECTURE_GUIDE.md, superseded patterns and migration guides folded in.
- **2.2.0 (2026-09-25):** Video DSP patterns (MTAudioProcessingTap, render-thread state, pinned format, fan-out, dual-producer feed, telemetry, generation tokens, debounced notifications) and their testing patterns.
