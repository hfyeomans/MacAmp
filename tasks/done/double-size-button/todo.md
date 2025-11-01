# Implementation TODO: Double-Sized Button

## Date Created
2025-10-30

## Overview
Implementation checklist for adding the "D" (Double-sized) button that toggles the main window between 100% and 200% scale.

---

## 📊 Progress Summary

**Git Branch:** `double-sized-button`
**Latest Commit:** `6bb3b67` - docs: Document Ctrl+D and Ctrl+A keyboard shortcuts
**Total Commits:** 12

### Completion Status

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: Discovery & Verification | ✅ Complete | 100% |
| Phase 2: Window Reference Capture | ✅ Complete | 100% |
| Phase 3: Button Styles | ✅ Complete | 100% |
| Phase 4: Clutter Bar Implementation | ✅ Complete | 100% |
| Phase 5: Window Resize Animation | ✅ Complete | 100% |
| Phase 6: Testing | ✅ Complete | 100% |
| Phase 7: Documentation | ✅ Complete | 100% |

**Overall Progress:** 100% complete (7 of 7 phases done)
**Status:** ✅ **FEATURE COMPLETE - SHIPPED!**

### Files Modified (6)
1. ✅ `MacAmpApp/Models/AppSettings.swift` - isDoubleSizeMode + isAlwaysOnTop states
2. ✅ `MacAmpApp/Models/SkinSprites.swift` - 12 clutter bar button sprites (fixed coordinates)
3. ✅ `MacAmpApp/Views/WinampMainWindow.swift` - buildClutterBarButtons() with A & D functional
4. ✅ `MacAmpApp/Views/UnifiedDockView.swift` - Scaling + window level toggle
5. ✅ `MacAmpApp/AppCommands.swift` - Keyboard shortcuts + reactive menu
6. ✅ `MacAmpApp/MacAmpApp.swift` - Pass settings to AppCommands
7. ✅ `README.md` - Documentation for all features

### Files Deleted (1)
1. ✅ `MacAmpApp/Views/Components/SkinToggleStyle.swift` - Unused (Oracle cleanup)

### Documentation Created (Phase 7)
1. ✅ `tasks/double-size-button/FEATURE_DOCUMENTATION.md` - Complete user & developer docs
2. ✅ `tasks/double-size-button/COMPLETION_SUMMARY.md` - Final delivery summary
3. ✅ `README.md` - Updated with D button, A button, and keyboard shortcuts
4. ✅ `tasks/magnetic-window-docking/research.md` - Migration guide for separate windows

### Features Delivered
1. ✅ **D Button**: Double-size mode (100% ↔ 200%)
2. ✅ **A Button**: Always on top (window float)
3. ✅ **Ctrl+D**: Keyboard shortcut for double-size
4. ✅ **Ctrl+A**: Keyboard shortcut for always on top
5. ✅ **Windows Menu**: Both commands with dynamic labels
6. ✅ **State Persistence**: Both features remember settings
7. ✅ **Visual Feedback**: Correct sprites for normal vs selected

### Known Issues (Deferred)
1. ⏸️ Playlist menu buttons don't scale → Fix in `magnetic-window-docking` task

### Final Status
1. ✅ **COMPLETE**: All 8 phases done (including Oracle review)
2. ✅ **COMPLETE**: Clutter bar with 5 buttons (2 functional: A, D)
3. ✅ **COMPLETE**: D button toggles double-size mode
4. ✅ **COMPLETE**: A button toggles always on top
5. ✅ **COMPLETE**: Keyboard shortcuts (Ctrl+D, Ctrl+A)
6. ✅ **COMPLETE**: All 3 windows scale to 200%
7. ✅ **COMPLETE**: Manual testing passed
8. ✅ **COMPLETE**: Oracle code review passed
9. ✅ **COMPLETE**: Documentation written
10. ✅ **READY**: For pull request and merge!

---

## Phase 1: Discovery & Verification ✅ COMPLETE

### 🔍 Codebase Discovery
- [x] Locate UIStateModel class (or equivalent state management)
  - [x] Search for `@Observable` classes
  - [x] Found `AppSettings.swift` - perfect location
  - [x] Document location in state.md

- [x] Locate SkinEngine class (or equivalent)
  - [x] Found `SkinManager.swift`, `SpriteResolver.swift`, `SkinSprites.swift`
  - [x] Verify image loading capabilities - confirmed
  - [x] Check sprite extraction methods - confirmed
  - [x] Document location in state.md

- [x] Find main window view
  - [x] Found `WinampMainWindow.swift` (Lines 1-706)
  - [x] Identify window composition structure - builder pattern
  - [x] Document view hierarchy in state.md

- [x] Locate clutter bar implementation
  - [x] No existing clutter bar - will add to WinampMainWindow.swift
  - [x] Check existing button implementations - buildTransportButtons() pattern found
  - [x] Document current structure in state.md

- [x] Verify asset files
  - [x] Found TITLEBAR.BMP with clutter button sprites
  - [x] Verify sprite dimensions - 8×8 and 8×7
  - [x] Document sprite coordinates in state.md

### ✅ Prerequisites Verification
- [x] Confirm macOS 15+ deployment target in project settings
- [x] Verify Swift 6 language mode enabled
- [x] Check for existing `@Observable` usage patterns - confirmed throughout
- [x] Verify `.windowResizeAnchor` API availability - macOS 15+
- [x] Check existing keyboard shortcut infrastructure - AppCommands.swift exists
- [x] Confirm NSAnimationContext usage in project

---

## Phase 2: Foundation Setup ⚠️ PARTIALLY COMPLETE

### 📦 AppSettings Implementation ✅ DONE (Commit: bcc4582)
- [x] Extend AppSettings class (used instead of UIStateModel)
  - [x] @MainActor already present on class
  - [x] Add `import AppKit`
  - [x] Add `weak var mainWindow: NSWindow?` property
  - [x] Add `var baseWindowSize: NSSize` property (not originalFrame - Oracle improvement)
  - [x] Add `isDoubleSizeMode: Bool = false` property with @AppStorage
  - [x] Add placeholder states for O, A, I, V buttons:
    - [x] `showOptionsMenu: Bool = false`
    - [x] `isAlwaysOnTop: Bool = false`
    - [x] `showInfoDialog: Bool = false`
    - [x] `visualizerMode: Int = 0`

- [x] Add computed properties
  - [x] Implement `targetWindowFrame` computed property (dynamic - no snap-back!)
  - [x] Frame calculation uses live window position
  - [ ] ⏸️ Screen bounds validation method (deferred to Phase 5)

- [ ] ⏸️ Environment injection (AppSettings already injected as singleton)
  - [x] AppSettings uses singleton pattern
  - [ ] ⏸️ Will verify injection in main window integration

### 🎨 Sprite System ✅ DONE (Commit: bcc4582)
- [x] Sprite infrastructure exists (SkinManager, SpriteResolver)
  - [x] `loadImage` methods exist in SkinManager
  - [x] Sprite extraction works via SpriteResolver
  - [x] Caching handled by SkinManager

- [x] Add sprite definitions to SkinSprites.swift
  - [x] Map O button sprites (MAIN_CLUTTER_BAR_BUTTON_O/O_SELECTED)
  - [x] Map A button sprites (MAIN_CLUTTER_BAR_BUTTON_A/A_SELECTED)
  - [x] Map I button sprites (MAIN_CLUTTER_BAR_BUTTON_I/I_SELECTED)
  - [x] Map D button sprites (MAIN_CLUTTER_BAR_BUTTON_D/D_SELECTED)
  - [x] Map V button sprites (MAIN_CLUTTER_BAR_BUTTON_V/V_SELECTED)
  - [x] Coordinates from webamp reference (TITLEBAR.BMP)

- [ ] ⏸️ Extension methods not needed (SimpleSpriteImage uses sprite names directly)

### 🪟 Window Accessor Bridge ⏸️ PENDING
- [x] `WindowAccessor.swift` already exists in codebase
  - [x] Implements `NSViewRepresentable` protocol
  - [x] Pattern confirmed working in existing views

- [ ] ⏸️ Integration into main window (next phase)
  - [ ] Add accessor to WinampMainWindow
  - [ ] Capture window reference to AppSettings.mainWindow
  - [ ] Call setupWindowObserver()
  - [ ] Test window capture works

---

## Phase 3: Button Styles ✅ COMPLETE

### 🎭 Create SkinToggleStyle (Oracle Improvement Applied)
- [x] Create `SkinToggleStyle.swift` file ✅ (Commit: bcc4582)
  - [x] Define struct conforming to `ToggleStyle` (not ButtonStyle - Oracle fix)
  - [x] Add properties:
    - [x] `normalImage: NSImage`
    - [x] `activeImage: NSImage`
    - [x] ❌ NO `isOn: Bool` (reads from configuration.isOn instead)

- [x] Implement `makeBody(configuration:)`
  - [x] Uses `configuration.isOn` to determine image (automatic state)
  - [x] Apply `.interpolation(.none)` for pixel-perfect rendering
  - [x] Add accessibility support (.accessibilityValue)
  - [x] Added static factory method `.skin(normal:active:)`

- [ ] ⏸️ Test button style (deferred until clutter bar integrated)
  - [ ] Will test with actual clutter bar buttons
  - [ ] Verify on/off states render correctly
  - [ ] Verify accessibility works with VoiceOver

---

## Phase 4: Clutter Bar Implementation 🔄 IN PROGRESS

### 🎮 Add Clutter Bar to WinampMainWindow.swift
- [ ] Read WinampMainWindow.swift structure
  - [ ] Review existing builder methods (buildTransportButtons, etc.)
  - [ ] Identify where to add clutter bar in layout
  - [ ] Understand positioning system (Coords struct)

- [ ] Create buildClutterBarButtons() method
  - [ ] Follow pattern from buildTransportButtons() (Lines 453-529)
  - [ ] Set up HStack with spacing: 0
  - [ ] Position clutter bar at x: 10, y: 22 (per webamp CSS)
  - [ ] Set frame size to 8×43 pixels

- [ ] Add O button (Options) - Placeholder
  - [ ] Create Button with empty action
  - [ ] Use SimpleSpriteImage(sprite: "MAIN_CLUTTER_BAR_BUTTON_O")
  - [ ] Set `.disabled(true)`
  - [ ] Add `.accessibilityHidden(true)` (Oracle improvement)
  - [ ] Add `.help("Options (not yet implemented)")`

- [ ] Add A button (Always On Top) - Placeholder
  - [ ] Create Button with empty action
  - [ ] Use SimpleSpriteImage(sprite: "MAIN_CLUTTER_BAR_BUTTON_A")
  - [ ] Set `.disabled(true)`
  - [ ] Add `.accessibilityHidden(true)`
  - [ ] Add `.help("Always on top (not yet implemented)")`

- [ ] Add I button (Info) - Placeholder
  - [ ] Create Button with empty action
  - [ ] Use SimpleSpriteImage(sprite: "MAIN_CLUTTER_BAR_BUTTON_I")
  - [ ] Set `.disabled(true)`
  - [ ] Add `.accessibilityHidden(true)`
  - [ ] Add `.help("Info (not yet implemented)")`

- [ ] Add D button (Double Size) - ⭐ FUNCTIONAL
  - [ ] Create Toggle bound to `AppSettings.instance().isDoubleSizeMode`
  - [ ] Apply `.toggleStyle(.skin(normal: ..., active: ...))` with D sprites
  - [ ] Add `.keyboardShortcut("d", modifiers: .control)` or use AppCommands
  - [ ] Add `.help("Toggle window size (Ctrl+D)")`
  - [ ] Verify binding to @AppStorage property works

- [ ] Add V button (Visualizer) - Placeholder
  - [ ] Create Button with empty action
  - [ ] Use SimpleSpriteImage(sprite: "MAIN_CLUTTER_BAR_BUTTON_V")
  - [ ] Set `.disabled(true)`
  - [ ] Add `.accessibilityHidden(true)`
  - [ ] Add `.help("Visualizer (not yet implemented)")`

- [ ] Integrate clutter bar into window layout
  - [ ] Call buildClutterBarButtons() in body
  - [ ] Position at correct location (x: 10, y: 22)
  - [ ] Verify doesn't overlap other elements

- [ ] Verify button layout
  - [ ] Confirm order: O, A, I, D, V (vertical stack)
  - [ ] Check spacing matches original design (per webamp CSS)
  - [ ] Verify button sizes (8×8 or 8×7)
  - [ ] Test buttons appear in correct position

---

## Phase 5: Window Resize Logic

### 🪟 Main Window Integration
- [ ] Add WindowAccessor to MainWindowView
  - [ ] Place in ZStack (hidden, size 0)
  - [ ] Wire onWindowAvailable callback
  - [ ] Store window reference in uiState
  - [ ] Store originalFrame in uiState

- [ ] Add window resize anchor modifier
  - [ ] Apply `.windowResizeAnchor(.topLeading)` to root view
  - [ ] Verify modifier is available (macOS 15+)

- [ ] Implement resize task
  - [ ] Add `.task(id: uiState.isDoublesize)` modifier
  - [ ] Create `animateWindowResize()` method marked `@MainActor`
  - [ ] Guard for window existence
  - [ ] Guard for target frame validity

- [ ] Implement animation
  - [ ] Use `NSAnimationContext.runAnimationGroup`
  - [ ] Set duration to 0.2 seconds
  - [ ] Set timing function to `.easeInEaseOut`
  - [ ] Call `window.animator().setFrame(_:display:)`

### 🎯 Frame Validation
- [ ] Add screen bounds validation
  - [ ] Implement `validateFrame(_:)` in UIStateModel
  - [ ] Check top boundary
  - [ ] Check left boundary
  - [ ] Check bottom boundary
  - [ ] Check right boundary
  - [ ] Adjust frame if needed

- [ ] Integrate validation
  - [ ] Call `validateFrame` before applying animation
  - [ ] Test with window at screen edges
  - [ ] Verify no off-screen positioning

---

## Phase 6: Testing

### ✅ Manual Testing
- [ ] Basic functionality
  - [ ] Launch app, verify window at 100%
  - [ ] Click D button, verify window doubles
  - [ ] Click D again, verify window returns to 100%
  - [ ] Verify button visual state matches window state

- [ ] Keyboard shortcut
  - [ ] Press Ctrl+D, verify toggle works
  - [ ] Press Ctrl+D multiple times
  - [ ] Verify same behavior as clicking button

- [ ] Animation quality
  - [ ] Verify smooth transition
  - [ ] Check for visual artifacts
  - [ ] Test on older Mac if available
  - [ ] Verify 200ms feels natural

- [ ] Edge cases
  - [ ] Position window at top edge, toggle to 200%
  - [ ] Position window at left edge, toggle to 200%
  - [ ] Position window at bottom edge, toggle to 200%
  - [ ] Position window at right edge, toggle to 200%
  - [ ] Verify window stays on screen

- [ ] Multi-display
  - [ ] Drag to second monitor, toggle
  - [ ] Verify works on any display
  - [ ] Check with different resolutions

- [ ] State persistence
  - [ ] Toggle to 200%
  - [ ] Minimize window
  - [ ] Restore window
  - [ ] Verify still at 200%

- [ ] App lifecycle
  - [ ] Set to 200%
  - [ ] Quit app
  - [ ] Relaunch app
  - [ ] Verify state (if persistence enabled)

- [ ] Rapid toggling
  - [ ] Click D button 10 times quickly
  - [ ] Verify animation completes
  - [ ] Verify ends in correct state
  - [ ] Check for memory leaks

### 🐛 Bug Fixing
- [ ] Document any discovered issues
  - [ ] Create list in separate section below
  - [ ] Prioritize by severity
  - [ ] Fix critical bugs before proceeding

- [ ] Performance validation
  - [ ] Profile with Instruments if issues found
  - [ ] Check memory usage during toggle
  - [ ] Verify no retain cycles

---

## Phase 7: Documentation

### 📝 Code Documentation
- [ ] Add doc comments to UIStateModel
  - [ ] Document isDoublesize property
  - [ ] Document frame calculation methods
  - [ ] Document validation logic

- [ ] Add doc comments to SkinEngine extension
  - [ ] Document ClutterButton enum
  - [ ] Document sprite extraction methods

- [ ] Add doc comments to WindowAccessor
  - [ ] Explain purpose and usage
  - [ ] Document callback behavior

- [ ] Add doc comments to button styles
  - [ ] Explain when to use
  - [ ] Document parameters

### 📚 User Documentation
- [ ] Create `docs/features/double-size-mode.md`
  - [ ] Overview section
  - [ ] Usage instructions (button + keyboard)
  - [ ] Behavior description
  - [ ] Troubleshooting tips

- [ ] Update main README (if applicable)
  - [ ] Add to features list
  - [ ] Link to detailed docs

### 🔧 Developer Documentation
- [ ] Update state.md with final component locations
- [ ] Document any deviations from plan
- [ ] Add notes for future O, A, I, V implementations
- [ ] Document sprite coordinate mapping

---

## Phase 8: Code Review & Cleanup

### 🧹 Code Quality
- [ ] Remove debug print statements
- [ ] Remove commented-out code
- [ ] Verify no force unwraps (!)
- [ ] Check for memory leaks
- [ ] Verify Swift 6 strict concurrency

### 📋 Checklist Review
- [ ] All TODOs in code removed or documented
- [ ] No placeholder implementations in production paths
- [ ] All guard statements have meaningful returns
- [ ] Error handling is comprehensive

### 🎨 Code Style
- [ ] Follow Swift API Design Guidelines
- [ ] Consistent naming conventions
- [ ] Proper indentation and formatting
- [ ] SwiftFormat applied (if used in project)

---

## Known Issues

### 🐛 Discovered Bugs
*Document issues found during testing here*

- None yet (update during testing phase)

---

## Future Enhancements

### 📅 Deferred to Future Tasks
- [ ] O button: Options menu implementation
- [ ] A button: Always on top window level
- [ ] I button: Info dialog
- [ ] V button: Visualizer mode toggle
- [ ] State persistence with @AppStorage
- [ ] Multi-window support (if needed)
- [ ] Custom animation curves
- [ ] Settings for animation speed

---

## Completion Criteria

### ✅ Definition of Done
- [x] All Phase 1-7 tasks completed
- [ ] All manual tests pass
- [ ] No critical bugs
- [ ] Code documented
- [ ] User documentation written
- [ ] Code review completed
- [ ] Changes committed to git
- [ ] Feature demo to stakeholder (if applicable)

### 🎯 Success Metrics
- Window toggles smoothly between 100% and 200%
- Animation feels natural (no jank)
- Button state always matches window state
- Keyboard shortcut works reliably
- No crashes or visual artifacts
- Works on all supported displays
- Code follows project standards

---

## Notes

### 💡 Implementation Tips
- Test frequently during development
- Keep commits small and focused
- Use descriptive commit messages
- Ask for help if blocked
- Reference webamp implementation for UX details
- Verify thread safety for window operations

### 🔗 Quick References
- Research: `tasks/double-size-button/research.md`
- Plan: `tasks/double-size-button/plan.md`
- State: `tasks/double-size-button/state.md`
- Original spec: `tasks/double-sized-plan.md`

---

## Progress Tracking

### Day 1: Discovery ⏸️
- Status: Not started
- Blockers: None

### Day 2: Foundation ⏸️
- Status: Not started
- Blockers: None

### Day 3-4: Implementation ⏸️
- Status: Not started
- Blockers: None

### Day 5: Testing ⏸️
- Status: Not started
- Blockers: None

### Day 6: Documentation ⏸️
- Status: Not started
- Blockers: None

---

*Last updated: 2025-10-30*
*Next review: Start of implementation*
