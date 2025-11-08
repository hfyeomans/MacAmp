# Magnetic Docking Foundation - Research

**Task ID**: magnetic-docking-foundation  
**Created**: 2025-11-08  
**Purpose**: Foundation for multi-window architecture (enables Video/Milkdrop windows)  
**Scope**: Break out Main/EQ/Playlist + basic magnetic snapping  
**Timeline**: 10-14 days (foundation only, not full feature set)

---

## Executive Summary

### What This Task Is

**Foundation Phase** for MacAmp's multi-window architecture:
- Break out Main/EQ/Playlist from unified window into 3 independent NSWindows
- Implement basic magnetic snapping (15px threshold)
- Set up infrastructure for future windows (Video, Milkdrop)
- NOT a complete polished implementation (defer some features)

### Why We Need This

**Blocker Discovered**: Video and Milkdrop windows cannot be implemented without multi-window foundation.

**Oracle's Verdict** (from milk-drop-video-support task):
> "Current plan mounts views inside WinampMainWindow - NO actual NSWindow infrastructure. This is a NO-GO."

**Strategic Decision**: Implement magnetic docking foundation FIRST, then add Video/Milkdrop as additional windows.

### Scope: Foundation vs Full Implementation

**FOUNDATION (This Task)**:
- ✅ 3 independent NSWindowControllers (Main, EQ, Playlist)
- ✅ WindowSnapManager integration (15px snap)
- ✅ Basic cluster movement (group dragging)
- ✅ Custom drag regions (borderless windows)
- ✅ Delegate multiplexer pattern
- ✅ Basic double-size coordination
- ✅ Basic persistence

**DEFERRED to Later** (Polish Features):
- ⏳ Playlist resize-aware docking
- ⏳ Z-order cluster focus management
- ⏳ Scaled snap threshold (30px at 2x)
- ⏳ Advanced persistence (off-screen detection)
- ⏳ Accessibility polish

**Timeline**: 10-14 days foundation vs 18-24 days full

---

## Research Sources (Synthesized)

This research combines findings from:

1. **tasks/magnetic-window-docking/** (Original research, 2025-10-23 to 2025-11-02)
   - Webamp implementation analysis
   - Frame-by-frame video analysis (40 frames)
   - WindowSnapManager discovery
   - Oracle architectural review
   - ULTRATHINK synthesis

2. **tasks/milk-drop-video-support/** (Recent research, 2025-11-08)
   - Multi-window architecture requirements
   - Oracle's B- grade feedback (critical issues)
   - Two-window Video/Milkdrop discovery
   - Strategic sequencing decision

3. **docs/MULTI_WINDOW_ARCHITECTURE.md** (2025-11-08)
   - SwiftUI WindowGroup patterns
   - NSWindow lifecycle management
   - State sharing across windows
   - Window positioning strategies

---

## Part 1: Existing WindowSnapManager Analysis

**CRITICAL DISCOVERY**: MacAmp already has complete magnetic snapping implementation!

**Location**: `MacAmpApp/Utilities/WindowSnapManager.swift`

### Already Implemented ✅

1. **15px Snap Threshold** (SnapUtils.SNAP_DISTANCE = 15)
2. **Cluster Detection** via `connectedCluster()` (depth-first search)
3. **Screen Edge Snapping** via `SnapUtils.snapWithin()`
4. **Multi-Monitor Support** with coordinate space transformation
5. **Connection Detection** via `boxesAreConnected()` (overlap + proximity)
6. **Feedback Prevention** via `isAdjusting` flag

### Key Methods

```swift
// Register window with snap manager
func register(window: NSWindow, kind: WindowKind)

// Handle window movement
func windowDidMove(_ notification: Notification) {
    // 1. Convert to top-left coordinate space
    // 2. Find connected cluster (BFS)
    // 3. Move entire cluster together
    // 4. Snap cluster to other windows + screen edges
}

// Find connected windows
private func connectedCluster(start: ObjectIdentifier, boxes: [ObjectIdentifier: Box]) -> Set<ObjectIdentifier>

// Check if two windows are connected
private func boxesAreConnected(_ a: Box, _ b: Box) -> Bool
```

### What's Missing

WindowSnapManager exists but is **NOT INTEGRATED** because:
- MacAmp currently uses single UnifiedDockView (not separate NSWindows)
- No window registration calls to `WindowSnapManager.shared.register()`
- Must refactor to 3 NSWindows before snap manager can be used

---

## Part 2: Current MacAmp Architecture

### Single-Window Design

**Current State**:
```
┌────────────────────────────────────┐
│ Single NSWindow                    │
├────────────────────────────────────┤
│ UnifiedDockView (SwiftUI)          │
│ ┌─────────┐                        │
│ │  Main   │  275×116               │
│ ├─────────┤                        │
│ │   EQ    │  275×116               │
│ ├─────────┤                        │
│ │Playlist │  275×232 (resizable)   │
│ └─────────┘                        │
└────────────────────────────────────┘
```

**Files**:
- `MacAmpApp/Views/UnifiedDockView.swift` - Contains all 3 windows
- `MacAmpApp/ViewModels/DockingController.swift` - Manages visibility (not position)
- Single `.windowStyle(.hiddenTitleBar)`

### Target Foundation Architecture

**Foundation Goal**:
```
┌─────────┐  ┌────┐  ┌──────────┐
│  Main   │  │ EQ │  │ Playlist │
│ NSWindow│  │    │  │  NSWindow│
└─────────┘  └────┘  └──────────┘
    ↓           ↓          ↓
WindowSnapManager (15px magnetic snap)
    ↓
All 3 windows snap together
```

**Future (After Foundation)**:
```
┌─────────┐  ┌────┐  ┌──────────┐  ┌───────┐  ┌──────────┐
│  Main   │  │ EQ │  │ Playlist │  │ Video │  │ Milkdrop │
└─────────┘  └────┘  └──────────┘  └───────┘  └──────────┘
                All snap together!
```

---

## Part 3: NSWindowController vs WindowGroup Decision

### Oracle's Critical Feedback

**Issue**: Original plan used `WindowGroup(id:)` approach

**Oracle's Concern**:
> "Raw WindowGroups risk duplicate instances and flaky close/restore behaviour. Prefer dedicated NSWindowControllers."

### Decision: NSWindowController Architecture ✅

**Why NSWindowController**:
1. ✅ Guarantees singleton windows (one instance per window)
2. ✅ Full lifecycle control (predictable create/destroy)
3. ✅ Trivial menu synchronization ("Show Main" shows single instance)
4. ✅ Proven pattern for multi-window apps
5. ✅ No duplicate window bugs
6. ✅ Proper delegate control

**Why NOT WindowGroup**:
1. ❌ Creates windows on-demand (not singletons)
2. ❌ Multiple instances possible (menu commands create duplicates)
3. ❌ Close behavior automatic (can't customize to hide instead of destroy)
4. ❌ Restoration opaque
5. ❌ Menu sync complex

### Implementation Pattern

```swift
// WindowCoordinator.swift - Main actor singleton
@MainActor
class WindowCoordinator: ObservableObject {
    static let shared = WindowCoordinator()
    
    private let mainController: NSWindowController
    private let eqController: NSWindowController
    private let playlistController: NSWindowController
    
    var mainWindow: NSWindow? { mainController.window }
    var eqWindow: NSWindow? { eqController.window }
    var playlistWindow: NSWindow? { playlistController.window }
    
    init() {
        // Create 3 NSWindowControllers (singletons)
        // Configure windows (borderless, transparent titlebar)
        // Register with WindowSnapManager
    }
    
    // Menu commands
    func showMain() { mainWindow?.makeKeyAndOrderFront(nil) }
    func hideMain() { mainWindow?.orderOut(nil) }
    // ... similar for EQ and Playlist
}
```

---

## Part 4: Critical Issues from Oracle (B- Grade)

### Issue #1: No Actual NSWindow Infrastructure ⚠️ SHOWSTOPPER

**Problem**: Original Video/Milkdrop plan mounted views inside WinampMainWindow
```swift
// WRONG - Still in unified window:
if appSettings.showVideoWindow {
    VideoWindowView()  // ❌ Inside WinampMainWindow
}
```

**Solution**: True NSWindowController architecture
```swift
// CORRECT - Independent NSWindow:
WindowGroup("Video", id: "video") {
    VideoWindowView()
}
// Or NSWindowController for singletons
```

### Issue #2: Borderless Window Drag Regions ⚠️ CRITICAL

**Oracle's Warning**:
> "Perform drag-region work immediately after splitting windows; otherwise users lose the ability to move borderless windows."

**Problem**: MacAmp uses borderless windows (custom chrome)
- Standard NSWindow titlebars hidden
- No default drag mechanism
- Windows become immovable without custom drag

**Solution**: Custom titlebar drag regions (Phase 1B - CRITICAL PRIORITY)

```swift
struct TitlebarDragRegion: View {
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 14)  // Winamp titlebar height
            .background(WindowAccessor { nsWindow in
                // Configure custom drag handling
            })
    }
}
```

### Issue #3: Delegate Conflicts ⚠️ ARCHITECTURAL

**Problem**: WindowSnapManager sets `window.delegate = self`
- Takes over entire delegate
- Custom close/resize/focus handlers conflict

**Solution**: Delegate multiplexer pattern
```swift
class WindowDelegateMultiplexer: NSWindowDelegate {
    var delegates: [NSWindowDelegate] = []
    
    func windowDidMove(_ notification: Notification) {
        delegates.forEach { $0.windowDidMove?(notification) }
    }
    // ... forward all delegate methods
}
```

---

## Part 5: Webamp Implementation Reference

### Architecture (JavaScript/React)

**Webamp Windows**:
- MainWindow, EqualizerWindow, PlaylistWindow
- Positioned `div` elements (`position: absolute`)
- Redux state management

**Magnetic Snapping**:
```typescript
// snapUtils.ts
const SNAP_DISTANCE = 15;  // pixels

const near = (a, b) => Math.abs(a - b) < SNAP_DISTANCE;

export const snap = (boxA: Box, boxB: Box) => {
  // Horizontal snapping (requires vertical overlap)
  if (overlapY(boxA, boxB)) {
    if (near(left(boxA), right(boxB))) x = right(boxB);
    // ... more snap cases
  }
  
  // Vertical snapping (requires horizontal overlap)
  if (overlapX(boxA, boxB)) {
    if (near(top(boxA), bottom(boxB))) y = bottom(boxB);
    // ... more snap cases
  }
  
  return { x, y };
};
```

**Cluster Movement**:
```typescript
// Recursively find connected windows (BFS)
export const traceConnection = (windowId, windows, visited = new Set()) => {
  if (visited.has(windowId)) return visited;
  visited.add(windowId);
  
  const window = windows.find(w => w.id === windowId);
  for (const other of windows) {
    if (other.id !== windowId && abuts(window, other)) {
      traceConnection(other.id, windows, visited);
    }
  }
  
  return visited;
};
```

**Key Insights**:
1. 15px snap distance (industry standard)
2. BFS for cluster detection
3. Move entire cluster when main window dragged
4. Snap detection on every mouse move
5. Don't persist connections (compute from positions)

---

## Part 6: Strategic Sequencing (Oracle Recommendation)

### Why Magnetic Docking MUST Come First

**From Oracle Consultation** (gpt-5-codex, high reasoning):

> "Commit to Option 1 (magnetic docking foundation first) so the Main/EQ/Playlist extraction, WindowGroup pattern, and multi-window snapping are solved before layering in Video/Milkdrop."

**Rationale**:
1. ✅ Establishes NSWindowController pattern
2. ✅ Video/Milkdrop just follow the pattern
3. ✅ No future rework needed
4. ✅ Consistent architecture
5. ✅ Each phase is self-contained and testable

### Two-Phase Roadmap

**Phase 1 (THIS TASK): Magnetic Docking Foundation** (10-14 days)
- Break out Main/EQ/Playlist into 3 NSWindowControllers
- Implement WindowSnapManager integration
- Custom drag regions (borderless windows)
- Delegate multiplexer
- Basic double-size coordination
- Basic persistence

**Phase 2 (NEXT TASK): Video/Milkdrop Windows** (8-10 days)
- Add Video window (follows established pattern)
- Add Milkdrop window (follows established pattern)
- VIDEO.bmp sprite parsing
- Butterchurn integration
- Register with WindowSnapManager (trivial)
- **All 5 windows snap together!**

**Total**: 18-24 days for complete multi-window + Video/Milkdrop

---

## Part 7: Foundation Scope Definition

### What's IN Scope (Foundation)

**Core Infrastructure**:
- ✅ NSWindowController architecture
- ✅ WindowCoordinator singleton
- ✅ 3 independent NSWindows (Main, EQ, Playlist)
- ✅ WindowSnapManager registration
- ✅ Basic magnetic snapping (15px threshold)
- ✅ Cluster movement (group dragging)
- ✅ Custom titlebar drag regions
- ✅ Delegate multiplexer
- ✅ Basic double-size synchronization
- ✅ Window position persistence (save/restore)

### What's OUT of Scope (Defer to Polish)

**Polish Features** (add later if needed):
- ⏳ Playlist resize-aware docking
- ⏳ Z-order cluster focus management
- ⏳ Scaled snap threshold (30px at 2x)
- ⏳ Advanced persistence (off-screen detection, monitor hotplug)
- ⏳ Accessibility enhancements (VoiceOver)
- ⏳ Mission Control behavior tuning

**Rationale**: Focus on getting infrastructure working, add polish incrementally.

---

## Part 8: File Structure Changes

### Files to CREATE (Foundation)

```
MacAmpApp/
├── ViewModels/
│   └── WindowCoordinator.swift        [NEW - Singleton window manager]
├── Windows/
│   ├── WinampMainWindowController.swift     [NEW - Main NSWindowController]
│   ├── WinampEqualizerWindowController.swift [NEW - EQ NSWindowController]
│   └── WinampPlaylistWindowController.swift  [NEW - Playlist NSWindowController]
└── Utilities/
    ├── WindowAccessor.swift           [NEW - SwiftUI → NSWindow bridge]
    └── WindowDelegateMultiplexer.swift [NEW - Delegate pattern]
```

### Files to MODIFY (Foundation)

```
MacAmpApp/
├── MacAmpApp.swift                    [MODIFY - Manual window creation]
├── Models/
│   ├── AppSettings.swift              [MODIFY - Window position storage]
│   └── DockingController.swift        [MODIFY - Update for multi-window]
└── Views/
    ├── WinampMainWindow.swift         [MODIFY - Add drag region]
    ├── WinampEqualizerWindow.swift    [MODIFY - Add drag region]
    └── WinampPlaylistWindow.swift     [MODIFY - Add drag region]
```

### Files to DELETE (Foundation)

```
MacAmpApp/Views/
└── UnifiedDockView.swift              [DELETE - Replace with 3 windows]
```

### Files UNCHANGED (Foundation)

```
MacAmpApp/Utilities/
└── WindowSnapManager.swift            [KEEP - Already complete!]
```

---

## Part 9: Implementation Phases (Foundation)

### Phase 1A: NSWindowController Setup (2-3 days)

**Goal**: Create 3 independent NSWindowControllers

**Tasks**:
- Create WindowCoordinator singleton
- Create 3 NSWindowController subclasses
- Configure borderless windows
- Position windows in default stack
- Connect menu commands
- Delete UnifiedDockView.swift

**Deliverable**: 3 independent windows (not draggable yet)

### Phase 1B: Drag Regions (2-3 days) - CRITICAL

**Goal**: Make borderless windows draggable

**Oracle's Priority**:
> "Must come immediately after Phase 1A - otherwise windows are immovable."

**Tasks**:
- Create WindowAccessor utility
- Add custom titlebar drag regions to all 3 views
- Implement NSEvent drag tracking
- Test independent window dragging

**Deliverable**: Fully draggable windows

### Phase 2: WindowSnapManager Integration (3-4 days)

**Goal**: Enable magnetic snapping

**Tasks**:
- Register 3 windows with WindowSnapManager
- Test 15px snap threshold
- Verify cluster detection works
- Test screen edge snapping
- Test multi-monitor support

**Deliverable**: Windows snap magnetically at 15px

### Phase 3: Delegate Multiplexer (1-2 days)

**Goal**: Resolve delegate conflicts

**Tasks**:
- Create WindowDelegateMultiplexer
- Register WindowSnapManager via multiplexer
- Test delegate forwarding
- Prepare for future delegates (resize, focus)

**Deliverable**: Extensible delegate pattern

### Phase 4: Double-Size Coordination (2-3 days)

**Goal**: All 3 windows scale together

**Tasks**:
- Migrate scaling logic from UnifiedDockView
- Synchronize window frame updates
- Maintain docked alignment during scale
- Test content scaling (scaleEffect)
- Test frame scaling (setFrame)

**Deliverable**: Double-size mode works with all 3 windows

### Phase 5: Basic Persistence (1-2 days)

**Goal**: Save/restore window positions

**Tasks**:
- Save window positions to UserDefaults
- Restore positions on launch
- Use default positions if no saved state
- Test persistence across restarts

**Deliverable**: Window layout persists

---

## Part 10: Success Criteria (Foundation)

### Must-Have (Foundation Complete)

**Core Functionality**:
- ✅ 3 independent NSWindows launch
- ✅ Windows can be dragged independently
- ✅ Magnetic snapping works (15px)
- ✅ Cluster movement works (drag main moves group)
- ✅ Windows can detach individually
- ✅ Windows can re-attach to form groups
- ✅ Double-size mode works with all windows
- ✅ Window positions persist

**Quality**:
- ✅ Smooth dragging (60fps target)
- ✅ No visual glitches
- ✅ No regressions in existing features
- ✅ Clean architecture (ready for Video/Milkdrop)

### Deferred Features (Post-Foundation)

**Polish** (add if time permits):
- ⏳ Playlist resize maintains docking
- ⏳ Z-order cluster focus
- ⏳ Scaled snap threshold (30px at 2x)
- ⏳ Off-screen position normalization
- ⏳ Accessibility polish

---

## Part 11: Key Discoveries

### Discovery #1: WindowSnapManager Exists (2025-10-23)
**Impact**: Saves 3-4 hours development time
**Status**: Already complete, just needs integration

### Discovery #2: 15px Snap Distance (2025-11-02)
**Source**: SnapUtils.swift:27
**Note**: Some docs incorrectly say 10px
**Fix**: All documentation updated to 15px

### Discovery #3: Oracle's B- Grade (2025-11-08)
**Finding**: Video/Milkdrop plan had no NSWindow infrastructure
**Impact**: Requires magnetic docking foundation FIRST
**Result**: Created this foundation task

### Discovery #4: NSWindowController vs WindowGroup (2025-11-08)
**Oracle**: NSWindowController is safer for singletons
**Impact**: Changed architecture approach
**Benefit**: Lower risk, better menu sync

---

## Part 12: Timeline Estimates

### Foundation Phase (This Task)

| Phase | Days | Cumulative |
|-------|------|------------|
| 1A: NSWindowController | 2-3 | 2-3 |
| 1B: Drag Regions | 2-3 | 4-6 |
| 2: Snap Integration | 3-4 | 7-10 |
| 3: Delegate Multiplexer | 1-2 | 8-12 |
| 4: Double-Size | 2-3 | 10-15 |
| 5: Basic Persistence | 1-2 | 11-17 |
| **Testing/Polish** | 1-2 | **12-19** |
| **TOTAL** | | **10-14 days** |

**Conservative Estimate**: 14 days with buffer

### After Foundation (Next Task)

**Video/Milkdrop Windows**: 8-10 days
- Follow established NSWindowController pattern
- Add VIDEO.bmp parsing
- Add Butterchurn integration
- Register with WindowSnapManager (trivial)

**Total to Full Multi-Window + Video/Milkdrop**: 18-24 days

---

## Part 13: Risks & Mitigations (Foundation)

| Risk | Severity | Mitigation |
|------|----------|------------|
| Drag regions feel sluggish | High | Profile with Instruments, optimize |
| Windows don't snap correctly | High | Extensive testing, coordinate validation |
| Double-size breaks alignment | High | Synchronized frame updates, testing |
| Delegate conflicts | Medium | Multiplexer pattern (Phase 3) |
| Position restoration fails | Medium | Bounds checking, fallback defaults |
| Memory leaks | Low | Proper NSWindowController cleanup |

**Overall Risk**: Medium-High (7/10 for foundation vs 8/10 for full)

---

## Part 14: Reference Implementation Patterns

### From Double-Size Button Task

**Pattern**: Scaling logic to migrate
```swift
// From UnifiedDockView.swift - MIGRATE to each window
let scale: CGFloat = settings.isDoubleSizeMode ? 2.0 : 1.0

.scaleEffect(scale, anchor: .topLeading)
.frame(width: baseSize.width * scale, height: baseSize.height * scale)
```

### From WindowSnapManager

**Pattern**: Already implemented, just register windows
```swift
// Register each window
WindowSnapManager.shared.register(window: mainWindow, kind: .main)
WindowSnapManager.shared.register(window: eqWindow, kind: .equalizer)
WindowSnapManager.shared.register(window: playlistWindow, kind: .playlist)

// That's it! Snapping happens automatically in windowDidMove
```

---

**Research Consolidated**: 2025-11-08  
**Sources**: 3 task directories + 1 architecture doc  
**Total Research Time**: ~15 hours (across all sources)  
**Next**: Create focused foundation plan
