# Multi-Window Architecture Documentation Index

## Overview

This documentation package provides comprehensive guidance for implementing modern SwiftUI multi-window architecture in MacAmp, enabling truly independent auxiliary windows (Video and Milkdrop visualizers) for macOS 15+/26+.

## Document Guide

### 1. **MULTI_WINDOW_QUICK_START.md** (Start Here!)
**Read This First** - 5-10 minute read
- TL;DR of the entire approach
- Five-minute visual explanation of three-layer architecture
- Quick code snippets showing the pattern
- File checklist for implementation
- Common mistakes to avoid
- Testing checklist
- Instant double-size docking checklist (added 2025-11-09)

**Use This For**: Quick understanding, implementation checklist, debugging

### 2. **MULTI_WINDOW_RESEARCH_SUMMARY.md** (Why This Approach?)
**Read This Second** - 10-15 minute read
- Complete research methodology documented
- Key findings and decisions explained
- Why WindowGroup(id:) is recommended (vs NSWindowController, value-based WindowGroup, etc.)
- Swift 6 compliance verification
- Performance considerations
- Testing strategy
- Rejected alternatives with rationale

**Use This For**: Understanding design decisions, validating approach, performance optimization

### 3. **MULTI_WINDOW_ARCHITECTURE.md** (Implementation Details)
**Read This For Implementation** - 30+ minute reference
- Complete architecture overview
- Detailed code examples for every pattern
  - Per-window state models (VideoVisualizerState, MilkdropVisualizerState)
  - WindowStateStore for frame persistence
  - Window Management with WindowAccessor
  - Opening windows with Commands
  - Lifecycle management
  - Concurrency patterns
- Complete integration with existing infrastructure
- Swift 6 concurrency best practices
- Common pitfalls with solutions
- Multi-monitor support
- Implementation roadmap with phases
- Full testing checklist

**Use This For**: Copy-paste code patterns, detailed implementation, troubleshooting

---

## Quick Navigation

**I want to...**

| Task | Read | Time |
|------|------|------|
| Understand the approach | QUICK_START | 5 min |
| See code examples | ARCHITECTURE | 20 min |
| Decide if this is right | RESEARCH_SUMMARY | 15 min |
| Implement the feature | ARCHITECTURE + QUICK_START | 4-6 hours |
| Debug a problem | ARCHITECTURE (Common Pitfalls) | 10 min |
| Optimize performance | RESEARCH_SUMMARY (Performance) + ARCHITECTURE | 20 min |
| Add new visualizer window | ARCHITECTURE (Pattern C) | 1 hour |

---

## Key Concepts at a Glance

### The Recommended Approach

```
WindowGroup(id: "videoVisualizer") {
    VideoVisualizerView()
        .environment(audioPlayer)           // Shared: all windows see same audio
        .environment(videoVisualizerState)  // Unique: this window only
        .environment(windowStore)           // Persistence: for all windows
}
```

### Why This Works

1. **Independent Windows**: Each WindowGroup gets its own SwiftUI scene lifecycle
2. **Shared State**: Global singletons injected to all windows via @Environment
3. **Per-Window State**: Separate @Observable models prevent state bleed
4. **Pure SwiftUI**: No NSWindowController complexity
5. **Swift 6 Safe**: All @Observable @MainActor enforces concurrency safety

### Architecture Diagram

```
MacAmpApp (App struct)
├── @State audioPlayer (shared to all windows)
├── @State appSettings (shared to all windows)
├── @State videoVisualizerState (for video window only)
├── @State milkdropVisualizerState (for milkdrop window only)
└── @State windowStateStore (for persistence, accessed by all)
    ├── WindowGroup (main window)
    │   └── UnifiedDockView
    ├── WindowGroup(id: "videoVisualizer")
    │   └── VideoVisualizerView
    └── WindowGroup(id: "milkdropVisualizer")
        └── MilkdropVisualizerView
```

---

## Implementation Roadmap

### Phase 1: Foundation (Implement First)
- [ ] Read QUICK_START.md (5 min)
- [ ] Read ARCHITECTURE.md sections 1-3 (20 min)
- [ ] Create VideoVisualizerState.swift
- [ ] Create MilkdropVisualizerState.swift
- [ ] Create WindowStateStore.swift
- [ ] Update MacAmpApp.swift with new WindowGroup declarations

### Phase 2: Views
- [ ] Create VideoVisualizerView.swift with WindowAccessor integration
- [ ] Create MilkdropVisualizerView.swift
- [ ] Add basic rendering (Canvas or Metal)
- [ ] Add overlay controls (color mode, fullscreen)

### Phase 3: Integration
- [ ] Extend DockingController to support visualizer windows
- [ ] Extend WindowSnapManager if needed
- [ ] Add VisualizerCommands for menu items
- [ ] Wire keyboard shortcuts (Cmd+Shift+V, Cmd+Shift+M)

### Phase 4: Testing & Polish
- [ ] Manual testing from checklist
- [ ] Memory leak detection with Instruments
- [ ] Multi-monitor testing
- [ ] Performance optimization with Metal if needed

---

## Testing Checklist

Use this to verify correct implementation:

**Basic Functionality**
- [ ] Open both visualizer windows simultaneously
- [ ] Each window has independent state (color mode doesn't sync)
- [ ] Close one window, other still works
- [ ] Reopen closed window

**Persistence**
- [ ] Change settings in visualizer (color mode, etc.)
- [ ] Quit and reopen app
- [ ] Settings are restored
- [ ] Window positions are restored

**Window Management**
- [ ] Windows snap magnetically to each other
- [ ] Windows snap to screen edges
- [ ] Double-size mode affects all windows proportionally
- [ ] Always-on-top affects only main window

**Multi-Monitor**
- [ ] Open visualizer on secondary display
- [ ] Quit app with display online
- [ ] Disconnect secondary display
- [ ] Reopen app - window restores to primary screen (not off-screen)

**Concurrency**
- [ ] No crashes with thread sanitizer enabled
- [ ] Audio updates don't stutter visualizers
- [ ] Window operations don't block audio

**Performance**
- [ ] Visualizers run at 60+ FPS
- [ ] No memory growth over 10+ minute sessions
- [ ] Snapping is smooth and responsive

---

## Code Patterns Quick Reference

### Pattern 1: Per-Window State Model
```swift
@Observable @MainActor final class VideoVisualizerState {
    var colorMode: ColorMode = .spectrum { didSet { persist() } }
    init() { load() }
}
```

### Pattern 2: Window Registration
```swift
.background(WindowAccessor { window in
    windowStore.register(window: window, kind: .videoVisualizer)
    docking.windowSnapManager.register(window: window, kind: .visualizerVideo)
})
```

### Pattern 3: Opening Windows
```swift
@Environment(\.openWindow) var openWindow
Button("Show Video") { openWindow(id: "videoVisualizer") }
```

### Pattern 4: Safe State Updates from Async
```swift
Task { @MainActor in
    videoVisState.colorMode = newMode
}
```

---

## Integration Points with Existing Code

### WindowAccessor.swift
Already exists! Reuse it exactly as shown in examples.

### AppSettings.swift
Pattern to follow: Use @Observable @MainActor with UserDefaults didSet

### DockingController.swift
Extend WindowKind enum, add register() method

### WindowSnapManager.swift
Already enum-based, will handle new window kinds automatically

---

## Common Issues & Solutions

**Issue**: Visualizer windows share state when they shouldn't
**Solution**: Create separate `@State` for each WindowGroup in MacAmpApp

**Issue**: Window position saved off-screen, can't recover
**Solution**: WindowStateStore.validateFrame() checks bounds before restoring

**Issue**: Memory leaks from NSWindow references
**Solution**: Always use weak references and WeakBox class

**Issue**: Audio stutters during visualizer rendering
**Solution**: Don't trigger SwiftUI body on every audio update, use onChange callbacks

**Issue**: Window won't open/appears then closes
**Solution**: Verify WindowGroup(id:) exactly matches openWindow(id:) string

---

## Performance Optimization Tips

1. **Use Metal for Audio Visualization**
   - Don't use SwiftUI Canvas with 60Hz audio updates
   - Use Metal with CVDisplayLink for smooth 120FPS rendering

2. **Cache Expensive Computations**
   - Store processed waveforms in per-window state
   - Update cache in onChange callbacks, not body

3. **Debounce UserDefaults Writes**
   - Use 500ms debounce for frame persistence
   - Prevents excessive disk I/O

4. **Lazy Load Resources**
   - Create Metal textures on first render
   - Release in onDisappear

5. **Monitor with Instruments**
   - Use Memory profiler to detect leaks
   - Use Core Data or Allocations to track object creation

---

## FAQ

**Q: Do I need NSWindowController?**
A: No! WindowAccessor provides all the NSWindow access you need.

**Q: Can multiple windows have the same visualizer?**
A: Not with current WindowGroup(id:) approach. One window per ID. To support multiple, use value-based WindowGroup (documented in ARCHITECTURE.md).

**Q: How do I make visualizers work with window snapping?**
A: Register with WindowSnapManager in WindowAccessor callback. Already shown in examples.

**Q: What about Milkdrop shaders?**
A: Use Metal rendering with SPIR-V or Metal shaders. Per-window state can store shader parameters.

**Q: Do I need to recompile skins?**
A: No, skins are orthogonal to window architecture.

---

## Document Statistics

| Document | Lines | Topics | Examples | Patterns |
|----------|-------|--------|----------|----------|
| QUICK_START | 305 | 10 | 8 | 5 |
| RESEARCH_SUMMARY | 278 | 15 | 5 | 3 |
| ARCHITECTURE | 1050 | 25 | 20+ | 12 |
| **Total** | **1633** | **50+** | **33+** | **20+** |

---

## Related Files in Codebase

These existing files provide patterns to follow:

- `MacAmpApp/MacAmpApp.swift` - App struct with WindowGroup pattern
- `MacAmpApp/Models/AppSettings.swift` - @Observable @MainActor singleton pattern
- `MacAmpApp/Utilities/WindowAccessor.swift` - NSWindow capture pattern
- `MacAmpApp/Utilities/WindowSnapManager.swift` - Window registration pattern
- `MacAmpApp/ViewModels/DockingController.swift` - Window kind enum pattern
- `MacAmpApp/Views/UnifiedDockView.swift` - Environment injection pattern

Study these to understand MacAmp's existing conventions.

---

## Next Steps

1. **Start Here**: Read MULTI_WINDOW_QUICK_START.md (5 min)
2. **Deep Dive**: Read MULTI_WINDOW_ARCHITECTURE.md sections 1-3 (20 min)
3. **Implement**: Follow implementation roadmap above
4. **Test**: Use testing checklist in QUICK_START and ARCHITECTURE
5. **Optimize**: Reference performance tips in RESEARCH_SUMMARY

---

## Questions After Reading?

These documents should answer:
- ✅ What approach to use (WindowGroup vs NSWindowController vs others)
- ✅ Why this approach (research and rationale)
- ✅ How to implement (detailed code patterns)
- ✅ How to test (complete checklist)
- ✅ How to optimize (performance tips)
- ✅ How to troubleshoot (common pitfalls section)

If you have questions not covered, the Oracle (Codex) can be consulted for MacAmp-specific guidance:

```
codex -p "@MacAmpApp.swift @MULTI_WINDOW_ARCHITECTURE.md [Your Question]"
```

---

## Document Lineage

**Research Conducted**: 
- Codex Oracle consultation with MacAmp context
- Web search of WWDC 2024/2022 documentation
- Analysis of MacAmp codebase patterns
- Community best practices from Swift Forums
- macOS NSWindow and AppKit documentation

**Documents Generated**:
1. MULTI_WINDOW_QUICK_START.md - Executive summary and quick reference
2. MULTI_WINDOW_RESEARCH_SUMMARY.md - Research findings and decisions
3. MULTI_WINDOW_ARCHITECTURE.md - Complete implementation guide
4. README_MULTI_WINDOW.md - This index and navigation guide

---

**Last Updated**: November 8, 2025
**Version**: 1.0
**Status**: Complete and Ready for Implementation
