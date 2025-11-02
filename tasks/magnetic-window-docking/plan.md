# Magnetic Window Docking - Implementation Plan

**Date:** 2025-10-23
**Priority:** P3 (Major architectural enhancement)
**Estimated Time:** 9-13 hours
**Status:** Deferred - Research complete

---

## 🎯 Goal

Transform MacAmp from single-window to multi-window with magnetic docking matching classic Winamp behavior.

---

## 📋 Implementation Phases

### Phase 1: Separate Windows (2-3 hours)

**Objective:** Convert UnifiedDockView to 3 independent NSWindows

**Files to Create:**
- `MacAmpApp/Windows/MainWindowController.swift`
- `MacAmpApp/Windows/EqualizerWindowController.swift`
- `MacAmpApp/Windows/PlaylistWindowController.swift`

**Files to Modify:**
- `MacAmpApp/MacAmpApp.swift` - WindowGroup definitions
- Remove UnifiedDockView.swift
- Update DockingController for multi-window

**Implementation:**
```swift
@main
struct MacAmpApp: App {
    @StateObject var dockingController = DockingController()

    var body: some Scene {
        WindowGroup(id: "main") {
            WinampMainWindow()
                .environmentObject(dockingController)
        }
        .defaultSize(width: 275, height: 116)
        .windowResizability(.contentSize)

        WindowGroup(id: "equalizer") {
            WinampEqualizerWindow()
                .environmentObject(dockingController)
        }
        .defaultSize(width: 275, height: 116)

        WindowGroup(id: "playlist") {
            WinampPlaylistWindow()
                .environmentObject(dockingController)
        }
        .defaultSize(width: 275, height: 232)
    }
}
```

**Testing:** 3 windows open, position them manually (no snapping yet)

---

### Phase 2: Window Snap Detection (3-4 hours)

**Objective:** Implement magnetic snapping algorithm from Webamp

**File to Create:**
- `MacAmpApp/Utils/WindowSnapManager.swift`

**Key Components:**
```swift
class WindowSnapManager: ObservableObject {
    let snapDistance: CGFloat = 15

    func checkSnap(window: NSWindow, others: [NSWindow]) -> NSPoint? {
        let frame = window.frame

        for other in others {
            if let snapPos = calculateSnapPosition(frame, to: other.frame) {
                return snapPos
            }
        }
        return nil
    }

    private func calculateSnapPosition(_ a: NSRect, to b: NSRect) -> NSPoint? {
        // Port webamp's snap() algorithm
        var x: CGFloat? = nil
        var y: CGFloat? = nil

        // Check vertical overlap for horizontal snapping
        if overlapY(a, b) {
            if near(a.minX, b.maxX) {
                x = b.maxX
            } else if near(a.maxX, b.minX) {
                x = b.minX - a.width
            }
            // ... other cases
        }

        // Check horizontal overlap for vertical snapping
        if overlapX(a, b) {
            // ... similar logic
        }

        if x != nil || y != nil {
            return NSPoint(x: x ?? a.origin.x, y: y ?? a.origin.y)
        }
        return nil
    }

    private func near(_ a: CGFloat, _ b: CGFloat) -> Bool {
        abs(a - b) < snapDistance
    }

    private func overlapX(_ a: NSRect, _ b: NSRect) -> Bool {
        !(a.maxX < b.minX || a.minX > b.maxX)
    }

    private func overlapY(_ a: NSRect, _ b: NSRect) -> Bool {
        !(a.maxY < b.minY || a.minY > b.maxY)
    }
}
```

**Testing:** Drag windows near each other, verify snap occurs at 15px

---

### Phase 3: Group Movement (2-3 hours)

**Objective:** Move all connected windows when dragging main window

**Implementation:**
```swift
extension WindowSnapManager {
    func findConnectedWindows(from: NSWindow, in windows: [NSWindow]) -> Set<NSWindow> {
        var visited = Set<NSWindow>()
        traceConnection(from, in: windows, visited: &visited)
        return visited
    }

    private func traceConnection(_ window: NSWindow, in windows: [NSWindow], visited: inout Set<NSWindow>) {
        guard !visited.contains(window) else { return }
        visited.insert(window)

        for other in windows where other != window {
            if abuts(window, other) {
                traceConnection(other, in: windows, visited: &visited)
            }
        }
    }

    private func abuts(_ a: NSWindow, _ b: NSWindow) -> Bool {
        let frameA = a.frame
        let frameB = b.frame

        // Check if edges are touching (< 2px apart)
        let distances = [
            abs(frameA.maxX - frameB.minX),
            abs(frameB.maxX - frameA.minX),
            abs(frameA.maxY - frameB.minY),
            abs(frameB.maxY - frameA.minY)
        ]

        return distances.min()! < 2
    }

    func moveGroup(_ windows: Set<NSWindow>, by delta: CGPoint) {
        for window in windows {
            var frame = window.frame
            frame.origin.x += delta.x
            frame.origin.y += delta.y
            window.setFrame(frame, display: true, animate: false)
        }
    }
}
```

**Testing:** Drag main window, verify EQ and Playlist move with it

---

### Phase 4: Custom Drag Handling (2-3 hours)

**Objective:** Override default window dragging to implement group movement

**Approach:** NSWindowController subclass

```swift
class MagneticWindowController: NSWindowController {
    var snapManager: WindowSnapManager
    var windowRegistry: WindowRegistry  // Tracks all 3 windows

    override func mouseDown(with event: NSEvent) {
        // Start tracking drag
        startDrag(event)
    }

    private func startDrag(_ event: NSEvent) {
        guard let window = window else { return }

        let startLocation = event.locationInWindow
        let startFrame = window.frame

        // Find connected windows
        let connectedWindows = snapManager.findConnectedWindows(
            from: window,
            in: windowRegistry.allWindows
        )

        // Track mouse movement
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) { dragEvent in
            let currentLocation = dragEvent.locationInWindow
            let delta = CGPoint(
                x: currentLocation.x - startLocation.x,
                y: currentLocation.y - startLocation.y
            )

            // Move all connected windows
            self.snapManager.moveGroup(connectedWindows, by: delta)

            // Check for snaps with non-connected windows
            if let snapPos = self.snapManager.checkSnap(window, others: ...) {
                // Apply snap position
            }

            return dragEvent
        }
    }
}
```

---

### Phase 5: State Persistence (1 hour)

**Objective:** Save/restore window positions and docking state

```swift
struct WindowState: Codable {
    var mainPosition: CGPoint
    var equalizerPosition: CGPoint
    var playlistPosition: CGPoint
    var mainVisible: Bool
    var equalizerVisible: Bool
    var playlistVisible: Bool
}

extension DockingController {
    func saveState() {
        let state = WindowState(...)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "WindowPositions")
        }
    }

    func restoreState() {
        guard let data = UserDefaults.standard.data(forKey: "WindowPositions"),
              let state = try? JSONDecoder().decode(WindowState.self, from: data) else {
            setDefaultPositions()
            return
        }

        // Apply saved positions
        applyPositions(state)
    }
}
```

---

## 🎮 Testing Plan

### Test 1: Independent Movement
- Open all 3 windows
- Drag each separately
- Verify independent movement

### Test 2: Magnetic Snapping
- Drag main window near equalizer
- Verify snap at 15px threshold
- Test all 4 edges (top, bottom, left, right)
- Test alignment snaps (left-to-left, etc.)

### Test 3: Group Movement
- Stack all 3 windows (Main, EQ, Playlist)
- Drag main window titlebar
- Verify all 3 move together
- Verify relative positions maintained

### Test 4: Detachment
- Drag docked window away
- Verify it detaches and moves alone
- Verify remaining windows stay docked

### Test 5: Complex Docking
- Create L-shape: Main+EQ horizontal, Playlist below
- Drag main window
- Verify entire shape moves together

### Test 6: Multi-Monitor
- Move windows across displays
- Verify snapping still works
- Verify group movement works

### Test 7: Persistence
- Position windows in custom layout
- Quit and relaunch app
- Verify positions restored

---

## ⚠️ Known Challenges

### Challenge 1: NSWindow Coordinate System
**Issue:** Bottom-left origin vs top-left in SwiftUI
**Solution:** Conversion helpers, careful testing

### Challenge 2: WindowGroup Lifecycle
**Issue:** SwiftUI WindowGroup creates/destroys windows
**Solution:** May need NSWindowController for more control

### Challenge 3: Titlebar Dragging
**Issue:** SwiftUI windows have standard titlebars
**Solution:** Custom titlebar views, NSWindow.isMovableByWindowBackground

### Challenge 4: Z-Order Maintenance
**Issue:** Docked windows must maintain visual stacking
**Solution:** window.level + orderFront() on group movement

### Challenge 5: Performance
**Issue:** Snap detection on every mouse move
**Solution:** Optimize with early exits, spatial indexing if needed

---

## 📊 Effort Estimate

| Phase | Time | Complexity |
|-------|------|------------|
| Separate Windows | 2-3h | Medium |
| Snap Detection | 3-4h | High |
| Group Movement | 2-3h | High |
| Custom Drag | 2-3h | High |
| Persistence | 1h | Low |
| **Total** | **10-16h** | **High** |

---

## 🤔 Decision: Defer to Future

**Rationale:**
- Major architectural change
- Requires NSWindowController expertise
- Complex testing matrix
- Current unified window works well
- Can ship v1.0 without this feature

**Benefits when implemented:**
- True Winamp experience
- More flexible window management
- Better multi-monitor support

**Recommendation:** Implement in v1.1 or v2.0 after core features stable

---

---

## 🔄 REVISED PHASE PLAN (from ULTRATHINK Synthesis 2025-11-02)

**Source:** Oracle (Codex) + Gemini recommendations combined
**Total Time:** 14-20 hours (base) + 3-4 hours (contingency) = **18-24 hours worst case**

### Phase 1A: Window Separation with NSWindowController (2-3 hours)

**Objective:** Create 3 independent NSWindowControllers, no dragging yet

**Files to Create:**
- `MacAmpApp/ViewModels/WindowCoordinator.swift` - Manages 3 window singletons
- `MacAmpApp/Windows/WinampMainWindowController.swift`
- `MacAmpApp/Windows/WinampEqualizerWindowController.swift`
- `MacAmpApp/Windows/WinampPlaylistWindowController.swift`

**Files to Modify:**
- `MacAmpApp/MacAmpApp.swift` - Replace WindowGroup with manual window creation
- `MacAmpApp/Views/WinampMainWindow.swift` - Update for NSWindow hosting
- `MacAmpApp/Views/WinampEqualizerWindow.swift` - Update for NSWindow hosting
- `MacAmpApp/Views/WinampPlaylistWindow.swift` - Update for NSWindow hosting

**Files to Delete:**
- `MacAmpApp/Views/UnifiedDockView.swift` - Remove completely

**Key Tasks:**
- Create WindowCoordinator singleton
- Create 3 NSWindowController subclasses
- Configure windows (borderless, no titlebar)
- Position windows in default stack (no snapping)
- Connect menu commands to WindowCoordinator
- Migrate double-size scaling to each window view

**Testing:**
- 3 windows open on launch
- Windows positioned correctly (stacked)
- Windows can't be moved yet (no drag regions)
- Menu commands show/hide windows
- Closing window hides it (doesn't destroy)

**Deliverable:** 3 independent windows, positioned but not movable

---

### Phase 1B: Drag Regions (2-3 hours) - CRITICAL PRIORITY

**Objective:** Make borderless windows draggable via custom titlebar areas

**Rationale (Oracle):**
> "Perform drag-region work immediately after splitting windows; otherwise users lose the ability to move borderless windows."

**Implementation Strategy:**
1. Define drag regions in SwiftUI views (top 14px)
2. NSEvent monitoring for mouseDown in drag region
3. Custom drag loop with windowDidMove triggering
4. Test: Can move windows independently

**Files to Modify:**
- `MacAmpApp/Views/WinampMainWindow.swift` - Add drag region
- `MacAmpApp/Views/WinampEqualizerWindow.swift` - Add drag region
- `MacAmpApp/Views/WinampPlaylistWindow.swift` - Add drag region
- `MacAmpApp/Utilities/WindowAccessor.swift` (create) - NSWindow bridge

**Key Implementation:**
```swift
// Custom drag region component
struct TitlebarDragRegion: View {
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 14)
            .background(WindowAccessor { nsWindow in
                nsWindow.isMovableByWindowBackground = false
                configureDragHandler(for: nsWindow)
            })
    }

    func configureDragHandler(for window: NSWindow) {
        // Mouse down tracking
        // Start drag loop
        // Move window programmatically
    }
}
```

**Testing:**
- Each window draggable by titlebar area
- Smooth movement (no lag)
- Windows move independently (no snapping yet)
- Cursor changes appropriately

**Deliverable:** Fully draggable borderless windows

**CRITICAL:** Must complete before Phase 2. Without this, snap detection is untestable.

---

### Phase 2: WindowSnapManager Integration (3-4 hours)

**Objective:** Register windows, enable snap detection + group movement

**Oracle's Insight:**
> "Merge 'snap detection' and 'group movement' into a single integration phase using the existing manager."

**Why Merge:** WindowSnapManager already implements both:
- Line 91: `connectedCluster()` - Group detection
- Line 96-102: Cluster movement
- Line 114: `snapToMany()` - Snap detection

**Files to Modify:**
- `MacAmpApp/ViewModels/WindowCoordinator.swift` - Register windows
- `MacAmpApp/Utilities/WindowSnapManager.swift` - (already complete!)
- `tasks/magnetic-window-docking/research.md` - Fix 15px documentation ⚠️
- `tasks/magnetic-window-docking/FEASIBILITY_SUMMARY.md` - Fix 10px → 15px

**Implementation:**
```swift
// WindowCoordinator.swift
init() {
    // ... create windows

    // Register with snap manager
    if let main = mainController.window {
        WindowSnapManager.shared.register(window: main, kind: .main)
    }
    if let eq = eqController.window {
        WindowSnapManager.shared.register(window: eq, kind: .equalizer)
    }
    if let playlist = playlistController.window {
        WindowSnapManager.shared.register(window: playlist, kind: .playlist)
    }

    // That's it! WindowSnapManager handles everything:
    // - 15px snap threshold (SnapUtils.SNAP_DISTANCE)
    // - Edge snapping (snapToMany)
    // - Cluster detection (connectedCluster)
    // - Group movement (automatic in windowDidMove)
    // - Screen edge snapping (snapWithin)
}
```

**Testing:**
- Drag main window near equalizer → snaps at 15px
- Drag docked group → moves together
- Drag equalizer away → detaches, moves alone
- Test all edge combinations (top, bottom, left, right)
- Test screen edge snapping
- Test multi-monitor snapping

**Deliverable:** Fully functional magnetic docking with group movement

---

### Phase 3: Delegate Multiplexer (1-2 hours)

**Objective:** Resolve delegate conflicts for future extensions

**Oracle's Warning:**
> "WindowSnapManager installs itself as the window delegate; if additional delegate callbacks required, add a delegate multiplexer."

**Problem:** WindowSnapManager.swift:29 does `window.delegate = self`

**Files to Create:**
- `MacAmpApp/Utilities/WindowDelegateMultiplexer.swift`

**Files to Modify:**
- `MacAmpApp/ViewModels/WindowCoordinator.swift` - Use multiplexer
- `MacAmpApp/Utilities/WindowSnapManager.swift` - Register with multiplexer

**Implementation:**
```swift
class WindowDelegateMultiplexer: NSObject, NSWindowDelegate {
    private var delegates: [NSWindowDelegate] = []

    func add(delegate: NSWindowDelegate) {
        delegates.append(delegate)
    }

    // Forward all NSWindowDelegate methods
    func windowDidMove(_ notification: Notification) {
        delegates.forEach { $0.windowDidMove?(notification) }
    }

    func windowDidResize(_ notification: Notification) {
        delegates.forEach { $0.windowDidResize?(notification) }
    }

    func windowDidBecomeMain(_ notification: Notification) {
        delegates.forEach { $0.windowDidBecomeMain?(notification) }
    }

    func windowWillClose(_ notification: Notification) {
        delegates.forEach { $0.windowWillClose?(notification) }
    }
}

// Usage in WindowCoordinator:
let multiplexer = WindowDelegateMultiplexer()
multiplexer.add(delegate: WindowSnapManager.shared)
window.delegate = multiplexer
```

**Testing:**
- WindowSnapManager still receives windowDidMove
- Can add custom close handler
- Can add custom resize handler
- Can add custom focus handler

**Deliverable:** Extensible delegate pattern for future features

---

### Phase 4: Double-Size Coordination (2-3 hours)

**Objective:** All 3 windows scale together, maintain docking

**Oracle's Warning:**
> "Each decoupled window must drive its NSWindow frame on toggle; otherwise AppKit crops the scaled content."

**Files to Modify:**
- `MacAmpApp/ViewModels/WindowCoordinator.swift` - Synchronization logic
- `MacAmpApp/Views/WinampMainWindow.swift` - Scale content
- `MacAmpApp/Views/WinampEqualizerWindow.swift` - Scale content
- `MacAmpApp/Views/WinampPlaylistWindow.swift` - Scale content
- `MacAmpApp/Models/AppSettings.swift` - Connect to WindowCoordinator

**Implementation:**
```swift
// WindowCoordinator.swift
@Published var isDoubleSizeMode: Bool = false {
    didSet {
        synchronizeScale()
    }
}

private func synchronizeScale() {
    let scale: CGFloat = isDoubleSizeMode ? 2.0 : 1.0

    // Resize all windows
    resizeWindows(scale: scale)

    // Maintain docked positions
    maintainDockedLayout()
}

private func resizeWindows(scale: CGFloat) {
    // Main: 275×116 → 550×232
    // EQ: 275×116 → 550×232
    // Playlist: 275×232 → 550×464

    for (window, baseSize) in windowBaseSizes {
        let newSize = NSSize(
            width: baseSize.width * scale,
            height: baseSize.height * scale
        )
        let newFrame = NSRect(
            origin: window.frame.origin,
            size: newSize
        )
        window.setFrame(newFrame, display: true, animate: true)
    }
}

private func maintainDockedLayout() {
    // Trigger WindowSnapManager recalculation
    // Or manually adjust origins to maintain docking
}
```

**Content Scaling in Views:**
```swift
// WinampMainWindow.swift
var body: some View {
    ZStack {
        // Window content at 1x coordinates
        // ...
    }
    .scaleEffect(
        coordinator.isDoubleSizeMode ? 2.0 : 1.0,
        anchor: .topLeading
    )
    .frame(
        width: coordinator.isDoubleSizeMode ? 550 : 275,
        height: coordinator.isDoubleSizeMode ? 232 : 116
    )
}
```

**Testing:**
- Click D button → all 3 windows scale together
- Docked windows maintain alignment during scale
- Origins adjust correctly (windows don't drift)
- Content not cropped
- Snap detection still works at 2x scale
- Toggle D multiple times → stable

**Deliverable:** Synchronized double-size mode across all windows

---

### Phase 5: Playlist Resize Handler (1-2 hours) - GEMINI

**Objective:** Maintain docking when playlist height changes

**Gemini's Insight:**
> "When playlist is docked and resized, other windows must shift to maintain docking."

**Implementation:**
```swift
// Add to WindowDelegateMultiplexer or custom delegate
func windowDidResize(_ notification: Notification) {
    guard let resizedWindow = notification.object as? NSWindow else { return }
    guard resizedWindow === playlistWindow else { return }

    // Find windows docked to playlist
    let boxes = allWindowBoxes()
    let playlistID = ObjectIdentifier(playlistWindow!)
    let cluster = WindowSnapManager.shared.connectedCluster(
        start: playlistID,
        boxes: boxes
    )

    // Recalculate positions to maintain docking
    // If playlist grows down, shift windows below it
    // If playlist shrinks, shift windows up

    for id in cluster where id != playlistID {
        // Adjust position
    }
}
```

**Testing:**
- Resize playlist when docked above another window → window below shifts
- Resize playlist when docked below another window → maintains connection
- Resize playlist when standalone → no other windows affected
- Resize + double-size interaction

**Deliverable:** Resize-aware docking

---

### Phase 6: Z-Order Management (1 hour) - GEMINI

**Objective:** Clicking one docked window brings all to front

**Gemini's Insight:**
> "When any window in cluster receives focus, bring all to front."

**Implementation:**
```swift
// Add to WindowDelegateMultiplexer
func windowDidBecomeMain(_ notification: Notification) {
    guard let activeWindow = notification.object as? NSWindow else { return }

    // Find cluster
    let boxes = allWindowBoxes()
    let activeID = ObjectIdentifier(activeWindow)
    let cluster = WindowSnapManager.shared.connectedCluster(
        start: activeID,
        boxes: boxes
    )

    // Bring entire cluster to front
    for id in cluster {
        if let window = idToWindow[id] {
            window.orderFront(nil)
        }
    }
}
```

**Testing:**
- Click docked main window → EQ and playlist come to front too
- Click standalone window → only that window comes to front
- Test with multiple window groups
- Test Mission Control behavior

**Deliverable:** Unified focus behavior for docked groups

---

### Phase 7: Snap Threshold Scaling (0.5 hours) - GEMINI

**Objective:** Scale 15px threshold to 30px at 2x

**Gemini's Insight:**
> "Snap threshold must scale with double-size mode."

**Implementation:**
```swift
// SnapUtils.swift
static func snapThreshold(scale: CGFloat = 1.0) -> CGFloat {
    return SNAP_DISTANCE * scale  // 15px * 2 = 30px
}

// Update near() function:
static func near(_ a: CGFloat, _ b: CGFloat, scale: CGFloat = 1.0) -> Bool {
    abs(a - b) < snapThreshold(scale: scale)
}

// WindowSnapManager passes scale:
let scale = AppSettings.shared.isDoubleSizeMode ? 2.0 : 1.0
if SnapUtils.near(left(boxA), right(boxB), scale: scale) { ... }
```

**Testing:**
- At 1x: snap at 15px
- At 2x: snap at 30px
- Toggle between modes → threshold updates

**Deliverable:** Scale-aware snap detection

---

### Phase 8: State Persistence (1-2 hours)

**Objective:** Save/restore window positions and docking state

**Files to Modify:**
- `MacAmpApp/Models/AppSettings.swift` - Add WindowState
- `MacAmpApp/ViewModels/WindowCoordinator.swift` - Save/restore

**Implementation:**
```swift
struct WindowState: Codable {
    var mainPosition: CGPoint
    var equalizerPosition: CGPoint
    var playlistPosition: CGPoint
    var mainVisible: Bool
    var equalizerVisible: Bool
    var playlistVisible: Bool
}

extension WindowCoordinator {
    func saveState() {
        let state = WindowState(
            mainPosition: mainWindow?.frame.origin ?? .zero,
            equalizerPosition: eqWindow?.frame.origin ?? .zero,
            playlistPosition: playlistWindow?.frame.origin ?? .zero,
            mainVisible: mainWindow?.isVisible ?? false,
            equalizerVisible: eqWindow?.isVisible ?? false,
            playlistVisible: playlistWindow?.isVisible ?? false
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "WindowPositions")
        }
    }

    func restoreState() {
        guard let data = UserDefaults.standard.data(forKey: "WindowPositions"),
              let state = try? JSONDecoder().decode(WindowState.self, from: data) else {
            setDefaultPositions()
            return
        }

        // Bounds check (Oracle's off-screen detection)
        let normalizedPositions = normalizePositions(state)
        applyPositions(normalizedPositions)
    }

    private func normalizePositions(_ state: WindowState) -> WindowState {
        // Ensure windows are on-screen
        // Handle monitor disconnection
        // Clamp to visible area
    }
}
```

**Testing:**
- Position windows, quit, relaunch → positions restored
- Dock windows, quit, relaunch → docking preserved
- Unplug monitor, relaunch → windows on primary screen
- Invalid state → fallback to defaults

**Deliverable:** Persistent window layout

---

### Phase 9: Testing & Polish (1-2 hours)

**Comprehensive Test Matrix:**

**Basic Movement:**
- Drag each window independently
- Drag titlebar (not content area)
- Cursor changes appropriately

**Snap Detection:**
- Snap at 15px threshold (1x scale)
- Snap at 30px threshold (2x scale)
- All 4 edges (top, bottom, left, right)
- Alignment snaps (left-to-left, right-to-right)
- Screen edge snapping

**Group Movement:**
- Docked group moves together
- Partial groups work (main+eq, eq+playlist)
- Detachment works (drag away)
- Re-docking works

**Double-Size:**
- All windows scale together
- Docked alignment maintained
- Content not cropped
- Origins correct
- Snap threshold scales

**Playlist Resize:**
- Resize while docked → maintains docking
- Resize while standalone → no effect on others
- Resize + double-size interaction

**Z-Order:**
- Click docked window → cluster comes to front
- Click standalone window → only that window
- Mission Control behavior

**Persistence:**
- Positions saved/restored
- Visibility saved/restored
- Off-screen detection works

**Multi-Monitor:**
- Snapping across displays
- Group movement across displays
- Coordinate math correct
- Monitor disconnection handled

**Edge Cases:**
- Minimize windows
- Hide windows via menu
- Fullscreen mode (if applicable)
- Fast drags (performance)
- Accessibility (VoiceOver)

**Deliverable:** Production-ready implementation

---

## Implementation Timeline Summary

| Phase | Time | Cumulative | Status |
|-------|------|------------|--------|
| 1A: Separate Windows | 2-3h | 2-3h | Ready |
| 1B: Drag Regions | 2-3h | 4-6h | Ready |
| 2: WindowSnapManager | 3-4h | 7-10h | Ready |
| 3: Delegate Multiplexer | 1-2h | 8-12h | Ready |
| 4: Double-Size | 2-3h | 10-15h | Ready |
| 5: Playlist Resize | 1-2h | 11-17h | Ready |
| 6: Z-Order | 1h | 12-18h | Ready |
| 7: Snap Scaling | 0.5h | 12.5-18.5h | Ready |
| 8: Persistence | 1-2h | 13.5-20.5h | Ready |
| 9: Testing | 1-2h | 14.5-22.5h | Ready |
| **TOTAL** | **14-20h** | | **GO** |

**Risk Contingency:** +20% (3-4 hours) = **18-24 hours worst case**

---

**Plan Status:** ✅ REVISED (2025-11-02 ULTRATHINK Synthesis)
**Decision:** Conditional GO - High Risk (8/10), High Value
**Architecture:** NSWindowController (NOT WindowGroup)
**Next:** Fix documentation bugs, update todos, begin Phase 1A
