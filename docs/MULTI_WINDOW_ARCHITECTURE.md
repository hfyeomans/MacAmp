# Modern SwiftUI Multi-Window Architecture for MacAmp (macOS 15+/26+)

## Executive Summary

This document provides comprehensive research and implementation guidance for creating truly independent auxiliary windows (Video and Milkdrop visualizers) in MacAmp while maintaining shared state across windows, persistent positioning, and proper Swift 6 concurrency patterns.

**Recommended Approach**: Multiple `WindowGroup` instances with unique IDs in the App scene, combined with dedicated per-window `@Observable` state models and a centralized `WindowStateStore` for persistence.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Window Scene Patterns](#window-scene-patterns)
3. [State Management Strategy](#state-management-strategy)
4. [Code Patterns & Examples](#code-patterns--examples)
5. [Window Positioning & Persistence](#window-positioning--persistence)
6. [Lifecycle Management](#lifecycle-management)
7. [Integration with Existing Infrastructure](#integration-with-existing-infrastructure)
8. [Swift 6 Concurrency Patterns](#swift-6-concurrency-patterns)
9. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
10. [WindowCoordinator Refactoring (2026-02)](#windowcoordinator-refactoring-2026-02)

---

## Architecture Overview

### Current MacAmp Architecture

MacAmp is a pure SwiftUI application for macOS 15+/26+ with the following characteristics:

- **App Entry Point**: `MacAmpApp.swift` - Single `@main` struct with one default `WindowGroup`
- **Scene-Level State**: Long-lived singletons (`SkinManager`, `AudioPlayer`, `DockingController`, `AppSettings`, `PlaybackCoordinator`, `StreamPlayer`) stored as `@State` in the App struct
- **Environment Injection**: All state models injected via `.environment()` modifier for access across all windows
- **Window Management**: 
  - `WindowAccessor.swift` - NSViewRepresentable to capture underlying NSWindow references
  - `WindowSnapManager.swift` - Handles magnetic snapping between docked windows
  - `DockingController.swift` - Manages visibility and layout of panes (Main, Playlist, Equalizer)

### Key Existing Patterns to Leverage

1. **Singleton Pattern for Shared State**
   ```swift
   // In MacAmpApp init()
   let settings = AppSettings.instance()
   _settings = State(initialValue: settings)
   ```
   - AppSettings uses `@Observable @MainActor` with `didSet` UserDefaults persistence
   - Single instance shared across entire app

2. **Window Accessor Pattern**
   - Captures `NSWindow` references for direct manipulation
   - Allows registration with WindowSnapManager
   - Used in UnifiedDockView for window-level configuration

3. **Docking System**
   - `DockingController` tracks visible panes with state persistence
   - WindowSnapManager registers windows and handles snapping
   - 2025-11 update: `WindowCoordinator` asks `WindowSnapManager.clusterKinds(containing:)` for the playlist's cluster before every double-size toggle. The helper builds a `PlaylistDockingContext` (anchor + attachment) so the playlist can follow either the Equalizer or Main window instantly. Magnetic snapping is disabled via `beginProgrammaticAdjustment()` during the frame update and re-enabled afterwards.
   - **2026-02 refactoring**: `WindowCoordinator` was decomposed from a 1,357-line god object into a 223-line Facade + 10 focused types using Composition pattern. Docking-aware resize logic now lives in `WindowResizeController`, pure geometry in `WindowDockingGeometry`, and value types in `WindowDockingTypes`. See [WindowCoordinator Refactoring (2026-02)](#windowcoordinator-refactoring-2026-02) for complete details. Source files: `MacAmpApp/ViewModels/WindowCoordinator.swift`, `MacAmpApp/Windows/WindowResizeController.swift`, `MacAmpApp/Windows/WindowDockingGeometry.swift`.

#### Instant Double-Size Docking Pipeline

1. `AppSettings.isDoubleSizeMode` toggles via CTRL+D / "D" button.
2. `WindowSettingsObserver` detects the change via recursive `withObservationTracking` and fires the `onDoubleSizeChanged` callback.
3. `WindowCoordinator` forwards to `WindowResizeController.resizeMainAndEQWindows()`, which captures the live frames for Main, EQ, and Playlist.
4. `WindowResizeController.makePlaylistDockingContext()` queries `WindowSnapManager.clusterKinds(containing: .playlist)` to discover the current magnetic cluster. If the playlist is touching the EQ or Main window, it derives an attachment enum (`below`, `above`, `left`, `right`) plus a saved anchor using `WindowDockingGeometry` pure functions.
5. Main and EQ windows resize synchronously (no NSAnimation). While `WindowSnapManager` is in programmatic adjustment mode and `WindowFramePersistence` has suppressed writes, the playlist is re-aligned relative to the anchor frame, preserving the Winamp stack.
6. DEBUG logging prints `[DOCKING] source: ...` so QA can immediately see which anchor drove the adjustment.

**Why this matters**: Visualizer windows (or other auxiliary panes) can plug into the same mechanism -- once they register with `WindowSnapManager` via `WindowDelegateWiring`, the resize controller can ask for their cluster membership and keep them glued to whichever window they are attached to. This architecture keeps the classic Winamp feel (instant 100% to 200% snap) while honoring macOS snapping semantics.

**File responsibilities in the docking pipeline** (post-refactoring):

| File | Role |
|------|------|
| `WindowSettingsObserver.swift` | Detects `isDoubleSizeMode` change |
| `WindowResizeController.swift` | Orchestrates resize + docking context |
| `WindowDockingGeometry.swift` | Pure geometry (attachment detection, origin calculation) |
| `WindowDockingTypes.swift` | Value types (`PlaylistDockingContext`, `PlaylistAttachmentSnapshot`) |
| `WindowFramePersistence.swift` | Suppresses persistence during programmatic moves |

---

## Window Scene Patterns

### Pattern 1: Multiple WindowGroup with ID (Recommended for MacAmp)

**When to use**: Independent windows that can exist in multiple instances but you only need one per type (e.g., one Video window, one Milkdrop window at a time).

```swift
@main
struct MacAmpApp: App {
    // Shared state (singletons)
    @State private var skinManager: SkinManager
    @State private var audioPlayer: AudioPlayer
    @State private var settings: AppSettings
    
    // Per-window state models
    @State private var videoVisualizerState = VideoVisualizerState()
    @State private var milkdropVisualizerState = MilkdropVisualizerState()
    @State private var windowStateStore = WindowStateStore()

    var body: some Scene {
        // Main window (default)
        WindowGroup {
            UnifiedDockView()
                .environment(skinManager)
                .environment(audioPlayer)
                .environment(settings)
                .environment(videoVisualizerState)
                .environment(milkdropVisualizerState)
                .environment(windowStateStore)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        // Video Visualizer Window
        WindowGroup(id: "videoVisualizer") {
            VideoVisualizerView()
                .environment(audioPlayer)
                .environment(settings)
                .environment(videoVisualizerState)
                .environment(windowStateStore)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultWindowPlacement { geometry in
            let screenFrame = NSScreen.main?.visibleFrame ?? .zero
            return WindowPlacement(
                size: CGSize(width: 512, height: 512),
                normalizedPosition: CGPoint(x: 0.65, y: 0.2)
            )
        }

        // Milkdrop Visualizer Window
        WindowGroup(id: "milkdropVisualizer") {
            MilkdropVisualizerView()
                .environment(audioPlayer)
                .environment(settings)
                .environment(milkdropVisualizerState)
                .environment(windowStateStore)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultWindowPlacement { geometry in
            let screenFrame = NSScreen.main?.visibleFrame ?? .zero
            return WindowPlacement(
                size: CGSize(width: 512, height: 512),
                normalizedPosition: CGPoint(x: 0.65, y: 0.6)
            )
        }

        // Preferences Window (already exists)
        WindowGroup("Preferences", id: "preferences") {
            PreferencesView()
                .environment(settings)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Global Commands
        .commands {
            AppCommands(...)
            SkinsCommands(...)
            VisualizerCommands() // New: Add visualizer window controls
        }
    }
}
```

**Advantages**:
- Pure SwiftUI - no NSWindowController overhead
- Automatic scene lifecycle management
- Environment injection works seamlessly
- Global commands apply to all windows
- State isolation prevents bugs

**Disadvantages**:
- Maximum one window per ID (but could be extended with value-based WindowGroup)
- Less direct NSAppKit control (but WindowAccessor provides escape hatch)

### Pattern 2: Window vs WindowGroup Comparison

| Feature | Window | WindowGroup | WindowGroup(id:) |
|---------|--------|-------------|------------------|
| Single instance | Yes | No | Yes (one per ID) |
| Multiple identical windows | No | Yes | No |
| Dynamic content | No | Yes with values | Only one at a time |
| State isolation | N/A | Per instance | Single shared |
| Use case | Main/unique window | Document/editor windows | Fixed auxiliary windows |

For MacAmp: **Use WindowGroup(id:)** for auxiliary windows.

---

## State Management Strategy

### The Three Levels of State

```
┌─────────────────────────────────────────────────────────┐
│  Level 1: Shared Global State (SingletonStyle)          │
│  ├─ AudioPlayer (playback status)                       │
│  ├─ AppSettings (user preferences)                      │
│  ├─ SkinManager (current skin, sprite cache)            │
│  └─ PlaybackCoordinator (synchronized playback)         │
│  Persistence: UserDefaults, file system                 │
│  Access: @Environment injection to all windows          │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Level 2: Per-Window Shared State (@Observable models)  │
│  ├─ VideoVisualizerState (color mode, refresh rate)    │
│  ├─ MilkdropVisualizerState (shader params, presets)   │
│  └─ WindowStateStore (frame positions, sizes)          │
│  Persistence: UserDefaults with window kind suffix      │
│  Access: @Environment injection per window              │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Level 3: View-Local State                              │
│  ├─ Transient UI state (animations, selections)         │
│  └─ Temporary calculations                              │
│  Persistence: None (ephemeral)                          │
│  Access: @State within view                             │
└─────────────────────────────────────────────────────────┘
```

### Critical: Shared Audio State Pattern

**Problem**: AudioPlayer publishes changes → all views observing it re-evaluate their body → expensive computations run repeatedly in all windows.

**Solution**: Level 2 state models extract **what to display**, not **how to display it**:

```swift
// Level 1: Global Audio State (shared across all windows)
@Observable
@MainActor
final class AudioPlayer {
    var isPlaying: Bool = false
    var currentTime: Double = 0.0
    var currentFrequencies: [Float] = [] // Updated at 60Hz
}

// Level 2: Per-Window Display State (visualizer-specific)
@Observable
@MainActor
final class VideoVisualizerState {
    var colorMode: ColorMode = .spectrum
    var refreshRate: Double = 60.0
    var smoothing: Double = 0.8
    
    // Computed from AudioPlayer's data, cached per-frame
    var cachedWaveform: [Float]?
    var lastUpdateTime: Double = 0
}

// In VideoVisualizerView:
struct VideoVisualizerView: View {
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(VideoVisualizerState.self) var visState
    
    var body: some View {
        MetalCanvasView(
            frequencies: audioPlayer.currentFrequencies,
            colorMode: visState.colorMode
        )
        // Body only invalidates when visState.colorMode changes
        // NOT when audioPlayer publishes every 16ms
        .onChange(of: audioPlayer.currentFrequencies) { _, newFreqs in
            visState.cachedWaveform = newFreqs
        }
    }
}
```

---

## Code Patterns & Examples

### Pattern A: Per-Window State Model (VideoVisualizerState)

```swift
import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class VideoVisualizerState: Sendable {
    enum ColorMode: String, Codable {
        case spectrum = "spectrum"
        case fire = "fire"
        case ice = "ice"
        case rainbow = "rainbow"
    }

    var colorMode: ColorMode = .spectrum {
        didSet {
            UserDefaults.standard.set(
                colorMode.rawValue,
                forKey: "videoVisualizer.colorMode"
            )
        }
    }

    var refreshRate: Double = 60.0 {
        didSet {
            UserDefaults.standard.set(
                refreshRate,
                forKey: "videoVisualizer.refreshRate"
            )
        }
    }

    var smoothing: Double = 0.8 {
        didSet {
            UserDefaults.standard.set(
                smoothing,
                forKey: "videoVisualizer.smoothing"
            )
        }
    }

    var isFullscreen: Bool = false

    init() {
        // Load persisted settings
        if let savedMode = UserDefaults.standard.string(forKey: "videoVisualizer.colorMode"),
           let mode = ColorMode(rawValue: savedMode) {
            self.colorMode = mode
        }
        
        let rate = UserDefaults.standard.double(forKey: "videoVisualizer.refreshRate")
        if rate > 0 {
            self.refreshRate = rate
        }
        
        let smooth = UserDefaults.standard.double(forKey: "videoVisualizer.smoothing")
        if smooth > 0 {
            self.smoothing = smooth
        }
    }
}
```

### Pattern B: Window State Store (Persistence & Registration)

```swift
import Foundation
import SwiftUI
import AppKit
import Observation

enum WindowKind: String, Codable {
    case main = "main"
    case videoVisualizer = "visualizer.video"
    case milkdropVisualizer = "visualizer.milkdrop"
    case playlist = "playlist"
    case equalizer = "equalizer"
}

struct WindowFrame: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    
    init(from nsFrame: NSRect) {
        self.x = nsFrame.origin.x
        self.y = nsFrame.origin.y
        self.width = nsFrame.size.width
        self.height = nsFrame.size.height
    }
    
    func toNSRect() -> NSRect {
        NSRect(x: x, y: y, width: width, height: height)
    }
}

@Observable
@MainActor
final class WindowStateStore {
    private let defaults = UserDefaults.standard
    private var trackedWindows: [WindowKind: WeakBox<NSWindow>] = [:]
    private var frameRestoration: [WindowKind: WindowFrame] = [:]
    
    init() {
        loadSavedFrames()
    }
    
    // MARK: - Frame Persistence
    
    func restoreFrame(for window: NSWindow, kind: WindowKind) {
        guard let saved = frameRestoration[kind] else {
            // No saved frame - use defaults
            return
        }
        
        // Set frame on main thread (WindowAccessor callback is already @MainActor)
        let rect = saved.toNSRect()
        window.setFrame(rect, display: true)
    }
    
    func persistFrame(_ frame: NSRect, for kind: WindowKind) {
        let windowFrame = WindowFrame(from: frame)
        frameRestoration[kind] = windowFrame
        
        // Persist to disk (debounced)
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            do {
                let data = try JSONEncoder().encode(windowFrame)
                self.defaults.set(data, forKey: "windowFrame.\(kind.rawValue)")
            } catch {
                console.error("Failed to persist window frame: \(error)")
            }
        }
    }
    
    private func loadSavedFrames() {
        for kind in [WindowKind.videoVisualizer, .milkdropVisualizer] {
            guard let data = defaults.data(forKey: "windowFrame.\(kind.rawValue)") else {
                continue
            }
            do {
                let frame = try JSONDecoder().decode(WindowFrame.self, from: data)
                frameRestoration[kind] = frame
            } catch {
                console.error("Failed to load frame for \(kind): \(error)")
            }
        }
    }
    
    // MARK: - Window Registration
    
    func register(window: NSWindow, kind: WindowKind) {
        trackedWindows[kind] = WeakBox(window)
        restoreFrame(for: window, kind: kind)
    }
    
    func window(for kind: WindowKind) -> NSWindow? {
        trackedWindows[kind]?.value
    }
}

// Weak reference wrapper for storing NSWindow without circular refs
private class WeakBox<T: AnyObject> {
    weak var value: T?
    
    init(_ value: T) {
        self.value = value
    }
}
```

### Pattern C: VideoVisualizerView with Window Management

```swift
import SwiftUI
import AppKit

struct VideoVisualizerView: View {
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(AppSettings.self) var settings
    @Environment(VideoVisualizerState.self) var visState
    @Environment(WindowStateStore.self) var windowStore
    @Environment(DockingController.self) var docking
    @Environment(\.openWindow) var openWindow
    
    @State private var windowID = UUID()
    
    var body: some View {
        ZStack {
            // Metal/Canvas-based visualization
            MetalVisualizerCanvas(
                frequencies: audioPlayer.currentFrequencies,
                colorMode: visState.colorMode,
                smoothing: visState.smoothing
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            
            // Overlay controls
            VStack(alignment: .trailing, spacing: 12) {
                HStack {
                    // Color mode picker
                    Menu {
                        ForEach(VideoVisualizerState.ColorMode.allCases, id: \.rawValue) { mode in
                            Button(mode.rawValue.capitalized) {
                                visState.colorMode = mode
                            }
                        }
                    } label: {
                        Label("Color", systemImage: "paintpalette")
                    }
                    .menuStyle(.button)
                    
                    // Fullscreen toggle
                    Button(action: { visState.isFullscreen.toggle() }) {
                        Image(systemName: visState.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    }
                    .help("Toggle fullscreen")
                }
                .padding(12)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding(16)
        }
        .background(WindowAccessor { window in
            // Register this window with state store
            guard window.identifier?.rawValue != windowID.uuidString else { return }
            window.identifier = NSUserInterfaceItemIdentifier(windowID.uuidString)
            
            // Restore saved position
            windowStore.register(window: window, kind: .videoVisualizer)
            
            // Register with snapping system
            docking.windowSnapManager.register(window: window, kind: .visualizerVideo)
            
            // Set up persistence listener
            Task { @MainActor in
                // Listen for window move/resize via notification
                NotificationCenter.default.publisher(
                    for: NSWindow.didMoveNotification,
                    object: window
                )
                .merge(with: NotificationCenter.default.publisher(
                    for: NSWindow.didResizeNotification,
                    object: window
                ))
                .debounce(for: 0.5, scheduler: DispatchQueue.main)
                .sink { _ in
                    windowStore.persistFrame(window.frame, for: .videoVisualizer)
                }
                .store(in: &subscriptions)
            }
        })
        .onAppear {
            // Ensure docking controller knows about this window type
            if !docking.hasVisualizers {
                docking.addVisualizerSupport()
            }
        }
    }
    
    @State private var subscriptions: Set<AnyCancellable> = []
}
```

### Pattern D: Opening Windows (Commands/Shortcuts)

```swift
struct VisualizerCommands: Commands {
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(\.openWindow) var openWindow
    
    var body: some Commands {
        CommandMenu("Visualizers") {
            Button("Show Video Visualizer") {
                openWindow(id: "videoVisualizer")
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            .disabled(audioPlayer.currentTrack == nil)
            
            Button("Show Milkdrop Visualizer") {
                openWindow(id: "milkdropVisualizer")
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(audioPlayer.currentTrack == nil)
        }
    }
}
```

---

## Window Positioning & Persistence

### Default Positioning Strategy

```swift
WindowGroup(id: "videoVisualizer") {
    VideoVisualizerView()
        // ... environment injection ...
}
.defaultWindowPlacement { geometry in
    // geometry.defaultDisplay - the main or focused screen
    let screens = NSScreen.screens
    let mainScreen = screens.first(where: { $0.frame.contains(NSCursor.mouseLocation) })
        ?? screens.first
        ?? NSScreen.main!
    
    let screenFrame = mainScreen.visibleFrame
    let windowSize = CGSize(width: 512, height: 512)
    
    // Position offset from main window or centered on secondary display
    let origin = CGPoint(
        x: screenFrame.midX - windowSize.width / 2,
        y: screenFrame.midY - windowSize.height / 2
    )
    
    return WindowPlacement(size: windowSize)
}
```

### Multi-Monitor Support

```swift
extension WindowStateStore {
    /// Validate saved frame is on an active screen, adjust if needed
    func validateFrame(_ frame: WindowFrame, for kind: WindowKind) -> NSRect {
        let rect = frame.toNSRect()
        let screens = NSScreen.screens
        
        // Check if frame overlaps any screen
        if screens.contains(where: { $0.frame.intersects(rect) }) {
            return rect // Frame is valid
        }
        
        // Frame is off-screen - reset to primary screen
        guard let primaryScreen = screens.first else {
            return NSRect(x: 100, y: 100, width: 512, height: 512)
        }
        
        let screenFrame = primaryScreen.visibleFrame
        return NSRect(
            x: screenFrame.midX - 256,
            y: screenFrame.midY - 256,
            width: 512,
            height: 512
        )
    }
}
```

---

## Lifecycle Management

### Window Open/Close Events

```swift
@Observable
@MainActor
final class WindowLifecycleManager {
    var openWindows: Set<WindowKind> = []
    
    @ObservationIgnored
    private var subscribers: [NSObjectProtocol] = []
    
    func observe(window: NSWindow, for kind: WindowKind) {
        openWindows.insert(kind)
        
        // Track window close
        let closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.openWindows.remove(kind)
            // Perform cleanup if needed
        }
        
        subscribers.append(closeObserver)
    }
    
    deinit {
        for observer in subscribers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
```

### Cleanup on Window Close

```swift
struct VideoVisualizerView: View {
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(VideoVisualizerState.self) var visState
    @Environment(WindowStateStore.self) var windowStore
    
    @State private var displayLink: CVDisplayLink?
    
    var body: some View {
        // ... visualization content ...
            .onAppear {
                setupDisplayLink()
            }
            .onDisappear {
                cleanupDisplayLink()
                // Metal resources cleaned up automatically
            }
    }
    
    private func setupDisplayLink() {
        // Set up high-frequency rendering
        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplay(0, &displayLink)
        self.displayLink = displayLink
        
        CVDisplayLinkSetOutputCallback(displayLink, { _, _, _, _, _, context in
            // Render callback
            return kCVReturnSuccess
        }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        CVDisplayLinkStart(displayLink!)
    }
    
    private func cleanupDisplayLink() {
        guard let link = displayLink else { return }
        CVDisplayLinkStop(link)
        self.displayLink = nil
    }
}
```

---

## Integration with Existing Infrastructure

### Extending DockingController

MacAmp's `DockingController` currently tracks main/playlist/equalizer panes. Extend it for visualizers:

```swift
// In DockingController.swift

enum WindowKind: Hashable {
    case main
    case playlist
    case equalizer
    case videoVisualizer
    case milkdropVisualizer
}

@MainActor
final class DockingController {
    private var trackedWindows: [WindowKind: WeakReference<NSWindow>] = [:]
    
    var windowSnapManager: WindowSnapManager = WindowSnapManager.shared
    
    func register(window: NSWindow, kind: WindowKind) {
        trackedWindows[kind] = WeakReference(window)
        windowSnapManager.register(window: window, kind: kind)
    }
    
    var hasVisualizerWindows: Bool {
        trackedWindows[.videoVisualizer] != nil || 
        trackedWindows[.milkdropVisualizer] != nil
    }
}
```

### WindowSnapManager Enhancement

```swift
extension WindowSnapManager {
    func register(window: NSWindow, kind: WindowKind) {
        window.tabbingMode = .disallowed
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        
        windows[kind] = TrackedWindow(window: window, kind: kind)
        window.delegate = self
    }
}
```

---

## Swift 6 Concurrency Patterns

### Safe State Updates from Async Contexts

```swift
// Pattern: Use Task { @MainActor in ... } for state mutations
struct VideoVisualizerView: View {
    @Environment(WindowStateStore.self) var windowStore
    @Environment(VideoVisualizerState.self) var visState
    
    var body: some View {
        Canvas { context, size in
            // Rendering code
        }
        .onChange(of: someAsyncValue) { _, newValue in
            // Method 1: Direct update (within View body context)
            visState.cachedValue = newValue
            
            // Method 2: From async context
            Task {
                let result = await computeExpensiveValue(newValue)
                await MainActor.run {
                    visState.cachedValue = result
                }
            }
        }
    }
}

// Pattern: @Observable models are @MainActor
@Observable
@MainActor
final class VideoVisualizerState {
    var cachedValue: SomeType = .default {
        didSet {
            // All property observers run on main thread
            persistToUserDefaults()
        }
    }
    
    func updateFromBackground(newValue: SomeType) {
        // This method is @MainActor by inheritance
        self.cachedValue = newValue
    }
}
```

### Safe Concurrent Access to Shared State

```swift
// AudioPlayer is @Observable @MainActor
// Multiple windows reading audioPlayer.currentFrequencies
// All reads/writes are automatically serialized to main thread

struct VideoVisualizerView: View {
    @Environment(AudioPlayer.self) var audioPlayer
    
    var body: some View {
        Canvas { context, size in
            // Safe to read audioPlayer properties here
            // SwiftUI automatically tracks changes
            let freqs = audioPlayer.currentFrequencies
            renderVisualization(freqs, in: context)
        }
        .onChange(of: audioPlayer.currentFrequencies) { _, newFreqs in
            // Also safe - running on main thread
            updateVisualization(newFreqs)
        }
    }
}
```

---

## Common Pitfalls & Solutions

### Pitfall 1: State Shared Between Windows When It Shouldn't Be

**Problem**: Using WindowGroup with @State @Observable models that create new instances per window, but instance sharing causing state sync:

```swift
// WRONG - @Observable instance created once, shared across all windows
@main
struct MacAmpApp: App {
    @State private var videoVisState = VideoVisualizerState() // ❌ Created once
    
    var body: some Scene {
        WindowGroup(id: "videoVisualizer") {
            VideoVisualizerView()
                .environment(videoVisState) // Both windows get same instance
        }
    }
}
```

**Solution**: Each WindowGroup gets its own @State instance:

```swift
// CORRECT - Each WindowGroup has independent @State
@main
struct MacAmpApp: App {
    @State private var videoVisState = VideoVisualizerState()
    @State private var milkdropVisState = MilkdropVisualizerState()
    
    var body: some Scene {
        WindowGroup(id: "videoVisualizer") {
            VideoVisualizerView()
                .environment(videoVisState)
        }
        
        WindowGroup(id: "milkdropVisualizer") {
            MilkdropVisualizerView()
                .environment(milkdropVisState)
        }
    }
}
```

### Pitfall 2: Window Reference Cycles

**Problem**: NSWindow references captured in closures cause memory leaks:

```swift
// WRONG - Strong reference cycle
struct VideoVisualizerView: View {
    var body: some View {
        Color.clear
            .background(WindowAccessor { window in
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: window,
                    queue: .main
                ) { [window] _ in // ❌ Strong reference to window
                    // Process resize
                }
            })
    }
}
```

**Solution**: Use weak references:

```swift
// CORRECT - Weak reference
struct VideoVisualizerView: View {
    var body: some View {
        Color.clear
            .background(WindowAccessor { [weak window = window] window in
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: window,
                    queue: .main
                ) { [weak window] _ in
                    window?.frame = // ...
                }
            })
    }
}
```

### Pitfall 3: Excessive Body Re-evaluations

**Problem**: Per-frame audio data changes trigger visualizer body re-evaluation:

```swift
// WRONG - Body recalculates every 16ms as frequencies change
struct VideoVisualizerView: View {
    @Environment(AudioPlayer.self) var audioPlayer
    
    var body: some View {
        Canvas { context, size in
            let freqs = audioPlayer.currentFrequencies
            // ❌ Canvas recreated every 16ms
            renderVisualization(freqs, context)
        }
    }
}
```

**Solution**: Use Canvas with @Binding or use Metal directly:

```swift
// CORRECT - Metal rendering independent of SwiftUI body
struct VideoVisualizerView: View {
    @Environment(AudioPlayer.self) var audioPlayer
    @State private var metalView: MTKView?
    
    var body: some View {
        MetalVisualizerView(frequencies: audioPlayer.currentFrequencies)
            .onChange(of: audioPlayer.currentFrequencies) { _, freqs in
                // Update Metal texture, not SwiftUI view
                updateMetalRendering(freqs)
            }
    }
}
```

### Pitfall 4: Not Respecting @MainActor

**Problem**: Trying to update @Observable models from background threads:

```swift
// WRONG - Crashes in Swift 6 strict mode
let frequencies = await audioEngine.getFrequencies()
videoVisState.cachedFrequencies = frequencies // ❌ Not on main thread
```

**Solution**: Explicitly hop to main thread:

```swift
// CORRECT
let frequencies = await audioEngine.getFrequencies()
await MainActor.run {
    videoVisState.cachedFrequencies = frequencies
}

// Or use Task with @MainActor
Task { @MainActor in
    videoVisState.cachedFrequencies = frequencies
}
```

---

## WindowCoordinator Refactoring (2026-02)

### Rationale

`WindowCoordinator` had grown to 1,357 lines with 10 orthogonal responsibilities crammed into a single file:

1. Window controller ownership (5 NSWindowController instances)
2. Window-to-kind mapping
3. Frame persistence (save/load/suppress)
4. Show/hide/toggle visibility for all 5 window types
5. Double-size resize with docking-aware playlist/video repositioning
6. Settings observation (always-on-top, double-size, show video, show milkdrop)
7. Delegate multiplexer + focus delegate wiring
8. Pure docking geometry calculations
9. Value types for docking context
10. Layout defaults, initial positioning, and presentation

This "god object" exceeded the SwiftLint `file_length` threshold, made changes risky (any modification could touch unrelated behavior), and was impossible to unit test in isolation. The Oracle (gpt-5.3-codex) pre-review confirmed the decomposition direction and provided critical architectural feedback.

### Architecture Decision: Facade + Composition

**Why Facade + Composition (chosen)**:
- Zero breaking changes: all callers continue using `WindowCoordinator.shared.method()` unchanged
- Incremental migration: each extraction phase is independently verifiable
- No protocol overhead: controllers are concrete types, no unnecessary abstraction
- Acyclic dependency graph: no controller-to-controller dependencies
- @Observable observation chaining: computed property forwarding preserves SwiftUI reactivity

**Why not Protocol-based Abstraction**:
- Oracle explicitly recommended against "broad protocol abstractions" for internal types
- Protocols add indirection cost without benefit when there is exactly one implementation
- The Facade pattern already provides a clean public API surface

**Why not Actor-based isolation**:
- All window operations must run on the main thread (AppKit requirement)
- @MainActor annotation provides the same isolation guarantee as an actor
- Actors would add unnecessary suspension points for purely main-thread work

### File Structure and Responsibilities

After refactoring, `WindowCoordinator.swift` is 223 lines (an 84% reduction) and serves as a pure Facade/Composition root. The 10 extracted types total 1,470 lines across 11 files.

```
MacAmpApp/ViewModels/
    WindowCoordinator.swift           (223 lines) -- Facade + composition root
    WindowCoordinator+Layout.swift    (153 lines) -- Layout, presentation, debug logging

MacAmpApp/Windows/
    WindowRegistry.swift              ( 83 lines) -- Window ownership + lookup
    WindowFramePersistence.swift      (147 lines) -- Frame persistence + suppression
    WindowVisibilityController.swift  (161 lines) -- Show/hide/toggle + @Observable state
    WindowResizeController.swift      (312 lines) -- Resize + docking-aware layout
    WindowSettingsObserver.swift      (114 lines) -- Settings observation lifecycle
    WindowDelegateWiring.swift        ( 54 lines) -- Delegate setup static factory
    WindowDockingTypes.swift          ( 50 lines) -- Value types (Sendable)
    WindowDockingGeometry.swift       (109 lines) -- Pure geometry (nonisolated)
    WindowFrameStore.swift            ( 65 lines) -- UserDefaults wrapper (injectable)
```

### Responsibility Breakdown

| Type | SRP Responsibility | @MainActor | @Observable | Lines |
|------|-------------------|:----------:|:-----------:|------:|
| `WindowCoordinator` | Composition root, API forwarding | Yes | Yes | 223 |
| `WindowCoordinator+Layout` | Init-time layout, presentation, debug | Yes (inherited) | -- | 153 |
| `WindowRegistry` | Owns 5 NSWindowController instances, kind mapping | Yes | No | 83 |
| `WindowFramePersistence` | Save/load/suppress frame positions | Yes | No | 147 |
| `WindowVisibilityController` | Show/hide/toggle for all windows | Yes | Yes | 161 |
| `WindowResizeController` | Double-size resize, docking context, move | Yes | No | 312 |
| `WindowSettingsObserver` | Observe 4 AppSettings properties | Yes | No | 114 |
| `WindowDelegateWiring` | Static factory for delegate setup | Yes (struct) | No | 54 |
| `WindowDockingTypes` | Value types for docking context | No (Sendable) | No | 50 |
| `WindowDockingGeometry` | Pure geometry calculations | nonisolated | No | 109 |
| `WindowFrameStore` | UserDefaults encode/decode | No (value type) | No | 65 |

### Dependency Graph (Acyclic)

```
WindowCoordinator (facade / composition root)
    |
    +-- WindowRegistry                (no dependencies on other extracted types)
    |
    +-- WindowFramePersistence        (depends on: WindowRegistry, WindowFrameStore, AppSettings)
    |
    +-- WindowVisibilityController    (depends on: WindowRegistry, AppSettings)
    |
    +-- WindowResizeController        (depends on: WindowRegistry, WindowFramePersistence)
    |       |
    |       +-- uses WindowDockingGeometry (static, pure functions)
    |       +-- uses WindowDockingTypes (value types)
    |
    +-- WindowSettingsObserver        (depends on: AppSettings only)
    |
    +-- WindowDelegateWiring          (depends on: WindowRegistry, WindowPersistenceDelegate, WindowFocusState)

NO controller-to-controller dependencies.
All cross-cutting coordination goes through WindowCoordinator facade.
```

The dependency graph is strictly acyclic: controllers at the same level never reference each other. When coordination is required (for example, suppressing persistence during resize), the Facade orchestrates the interaction by calling methods on the appropriate controllers in sequence.

### @MainActor Isolation Boundaries

All types that manipulate `NSWindow` or AppKit objects are annotated `@MainActor`:

```swift
// WindowCoordinator.swift:4-6
@MainActor
@Observable
final class WindowCoordinator { ... }

// WindowRegistry.swift:4-5
@MainActor
final class WindowRegistry { ... }

// WindowFramePersistence.swift:4-5
@MainActor
final class WindowFramePersistence { ... }

// WindowVisibilityController.swift:5-7
@MainActor
@Observable
final class WindowVisibilityController { ... }
```

Two types are intentionally **not** `@MainActor`:

- **`WindowDockingGeometry`**: Declared `nonisolated struct` with all-static methods. Takes `NSRect` inputs and returns `NSRect`/`NSPoint` outputs. No side effects, no mutable state. Can be called from any isolation domain.
- **`WindowDockingTypes`**: Pure value types (`PlaylistAttachmentSnapshot`, `VideoAttachmentSnapshot`, `PlaylistDockingContext`) marked `Sendable`. Thread-safe by construction.

The `WindowCoordinator+Layout.swift` extension inherits `@MainActor` from the base type declaration -- no explicit annotation is needed on the extension.

### Swift 6.2 Concurrency Patterns

#### Recursive withObservationTracking

`WindowSettingsObserver` uses the standard one-shot observation pattern required for `@Observable` objects outside of SwiftUI View bodies:

```swift
// WindowSettingsObserver.swift:51-64
private func observeAlwaysOnTop() {
    tasks["alwaysOnTop"]?.cancel()  // Cancel existing before creating new
    tasks["alwaysOnTop"] = Task { @MainActor [weak self] in
        guard let self else { return }
        withObservationTracking {
            _ = self.settings.isAlwaysOnTop  // Register property access
        } onChange: {
            Task { @MainActor [weak self] in  // Nested Task for @Sendable boundary
                guard let self, self.handlers != nil else { return }
                self.handlers?.onAlwaysOnTopChanged(self.settings.isAlwaysOnTop)
                self.observeAlwaysOnTop()  // Re-establish (recursive)
            }
        }
    }
}
```

Key design decisions:
- **`[weak self]` on both Tasks**: Prevents retain cycles; when WindowCoordinator deallocates, observers terminate naturally
- **`self.handlers != nil` guard**: Prevents re-registration after `stop()` has been called
- **Explicit `@MainActor` on inner Task**: Defensive isolation annotation despite being in @MainActor context
- **Explicit `start()`/`stop()` lifecycle**: Oracle review required this instead of relying on `deinit` (which is `nonisolated` in Swift 6.2)

**Future migration path (macOS 26+)**:
```swift
// When minimum target is macOS 26, replace with:
for await _ in Observations(\.isAlwaysOnTop, on: settings) {
    handlers?.onAlwaysOnTopChanged(settings.isAlwaysOnTop)
}
```

#### nonisolated deinit Awareness

```swift
// WindowCoordinator.swift:145-149
deinit {
    skinPresentationTask?.cancel()
    // settingsObserver.stop() is not callable from nonisolated deinit;
    // tasks hold [weak self] references so they will naturally terminate.
}
```

In Swift 6.2, `deinit` is `nonisolated` -- it cannot call `@MainActor`-isolated methods. The design deliberately avoids this problem by ensuring all Tasks use `[weak self]`, so they terminate via `guard let self else { return }` when the coordinator is deallocated.

#### @Observable Observation Chaining

`WindowCoordinator` is `@Observable` and forwards visibility state from `WindowVisibilityController` (also `@Observable`) via computed properties:

```swift
// WindowCoordinator.swift:188-196
var isEQWindowVisible: Bool {
    get { visibility.isEQWindowVisible }
    set { visibility.isEQWindowVisible = newValue }
}

var isPlaylistWindowVisible: Bool {
    get { visibility.isPlaylistWindowVisible }
    set { visibility.isPlaylistWindowVisible = newValue }
}
```

This pattern is necessary because SwiftUI views observe `WindowCoordinator` -- the `@Observable` macro tracks the computed property access and chains the observation through to `WindowVisibilityController`. Without this forwarding, SwiftUI would not detect changes to the visibility state.

#### Debounced Persistence with Cancellation

```swift
// WindowFramePersistence.swift:45-53
func schedulePersistenceFlush() {
    guard persistenceSuppressionCount == 0 else { return }
    persistenceTask?.cancel()
    persistenceTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }  // Oracle fix: check after sleep
        self?.persistAllWindowFrames()
    }
}
```

The `guard !Task.isCancelled` check after `Task.sleep` was added based on Oracle review -- without it, a cancelled task could still execute `persistAllWindowFrames()` because `Task.sleep` throws on cancellation only if the caller checks.

### Phased Migration Strategy

The refactoring was executed in 4 phases, each independently buildable and verifiable:

| Phase | Extractions | Risk | Lines Removed |
|-------|------------|------|:-------------:|
| Phase 1 | `WindowDockingTypes`, `WindowDockingGeometry`, `WindowFrameStore` | Zero (pure types) | ~325 |
| Phase 2 | `WindowRegistry`, `WindowFramePersistence`, `WindowVisibilityController`, `WindowResizeController` | Low-Medium (controllers) | ~500 |
| Phase 3 | `WindowSettingsObserver`, `WindowDelegateWiring` | Low (observation + wiring) | ~200 |
| Phase 4 | `WindowCoordinator+Layout` (extension) | Cosmetic | ~130 |

**Build verification after each phase**:
```bash
xcodebuild -scheme MacAmp -configuration Debug -enableThreadSanitizer YES build
xcodebuild test -scheme MacAmp -enableThreadSanitizer YES
```

All 4 phases passed build + Thread Sanitizer + full test suite.

### Oracle Review Results

Five Oracle reviews (gpt-5.3-codex, reasoning effort: xhigh) were conducted across the refactoring:

| Review | Scope | Verdict | Key Findings |
|--------|-------|---------|-------------|
| Pre-implementation | Plan review | REVISE then proceed | Split pure/stateful geometry; fix deinit lifecycle |
| Post-Phase 1 | 3 new files + tests | 1 finding (P2) | Test build phase ordering; fixed |
| Post-Phase 2 | 4 controllers | No concrete defects | Clean architecture verified |
| Post-Phase 3 | Observer + wiring | No functional regressions | Lifecycle pattern approved |
| Post-Phase 4 (Final) | All 11 files | No blocking issues | 2 HIGH fixes applied (debounce cancellation, observer stop guard) |

**Critical fixes from Oracle review**:

1. **Debounce cancellation bug** (HIGH): Added `guard !Task.isCancelled` after `Task.sleep` in `WindowFramePersistence.schedulePersistenceFlush()` to prevent persistence writes after task cancellation.

2. **Observer stop guard** (MEDIUM): Added `self.handlers != nil` guard in all 4 `onChange` callbacks in `WindowSettingsObserver` to prevent re-registration after `stop()` is called.

### Swift 6.2 Compliance Summary

The Swift patterns review (conducted by swift-concurrency-expert skill) graded the refactoring **A+ (95/100)**.

| Check | Status |
|-------|--------|
| No implicit @MainActor capture warnings | Pass |
| No Sendable conformance violations | Pass |
| No nonisolated deinit violations | Pass |
| No data race warnings (Thread Sanitizer) | Pass |
| No @unchecked Sendable usage | Pass |
| No global mutable state (except managed) | Pass |
| No Task detachment without isolation | Pass |
| No unstructured concurrency leaks | Pass |

**Patterns demonstrated**:
- `@Observable` macro (Swift 5.9+) with fine-grained change tracking
- Composition over inheritance (zero class hierarchies)
- Constructor dependency injection throughout
- Value types where appropriate (`WindowDelegateWiring` struct, docking types)
- Actor isolation first (all UI types @MainActor)
- Structured concurrency (all Tasks stored and managed)

### File Organization Principles

1. **Facade stays in `ViewModels/`**: `WindowCoordinator.swift` and its layout extension remain in `MacAmpApp/ViewModels/` because they are consumed by SwiftUI views as an `@Observable` model.

2. **Controllers move to `Windows/`**: All extracted types that deal with `NSWindow` manipulation live in `MacAmpApp/Windows/`, colocated with other window infrastructure (`WindowSnapManager`, `WindowDelegateMultiplexer`, etc.).

3. **Pure types are nonisolated**: `WindowDockingGeometry` and `WindowDockingTypes` have no actor isolation. They are pure value computations that can be called from any context and unit-tested trivially.

4. **Static factories for complex construction**: `WindowDelegateWiring.wire()` encapsulates the 60+ lines of multiplexer/delegate setup into a single call that returns an immutable struct holding strong references.

5. **Injectable dependencies**: `WindowFrameStore` accepts `UserDefaults` via `init(defaults:)`, enabling unit tests with isolated UserDefaults instances.

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1)
- [ ] Create `VideoVisualizerState` and `MilkdropVisualizerState` models
- [ ] Create `WindowStateStore` for frame persistence
- [ ] Add new `WindowGroup` declarations to `MacAmpApp`
- [ ] Update `DockingController` to support visualizer windows

### Phase 2: Views (Week 2)
- [ ] Build `VideoVisualizerView` with basic rendering
- [ ] Build `MilkdropVisualizerView` with basic rendering
- [ ] Integrate `WindowAccessor` for frame capture
- [ ] Add window controls (color mode, fullscreen)

### Phase 3: Integration (Week 3)
- [ ] Add `VisualizerCommands` for menu items and keyboard shortcuts
- [ ] Integrate with `WindowSnapManager` for magnetic snapping
- [ ] Test multi-window window positioning
- [ ] Implement frame persistence and restoration

### Phase 4: Polish (Week 4)
- [ ] Add window lifecycle management
- [ ] Verify Swift 6 concurrency compliance
- [ ] Test multi-monitor scenarios
- [ ] Performance testing and optimization

---

## Testing Checklist

- [ ] Open both visualizer windows simultaneously
- [ ] Verify independent state (one in spectrum mode, other in fire mode)
- [ ] Close one window, verify other still functional
- [ ] Reopen closed window, verify settings restored
- [ ] Move window off-screen, quit app, reopen (should restore valid position)
- [ ] Test on multi-monitor setup (windows restore to correct screen)
- [ ] Verify window snapping between main window and visualizers
- [ ] Test keyboard shortcuts (Cmd+Shift+V, Cmd+Shift+M)
- [ ] Verify no memory leaks with Instruments
- [ ] Test with thread sanitizer enabled

---

## References

1. **Apple Developer Documentation**
   - [Bringing Multiple Windows to Your SwiftUI App](https://developer.apple.com/documentation/swiftui/bringing-multiple-windows-to-your-swiftui-app)
   - [WindowGroup Documentation](https://developer.apple.com/documentation/swiftui/windowgroup)
   - [WWDC 2024: Work with Windows in SwiftUI](https://developer.apple.com/videos/play/wwdc2024/10149/)
   - [WWDC 2022: Bring Multiple Windows to Your SwiftUI App](https://developer.apple.com/videos/play/wwdc2022/10061/)

2. **Community Resources**
   - [Swift with Majid: Window Management in SwiftUI](https://swiftwithmajid.com/2022/11/02/window-management-in-swiftui/)
   - [Swift with Majid: Customizing Windows in SwiftUI](https://swiftwithmajid.com/2024/08/06/customizing-windows-in-swiftui/)
   - [FatBobman: The @State Specter - Multi-Window SwiftUI Bug Analysis](https://fatbobman.com/en/posts/the-state-specter-analyzing-a-bug-in-multi-window-swiftui-applications/)

3. **MacAmp-Specific**
   - See `MacAmpApp/Utilities/WindowAccessor.swift` for NSWindow capture pattern
   - See `MacAmpApp/Utilities/WindowSnapManager.swift` for magnetic snapping
   - See `MacAmpApp/ViewModels/DockingController.swift` for pane management
   - See `MacAmpApp/Models/AppSettings.swift` for @Observable singleton pattern

4. **WindowCoordinator Refactoring (2026-02)**
   - See `MacAmpApp/ViewModels/WindowCoordinator.swift` (223 lines, Facade)
   - See `MacAmpApp/ViewModels/WindowCoordinator+Layout.swift` (153 lines, layout extension)
   - See `MacAmpApp/Windows/WindowRegistry.swift` (83 lines, window ownership)
   - See `MacAmpApp/Windows/WindowFramePersistence.swift` (147 lines, frame persistence)
   - See `MacAmpApp/Windows/WindowVisibilityController.swift` (161 lines, visibility)
   - See `MacAmpApp/Windows/WindowResizeController.swift` (312 lines, resize + docking)
   - See `MacAmpApp/Windows/WindowSettingsObserver.swift` (114 lines, observation)
   - See `MacAmpApp/Windows/WindowDelegateWiring.swift` (54 lines, delegate setup)
   - See `MacAmpApp/Windows/WindowDockingTypes.swift` (50 lines, value types)
   - See `MacAmpApp/Windows/WindowDockingGeometry.swift` (109 lines, pure geometry)
   - See `MacAmpApp/Windows/WindowFrameStore.swift` (65 lines, UserDefaults persistence)
   - See `tasks/window-coordinator-refactor/plan.md` for refactoring plan
   - See `tasks/window-coordinator-refactor/state.md` for final state
   - See `tasks/window-coordinator-refactor/swift-patterns-review.md` for Swift 6.2 review

---

## Appendix: Complete WindowStateStore Implementation

See the "Window State Store" section above for full implementation including:
- Frame persistence with JSON encoding
- Window registration and tracking
- Multi-monitor validation
- Debounced UserDefaults writes
- Weak reference management
