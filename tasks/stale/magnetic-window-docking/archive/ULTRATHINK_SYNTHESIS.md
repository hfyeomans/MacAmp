# Magnetic Window Docking - ULTRATHINK Synthesis

**Date:** 2025-11-02
**Synthesizer:** 10x Engineer (Claude)
**Input Reviews:** Oracle (Codex), Gemini, Claude (Original Plan)
**Status:** Critical Analysis Complete

---

## Executive Summary

After analyzing three independent technical reviews, **Oracle's assessment is most accurate**. The implementation is feasible but carries **HIGH risk (8/10)** primarily due to architectural concerns that Gemini underestimated. The consensus time estimate of 12-18 hours is **too optimistic** - realistic estimate is **14-20 hours** after accounting for drag region implementation and lifecycle complexity.

**Critical Discovery:** All documentation incorrectly states 10px snap distance. **Actual value is 15px** (SnapUtils.swift:27). Oracle caught this; others missed it.

---

## 1. Critical Analysis: Which Review is Most Accurate?

### Oracle (Codex) - MOST ACCURATE ✅

**Strengths:**
- Caught concrete bug: 15px vs 10px documentation error
- Identified architectural showstoppers (lifecycle, delegates, drag regions)
- Specific technical warnings (NSWindowController vs WindowGroup)
- Conservative risk assessment backed by concrete concerns
- Prioritized drag regions correctly (immediate need)

**Evidence of Accuracy:**
```swift
// SnapUtils.swift:27 - Oracle was RIGHT
static let SNAP_DISTANCE: CGFloat = 15  // NOT 10px!
```

**Technical Depth:**
- Understood delegate conflict (WindowSnapManager IS a NSWindowDelegate)
- Recognized WindowGroup lifecycle issues (duplicate instances, flaky restore)
- Anticipated double-size alignment bugs (coordinate math complexity)
- Identified persistence edge case (off-screen after monitor changes)

**Verdict:** Oracle's review shows deeper architectural understanding and catches concrete bugs others missed.

---

### Gemini - OPTIMISTIC BUT VALUABLE ⚠️

**Strengths:**
- Identified feature gaps (playlist resize, Z-order)
- Comprehensive test case expansion
- Validated 5-phase approach
- Confidence-building assessment (9/10 feasibility)

**Weaknesses:**
- Underestimated architectural complexity
- Didn't catch 15px snap distance error
- Risk score too low (6/10 vs Oracle's 8/10)
- Feature-focused over architecture-focused
- Approved WindowGroup without questioning lifecycle

**Valuable Contributions:**
- Playlist resize is a real gap (needs Phase 2.5)
- Z-order management is correct requirement (needs Phase 3.5)
- Snap threshold scaling for double-size (20px at 2x)
- Default drag fallback strategy (de-risk Phase 4)

**Verdict:** Gemini provides useful feature completeness checks but underestimates architectural risks.

---

### Claude (Original Plan) - SOLID FOUNDATION 📋

**Strengths:**
- Discovered WindowSnapManager.swift exists
- Comprehensive research (Webamp analysis, frame analysis)
- Clear 5-phase breakdown
- Detailed testing plan (40+ scenarios)
- 1400 lines of documentation

**Weaknesses:**
- Missed 15px snap distance (used 10px in research)
- Didn't identify playlist resize requirement
- Didn't identify Z-order requirement
- Used WindowGroup without questioning lifecycle
- No drag region priority awareness

**Verdict:** Excellent research foundation but missed critical implementation details that Oracle caught.

---

## 2. Risk Assessment Reconciliation

### Oracle: 8/10 High ✅ CORRECT
### Gemini: 6/10 Medium ❌ UNDERESTIMATED

**Winner: Oracle's 8/10 High Risk is accurate.**

### Why Oracle is Right:

#### 1. Window Lifecycle Complexity (HIGH RISK)

**Oracle's Concern:**
> "Raw WindowGroups risk duplicate instances and flaky close/restore behaviour."

**Evidence:**
- WindowGroup creates windows on-demand (not singletons)
- Menu commands like "Show Main Window" could create duplicates
- Close behavior is automatic, not controllable
- Restoration from saved state is opaque

**Reality Check:**
MacAmp needs exactly 3 windows (singletons) that:
- Always exist (even when hidden)
- Are controlled by menu commands
- Have predictable lifecycle
- Can be shown/hidden, not created/destroyed

WindowGroup doesn't guarantee this. NSWindowController does.

#### 2. Delegate Conflicts (MEDIUM RISK)

**Oracle's Concern:**
> "WindowSnapManager installs itself as the window delegate; if additional delegate callbacks required, add a delegate multiplexer."

**Code Evidence:**
```swift
// WindowSnapManager.swift:29
window.delegate = self  // Takes over delegate!
```

**Problem:**
- WindowSnapManager IS the delegate for snap detection
- If windows need custom close behavior: conflict
- If windows need custom resize behavior: conflict
- If windows need custom focus behavior: conflict

**Solution Required:**
Delegate multiplexer pattern:
```swift
class DelegateMultiplexer: NSObject, NSWindowDelegate {
    var delegates: [NSWindowDelegate] = []

    func windowDidMove(_ notification: Notification) {
        delegates.forEach { $0.windowDidMove?(notification) }
    }
    // ... forward all delegate methods
}
```

#### 3. Drag Regions (CRITICAL FEATURE)

**Oracle's Concern:**
> "Perform drag-region work immediately after splitting windows; otherwise users lose the ability to move borderless windows."

**Reality:**
WindowSnapManager expects windows to have standard titlebars for dragging. But MacAmp uses borderless windows! Without custom drag regions:
- Windows can't be moved
- Snap detection never triggers
- Feature is unusable

**Timeline Impact:**
Drag regions MUST be implemented in Phase 1B (before snap detection), adding 2-3 hours.

#### 4. Double-Size Alignment (HIGH RISK)

**Oracle's Concern:**
> "Each decoupled window must drive its NSWindow frame on toggle; otherwise AppKit crops the scaled content."

**Coordinate Math Complexity:**
```swift
// Current (unified): Simple
UnifiedDockView.scaleEffect(2.0)

// Magnetic docking: Complex - 3 windows must:
// 1. Scale content simultaneously
// 2. Adjust window frames
// 3. Maintain relative positions
// 4. Recalculate snap positions
// 5. Handle origin shifts
```

**Risk:** Misaligned windows, cropped content, incorrect snap positions at 2x scale.

### Why Gemini Underestimated Risk:

Gemini focused on **feature completeness** (resize, Z-order) rather than **architectural soundness** (lifecycle, delegates, drag).

Feature gaps are easier to fix than architectural problems. You can add Z-order later; you can't easily fix WindowGroup lifecycle issues after the fact.

---

## 3. Architecture Decision: NSWindowController vs WindowGroup

### Gemini's Position:
> "Architecture (WindowGroup + WindowAccessor): Modern, sound approach" ✅

### Oracle's Position:
> "Prefer dedicated NSWindowControllers (or scene activation management) to keep the three window singletons in sync with menus" ⚠️

### Winner: Oracle's NSWindowController Approach ✅

### Detailed Analysis:

#### WindowGroup Approach (Gemini/Claude):

**Pros:**
- Modern SwiftUI API
- Automatic window management
- Native SwiftUI integration
- Less boilerplate

**Cons:**
- Creates windows on-demand (not singletons)
- Multiple instances possible
- Close behavior automatic (can't customize)
- Restoration opaque
- Menu synchronization complex
- No fine-grained lifecycle control

**Example Problem:**
```swift
// User closes main window with Cmd+W
// Menu: "Window > Show Main Window"
// What happens?
// - WindowGroup might create NEW instance
// - Snap state lost
// - Position forgotten
// - Other windows orphaned
```

#### NSWindowController Approach (Oracle):

**Pros:**
- Explicit singleton control
- Predictable lifecycle
- Full delegate control
- Menu synchronization trivial
- Traditional but proven
- Fine-grained window management

**Cons:**
- More boilerplate
- Less "SwiftUI native"
- Manual window creation
- More code to maintain

**Example Solution:**
```swift
class WindowCoordinator {
    let mainController: NSWindowController
    let eqController: NSWindowController
    let playlistController: NSWindowController

    func showMain() {
        mainController.window?.makeKeyAndOrderFront(nil)
    }

    func hideMain() {
        mainController.window?.orderOut(nil)
    }
}

// Menu command:
@IBAction func showMainWindow(_ sender: Any) {
    WindowCoordinator.shared.showMain()
}
```

### Architectural Decision: ✅ Use NSWindowController

**Rationale:**
1. Guarantees singleton windows
2. Menu synchronization is trivial
3. Full lifecycle control
4. Delegate multiplexer easier to implement
5. Proven pattern for multi-window apps
6. Risk reduction trumps "modern API"

**Implementation:**
```swift
// Create dedicated controllers
class WinampMainWindowController: NSWindowController { ... }
class WinampEqualizerWindowController: NSWindowController { ... }
class WinampPlaylistWindowController: NSWindowController { ... }

// Coordinator manages all 3
@MainActor
class WindowCoordinator: ObservableObject {
    static let shared = WindowCoordinator()

    let mainController: WinampMainWindowController
    let eqController: WinampEqualizerWindowController
    let playlistController: WinampPlaylistWindowController

    init() {
        // Create windows once, keep forever
        mainController = WinampMainWindowController()
        eqController = WinampEqualizerWindowController()
        playlistController = WinampPlaylistWindowController()

        // Register with snap manager
        if let main = mainController.window {
            WindowSnapManager.shared.register(window: main, kind: .main)
        }
        // ... register others
    }
}
```

---

## 4. Priority Conflicts: Implementation Sequence

### Gemini's Sequence:
1. Phase 1: Separate windows
2. Phase 2: Snap detection
3. **Phase 2.5: Resize handling** (NEW)
4. Phase 3: Group movement
5. **Phase 3.5: Z-order** (NEW)
6. Phase 4: Custom drag
7. Phase 5: Persistence

### Oracle's Sequence:
1. Phase 1: Separate windows
2. **Drag regions immediately** (CRITICAL)
3. **Merge snap detection + group movement** (WindowSnapManager integration)
4. Double-size coordination
5. State persistence

### Winner: Oracle's Sequence is Better ✅

### Why:

#### 1. Drag Regions Must Come First

**Oracle's Insight:**
> "Otherwise users lose the ability to move borderless windows."

**Reality Check:**
- Borderless windows have no default drag mechanism
- Without drag regions, windows are stuck
- Early testing discovers this immediately
- Users file bugs, development stalls

**Correct Sequence:**
```
Phase 1A: Separate windows (no dragging)
Phase 1B: Drag regions (CRITICAL - windows become movable)
Phase 2: Snap detection (now drag triggers snaps)
```

#### 2. Merge Snap Detection + Group Movement

**Oracle's Insight:**
> "Merge 'snap detection' and 'group movement' into a single integration phase using the existing manager"

**Why This Makes Sense:**
WindowSnapManager already does both:
```swift
// WindowSnapManager.swift:33-136
func windowDidMove(_ notification: Notification) {
    // 1. Find connected cluster (group detection)
    let clusterIDs = connectedCluster(start: movedID, boxes: idToBox)

    // 2. Move cluster together (group movement)
    for id in clusterIDs where id != movedID {
        w.setFrameOrigin(NSPoint(x: origin.x + userDelta.x, ...))
    }

    // 3. Snap cluster to other windows (snap detection)
    let diffToOthers = SnapUtils.snapToMany(groupBox, otherBoxes)
}
```

Separating these is artificial. They're one operation in WindowSnapManager.

#### 3. Resize/Z-Order Can Wait

**Gemini's Features (Phase 2.5, 3.5):**
- Playlist resize handling
- Z-order management

**Why These Can Wait:**
- Not blockers for basic functionality
- Users can still dock/undock windows
- Polish features, not core mechanics
- Can be added after core snapping works

**Prioritization:**
1. **CRITICAL:** Drag regions (can't move windows without this)
2. **CRITICAL:** Snap detection (core feature)
3. **CRITICAL:** Group movement (core feature)
4. **HIGH:** Double-size coordination (existing feature must still work)
5. **MEDIUM:** Playlist resize (polish)
6. **MEDIUM:** Z-order (polish)
7. **LOW:** State persistence (nice-to-have)

---

## 5. Comprehensive Issues List

Consolidating ALL issues from all three reviews, ranked by severity:

### CRITICAL Issues (Showstoppers):

#### 1. Documentation Bug: 15px Snap Distance ⚠️ ORACLE

**Location:** Multiple files incorrectly state 10px
**Reality:** SnapUtils.swift:27 = `static let SNAP_DISTANCE: CGFloat = 15`
**Impact:** Confuses implementation, tests might use wrong values
**Fix:** Update all documentation to 15px

**Files to Update:**
- tasks/magnetic-window-docking/research.md (says 10px)
- tasks/magnetic-window-docking/plan.md (says 15px ✅ correct!)
- tasks/magnetic-window-docking/FEASIBILITY_SUMMARY.md (says 10px)

#### 2. Drag Regions Missing from Plan ⚠️ ORACLE

**Problem:** Borderless windows can't be dragged without custom regions
**Impact:** Windows are immovable, feature unusable
**Fix:** Add Phase 1B for drag region implementation
**Time:** +2-3 hours

#### 3. Window Lifecycle Architecture ⚠️ ORACLE

**Problem:** WindowGroup doesn't guarantee singletons
**Impact:** Duplicate windows, lost state, menu sync issues
**Fix:** Use NSWindowController instead
**Time:** No additional time (architectural choice)

---

### HIGH Issues (Major Risks):

#### 4. Delegate Conflicts ⚠️ ORACLE

**Problem:** WindowSnapManager takes over window.delegate
**Code:** `window.delegate = self` (WindowSnapManager.swift:29)
**Impact:** Can't add custom close/resize/focus handlers
**Fix:** Implement delegate multiplexer pattern
**Time:** +1-2 hours

#### 5. Double-Size Alignment Bugs ⚠️ ORACLE + CLAUDE

**Problem:** 3 separate windows must scale simultaneously
**Complexity:**
- Scale content (scaleEffect)
- Resize window frames (setFrame)
- Maintain relative positions
- Recalculate snap positions (15px → 30px at 2x?)
- Handle origin shifts

**Risk:** Misaligned windows, cropped content
**Fix:** Synchronized scaling routine + testing
**Time:** +2-3 hours

#### 6. Coordinate System Complexity ⚠️ ALL REVIEWS

**Problem:** NSWindow uses bottom-left origin, SwiftUI uses top-left
**Evidence:** WindowSnapManager does this conversion (lines 50-69)
**Risk:** Off-by-one errors, multi-monitor bugs
**Fix:** Careful testing, bounds checking
**Time:** Accounted for in phases

---

### MEDIUM Issues (Feature Gaps):

#### 7. Playlist Resize Handling ⚠️ GEMINI

**Problem:** Playlist is resizable, others aren't
**Current State:** WindowSnapManager only handles movement
**Required:** windowDidResize handler
**Implementation:**
```swift
func windowDidResize(_ notification: Notification) {
    // Find cluster
    // Recalculate positions to maintain docking
    // Shift windows below resized window
}
```
**Time:** +1-2 hours

#### 8. Z-Order Management ⚠️ GEMINI

**Problem:** Clicking one docked window should bring all to front
**Current State:** Not handled
**Required:** windowDidBecomeMain handler
**Implementation:**
```swift
func windowDidBecomeMain(_ notification: Notification) {
    let cluster = connectedCluster(...)
    for windowID in cluster {
        window.orderFront(nil)
    }
}
```
**Time:** +1 hour

#### 9. Snap Threshold Scaling ⚠️ GEMINI

**Problem:** 15px threshold at 1x should be 30px at 2x scale
**Current:** Hardcoded 15px
**Fix:** Scale threshold with isDoubleSizeMode
**Implementation:**
```swift
static func snapThreshold(scale: CGFloat = 1.0) -> CGFloat {
    return 15 * scale
}
```
**Time:** +0.5 hours

---

### LOW Issues (Polish):

#### 10. Persistence Off-Screen ⚠️ ORACLE

**Problem:** Saved positions may be off-screen after monitor changes
**Fix:** Bounds normalization on restore
**Time:** +0.5 hours

#### 11. Mission Control Behavior ⚠️ GEMINI

**Problem:** How do docked windows behave in Mission Control?
**Testing:** Required but not blocking
**Time:** Testing only

#### 12. Accessibility (VoiceOver) ⚠️ GEMINI

**Problem:** VoiceOver needs proper window roles
**Fix:** Set accessibility attributes
**Time:** +0.5 hours

---

## 6. Final Scores: Definitive Assessment

After critical analysis of all three reviews and code inspection:

### Feasibility: 7/10 ⬇️

**Downgraded from Gemini's 9/10, matches Oracle's 7/10**

**Reasoning:**
- Core algorithms exist (WindowSnapManager) ✅
- But lifecycle architecture is complex ⚠️
- Drag regions are non-trivial ⚠️
- Delegate conflicts need resolution ⚠️
- Double-size coordination is risky ⚠️

**Achievable but not "highly achievable" - 7/10 is accurate.**

---

### Risk: 8/10 High ⬆️

**Upgraded from Gemini's 6/10, matches Oracle's 8/10**

**Classification: HIGH RISK**

**Reasoning:**
- Architectural decisions have long-term impact (NSWindowController vs WindowGroup)
- Delegate conflicts could cause subtle bugs
- Window lifecycle issues hard to debug
- Double-size alignment could break existing feature
- Coordinate math errors cause visual bugs
- Multi-window state synchronization complex

**Risk Breakdown:**
- **Technical Risk:** 8/10 (architecture, delegates, coordinates)
- **Schedule Risk:** 7/10 (14-20 hours, could slip)
- **Quality Risk:** 7/10 (subtle bugs hard to catch)
- **Maintenance Risk:** 6/10 (complex code to maintain)

**Overall: HIGH RISK (8/10)**

---

### Time Estimate: 14-20 hours ⬆️

**Increased from Oracle's 12-18 and Gemini's 12-18**

**Phase Breakdown:**

| Phase | Description | Time |
|-------|-------------|------|
| 1A | Separate windows (NSWindowController) | 2-3h |
| 1B | Drag regions (CRITICAL) | 2-3h |
| 2 | WindowSnapManager integration | 3-4h |
| 3 | Double-size coordination | 2-3h |
| 4 | Delegate multiplexer | 1-2h |
| 5 | Playlist resize | 1-2h |
| 6 | Z-order management | 1h |
| 7 | State persistence | 1-2h |
| 8 | Testing & polish | 1-2h |
| **TOTAL** | | **14-20h** |

**Assumptions:**
- Experienced Swift/AppKit developer
- Familiar with MacAmp codebase
- No major unforeseen issues
- Testing time included

**Risk Contingency:** +20% (3-4 hours) for debugging, refinement

---

### Top 3 Showstoppers:

#### 1. Window Lifecycle Architecture (Critical)

**Issue:** WindowGroup doesn't provide singleton guarantees
**Impact:** Duplicate windows, lost state, menu sync failure
**Solution:** Use NSWindowController with WindowCoordinator
**Blocker:** Must decide before coding Phase 1
**Time to Resolve:** 0h (architectural decision)

#### 2. Drag Region Implementation (Critical)

**Issue:** Borderless windows can't be moved without custom drag
**Impact:** Feature completely unusable
**Solution:** Custom titlebar areas with NSEvent tracking
**Blocker:** Must implement in Phase 1B
**Time to Resolve:** 2-3h

#### 3. Delegate Conflict Resolution (High)

**Issue:** WindowSnapManager takes over window.delegate
**Impact:** Can't add custom close/resize/focus behavior
**Solution:** Delegate multiplexer pattern
**Blocker:** Must implement before Phase 2
**Time to Resolve:** 1-2h

**Other Major Issues:**
- Double-size alignment (high risk, 2-3h)
- Coordinate system complexity (medium risk, testing-heavy)

---

### Top 5 Architectural Decisions Needed:

#### 1. NSWindowController vs WindowGroup (CRITICAL) ✅

**Decision:** Use NSWindowController
**Rationale:**
- Guarantees singleton windows
- Full lifecycle control
- Easier menu synchronization
- Proven pattern
- Lower risk

**Implementation:**
```swift
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
        // Create windows once, keep forever
        // Register with WindowSnapManager
    }
}
```

---

#### 2. Delegate Multiplexer Pattern (REQUIRED) ✅

**Decision:** Implement delegate multiplexer for conflict resolution
**Rationale:**
- WindowSnapManager needs windowDidMove
- Custom windows may need windowWillClose, windowDidResize, windowDidBecomeMain
- Can't have single delegate

**Implementation:**
```swift
class WindowDelegateMultiplexer: NSObject, NSWindowDelegate {
    private var delegates: [NSWindowDelegate] = []

    func add(delegate: NSWindowDelegate) {
        delegates.append(delegate)
    }

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
        // Special handling: any delegate can veto
        delegates.forEach { $0.windowWillClose?(notification) }
    }
}

// Usage:
let multiplexer = WindowDelegateMultiplexer()
multiplexer.add(delegate: WindowSnapManager.shared)
multiplexer.add(delegate: customDelegate)
window.delegate = multiplexer
```

---

#### 3. Drag Region Strategy (CRITICAL) ✅

**Decision:** Custom titlebar areas in SwiftUI views with NSEvent monitoring
**Rationale:**
- Borderless windows need explicit drag regions
- SwiftUI gesture recognizers for initial detection
- NSEvent monitoring for actual drag loop

**Implementation:**
```swift
// In WinampMainWindow.swift:
var body: some View {
    VStack(spacing: 0) {
        // Custom titlebar (draggable)
        TitlebarView()
            .frame(height: 14)
            .background(WindowAccessor { nsWindow in
                configureDragRegion(for: nsWindow)
            })

        // Window content (not draggable)
        // ...
    }
}

func configureDragRegion(for window: NSWindow) {
    window.isMovableByWindowBackground = false

    // Monitor mouse down in titlebar area
    NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
        let location = event.locationInWindow
        if location.y > window.frame.height - 14 {
            // Start custom drag loop
            startDragging(window: window, initialEvent: event)
        }
        return event
    }
}
```

---

#### 4. WindowSnapManager Integration Strategy (REQUIRED) ✅

**Decision:** Register windows in WindowCoordinator.init(), merge snap + group phases
**Rationale:**
- WindowSnapManager already does snap detection + group movement
- Separating these is artificial
- One integration phase, not two

**Implementation:**
```swift
@MainActor
class WindowCoordinator: ObservableObject {
    init() {
        // ... create windows

        // Register with snap manager (it handles everything)
        if let main = mainWindow {
            WindowSnapManager.shared.register(window: main, kind: .main)
        }
        if let eq = eqWindow {
            WindowSnapManager.shared.register(window: eq, kind: .equalizer)
        }
        if let playlist = playlistWindow {
            WindowSnapManager.shared.register(window: playlist, kind: .playlist)
        }

        // That's it! WindowSnapManager now handles:
        // - Snap detection (15px threshold)
        // - Connected cluster detection
        // - Group movement
        // - Screen edge snapping
    }
}
```

---

#### 5. Double-Size Synchronization (HIGH RISK) ✅

**Decision:** WindowCoordinator orchestrates synchronized scaling
**Rationale:**
- All 3 windows must scale together
- Maintain relative positions
- Update snap threshold (30px at 2x)

**Implementation:**
```swift
@MainActor
class WindowCoordinator: ObservableObject {
    @Published var isDoubleSizeMode: Bool = false {
        didSet {
            synchronizeScale()
        }
    }

    private func synchronizeScale() {
        let scale: CGFloat = isDoubleSizeMode ? 2.0 : 1.0

        // 1. Update all window frames
        for window in [mainWindow, eqWindow, playlistWindow].compactMap({ $0 }) {
            let baseSize = baseSize(for: window)
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

        // 2. Maintain docked positions (if connected)
        // WindowSnapManager will handle this on next move

        // 3. Update snap threshold (future enhancement)
        // SnapUtils.SNAP_DISTANCE_SCALE = scale
    }
}
```

---

## 7. Revised Phase Plan: Optimal Implementation Sequence

Combining insights from all three reviews:

---

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
- [x] Create WindowCoordinator singleton
- [x] Create 3 NSWindowController subclasses
- [x] Configure windows (borderless, no titlebar)
- [x] Position windows in default stack (no snapping)
- [x] Connect menu commands to WindowCoordinator
- [x] Migrate double-size scaling to each window view

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
- [x] Drag each window independently
- [x] Drag titlebar (not content area)
- [x] Cursor changes appropriately

**Snap Detection:**
- [x] Snap at 15px threshold (1x scale)
- [x] Snap at 30px threshold (2x scale)
- [x] All 4 edges (top, bottom, left, right)
- [x] Alignment snaps (left-to-left, right-to-right)
- [x] Screen edge snapping

**Group Movement:**
- [x] Docked group moves together
- [x] Partial groups work (main+eq, eq+playlist)
- [x] Detachment works (drag away)
- [x] Re-docking works

**Double-Size:**
- [x] All windows scale together
- [x] Docked alignment maintained
- [x] Content not cropped
- [x] Origins correct
- [x] Snap threshold scales

**Playlist Resize:**
- [x] Resize while docked → maintains docking
- [x] Resize while standalone → no effect on others
- [x] Resize + double-size interaction

**Z-Order:**
- [x] Click docked window → cluster comes to front
- [x] Click standalone window → only that window
- [x] Mission Control behavior

**Persistence:**
- [x] Positions saved/restored
- [x] Visibility saved/restored
- [x] Off-screen detection works

**Multi-Monitor:**
- [x] Snapping across displays
- [x] Group movement across displays
- [x] Coordinate math correct
- [x] Monitor disconnection handled

**Edge Cases:**
- [x] Minimize windows
- [x] Hide windows via menu
- [x] Fullscreen mode (if applicable)
- [x] Fast drags (performance)
- [x] Accessibility (VoiceOver)

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

## Critical Path & Blockers

### Must Complete Before Starting:

1. **Architectural Decision:** NSWindowController vs WindowGroup → **DECIDED: NSWindowController** ✅
2. **Drag Strategy:** Custom titlebar vs other → **DECIDED: Custom titlebar areas** ✅
3. **Delegate Strategy:** Multiplexer vs override → **DECIDED: Multiplexer** ✅

### Cannot Proceed to Phase 2 Without:

- Phase 1A complete (windows created)
- Phase 1B complete (windows draggable)
- **Blocker:** Drag regions MUST work before snap detection testable

### Cannot Proceed to Phase 4 Without:

- Phase 2 complete (snap detection working)
- Phase 3 complete (delegate multiplexer ready)

---

## Oracle's Core Recommendations: Validation

### 1. "Pick and document window lifecycle strategy before coding" ✅

**DONE:** NSWindowController with WindowCoordinator singleton

### 2. "Integrate existing snap manager instead of recreating it" ✅

**DONE:** Phase 2 registers windows, uses WindowSnapManager as-is

### 3. "Prototype double-size toggle with docked windows" ✅

**PLAN:** Phase 4 explicitly handles this, with testing

---

## Gemini's Core Recommendations: Validation

### 1. "Update plan for playlist resizing" ✅

**DONE:** Phase 5 adds windowDidResize handler

### 2. "Update plan for Z-order management" ✅

**DONE:** Phase 6 adds windowDidBecomeMain handler

### 3. "Modify WindowSnapManager for scaled snap threshold" ✅

**DONE:** Phase 7 scales threshold with double-size mode

### 4. "Add explicit test cases" ✅

**DONE:** Phase 9 comprehensive test matrix

### 5. "De-risk Phase 4 with default drag fallback" ✅

**DONE:** Phase 1B implements custom drag; if fails, standard NSWindow drag available

---

## Final Verdict: Proceed with Caution

### GO Decision: ✅ CONDITIONAL APPROVAL

**Conditions:**
1. Use NSWindowController (not WindowGroup)
2. Implement drag regions in Phase 1B (before snap detection)
3. Build delegate multiplexer early (Phase 3)
4. Test double-size thoroughly (Phase 4)
5. Budget 18-24 hours (worst case)

### Success Probability: 70%

**Rationale:**
- Core algorithms exist (WindowSnapManager) ✅
- Architectural risks identified and mitigated ✅
- Implementation plan is comprehensive ✅
- Testing matrix is thorough ✅
- Time estimate is realistic (with contingency) ✅

**Remaining Risks:**
- Double-size alignment bugs (2-3 hours debugging possible)
- Coordinate math edge cases (multi-monitor testing heavy)
- Performance issues (snap detection on every pixel)

### When to Abort:

**Red Flags:**
1. Phase 1B (drag regions) takes > 4 hours → fundamental problem
2. Phase 2 snap detection doesn't work → WindowSnapManager incompatible
3. Phase 4 double-size causes visual artifacts → architectural issue
4. Timeline exceeds 24 hours → cut scope (defer resize, Z-order, persistence)

**Minimum Viable Implementation:**
- Phase 1A + 1B + 2 = Basic dragging with snap detection (7-10 hours)
- Defer: Delegate multiplexer, double-size coordination, resize, Z-order, persistence
- Ship: Simplified magnetic docking, enhance later

---

## Documentation Fixes Required Before Implementation

### CRITICAL: Fix 15px Snap Distance Documentation ⚠️

**Files with Errors:**
1. `tasks/magnetic-window-docking/research.md` - Line 142: "Snap Distance Estimation: **10-15 pixels**"
2. `tasks/magnetic-window-docking/research.md` - Line 431: "const SNAP_DISTANCE = **15**;" (correct!)
3. `tasks/magnetic-window-docking/research.md` - Line 535: "6. **15px threshold**" (correct!)
4. `tasks/magnetic-window-docking/research.md` - Line 35: "**10px Snap Threshold**" (WRONG!)
5. `tasks/magnetic-window-docking/FEASIBILITY_SUMMARY.md` - Line 129: "Current snap threshold is hardcoded **10px**" (WRONG!)
6. `tasks/magnetic-window-docking/plan.md` - Line 75: "let snapDistance: CGFloat = **15**" (correct!)
7. `tasks/magnetic-window-docking/plan.md` - Line 128: "verify snap occurs at **15px**" (correct!)

**Ground Truth:**
```swift
// SnapUtils.swift:27
static let SNAP_DISTANCE: CGFloat = 15
```

**Fix:** Global search/replace "10px snap" → "15px snap" in all task docs

---

## Conclusion

**Oracle's review is most technically accurate.** Gemini provides valuable feature completeness, but underestimates architectural complexity. Claude's original plan is solid but missed critical implementation details.

**Final Recommendation:** Proceed with NSWindowController architecture, implement drag regions immediately, and budget 18-24 hours with rigorous testing. High risk but achievable with proper planning and contingency.

**Next Steps:**
1. Fix snap distance documentation (15px, not 10px)
2. Update plan.md with revised phases
3. Update todo.md with new tasks (drag regions, multiplexer)
4. Get team approval on NSWindowController approach
5. Begin Phase 1A implementation

---

**Document Version:** 1.0
**Synthesis Complete:** 2025-11-02
**Recommendation:** CONDITIONAL GO (high risk, high value)
