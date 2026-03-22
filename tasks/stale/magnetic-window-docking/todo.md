# Magnetic Window Docking - Implementation Checklist (REVISED)

**Branch:** `feature/magnetic-window-docking`
**Base Commit:** `1235fc06af6daa6fca89d47ab1142514ce3bf5a0`
**Estimated Total Time:** 18-24 hours (worst case with contingency)
**Priority:** P3 (Post-1.0 enhancement)
**Status:** CONDITIONAL GO - High Risk (8/10)

**CRITICAL UPDATES from ULTRATHINK Synthesis (2025-11-02):**
- Architecture changed: NSWindowController (NOT WindowGroup)
- Phase 1B added: Drag regions (CRITICAL - must come before Phase 2)
- Phase 3 added: Delegate multiplexer (required)
- Phases 5-7 added: Playlist resize, Z-order, snap threshold scaling
- Time increased: 18-24 hours (from 10-16)
- Risk increased: 8/10 High (from 7/10 Medium-High)

---

## 📋 REVISED PHASE SUMMARY

| Phase | Description | Time | Priority | Status |
|-------|-------------|------|----------|--------|
| 1A | Separate Windows (NSWindowController) | 2-3h | CRITICAL | Ready |
| 1B | **Drag Regions** | 2-3h | **BLOCKER** | Ready |
| 2 | WindowSnapManager Integration | 3-4h | CRITICAL | Ready |
| 3 | **Delegate Multiplexer** | 1-2h | HIGH | Ready |
| 4 | Double-Size Coordination | 2-3h | HIGH | Ready |
| 5 | **Playlist Resize Handler** | 1-2h | MEDIUM | Ready |
| 6 | **Z-Order Management** | 1h | MEDIUM | Ready |
| 7 | **Snap Threshold Scaling** | 0.5h | LOW | Ready |
| 8 | State Persistence | 1-2h | LOW | Ready |
| 9 | Testing & Polish | 1-2h | CRITICAL | Ready |
| **TOTAL** | | **14-20h** | | |
| **Contingency** | +20% buffer | **+3-4h** | | |
| **WORST CASE** | | **18-24h** | | |

**NEW PHASES:**
- **Phase 1B:** Drag regions (MUST complete before Phase 2 - windows unmovable otherwise)
- **Phase 3:** Delegate multiplexer (Oracle identified delegate conflicts)
- **Phase 5:** Playlist resize (Gemini identified feature gap)
- **Phase 6:** Z-order management (Gemini identified feature gap)
- **Phase 7:** Snap threshold scaling for double-size mode (Gemini identified)

**ARCHITECTURAL CHANGE:**
- ❌ DEPRECATED: WindowGroup + WindowAccessor approach
- ✅ NEW: NSWindowController + WindowCoordinator singleton
- **Rationale:** WindowGroup doesn't guarantee singleton windows, causes lifecycle issues

---

## ⚠️ CRITICAL CHANGES FROM ORIGINAL PLAN

### 1. Architecture: NSWindowController (NOT WindowGroup)

**Original Plan:** Use SwiftUI WindowGroup with WindowAccessor
**NEW Plan:** Use NSWindowController subclasses with WindowCoordinator singleton

**Why Changed (Oracle/Codex):**
> "Raw WindowGroups risk duplicate instances and flaky close/restore behaviour. Prefer dedicated NSWindowControllers to keep the three window singletons in sync with menus."

**Impact on Tasks:**
- Phase 1A completely changed (create NSWindowControllers, not WindowGroups)
- Delete tasks related to WindowGroup configuration
- Add tasks for NSWindowController subclasses
- Add WindowCoordinator singleton

### 2. Phase 1B: Drag Regions (NEW - CRITICAL)

**Original Plan:** Phase 4 (Custom Drag Handling)
**NEW Plan:** Phase 1B (immediately after window separation)

**Why Changed (Oracle/Codex):**
> "Perform drag-region work immediately after splitting windows; otherwise users lose the ability to move borderless windows."

**Impact:**
- +2-3 hours to timeline
- BLOCKER for Phase 2 (snap detection untestable without movable windows)
- Must implement before any snap testing

### 3. Phase 3: Delegate Multiplexer (NEW)

**Original Plan:** Not addressed
**NEW Plan:** Phase 3 (after WindowSnapManager integration)

**Why Added (Oracle/Codex):**
> "WindowSnapManager installs itself as the window delegate; if additional delegate callbacks required, add a delegate multiplexer."

**Impact:**
- +1-2 hours to timeline
- Required for windowDidResize, windowDidBecomeMain, windowWillClose
- Prevents delegate conflicts

### 4. Phases 5-7: Feature Gaps (NEW)

**Original Plan:** Basic snapping only
**NEW Plan:** Add playlist resize, Z-order, snap threshold scaling

**Why Added (Gemini):**
- Playlist is resizable (others aren't) - needs special handling
- Docked windows should act as unit (Z-order management)
- Snap threshold must scale with double-size mode (15px → 30px at 2x)

**Impact:**
- +2.5 hours to timeline
- Improves feature completeness
- Polish features, not blockers

---

## 📋 Pre-Implementation Setup

- [x] Create feature branch
- [x] Complete research (Webamp, frame analysis, architecture review)
- [x] Validate existing WindowSnapManager implementation
- [x] Get feasibility assessment (Gemini: 8/10)
- [ ] Review all current window-related code
- [ ] Create backup of UnifiedDockView.swift for reference

---

## Phase 1: Separate Windows (2-3 hours)

### 1.1 Create WindowAccessor Utility
- [ ] Create `MacAmpApp/Utilities/WindowAccessor.swift`
- [ ] Implement NSViewRepresentable bridge to access NSWindow
- [ ] Add `onWindow` callback for NSWindow configuration
- [ ] Test with simple window property changes

**Acceptance Criteria:**
- WindowAccessor can access NSWindow from SwiftUI views
- Callback fires reliably on window appearance
- Window properties can be modified from SwiftUI

### 1.2 Create WindowCoordinator
- [ ] Create `MacAmpApp/ViewModels/WindowCoordinator.swift`
- [ ] Add `@Observable` and `@MainActor` attributes
- [ ] Track 3 NSWindow instances (main, equalizer, playlist)
- [ ] Implement window registration method
- [ ] Add computed properties for window visibility state

**Acceptance Criteria:**
- Coordinator tracks all 3 windows
- Windows can be registered/unregistered
- State updates propagate to UI

### 1.3 Replace UnifiedDockView with 3 WindowGroups
- [ ] Modify `MacAmpApp/MacAmpApp.swift`
- [ ] Remove UnifiedDockView import and usage
- [ ] Define WindowGroup for Main window (id: "main")
- [ ] Define WindowGroup for Equalizer (id: "equalizer")
- [ ] Define WindowGroup for Playlist (id: "playlist")
- [ ] Set `.defaultSize()` for each window
- [ ] Configure `.windowStyle(.hiddenTitleBar)` for all

**Acceptance Criteria:**
- 3 separate windows launch on app start
- Each window has correct dimensions
- No title bars visible
- Windows are independently movable

### 1.4 Migrate Double-Size Scaling to Individual Windows
- [ ] Add double-size scaling to WinampMainWindow.swift
  - [ ] Add `.scaleEffect()` based on AppSettings.isDoubleSizeMode
  - [ ] Add `.frame()` with dynamic width/height
  - [ ] Test scaling at 1x and 2x
- [ ] Add double-size scaling to WinampEqualizerWindow.swift
  - [ ] Same scaleEffect and frame logic
  - [ ] Test scaling synchronized with main
- [ ] Add double-size scaling to WinampPlaylistWindow.swift
  - [ ] Same scaleEffect and frame logic
  - [ ] Handle variable height correctly
- [ ] Implement synchronized scaling across all 3 windows
- [ ] Test D button toggles all windows together

**Acceptance Criteria:**
- All 3 windows scale correctly at 1x
- All 3 windows scale correctly at 2x
- Pressing D button scales all windows together
- Animation is smooth (0.2s easeInOut)
- Window positions maintained during scale

### 1.5 Update AppSettings for Window Positions
- [ ] Add `@AppStorage` properties for window positions
  - `mainWindowPosition: CGPoint?`
  - `equalizerWindowPosition: CGPoint?`
  - `playlistWindowPosition: CGPoint?`
- [ ] Add helper methods to save/restore positions
- [ ] Test persistence across app restarts

**Acceptance Criteria:**
- Window positions saved when moved
- Positions restored on app launch
- Handles nil (first launch) gracefully

### 1.6 Remove UnifiedDockView
- [ ] Delete `MacAmpApp/Views/UnifiedDockView.swift`
- [ ] Remove references from ContentView
- [ ] Clean up imports
- [ ] Update DockingController if needed

**Acceptance Criteria:**
- No compilation errors
- App launches with 3 separate windows
- No references to UnifiedDockView remain

---

## Phase 2: Window Snap Detection (3-4 hours)

### 2.1 Register Windows with WindowSnapManager
- [ ] Import WindowSnapManager in WinampMainWindow
- [ ] Add WindowAccessor to register main window
  ```swift
  WindowAccessor { window in
      WindowSnapManager.shared.register(window: window, kind: .main)
  }
  ```
- [ ] Repeat for WinampEqualizerWindow (kind: .equalizer)
- [ ] Repeat for WinampPlaylistWindow (kind: .playlist)
- [ ] Verify registration in debugger

**Acceptance Criteria:**
- All 3 windows registered on launch
- WindowSnapManager.shared.windows contains 3 entries
- Window kinds correctly identified

### 2.2 Test Existing Snap Detection
- [ ] Manually drag main window near equalizer
- [ ] Verify snap occurs at 15px threshold
- [ ] Test snap on all 4 edges (left, right, top, bottom)
- [ ] Test alignment variants (left-left, right-right, etc.)
- [ ] Test screen edge snapping
- [ ] Test multi-monitor snapping

**Acceptance Criteria:**
- Windows snap together at 15px threshold
- All 8 snap variants work (4 edges + 4 alignments)
- Screen edges also snap
- Multi-monitor snapping works correctly

### 2.3 Verify Cluster Detection
- [ ] Dock all 3 windows together
- [ ] Verify `connectedCluster` returns all 3 windows
- [ ] Test partial docking (Main+EQ only)
- [ ] Verify cluster detection for partial group
- [ ] Test disconnected windows (all separate)

**Acceptance Criteria:**
- All-docked: cluster contains 3 windows
- Partial-docked: cluster contains 2 windows
- Separate: clusters contain 1 window each
- BFS algorithm correctly finds connections

### 2.4 Debug Coordinate System Issues
- [ ] Add logging for window frames (bottom-left coordinates)
- [ ] Add logging for snap calculations
- [ ] Verify coordinate transformations (bottom-left → top-left)
- [ ] Test on multiple monitors with different positions
- [ ] Fix any coordinate bugs discovered

**Acceptance Criteria:**
- No windows snap to incorrect positions
- Multi-monitor coordinates correct
- Logging shows accurate calculations
- No windows positioned off-screen

---

## Phase 3: Group Movement (2-3 hours)

### 3.1 Implement Cluster Movement on Main Window Drag
- [ ] Detect when main window begins dragging
- [ ] Call `connectedCluster` to find docked windows
- [ ] Calculate delta from original position
- [ ] Apply delta to all windows in cluster
- [ ] Use `isAdjusting` flag to prevent snap loops

**Acceptance Criteria:**
- Dragging main window moves entire docked group
- Relative positions maintained during drag
- No jitter or snap loops
- Smooth movement at 60fps

### 3.2 Test Individual Window Detachment
- [ ] Drag equalizer away from docked group
- [ ] Verify only equalizer moves
- [ ] Verify main+playlist stay docked if they were
- [ ] Test all detachment combinations:
  - [ ] Drag main away (EQ+Playlist stay if docked)
  - [ ] Drag EQ away (Main+Playlist stay if docked)
  - [ ] Drag playlist away (Main+EQ stay if docked)

**Acceptance Criteria:**
- Individual windows can be detached
- Remaining docked windows maintain connection
- All 3 detachment scenarios work correctly

### 3.3 Test Re-attachment
- [ ] Drag detached window near docked group
- [ ] Verify snap occurs at 15px threshold
- [ ] Verify window joins the cluster
- [ ] Test re-attaching to different edges
- [ ] Test rebuilding full 3-window stack

**Acceptance Criteria:**
- Detached windows can re-attach
- Snap threshold consistent (15px)
- Cluster immediately includes re-attached window
- Can rebuild original vertical stack

### 3.4 Test Complex Docking Scenarios
- [ ] Test L-shaped docking (Main→EQ→Playlist horizontal)
- [ ] Test T-shaped docking (if possible with 3 windows)
- [ ] Test all windows separate
- [ ] Test rapid attach/detach cycles
- [ ] Test docking while in double-size mode

**Acceptance Criteria:**
- All docking configurations stable
- No crashes during complex arrangements
- Double-size mode compatible with all configs
- Cluster detection works for all shapes

---

## Phase 4: Custom Drag Handling (2-3 hours)

### 4.1 Implement Custom Drag Loop
- [ ] Create custom mouse-down handler in SwiftUI
- [ ] Detect drag start on window title area
- [ ] Track mouse position during drag
- [ ] Update window position programmatically
- [ ] Coordinate with WindowSnapManager.windowDidMove

**Acceptance Criteria:**
- Custom drag feels as smooth as native
- No lag or jitter
- Snap detection works during custom drag
- Performance at 60fps or better

### 4.2 Handle Edge Cases
- [ ] Test dragging partially off-screen
- [ ] Test dragging to different monitors
- [ ] Test dragging during app switch (Cmd+Tab)
- [ ] Test dragging during window minimize/restore
- [ ] Test dragging with accessibility zoom enabled

**Acceptance Criteria:**
- No crashes in edge cases
- Windows stay on valid screen areas
- Multi-monitor transitions smooth
- Accessibility compatible

### 4.3 Optimize Performance
- [ ] Profile drag performance with Instruments
- [ ] Optimize snap calculations if needed
- [ ] Reduce unnecessary window updates
- [ ] Test with 3 windows + 2 monitors
- [ ] Verify CPU usage < 10% during drag

**Acceptance Criteria:**
- Drag feels native (no perceptible lag)
- CPU usage minimal
- No frame drops during drag
- Smooth on both Intel and Apple Silicon

### 4.4 Test Double-Size During Drag
- [ ] Drag windows while in 2x mode
- [ ] Verify snap threshold scales (30px at 2x)
- [ ] Verify cluster movement at 2x
- [ ] Test toggling D during drag (edge case)

**Acceptance Criteria:**
- Dragging works correctly at 2x scale
- Snap threshold appropriate for scale (30px at 2x)
- No visual glitches
- Toggling scale during drag handled gracefully

---

## Phase 5: State Persistence (1 hour)

### 5.1 Save Window Positions
- [ ] Save position on window move
- [ ] Save to AppSettings/UserDefaults
- [ ] Debounce saves (avoid excessive writes)
- [ ] Test save during drag
- [ ] Test save on app quit

**Acceptance Criteria:**
- Positions saved reliably
- No excessive disk writes
- Saves survive app quit
- Background save doesn't block UI

### 5.2 Restore Window Positions on Launch
- [ ] Read saved positions on app launch
- [ ] Apply to windows before first display
- [ ] Handle missing data (first launch)
- [ ] Validate positions are on-screen
- [ ] Adjust if monitor configuration changed

**Acceptance Criteria:**
- Windows restore to saved positions
- First launch defaults to stacked layout
- Invalid positions corrected automatically
- Multi-monitor changes handled gracefully

### 5.3 Save/Restore Docking State (Optional Enhancement)
- [ ] Compute docking state on save
- [ ] Store which windows are connected
- [ ] Restore docking on launch
- [ ] Validate docking state is achievable

**Acceptance Criteria:**
- Docked windows restore as docked
- Separated windows restore as separated
- Invalid docking states corrected
- Smooth transition on launch

### 5.4 Handle Monitor Configuration Changes
- [ ] Detect monitor count change
- [ ] Detect primary monitor change
- [ ] Move off-screen windows back on-screen
- [ ] Preserve relative positions if possible
- [ ] Test disconnect/reconnect external display

**Acceptance Criteria:**
- No windows lost off-screen
- Adapts to monitor changes
- Relative positions preserved when possible
- External display disconnect handled

---

## Testing & Validation

### Functional Testing
- [ ] All 3 windows launch separately ✅
- [ ] Windows can be dragged independently ✅
- [ ] Magnetic snapping works (15px threshold) ✅
- [ ] Cluster movement works (drag main moves all) ✅
- [ ] Individual detachment works ✅
- [ ] Re-attachment works ✅
- [ ] Double-size mode works (1x ↔ 2x) ✅
- [ ] Position persistence works ✅
- [ ] State persistence works ✅

### Performance Testing
- [ ] Drag smoothness (60fps) ✅
- [ ] CPU usage during drag (< 10%) ✅
- [ ] Memory usage stable (no leaks) ✅
- [ ] App launch time acceptable ✅
- [ ] Multi-monitor performance acceptable ✅

### Edge Case Testing
- [ ] All windows separate ✅
- [ ] All windows docked ✅
- [ ] 2 windows docked, 1 separate ✅
- [ ] Windows partially off-screen ✅
- [ ] Multi-monitor configurations ✅
- [ ] Monitor disconnect/reconnect ✅
- [ ] App launch with missing monitors ✅
- [ ] Double-size + docking combinations ✅
- [ ] Rapid attach/detach cycles ✅
- [ ] Window close during drag ✅
- [ ] Cmd+W on docked vs separate windows ✅

### Regression Testing
- [ ] Skin loading still works ✅
- [ ] Playlist functionality intact ✅
- [ ] Equalizer functionality intact ✅
- [ ] Playback controls work ✅
- [ ] Menu bar items work ✅
- [ ] Keyboard shortcuts work ✅
- [ ] Double-size button works ✅
- [ ] All existing features unaffected ✅

---

## Documentation & Cleanup

- [ ] Update README with multi-window behavior
- [ ] Document WindowSnapManager integration
- [ ] Add code comments for custom drag logic
- [ ] Update architecture documentation
- [ ] Add screenshots of docking behavior
- [ ] Document known limitations
- [ ] Clean up debug logging
- [ ] Remove unused code
- [ ] Run linter and fix issues

---

## Deployment Checklist

- [ ] All tests passing ✅
- [ ] No compiler warnings ✅
- [ ] Performance acceptable ✅
- [ ] Code review complete ✅
- [ ] Documentation complete ✅
- [ ] Merge to main branch
- [ ] Tag release (if applicable)
- [ ] Monitor for issues in production

---

**Notes:**
- WindowSnapManager.swift already exists and is feature-complete! ✨
- Actual snap threshold: 15px (SnapUtils.swift:27)
- Main work is architectural refactor (UnifiedDockView → 3 NSWindows)
- Double-size mode logic must be migrated carefully
- Coordinate system (bottom-left vs top-left) requires careful attention
- Priority: P3 (not critical for v1.0 release)

**Estimated Breakdown:**
- Phase 1: 2-3 hours (window separation + double-size migration)
- Phase 2: 3-4 hours (snap detection integration)
- Phase 3: 2-3 hours (cluster movement)
- Phase 4: 2-3 hours (custom drag)
- Phase 5: 1 hour (persistence)
- **Total: 10-16 hours**
