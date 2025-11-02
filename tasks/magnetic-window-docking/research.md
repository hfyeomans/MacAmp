# Magnetic Window Docking - Research

**Date:** 2025-10-23 (Updated: 2025-11-02)
**Task:** Refactor to multi-window with magnetic snapping
**Status:** Research Complete - Ready for Implementation
**Priority:** P3 (Architectural enhancement)
**Feasibility Score:** 8/10 (High complexity but achievable)

---

## 🎯 Executive Summary

**Goal:** Transform MacAmp from single-window to multi-window architecture matching classic Winamp:
- 3 independent NSWindows (Main, Equalizer, Playlist)
- Magnetic snapping on all edges (10px threshold)
- Group movement when docked (cluster detection via BFS)
- Position persistence
- Borderless windows with custom drag areas

**Current State:** Single UnifiedDockView containing all 3 windows
**Target State:** 3 separate NSWindows with WindowSnapManager coordination
**Estimated Effort:** 10-16 hours across 5 implementation phases
**Key Discovery:** WindowSnapManager.swift already exists with 10px snap, cluster detection, and multi-monitor support!

---

## 🔍 Existing Implementation Discovery

### WindowSnapManager.swift Analysis

**Location:** `MacAmpApp/Utilities/WindowSnapManager.swift` (lines 1757-1887 in MACAMP_ARCHITECTURE_GUIDE.md)

**Already Implemented:**
- ✅ **10px Snap Threshold** via `SnapUtils.near`
- ✅ **Cluster Detection** via `connectedCluster` method (depth-first search)
- ✅ **Screen Edge Snapping** via `SnapUtils.snapWithin`
- ✅ **Multi-Monitor Support** with virtual coordinate space transformation
- ✅ **Connection Detection** via `boxesAreConnected` checking overlap + proximity
- ✅ **Feedback Prevention** via `isAdjusting` flag

**Key Methods:**
```swift
// File: MacAmpApp/Utilities/WindowSnapManager.swift:33-136
func windowDidMove(_ notification: Notification) {
    // 1. Convert to top-left coordinate space
    // 2. Find connected cluster (BFS)
    // 3. Move entire cluster together
    // 4. Snap cluster to other windows + screen edges
}

// File: MacAmpApp/Utilities/WindowSnapManager.swift:139-155
private func boxesAreConnected(_ a: Box, _ b: Box) -> Bool {
    // Check if edges are within 10px and have overlap
}

// File: MacAmpApp/Utilities/WindowSnapManager.swift:157-171
private func connectedCluster(start: ObjectIdentifier, boxes: [ObjectIdentifier: Box]) -> Set<ObjectIdentifier> {
    // Depth-first search to find all connected windows
}
```

**What's Missing:**
The WindowSnapManager exists but is NOT yet integrated because:
1. MacAmp uses a single UnifiedDockView, not separate NSWindows
2. No window registration calls to `WindowSnapManager.shared.register(window:kind:)`
3. Architecture must be refactored to create 3 NSWindows first

---

## 📹 Video Frame Analysis

**Source:** `ScreenRecording10-23.mov` (extracted 40 frames total)

### Observed Behavior - Frame by Frame:

**Frames 001-010: Docked Configuration**
- All 3 windows stacked vertically (perfectly aligned)
- Main window (top) - 275×116px
- Equalizer (middle) - 275×116px
- Playlist (bottom) - 275×232px (taller, variable height)
- Zero pixel gap between windows
- Perfect horizontal alignment (left edges flush)

**Frame 020: DETACHMENT DEMONSTRATED ✨**
- Main + Equalizer still docked (top-left position)
- **Playlist SEPARATED** (moved to lower-right independently)
- Cursor visible over playlist titlebar (being dragged)
- Shows windows can exist in separate locations
- No visual connection when detached

**Frame 030: Independent State Maintained**
- Windows remain separated
- Each maintains independent position
- Demonstrates persistent detachment

### Key Observations:

**Docked State:**
- Zero pixel gap between windows when docked
- Perfect horizontal alignment (left edges flush)
- Each has independent titlebar
- Visual continuity suggests single unit

**Detached State:**
- Windows move completely independently
- No positional constraints
- Can be positioned anywhere on screen
- Original docked windows maintain their connection

**Critical Behaviors Demonstrated:**
1. ✅ Windows can be docked (frames 1-10)
2. ✅ Windows can be separated by dragging (frame 20)
3. ✅ Partial groups maintained (Main+EQ stay docked when Playlist detaches)
4. ✅ Each window independently draggable
5. ✅ Cursor interaction with individual titlebars

### Frame-by-Frame Technical Analysis

**Frames 1-10 (Detail 1-5): Initial State**
- All windows perfectly docked vertically
- Main (top), Equalizer (middle), Playlist (bottom)
- Zero-pixel gaps
- Windows appear "locked" in docked state

**Detail 6-15: Cursor Movement Phase**
- Cursor moves from bottom-right toward Playlist window
- No visual feedback during cursor movement
- Windows remain perfectly docked

**Detail 16-29: Detachment Sequence**
- Frame 16-20: Playlist begins detachment
- Frame 21-28: Progressive separation of Playlist
- Main + Equalizer maintain docked relationship
- Gap between Equalizer and Playlist increases
- **No "snap back" behavior observed**

**Detail 30: Final State**
- Main + Equalizer = 2-window docked unit (top-left)
- Playlist = independent window (center-bottom)
- Approximately 100+ pixel gap

**Snap Distance Estimation:** 10-15 pixels (standard Winamp behavior)

---

## 🏗️ Current MacAmp Architecture

### Single-Window Approach

**File:** `MacAmpApp/Views/UnifiedDockView.swift`
- Single NSWindow containing all 3 views
- VStack layout stacks windows vertically
- No titlebar (`.windowStyle(.hiddenTitleBar)`)
- Conditional rendering via `DockingController`

**File:** `MacAmpApp/ViewModels/DockingController.swift`
- `@Published var showMain/showPlaylist/showEqualizer: Bool`
- Controls visibility, not position
- No concept of magnetic snapping

### Limitations of Current Approach:
- ❌ Cannot separate windows
- ❌ Cannot drag windows independently
- ❌ No magnetic snapping
- ❌ All-or-nothing movement
- ✅ Simple state management
- ✅ No z-order complexity

---

## 🎯 Double-Size Mode Implementation (Completed 2025-10-30)

**Task:** `tasks/double-size-button/`
**Branch:** `double-sized-button`
**Commits:** bcc4582, dc48d29, 6e7cf10, a4d2d2d
**Status:** ✅ Implemented with unified window architecture

### Architecture Decision

**Implemented double-size mode WITHOUT separating windows first.**

**Rationale:**
- Magnetic window docking is complex (10-16 hours, P3 priority)
- Double-size mode needed sooner
- Can work with current unified window architecture
- When windows separate, scaling logic will move to individual NSWindows

### Implementation Details (Reference for Future Magnetic Docking)

**Files Modified:**
1. `AppSettings.swift` - Added `isDoubleSizeMode: Bool` with @AppStorage
2. `UnifiedDockView.swift` - Scaling logic (THIS NEEDS TO MOVE when windows separate)
3. `WinampMainWindow.swift` - D button + O, A, I, V scaffolded buttons
4. `SkinSprites.swift` - Clutter bar button sprites

**Scaling Architecture (Unified Window):**

```swift
// UnifiedDockView.swift - Lines 238-261

/// Returns base size without scaling
private func baseNaturalSize(for type: DockPaneType) -> CGSize {
    switch type {
    case .main: return WinampSizes.main        // 275×116
    case .equalizer: return WinampSizes.equalizer  // 275×116
    case .playlist: return WinampSizes.playlistBase  // 275×232
    }
}

/// Returns size with double-size scaling applied
private func naturalSize(for type: DockPaneType) -> CGSize {
    let baseSize = baseNaturalSize(for: type)
    let scale: CGFloat = settings.isDoubleSizeMode ? 2.0 : 1.0
    return CGSize(width: baseSize.width * scale, height: baseSize.height * scale)
}

// Applied to each window:
windowContent(for: pane.type)
    .scaleEffect(scale, anchor: .topLeading)  // Scale content
    .frame(width: baseSize.width * scale,      // Scale frame
           height: baseSize.height * scale)
```

### 🚨 CRITICAL: What Needs to Change for Magnetic Docking

When implementing separate NSWindows, **each window must handle its own double-size scaling.**

**Current (Unified):**
- UnifiedDockView handles scaling for all 3 windows
- Single `.scaleEffect()` and frame calculation per window
- Unified macOS window resizes automatically

**Future (Magnetic Docking):**
Each independent NSWindow will need:

1. **Individual Window Size Calculation:**
```swift
// Per-window WindowGroup
WindowGroup("Main", id: "main") {
    WinampMainWindow()
}
.defaultSize(
    width: settings.isDoubleSizeMode ? 550 : 275,
    height: settings.isDoubleSizeMode ? 232 : 116
)

// OR use programmatic NSWindow sizing:
func updateWindowSize(for window: NSWindow) {
    let scale: CGFloat = AppSettings.instance().isDoubleSizeMode ? 2.0 : 1.0
    let baseSize = windowBaseSize(for: window.identifier)
    window.setFrame(
        NSRect(
            origin: window.frame.origin,
            size: NSSize(
                width: baseSize.width * scale,
                height: baseSize.height * scale
            )
        ),
        display: true,
        animate: true
    )
}
```

2. **Content Scaling:**
```swift
// Each window view needs .scaleEffect()
struct WinampMainWindow: View {
    @Environment(AppSettings.self) var settings

    var body: some View {
        ZStack {
            // Window content at 1x coordinates...
        }
        .scaleEffect(
            settings.isDoubleSizeMode ? 2.0 : 1.0,
            anchor: .topLeading
        )
        .frame(
            width: settings.isDoubleSizeMode ? 550 : 275,
            height: settings.isDoubleSizeMode ? 232 : 116
        )
    }
}
```

3. **Synchronized Scaling:**
All 3 windows must scale together when D is clicked:
```swift
// When isDoubleSizeMode changes:
func handleDoubleSizeModeChange() {
    // Update all 3 windows simultaneously
    for window in [mainWindow, eqWindow, playlistWindow] {
        updateWindowSize(for: window)
    }

    // Maintain relative positions (magnetic docking)
    maintainDockedPositions()
}
```

4. **Magnetic Snapping at 2x:**
Snap detection must work at both scales:
```swift
func checkSnap(draggedWindow: NSWindow) -> SnapPosition? {
    let scale: CGFloat = settings.isDoubleSizeMode ? 2.0 : 1.0
    let threshold: CGFloat = 15 * scale  // Scale threshold too!

    // Check edges at scaled dimensions...
}
```

5. **Docking State Preservation:**
When doubling size, docked windows must:
- Scale together
- Maintain alignment
- Preserve docking relationships
- Update snap positions

### Code to Migrate from UnifiedDockView

**When implementing magnetic docking, take this scaling logic:**

```swift
// From: tasks/double-size-button/state.md
// Lines: See UnifiedDockView.swift implementation

// 1. Base size constants (keep in WinampSizes)
static let main = CGSize(width: 275, height: 116)
static let mainDouble = CGSize(width: 550, height: 232)

// 2. Scale factor calculation
let scale: CGFloat = settings.isDoubleSizeMode ? 2.0 : 1.0

// 3. .scaleEffect() for content scaling
.scaleEffect(scale, anchor: .topLeading)

// 4. Frame calculation for window size
.frame(width: baseSize.width * scale, height: baseSize.height * scale)

// 5. Animation for smooth transitions
.animation(.easeInOut(duration: 0.2), value: settings.isDoubleSizeMode)
```

### Known Issues to Fix When Implementing Magnetic Docking

**Playlist Menu Buttons Don't Scale (2025-10-30):**

When double-size mode is active, playlist menu buttons (ADD, REM, SEL, MISC, LIST OPTS) don't expand with the window.

**Root Cause:**
- Playlist window has independent variable height (resizable)
- Menu buttons use absolute positioning
- In classic Winamp, playlist is independently resizable (not just double-size)
- Main and EQ windows only support double-size (fixed dimensions)

**Fix Required for Magnetic Docking:**
When playlist becomes a separate NSWindow:
1. Playlist window needs its own scale factor OR dynamic button positioning
2. Menu buttons should scale with window OR reposition based on window height
3. Main/EQ windows only scale with double-size mode (fixed dimensions)
4. Playlist window supports both double-size AND independent resize

---

## 🔍 Webamp Implementation Analysis

**Source:** `webamp_clone` codebase analysis (JavaScript/React)

### Architecture Summary

**Window Implementation:**
- Type: React components rendered as positioned `div` elements
- Positioning: `position: absolute` with `transform: translate(x, y)`
- Components: `MainWindow`, `EqualizerWindow`, `PlaylistWindow`
- Manager: `WindowManager.tsx` orchestrates all 3 windows

**State Management:**
- Framework: Redux
- Reducer: `js/reducers/windows.ts`
- State Shape:
```typescript
{
  genWindows: {
    [windowId]: {
      open: boolean,
      shade: boolean,
      size: {width, height},
      position: {x, y}
    }
  },
  focused: string,  // Current window ID
  windowOrder: string[],  // Z-index stacking
  positionsAreRelative: boolean
}
```

### Magnetic Snapping Logic

**Constants:**
```typescript
const SNAP_DISTANCE = 15;  // pixels
```

**Core Algorithm (`js/snapUtils.ts`):**

**1. Proximity Detection:**
```typescript
const near = (a, b) => Math.abs(a - b) < SNAP_DISTANCE;
```

**2. Overlap Detection:**
```typescript
const overlapX = (boxA, boxB) => {
  return !(right(boxA) < left(boxB) || left(boxA) > right(boxB));
};

const overlapY = (boxA, boxB) => {
  return !(bottom(boxA) < top(boxB) || top(boxA) > bottom(boxB));
};
```

**3. Snap Calculation:**
```typescript
export const snap = (boxA: Box, boxB: Box) => {
  let x, y;

  // Horizontal snapping (requires vertical overlap)
  if (overlapY(boxA, boxB)) {
    if (near(left(boxA), right(boxB))) {
      x = right(boxB);  // Snap left edge to right edge
    } else if (near(right(boxA), left(boxB))) {
      x = left(boxB) - boxA.width;  // Snap right edge to left edge
    } else if (near(left(boxA), left(boxB))) {
      x = left(boxB);  // Align left edges
    } else if (near(right(boxA), right(boxB))) {
      x = right(boxB) - boxA.width;  // Align right edges
    }
  }

  // Vertical snapping (requires horizontal overlap)
  if (overlapX(boxA, boxB)) {
    if (near(top(boxA), bottom(boxB))) {
      y = bottom(boxB);  // Snap top to bottom
    } else if (near(bottom(boxA), top(boxB))) {
      y = top(boxB) - boxA.height;  // Snap bottom to top
    } else if (near(top(boxA), top(boxB))) {
      y = top(boxB);  // Align tops
    } else if (near(bottom(boxA), bottom(boxB))) {
      y = bottom(boxB) - boxA.height;  // Align bottoms
    }
  }

  return { x, y };
};
```

### Group Movement (Docked Windows)

**Connection Detection (`js/snapUtils.ts`):**

```typescript
// Recursively find all connected windows
export const traceConnection = (
  windowId: string,
  windows: WindowInfo[],
  visited: Set<string> = new Set()
): Set<string> => {
  if (visited.has(windowId)) return visited;
  visited.add(windowId);

  const window = windows.find(w => w.id === windowId);
  if (!window) return visited;

  // Find all windows abutting this one
  for (const other of windows) {
    if (other.id !== windowId && abuts(window, other)) {
      traceConnection(other.id, windows, visited);
    }
  }

  return visited;
};

// Check if two windows are touching
const abuts = (a: WindowInfo, b: WindowInfo) => {
  const distance = Math.min(
    Math.abs(a.position.x + a.size.width - b.position.x),
    Math.abs(b.position.x + b.size.width - a.position.x),
    Math.abs(a.position.y + a.size.height - b.position.y),
    Math.abs(b.position.y + b.size.height - a.position.y)
  );
  return distance < 2;  // Touching if < 2px apart
};
```

**Movement Synchronization (`WindowManager.tsx`):**

```typescript
const useHandleMouseDown = (windowId) => {
  return (e) => {
    // Only drag main window moves connected group
    if (windowId === 'main') {
      const connectedIds = traceConnection(windowId, allWindows);
      const windowsToMove = Array.from(connectedIds);

      // Calculate bounding box of group
      const boundingBox = getBoundingBox(windowsToMove);

      // On mouse move: apply delta to all windows in group
      const handleMouseMove = (moveEvent) => {
        const delta = {
          x: moveEvent.clientX - startX,
          y: moveEvent.clientY - startY
        };

        // Update positions for all windows in group
        const newPositions = {};
        for (const id of windowsToMove) {
          newPositions[id] = {
            x: originalPositions[id].x + delta.x,
            y: originalPositions[id].y + delta.y
          };
        }

        dispatch(updateWindowPositions(newPositions));
      };
    }
  };
};
```

### Key Insights for macOS Implementation

**1. Snap Distance:** 15 pixels (industry standard)
**2. Connection Graph:** Dynamically computed on drag start
**3. Group Movement:** Only main window drag moves group (in Webamp)
**4. Docking State:** Not persisted, computed from positions
**5. Edge Cases Webamp Handles:**
   - Window close/shade triggers layout adjustment
   - Z-order via windowOrder array
   - Relative vs absolute positioning mode

### Webamp → macOS Translation

| Webamp Concept | macOS Equivalent |
|---------------|------------------|
| `div` with `position: absolute` | `NSWindow` with custom frame |
| `transform: translate(x, y)` | `window.setFrame(...)` |
| `onMouseDown` + window listeners | `NSEvent` monitoring or NSWindowController override |
| Redux state | `@StateObject` + `@Published` properties |
| `traceConnection()` BFS | Same algorithm in Swift |
| localStorage | UserDefaults |
| CSS z-index via array | `window.level` + `orderFront()` |

**Key macOS APIs:**
```swift
// Window positioning
window.setFrame(NSRect, display: Bool, animate: Bool)

// Get window frame
window.frame  // NSRect with origin (bottom-left in screen coordinates!)

// Z-order
window.orderFront(nil)  // Bring to front
window.level = .floating  // Keep above others

// Drag tracking
NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged])
```

### Critical Webamp Files Referenced
- `packages/webamp/js/snapUtils.ts` - Core snapping algorithm
- `packages/webamp/js/components/WindowManager.tsx` - Drag handling
- `packages/webamp/js/resizeUtils.ts` - Layout maintenance on resize/shade
- `packages/webamp/js/reducers/windows.ts` - State shape

### Lessons Learned from Webamp

1. **Don't persist connections** - Compute from positions (simpler, fewer bugs)
2. **Use BFS/DFS** - Recursive connection tracing handles complex graphs
3. **Bounding box approach** - Maintain relative positions during group drag
4. **Special case main window** - Only main drag moves group (UX clarity)
5. **Snap on all 4 edges** - Left, right, top, bottom + alignment variants
6. **15px threshold** - Feels right, industry standard

---

## 📚 macOS Multi-Window Patterns

### SwiftUI WindowGroup API (macOS 13+)

```swift
@main
struct MacAmpApp: App {
    var body: some Scene {
        WindowGroup("Main", id: "main") {
            WinampMainWindow()
        }
        .defaultSize(width: 275, height: 116)

        WindowGroup("Equalizer", id: "equalizer") {
            WinampEqualizerWindow()
        }
        .defaultSize(width: 275, height: 116)

        WindowGroup("Playlist", id: "playlist") {
            WinampPlaylistWindow()
        }
        .defaultSize(width: 275, height: 232)
    }
}
```

**Issues:**
- Each WindowGroup creates independent window lifecycle
- No built-in magnetic snapping
- Complex to synchronize movement
- Need custom snap detection

### NSWindowController Approach (AppKit)

```swift
class WinampWindowController: NSWindowController {
    var snapManager: WindowSnapManager

    override func mouseDragged(with event: NSEvent) {
        // Detect nearby windows
        // Calculate snap positions
        // Move docked windows together
    }
}
```

**Better for:**
- Fine-grained window control
- Custom drag behavior
- Magnetic snapping logic
- Z-order management

---

## ⚠️ macOS Implementation Gotchas

1. **Coordinate System:** NSWindow uses bottom-left origin, not top-left!
2. **Multi-Monitor:** NSScreen.screens array, different coordinate spaces
3. **Mission Control:** Windows may be in different Spaces
4. **Full Screen:** Need to handle full-screen windows differently
5. **Accessibility:** VoiceOver needs proper window roles/titles

---

## 💡 Feasibility Assessment (Gemini Analysis)

### Complexity Ratings (1-10 scale, 1=trivial, 10=extremely complex)

**Overall Implementation Complexity: 8/10**
- Major architectural refactor
- Custom window dragging required
- Coordinate system transformations
- State synchronization across windows

**Risk of Breaking Existing Features: 7/10**
- Touches core UI structure
- Double-size mode must be migrated carefully
- State synchronization complexity
- Coordinate math errors could cause visual bugs

**Time Estimate Validity: ✅ CONFIRMED**
- 10-16 hour estimate is valid
- Well-structured 5-phase breakdown
- Reasonable for experienced developer

### Top 3 Technical Blockers

1. **Custom Window Dragging Performance**
   - Risk: Laggy, jerky, or unstable movement
   - Snap detection runs on every mouse-drag event
   - Must feel as good as native window movement

2. **State Synchronization**
   - Risk: Race conditions or desynchronization
   - Double-size mode must apply to all windows simultaneously
   - Maintaining relative docked positions is complex

3. **Coordinate System Management**
   - Risk: Windows snap incorrectly or position off-screen
   - Translation between SwiftUI top-left and AppKit bottom-left
   - Multi-monitor setups complicate coordinate math

### Best Approach for Borderless Draggable Windows

**Recommended:** Standard NSWindow with borderless configuration

```swift
window.titleVisibility = .hidden
window.titlebarAppearsTransparent = true
```

- Capture `mouseDown` on custom title bar area in SwiftUI
- Trigger custom drag loop that moves window programmatically
- Don't use NSPanel (not appropriate for primary windows)
- Don't subclass NSWindow for mouseDown (less clean)

### Migration Strategy

**Complete Cutover on Feature Branch** ✅

- Remove `UnifiedDockView.swift`
- Define 3 new `WindowGroup`s in `MacAmpApp.swift`
- Build and test entire multi-window system on branch
- Merge when feature is complete

**Rationale:**
- Two paradigms (single vs multi-window) too different to coexist
- Feature flag would add complexity without benefit
- Clean cutover is cleaner and safer

---

## 📋 Implementation Phases (Refined)

### Phase 1: Separate Windows (2-3 hours)
- Convert UnifiedDockView to 3 NSWindows
- Maintain current stacked layout (no movement yet)
- Each window independent but positioned correctly
- State sharing via Environment
- Migrate double-size scaling logic to each window

### Phase 2: Window Snap Detection (3-4 hours)
- Integrate existing WindowSnapManager.swift
- Register all 3 windows with snap manager
- Implement edge detection during drag
- Test 10px snap threshold
- Screen edge snapping

### Phase 3: Group Movement (2-3 hours)
- Use existing `connectedCluster` method
- Synchronize movement of docked windows
- Maintain relative positions
- Handle complex docking (all 3 connected)

### Phase 4: Custom Drag Handling (2-3 hours)
- Override default window dragging
- Implement custom drag loop
- Coordinate with WindowSnapManager
- Ensure smooth performance

### Phase 5: State Persistence (1 hour)
- Save window positions to UserDefaults
- Save docking relationships
- Restore on app launch
- Handle edge cases (off-screen, monitor changes)

**Total Estimated Time:** 10-16 hours

---

## 🎓 Design Decisions

### Answered Questions:

1. **Window Lifecycle:** All 3 windows always exist (registered with WindowSnapManager)
2. **Docking State:** WindowSnapManager.shared singleton manages connections
3. **Snap Feedback:** Implicit (no visual indicators, like classic Winamp)
4. **Close Behavior:** Cmd+W closes individual window (not all docked)
5. **Menu Bar:** "Show Main/EQ/Playlist" shows hidden windows (always exist)
6. **Shade Mode:** Deferred to future implementation

### Open Questions:

7. **Double-Size Synchronization:** How to ensure all 3 windows scale together?
8. **Playlist Resize:** How does independent resize interact with double-size?
9. **Performance Monitoring:** What metrics to track during drag operations?

---

## 📂 Critical Files to Modify

**Existing (Keep/Extend):**
- `MacAmpApp/Utilities/WindowSnapManager.swift` - Already complete!
- `MacAmpApp/Models/AppSettings.swift` - Add window position storage
- `MacAmpApp/Views/WinampMainWindow.swift` - Add window registration
- `MacAmpApp/Views/WinampEqualizerWindow.swift` - Add window registration
- `MacAmpApp/Views/WinampPlaylistWindow.swift` - Add window registration

**To Remove:**
- `MacAmpApp/Views/UnifiedDockView.swift` - Delete entirely

**To Modify:**
- `MacAmpApp/MacAmpApp.swift` - Replace single WindowGroup with 3

**To Create:**
- `MacAmpApp/Utilities/WindowAccessor.swift` - Bridge SwiftUI → NSWindow
- `MacAmpApp/ViewModels/WindowCoordinator.swift` - Manage 3-window lifecycle

---

**Research Status:** ✅ COMPLETE
**Feasibility:** 8/10 (High complexity, achievable with existing WindowSnapManager)
**Blockers Identified:** Custom drag performance, state sync, coordinate systems
**Next:** Create detailed implementation plan and todos
