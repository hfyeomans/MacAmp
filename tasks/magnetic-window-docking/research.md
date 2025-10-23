# Magnetic Window Docking - Research

**Date:** 2025-10-23
**Task:** Refactor to multi-window with magnetic snapping
**Status:** Research phase
**Priority:** P3 (Architectural enhancement)

---

## 🎯 Goal

Transform MacAmp from single-window to multi-window architecture matching classic Winamp:
- 3 independent NSWindows (Main, Equalizer, Playlist)
- Magnetic snapping on all edges
- Group movement when docked
- Position persistence

---

## 📹 Video Analysis

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

## 🔍 Webamp Implementation (Pending Gemini Analysis)

**Gemini Research Query Running...**

Analyzing:
- Window management in webamp_clone
- Magnetic snap detection algorithm
- Group movement synchronization
- State persistence patterns

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

## 💡 Architectural Approaches

### Approach 1: Pure SwiftUI WindowGroup
- **Pros:** Modern, declarative
- **Cons:** Limited control over window positioning/snapping

### Approach 2: NSWindowController + SwiftUI Views
- **Pros:** Full window control, custom snapping
- **Cons:** More AppKit boilerplate

### Approach 3: Hybrid (SwiftUI Scene + NSWindow coordination)
- **Pros:** SwiftUI views, AppKit window management
- **Cons:** Bridging complexity

---

## 🧮 Magnetic Snapping Algorithm (Conceptual)

### Snap Detection (executed on drag)

```swift
func checkSnap(draggedWindow: NSWindow, allWindows: [NSWindow]) -> CGPoint? {
    let draggedFrame = draggedWindow.frame
    let snapThreshold: CGFloat = 15  // pixels

    for other in allWindows where other != draggedWindow {
        let otherFrame = other.frame

        // Check each edge pair
        let snapPositions = [
            // Right edge of dragged → Left edge of other
            (draggedFrame.maxX, otherFrame.minX, "right-to-left"),
            // Left edge of dragged → Right edge of other
            (draggedFrame.minX, otherFrame.maxX, "left-to-right"),
            // Top edge of dragged → Bottom edge of other
            (draggedFrame.maxY, otherFrame.minY, "top-to-bottom"),
            // Bottom edge of dragged → Top edge of other
            (draggedFrame.minY, otherFrame.maxY, "bottom-to-top"),
        ]

        for (edge1, edge2, type) in snapPositions {
            if abs(edge1 - edge2) < snapThreshold {
                // Calculate snapped position
                return calculateSnapPosition(type: type)
            }
        }
    }

    return nil  // No snap
}
```

### Group Movement (when windows are docked)

```swift
struct DockingGraph {
    var connections: [(WindowID, WindowID, Edge)]

    func getConnectedWindows(from: WindowID) -> Set<WindowID> {
        // BFS/DFS to find all transitively connected windows
    }

    func moveGroup(windows: Set<WindowID>, delta: CGPoint) {
        for window in windows {
            window.setFrameOrigin(window.frame.origin + delta)
        }
    }
}
```

---

## 📋 Implementation Phases (Estimated)

### Phase 1: Separate Windows (2-3 hours)
- Convert UnifiedDockView to 3 NSWindows
- Maintain current stacked layout (no movement yet)
- Each window independent but positioned correctly
- State sharing via EnvironmentObject

### Phase 2: Independent Movement (1-2 hours)
- Remove automatic stacking
- Make windows draggable
- Remember positions in UserDefaults
- No snapping yet

### Phase 3: Magnetic Snapping (3-4 hours)
- Implement snap detection on drag
- Calculate snap-to positions
- Visual feedback during snap
- Threshold tuning (15px standard)

### Phase 4: Group Movement (2-3 hours)
- Track docking relationships
- Synchronize movement of docked windows
- Maintain relative positions
- Handle complex docking (all 3 connected)

### Phase 5: State Persistence (1 hour)
- Save window positions
- Save docking relationships
- Restore on app launch
- Handle edge cases (off-screen, monitor changes)

**Total Estimated Time:** 9-13 hours

---

## ⚠️ Complexity Assessment

### High Complexity Items:
1. **Snap Detection Algorithm** - Needs to be fast (runs on every mouse move)
2. **Group Movement** - Transitive dependencies (A→B→C all move)
3. **Z-Order Management** - Docked windows must maintain visual order
4. **Multi-Monitor** - Handle windows on different displays
5. **State Migration** - Convert existing users from single-window

### Medium Complexity:
6. **NSWindow Coordination** - Managing 3 window lifecycles
7. **Titlebar Customization** - Skinned titlebars per window
8. **Close Behavior** - Should closing one close all?

### Low Complexity:
9. **Position Save/Restore** - UserDefaults straightforward
10. **Individual Drag** - NSWindow handles this natively

---

## 🤔 Design Questions

1. **Window Lifecycle:** Should all 3 windows always exist, or create on-demand?
2. **Docking State:** Where should DockingGraph live (singleton, @StateObject)?
3. **Snap Feedback:** Visual indicator when snap occurs (highlight, vibration)?
4. **Close Behavior:** Cmd+W closes one window or all docked windows?
5. **Menu Bar:** Should "Show Main/EQ/Playlist" create windows or just show hidden ones?
6. **Shade Mode:** How does shading affect docking?

---

**Research Status:** ⏳ IN PROGRESS
**Gemini Analysis:** Running
**Next:** Complete research, create implementation plan
