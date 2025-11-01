# Current State: Double-Sized Button Implementation

## Date
2025-10-30

## Task Status
✅ **COMPLETE** - Oracle Reviewed - Production Ready!

### Completed Phases
- ✅ **Phase 1: AppSettings Enhancement** (Commit: bcc4582)
- ✅ **Phase 2: Window Reference Capture** (Commit: dc48d29, fixed: 6e7cf10)
- ✅ **Phase 3: Button Styles** (Commit: bcc4582, simplified: 6e7cf10)
- ✅ **Phase 4: Clutter Bar Implementation** (Commit: dc48d29)
- ✅ **Phase 5: Window Resize Animation** (Commit: a4d2d2d, 86b3d5b)
- ✅ **Phase 6: Manual Testing** (2025-10-30 - PASSED)
- ✅ **Phase 7: Documentation** (Complete)
- ✅ **Phase 8: Oracle Code Review** (Complete - All issues resolved)

### Build & Test Status
- ✅ **Clean Build** - No errors
- ✅ **Thread Sanitizer** - Enabled and passing
- ✅ **Swift 6 Strict Concurrency** - All issues resolved
- ✅ **Manual Testing** - All core functionality verified
- ✅ **Oracle Code Review** - PASSED (Low risk after cleanup)

### Testing Results (Phase 6)
- ✅ App starts at 100% size (normal)
- ✅ Click D → Window smoothly resizes to 200%
- ✅ Click D again → Window resizes back to 100%
- ✅ All 3 windows scale together (main, EQ, playlist)
- ✅ State persists across skin changes
- ✅ D button visual state matches mode
- ✅ Ctrl+D keyboard shortcut works
- ✅ A button toggles window always on top
- ✅ Ctrl+A keyboard shortcut works
- ✅ Menu labels update in real-time
- ⚠️ **Known Issue:** Playlist menu buttons don't scale (deferred to magnetic-window-docking task)

### Bonus Features Implemented
- ✅ **A Button (Always On Top)** - Window floats above others (Commits: a5c0107, 38a3c57, 0f8c3b9)
- ✅ **Keyboard Shortcuts** - Ctrl+D and Ctrl+A (Commits: a5c0107, 6bb3b67)
- ✅ **Reactive Menus** - Windows menu labels update live (Commit: 0f8c3b9)

---

## Implementation Details

### Phase 1: AppSettings Enhancement ✅

**File Modified:** `MacAmpApp/Models/AppSettings.swift`
**Lines Added:** 85+

**Completed Items:**
- ✅ Added `import AppKit`
- ✅ Added `@MainActor` annotation (already existed on class)
- ✅ Added `weak var mainWindow: NSWindow?`
- ✅ Added `var baseWindowSize: NSSize = NSSize(width: 275, height: 116)`
- ✅ Added `@ObservationIgnored private var windowObserver: NSObjectProtocol?`
- ✅ Added `@AppStorage("isDoubleSizeMode") var isDoubleSizeMode: Bool = false`
- ✅ Added placeholder states: `showOptionsMenu`, `isAlwaysOnTop`, `showInfoDialog`, `visualizerMode`
- ✅ Added `targetWindowFrame` computed property (dynamic calculation)
- ✅ Added `setupWindowObserver()` method
- ✅ Added `deinit` to clean up observer

**Oracle Improvements Applied:**
- @MainActor for Swift 6 concurrency safety
- weak var to prevent retain cycles
- Dynamic frame calculation (no snap-back)
- @AppStorage for persistence

### Phase 2: Window Reference Capture ✅

**File Modified:** `MacAmpApp/Views/WinampMainWindow.swift` (Commit: dc48d29)
**Lines Added:** 13

**Completed Items:**
- ✅ Added `WindowAccessor` to body (Lines 108-116)
- ✅ Captures window reference once on appear
- ✅ Stores in `AppSettings.mainWindow` (weak reference)
- ✅ Calls `setupWindowObserver()` to track movements
- ✅ Hidden with `.frame(width: 0, height: 0)` + `.hidden()`

### Phase 3: Button Styles ✅

**File Created:** `MacAmpApp/Views/Components/SkinToggleStyle.swift` (Commit: bcc4582)
**Lines Added:** 31

**Completed Items:**
- ✅ Implemented `ToggleStyle` protocol (Oracle improvement)
- ✅ Uses `configuration.isOn` for automatic state
- ✅ Added accessibility support (.accessibilityValue)
- ✅ Added static factory method `.skin(normal:active:)`
- ✅ Pixel-perfect rendering (.interpolation(.none))

### Phase 4: Clutter Bar Implementation ✅

**File Modified:** `MacAmpApp/Views/WinampMainWindow.swift` (Commit: dc48d29)
**Lines Added:** 90+

**Completed Items:**
- ✅ Added clutter bar coordinates to Coords struct (Lines 76-81)
- ✅ Created `buildClutterBarButtons()` method (Lines 520-607)
- ✅ Added `spriteImage()` helper method (Lines 609-626)
- ✅ Integrated clutter bar into buildFullWindow() (Line 166)
- ✅ O button: 8×8 @ (10, 25) - Scaffold with .accessibilityHidden
- ✅ A button: 8×7 @ (10, 33) - Scaffold with .accessibilityHidden
- ✅ I button: 8×7 @ (10, 40) - Scaffold with .accessibilityHidden
- ✅ D button: 8×8 @ (10, 47) - FUNCTIONAL with Toggle + SkinToggleStyle
- ✅ V button: 8×7 @ (10, 55) - Scaffold with .accessibilityHidden

**File Modified:** `MacAmpApp/Models/SkinSprites.swift` (Commit: bcc4582)
**Lines Added:** 12 sprite definitions

**Completed Items:**
- ✅ Added `MAIN_CLUTTER_BAR_BUTTON_O` (x: 304, y: 47, 8×8)
- ✅ Added `MAIN_CLUTTER_BAR_BUTTON_O_SELECTED` (x: 304, y: 47, 8×8)
- ✅ Added `MAIN_CLUTTER_BAR_BUTTON_A` (x: 312, y: 55, 8×7)
- ✅ Added `MAIN_CLUTTER_BAR_BUTTON_A_SELECTED` (x: 312, y: 55, 8×7)
- ✅ Added `MAIN_CLUTTER_BAR_BUTTON_I` (x: 320, y: 62, 8×7)
- ✅ Added `MAIN_CLUTTER_BAR_BUTTON_I_SELECTED` (x: 320, y: 62, 8×7)
- ✅ Added `MAIN_CLUTTER_BAR_BUTTON_D` (x: 328, y: 69, 8×8)
- ✅ Added `MAIN_CLUTTER_BAR_BUTTON_D_SELECTED` (x: 328, y: 69, 8×8)
- ✅ Added `MAIN_CLUTTER_BAR_BUTTON_V` (x: 336, y: 77, 8×7)
- ✅ Added `MAIN_CLUTTER_BAR_BUTTON_V_SELECTED` (x: 336, y: 77, 8×7)

### Phase 5: Window Resize Logic ✅

**File Modified:** `MacAmpApp/Views/UnifiedDockView.swift` (Commit: a4d2d2d)
**Lines Added:** 20

**Completed Items:**
- ✅ Added `baseNaturalSize(for:)` - returns 1x sizes
- ✅ Modified `naturalSize(for:)` - applies 2x scaling when mode active
- ✅ Updated `calculateTotalWidth()` - uses scaled sizes
- ✅ Updated `calculateTotalHeight()` - uses scaled sizes
- ✅ Added `.scaleEffect(scale, anchor: .topLeading)` to each window
- ✅ Added `.animation(.easeInOut(duration: 0.2))` for smooth transitions
- ✅ Unified window approach (all 3 windows scale together)

**File Modified:** `MacAmpApp/Models/AppSettings.swift` (Reactivity fix)
**Critical Fix:** Removed `@ObservationIgnored` from `isDoubleSizeMode`

**Original Problem:**
```swift
@ObservationIgnored  // ← Blocked @Observable!
@AppStorage("isDoubleSizeMode") private var _isDoubleSizeMode: Bool
```

**Solution:**
```swift
var isDoubleSizeMode: Bool = false {
    didSet {
        UserDefaults.standard.set(isDoubleSizeMode, forKey: "isDoubleSizeMode")
    }
}
```

This allows @Observable to track changes and trigger UnifiedDockView re-renders.

### Phase 6: Manual Testing ✅

**Date:** 2025-10-30
**Tester:** User manual testing

**Test Results:**
- ✅ App starts at 100% (normal size)
- ✅ Click D → All windows resize to 200%
- ✅ Click D again → All windows resize back to 100%
- ✅ Smooth animation (0.2s easeInEaseOut)
- ✅ All 3 windows scale together
- ✅ Works with all skins
- ✅ State persists across skin changes
- ✅ D button visual state matches mode
- ⚠️ **Known Issue:** Playlist menu buttons don't scale (documented, deferred)

**Deferred Issues:**
- Playlist menu button scaling → `magnetic-window-docking` task
- Keyboard shortcut → Future enhancement
- Screen bounds validation → Not needed with current architecture

### Phase 7: Documentation ✅

**Files Created/Updated:**

1. ✅ `tasks/double-size-button/FEATURE_DOCUMENTATION.md`
   - User guide
   - Technical details
   - Known limitations
   - Architecture notes
   - Testing checklist

2. ✅ `README.md` (root)
   - Added to Key Features section
   - Added Usage → Double-Size Mode section
   - Listed clutter bar buttons

3. ✅ `tasks/magnetic-window-docking/research.md`
   - Added playlist menu scaling issue
   - Migration guide for when windows separate
   - Testing notes for future implementation

4. ✅ `tasks/double-size-button/state.md` (this file)
   - Complete implementation status
   - All phases documented

5. ✅ `tasks/double-size-button/todo.md`
   - All phases marked complete
   - Final status updated

---

## Prerequisites Checklist

### ✅ Verified
- [x] macOS 15+ deployment target (Sequoia/Tahoe)
- [x] Swift 6 language mode enabled
- [x] Xcode 16.0+ available
- [x] Project using SwiftUI for UI layer
- [x] Reference implementation in webamp_clone/ repository

### ✅ DISCOVERED (2025-10-30)

#### State Management
- [x] **AppSettings.swift** (Lines 1-200+) - State management with @Observable
  - Perfect location for `isDoubleSizeMode: Bool`
  - Already using @Observable pattern
  - Environment injection ready

#### Sprite System
- [x] **SkinManager.swift** (Lines 102-621) - Sprite loading infrastructure
  - `applySkinPayload()` method (Lines 454-610)
  - Image loading capabilities confirmed
- [x] **SpriteResolver.swift** (Lines 97-402) - Semantic sprite mapping
  - Perfect for adding clutter button sprites
- [x] **SkinSprites.swift** (Lines 46-275+) - Sprite definitions
  - Can extend for O, A, I, D, V buttons
- [x] **SimpleSpriteImage.swift** (Lines 27-82) - View component
  - Ready for use in buttons

#### Main Window
- [x] **WinampMainWindow.swift** (Lines 1-706) - Main window view
  - Organized builder pattern for buttons
  - `Coords` struct (Lines 34-74) for positions
  - `buildTransportButtons()`, `buildShuffleRepeatButtons()`, etc.
  - Easy to add `buildClutterBarButtons()` method

#### Window Infrastructure
- [x] **WindowAccessor.swift** - NSViewRepresentable for window capture
  - Pattern exists and working
- [x] **UnifiedDockView.swift** - Window configuration point
  - Can add window resize logic here

#### Assets
- [x] **CBUTTONS.BMP** located at:
  - `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/assets/skins/base-2.91/CBUTTONS.BMP`
- [x] All other sprite sheets (MAIN.BMP, TITLEBAR.BMP, etc.) found

#### Infrastructure
- [x] **AppCommands.swift** - Keyboard shortcut infrastructure
  - Available slot: ⌘⌃1 or custom Ctrl+D
- [x] **DockingController.swift** - State persistence patterns
  - Can use for persisting double-size mode
- [x] **WinampSizes struct** (Lines 98-105) - Size constants
  - Easy to extend: `mainDouble = NSSize(width: 550, height: 232)`

### 🔍 Additional Findings
- [x] Modern Swift 6 @Observable pattern used throughout
- [x] Environment injection established pattern
- [x] Absolute positioning with well-documented coordinates
- [x] No existing double-size implementation (no duplication risk)
- [x] Clean codebase, no deprecated code found

---

# Comprehensive Discovery Report

**Date:** 2025-10-30
**Status:** ✅ Complete - All Required Components Located

## File Paths & Line Numbers

### 1. State Management Files

| File | Lines | Purpose | Status |
|------|-------|---------|--------|
| AppSettings.swift | 1-200+ | User preferences, perfect for `isDoubleSizeMode` | ✅ READY |
| SkinManager.swift | 102-621 | Sprite loading, `applySkinPayload()` at 454-610 | ✅ READY |
| DockingController.swift | 31-118 | Window visibility, state persistence pattern | ✅ READY |
| AudioPlayer.swift | 94-96 | Playback state (not needed for this feature) | N/A |

### 2. Sprite System Files

| File | Lines | Purpose | Status |
|------|-------|---------|--------|
| SpriteResolver.swift | 97-402 | Semantic sprite mapping | ✅ READY |
| SkinSprites.swift | 46-275+ | All sprite definitions | ✅ EXTEND |
| SimpleSpriteImage.swift | 27-82 | View component for rendering | ✅ READY |

### 3. Main Window Files

| File | Lines | Purpose | Status |
|------|-------|---------|--------|
| WinampMainWindow.swift | 1-706 | Main window view | ✅ MODIFY |
| - Coords struct | 34-74 | All button positions | ✅ EXTEND |
| - buildTransportButtons() | 453-529 | Transport button builder | PATTERN |
| - buildShuffleRepeatButtons() | 531-595 | Shuffle/repeat builder | PATTERN |
| - buildWindowToggleButtons() | 597-663 | EQ/playlist builder | PATTERN |

### 4. Infrastructure Files

| File | Purpose | Status |
|------|---------|--------|
| WindowAccessor.swift | NSViewRepresentable for window capture | ✅ EXISTS |
| UnifiedDockView.swift | Window configuration, naturalSize() at 238-248 | ✅ MODIFY |
| AppCommands.swift | Keyboard shortcuts | ✅ EXTEND |
| WinampSizes struct (in SimpleSpriteImage.swift) | Lines 98-105 | ✅ EXTEND |

### 5. Asset Files

**Location:** `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/assets/skins/base-2.91/`

- CBUTTONS.BMP - Clutter buttons (need coordinate research)
- MAIN.BMP - Main window background
- SHUFREP.BMP - Shuffle/repeat/EQ/playlist buttons
- TITLEBAR.BMP - Titlebar controls
- POSBAR.BMP - Position bar sprites
- All other sprite sheets present

## Coordinate Mappings for Double-Size

### Transport Buttons (y: 88 → 176)
| Button | 1x (Current) | 2x (Double) |
|--------|--------------|-------------|
| Previous | 23×18 @ (16,88) | 46×36 @ (32,176) |
| Play | 23×18 @ (39,88) | 46×36 @ (78,176) |
| Pause | 23×18 @ (62,88) | 46×36 @ (124,176) |
| Stop | 23×18 @ (85,88) | 46×36 @ (170,176) |
| Next | 23×18 @ (108,88) | 46×36 @ (216,176) |
| Eject | 22×16 @ (136,89) | 44×32 @ (272,178) |

### Window Toggle Buttons (y: 58 → 116)
| Button | 1x (Current) | 2x (Double) |
|--------|--------------|-------------|
| EQ | 23×12 @ (219,58) | 46×24 @ (438,116) |
| Playlist | 23×12 @ (242,58) | 46×24 @ (484,116) |

### Titlebar Buttons (y: 3 → 6)
| Button | 1x (Current) | 2x (Double) |
|--------|--------------|-------------|
| Minimize | 9×9 @ (244,3) | 18×18 @ (488,6) |
| Shade | 9×9 @ (254,3) | 18×18 @ (508,6) |
| Close | 9×9 @ (264,3) | 18×18 @ (528,6) |

### Window Sizes
| Mode | 1x (Current) | 2x (Double) |
|------|--------------|-------------|
| Full Window | 275×116 | 550×232 |
| Shade Mode | 275×14 | 550×28 |

## Implementation Approach

### Option A: Conditional Coordinates (RECOMMENDED)
```swift
// In WinampMainWindow
private var coords: Coords {
    settings.isDoubleSizeMode ? Coords.double : Coords.standard
}

struct Coords {
    static let standard = StandardCoords()
    static let double = DoubleCoords()

    struct StandardCoords {
        let prevButton = CGPoint(x: 16, y: 88)
        // ... existing coords
    }

    struct DoubleCoords {
        let prevButton = CGPoint(x: 32, y: 176)  // All x2
        // ... doubled coords
    }
}
```

### Option B: Calculated Coordinates
```swift
let scale = settings.isDoubleSizeMode ? 2.0 : 1.0
let position = CGPoint(x: 16 * scale, y: 88 * scale)
```

## 7 Files to Modify

1. **AppSettings.swift** - Add `@MainActor`, `isDoubleSizeMode: Bool`, window reference, frame calculation
2. **WinampMainWindow.swift** - Extend Coords struct, add `buildClutterBarButtons()`
3. **SimpleSpriteImage.swift** - Extend WinampSizes with double constants
4. **SkinSprites.swift** - Add clutter button sprite definitions (O, A, I, D, V)
5. **AppCommands.swift** - Add keyboard shortcut (⌘⌃1)
6. **UnifiedDockView.swift** - Update `naturalSize()` to consider double-size mode
7. **SkinToggleStyle.swift** - NEW FILE - Proper ToggleStyle implementation

## No Duplication Risk

**Verified:** No existing double-size implementation found in codebase
- No "double" or "doublesize" references
- No 2x scaling code
- No clutter button implementation (O, A, I, D, V)
- Clean slate for implementation

---

## 🎯 Implementation Summary

### Total Changes (Final)
- **6 files modified** (AppSettings, SkinSprites, WinampMainWindow, UnifiedDockView, AppCommands, MacAmpApp, README)
- **1 file deleted** (SkinToggleStyle.swift - unused)
- **+197 lines added, ~100 removed (net +97)**
- **12 commits total**
- **Clean build with Thread Sanitizer enabled**
- **All Oracle feedback applied**
- **Oracle code review PASSED (2 rounds)**

### All Commits
1. `bcc4582` - Foundation (Phase 1, 3, 4 sprites)
2. `dc48d29` - Clutter bar + window resize (Phase 2, 4, 5)
3. `6e7cf10` - Swift 6 concurrency fixes
4. `a4d2d2d` - Unified window scaling (Phase 5 architecture fix)
5. `538098f` - Magnetic docking migration docs
6. `86b3d5b` - Reactivity fix + Phase 7 documentation
7. `d9113e7` - Oracle cleanup round 1 (dead code removal, sprite coordinate fixes)
8. `af44004` - Restore scaffolded states for O, I, V buttons
9. `a5c0107` - A button (Always On Top) + keyboard shortcuts (Ctrl+D, Ctrl+A)
10. `38a3c57` - Oracle fix: Use specific dock window reference
11. `0f8c3b9` - Oracle fix: Make AppCommands reactive with @Bindable
12. `6bb3b67` - Documentation: Keyboard shortcuts in README

### Implementation Approach (Final)
- **State:** AppSettings with @AppStorage persistence
- **Buttons:** Simple Button (not Toggle) for cleaner implementation
- **Sprites:** SimpleSpriteImage with conditional sprite names
- **Window Scaling:** UnifiedDockView with .scaleEffect() + scaled frame calculations
- **Animation:** SwiftUI .animation(.easeInOut(duration: 0.2))
- **Concurrency:** @MainActor, Swift 6 strict concurrency compliant
- **Accessibility:** Scaffolded buttons hidden from VoiceOver

### Architectural Decision: Unified Window Scaling

**Current Architecture:** Single macOS window containing all 3 Winamp windows (main, EQ, playlist)

**Decision:** Implement double-size with unified window approach (not separate windows)

**Rationale:**
- Magnetic window docking (separate windows) is deferred to future task (P3)
- Current unified window architecture is stable and working
- Can implement double-size mode without major refactor
- Classic Winamp behavior: ALL windows double together ✅

**Implementation:**
- UnifiedDockView calculates scaled sizes via `naturalSize()`
- Each window gets `.scaleEffect(2.0, anchor: .topLeading)` when mode active
- Unified window frame automatically resizes via `calculateTotalWidth/Height()`
- SwiftUI animation provides smooth 0.2s transition

**Future:** When magnetic docking is implemented, scaling logic moves to individual NSWindow instances

### What Works
- ✅ D button toggles `isDoubleSizeMode` boolean with visual feedback
- ✅ A button toggles `isAlwaysOnTop` with window.level = .floating/.normal
- ✅ Ctrl+D keyboard shortcut toggles double-size mode
- ✅ Ctrl+A keyboard shortcut toggles always on top
- ✅ Windows menu shows both commands with dynamic labels
- ✅ State persists across app restarts (both features)
- ✅ All 3 windows (main, EQ, playlist) scale to 200% together
- ✅ UnifiedDockView calculates 2x frame sizes automatically
- ✅ .scaleEffect(2.0) scales visual content pixel-perfectly
- ✅ Smooth 0.2s animation on toggle
- ✅ O, I, V buttons scaffolded for future implementation
- ✅ Works with shade mode (14px → 28px when doubled)
- ✅ Specific dock window targeting (not NSApp.keyWindow)
- ✅ @Bindable reactivity for menu labels

### Testing Required
See Phase 6 in todo.md for complete test checklist.

---

## 🔍 Oracle Code Review (Phase 8)

**Date:** 2025-10-30
**Reviewer:** Oracle (Codex)
**Scope:** All 7 phases, 6 commits, 5 files

### Issues Found & Fixed

#### 1. HIGH: Sprite Coordinate Mapping ✅
**Issue:** Normal and SELECTED sprites had identical coordinates - no visual state change
**Fix:** Normal sprites now extract from CLUTTER_BAR_BACKGROUND
- D normal: (304, 25) vs D selected: (328, 69)
- All buttons now have distinct normal/selected sprites
**Commit:** d9113e7

#### 2. MEDIUM: Dead Code in AppSettings ✅
**Issue:** mainWindow, baseWindowSize, targetWindowFrame unused
**Fix:** Removed all unused window management properties
**Impact:** -30 lines, cleaner architecture
**Commit:** d9113e7

#### 3. MEDIUM: Unused Scaffolded States ✅
**Issue:** showOptionsMenu, isAlwaysOnTop, showInfoDialog, visualizerMode never used
**Fix:** Removed all placeholder states
**Impact:** -5 lines, no silent drift
**Commit:** d9113e7

#### 4. MEDIUM: Orphaned Component File ✅
**Issue:** SkinToggleStyle.swift created but never referenced
**Fix:** Deleted entire file
**Impact:** -31 lines
**Commit:** d9113e7

#### 5. LOW: Debug Print Statements ✅
**Issue:** 8 print() statements in production code
**Fix:** Removed all debug logging
**Impact:** Clean stdout
**Commit:** d9113e7

#### 6. LOW: Unnecessary Import ✅
**Issue:** import AppKit after window properties removed
**Fix:** Removed unused import
**Impact:** Minimal dependencies
**Commit:** d9113e7

### Oracle Final Assessment

**Before Cleanup:**
- Risk Level: **Medium**
- Code Smell: **Medium**
- Dead Code: ~100 lines
- Issues: 6

**After Cleanup:**
- Risk Level: **LOW** ✅
- Code Smell: **LOW** ✅
- Dead Code: 0 lines ✅
- Issues: 0 ✅

**Recommendation:** "Cleaning these items up before merge will keep the feature aligned with existing architecture and polish expectations."

**Status:** ✅ **All recommendations implemented**

---

## Current Architecture Understanding

### Known Components
Based on discovered infrastructure:

1. **UIStateModel Pattern**
   - Uses `@Observable` macro (Swift 6)
   - Injected via `.environment()`
   - Single source of truth for UI state

2. **SkinEngine Service**
   - Loads bitmap assets
   - Provides sprite extraction
   - Supports dynamic skin switching

3. **Window Management**
   - AppKit bridge via `NSViewRepresentable`
   - `NSWindow` reference captured at runtime
   - `.windowResizeAnchor(.topLeading)` for coordinated resizing

4. **Reactive Patterns**
   - `.task(id:)` modifier for state-driven async work
   - `NSAnimationContext` for window animations
   - Binding to @Observable properties

### Unknown Components
Need to discover in codebase:

1. Where is UIStateModel defined?
2. Where is SkinEngine implemented?
3. How are other buttons currently implemented?
4. What's the main window view file name?
5. How are keyboard shortcuts currently handled?
6. What's the existing animation infrastructure?

## Repository Structure

```
MacAmp/
├── MacAmpApp.swift                 # App entry point - verify environment injection
├── Models/
│   ├── UIStateModel.swift?         # Search for this
│   └── ...
├── Services/
│   ├── SkinEngine.swift?           # Search for this
│   └── ...
├── Views/
│   ├── MainWindowView.swift?       # Search for main window
│   ├── ClutterBarView.swift?       # Search for clutter bar
│   ├── Styles/
│   │   └── ButtonStyles.swift?     # Check for existing button styles
│   └── WindowAccessor.swift?       # Check if bridge exists
├── Resources/
│   └── Skins/
│       └── Base.wsz/
│           └── cbuttons.bmp        # Verify sprite sheet exists
└── tasks/
    ├── double-sized-plan.md        # Reference implementation
    └── double-size-button/         # This task
        ├── research.md
        ├── plan.md
        ├── state.md (this file)
        └── todo.md
```

## Integration Points

### 1. App Root Injection
**File**: `MacAmpApp.swift`
**Status**: 🔍 Need to verify

Expected pattern:
```swift
@main
struct MacAmpApp: App {
    @State private var uiStateModel = UIStateModel()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(uiStateModel)
        }
    }
}
```

**Action**: Search for `@main` and verify environment injection

### 2. UIStateModel
**Location**: Unknown
**Status**: 🔍 Need to find

Expected to contain:
- Window reference storage
- UI state properties
- Observable macro usage

**Action**: Search for `@Observable`, `UIStateModel`, or similar state management

### 3. SkinEngine
**Location**: Unknown
**Status**: 🔍 Need to find

Expected capabilities:
- Image loading from skin files
- Sprite extraction
- Asset caching

**Action**: Search for `SkinEngine`, skin loading, or bitmap handling

### 4. Main Window View
**Location**: Unknown
**Status**: 🔍 Need to find

Expected structure:
- Root container for player UI
- Title bar component
- Display area
- Clutter bar area
- Window accessor integration

**Action**: Search for main window, player view, or window composition

### 5. Clutter Bar
**Location**: Unknown
**Status**: 🔍 Need to find

Expected to contain:
- Horizontal button strip
- O, A, I, D, V button placeholders
- Skin-driven button styling

**Action**: Search for clutter bar, button bar, or control strip

## Asset Requirements

### Sprite Sheet: cbuttons.bmp
**Status**: 🔍 Need to verify location and structure

Expected layout (9x9 pixels per button):
```
┌─────┬─────┬─────┬─────┬─────┐
│  O  │  A  │  I  │  D  │  V  │  (Off state)
├─────┼─────┼─────┼─────┼─────┤
│  O  │  A  │  I  │  D  │  V  │  (On state)
└─────┴─────┴─────┴─────┴─────┘
```

Sprite coordinates to verify:
- O button: (0,0,9,9) off, (0,9,9,9) on
- A button: (9,0,9,9) off, (9,9,9,9) on
- I button: (18,0,9,9) off, (18,9,9,9) on
- D button: (27,0,9,9) off, (27,9,9,9) on
- V button: (36,0,9,9) off, (36,9,9,9) on

**Action**: Locate skin files and verify sprite positions

## Dependencies Status

### System Requirements
- ✅ macOS 15+ (Sequoia/Tahoe confirmed in CLAUDE.md)
- ✅ Swift 6 (modern architecture confirmed)
- ✅ Xcode 16.0+ (implied by Swift 6 usage)

### Framework Requirements
- ✅ SwiftUI (primary UI framework)
- ✅ AppKit (for NSWindow manipulation)
- ✅ Observation framework (Swift 6 @Observable)

### Project Configuration
- ⏳ Thread Sanitizer enabled (`-enableThreadSanitizer YES`)
- ⏳ Window resize anchor API availability
- ⏳ Keyboard shortcut infrastructure

## Known Constraints

1. **Platform Specific**
   - macOS 15+ required for `.windowResizeAnchor()`
   - Cannot support older macOS versions for this feature

2. **Architecture Requirements**
   - Must use @Observable (not @StateObject/@ObservedObject)
   - Must use .task(id:) for reactive work
   - Must use NSAnimationContext for window animations

3. **Visual Requirements**
   - Maintain pixel-perfect rendering
   - Support dynamic skin switching
   - Match classic Winamp aesthetic

## Risks & Blockers

### Critical Path Items
1. **UIStateModel Discovery** (HIGH)
   - If missing: Must create from scratch
   - If exists: Must verify @Observable usage
   - Impact: Affects entire architecture

2. **SkinEngine Availability** (HIGH)
   - If missing: Must implement basic version
   - If incomplete: Must add sprite extraction
   - Impact: Blocks button rendering

3. **Window Access Pattern** (MEDIUM)
   - If no bridge exists: Must create WindowAccessor
   - If different pattern: Must adapt plan
   - Impact: Affects window manipulation

### Technical Challenges
1. **Frame Calculation Edge Cases**
   - Screen boundaries
   - Multiple displays
   - Menu bar positioning
   - Mission Control/Spaces

2. **Animation Performance**
   - Must be smooth on older Macs
   - No jank during transition
   - Proper timing coordination

3. **State Synchronization**
   - Button visual vs actual window state
   - Race conditions during rapid toggling
   - Persistence across restarts

## Next Steps

### Phase 1: Discovery (Day 1)
1. Search for UIStateModel
2. Search for SkinEngine
3. Locate main window view
4. Find clutter bar implementation
5. Verify asset files
6. Document findings in this file

### Phase 2: Foundation (Day 2)
1. Create/extend UIStateModel
2. Create/extend SkinEngine
3. Create WindowAccessor if needed
4. Set up environment injection

### Phase 3: Implementation (Days 3-4)
1. Implement D button
2. Add window resize logic
3. Wire keyboard shortcut
4. Scaffold O, A, I, V buttons

### Phase 4: Polish (Day 5)
1. Edge case handling
2. Testing
3. Bug fixes

### Phase 5: Documentation (Day 6)
1. Code documentation
2. User guide
3. Handoff notes

## References

- Planning document: `tasks/double-size-button/plan.md`
- Research notes: `tasks/double-size-button/research.md`
- Original spec: `tasks/double-sized-plan.md`
- Webamp reference: `webamp_clone/js/components/MainWindow/ClutterBar.tsx`

## Status Summary

**Overall**: 🟡 Ready to begin discovery phase

**Confidence Level**: Medium
- High: Architecture pattern clarity
- High: Technical approach viability
- Medium: Existing codebase integration
- Low: Current component locations

**Estimated Effort**: 3-5 days
- Discovery: 0.5 day
- Foundation: 1 day
- Implementation: 1.5 days
- Testing: 1 day
- Documentation: 0.5 day
- Buffer: 0.5 day

**Blocker Risk**: Low-Medium
- Primary risk: Missing SkinEngine implementation
- Mitigation: Can create minimal version if needed

---

*This document will be updated as discovery progresses and actual component locations are confirmed.*


---

## 🎉 Final Summary

**Delivered Features:**
1. ✅ D button - Double-size mode (100% ↔ 200%)
2. ✅ A button - Always on top window float
3. ✅ Ctrl+D keyboard shortcut
4. ✅ Ctrl+A keyboard shortcut
5. ✅ Clutter bar with 5 buttons (O, A, I, D, V)
6. ✅ State persistence for both features
7. ✅ Reactive Windows menu
8. ✅ Oracle-reviewed and approved

**Production Status:** ✅ READY TO MERGE
**Oracle Risk Level:** LOW
**Test Coverage:** Manual testing complete
**Documentation:** Complete

---

*Task completed: 2025-10-30*
*Ready for PR: YES*

