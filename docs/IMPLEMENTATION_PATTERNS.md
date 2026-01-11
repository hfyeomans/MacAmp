# MacAmp Implementation Patterns

**Version:** 1.2.0
**Date:** 2026-01-11
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
   - [Window Focus State Tracking](#pattern-window-focus-state-tracking)
   - [Action-Based Bridge Pattern](#pattern-action-based-bridge-pattern) **(New - Swift 6)**
3. [UI Component Patterns](#ui-component-patterns)
   - [Sprite-Based Button Component](#pattern-sprite-based-button-component)
   - [Absolute Positioning Extension](#pattern-absolute-positioning-extension)
   - [Multi-State Slider](#pattern-multi-state-slider)
   - [VIDEO.bmp Chrome Composition](#pattern-videobmp-chrome-composition)
   - [GEN.bmp Chrome & Two-Piece Sprites](#pattern-genbmp-chrome--two-piece-sprites)
   - [Video Playback Embedding](#pattern-video-playback-embedding)
4. [Audio Processing Patterns](#audio-processing-patterns)
   - [Safe Audio Buffer Processing](#pattern-safe-audio-buffer-processing)
   - [Thread-Safe Audio State](#pattern-thread-safe-audio-state)
   - [nonisolated(unsafe) Deinit Safety](#pattern-nonisolatedunsafe-deinit-safety-swift-6) **(New - Swift 6)**
   - [Unmanaged Pointer for Core Audio Callbacks](#pattern-unmanaged-pointer-for-core-audio-callbacks-swift-6) **(New - Swift 6)**
5. [Async/Await Patterns](#asyncawait-patterns)
   - [Async Stream Events](#pattern-async-stream-events)
   - [Cancellable Tasks](#pattern-cancellable-tasks)
   - [Background I/O Fire-and-Forget](#pattern-background-io-fire-and-forget-swift-6) **(New - Swift 6)**
   - [Callback Synchronization for Cross-Component Communication](#pattern-callback-synchronization-for-cross-component-communication) **(New - Swift 6)**
6. [Error Handling Patterns](#error-handling-patterns)
7. [Testing Patterns](#testing-patterns)
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

**Real usage**: `PlaybackCoordinator.swift` for `displayTitle`, `canUseEQ`

### Pattern: Computed Forwarding for API Compatibility

**When to use**: Maintaining backwards-compatible API surface after extracting functionality to sub-components

**Swift 6 Relevance**: Essential for incremental refactoring while preserving existing view bindings

**Implementation**:
```swift
// File: MacAmpApp/Audio/AudioPlayer.swift:86-126
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

**Real usage**: `AudioPlayer.swift` maintains API compatibility after extracting `PlaylistController`, `EQPresetStore`, `VideoPlaybackController`, and `VisualizerPipeline`

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

// File: MacAmpApp/Audio/AudioPlayer.swift:1021-1042
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

**Real usage**: All buttons in `WinampMainWindow.swift`, `WinampEqualizerWindow.swift`

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
// File: MacAmpApp/Views/WinampMainWindow.swift
SimpleSpriteImage(
    source: .legacy("MAIN_PLAY_BUTTON"),
    action: .button(onClick: { playbackCoordinator.play() })
)
.at(x: 39, y: 88)  // Exact Winamp coordinates

// Time display positioning
TimeDisplay()
    .at(x: 39, y: 26)

// Visualizer positioning
VisualizerView()
    .at(x: 24, y: 43)
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

**When to use**: Embedding video playback in SwiftUI views with proper lifecycle

**Implementation**:
```swift
// File: MacAmpApp/Views/Components/AVPlayerViewRepresentable.swift
// Purpose: Bridge AVPlayerView (AppKit) into SwiftUI with proper cleanup
// Context: Used by VideoWindow for video file playback

struct AVPlayerViewRepresentable: NSViewRepresentable {
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = nil  // Start with no player
        playerView.controlsStyle = .floating
        playerView.videoGravity = .resizeAspect
        playerView.showsFullScreenToggleButton = true
        playerView.showsSharingServiceButton = false

        return playerView
    }

    func updateNSView(_ playerView: AVPlayerView, context: Context) {
        // Media type switching logic
        switch playbackCoordinator.currentMediaType {
        case .video:
            // Attach video player if not already attached
            if playerView.player !== playbackCoordinator.videoPlayer {
                playerView.player = playbackCoordinator.videoPlayer
            }
        case .audio, .none:
            // Detach player for audio files
            if playerView.player != nil {
                playerView.player = nil
            }
        }

        // Update control visibility based on playback state
        playerView.controlsStyle = playbackCoordinator.isPlaying ? .floating : .inline
    }

    static func dismantleNSView(_ playerView: AVPlayerView, coordinator: ()) {
        // CRITICAL: Clean up player reference to prevent retain cycles
        playerView.player = nil
    }
}

// Usage in VideoWindow
struct VideoContentView: View {
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator

    var body: some View {
        Group {
            if playbackCoordinator.currentMediaType == .video {
                // Video playback
                AVPlayerViewRepresentable()
                    .background(Color.black)
            } else {
                // Audio visualization or placeholder
                VisualizerView()
                    .background(backgroundGradient)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Media type detection
extension PlaybackCoordinator {
    enum MediaType {
        case audio
        case video
        case none
    }

    var currentMediaType: MediaType {
        guard let url = currentTrack?.url else { return .none }

        let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv"]
        let audioExtensions = ["mp3", "flac", "wav", "m4a", "ogg"]

        let ext = url.pathExtension.lowercased()

        if videoExtensions.contains(ext) {
            return .video
        } else if audioExtensions.contains(ext) {
            return .audio
        } else {
            // Try to detect from AVAsset tracks
            let asset = AVAsset(url: url)
            let hasVideo = asset.tracks(withMediaType: .video).count > 0
            return hasVideo ? .video : .audio
        }
    }

    // Separate players for audio and video
    var videoPlayer: AVPlayer? {
        // Only return player if playing video
        currentMediaType == .video ? avPlayer : nil
    }
}
```

**Real usage**: `VideoWindow.swift`, `AVPlayerViewRepresentable.swift`

**Lifecycle management**:
1. **makeNSView**: Create player view without player attached
2. **updateNSView**: Attach/detach player based on media type
3. **dismantleNSView**: MUST clear player reference to prevent leaks

**Format support**:
```swift
// Video formats (use AVPlayer)
let videoFormats = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]

// Audio formats (use AVAudioEngine for local, AVPlayer for streams)
let audioFormats = ["mp3", "flac", "wav", "m4a", "ogg", "aac"]

// Stream detection
let isStream = url.scheme?.hasPrefix("http") == true
```

**Pitfalls**:
- Must clear player reference in dismantleNSView to prevent memory leaks
- Don't create new AVPlayer instances on every update
- Check media type before attaching player
- AVPlayer doesn't support all audio features (EQ, visualization)
- Some video files may only have audio tracks - detect properly
- Controls visibility should reflect playback state

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

**Real usage**: `AudioPlayer.swift` visualization processing

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
Task.detached {
    let spectrum = processFFT(buffer)
    await audioState.updateSpectrum(spectrum)
}

// Usage from UI (main thread)
Task { @MainActor in
    let spectrum = await audioState.getSpectrum()
    spectrumView.update(spectrum)
}
```

**Real usage**: Visualization data flow in `AudioPlayer.swift`

### Pattern: nonisolated(unsafe) Deinit Safety (Swift 6)

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

### Pattern: Unmanaged Pointer for Core Audio Callbacks (Swift 6)

**When to use**: Passing Swift objects to C-style callback contexts (e.g., AVAudioEngine taps)

**Swift 6 Relevance**: Bridges Swift actor isolation to non-actor C callbacks

**Implementation**:
```swift
// File: MacAmpApp/Audio/VisualizerPipeline.swift:178-184, 265-274, 518-522
// Purpose: Pass VisualizerPipeline reference through Core Audio tap callback
// Context: Audio tap runs on realtime audio thread, not @MainActor

/// Context passed to audio tap (must be Sendable for Swift 6)
private struct VisualizerTapContext: @unchecked Sendable {
    let pipelinePointer: UnsafeMutableRawPointer
}

@MainActor
@Observable
final class VisualizerPipeline {
    @ObservationIgnored nonisolated(unsafe) private var tapInstalled = false
    @ObservationIgnored nonisolated(unsafe) private weak var mixerNode: AVAudioMixerNode?

    /// Install visualizer tap on the given mixer node
    func installTap(on mixer: AVAudioMixerNode) {
        guard !tapInstalled else { return }

        mixerNode = mixer

        // Create context with Unmanaged pointer to self
        // passUnretained: Does NOT increment reference count
        // CRITICAL: self must outlive the tap - caller must call removeTap() before releasing
        let context = VisualizerTapContext(
            pipelinePointer: Unmanaged.passUnretained(self).toOpaque()
        )

        let handler = Self.makeTapHandler(context: context, scratch: VisualizerScratchBuffers())

        mixer.installTap(onBus: 0, bufferSize: 2048, format: nil, block: handler)
        tapInstalled = true
    }

    /// Remove visualizer tap if installed
    /// Nonisolated to allow calling from deinit (AVAudioMixerNode.removeTap is thread-safe)
    nonisolated func removeTap() {
        guard tapInstalled, let mixer = mixerNode else { return }
        mixer.removeTap(onBus: 0)
        tapInstalled = false
        mixerNode = nil
    }

    /// Build the tap handler in a nonisolated context
    /// AVAudioEngine calls this on its realtime audio queue
    private nonisolated static func makeTapHandler(
        context: VisualizerTapContext,
        scratch: VisualizerScratchBuffers
    ) -> @Sendable (AVAudioPCMBuffer, AVAudioTime?) -> Void {
        { buffer, _ in
            // ... process buffer ...

            // Dispatch to MainActor to update pipeline state
            Task { @MainActor [context, data] in
                // Convert opaque pointer back to VisualizerPipeline
                let pipeline = Unmanaged<VisualizerPipeline>.fromOpaque(
                    context.pipelinePointer
                ).takeUnretainedValue()

                pipeline.updateLevels(with: data, useSpectrum: pipeline.useSpectrum)
            }
        }
    }
}

// In AudioPlayer.deinit - ensure tap is removed before pipeline is deallocated
deinit {
    // CRITICAL: Remove tap before self deallocates to prevent use-after-free
    visualizerPipeline.removeTap()
}
```

**Key elements**:
1. **Unmanaged.passUnretained**: Creates raw pointer without retaining (caller manages lifetime)
2. **@unchecked Sendable context**: Context struct holds raw pointer, marked Sendable for crossing actor boundary
3. **nonisolated removeTap()**: Can be called from deinit to safely remove tap
4. **Static tap handler**: Uses `nonisolated static func` to avoid capturing self directly
5. **Task dispatch**: Hops back to MainActor after processing

**Lifetime contract**:
```
┌─────────────────────────────────────────────────────────────────┐
│                     LIFETIME CONTRACT                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. VisualizerPipeline created                                   │
│  2. installTap() called - tap holds Unmanaged pointer            │
│  3. Tap callback runs repeatedly on audio thread                 │
│  4. removeTap() MUST be called before VisualizerPipeline release │
│  5. VisualizerPipeline deallocated                               │
│                                                                  │
│  If step 4 is skipped: USE-AFTER-FREE crash in tap callback      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Real usage**: `VisualizerPipeline.swift` for audio tap callback

**Pitfalls**:
- **CRITICAL**: removeTap() must be called before releasing the object
- Don't use `passRetained` unless you explicitly call `release()` later
- Verify lifetime management in code review - memory bugs are subtle
- Consider logging when tap is installed/removed for debugging
- Test with Thread Sanitizer to catch use-after-free issues

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

### Pattern: Background I/O Fire-and-Forget (Swift 6)

**When to use**: File I/O operations that don't need immediate confirmation of success

**Swift 6 Relevance**: Uses `Task.detached` with state snapshot for `@Sendable` compliance

**Implementation**:
```swift
// File: MacAmpApp/Audio/EQPresetStore.swift:130-146
// Purpose: Perform file writes off main thread without blocking UI
// Context: Per-track preset persistence - writes happen on every EQ change

@MainActor
@Observable
final class EQPresetStore {
    @ObservationIgnored var perTrackPresets: [String: EqfPreset] = [:]

    /// Save per-track presets to JSON file (fire-and-forget)
    /// State is captured before dispatch to prevent race conditions
    func savePerTrackPresets() {
        guard let url = presetsFileURL() else { return }

        // CRITICAL: Capture current state BEFORE dispatching
        // This ensures we save the state at call time, not when the task runs
        let presetsToSave = perTrackPresets

        // Perform file I/O off main thread (fire-and-forget with error logging)
        Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(presetsToSave)
                try data.write(to: url, options: .atomic)
                AppLog.debug(.audio, "Saved \(presetsToSave.count) per-track presets")
            } catch {
                AppLog.warn(.audio, "Failed to save per-track presets: \(error)")
            }
        }
    }
}
```

**Key elements**:
1. **State snapshot**: Capture state before `Task.detached` to avoid Sendable violations
2. **Fire-and-forget**: No `await` - caller continues immediately
3. **Error logging**: Use `AppLog` for errors since we can't propagate them
4. **Priority**: Use `.utility` for non-urgent I/O, `.userInitiated` for user-triggered saves

**When to use**:
- Periodic auto-saves (preference changes, EQ adjustments)
- Non-critical persistence (cache files, recent items)
- High-frequency updates where blocking would cause UI lag

**When NOT to use**:
- Operations where success confirmation is needed (use `await Task.detached { }.value`)
- Writes that must complete before app terminates (use synchronous I/O or `await`)
- Operations with complex error recovery requirements

**Real usage**: `EQPresetStore.savePerTrackPresets()`, per-track preset auto-save

**Pitfalls**:
- Always capture state BEFORE the `Task.detached` block
- The captured type must be `Sendable` (value types or explicitly marked)
- Fire-and-forget loses error propagation - ensure adequate logging
- Multiple rapid calls may result in out-of-order writes (use `.atomic` option)

### Pattern: Callback Synchronization for Cross-Component Communication

**When to use**: Coordinating state updates between extracted components without tight coupling

**Swift 6 Relevance**: Closures must be marked `@Sendable` when crossing actor boundaries

**Implementation**:
```swift
// File: MacAmpApp/Audio/VideoPlaybackController.swift:52-59
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
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                // ... compute time values ...

                // Notify AudioPlayer to sync its UI-bound properties
                self.onTimeUpdate?(seconds, dur, self.progress)
            }
        }
    }
}

// File: MacAmpApp/Audio/AudioPlayer.swift:141-153
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

**Real usage**: `VideoPlaybackController.swift` for `onPlaybackEnded`, `onTimeUpdate` callbacks

**Pitfalls**:
- Always use `[weak self]` in callbacks to prevent retain cycles
- Mark closures `@Sendable` if they cross actor boundaries
- Don't pass non-Sendable types through callbacks in Swift 6
- Consider using `AsyncStream` for high-frequency events

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

---

## Testing Patterns

### Test Plan Quick Reference

**Test target**: `MacAmpTests` (`Tests/MacAmpTests`)
**Test plan**: `MacAmpApp.xcodeproj/xcshareddata/xctestplans/MacAmpApp.xctestplan`

**Configurations**:
- Core: AppSettingsTests, EQCodecTests, SpriteResolverTests
- Concurrency: AudioPlayerStateTests, DockingControllerTests, PlaylistNavigationTests, SkinManagerTests
- All: full MacAmpTests target

**CLI**:
```bash
xcodebuild test -project MacAmpApp.xcodeproj -scheme MacAmpApp -destination 'platform=macOS' -testPlan MacAmpApp -only-test-configuration Core -derivedDataPath build/DerivedDataTests
```

Swap `Core` for `Concurrency` or `All` as needed.

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

**When to use**: Testing async operations

**Implementation**:
```swift
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

*Document Version: 1.2.0 | Last Updated: 2026-01-11 | Lines: 2,327*
