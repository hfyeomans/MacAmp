# Multi-Window Architecture Quick Reference

## TL;DR: The Answer

Use **multiple `WindowGroup(id:)` instances** in `MacAmpApp.swift` with:
- Shared global state (AudioPlayer, AppSettings) via `@Environment`
- Per-window state models (`VideoVisualizerState`, etc.) via `@Observable @MainActor`
- Frame persistence via `WindowStateStore`
- Reuse existing `WindowAccessor` pattern
- Extend `WindowSnapManager` with new window kinds

**Result**: Pure SwiftUI, no NSWindowController, automatic lifecycle, Swift 6 safe.

---

## Five Minutes to Understand It

### 1. The Three-Layer Architecture

```
┌─────────────────────────────────────────┐
│ Layer 1: Shared Globals (create ONCE)  │
│ AudioPlayer, AppSettings, SkinManager   │
│ Lives in MacAmpApp init()               │
└─────────────────────────────────────────┘
                  ↓ @Environment
┌─────────────────────────────────────────┐
│ Layer 2: Per-Window State (one per ID)  │
│ VideoVisualizerState (for video window) │
│ MilkdropVisualizerState (for milkdrop)  │
│ WindowStateStore (frame persistence)    │
│ Lives in MacAmpApp init()               │
└─────────────────────────────────────────┘
                  ↓ @Environment per window
┌─────────────────────────────────────────┐
│ Layer 3: View State (transient)          │
│ @State for animations, selections       │
│ Created/destroyed with view              │
└─────────────────────────────────────────┘
```

### 2. The Window Declaration

```swift
@main
struct MacAmpApp: App {
    // Layer 1: Global singletons (shared across all windows)
    @State private var audioPlayer: AudioPlayer
    @State private var settings: AppSettings
    
    // Layer 2: Per-window state (one set per WindowGroup)
    @State private var videoVisState = VideoVisualizerState()
    @State private var milkdropVisState = MilkdropVisualizerState()
    @State private var windowStore = WindowStateStore()
    
    var body: some Scene {
        // Main window
        WindowGroup {
            UnifiedDockView()
                .environment(audioPlayer)
                .environment(settings)
                .environment(videoVisState)
                .environment(milkdropVisState)
                .environment(windowStore)
        }
        
        // Video visualizer window
        WindowGroup(id: "videoVisualizer") {
            VideoVisualizerView()
                .environment(audioPlayer)    // Shared
                .environment(settings)       // Shared
                .environment(videoVisState)  // Unique to this window
                .environment(windowStore)
        }
        
        // Milkdrop visualizer window
        WindowGroup(id: "milkdropVisualizer") {
            MilkdropVisualizerView()
                .environment(audioPlayer)     // Shared
                .environment(settings)        // Shared
                .environment(milkdropVisState) // Unique to this window
                .environment(windowStore)
        }
    }
}
```

### 3. Opening a Window

```swift
struct VideoVisualizerView: View {
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        Button("Show Visualizer") {
            openWindow(id: "videoVisualizer")
        }
    }
}
```

### 4. Per-Window State Model

```swift
@Observable
@MainActor
final class VideoVisualizerState {
    var colorMode: ColorMode = .spectrum {
        didSet { 
            UserDefaults.standard.set(colorMode.rawValue, forKey: "video.color")
        }
    }
    
    init() {
        if let saved = UserDefaults.standard.string(forKey: "video.color"),
           let mode = ColorMode(rawValue: saved) {
            self.colorMode = mode
        }
    }
}
```

### 5. Capturing the NSWindow

```swift
struct VideoVisualizerView: View {
    @Environment(WindowStateStore.self) var windowStore
    @State private var windowID = UUID()
    
    var body: some View {
        YourContent()
            .background(WindowAccessor { window in
                // Register for frame persistence
                windowStore.register(window: window, kind: .videoVisualizer)
                // Register for snapping
                docking.windowSnapManager.register(window: window, kind: .visualizerVideo)
            })
    }
}
```

---

## Files to Create

### 1. `VideoVisualizerState.swift`
```swift
@Observable @MainActor final class VideoVisualizerState {
    enum ColorMode: String, Codable { case spectrum, fire, ice, rainbow }
    var colorMode: ColorMode = .spectrum { didSet { persist() } }
    var refreshRate: Double = 60.0 { didSet { persist() } }
    init() { load() }
    private func persist() { /* UserDefaults */ }
    private func load() { /* UserDefaults */ }
}
```

### 2. `MilkdropVisualizerState.swift`
Same structure as VideoVisualizerState but with milkdrop-specific params.

### 3. `WindowStateStore.swift`
```swift
@Observable @MainActor final class WindowStateStore {
    private var trackedWindows: [WindowKind: WeakBox<NSWindow>] = [:]
    func register(window: NSWindow, kind: WindowKind) { /* register */ }
    func persistFrame(_ frame: NSRect, for kind: WindowKind) { /* UserDefaults */ }
    func restoreFrame(for window: NSWindow, kind: WindowKind) { /* load */ }
}
```

### 4. `VideoVisualizerView.swift`
```swift
struct VideoVisualizerView: View {
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(VideoVisualizerState.self) var visState
    @Environment(WindowStateStore.self) var windowStore
    
    var body: some View {
        ZStack {
            // Your Metal/Canvas rendering
            MetalVisualizerCanvas(frequencies: audioPlayer.currentFrequencies)
            // Overlay controls
            VStack { /* controls */ }
        }
        .background(WindowAccessor { /* register */ })
    }
}
```

### 5. `MilkdropVisualizerView.swift`
Same structure as VideoVisualizerView.

---

## Files to Modify

### `MacAmpApp.swift`
Add three new `WindowGroup` declarations (see above)

### `DockingController.swift`
```swift
enum WindowKind: Hashable {
    case main, playlist, equalizer
    case videoVisualizer, milkdropVisualizer  // NEW
}

// Add method:
func register(window: NSWindow, kind: WindowKind) { /* ... */ }
```

### `WindowSnapManager.swift`
Handle new WindowKind cases automatically (no changes needed if enum-based)

---

## Key Principles

1. **One @State per WindowGroup**: Each window gets its own state instance
2. **@Observable @MainActor Everything**: Automatic concurrency safety
3. **Reuse WindowAccessor**: Already exists, just use it
4. **Debounce UserDefaults**: 500ms delay to avoid disk thrashing
5. **Weak References**: Prevent NSWindow retention cycles

---

## Common Mistakes to Avoid

❌ Creating a single `VideoVisualizerState()` instance shared across windows
✅ Create separate `@State` for each WindowGroup

❌ Strong reference to NSWindow in closures
✅ Use weak references or WeakBox

❌ Updating AudioPlayer.currentFrequencies causes body re-evaluation
✅ Use onChange callbacks, not body dependence

❌ Mutating @Observable from background thread
✅ Use `Task { @MainActor in }` 

❌ Creating NSWindowController wrapper
✅ Use WindowAccessor in your SwiftUI view

---

## Testing Checklist

- [ ] Open both visualizers, verify independent settings
- [ ] Close one visualizer, other still works
- [ ] Quit app, reopen, settings restored
- [ ] Windows snap together
- [ ] No memory leaks (Instruments)
- [ ] Multi-monitor: open on secondary, quit, reopen (valid position)
- [ ] Keyboard shortcuts work (Cmd+Shift+V, etc.)
- [ ] Thread sanitizer clean

### Instant Double-Size Docking (Updated – 2026-02-09)

**Note:** As of Feb 2026, WindowCoordinator was refactored into 11 focused files. The docking logic is now split across:

1. `WindowSettingsObserver` detects `AppSettings.isDoubleSizeMode` changes via `withObservationTracking`
2. Fires `onDoubleSizeChanged` callback to `WindowCoordinator`
3. `WindowCoordinator` forwards to `WindowResizeController.resizeMainAndEQWindows()`
4. `WindowResizeController.makePlaylistDockingContext()` calls `WindowSnapManager.clusterKinds(containing: .playlist)` and uses `WindowDockingGeometry` pure functions for attachment detection
5. Main/EQ resize synchronously while `WindowFramePersistence` suppresses writes
6. Playlist repositioned via `movePlaylist(using:context,targetFrame:)` to stay glued to anchor

**Files involved:**
- `WindowSettingsObserver.swift` - Observation
- `WindowResizeController.swift` - Resize orchestration
- `WindowDockingGeometry.swift` - Pure geometry calculations
- `WindowFramePersistence.swift` - Persistence suppression

If docking regresses, check debug logs: `[DOCKING] source: ...` (prefix changed from `[ORACLE]`)

See MULTI_WINDOW_ARCHITECTURE.md §10 for complete refactoring details.

---

## Performance Tips

1. Use **Metal rendering** not SwiftUI Canvas for audio visualization
2. **Don't trigger body** on every audio update (use onChange)
3. **Cache waveforms** in per-window state
4. **Clean up DisplayLink** in onDisappear
5. **Use CVDisplayLink** for 60+ FPS smooth rendering

---

## Where to Find Examples

- Full architecture details: `MULTI_WINDOW_ARCHITECTURE.md`
- Research summary: `MULTI_WINDOW_RESEARCH_SUMMARY.md`
- Complete code patterns: Both docs above
- Existing code to learn from:
  - `WindowAccessor.swift` - NSWindow capture pattern
  - `AppSettings.swift` - @Observable model pattern
  - `DockingController.swift` - Window registration pattern
  - `UnifiedDockView.swift` - Environment injection pattern

---

## Success = This Code Works

```swift
// In VideoVisualizerView
@Environment(VideoVisualizerState.self) var visState

Button("Switch to Fire") { visState.colorMode = .fire }

// In MilkdropVisualizerView
@Environment(MilkdropVisualizerState.self) var visState

Button("Switch to Fire") { visState.colorMode = .fire }

// These don't affect each other! Independent state.
```

If clicking in one visualizer affects the other → you shared state wrong.

---

## That's It

You now have everything needed to implement multi-window architecture in MacAmp.

Review the detailed `MULTI_WINDOW_ARCHITECTURE.md` for complete code examples and implementation details.
