# Magnetic Window Docking - Task State

**Date:** 2025-11-02
**Branch:** `feature/magnetic-window-docking`
**Base Commit:** `1235fc06af6daa6fca89d47ab1142514ce3bf5a0`
**Status:** READY FOR IMPLEMENTATION
**Priority:** P3 (Post-1.0 enhancement)

---

## 🎯 Current State

### Research Phase: ✅ COMPLETE

**Completed Activities:**
1. ✅ Analyzed Webamp implementation (JavaScript/React)
2. ✅ Frame-by-frame video analysis of Winamp behavior (40 frames)
3. ✅ Reviewed existing MacAmp architecture
4. ✅ Discovered WindowSnapManager.swift already exists!
5. ✅ Consulted Gemini for feasibility assessment
6. ✅ Consolidated research into single comprehensive document
7. ✅ Created detailed implementation plan
8. ✅ Created comprehensive todo checklist

**Key Discovery:** 🎉
MacAmp already has a complete WindowSnapManager implementation (MacAmpApp/Utilities/WindowSnapManager.swift) with:
- 15px snap threshold (SnapUtils.swift:27)
- Cluster detection via depth-first search
- Screen edge snapping
- Multi-monitor support
- Connection detection
- Feedback prevention

**What's Missing:**
The manager exists but isn't integrated because MacAmp uses a single UnifiedDockView instead of separate NSWindows.

---

## 📊 Feasibility Assessment

### Overall Scores (Gemini Analysis)

**Implementation Complexity: 8/10**
- High complexity but achievable
- Major architectural refactor required
- Existing WindowSnapManager reduces scope significantly

**Risk of Breaking Features: 7/10**
- Touches core UI structure
- Double-size mode must be migrated carefully
- State synchronization across windows
- Coordinate system transformations

**Time Estimate: 10-16 hours** ✅ VALIDATED
- Well-structured 5-phase plan
- Reasonable for experienced developer
- Existing WindowSnapManager saves 3-4 hours

**Feasibility Rating: 8/10 - Highly Achievable**

---

## 🚧 Top 3 Technical Blockers

### 1. Custom Window Dragging Performance
**Risk:** Laggy, jerky, or unstable movement
- Snap detection runs on every mouse-drag event
- Must feel as smooth as native macOS window movement
- Target: 60fps, < 10% CPU usage

**Mitigation:**
- Profile with Instruments
- Optimize snap calculations
- Use efficient data structures
- Test on both Intel and Apple Silicon

### 2. State Synchronization
**Risk:** Race conditions or desynchronization
- Double-size mode must apply to all windows simultaneously
- Maintaining relative docked positions is complex
- Three separate window lifecycles to coordinate

**Mitigation:**
- Use @MainActor for thread safety
- Single source of truth for window state
- Synchronous window updates during scaling
- Comprehensive state transition testing

### 3. Coordinate System Management
**Risk:** Windows snap incorrectly or position off-screen
- NSWindow uses bottom-left origin (AppKit)
- SwiftUI uses top-left origin
- Multi-monitor setups complicate coordinate math

**Mitigation:**
- Careful coordinate transformation logic
- Extensive multi-monitor testing
- Bounds validation before positioning
- Reference WindowSnapManager implementation (already handles this!)

---

## 📋 Implementation Plan Summary

### Phase 1: Separate Windows (2-3 hours)
- Create WindowAccessor utility (SwiftUI → NSWindow bridge)
- Create WindowCoordinator (@Observable state manager)
- Replace UnifiedDockView with 3 WindowGroups
- Migrate double-size scaling to each window
- Update AppSettings for window positions
- Delete UnifiedDockView.swift

### Phase 2: Window Snap Detection (3-4 hours)
- Register all 3 windows with WindowSnapManager
- Test existing snap detection (15px threshold)
- Verify cluster detection algorithm
- Debug coordinate system issues
- Test multi-monitor snapping

### Phase 3: Group Movement (2-3 hours)
- Implement cluster movement on main window drag
- Test individual window detachment
- Test re-attachment to groups
- Test complex docking scenarios
- Verify double-size compatibility

### Phase 4: Custom Drag Handling (2-3 hours)
- Implement custom drag loop in SwiftUI
- Handle edge cases (off-screen, multi-monitor)
- Optimize performance (60fps target)
- Test double-size during drag
- Coordinate with WindowSnapManager

### Phase 5: State Persistence (1 hour)
- Save window positions to UserDefaults
- Restore positions on app launch
- Handle monitor configuration changes
- Optional: Save/restore docking state

---

## 🎯 Migration Strategy

**Approach:** Complete Cutover on Feature Branch ✅

**Rationale:**
- Two paradigms (single vs multi-window) too different to coexist
- Feature flag would add unnecessary complexity
- Clean cutover is safer and cleaner
- Can test thoroughly on branch before merge

**Steps:**
1. Complete all work on `feature/magnetic-window-docking` branch
2. Extensive testing of all functionality
3. Validate no regressions in existing features
4. Merge to main when fully complete
5. Tag as post-1.0 enhancement release

---

## 📂 Files Affected

### To Create
- `MacAmpApp/Utilities/WindowAccessor.swift` - NEW
- `MacAmpApp/ViewModels/WindowCoordinator.swift` - NEW

### To Modify
- `MacAmpApp/MacAmpApp.swift` - Replace UnifiedDockView with 3 WindowGroups
- `MacAmpApp/Views/WinampMainWindow.swift` - Add window registration + double-size
- `MacAmpApp/Views/WinampEqualizerWindow.swift` - Add window registration + double-size
- `MacAmpApp/Views/WinampPlaylistWindow.swift` - Add window registration + double-size
- `MacAmpApp/Models/AppSettings.swift` - Add window position storage

### To Delete
- `MacAmpApp/Views/UnifiedDockView.swift` - REMOVE ENTIRELY

### Unchanged (Already Complete!)
- `MacAmpApp/Utilities/WindowSnapManager.swift` - NO CHANGES NEEDED! ✨

---

## ✅ Prerequisites for Implementation

1. ✅ Research complete
2. ✅ Existing code reviewed
3. ✅ WindowSnapManager validated as complete
4. ✅ Feasibility confirmed (8/10)
5. ✅ Implementation plan created
6. ✅ Todo checklist created
7. ✅ Feature branch created
8. ⏳ Awaiting go-ahead for implementation

---

## 🔄 Next Steps

**Immediate:**
1. Begin Phase 1 implementation (if approved)
2. Create WindowAccessor utility first (foundation)
3. Create WindowCoordinator for state management
4. Replace UnifiedDockView with 3 WindowGroups

**After Phase 1:**
- Validate 3 windows launch correctly
- Test basic independent movement
- Verify no regressions in existing functionality

**Milestone Markers:**
- Phase 1 complete: 3 separate windows working ✓
- Phase 2 complete: Magnetic snapping functional ✓
- Phase 3 complete: Cluster movement working ✓
- Phase 4 complete: Custom drag smooth ✓
- Phase 5 complete: Positions persisted ✓
- Final: All tests passing, ready to merge ✓

---

## 📊 Success Criteria

### Must Have (P0)
- [ ] 3 separate NSWindows launch on app start
- [ ] Windows can be dragged independently
- [ ] Magnetic snapping works (15px threshold)
- [ ] Cluster movement works (drag main moves all docked)
- [ ] Windows can be detached individually
- [ ] Windows can re-attach to groups
- [ ] Double-size mode works with all windows
- [ ] Position persistence works
- [ ] No regressions in existing features

### Should Have (P1)
- [ ] Smooth 60fps dragging performance
- [ ] Multi-monitor support
- [ ] Screen edge snapping
- [ ] Handles monitor configuration changes
- [ ] Docking state persistence

### Nice to Have (P2)
- [ ] Visual snap feedback (optional)
- [ ] Keyboard modifiers to disable snapping
- [ ] Fine-tuned snap threshold per-edge
- [ ] Advanced docking configurations (L-shape, T-shape)

---

## 🎓 Lessons Learned from Research

### From Webamp Analysis:
1. 15px snap threshold is industry standard (MacAmp uses 15px)
2. Don't persist connections - compute from positions
3. Use BFS/DFS for cluster detection (WindowSnapManager does this!)
4. Bounding box approach for group movement
5. Main window as "leader" for group drags

### From Frame Analysis:
1. Partial docking is critical (Main+EQ while Playlist separate)
2. Zero-pixel gap when docked
3. No visual feedback during snap (implicit behavior)
4. Detachment happens immediately on drag

### From Architecture Review:
1. WindowSnapManager already handles the hard parts!
2. Double-size mode must be migrated carefully
3. Coordinate systems require careful transformation
4. @Observable pattern simplifies state management

---

## 🚀 Decision Log

**2025-10-23:** Task created, initial research started
**2025-10-23:** Video frame analysis completed (40 frames)
**2025-10-23:** Webamp implementation analyzed
**2025-10-23:** Task DEFERRED to P3 (post-1.0)
**2025-11-02:** Research consolidated, feasibility confirmed
**2025-11-02:** Feature branch created
**2025-11-02:** Comprehensive plan and todos created
**2025-11-02:** Task status: READY FOR IMPLEMENTATION

**Current Decision:** DEFERRED to P3 priority (post-1.0 release)
- Complexity: High (8/10)
- Time: 10-16 hours
- Risk: Medium-High (7/10 for breaking features)
- Benefit: High (authentic Winamp experience)
- Urgency: Low (not critical for v1.0)

---

## 📝 Notes

- WindowSnapManager.swift is a hidden gem - already implements everything we need!
- Actual snap threshold: 15px (SnapUtils.swift:27)
- Main challenge is architectural refactor, not snap algorithm
- Double-size mode implementation provides useful reference for window scaling
- Coordinate system transformation is well-documented in WindowSnapManager
- Testing strategy should focus on edge cases and multi-monitor scenarios

**Recommendation:** Implement post-1.0 when time allows for thorough testing and polish.

---

---

## 🎯 FINAL SCORES & DECISION (ULTRATHINK Synthesis 2025-11-02)

### Final Assessment

**Feasibility: 7/10** ⬇️ Downgraded from Gemini's 9/10, matches Oracle's 7/10

**Reasoning:**
- Core algorithms exist (WindowSnapManager) ✅
- But lifecycle architecture is complex ⚠️
- Drag regions are non-trivial ⚠️
- Delegate conflicts need resolution ⚠️
- Double-size coordination is risky ⚠️

**Achievable but not "highly achievable" - 7/10 is accurate.**

---

**Risk: 8/10 High** ⬆️ Upgraded from Gemini's 6/10, matches Oracle's 8/10

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
- **Schedule Risk:** 7/10 (18-24 hours, could slip)
- **Quality Risk:** 7/10 (subtle bugs hard to catch)
- **Maintenance Risk:** 6/10 (complex code to maintain)

**Overall: HIGH RISK (8/10)**

---

**Time Estimate: 18-24 hours** ⬆️ Increased from 10-16 hours

**Phase Breakdown:**

| Phase | Description | Time |
|-------|-------------|------|
| 1A | Separate windows (NSWindowController) | 2-3h |
| 1B | Drag regions (CRITICAL) | 2-3h |
| 2 | WindowSnapManager integration | 3-4h |
| 3 | Delegate multiplexer | 1-2h |
| 4 | Double-size coordination | 2-3h |
| 5 | Playlist resize | 1-2h |
| 6 | Z-order management | 1h |
| 7 | Snap threshold scaling | 0.5h |
| 8 | State persistence | 1-2h |
| 9 | Testing & polish | 1-2h |
| **TOTAL** | | **14-20h** |

**Risk Contingency:** +20% (3-4 hours) = **18-24 hours worst case**

**Assumptions:**
- Experienced Swift/AppKit developer
- Familiar with MacAmp codebase
- No major unforeseen issues
- Testing time included

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

### Top 5 Architectural Decisions Made:

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

#### 4. WindowSnapManager Integration Strategy (REQUIRED) ✅

**Decision:** Register windows in WindowCoordinator.init(), merge snap + group phases
**Rationale:**
- WindowSnapManager already does snap detection + group movement
- Separating these is artificial
- One integration phase, not two

#### 5. Double-Size Synchronization (HIGH RISK) ✅

**Decision:** WindowCoordinator orchestrates synchronized scaling
**Rationale:**
- All 3 windows must scale together
- Maintain relative positions
- Update snap threshold (30px at 2x)

---

## 📋 Final Verdict: CONDITIONAL GO ✅

### Decision: PROCEED WITH CAUTION

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

---

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

### Review Consensus

**Claude (Original Research):**
- Feasibility: 8/10
- Risk: 7/10 Medium-High
- Time: 10-16 hours
- **Verdict:** Solid foundation but missed critical details

**Gemini (Feasibility Review):**
- Feasibility: 9/10 ✅ OPTIMISTIC
- Risk: 6/10 Medium ❌ UNDERESTIMATED
- Time: 12-18 hours (adjusted)
- **Verdict:** Feature-complete but underestimated architecture risks

**Oracle/Codex (Architecture Review):**
- Feasibility: 7/10 ✅ ACCURATE
- Risk: 8/10 High ✅ ACCURATE
- Time: 12-18 hours (base)
- **Verdict:** Most technically accurate, caught showstoppers

**ULTRATHINK Synthesis:**
- Feasibility: 7/10 (Oracle is correct)
- Risk: 8/10 High (Oracle is correct)
- Time: 18-24 hours (with contingency)
- **Verdict:** Oracle's assessment validated, Gemini's features added

---

**Status:** ✅ CONDITIONAL GO - High Risk (8/10), High Value
**Decision Date:** 2025-11-02
**Architecture:** NSWindowController (NOT WindowGroup)
**Risk Level:** HIGH (8/10) - Proceed with caution
**Confidence:** 70% success probability with proper execution
**Estimated Effort:** 18-24 hours (worst case with 20% contingency)

---

## 🚦 Before Implementation - Required Approvals

**Status:** ⏸️ AWAITING DECISIONS

### 1. Get Team Buy-In on NSWindowController Approach ⏳

**Decision Required:** Approve NSWindowController architecture (not raw WindowGroup)

**Why NSWindowController:**
- ✅ Guarantees singleton windows (no duplicates)
- ✅ Full lifecycle control
- ✅ Trivial menu synchronization
- ✅ Lower architectural risk
- ✅ Oracle's strong recommendation

**Risk of WindowGroup:**
- ❌ Creates windows on-demand (can duplicate)
- ❌ Flaky close/restore behavior
- ❌ Complex menu synchronization
- ❌ No singleton guarantees

**Required:** Architectural decision approval from tech lead/team

---

### 2. Approve 18-24 Hour Time Budget ⏳

**Requested Timeline:** 18-24 hours (worst case with 20% contingency)

**Breakdown:**
- Base implementation: 14-20 hours
- Risk contingency: +20% (3-4 hours)
- Total range: 18-24 hours

**Comparison to Original Estimates:**
- Original: 10-16 hours
- Gemini: 12-18 hours
- Oracle: 12-18 hours (base)
- **Final with gaps:** 18-24 hours

**Justification:**
- Added Phase 1B (drag regions) +2-3h
- Added Phase 3 (delegate multiplexer) +1-2h
- Added Phases 5-7 (resize, Z-order, threshold) +2.5-3h
- Contingency for coordinate debugging +3-4h

**Required:** Time budget approval from product owner

---

### 3. Acknowledge High Risk (8/10) ⏳

**Risk Level:** HIGH (8/10)

**Oracle's Risk Factors:**
1. Window lifecycle drift
2. Double-size alignment bugs
3. Delegate conflicts
4. Drag UX regression (borderless windows)
5. Persistence restoring off-screen clusters
6. Multi-monitor edge cases

**Gemini's Risk Factors:**
1. Playlist resize breaks docking
2. Z-order doesn't feel right
3. State synchronization races
4. Performance during drag

**Mitigation Required:**
- Singleton controllers (Oracle)
- Coordinated resize routine (Gemini)
- Delegate multiplexer (Oracle)
- Early drag prototype (Oracle)
- Bounds normalization (Oracle)
- Extensive testing (All)

**Required:** Formal risk acknowledgment and mitigation plan approval

---

### 4. Review ULTRATHINK_SYNTHESIS.md in Detail ⏳

**Location:** `tasks/magnetic-window-docking/archive/ULTRATHINK_SYNTHESIS.md`

**Contents:** 1,546 lines of comprehensive analysis
- Complete three-team comparison
- Critical issues ranked (12 total)
- Revised 9-phase implementation plan
- Final scores with rationale
- Architectural decisions explained
- Testing matrix

**Action Required:**
- [ ] Tech lead reviews ULTRATHINK_SYNTHESIS.md
- [ ] Confirms agreement with Oracle's recommendations
- [ ] Approves NSWindowController architecture
- [ ] Understands all 12 identified issues
- [ ] Approves revised 9-phase sequence

**Timeline:** 30-60 minutes for thorough review

---

### 5. Consider Deferring to Post-1.0 (P3 Priority) ⏳

**Current Recommendation:** DEFER to P3

**Rationale for Deferral:**
- ⚠️ High complexity (7/10 feasibility)
- ⚠️ High risk (8/10 - architectural change)
- ⚠️ Significant time (18-24 hours)
- ⚠️ Not critical for v1.0 launch
- ✅ Current unified window works
- ✅ Can ship v1.0 without magnetic docking

**Rationale for Proceeding:**
- ✅ WindowSnapManager already exists (reduces risk)
- ✅ Authentic Winamp experience (high value)
- ✅ Comprehensive planning complete
- ✅ Clear implementation path
- ✅ Testing strategy in place

**Decision Required:**
- [ ] Ship v1.0 with current unified window (defer magnetic docking)
- [ ] Implement magnetic docking pre-v1.0 (18-24 hour investment)

**Impact:**
- Defer: Low risk, faster to v1.0, implement in v1.1/v2.0
- Proceed: High risk, authentic Winamp experience, delays v1.0 by ~3 days

---

## ✅ Prerequisites Checklist

**Before Implementation Can Begin:**
- [ ] NSWindowController architecture approved
- [ ] 18-24 hour time budget approved
- [ ] High risk (8/10) formally acknowledged
- [ ] ULTRATHINK_SYNTHESIS.md reviewed by tech lead
- [ ] Defer vs proceed decision made
- [ ] All 5 synthesis files reviewed for completeness
- [ ] Team understands 15px snap distance (not 10px)
- [ ] Oracle's 3 showstoppers understood and accepted

**If All Prerequisites Met:**
→ Proceed to Phase 1A implementation

**If Any Blocked:**
→ Task remains DEFERRED at P3 priority

---

**Checkpoint:** ⏸️ AWAITING APPROVALS (5 required)
**Next Action:** Obtain required decisions before proceeding
