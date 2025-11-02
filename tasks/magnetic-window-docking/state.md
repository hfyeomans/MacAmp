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

**Status:** ✅ READY FOR IMPLEMENTATION (Awaiting P3 scheduling)
**Risk Level:** Medium-High (architectural change)
**Confidence:** High (existing WindowSnapManager + clear plan)
**Estimated Effort:** 10-16 hours (validated by Gemini)
