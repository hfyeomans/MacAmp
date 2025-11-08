# Multi-Window Architecture Research Summary

## Research Conducted

This document summarizes the comprehensive research on modern SwiftUI multi-window architecture for macOS 15+/26+, with specific focus on implementing independent auxiliary windows (Video and Milkdrop visualizers) in MacAmp.

### Research Sources

1. **Apple Developer Documentation**
   - Official WWDC 2024 videos on window management
   - WWDC 2022 "Bring Multiple Windows to Your SwiftUI App"
   - SwiftUI WindowGroup, Window, and Scene documentation
   - macOS NSWindow and NSWindowDelegate APIs

2. **MacAmp Codebase Analysis**
   - Current architecture: Pure SwiftUI with @Observable models
   - Existing patterns: WindowAccessor, WindowSnapManager, DockingController
   - State management: Singleton pattern with environment injection

3. **Community Best Practices**
   - Swift Forums discussions on multi-window state management
   - Known bugs with @Observable in WindowGroup (fixed in iOS 17.5+, macOS 14.5+)
   - Workarounds and recommended patterns

4. **Oracular Consultation (Codex CLI)**
   - Architecture validation from MacAmp context
   - Pattern recommendations for MacAmp's specific use case
   - Swift 6 concurrency pattern guidance

---

## Key Findings

### 1. WindowGroup(id:) is the Right Pattern for MacAmp

**Why**: MacAmp needs:
- Independent windows that can coexist simultaneously
- One instance per window type (one video, one milkdrop)
- Shared global state across all windows
- Pure SwiftUI lifecycle management

**Pattern**:
```swift
WindowGroup(id: "videoVisualizer") { VideoVisualizerView() }
WindowGroup(id: "milkdropVisualizer") { MilkdropVisualizerView() }
```

Not NSWindowController (adds unnecessary complexity)
Not value-based WindowGroup (overkill for fixed window types)
Not Document-based app (not applicable here)

### 2. Three-Level State Architecture

```
Level 1: Global Singletons (AudioPlayer, AppSettings, SkinManager)
    ↓ @Environment injection
Level 2: Per-Window Models (VideoVisualizerState, MilkdropVisualizerState)
    ↓ Per-window @Environment injection
Level 3: View-Local State (@State, transient UI state)
```

This prevents the "@Observable sharing bug" where windows unexpectedly share state.

### 3. Critical Concurrency Pattern: @MainActor Enforcement

**All state models MUST be**:
```swift
@Observable
@MainActor
final class VideoVisualizerState { ... }
```

This ensures:
- Automatic main-thread serialization
- Safe concurrent reads from multiple windows
- Swift 6 strict concurrency compliance
- No race conditions despite multi-window access

### 4. WindowAccessor is Perfect for Frame Capture

MacAmp already has this pattern! Reuse it:
```swift
.background(WindowAccessor { window in
    windowStore.register(window: window, kind: .videoVisualizer)
    docking.windowSnapManager.register(window: window, kind: .visualizerVideo)
})
```

No additional NSWindowController needed.

### 5. Window Snapping Integration

WindowSnapManager can be extended with new WindowKind cases:
```swift
enum WindowKind: Hashable {
    case main, playlist, equalizer
    case videoVisualizer, milkdropVisualizer  // NEW
}
```

All windows participate in magnetic snapping automatically.

---

## Implementation Strategy

### Phase 1: Foundation Models
Create three new files:
1. `VideoVisualizerState.swift` - @Observable per-window state
2. `MilkdropVisualizerState.swift` - @Observable per-window state
3. `WindowStateStore.swift` - @Observable frame persistence

### Phase 2: Views
Create two new files:
1. `VideoVisualizerView.swift` - Uses Metal/Canvas rendering
2. `MilkdropVisualizerView.swift` - Uses Metal/Canvas rendering

### Phase 3: App Integration
Modify one file:
1. `MacAmpApp.swift` - Add WindowGroup declarations and VisualizerCommands

### Phase 4: Extensions
Extend existing files:
1. `DockingController.swift` - Add visualizer window registration
2. `WindowSnapManager.swift` - Handle new window kinds

---

## Critical Design Decisions

### Decision 1: State Sharing for Audio
**Chosen**: Share AudioPlayer and AppSettings globally
**Reason**: All windows need same playback state and user settings
**Implementation**: Inject via .environment() into all windows

### Decision 2: Per-Window Display State
**Chosen**: Independent models for each visualizer window
**Reason**: Each visualizer has different rendering params (colors, shaders, etc.)
**Implementation**: VideoVisualizerState and MilkdropVisualizerState are separate

### Decision 3: Frame Persistence Strategy
**Chosen**: Debounced UserDefaults writes via JSON encoding
**Reason**: Simple, effective, matches AppSettings pattern
**Implementation**: WindowStateStore handles all persistence

### Decision 4: Window Opening Method
**Chosen**: .openWindow environment action from Commands
**Reason**: Native SwiftUI, automatic window lifecycle, works with keyboard shortcuts
**Implementation**: VisualizerCommands struct with @Environment(\.openWindow)

---

## Known Pitfalls Documented

1. **State Shared Between Windows**: Use separate @State for each WindowGroup
2. **Window Reference Cycles**: Use weak references in closures
3. **Excessive Body Re-evaluations**: Use Metal directly, not SwiftUI Canvas for audio data
4. **@MainActor Violations**: All mutations must run on main thread (automatic with @Observable @MainActor)
5. **Off-Screen Windows**: Validate and restore frames to active screens

---

## Swift 6 Compliance

All recommended patterns follow Swift 6 strict concurrency:
- ✅ @Observable models are @MainActor by default
- ✅ Sendable conformance for WindowStateStore (WeakBox class)
- ✅ Task { @MainActor in ... } for background→UI transitions
- ✅ No force unwraps or !
- ✅ Weak references for NSWindow to prevent cycles

---

## Performance Considerations

### Audio Frequency Updates
- AudioPlayer.currentFrequencies updates at ~60Hz
- **Don't** trigger SwiftUI body re-evaluation for each update
- **Do** use Metal/Canvas with onChange callbacks
- **Do** cache processed waveforms in per-window state

### Memory Usage
- Weak box references prevent window retention
- DisplayLink cleanup on view disappear
- Metal textures auto-released when view deallocates

### GPU Rendering
- Metal is preferred for real-time visualization
- MTKView with displayLink for 60FPS+
- Lazy Metal texture allocation
- SwiftUI Canvas acceptable for simple 2D rendering

---

## Testing Strategy

### Unit Tests
- WindowStateStore frame persistence
- State model initialization from UserDefaults
- WindowKind enum variants

### Integration Tests
- Open both visualizer windows simultaneously
- Verify independent state (colors don't sync)
- Close one window, verify other continues
- Test magnetic snapping across all 5 windows
- Verify no memory leaks with Instruments

### Multi-Monitor Tests
- Open window on secondary display
- Quit app, move display offline, reopen
- Verify window restores to valid screen

### Stress Tests
- Rapid open/close cycles
- High-frequency audio data updates
- Window snapping while visualizers running
- Long-running playback sessions

---

## Comparison: Rejected Alternatives

### Alternative 1: NSWindowController Wrapper
**Why rejected**:
- Duplicates SwiftUI scene lifecycle
- Complicates environment injection
- Not needed - WindowAccessor provides escape hatch
- Adds 200+ lines of unnecessary code

### Alternative 2: Value-Based WindowGroup
**Why rejected**:
- Designed for document-style multiple windows of same type
- Overkill for fixed auxiliary windows
- Adds unnecessary identifier management complexity

### Alternative 3: Single MDI-Style Window
**Why rejected**:
- Doesn't match Winamp's multi-window paradigm
- Harder to implement window snapping
- Less user-friendly for multi-monitor setups

---

## Success Criteria

- ✅ Two auxiliary windows coexist with main window
- ✅ Each visualizer has independent display settings
- ✅ Window positions/sizes persist across app restarts
- ✅ Windows snap magnetically to each other
- ✅ No memory leaks on open/close cycles
- ✅ Swift 6 strict concurrency compliance
- ✅ 60FPS+ rendering performance
- ✅ Multi-monitor support working correctly

---

## Next Steps for Implementation

1. Review MULTI_WINDOW_ARCHITECTURE.md for detailed code patterns
2. Create VideoVisualizerState.swift with proper structure
3. Create WindowStateStore.swift with frame persistence
4. Add new WindowGroup entries to MacAmpApp.swift
5. Build VideoVisualizerView.swift and MilkdropVisualizerView.swift
6. Extend DockingController for visualizer windows
7. Add VisualizerCommands for menu items and shortcuts
8. Test all scenarios from Testing Strategy section
9. Optimize rendering performance with Instruments

---

## References

See MULTI_WINDOW_ARCHITECTURE.md for:
- Complete code examples for all patterns
- Detailed API documentation
- Line-by-line implementation guidance
- Troubleshooting common issues
