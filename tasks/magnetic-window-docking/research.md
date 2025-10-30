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

### Button Implementation (Already Done)

The clutter bar buttons are implemented in `WinampMainWindow.swift`:
- O, A, I, D, V buttons (Lines 494-577)
- D button is functional
- Sprites from TITLEBAR.BMP (coordinates: see SkinSprites.swift)

**No changes needed** to button code when separating windows.

### State Management (Already Done)

`AppSettings.isDoubleSizeMode` is ready:
- @AppStorage for persistence
- @MainActor for concurrency
- Accessible from all views

**No changes needed** to state management when separating windows.

### Testing Notes for Future Implementation

When magnetic docking is implemented, test:
- [ ] All 3 windows scale together when docked
- [ ] Separated windows scale independently
- [ ] Docking works at both 1x and 2x scales
- [ ] Snap threshold scales with window size
- [ ] Group movement works at 2x
- [ ] Position persistence works with scaling
- [ ] Animation is smooth for all windows

### Reference Implementation

**See:** `tasks/double-size-button/` for complete implementation details
- research.md - Oracle feedback and architecture decisions
- plan.md - Phase-by-phase implementation guide
- state.md - Final implementation status and code locations

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
