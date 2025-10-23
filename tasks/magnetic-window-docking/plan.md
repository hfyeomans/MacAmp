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

**Plan Status:** ✅ COMPLETE
**Decision:** Defer to P3 (post-1.0 enhancement)
**Next:** Document and commit research
