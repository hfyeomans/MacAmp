# TODO: Magnetic Docking Foundation

**Status**: Ready for Oracle validation  
**Timeline**: 10-14 days  
**Scope**: Foundation only (NOT full polish)

**IMPORTANT**: This is TASK 1. Complete this FULLY before resuming milk-drop-video-support (Task 2).

---

## Phase 1A: NSWindowController Setup (Days 1-3) ⏳

### Day 1: WindowCoordinator

#### 1.1 Create WindowCoordinator.swift
- [ ] Create `MacAmpApp/ViewModels/WindowCoordinator.swift`
- [ ] Add `@MainActor @Observable` annotations
- [ ] Create singleton pattern (`static let shared`)
- [ ] Add properties for 3 NSWindowController references
- [ ] Add computed properties for NSWindow access
- [ ] Implement private init()

#### 1.2 WindowCoordinator Init Logic
- [ ] Create mainController (WinampMainWindowController)
- [ ] Create eqController (WinampEqualizerWindowController)
- [ ] Create playlistController (WinampPlaylistWindowController)
- [ ] Call configureWindows()
- [ ] Call setDefaultPositions()
- [ ] Call showAllWindows()

#### 1.3 Window Configuration
- [ ] Set titleVisibility = .hidden
- [ ] Set titlebarAppearsTransparent = true
- [ ] Set isMovableByWindowBackground = false
- [ ] Insert .borderless style mask
- [ ] Test configuration on all 3 windows

#### 1.4 Default Positioning
- [ ] Position Main at (100, 500)
- [ ] Position EQ at (100, 384) - 116px below Main
- [ ] Position Playlist at (100, 152) - 232px below EQ
- [ ] Test stacked layout

#### 1.5 Menu Commands
- [ ] Implement showMain(), hideMain()
- [ ] Implement showEqualizer(), hideEqualizer()
- [ ] Implement showPlaylist(), hidePlaylist()
- [ ] Test menu commands

**Day 1 Complete**: ✅ WindowCoordinator singleton created

### Day 2: NSWindowControllers ✅ COMPLETED IN DAY 1

#### 2.1 Create WinampMainWindowController
- [x] Create `MacAmpApp/Windows/WinampMainWindowController.swift`
- [x] Subclass NSWindowController
- [x] Create convenience init()
- [x] Create NSWindow with size 275×116
- [x] Set style mask ([.borderless] - Oracle fix)
- [x] Create NSHostingController (not just NSHostingView)
- [x] Set contentViewController and contentView

#### 2.2 Create WinampEqualizerWindowController
- [x] Create `MacAmpApp/Windows/WinampEqualizerWindowController.swift`
- [x] Same pattern as Main
- [x] Size: 275×116

#### 2.3 Create WinampPlaylistWindowController
- [x] Create `MacAmpApp/Windows/WinampPlaylistWindowController.swift`
- [x] Same pattern as Main/EQ
- [x] Size: 275×232

#### 2.4 Test Window Creation
- [x] Build app
- [x] Verify 3 NSWindowControllers created
- [x] Verify windows exist (not nil)
- [x] Check window sizes correct

**Day 2 Complete**: ✅ 3 NSWindowControllers created (done in Day 1)

### Day 3: MacAmpApp Integration ✅ COMPLETED IN DAY 1

#### 3.1 Update MacAmpApp.swift
- [x] Remove old WindowGroup approach (UnifiedDockView)
- [x] Keep Settings scene (for preferences)
- [x] Initialize WindowCoordinator in init()
- [x] Test app launches

#### 3.2 Delete UnifiedDockView
- [x] Analyzed UnifiedDockView.swift (migrated features)
- [x] Delete `MacAmpApp/Views/UnifiedDockView.swift`
- [x] Remove all UnifiedDockView references
- [x] Build and verify no errors

#### 3.3 UnifiedDockView Feature Migration (BONUS - Not in original plan)
- [x] Skin auto-loading
- [x] Always-on-top observer
- [x] Window configuration
- [x] Slider track handling
- [x] Bleed-through prevention
- [x] Menu positioning

#### 3.4 Integration Testing
- [x] Build and run app
- [x] Verify 3 windows launch
- [x] Verify windows positioned correctly (stacked)
- [x] Verify menu commands work
- [x] Verify no crashes
- [x] Verify all features working (sliders, buttons, menus)

**Day 3 Complete**: ✅ 3 independent windows launch + fully functional (done in Day 1)

---

## Phase 1B: Drag Regions (Days 4-6) ✅ SKIPPED - NOT NEEDED

### Discovery: WindowDragGesture Already Provides Dragging

**Found**: All 3 windows already use `WindowDragGesture()` (macOS 15+ API)
- Main window: SimpleSpriteImage with .gesture(WindowDragGesture())
- EQ window: Same pattern
- Playlist window: Same pattern

**Oracle Consultation**: WindowDragGesture works with WindowSnapManager!
- No custom drag implementation needed
- WindowDragGesture triggers windowDidMove notifications
- WindowSnapManager receives those notifications
- Magnetic snapping will work automatically in Phase 2

**Attempted Work**:
- [x] Discovered WindowAccessor already exists
- [x] Created TitlebarDragRegion component
- [x] Added to Main window
- [x] **DISCOVERED IT BROKE DRAGGING** (blocked existing gesture)
- [x] Reverted TitlebarDragRegion
- [x] Deleted TitlebarDragRegion.swift
- [x] Verified dragging works again

**Conclusion**: Phase 1B not required - skip to Phase 2

**Day 4-6 Complete**: ✅ SKIPPED (dragging already works via WindowDragGesture)

---

## Phase 2: WindowSnapManager Integration (Days 7-10) ⏳

### Day 7: Window Registration

#### 7.1 Register Windows with WindowSnapManager
- [ ] Open WindowCoordinator.swift init()
- [ ] Register Main: `WindowSnapManager.shared.register(window: mainWindow, kind: .main)`
- [ ] Register EQ: `WindowSnapManager.shared.register(window: eqWindow, kind: .equalizer)`
- [ ] Register Playlist: `WindowSnapManager.shared.register(window: playlist Window, kind: .playlist)`
- [ ] Build and test

#### 7.2 Test Basic Snap Detection
- [ ] Drag Main near EQ (horizontal)
- [ ] Verify snap occurs at ~15px
- [ ] Log snap events in console
- [ ] Verify snap feels right

**Day 7 Complete**: ✅ Windows registered, basic snapping works

### Day 8: Comprehensive Snap Testing

#### 8.1 Edge Snap Tests
- [ ] Snap Main to EQ (right edge to left edge)
- [ ] Snap EQ to Playlist (bottom edge to top edge)
- [ ] Snap Playlist to Main (left edge to right edge)
- [ ] Test all 4 edges (top, bottom, left, right)

#### 8.2 Alignment Snap Tests
- [ ] Align left edges (Main and EQ)
- [ ] Align right edges
- [ ] Align top edges
- [ ] Align bottom edges

#### 8.3 Screen Edge Snapping
- [ ] Drag window to screen edges
- [ ] Verify snaps to screen boundaries
- [ ] Test all 4 screen edges

**Day 8 Complete**: ✅ All snap types working

### Day 9: Cluster Movement

#### 9.1 Test Group Movement
- [ ] Stack Main + EQ + Playlist (docked)
- [ ] Drag Main window
- [ ] Verify EQ and Playlist move together
- [ ] Verify relative positions maintained

#### 9.2 Test Partial Clusters
- [ ] Dock Main + EQ (leave Playlist separate)
- [ ] Drag Main → verify EQ moves, Playlist doesn't
- [ ] Dock EQ + Playlist (leave Main separate)
- [ ] Drag EQ → verify Playlist moves, Main doesn't

#### 9.3 Test Detachment
- [ ] Dock all 3 windows
- [ ] Drag Playlist away from group
- [ ] Verify it detaches and moves alone
- [ ] Verify Main + EQ stay docked

#### 9.4 Test Re-Attachment
- [ ] Detach window from group
- [ ] Drag back near group
- [ ] Verify it re-snaps and joins cluster

**Day 9 Complete**: ✅ Cluster movement works

### Day 10: Multi-Monitor & Edge Cases

#### 10.1 Multi-Monitor Testing
- [ ] Drag windows to second monitor
- [ ] Verify snapping still works
- [ ] Drag cluster across monitors
- [ ] Test coordinate math correctness

#### 10.2 Edge Case Testing
- [ ] Windows off-screen (partially)
- [ ] Windows on different monitors
- [ ] Rapid drag movements
- [ ] Complex docking shapes (L, T)

**Day 10 Complete**: ✅ WindowSnapManager fully integrated

---

## Phase 3: Delegate Multiplexer (Days 11-12) ⏳

### Day 11: Create Multiplexer

#### 11.1 Create WindowDelegateMultiplexer.swift
- [ ] Create `MacAmpApp/Utilities/WindowDelegateMultiplexer.swift`
- [ ] Subclass NSObject, implement NSWindowDelegate
- [ ] Add delegates array property
- [ ] Implement add(delegate:) method

#### 11.2 Forward Delegate Methods
- [ ] Forward windowDidMove
- [ ] Forward windowDidResize
- [ ] Forward windowDidBecomeMain
- [ ] Forward windowWillClose

**Day 11 Complete**: ✅ Multiplexer created

### Day 12: Integration & Testing

#### 12.1 Integrate Multiplexer
- [ ] Update WindowCoordinator.init()
- [ ] Create multiplexer for each window
- [ ] Add WindowSnapManager to multiplexer
- [ ] Set window.delegate = multiplexer

#### 12.2 Test Delegate Forwarding
- [ ] Verify WindowSnapManager still receives windowDidMove
- [ ] Test snapping still works
- [ ] Test cluster movement still works

**Day 12 Complete**: ✅ Delegate multiplexer working

---

## Phase 4: Double-Size Coordination (Days 13-15) ⏳

### Day 13: Migrate Scaling Logic

#### 13.1 Update WinampMainWindow
- [ ] Add @Environment(AppSettings.self)
- [ ] Add .scaleEffect modifier
- [ ] Scale: appSettings.isDoubleSizeMode ? 2.0 : 1.0
- [ ] Anchor: .topLeading
- [ ] Add .frame modifier with scaled dimensions
- [ ] Test content scales

#### 13.2 Update WinampEqualizerWindow
- [ ] Same scaling logic as Main
- [ ] Test content scales

#### 13.3 Update WinampPlaylistWindow
- [ ] Same scaling logic
- [ ] Test content scales

**Day 13 Complete**: ✅ Content scaling migrated to views

### Day 14: Synchronized Frame Resizing

#### 14.1 WindowCoordinator Double-Size Observer
- [ ] Observe AppSettings.isDoubleSizeMode
- [ ] When changed, call resizeWindows()

#### 14.2 Implement resizeWindows()
- [ ] Calculate new sizes for all 3 windows
- [ ] Main: 275×116 or 550×232
- [ ] EQ: 275×116 or 550×232
- [ ] Playlist: 275×232 or 550×464
- [ ] Call setFrame on all windows simultaneously
- [ ] Animate: true

#### 14.3 Maintain Docked Layout
- [ ] After resize, verify docked windows stay aligned
- [ ] Adjust origins if needed
- [ ] Test cluster stays intact during scale

**Day 14 Complete**: ✅ Double-size mode works with all 3 windows

### Day 15: Double-Size Testing

#### 15.1 Test Double-Size with Docking
- [ ] Dock all 3 windows
- [ ] Toggle double-size (D button)
- [ ] Verify all scale together
- [ ] Verify alignment maintained
- [ ] Verify no visual glitches

#### 15.2 Test Edge Cases
- [ ] Toggle D while dragging
- [ ] Toggle D with windows detached
- [ ] Toggle D multiple times rapidly
- [ ] Verify stable

**Day 15 Complete** (may finish Day 14): ✅ Double-size fully functional

---

## Phase 5: Basic Persistence (Days 16-17 - OPTIONAL) ⏳

### Day 16: Implement Persistence

#### 16.1 AppSettings Extension
- [ ] Add mainWindowPosition: CGPoint (with get/set)
- [ ] Add eqWindowPosition: CGPoint
- [ ] Add playlistWindowPosition: CGPoint
- [ ] Add window visibility bools
- [ ] Import AppKit for NSPointFromString

#### 16.2 WindowCoordinator Save
- [ ] Implement saveState() method
- [ ] Save all 3 window positions
- [ ] Save all 3 visibility states
- [ ] Call on windowWillClose or app termination

#### 16.3 WindowCoordinator Restore
- [ ] Implement restoreState() method
- [ ] Load saved positions
- [ ] Apply to windows
- [ ] Use defaults if no saved state

**Day 16 Complete**: ✅ Basic persistence implemented

### Day 17: Persistence Testing

#### 17.1 Test Save/Restore
- [ ] Position windows custom layout
- [ ] Quit app
- [ ] Relaunch app
- [ ] Verify positions restored

#### 17.2 Test Defaults
- [ ] Delete UserDefaults (clean slate)
- [ ] Launch app
- [ ] Verify default positions used

**Day 17 Complete** (may not be needed): ✅ Persistence works

---

## Foundation Complete Checklist ✅

### Core Functionality (Must-Have)
- [ ] 3 independent NSWindows launch
- [ ] Windows positioned in default stack
- [ ] Windows draggable by titlebar area
- [ ] Magnetic snapping works (15px threshold)
- [ ] Cluster movement works (group dragging)
- [ ] Windows can detach individually
- [ ] Windows can re-attach to groups
- [ ] Double-size mode works with all 3 windows
- [ ] Window positions persist (basic)
- [ ] No regressions in existing features

### Quality Checks
- [ ] Smooth dragging (60fps)
- [ ] No visual glitches
- [ ] No memory leaks
- [ ] No console errors
- [ ] Thread Sanitizer clean

### Documentation
- [ ] Code comments added
- [ ] Architecture documented
- [ ] Update READY_FOR_NEXT_SESSION.md
- [ ] Create completion summary

---

## Deferred Features (NOT in This Task)

**Polish Features** (add in future polish task if needed):
- ⏳ Playlist resize-aware docking
- ⏳ Z-order cluster focus management
- ⏳ Scaled snap threshold (30px at 2x)
- ⏳ Advanced persistence (off-screen detection)
- ⏳ Accessibility enhancements (VoiceOver)

**Rationale**: Foundation infrastructure is complete, polish can wait

---

## After Foundation Complete

### Task Completion Steps
1. ✅ All checkboxes above completed
2. ✅ Comprehensive testing passed
3. ✅ No regressions
4. ✅ Code committed
5. ✅ Task archived to `tasks/done/magnetic-docking-foundation/`

### Resume Next Task
**Next**: `tasks/milk-drop-video-support/` (Task 2)
- Add Video window (follows NSWindowController pattern)
- Add Milkdrop window (follows NSWindowController pattern)
- VIDEO.bmp sprite parsing
- Butterchurn integration
- Register with WindowSnapManager (trivial!)

**Timeline for Task 2**: 8-10 days (much easier after foundation)

---

**Task Organization**: ONE task at a time (no blending)  
**This Task**: Foundation ONLY  
**Next Task**: Video/Milkdrop (resume after complete)  
**Last Updated**: 2025-11-08
