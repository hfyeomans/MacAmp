# MacAmp Implementation Patterns

**Version:** 2.2.0
**Date:** 2026-09-25
**Purpose:** Practical code patterns and best practices for MacAmp development

---

## Table of Contents

1. [Pattern Overview](#pattern-overview)
2. [State Management Patterns](#state-management-patterns)
   - [@Observable with @MainActor](#pattern-observable-with-mainactor)
   - [Dependency Injection via Environment](#pattern-dependency-injection-via-environment)
   - [Computed Properties with Dependency Tracking](#pattern-computed-properties-with-dependency-tracking)
   - [Computed Forwarding for API Compatibility](#pattern-computed-forwarding-for-api-compatibility) **(New - Swift 6)**
   - [Enum State with Persistence](#pattern-enum-state-with-persistence-repeatmode-pattern)
   - [UserDefaults Persistence with Centralized Keys](#pattern-userdefaults-persistence-with-centralized-keys)
   - [Window Focus State Tracking](#pattern-window-focus-state-tracking)
   - [Action-Based Bridge Pattern](#pattern-action-based-bridge-pattern) **(New - Swift 6)**
   - [Coordinator Volume Routing](#pattern-coordinator-volume-routing) **(New - T5 Phase 1)**
   - [Asymmetric Binding for Coordinator Routing](#pattern-asymmetric-binding-for-coordinator-routing) **(New - T5 Phase 1)**
   - [Capability Flag Pattern](#pattern-capability-flag-pattern) **(New - T5 Phase 1)**
   - [Display Title Provider Closure](#pattern-display-title-provider-closure) **(New - T3 Decomposition)**
   - [Task.sleep with Cancellation](#pattern-tasksleep-with-cancellation) **(New - T3 Decomposition)**
   - [NSMenu Presenter Isolation](#pattern-nsmenu-presenter-isolation) **(New - T3 Decomposition)**
3. [UI Component Patterns](#ui-component-patterns)
   - [Sprite-Based Button Component](#pattern-sprite-based-button-component)
   - [Absolute Positioning Extension](#pattern-absolute-positioning-extension)
   - [Multi-State Slider](#pattern-multi-state-slider)
   - [VIDEO.bmp Chrome Composition](#pattern-videobmp-chrome-composition)
   - [GEN.bmp Chrome & Two-Piece Sprites](#pattern-genbmp-chrome--two-piece-sprites)
   - [Video Playback Embedding](#pattern-video-playback-embedding) **(Updated - S3-2)**
   - [View Layer Decomposition (MainWindow)](#pattern-view-layer-decomposition-mainwindow) **(New - T3 Decomposition)**
4. [Audio Processing Patterns](#audio-processing-patterns)
   - [Safe Audio Buffer Processing](#pattern-safe-audio-buffer-processing)
   - [Thread-Safe Audio State](#pattern-thread-safe-audio-state)
   - [nonisolated(unsafe) Deinit Safety](#pattern-nonisolatedunsafe-deinit-safety-swift-6) **(New - Swift 6)**
   - [SPSC Shared Buffer for Audio-to-Main Thread Transfer](#pattern-spsc-shared-buffer-for-audio-to-main-thread-transfer) **(Updated - S3-2)**
   - [Stream Decode Pipeline (Unified Audio)](#pattern-stream-decode-pipeline-unified-audio) **(New - Unified Pipeline)**
   - [AudioConverter Input Buffer Lifecycle](#pattern-audioconverter-input-buffer-lifecycle) **(New - Unified Pipeline)**
   - [Engine Graph Explicit Format](#pattern-engine-graph-explicit-format) **(New - Unified Pipeline)**
   - [Engine File Duration as Authoritative Source](#pattern-engine-file-duration-as-authoritative-source-vbr-lesson-s1) **(New - S1)**
   - [MTAudioProcessingTap with Unmanaged Context](#pattern-mtaudioprocessingtap-with-unmanaged-context) **(New - S3-2)**
   - [Render-Thread-Safe Shared State](#pattern-render-thread-safe-shared-state) **(New - S3-2)**
   - [Pinned Tap Format and Build-Time audioMix](#pattern-pinned-tap-format-and-build-time-audiomix) **(New - S3-2)**
   - [Parallel DSP Fan-Out via WeakBox Registries](#pattern-parallel-dsp-fan-out-via-weakbox-registries) **(New - S3-2)**
   - [Dual-Producer Visualizer Feed](#pattern-dual-producer-visualizer-feed) **(New - S3-2)**
   - [Sampled Deadline Telemetry](#pattern-sampled-deadline-telemetry) **(New - S3-2)**
5. [Async/Await Patterns](#asyncawait-patterns)
   - [Async Stream Events](#pattern-async-stream-events)
   - [Cancellable Tasks](#pattern-cancellable-tasks)
   - [Background I/O with @concurrent Static Functions](#pattern-background-io-with-concurrent-static-functions-swift-62) **(Updated - Swift 6.2)**
   - [Callback Synchronization for Cross-Component Communication](#pattern-callback-synchronization-for-cross-component-communication) **(New - Swift 6, Updated - S1)**
   - [Stream Bridge Lifecycle Callbacks](#pattern-stream-bridge-lifecycle-callbacks) **(New - Unified Pipeline)**
   - [Exponential Backoff Reconnect with Bridge Tear-Down](#pattern-exponential-backoff-reconnect-with-bridge-tear-down-s1) **(New - S1)**
   - [Generation Token Guards Across await](#pattern-generation-token-guards-across-await) **(New - S3-2)**
   - [Debounced Will/Did Notification Bursts](#pattern-debounced-willdid-notification-bursts) **(New - S3-2)**
6. [Error Handling Patterns](#error-handling-patterns)
   - [Typed Stream Termination Reasons](#pattern-typed-stream-termination-reasons-s1) **(New - S1)**
7. [Testing Patterns](#testing-patterns)
   - [Polling for Asynchronous Release](#pattern-polling-for-asynchronous-release) **(New - S3-2)**
   - [Wall-Clock Benchmarks Disabled Under TSan](#pattern-wall-clock-benchmarks-disabled-under-tsan) **(New - S3-2)**
   - [Numerical Match Against the Apple Reference Unit](#pattern-numerical-match-against-the-apple-reference-unit) **(New - S3-2)**
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

**When to use**: For UI-bound state that needs thread safety

**Implementation**:
```swift
@MainActor
@Observable
final class PlayerState {
    // Observable properties (automatic change detection)
    private(set) var isPlaying: Bool = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    // Non-observable (use @ObservationIgnored)
    @ObservationIgnored
    private var updateTimer: Timer?

    // All methods run on main thread automatically
    func play() {
        isPlaying = true
        startTimer()
    }

    func pause() {
        isPlaying = false
        stopTimer()
    }

    private func startTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.currentTime += 0.1
        }
    }
}
```

**Real usage**: `AudioPlayer.swift`, `StreamPlayer.swift`, `PlaybackCoordinator.swift`

**Note**: PlaybackCoordinator uses this pattern but its `isPlaying`/`isPaused` are computed properties deriving from the active backend (see "Computed Properties with Dependency Tracking" pattern below), not stored booleans. AudioPlayer and StreamPlayer use stored vars as shown above.

**Pitfalls**:
- Don't forget `@MainActor` for UI state
- Use `private(set)` for read-only properties
- Remember `@ObservationIgnored` for non-UI properties

### Pattern: Dependency Injection via Environment

**When to use**: Sharing state across multiple views

**Implementation**:
```swift
// 1. Create the observable model
@Observable
final class AppState {
    var theme: Theme = .default
    var volume: Float = 0.5
}

// 2. Inject at app root
@main
struct MyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)  // Inject here
        }
    }
}

// 3. Consume in any child view
struct PlayerView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        Slider(value: Binding(
            get: { appState.volume },
            set: { appState.volume = $0 }
        ))
    }
}
```

**Real usage**: `MacAmpApp.swift` injects all major services

**Pitfalls**:
- Must use `@State` at injection point, not computed property
- Don't inject too many separate objects (group related state)

### Pattern: Computed Properties with Dependency Tracking

**When to use**: Derived state that updates automatically

**Implementation**:
```swift
@Observable
final class PlaylistManager {
    var tracks: [Track] = []
    var currentIndex: Int = 0

    // Computed properties automatically track dependencies
    var currentTrack: Track? {
        guard currentIndex >= 0 && currentIndex < tracks.count else {
            return nil
        }
        return tracks[currentIndex]
    }

    var hasNext: Bool {
        currentIndex < tracks.count - 1
    }

    var hasPrevious: Bool {
        currentIndex > 0
    }

    // These will trigger view updates when dependencies change
    var displayTitle: String {
        currentTrack?.title ?? "No Track"
    }
}
```

**Real usage**: `PlaybackCoordinator.swift` for `displayTitle`, `isPlaying`, `isPaused` (computed from active audio source since PR #49)

### Pattern: Computed Forwarding for API Compatibility

**When to use**: Maintaining backwards-compatible API surface after extracting functionality to sub-components

**Swift 6 Relevance**: Essential for incremental refactoring while preserving existing view bindings

**Implementation**:
```swift
// File: MacAmpApp/Audio/AudioPlayer.swift
// Purpose: Forward state from extracted components while preserving existing bindings
// Context: Views bind to AudioPlayer.playlist instead of playlistController.playlist

@Observable
@MainActor
final class AudioPlayer {
    // Extracted controllers (internal implementation)
    let playlistController = PlaylistController()
    let eqPresetStore = EQPresetStore()
    let videoPlaybackController = VideoPlaybackController()
    let visualizerPipeline = VisualizerPipeline()

    // MARK: - Computed Forwarding (API Compatibility)

    // Read-only forwarding
    var playlist: [Track] { playlistController.playlist }
    var userPresets: [EQPreset] { eqPresetStore.userPresets }
    var videoPlayer: AVPlayer? { videoPlaybackController.player }
    var videoMetadataString: String { videoPlaybackController.metadataString }
    var visualizerLevels: [Float] { visualizerPipeline.levels }

    // Read-write forwarding
    var shuffleEnabled: Bool {
        get { playlistController.shuffleEnabled }
        set { playlistController.shuffleEnabled = newValue }
    }

    // Settings-backed forwarding (delegates to AppSettings)
    var repeatMode: AppSettings.RepeatMode {
        get { AppSettings.instance().repeatMode }
        set { AppSettings.instance().repeatMode = newValue }
    }

    // Method forwarding with state sync
    var visualizerSmoothing: Float {
        get { visualizerPipeline.smoothing }
        set { visualizerPipeline.smoothing = newValue }
    }
}
```

**When to use this pattern**:
- **Incremental refactoring**: Extract functionality without breaking existing view bindings
- **Facade maintenance**: Keep public API stable while internal structure evolves
- **Single source of truth**: Prevent duplicate state across components

**When NOT to use**:
- New code should access components directly where appropriate
- Views should use the facade (AudioPlayer), not reach into sub-components
- Don't forward every property - only those needed by external callers

**Real usage**: `AudioPlayer.swift` maintains API compatibility after extracting 6 components: `PlaylistController`, `EQPresetStore`, `VideoPlaybackController`, `VisualizerPipeline`, `EqualizerController` (EQ bands, preamp, presets, auto-EQ — extracted in Wave 1), and `AudioEngineController` (AVAudioEngine graph, node operations, stream bridge, progress timer — extracted in S1)

**Pitfalls**:
- Don't duplicate state - always delegate to the source component
- Remember to update forwarding when component API changes
- Avoid deep forwarding chains (A forwards to B forwards to C)
- Keep forwarding properties grouped together for discoverability

### Pattern: Enum State with Persistence (RepeatMode Pattern)

**When to use**: Multi-state UI controls that need to persist across app launches

**Implementation**:
```swift
// File: MacAmpApp/Models/AppSettings.swift:232-266
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

**When to use**: Tracking which window is focused for active/inactive rendering

**Implementation**:
```swift
// File: MacAmpApp/Models/WindowFocusState.swift
// Purpose: Centralized window focus tracking for titlebar states
// Pattern: @Observable singleton with delegate bridge

@Observable
@MainActor
final class WindowFocusState {
    // Track each window's focus state
    var isMainKey: Bool = true
    var isEqualizerKey: Bool = false
    var isPlaylistKey: Bool = false
    var isVideoKey: Bool = false
    var isMilkdropKey: Bool = false

    var hasAnyFocus: Bool {
        isMainKey || isEqualizerKey || isPlaylistKey ||
        isVideoKey || isMilkdropKey
    }
}

// Bridge from AppKit to Observable state
@MainActor
final class WindowFocusDelegate: NSObject, NSWindowDelegate {
    private let kind: WindowKind
    private let focusState: WindowFocusState

    init(kind: WindowKind, focusState: WindowFocusState) {
        self.kind = kind
        self.focusState = focusState
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // Mutual exclusivity - only one window is key
        focusState.isMainKey = (kind == .main)
        focusState.isEqualizerKey = (kind == .equalizer)
        // ... etc
    }
}

// Usage in views - computed property pattern
struct VideoWindowChromeView: View {
    @Environment(WindowFocusState.self) private var windowFocusState

    // ALWAYS use computed property for reactive updates
    private var isWindowActive: Bool {
        windowFocusState.isVideoKey
    }

    var body: some View {
        SimpleSpriteImage(
            sprite: skinManager.sprite(
                for: .videoTitleBar,
                state: isWindowActive ? .active : .inactive
            )
        )
    }
}
```

**Real usage**: `VideoWindowChromeView.swift`, `MilkdropWindowChromeView.swift`

**Integration steps**:
1. Create WindowFocusState instance at app level
2. Create WindowFocusDelegate for each window
3. Add delegates to WindowDelegateMultiplexer
4. Pass WindowFocusState via environment
5. Read state in views for sprite selection

**Pitfalls**:
- Must ensure single WindowFocusState instance app-wide
- Remember to add delegate to multiplexer, not replace window.delegate
- Use computed properties in views, not @State caching
- Don't cache isWindowActive in @State - breaks reactivity

### Pattern: Action-Based Bridge Pattern

**When to use**: Separating navigation logic from playback side effects for testability and clarity

**Swift 6 Relevance**: Enables pure unit testing of logic without mocking playback infrastructure

**Implementation**:
```swift
// File: MacAmpApp/Audio/PlaylistController.swift:20-29
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

**T5 Phase 1**: Replaces direct `@Bindable var player = audioPlayer; $player.volume` bindings that bypassed the coordinator.

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

**Replaced pattern** (deprecated T5 Phase 1):
```swift
// DEPRECATED: Direct binding bypasses coordinator fan-out
@Bindable var player = audioPlayer
WinampVolumeSlider(volume: $player.volume)  // Only updates AudioPlayer!
```

**Real usage**: `MainWindowSlidersLayer.swift` buildVolumeSlider(), buildBalanceSlider()

**Pitfalls**:
- The `get` closure accesses `audioPlayer.volume` directly -- this is fine because `@Observable` tracks the access for SwiftUI view updates
- Do not use `@Bindable` for properties that need coordinator routing
- The binding captures `audioPlayer` and `playbackCoordinator` from the view's environment -- ensure both are injected
- Balance slider also applies capability-flag-based dimming (see "Capability Flag Pattern" below)

### Pattern: Capability Flag Pattern

**When to use**: Exposing a computed boolean flag from the coordinator to indicate whether audio-processing features (EQ, balance, visualizer) are available for the current playback mode, and using it to dim/disable UI controls

**History**: T5 Phase 1 introduced three separate flags (`supportsEQ`, `supportsBalance`, `supportsVisualizer`). With the unified stream decode pipeline, all three followed identical logic, so they were consolidated into a single `supportsAudioProcessing` flag.

**Implementation**:
```swift
// File: MacAmpApp/Audio/PlaybackCoordinator.swift:110-120
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
// File: MacAmpApp/Views/WinampEqualizerWindow.swift:104-105
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

**Real usage**: `PlaybackCoordinator.swift:120` capability flag, `MainWindowSlidersLayer.swift` balance dimming, `WinampEqualizerWindow.swift` EQ dimming

**Pitfalls**:
- Controls dim briefly during stream prebuffering (before bridge activates) and re-enable once `onFormatReady` fires and the bridge is active
- Use `opacity(0.5)` (not `0.0`) to indicate "unavailable" rather than "hidden" -- users should see the control exists but cannot be used
- Always pair `.opacity()` with `.allowsHitTesting(false)` to prevent interaction with dimmed controls
- Optional `.help()` tooltip explains why the control is disabled

### Pattern: Display Title Provider Closure

**When to use**: When a Timer or periodic callback needs to read the current value of an external property, but the callback's closure would capture a stale value at creation time

**T3 Decomposition**: Introduced in PR #54 to solve a bug where the scrolling title timer captured `displayTitle` at timer creation time and never picked up track changes.

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
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // CORRECT: Calls closure which reads live value from PlaybackCoordinator
                let trackText = self.displayTitleProvider()
                // ... scroll logic using trackText ...
            }
        }
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
- Timer callbacks created with `Timer.scheduledTimer` capture variables at closure creation, not at invocation
- The closure indirection ensures the timer always reads the **current** value from the coordinator

**Real usage**: `WinampMainWindowInteractionState.swift` `displayTitleProvider`, wired in `WinampMainWindow.swift` `.onAppear`

**Pitfalls**:
- The closure must capture the coordinator weakly or as unowned to avoid retain cycles
- The closure is set in `.onAppear` and must be updated if the coordinator changes (unlikely with environment injection)
- Prefer this pattern over storing a reference to the coordinator in the interaction state (keeps the state class view-agnostic)

### Pattern: Task.sleep with Cancellation

**When to use**: Replacing `DispatchQueue.main.asyncAfter` with structured concurrency for delayed state changes that may need cancellation

**T3 Decomposition**: Introduced in PR #54 for scroll restart delays and scrub reset delays in the MainWindow interaction state. The key improvement is that cancelling a `Task` prevents the delayed action from firing, whereas cancelling a `DispatchQueue.main.asyncAfter` requires tracking `DispatchWorkItem` references.

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

**T3 Decomposition**: Introduced in PR #54 to extract the Options (O button) menu from the monolithic `WinampMainWindow+Helpers.swift` extension. The menu is **not** interaction state -- it is a presentation concern that bridges AppKit to SwiftUI.

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

        // Uses shared MenuItemFactory (see MacAmpApp/Utilities/MenuActionTarget.swift)
        menu.addItem(MenuItemFactory.createMenuItem(
            title: "Always on Top",
            isChecked: settings.alwaysOnTop
        ) { [weak settings] in settings?.alwaysOnTop.toggle() })

        // ... additional menu items via MenuItemFactory.createMenuItem(...)

        // Position calculation accounting for double-size mode
        if let window = findMainWindow() {
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

**Implementation**:
```swift
// File: MacAmpApp/Views/Components/SimpleSpriteImage.swift (actual button pattern)
// Purpose: Interactive sprite rendering with button behaviors
// Context: Core component used throughout all UI views

struct SimpleSpriteImage: View {
    let source: SpriteSource
    let width: CGFloat?
    let height: CGFloat?
    let action: SpriteAction?

    @Environment(SkinManager.self) var skinManager
    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        if let imageName = resolveSpriteName(),
           let image = skinManager.currentSkin?.images[imageName] {

            switch action {
            case .button(let onClick, let whilePressed, let onRelease):
                Image(nsImage: image)
                    .interpolation(.none)  // Pixel-perfect rendering
                    .antialiased(false)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .onHover { hovering in
                        isHovered = hovering
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isPressed {
                                    isPressed = true
                                    whilePressed?()
                                }
                            }
                            .onEnded { _ in
                                if isPressed {
                                    isPressed = false
                                    onRelease?()
                                    onClick?()
                                }
                            }
                    )

            case .toggle(let isOn, let onChange):
                Image(nsImage: image)
                    .interpolation(.none)
                    .antialiased(false)
                    .onTapGesture {
                        onChange(!isOn)
                    }

            default:
                Image(nsImage: image)
                    .interpolation(.none)
                    .antialiased(false)
            }
        }
    }

    private func resolveSpriteName() -> String? {
        switch source {
        case .legacy(let name):
            return name
        case .semantic(let semantic):
            guard let skin = skinManager.currentSkin else { return nil }
            return SpriteResolver(skin: skin).resolve(semantic)
        }
    }
}
```

**Real usage**: All buttons in `MainWindow/MainWindowFullLayer.swift`, `MainWindow/MainWindowTransportLayer.swift`, `WinampEqualizerWindow.swift`

### Pattern: Absolute Positioning Extension

**When to use**: Placing elements at exact pixel coordinates

**Implementation**:
```swift
// File: MacAmpApp/Views/Components/SimpleSpriteImage.swift:85-89
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

### Pattern: Multi-State Slider

**When to use**: Creating draggable sliders with visual feedback

**Implementation**:
```swift
struct SkinSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let thumbSprite: ResolvedSprite
    let trackSprite: ResolvedSprite
    let trackRect: CGRect

    @State private var isDragging = false
    @State private var dragStartValue: Double = 0

    private var thumbOffset: CGFloat {
        let percent = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return trackRect.width * CGFloat(percent)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Track
            Image(nsImage: trackSprite.image)
                .interpolation(.none)

            // Thumb
            Image(nsImage: thumbSprite.image)
                .interpolation(.none)
                .offset(x: thumbOffset)
                .gesture(
                    DragGesture()
                        .onChanged { drag in
                            if !isDragging {
                                isDragging = true
                                dragStartValue = value
                            }

                            let percent = drag.location.x / trackRect.width
                            let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * Double(percent)
                            value = newValue.clamped(to: range)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
        }
        .frame(width: trackRect.width, height: trackRect.height)
    }
}
```

**Real usage**: Volume/balance sliders, EQ sliders

#### Balance Slider Gradient Mapping

The balance slider maps `abs(balance)` (0.0-1.0) to BALANCE.BMP sprite frames using webamp-compatible linear mapping:

```swift
// File: MacAmpApp/Views/Components/WinampVolumeSlider.swift:225-229
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

Balance and volume sliders use haptic feedback when the thumb enters the center snap zone:
- **Threshold**: 12% of slider range (widened from original 8% for noticeable catch)
- **Trigger**: Fires once on entry into snap zone, not on every frame
- **Implementation**: Track previous snap state to detect entry vs. continued presence

### Pattern: VIDEO.bmp Chrome Composition

**When to use**: Building chrome for video windows with VIDEO.bmp assets

**Implementation**:
```swift
// File: MacAmpApp/Views/VideoWindowChromeView.swift
// Purpose: Composite chrome from VIDEO.bmp sprites for video window
// Context: Used by skins with dedicated video window assets

struct VideoWindowChromeView: View {
    @Environment(SkinManager.self) private var skinManager
    @Environment(WindowFocusState.self) private var windowFocusState
    @State private var showingTrackInfo = false

    private var isWindowActive: Bool {
        windowFocusState.isVideoKey
    }

    var body: some View {
        ZStack {
            // Background chrome composition
            VStack(spacing: 0) {
                // Titlebar: 3 sections (left, center tiled, right)
                titleBar

                // Middle: tiled borders
                middleSection

                // Bottom bar (controls and metadata)
                bottomBar
            }

            // Video content area
            GeometryReader { geometry in
                Color.black
                    .frame(
                        width: geometry.size.width - 16,  // 8px borders each side
                        height: geometry.size.height - 65  // Top + bottom chrome
                    )
                    .offset(x: 8, y: 20)  // Position inside chrome
            }
        }
    }

    private var titleBar: some View {
        HStack(spacing: 0) {
            // Left corner (fixed width)
            SimpleSpriteImage(
                source: .semantic(isWindowActive ?
                    .videoTitleBarLeft : .videoTitleBarLeftInactive),
                width: 11, height: 20
            )

            // Center (tiled horizontally)
            SimpleSpriteImage(
                source: .semantic(isWindowActive ?
                    .videoTitleBar : .videoTitleBarInactive)
            )
            .frame(maxWidth: .infinity)
            .drawingGroup()  // Optimize tiling performance

            // Right corner with close button
            ZStack(alignment: .topTrailing) {
                SimpleSpriteImage(
                    source: .semantic(isWindowActive ?
                        .videoTitleBarRight : .videoTitleBarRightInactive),
                    width: 11, height: 20
                )

                // Close button overlay
                SimpleSpriteImage(
                    source: .semantic(.videoCloseButton),
                    action: .button(onClick: { closeWindow() })
                )
                .offset(x: -2, y: 2)
            }
        }
        .frame(height: 20)
    }

    private var bottomBar: some View {
        ZStack {
            // Background
            SimpleSpriteImage(source: .semantic(.videoBottomBar))
                .frame(height: 45)

            // Metadata ticker with TEXT.bmp font
            HStack {
                ScrollingTextView(
                    text: currentMetadata,
                    font: .winampBitmapFont,
                    speed: 1.0
                )
                .frame(maxWidth: 200)
                .offset(x: 10)

                Spacer()

                // Control buttons
                controlButtons
            }
        }
    }
}

// Sprite discovery helpers
extension SkinManager {
    func hasVideoSprites() -> Bool {
        // Check for VIDEO.bmp or video-specific sprites
        return currentSkin?.images["VIDEO"] != nil ||
               currentSkin?.images["videownd"] != nil
    }

    func videoSprite(for section: VideoSection, active: Bool) -> NSImage? {
        // Priority order for sprite discovery:
        // 1. VIDEO.bmp regions (modern skins)
        // 2. videownd_*.bmp (alternative naming)
        // 3. Fallback to generated chrome

        let baseName = active ? section.activeSpriteName : section.inactiveSpriteName

        // Try VIDEO.bmp extraction first
        if let videoBmp = extractFromVideoBmp(section: section, active: active) {
            return videoBmp
        }

        // Try direct sprite files
        if let direct = currentSkin?.images[baseName] {
            return direct
        }

        // Generate fallback
        return generateFallbackChrome(for: section, active: active)
    }
}
```

**Real usage**: `VideoWindowChromeView.swift` for video playback window

**Chrome composition rules**:
1. **Titlebar**: 3-piece (left corner, tiled center, right corner)
2. **Borders**: Tiled vertically for left/right edges
3. **Bottom bar**: Fixed height with embedded controls
4. **Content area**: Inset by chrome thickness (typically 8px borders)

**Metadata ticker pattern**:
```swift
// Use TEXT.bmp for authentic Winamp text rendering
struct MetadataTicker: View {
    let text: String
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        WinampTextView(text: text)
            .offset(x: scrollOffset)
            .onAppear {
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    scrollOffset = -textWidth
                }
            }
    }
}
```

**Pitfalls**:
- VIDEO.bmp may not exist in all skins - need fallback strategy
- Focus state sprites have _SELECTED suffix, not _ACTIVE
- Don't hard-code chrome dimensions - extract from sprites
- Remember to exclude video content area from chrome hit testing
- Tiling performance: use drawingGroup() for repeated sprites
- Some skins use "videownd" prefix instead of "VIDEO"

### Pattern: GEN.bmp Chrome & Two-Piece Sprites

**When to use**: Building general-purpose windows (Milkdrop, Library, etc.) with GEN.bmp

**Implementation**:
```swift
// File: MacAmpApp/Views/MilkdropWindowChromeView.swift
// Purpose: Composite chrome from GEN.bmp sprites with two-piece pattern
// Context: General windows that use GEN.bmp for chrome elements

struct MilkdropWindowChromeView: View {
    @Environment(SkinManager.self) private var skinManager
    @State private var discoveredTwoPiece = false
    @State private var bottomPieceHeight: CGFloat = 14

    var body: some View {
        ZStack {
            // Background chrome
            VStack(spacing: 0) {
                // Titlebar: 6-section pattern
                titleBar

                // Middle content area (black/transparent)
                Color.black
                    .frame(maxHeight: .infinity)

                // Bottom bar (if two-piece sprite exists)
                if discoveredTwoPiece {
                    bottomBar
                }
            }

            // Content overlay
            contentArea
        }
        .onAppear {
            discoverTwoPieceSprites()
        }
    }

    private var titleBar: some View {
        HStack(spacing: 0) {
            // 6-section titlebar composition:
            // 1. Top-left corner (fixed)
            SimpleSpriteImage(
                source: .semantic(isWindowActive ?
                    .genTopLeft : .genTopLeftInactive),
                width: 25, height: 20
            )

            // 2. Left-fill (tiled to caption)
            SimpleSpriteImage(
                source: .semantic(isWindowActive ?
                    .genTopLeftFill : .genTopLeftFillInactive)
            )
            .frame(width: 50)  // Fixed or calculate based on caption

            // 3. Caption/title area (tiled)
            SimpleSpriteImage(
                source: .semantic(isWindowActive ?
                    .genTopTitle : .genTopTitleInactive)
            )
            .frame(maxWidth: .infinity)

            // 4. Right-fill (tiled from caption)
            SimpleSpriteImage(
                source: .semantic(isWindowActive ?
                    .genTopRightFill : .genTopRightFillInactive)
            )
            .frame(width: 50)

            // 5. Top-right corner (fixed)
            SimpleSpriteImage(
                source: .semantic(isWindowActive ?
                    .genTopRight : .genTopRightInactive),
                width: 25, height: 20
            )
        }
        .frame(height: 20)
    }

    // Two-piece sprite discovery
    private func discoverTwoPieceSprites() {
        guard let genBmp = skinManager.currentSkin?.images["GEN"] else { return }

        // Two-piece pattern detection:
        // Main sprite + 1px cyan delimiter + bottom piece
        // Example: GEN.bmp might be 400x35 where:
        // - Rows 0-19: Main titlebar sprites
        // - Row 20: Cyan delimiter (RGB: 0,255,255)
        // - Rows 21-34: Bottom bar sprite

        let bitmap = NSBitmapImageRep(data: genBmp.tiffRepresentation!)!
        let height = bitmap.pixelsHigh

        // Scan for cyan delimiter row
        for y in 20..<height {
            if isCyanRow(bitmap, row: y) {
                // Found delimiter - extract bottom piece
                let bottomHeight = height - y - 1
                if bottomHeight > 0 {
                    discoveredTwoPiece = true
                    bottomPieceHeight = CGFloat(bottomHeight)
                    extractBottomPiece(from: bitmap, startY: y + 1)
                }
                break
            }
        }
    }

    private func isCyanRow(_ bitmap: NSBitmapImageRep, row: Int) -> Bool {
        // Check if entire row is cyan (0,255,255)
        for x in 0..<bitmap.pixelsWide {
            let color = bitmap.colorAt(x: x, y: row)!
            if color.redComponent != 0 || color.greenComponent != 1 || color.blueComponent != 1 {
                return false
            }
        }
        return true
    }

    private var bottomBar: some View {
        // Use discovered bottom piece or fallback
        SimpleSpriteImage(
            source: .semantic(.genBottom)
        )
        .frame(height: bottomPieceHeight)
    }
}

// Letter sprite composition for window titles
struct LetterSpriteText: View {
    let text: String
    let isActive: Bool
    @Environment(SkinManager.self) private var skinManager

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, char in
                letterSprite(for: char)
            }
        }
    }

    private func letterSprite(for char: Character) -> some View {
        // Map character to GEN.bmp letter sprite region
        // Letters are typically in rows with specific offsets
        let spriteRegion = mapCharToSpriteRegion(char, active: isActive)

        return SimpleSpriteImage(
            source: .region(sprite: "GEN", rect: spriteRegion),
            width: 5, height: 7  // Standard Winamp letter size
        )
    }

    private func mapCharToSpriteRegion(_ char: Character, active: Bool) -> CGRect {
        // Character mapping logic
        // A-Z: rows 88-95 (inactive) or 96-103 (active)
        // Special chars: specific coordinates
        let baseY = active ? 96 : 88
        let charIndex = Int(char.asciiValue ?? 65) - 65  // A=0, B=1, etc.
        let x = charIndex * 5
        return CGRect(x: x, y: baseY, width: 5, height: 7)
    }
}
```

**Real usage**: `MilkdropWindowChromeView.swift`, Library window chrome

**Two-piece sprite pattern**:
1. **Detection**: Scan GEN.bmp for cyan delimiter row (0,255,255)
2. **Extraction**: Split sprite into main and bottom pieces
3. **Composition**: Stack pieces with content in between
4. **Caching**: Store extracted pieces to avoid re-scanning

**Focus state handling**:
```swift
// GEN.bmp uses _SELECTED suffix for focused state
let suffix = isWindowActive ? "_SELECTED" : ""
let spriteName = "GEN_TOP_LEFT\(suffix)"
```

**Pitfalls**:
- Cyan delimiter must be EXACTLY (0,255,255) - no tolerance
- Not all skins have two-piece sprites - need detection
- Letter sprites require complex coordinate mapping
- Some skins use different GEN.bmp layouts - be flexible
- Don't assume fixed heights - measure from actual sprites
- _SELECTED suffix varies by skin (some use _ACTIVE)
- Dynamic extraction needed - can't hard-code regions

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

**T3 Decomposition**: PR #54 decomposed `WinampMainWindow.swift` (originally ~650 lines with its extension) into 10 focused files in `MacAmpApp/Views/MainWindow/`. This is the canonical example of the layer decomposition pattern established in Wave 1 (PlaylistWindow) and refined in T3.

**Directory structure**:
```
MacAmpApp/Views/MainWindow/
  WinampMainWindow.swift              # Root composition (103 lines)
  WinampMainWindowInteractionState.swift  # @Observable interaction state
  WinampMainWindowLayout.swift        # Coordinate constants enum
  MainWindowOptionsMenuPresenter.swift # NSMenu bridge (presentation)
  MainWindowFullLayer.swift           # Full-mode composition (~267 lines)
  MainWindowShadeLayer.swift          # Shade-mode composition
  MainWindowTransportLayer.swift      # Prev/Play/Pause/Stop/Next/Eject
  MainWindowSlidersLayer.swift        # Volume/Balance/Position sliders
  MainWindowIndicatorsLayer.swift     # Play state, mono/stereo, bitrate
  MainWindowTrackInfoLayer.swift      # Scrolling track title
```

**Key architectural decisions**:

1. **Root view is thin**: `WinampMainWindow.swift` is ~100 lines -- it owns `@State` for interaction state and presenter, switches between full/shade mode, and wires lifecycle callbacks. No UI building logic.

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

**Known optimization opportunity**: `VisualizerView` is currently inlined in `MainWindowFullLayer` via `buildSpectrumAnalyzer()`. This means the spectrum analyzer shares `MainWindowFullLayer`'s recomposition scope -- a volume drag causes the visualizer to re-evaluate even though its data has not changed. Extracting a `MainWindowVisualizerLayer` struct would create an independent recomposition boundary. This is documented as a future optimization.

**Pitfalls**:
- Children should declare `@Environment` for only the services they actually read -- avoid pulling in unused environments
- The `interactionState` is passed as a plain property (not environment) because it is view-local, not app-wide
- `MainWindowFullLayer` still contains several `@ViewBuilder` helper methods (time digits, shuffle/repeat, clutter bar) that could become separate child views for further recomposition isolation
- When adding new UI elements, add them to the appropriate child layer, not to the root `WinampMainWindow`

---

## Audio Processing Patterns

### Pattern: Safe Audio Buffer Processing

**When to use**: Processing audio buffers from taps

**Implementation**:
```swift
struct AudioProcessor {
    static func processSafely(
        buffer: AVAudioPCMBuffer,
        process: (UnsafeBufferPointer<Float>) -> Void
    ) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        // Process each channel safely
        for channel in 0..<channelCount {
            let data = UnsafeBufferPointer(
                start: channelData[channel],
                count: frameLength
            )
            process(data)
        }
    }

    static func mixToMono(buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }

        let frameLength = Int(buffer.frameLength)
        var mono = [Float](repeating: 0, count: frameLength)

        if buffer.format.channelCount == 2 {
            // Mix stereo to mono
            vDSP_vadd(
                channelData[0], 1,  // Left
                channelData[1], 1,  // Right
                &mono, 1,
                vDSP_Length(frameLength)
            )
            var scale: Float = 0.5
            vDSP_vsmul(&mono, 1, &scale, &mono, 1, vDSP_Length(frameLength))
        } else {
            // Copy mono
            mono = Array(UnsafeBufferPointer(
                start: channelData[0],
                count: frameLength
            ))
        }

        return mono
    }
}
```

**Real usage**: Mono downmix in the two visualizer producers — `VisualizerPipeline.makeTapHandler` (`AVAudioPCMBuffer.floatChannelData`) and `videoTapVisualizerRender` (`AudioBufferList`, interleaved or not). Both write into pre-allocated `VisualizerScratchBuffers` instead of returning a new `[Float]`, because they run on a real-time thread.

### Pattern: Thread-Safe Audio State

**When to use**: Sharing audio state between threads

**Implementation**:
```swift
actor AudioState {
    private var spectrum: [Float] = Array(repeating: 0, count: 75)
    private var waveform: [Float] = Array(repeating: 0, count: 576)

    func updateSpectrum(_ newSpectrum: [Float]) {
        spectrum = newSpectrum
    }

    func updateWaveform(_ newWaveform: [Float]) {
        waveform = newWaveform
    }

    func getSpectrum() -> [Float] {
        spectrum
    }

    func getWaveform() -> [Float] {
        waveform
    }
}

// Usage from audio tap (background thread)
Task {
    let spectrum = processFFT(buffer)
    await audioState.updateSpectrum(spectrum)
}

// Usage from UI (main thread)
Task { @MainActor in
    let spectrum = await audioState.getSpectrum()
    spectrumView.update(spectrum)
}
```

**Real usage**: Suitable for non-real-time producers only. Audio render threads cannot `await`, so visualization data does NOT use an actor — it goes through `VisualizerFeed` (see [SPSC Shared Buffer](#pattern-spsc-shared-buffer-for-audio-to-main-thread-transfer)) and tap parameters through atomics (see [Render-Thread-Safe Shared State](#pattern-render-thread-safe-shared-state)).

### Pattern: nonisolated(unsafe) Deinit Safety (Swift 6)

> **SUPERSEDED (Swift 6.2):** Use `isolated deinit` instead. One `nonisolated(unsafe)` usage remains in the codebase (`StreamDecodePipeline.swift:75`, for AudioWorkgroup interop).

**When to use**: Accessing @MainActor properties in deinit for cleanup

**Swift 6 Relevance**: Required for safe observer cleanup when deinit cannot be @MainActor

**Implementation**:
```swift
// File: MacAmpApp/Audio/VideoPlaybackController.swift:24-85
// Purpose: Clean up AVPlayer observers in deinit (which is nonisolated)
// Context: Swift 6 prohibits calling @MainActor methods from deinit

@MainActor
@Observable
final class VideoPlaybackController {
    // MARK: - Observer Management
    // Note: nonisolated(unsafe) allows deinit to access these for cleanup
    // Safe because at deinit time there are no concurrent references

    @ObservationIgnored nonisolated(unsafe) private var endObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var timeObserver: Any?

    /// Shadow property to maintain AVPlayer reference for deinit access
    /// Required because `player` property might be nil-ed out before deinit
    @ObservationIgnored nonisolated(unsafe) private var _playerForCleanup: AVPlayer?

    @ObservationIgnored private(set) var player: AVPlayer?

    func loadVideo(url: URL, autoPlay: Bool = true) {
        cleanup()  // Clean up any existing video player

        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        _playerForCleanup = newPlayer  // Keep in sync for deinit access

        // ... setup observers ...
    }

    func cleanup() {
        // ... normal cleanup on MainActor ...
        player = nil
        _playerForCleanup = nil  // Keep in sync
    }

    deinit {
        // NOTE: Cannot call @MainActor cleanup() from deinit
        // Must access nonisolated(unsafe) properties directly

        // Remove time observer (requires player reference)
        if let observer = timeObserver, let player = _playerForCleanup {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil

        // Remove notification observer
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        endObserver = nil

        // Pause player for clean shutdown
        _playerForCleanup?.pause()
        _playerForCleanup = nil
    }
}
```

**Key elements**:
1. **nonisolated(unsafe)**: Marks properties as accessible from nonisolated context
2. **Shadow property**: `_playerForCleanup` maintains reference when `player` is nilled
3. **Manual cleanup**: deinit must duplicate cleanup logic (cannot call @MainActor methods)
4. **Safety rationale**: At deinit time, no other references exist - single-threaded access

**When to use**:
- AVPlayer/AVPlayerItem observer cleanup
- NotificationCenter observer removal
- Timer invalidation
- Any cleanup requiring access to @MainActor properties

**Real usage**: `VideoPlaybackController.swift` for observer cleanup, `VisualizerPipeline.swift` for tap removal

**Pitfalls**:
- Must keep shadow properties in sync with main properties
- Document WHY nonisolated(unsafe) is safe in comments
- Don't use nonisolated(unsafe) for properties accessed during normal operation
- Consider if cleanup can be moved to explicit `cleanup()` method called before deinit

### Pattern: SPSC Shared Buffer for Audio-to-Main Thread Transfer

**When to use**: Transferring real-time audio data (visualizer, spectrum, waveform) from the audio thread to the main thread without any heap allocations on the audio thread.

**Swift 6 Relevance**: Replaces the previous `Unmanaged` pointer + `Task { @MainActor }` pattern, eliminating use-after-free risk and audio-thread allocations.

**Why this pattern exists**: Audio engine tap callbacks run on a real-time thread where heap allocations (Array creation, ARC reference counting, Task dispatch) can cause lock contention and buffer underruns (audible skips). This SPSC (Single Producer, Single Consumer) shared buffer eliminates all allocations from the audio thread by using pre-allocated storage and `os_unfair_lock_trylock` for non-blocking publishing.

**S3-2**: The buffer (formerly a private `VisualizerSharedBuffer` inside `VisualizerPipeline.swift`) is now `VisualizerFeed` in `MacAmpApp/Audio/VisualizerFeed.swift`, and the scratch buffers moved to `MacAmpApp/Audio/VisualizerScratchBuffers.swift`. The feed now has two producers (the engine tap and the video tap), only one active at a time — see [Dual-Producer Visualizer Feed](#pattern-dual-producer-visualizer-feed). It is still single-producer at any instant, so the SPSC reasoning below holds.

**Architecture Evolution (BEFORE → AFTER)**:

#### Previous Architecture (Task Dispatch Pattern)

```
┌──────────────────────────────────────────────────────────────┐
│                    AUDIO THREAD (real-time)                   │
│                                                              │
│  AVAudioEngine Tap Callback (~21.5 Hz)                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 1. scratch.prepare(buffer)                             │  │
│  │ 2. FFT + Goertzel computation                          │  │
│  │ 3. snapshotRms()          → NEW Array  ⚠️ ALLOC       │  │
│  │ 4. snapshotSpectrum()     → NEW Array  ⚠️ ALLOC       │  │
│  │ 5. waveformSnapshot       → NEW Array  ⚠️ ALLOC       │  │
│  │    (stride.prefix.map)                                 │  │
│  │ 6. butterchurnSpectrum    → NEW Array  ⚠️ ALLOC       │  │
│  │ 7. butterchurnWaveform    → NEW Array  ⚠️ ALLOC       │  │
│  │ 8. VisualizerData(...)    → struct w/ 5 arrays         │  │
│  │ 9. Task { @MainActor }    → NEW TASK   ⚠️ ALLOC+ARC   │  │
│  └────────────────┬───────────────────────────────────────┘  │
│                   │                                          │
│         ~7-8 heap allocations per callback                   │
│         = ~150-170 allocations/second                        │
│         = ARC ref counting = potential lock acquisition      │
│         = AUDIO THREAD STALL = SKIP                          │
└───────────────────┼──────────────────────────────────────────┘
                    │ Task dispatch (heap alloc)
                    ▼
┌──────────────────────────────────────────────────────────────┐
│                    MAIN THREAD                                │
│  Task { @MainActor in                                        │
│      pipeline.visualizerData = data   ← triggers @Observable │
│      pipeline.butterchurnFrame = ...  ← triggers @Observable │
│  }                                                           │
└──────────────────────────────────────────────────────────────┘
```

**Problems:** 7-8 heap allocations per callback on the audio thread. Any allocation can trigger ARC reference counting (which acquires locks), potentially stalling the real-time audio thread and causing buffer underruns (audible skips).

#### New Architecture (SPSC Shared Buffer)

```
┌──────────────────────────────────────────────────────────────┐
│                    AUDIO THREAD (real-time)                   │
│                                                              │
│  AVAudioEngine Tap Callback (~21.5 Hz)                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 1. scratch.prepare(buffer)          ← no alloc         │  │
│  │ 2. FFT + Goertzel computation       ← no alloc         │  │
│  │ 3. feed.tryPublish(scratch)         ← no alloc         │  │
│  │    ├─ os_unfair_lock_trylock()   (non-blocking)        │  │
│  │    ├─ if locked: memcpy into pre-allocated arrays      │  │
│  │    ├─ waveform: direct stride copy (no map/iterator)   │  │
│  │    ├─ generation += 1                                  │  │
│  │    └─ unlock                                           │  │
│  │    └─ if contention: drop frame (inaudible, invisible) │  │
│  └────────────────┬───────────────────────────────────────┘  │
│                   │                                          │
│         ZERO heap allocations per callback                   │
│         trylock = non-blocking (never stalls audio thread)   │
└───────────────────┼──────────────────────────────────────────┘
                    │ Shared memory (VisualizerFeed)
                    │ Pre-allocated arrays, atomic generation
                    ▼
┌──────────────────────────────────────────────────────────────┐
│                    MAIN THREAD (30 Hz Timer)                  │
│                                                              │
│  pollVisualizerData() ← Timer @ 30 Hz on RunLoop.main .common│
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 1. feed.consume()                                      │  │
│  │    ├─ os_unfair_lock_lock()    (OK to block here)      │  │
│  │    ├─ check generation > lastConsumed                   │  │
│  │    ├─ create VisualizerData from pre-allocated storage  │  │
│  │    └─ unlock, return data                              │  │
│  │ 2. self.visualizerData = data  ← triggers @Observable  │  │
│  │ 3. self.butterchurnFrame = ... ← triggers @Observable  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  Array allocation happens HERE (main thread = safe)          │
└──────────────────────────────────────────────────────────────┘
```

**Key change:** Zero allocations on the audio thread. All Array creation happens on the main thread (30 Hz poll timer), where heap allocations and ARC operations are safe. The `os_unfair_lock_trylock()` is non-blocking - if the main thread holds the lock, the audio thread simply drops that frame (imperceptible at 21.5 Hz).

**Simplified data flow**:
```
Audio Thread (21.5 Hz)              Main Thread (30 Hz poll timer)
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

**Supersedes**: The previous `Unmanaged` pointer + `Task { @MainActor }` pattern, which had two problems:
- **7-8 heap allocations per audio callback** (Array creation, Task dispatch, ARC)
- **Use-after-free risk** if `removeTap()` was not called before deallocation

The SPSC pattern eliminates both: zero audio-thread allocations in steady state, and no raw pointer lifetime management required.

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

**Related Memory Optimizations (Same Release)**:

The SPSC pattern was part of a comprehensive memory optimization effort. Other key improvements:

#### Skin Loading Pipeline Optimization

**BEFORE (Double Load):**
```
┌─────────────────────────────────────────────────────────────┐
│                    APP STARTUP                                │
│                                                              │
│  SkinManager.loadInitialSkin()                               │
│  ┌───────────────────────────────────────────────────────┐   │
│  │ Step 1: loadDefaultSkinIfNeeded()                     │   │
│  │   ├─ SkinArchiveLoader.load(Winamp.wsz)               │   │
│  │   │   └─ Extract ALL BMP sheets from ZIP              │   │
│  │   ├─ parseDefaultSkin(payload)                        │   │
│  │   │   ├─ For EACH sheet: NSImage(data:) ⚠️ PEAK      │   │
│  │   │   └─ For EACH sprite: crop → NSImage  ⚠️ PEAK    │   │
│  │   └─ defaultSkin = Skin(images: ~200 sprites)         │   │
│  │       └─ ~15-20 MB of NSImages PERMANENTLY in memory  │   │
│  │                                                       │   │
│  │ Step 2: switchToSkin(selectedSkin)                     │   │
│  │   ├─ SkinArchiveLoader.load(selected.wsz)             │   │
│  │   │   └─ Extract ALL BMP sheets from ZIP  ⚠️ DOUBLE   │   │
│  │   ├─ applySkinPayload(payload)                        │   │
│  │   │   ├─ For EACH sheet: NSImage(data:)               │   │
│  │   │   └─ For EACH sprite: crop → NSImage              │   │
│  │   └─ currentSkin = Skin(images: ~200 sprites)         │   │
│  │                                                       │   │
│  │ PEAK MEMORY: default sprites + selected sprites       │   │
│  │              + intermediate CGImage buffers            │   │
│  │              + float pixel backing stores              │   │
│  │              = ~594 MB PEAK                            │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  At rest: defaultSkin (~15-20 MB) + currentSkin (~15-20 MB)  │
│         = ~30-40 MB of sprite images always in memory        │
└─────────────────────────────────────────────────────────────┘
```

**AFTER (Lazy Loading):**
```
┌─────────────────────────────────────────────────────────────┐
│                    APP STARTUP                                │
│                                                              │
│  SkinManager.loadInitialSkin()                               │
│  ┌───────────────────────────────────────────────────────┐   │
│  │ Step 1: loadDefaultSkinIfNeeded()                     │   │
│  │   ├─ SkinArchiveLoader.load(Winamp.wsz)               │   │
│  │   └─ defaultSkinPayload = payload  (~200 KB ZIP data) │   │
│  │       └─ NO sprite parsing, NO NSImage creation       │   │
│  │       └─ Sprites extracted LAZILY on demand            │   │
│  │                                                       │   │
│  │ Step 2a: IF selected == "bundled:Winamp"              │   │
│  │   └─ parseDefaultSkinFully(payload)                   │   │
│  │       ├─ Parse sprites with autoreleasepool            │   │
│  │       ├─ Populate defaultSkinSpriteCache              │   │
│  │       └─ currentSkin = Skin(...)                       │   │
│  │       └─ PEAK: only ONE skin parsed (not two)         │   │
│  │                                                       │   │
│  │ Step 2b: IF selected != default                       │   │
│  │   ├─ switchToSkin(selectedSkin)                        │   │
│  │   ├─ applySkinPayload() with autoreleasepool per crop │   │
│  │   │   └─ Missing sheets → lazy fallback:              │   │
│  │   │       fallbackSpritesFromDefaultSkin()             │   │
│  │   │       ├─ Extract ONLY the missing sheet from ZIP  │   │
│  │   │       ├─ Cache in defaultSkinSpriteCache          │   │
│  │   │       └─ Only ~5-10 sprites per missing sheet     │   │
│  │   └─ currentSkin = Skin(...)                           │   │
│  │                                                       │   │
│  │ PEAK MEMORY: payload (~200 KB) + ONE skin's sprites   │   │
│  │              + autoreleasepool cleans intermediates    │   │
│  │              = MUCH LOWER PEAK                        │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  At rest: payload (~200 KB) + spriteCache (lazy, partial)    │
│         + currentSkin (~15-20 MB)                            │
│         = ~15-20 MB total (was ~30-40 MB)                    │
└─────────────────────────────────────────────────────────────┘
```

**Result**: Peak memory reduced from ~594 MB to ~553 MB (-23%) by avoiding double skin parse. At-rest memory reduced from ~30-40 MB to ~15-20 MB (-50%) through lazy fallback extraction.

#### CGImage Cropping Pipeline Optimization

**BEFORE (Shared Parent Buffer):**
```
NSImage.cropped(to: rect)
├─ self.cgImage(forProposedRect:)  → creates float-format backing store
├─ cgImage.cropping(to:)           → child CGImage SHARES parent buffer
└─ NSImage(cgImage:, size:)        → wraps child, parent buffer RETAINED
    └─ Parent's full float pixel buffer stays alive as long as
       ANY cropped sprite references it (~136 KB per parent sheet)
```

**AFTER (Independent Copy):**
```
NSImage.cropped(to: rect)
├─ self.cgImage(forProposedRect:)  → creates float-format backing store
├─ cgImage.cropping(to:)           → child CGImage references parent
├─ CGContext(sRGB, RGBA8, 8bpc)    → independent context
├─ context.draw(croppedCGImage)    → copies pixels into new buffer
├─ context.makeImage()             → independent CGImage (no parent ref)
└─ NSImage(cgImage:, size:)        → wraps independent image
    └─ Parent float buffer is released when autorelease pool drains
    └─ Each sprite owns only its own pixel data (~width*height*4 bytes)
```

**Result**: Eliminates parent-child buffer retention. Each sprite owns only its own pixels instead of retaining the full parent sheet buffer. Combined with `autoreleasepool` per crop, this prevents accumulation during sprite extraction loops.

**File**: `MacAmpApp/Models/ImageSlicing.swift`

#### Pause Tap Policy

**BEFORE:**
```
play()  → installVisualizerTapIfNeeded()
pause() → (tap stays active, callbacks continue at 21.5 Hz)
stop()  → removeVisualizerTapIfNeeded()
```

**AFTER:**
```
play()  → installVisualizerTapIfNeeded()  + startPollTimer()
pause() → removeVisualizerTapIfNeeded()   ← NEW
stop()  → removeVisualizerTapIfNeeded()
          (removeTap also stops poll timer)
```

**Result**: Removes visualizer tap on pause, saving CPU during paused playback. Previously the tap continued running at 21.5 Hz even when paused, consuming ~1-2% CPU for unused visualization data.

### Pattern: Stream Decode Pipeline (Unified Audio)

**When to use**: Decoding internet radio streams (SHOUTcast/Icecast) into PCM for playback through AVAudioEngine, enabling EQ, visualization, and balance for streams — feature parity with local files.

**Unified Pipeline**: Replaces the previous AVPlayer-based StreamPlayer. AVPlayer was a black box that provided no access to decoded PCM, preventing EQ, visualization, and balance for streams. The custom decode pipeline feeds PCM directly into AVAudioEngine via AVAudioSourceNode.

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

**Buffer sizing note**: The stream ring buffer is sized in frames, not seconds. For the current `32768`-frame capacity, that works out to about `0.743 s` at `44.1 kHz`, `0.683 s` at `48 kHz`, and `0.341 s` at `96 kHz`. Bitrate values such as `192 kbps` are compressed data-rate measurements and do not determine the ring buffer's sample rate.

**Key component — DecodeContext**:
```swift
// File: MacAmpApp/Audio/StreamDecodePipeline.swift
// Purpose: Queue-confined mutable state for the decode pipeline
// Context: @unchecked Sendable because all access is on the serial decode queue

final class DecodeContext: @unchecked Sendable {
    let framer: ICYFramer
    let parser: AudioFileStreamParser
    let decoder: AudioConverterDecoder
    let ringBuffer: LockFreeRingBuffer

    // All mutation happens on decodeQueue — no locks needed
}
```

**Key component — StreamDecodePipeline**:
```swift
// File: MacAmpApp/Audio/StreamDecodePipeline.swift
// Purpose: @MainActor orchestrator that owns the decode queue and DecodeContext
// Context: Observable state (playing/buffering/error) published to UI

@MainActor final class StreamDecodePipeline {
    private let decodeQueue = DispatchQueue(label: "...", qos: .userInitiated)
    private var decodeContext: DecodeContext?  // @unchecked Sendable, queue-confined

    // Callbacks to StreamPlayer (dispatched to MainActor)
    var onStateChange: ((StreamState) -> Void)?
    var onFormatReady: ((Float64) -> Void)?
    var onMetadata: ((ICYFramer.ICYMetadata) -> Void)?
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

**Unified Pipeline**: This pattern was discovered during the stream decode pipeline implementation. AudioConverter's input callback has a strict contract: the buffer provided to the converter must remain valid until the NEXT callback invocation.

**Implementation**:
```swift
// File: MacAmpApp/Audio/AudioConverterDecoder.swift
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

**Unified Pipeline**: After the stream bridge sets an explicit non-interleaved format on graph connections, reconnecting with `format: nil` causes EQ node format stickiness (error -10868). Always use explicit `AVAudioFormat` for all graph connections.

**Implementation**:
```swift
// File: MacAmpApp/Audio/AudioPlayer.swift
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
4. **`deactivateStreamBridge()` in `rewireForCurrentFile()`** — this is the single choke point for ALL local file playback paths (drag-and-drop, playlist double-click, etc.)

**Real usage**: `AudioPlayer.swift` `rewireForCurrentFile()`, `activateStreamBridge()`, `deactivateStreamBridge()`

**Pitfalls**:
- Error -10868 (`kAudioUnitErr_FormatNotSupported`) almost always means a stale format from a previous graph configuration
- Direct playback paths that bypass PlaybackCoordinator must still deactivate the bridge — guard this in `rewireForCurrentFile()`
- Engine start must be a hard gate: if `audioEngine.start()` fails, abort immediately (don't install taps or call `playerNode.play()`)

### Pattern: Engine File Duration as Authoritative Source (VBR Lesson, S1)

**When to use**: Computing playback progress and seek targets for local audio files. The engine's `AVAudioFile.length / sampleRate` is the authoritative duration for runtime progress, NOT metadata duration from `AVAsset.duration`.

**S1**: Discovered when VBR (Variable Bit Rate) MP3 files caused seek bar drift. `AVAsset.duration` uses the file's metadata header (which estimates duration from average bitrate), while `AVAudioFile.length` counts actual audio frames. These diverge on VBR files, causing the seek bar to jump at end-of-track when the two sources disagree.

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

**S3-2**: Introduced so video audio (played by `AVPlayer`, never routed through `AVAudioEngine`) gets the same DSP as local files. Design rationale: `tasks/avplayer-native-video-dsp/plan.md` ADR-1, ADR-3, ADR-7, ADR-10.

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

**S3-2**: The `VideoTapContext` envelope is `@unchecked Sendable` to cross the C boundary. The unsafety is contained by restricting every stored property to a thread-safe storage shape and enforcing that with tests. Rationale: plan ADR-3, ADR-3a, ADR-4 amendment #2.

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

**Storage rules** (from the `VideoTapContext.swift` header contract):

| Permitted | Forbidden |
|---|---|
| `Synchronization.Atomic<T>` | `@MainActor`- or actor-isolated types |
| `Synchronization.Mutex<T>` — render side uses `withLockIfAvailable` only | Non-`Sendable` reference types (unless render-confined and marked) |
| `let` of an immutable value type | Swift closures that capture state |
| Unsafe pointers owned by the class's `init`/`deinit` | Any `var` that is not `Atomic`/`Mutex` |
| Types conforming to `RenderThreadSafe` | |

**Contract tests** (`Tests/MacAmpTests/VideoTapSendableContractTests.swift`):
1. `Mirror` over the Context's stored fields — every Copyable field must be `RenderThreadSafe` (`~Copyable` `Atomic`/`Mutex` reflect as `Void` and are skipped)
2. Source regex over `VideoTapContext.swift` — every stored `var` must be `Atomic<…>` or `Mutex<…>`
3. Render confinement — `.cascade` may appear only in `VideoTapContext.swift` and `VideoTap.swift`

**Real usage**: `VideoTapContext.swift`, `RenderThreadSafe.swift`, `VideoTap.swift` (`tapPrepare`, `tapProcess`)

**Pitfalls**:
- Don't collapse the `withLockIfAvailable` result with `??` or `if let` — "contended" (keep the cache) and "nothing installed" (bypass) need different handling
- Hold the Mutex only to copy the value out; run the DSP lock-free against the render-owned copy
- Store `Float`/`Double` through atomics as `bitPattern` (`Atomic<UInt32>` / `Atomic<UInt64>`)
- Main-thread writers (fan-out) write only the Mutex and atomics, never a render-confined field — contract test 3 catches `.cascade`
- `Mirror` cannot see `~Copyable` fields; a future non-atomic `~Copyable` `let` is caught only by review against the header contract
- Adding a field means updating the header contract comment and, if needed, adding a conformance in `RenderThreadSafe.swift`

### Pattern: Pinned Tap Format and Build-Time audioMix

**When to use**: Installing an `MTAudioProcessingTap` on an `AVPlayerItem` so its processing format is stable and it is never added to an item that is already playing.

**S3-2**: Rationale in plan ADR-7 (+ amendment) and ADR-12.

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

**Why pin**: without a preferred format the tap runs in a format optimized for the current output device, so it changes with the route. On system-output AirPlay 2 that produced audible pumping and cut-outs; pinning to the source rate removed it. Pinning to **stereo** (not the source layout) keeps channels 0/1 as L/R for the balance stage — mono is upmixed and 5.1 downmixed by the system before the tap.

**Real usage**: `VideoTap.preferredProcessingFormat(for:)` / `createTap`, `VideoPlaybackController.loadVideo(url:autoPlay:audioMixBuilder:isStillRelevant:)`, orchestrated by `AudioPlayer.startVideoLoad(track:)`

**Pitfalls**:
- Never assign `audioMix` to an item an `AVPlayer` already owns, or while playing; to detach, pause first
- One tap + one Context per `AVPlayerItem`; a new item gets a freshly built pair
- `tapPrepare` still validates the negotiated format (Float32 LPCM gate) — the preferred format is a request, not a guarantee
- 5.1+ sources play as stereo while the pin is in place, including on multichannel outputs

### Pattern: Parallel DSP Fan-Out via WeakBox Registries

**When to use**: One `@MainActor` owner of a setting must drive several DSP sinks with independent lifetimes (the engine node plus zero or more per-video-item taps), without the owner keeping the sinks alive.

**S3-2**: EQ is owned by `EqualizerController`, balance by `AudioPlayer`. Each fans out to its engine node and to registered `VideoTapContext`s through its own registry. Rationale: plan ADR-5. (Contrast [Coordinator Volume Routing](#pattern-coordinator-volume-routing), where a coordinator fans one value out to whole playback backends.)

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

**S3-2**: Rationale: plan ADR-6.

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

**S3-2**: Added to `tapProcess`. Rationale: plan Phase 6.

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

**Readout**: there is no log path — counters are read on the main thread via `VideoTapContext.diagnosticSnapshot` (an immutable `Sendable` `VideoTapDiagnostics`). In practice they are read from LLDB with a breakpoint in `EqualizerController.pollVideoTapSampleRates()`, which fires at 30 Hz during video. In optimized builds the computed `diagnosticSnapshot` getter is stripped; load the atomics directly instead (`expr -l swift -- import Synchronization`, then `….registeredVideoTapContexts[0].value!.budgetOverrunCount.load(ordering: .relaxed)`). Procedure: `tasks/avplayer-native-video-dsp/verification.md` gate 8.5e.

**Real usage**: `VideoTap.swift` (`tapProcess`, cached `videoTapMachTimebase`, `prewarmVideoTapTimebase()`), `VideoTapContext.swift` (`recordProcessingDeadline`, `diagnosticSnapshot`). Tests: `Tests/MacAmpTests/VideoTapTelemetryTests.swift` call `recordProcessingDeadline` directly with synthetic values.

**Pitfalls**:
- 1-in-64 sampling is advisory observability, not a CPU gate — use the dense benchmark (see [Wall-Clock Benchmarks Disabled Under TSan](#pattern-wall-clock-benchmarks-disabled-under-tsan)) for pass/fail
- Query `mach_timebase_info` once and prewarm it from the main thread, so the first sampled callback doesn't pay the lazy-init once-token
- No `os_log`/`print` on the render thread, even on the sampled path
- `diagnosticSnapshot` does independent relaxed loads; fields may be from slightly different instants

---

## Async/Await Patterns

### Pattern: Async Stream Events

**When to use**: Publishing events from async contexts

**Implementation**:
```swift
@Observable
final class EventEmitter {
    let events: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation

    enum Event {
        case trackChanged(Track)
        case errorOccurred(Error)
        case stateChanged(State)
    }

    init() {
        (events, continuation) = AsyncStream<Event>.makeStream()
    }

    func emit(_ event: Event) {
        continuation.yield(event)
    }

    deinit {
        continuation.finish()
    }
}

// Consumer
Task {
    for await event in emitter.events {
        switch event {
        case .trackChanged(let track):
            updateUI(for: track)
        case .errorOccurred(let error):
            showError(error)
        case .stateChanged(let state):
            handleStateChange(state)
        }
    }
}
```

**Real usage**: Future pattern for event systems

### Pattern: Cancellable Tasks

**When to use**: Tasks that should be cancelled when view disappears

**Implementation**:
```swift
struct DataLoadingView: View {
    @State private var loadTask: Task<Void, Never>?
    @State private var data: [Item] = []

    var body: some View {
        List(data) { item in
            ItemRow(item: item)
        }
        .task {
            loadTask = Task {
                do {
                    for await batch in loadDataStream() {
                        // Check for cancellation
                        try Task.checkCancellation()
                        data.append(contentsOf: batch)
                    }
                } catch {
                    // Handle cancellation or other errors
                    if !Task.isCancelled {
                        print("Load error: \(error)")
                    }
                }
            }
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }
}
```

**Real usage**: Stream metadata loading in `StreamPlayer.swift`

### Pattern: Background I/O with @concurrent Static Functions (Swift 6.2)

**When to use**: File I/O operations that should run off the calling actor's executor

**Swift 6.2 Relevance**: Uses `@concurrent` static functions with serialized Task chaining, replacing the older `Task.detached` pattern

> **Swift 6.2:** `@concurrent` on a static function tells Swift to run it off the calling actor's executor, replacing `Task.detached` for this kind of off-actor helper. The surrounding `Task {}` call remains unstructured, so ownership and cancellation still need to be managed explicitly.

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

**Real usage**: `EQPresetStore.savePerTrackPresets()`, per-track preset auto-save

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
- `AudioPlayer.swift` for `onTrackMetadataUpdate`, `onPlaylistAdvanceRequest` callbacks (PR #49)

**AudioPlayer callback split (PR #49)**: The former single `externalPlaybackHandler` on AudioPlayer was split into two purpose-specific callbacks:
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
// File: MacAmpApp/Audio/PlaybackCoordinator.swift:78-88
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

#### AudioEngineController Callback Wiring (S1 Decomposition)

**Context**: When `AudioEngineController` was extracted from `AudioPlayer` in S1, it took ownership of the progress timer, audio scheduling completion, and bridge state -- but `AudioPlayer` still owns the observable state that drives the UI. Three callbacks bridge this gap:

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

**Unified Pipeline**: These callbacks replace the previous AVPlayer-based approach where streams were fully self-contained. With the unified pipeline, StreamPlayer produces PCM into a ring buffer, and AudioPlayer consumes it via AVAudioSourceNode — requiring explicit bridge lifecycle management.

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
- `onFormatReady` fires ONCE per stream, after prebuffer threshold is reached (~16384 frames / ~371ms)
- `onStreamTerminated` fires on idle or error states — PlaybackCoordinator checks `isBridgeActive` before deactivating
- ICYFramer.configure() must be called EXACTLY ONCE per stream, from the delegate queue (NOT MainActor)
- Bridge deactivation must occur in ALL playback transition paths (stream-to-local, stream-to-stream, stop)

**Real usage**: `StreamPlayer.swift` callbacks, `PlaybackCoordinator.swift` init wiring

**Pitfalls**:
- Calling `configureFramer` from both delegate queue AND MainActor causes double-configure — the second call resets `audioByteCount`, corrupting ICY metadata alignment for the entire stream
- When adding an "early" call to fix a race, ALWAYS search for and remove the "late" call (`grep -r "configureFramer"`)
- Diagnostic code (file I/O) on the decode queue can mask this timing bug by adding latency

### Pattern: Exponential Backoff Reconnect with Bridge Tear-Down (S1)

**When to use**: Automatically reconnecting internet radio streams after transient network failures while maintaining AVAudioEngine bridge integrity.

**S1**: Introduced to give internet radio streams resilience against network glitches, server restarts, and connection resets without user intervention.

**Implementation**:
```swift
// File: MacAmpApp/Audio/StreamPlayer.swift
// Purpose: Reconnect with exponential backoff, tearing down and re-creating the bridge each attempt
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

**S3-2**: `AudioPlayer.startVideoLoad(track:)` awaits track loading and format loading before building the tap and the `AVPlayer`. Main-actor code is reentrant across `await`, so every suspension point is a place where the world may have changed. Rationale: plan ADR-7 amendment.

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

**S3-2**: Added for output-route changes (Control Center, AirPlay, HDMI, sleep/wake) that fire several `AVAudioEngineConfigurationChange` notifications.

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
// Called from play/pause/stop/seek/playTrack
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

### Pattern: Result Builder for Complex Operations

**When to use**: Operations with multiple failure points

**Implementation**:
```swift
enum LoadError: Error {
    case invalidURL
    case downloadFailed(Error)
    case extractionFailed
    case parsingFailed(String)
}

struct SkinLoader {
    static func load(from url: URL) async -> Result<Skin, LoadError> {
        // Validate URL
        guard url.pathExtension == "wsz" else {
            return .failure(.invalidURL)
        }

        // Download if needed
        let localURL: URL
        if url.isFileURL {
            localURL = url
        } else {
            do {
                localURL = try await download(url)
            } catch {
                return .failure(.downloadFailed(error))
            }
        }

        // Extract archive
        guard let extracted = try? extractArchive(localURL) else {
            return .failure(.extractionFailed)
        }

        // Parse skin files
        guard let skin = try? parseSkin(from: extracted) else {
            return .failure(.parsingFailed("Invalid skin format"))
        }

        return .success(skin)
    }
}

// Usage
Task {
    let result = await SkinLoader.load(from: skinURL)

    switch result {
    case .success(let skin):
        applySkin(skin)
    case .failure(let error):
        switch error {
        case .invalidURL:
            showAlert("Invalid skin file")
        case .downloadFailed(let underlying):
            showAlert("Download failed: \(underlying)")
        case .extractionFailed:
            showAlert("Could not extract skin archive")
        case .parsingFailed(let reason):
            showAlert("Skin format error: \(reason)")
        }
    }
}
```

**Real usage**: Skin loading in `SkinManager.swift`

### Pattern: Graceful Degradation

**When to use**: Non-critical features that shouldn't crash the app

**Implementation**:
```swift
struct VisualizationView: View {
    @State private var spectrum: [Float] = Array(repeating: 0, count: 75)
    @State private var visualizationAvailable = true

    var body: some View {
        Group {
            if visualizationAvailable {
                SpectrumBars(data: spectrum)
                    .onAppear {
                        startVisualization()
                    }
            } else {
                // Fallback UI
                Text("Visualization unavailable")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func startVisualization() {
        do {
            try AudioEngine.shared.installTap { buffer in
                // Process audio
                updateSpectrum(from: buffer)
            }
        } catch {
            // Gracefully degrade
            print("Could not start visualization: \(error)")
            visualizationAvailable = false
        }
    }
}
```

**Real usage**: Spectrum analyzer fallback

### Pattern: Typed Stream Termination Reasons (S1)

**When to use**: Classifying stream failure modes to determine reconnect eligibility, replacing string-based error matching with exhaustive enum pattern matching.

**S1**: Introduced to replace ad-hoc `error.localizedDescription.contains(...)` string matching in StreamPlayer reconnect logic. The typed enum ensures all failure modes are handled at compile time and makes reconnect policy explicit.

**Implementation**:
```swift
// File: MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift
// Purpose: Typed enum for all stream termination modes
// Context: Produced by StreamDecodePipeline, consumed by StreamPlayer for reconnect decisions

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

**Configuration**: Single "All" configuration running the full `MacAmpTests` target (simplified from the previous 3-configuration layout with per-test `selectedTests`).

**CLI**:
```bash
xcodegen generate  # if xcodeproj is stale or missing
xcodebuild test -scheme MacAmpApp -destination 'platform=macOS'
```

**Thread Sanitizer run** (required before committing): add `-enableThreadSanitizer YES`. Wall-clock benchmarks skip themselves under TSan (see [Wall-Clock Benchmarks Disabled Under TSan](#pattern-wall-clock-benchmarks-disabled-under-tsan)), so run the suite once without TSan as well.

**Video fixtures**: `VideoTapLifecycleTests` and `VideoSeekStateMatrixTests` load clips from `clapperboard-videos/` at the project root (resolved via `SRCROOT`, falling back to `#filePath`).

### Pattern: Mock Injection for Testing

**When to use**: Unit testing components with dependencies

**Implementation**:
```swift
// Protocol for mockable dependency
protocol AudioPlayable {
    var isPlaying: Bool { get }
    func play()
    func pause()
    func stop()
}

// Real implementation
@Observable
final class AudioPlayer: AudioPlayable {
    private(set) var isPlaying = false

    func play() {
        // Real implementation
        isPlaying = true
    }
}

// Mock for testing
class MockAudioPlayer: AudioPlayable {
    var isPlaying = false
    var playCalled = false

    func play() {
        playCalled = true
        isPlaying = true
    }
}

// Component that uses the protocol
struct PlayerControls: View {
    let player: AudioPlayable

    var body: some View {
        Button(player.isPlaying ? "Pause" : "Play") {
            if player.isPlaying {
                player.pause()
            } else {
                player.play()
            }
        }
    }
}

// Test
func testPlayButton() {
    let mock = MockAudioPlayer()
    let controls = PlayerControls(player: mock)

    // Trigger play
    controls.playButton.tap()

    XCTAssertTrue(mock.playCalled)
    XCTAssertTrue(mock.isPlaying)
}
```

**Real usage**: Testing patterns for `PlaybackCoordinator`

### Pattern: Async Test Helpers

> **Note:** MacAmp tests have been migrated to Swift Testing (`struct` suites, `#expect` macros, `@Test` attributes). The `XCTestCase` extension below is a **legacy pattern** retained for reference. New tests should use Swift Testing's built-in concurrency support (e.g., `await confirmation()`, `#expect(throws:)`) instead.

**When to use**: Testing async operations (legacy XCTest pattern)

**Implementation**:
```swift
// LEGACY: XCTestCase-based pattern. New tests use Swift Testing struct suites.
extension XCTestCase {
    func asyncTest<T>(
        timeout: TimeInterval = 5,
        test: @escaping () async throws -> T
    ) async throws -> T {
        try await withTimeout(seconds: timeout) {
            try await test()
        }
    }

    func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TestTimeout()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// Usage in test
func testStreamLoading() async throws {
    let player = StreamPlayer()

    try await asyncTest {
        await player.play(url: testStreamURL)
        XCTAssertTrue(player.isPlaying)
    }
}
```

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

### Migrating from Boolean to Enum State (RepeatMode Example)

**When to migrate**: When a boolean flag becomes insufficient and you need 3+ states

**Before**: Boolean flag with limited expressiveness
```swift
// Old implementation
class AudioPlayer {
    @Published var repeatEnabled: Bool = false  // Only on/off

    func handleTrackEnd() {
        if repeatEnabled {
            // Repeat... but what exactly? Current track? Playlist?
            restartPlaylist()  // Ambiguous behavior
        }
    }
}
```

**After**: Rich enum with clear semantics
```swift
// New implementation with RepeatMode enum
enum RepeatMode: String, Codable, CaseIterable {
    case off = "off"   // Stop at end
    case all = "all"   // Loop playlist
    case one = "one"   // Repeat current track
}

class AudioPlayer {
    var repeatMode: RepeatMode = .off

    func handleTrackEnd() {
        switch repeatMode {
        case .off:
            stop()  // Clear behavior
        case .all:
            playFirstTrack()  // Clear behavior
        case .one:
            restartCurrentTrack()  // Clear behavior
        }
    }
}
```

**Migration with User Preference Preservation**:
```swift
// In AppSettings init()
init() {
    // Try to load new enum value
    if let savedMode = UserDefaults.standard.string(forKey: "repeatMode"),
       let mode = RepeatMode(rawValue: savedMode) {
        self.repeatMode = mode
    } else {
        // Fall back to old boolean, preserve user's choice
        let oldRepeat = UserDefaults.standard.bool(forKey: "audioPlayerRepeatEnabled")
        self.repeatMode = oldRepeat ? .all : .off

        // Save in new format
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")

        // Optional: Clean up old key
        UserDefaults.standard.removeObject(forKey: "audioPlayerRepeatEnabled")
    }
}
```

**Real usage**: RepeatMode migration in MacAmp v0.7.9

### Migrating from Task.detached to @concurrent (Swift 6.2)

**When to migrate**: Any use of `Task.detached` for running work off the calling actor's executor

**Why**: Swift 6.2 changed the behavior of nonisolated async functions to inherit the caller's executor by default. `@concurrent` explicitly opts into off-actor execution, replacing the old `Task.detached` escape hatch for this helper pattern while preserving explicit actor boundaries.

**Before**: Unstructured `Task.detached`
```swift
// Old pattern: Task.detached for off-actor I/O
func saveData() {
    let snapshot = data
    Task.detached(priority: .utility) {
        await doWork(snapshot)
    }
}
```

**After**: `@concurrent` static function with Task chaining
```swift
// New pattern: @concurrent static func called from an owned Task chain
func saveData() {
    let snapshot = data
    let previousTask = saveTask
    saveTask = Task {
        _ = await previousTask?.result  // serialize writes
        await Self.doWork(snapshot)
    }
}

@concurrent
private static func doWork(_ data: SomeData) async {
    // Runs off the calling actor's executor
}
```

**Key differences**:
- `@concurrent` controls executor placement; the surrounding `Task {}` remains unstructured but can still be owned and cancelled by the caller
- Task chaining via `previousTask?.result` serializes writes, preventing out-of-order execution
- `@concurrent` on a static function is explicit about actor isolation (runs off-actor)
- No need for `priority:` parameter -- Task inherits caller's priority by default

**Real usage**: `EQPresetStore.swift` (savePresetsToDisk, loadPresetsFromDisk, parseEqfFile)

### Migrating from Timer to Task.sleep

**Before**: Timer-based updates
```swift
class PollingService {
    private var timer: Timer?

    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.poll()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
```

**After**: Task-based updates
```swift
@Observable
final class PollingService {
    private var pollTask: Task<Void, Never>?

    func startPolling() {
        pollTask = Task {
            while !Task.isCancelled {
                poll()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
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
guard let track = playlist.tracks[safe: index] else { return }
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

### Anti-Pattern: Massive View Bodies

**Wrong**:
```swift
struct BadView: View {
    var body: some View {
        // ❌ 500+ lines of nested views
        VStack {
            // ... hundreds of lines
        }
    }
}
```

**Correct**:
```swift
struct GoodView: View {
    var body: some View {
        VStack {
            HeaderSection()
            ContentSection()
            FooterSection()
        }
    }
}

// Extracted into focused components
struct HeaderSection: View { ... }
struct ContentSection: View { ... }
struct FooterSection: View { ... }
```

### Anti-Pattern: Cross-File SwiftUI Extensions as View Decomposition

**Context**: PR #49 split `WinampMainWindow.swift` and `WinampPlaylistWindow.swift` into main file + extension files (e.g., `WinampMainWindow+Helpers.swift`, `WinampPlaylistWindow+Menus.swift`, `PlaylistWindowActions.swift`) to reduce per-file complexity. This was **subsequently corrected** for `WinampPlaylistWindow` in Wave 1, and for `WinampMainWindow` in PR #54 (T3 MainWindow Layer Decomposition).

**Why this is an anti-pattern** (not just tactical debt):
1. **Forces access widening**: Properties that should be `private` must become `internal` so the extension file can reach them
2. **No SwiftUI recomposition boundaries**: Extensions share the parent view's `body` evaluation scope, so changes to any state invalidate the entire view
3. **No real isolation**: Extensions have full access to all properties — they move code but do not reduce coupling

```swift
// ❌ ANTI-PATTERN: Extensions in separate files widen access and share body scope
// File: WinampPlaylistWindow+Menus.swift (REMOVED in Wave 1)
// File: WinampMainWindow+Helpers.swift (REMOVED in PR #54)
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
@MainActor @Observable
final class PlaylistWindowInteractionState {
    var isEditing = false
    var selectionAnchor: Int?
    // ... focused, testable state
}

// 2. Child views declare only the dependencies they need
struct PlaylistHeaderView: View {
    let skinManager: SkinManager
    let interactionState: PlaylistWindowInteractionState

    var body: some View {
        // Self-contained: only re-evaluates when its inputs change
    }
}
```

**Why the correct pattern is better**:
- `private` stays `private` — no access widening
- Each child view is an independent SwiftUI recomposition boundary
- Explicit dependency lists make data flow visible and testable
- `@Observable` interaction state classes are unit-testable without views

**Current status** (all RESOLVED):
- `WinampPlaylistWindow+Menus.swift` -- **REMOVED** (replaced by child view structs in Wave 1; see `tasks/playlistwindow-layer-decomposition/research.md`)
- `PlaylistWindowActions.swift` -- **RETAINED** (318 lines; handles NEW/LOAD/SAVE list operations as standalone action methods)
- `WinampMainWindow+Helpers.swift` -- **REMOVED** (replaced by child layer structs in PR #54 T3 MainWindow Layer Decomposition; see `tasks/mainwindow-layer-decomposition/`)
- `WinampMainWindow.swift` moved from `MacAmpApp/Views/WinampMainWindow.swift` to `MacAmpApp/Views/MainWindow/WinampMainWindow.swift` with 10 files in the `MainWindow/` directory

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

### Common Extensions

```swift
// Safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// Clamping values
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// Async main actor running
extension Task where Failure == Never, Success == Void {
    @MainActor
    static func onMain(_ operation: @MainActor @escaping () async -> Void) {
        Task { @MainActor in
            await operation()
        }
    }
}
```

### Debug Helpers

```swift
// Performance timing
func measure<T>(_ label: String, operation: () throws -> T) rethrows -> T {
    let start = CFAbsoluteTimeGetCurrent()
    defer {
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        print("⏱ \(label): \(elapsed * 1000)ms")
    }
    return try operation()
}

// State debugging
extension View {
    func debugPrint(_ value: Any) -> some View {
        #if DEBUG
        print("🔍 \(value)")
        #endif
        return self
    }
}
```

### SwiftUI Modifiers

```swift
// Conditional modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// Usage
Text("Hello")
    .if(isLarge) { $0.font(.largeTitle) }
```

---

## Conclusion

These patterns represent the collective wisdom gained from building MacAmp. They emphasize:
- **Safety**: Prevent crashes through optional handling and error recovery
- **Performance**: Efficient audio processing and UI updates
- **Maintainability**: Clear separation of concerns and testability
- **Modernization**: Embrace Swift 6 features while maintaining stability

When implementing new features, prefer these established patterns. When you discover new patterns, document them here for the team.

---

*Document Version: 2.2.0 | Last Updated: 2026-09-25*
