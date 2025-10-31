# Ready for Next Session - MacAmp Development

**Last Updated:** 2025-10-30
**Current Branch:** `main`
**Build Status:** ✅ Swift 6.0 + Clutter Bar (2 of 5 buttons functional)

---

## 🎉 **Latest: Clutter Bar D & A Buttons Complete!**

### **PR #26 - MERGED (2025-10-30)**

**Features Delivered:**
- ✅ D Button - Double-size mode (100% ↔ 200%)
- ✅ A Button - Always on top (window float)
- ✅ Keyboard shortcuts (Ctrl+D, Ctrl+A)
- ✅ Clutter bar with 5 buttons (2 functional, 3 scaffolded)
- ✅ State persistence for both features
- ✅ Windows menu integration with dynamic labels

**Implementation:**
- 12 commits, 6 files modified
- Oracle-reviewed (2 rounds, all issues fixed)
- Manual testing passed
- Production ready

**Status:** ✅ **SHIPPED TO MAIN**

---

## 🎯 **Immediate Next Tasks (Ready to Implement)**

### **NEW: AirPlay Integration (PLANNED - Oracle-Reviewed)**

**Status:** ✅ Complete task ready in `tasks/airplay/`
**Effort:** 2-6 hours (3 phases)
**Priority:** HIGH - User-requested feature

**What's Ready:**
- ✅ Gemini research complete (with Oracle corrections)
- ✅ Oracle review complete (5 critical issues fixed)
- ✅ Entitlements verified (no changes needed)
- ✅ Implementation plan with Winamp logo overlay approach
- ✅ All task files created (research, plan, state, todo)

**Key Findings:**
- ✅ AVRoutePickerView (import AVKit, not AVFoundation)
- ✅ **CRITICAL:** Must add engine configuration observer or audio goes silent
- ❌ Custom UI impossible (APIs don't exist)
- ✅ Logo overlay approach validated (user's creative idea!)
- ❌ No Info.plist changes needed (NSLocalNetworkUsageDescription is iOS-only)

**See:** `tasks/airplay/IMPLEMENTATION_SUMMARY.md` for overview

---

### **SHIPPED: Oscilloscope/Spectrum Analyzer Modes (PR #27 - MERGED)**

**Status:** ✅ Complete and merged to main
**Date:** 2025-10-30
**Time Spent:** ~3 hours

**What Was Delivered:**
- ✅ Click spectrum analyzer to cycle modes
- ✅ 3 modes: Spectrum, Oscilloscope, None
- ✅ Spectrum: FFT frequency bars (19 bars)
- ✅ Oscilloscope: Time-domain waveform (connected line)
- ✅ None: Off/blank
- ✅ State persistence
- ✅ Type-safe VisualizerMode enum
- ✅ Centralized constants (VisualizerLayout)

**User Feedback:** "Amazing! It works!"

**Key Learning:**
- User discovered oscilloscope wasn't active enough
- Root cause: Using RMS (averaged) instead of raw waveform samples
- Fixed: Expose actual time-domain mono buffer samples
- Result: Very dynamic oscilloscope! ✅

**Oracle Reviews:** 2 rounds, 7 issues fixed, production-ready

---

### **Clutter Bar Completion (3 buttons remaining)**

**Current Status:**
- O: Scaffolded (options menu) - Ready to implement
- A: FUNCTIONAL ✅ (always on top + Ctrl+A)
- I: Scaffolded (info dialog) - Ready to implement
- D: FUNCTIONAL ✅ (double-size + Ctrl+D)
- V: Scaffolded (visualizer) - **Could be Oscilloscope/RMS toggle!**

### **Recommended: I Button (Track Info Dialog) - 1-2 hours**

**Why start here:**
- Simple feature (just display metadata)
- Follow established D/A button pattern
- Quick win
- Uses existing AudioPlayer data

**Implementation steps:**
1. Create task directory: `tasks/info-button/`
2. Review pattern: `tasks/double-size-button/state.md`
3. Remove `.disabled(true)` from I button
4. Create `TrackInfoView.swift` sheet
5. Display: currentTitle, duration, bitrate, format
6. Add Ctrl+I keyboard shortcut to AppCommands
7. Test and commit

**Files to modify:**
- `WinampMainWindow.swift` - Enable I button (Lines 524-528)
- Create `TrackInfoView.swift` - Info dialog
- `AppCommands.swift` - Add Ctrl+I shortcut

### **Alternative: V Button (Visualizer Modes) - 1 hour**

**Even quicker:**
- Visualizer already exists in codebase
- Just add mode cycling (0=off, 1=spectrum, 2=oscilloscope)
- Follow D/A button pattern
- Add Ctrl+V shortcut

### **Alternative: O Button (Options Menu) - 2-3 hours**

**More complex:**
- Context menu with settings
- Skin selection
- Preferences access
- Reference webamp implementation

---

## 💡 **Important Context from Recent Sessions**

### **Critical Pattern: @Observable Reactivity**

**DO NOT use @ObservationIgnored with properties you want to observe!**

```swift
// ❌ WRONG - Blocks reactivity:
@ObservationIgnored
@AppStorage("key") var value: Bool = false

// ✅ CORRECT - Maintains @Observable:
var value: Bool = false {
    didSet {
        UserDefaults.standard.set(value, forKey: "key")
    }
}
```

This caused the double-size button to not trigger window resize initially.

### **AirPlay Critical Finding: AVAudioEngine Configuration**

**Oracle Discovery:** Engine STOPS when switching to AirPlay (sample rate changes)

**MUST implement engine restart observer or AirPlay audio goes silent:**

```swift
NotificationCenter.default.addObserver(
    forName: .AVAudioEngineConfigurationChange,
    object: audioEngine,
    queue: .main
) { [weak self] _ in
    // Save state, restart engine, resume playback
    self?.handleEngineConfigurationChange()
}
```

**Without this:** User switches to AirPlay → audio stops → appears broken
**With this:** Seamless routing with automatic resume

### **Oracle vs Gemini: API Accuracy**

**Lesson Learned:**
- Gemini: Good for conceptual research, 60% technically accurate
- Oracle: Catches implementation details, API existence, edge cases
- **Always have Oracle review Gemini's findings!**

**AirPlay Example:**
- Gemini said: "Use AVFoundation" → ❌ Wrong (it's AVKit)
- Gemini said: "Use outputNode.setDeviceID()" → ❌ Doesn't exist
- Gemini said: "Add NSLocalNetworkUsageDescription" → ❌ iOS-only
- Oracle caught all 5 critical errors before implementation ✅

### **Clutter Bar Button Pattern (Use for O, I, V)**

Complete working example from D and A buttons:

```swift
// 1. Add state to AppSettings (already done for O, I, V)
var showInfoDialog: Bool = false {
    didSet {
        UserDefaults.standard.set(showInfoDialog, forKey: "showInfoDialog")
    }
}

// Load in init():
self.showInfoDialog = UserDefaults.standard.bool(forKey: "showInfoDialog")

// 2. In buildClutterBarButtons() in WinampMainWindow.swift:
let iSpriteName = settings.showInfoDialog
    ? "MAIN_CLUTTER_BAR_BUTTON_I_SELECTED"
    : "MAIN_CLUTTER_BAR_BUTTON_I"

Button(action: {
    settings.showInfoDialog.toggle()
}) {
    SimpleSpriteImage(iSpriteName, width: 8, height: 7)
}
.buttonStyle(.plain)
.help("Show track info (Ctrl+I)")
.at(Coords.clutterButtonI)

// 3. Add keyboard shortcut to AppCommands.swift:
Button(settings.showInfoDialog ? "Hide Info" : "Show Info") {
    settings.showInfoDialog.toggle()
}
.keyboardShortcut("i", modifiers: [.control])

// 4. Implement the feature:
// - Create TrackInfoView.swift
// - Show as sheet or window
// - Display audioPlayer.currentTitle, duration, etc.
```

### **Unified Window Architecture**

**Important:** All 3 windows (main, EQ, playlist) are in ONE macOS window.

- Managed by `UnifiedDockView.swift`
- Uses `.scaleEffect()` for double-size mode
- Window level (.normal/.floating) applies to all 3 together
- Future: Will be separated with magnetic docking (see `tasks/magnetic-window-docking/`)

### **Oracle Usage**

When you need code review, architecture advice, or research:

```bash
codex-mcp "@file1.swift @file2.swift Your question or review request"
```

Oracle found and helped fix:
- 8 code quality issues (dead code, bugs, sprite coordinates)
- NSApp.keyWindow bug (wrong window targeted)
- @Bindable reactivity issue (menu labels stuck)

---

## 📚 **Key Documentation**

**This Session (Double-Size Button):**
- `tasks/double-size-button/` - Complete implementation docs
  - state.md - All 12 commits, Oracle reviews, final status
  - FEATURE_DOCUMENTATION.md - User guide
  - COMPLETION_SUMMARY.md - Stats and learnings

**For Next Button:**
- Copy the pattern from `tasks/double-size-button/`
- All sprites already defined in `SkinSprites.swift`
- All state properties already scaffolded in `AppSettings.swift`
- Just wire button, add feature logic, add shortcut

**For Future Magnetic Docking:**
- `tasks/magnetic-window-docking/research.md` - Complete migration guide
  - How double-size mode will work with separate windows
  - Playlist menu scaling notes

**Swift Modernization (Previous Sessions):**
- `tasks/swift-modernization-recommendations/` - All phases complete
- @Observable migration patterns
- Swift 6 strict concurrency patterns

---

## 🚀 **Where to Start Next Session**

### **Option A: Continue Clutter Bar (Recommended)**

Pick the next button to implement:

**I Button (Info) - Easiest (1-2 hours):**
1. Create `tasks/info-button/`
2. Follow D/A button pattern
3. Create simple sheet with track metadata
4. Add Ctrl+I shortcut

**V Button (Visualizer) - Quick (1 hour):**
1. Create `tasks/visualizer-button/`
2. Add mode cycling logic
3. Visualizer component already exists
4. Add Ctrl+V shortcut

**O Button (Options) - Complex (2-3 hours):**
1. Create `tasks/options-button/`
2. Context menu with settings
3. Reference webamp implementation
4. Add Ctrl+O shortcut (or right-click menu)

### **Option B: Different Priority**

**Playlist Features:**
- Add scrolling (currently fixed height)
- Fix menu button scaling in double-size mode (needs magnetic docking)

**Audio Features:**
- Persist volume/balance settings
- Repeat mode enhancements (off/one/all)

**Window Features:**
- Magnetic window docking (major task, 10-16 hours)
- Screen bounds validation

---

## 📊 **Project Metrics**

**Recent PRs:**
- PR #23-25: Swift modernization (3 PRs)
- PR #26: Clutter bar D & A buttons

**Current State:**
- Main branch is production-ready
- Zero build warnings
- All features tested
- Oracle-reviewed code
- Complete documentation

**Clutter Bar Progress:** 40% (2 of 5 buttons)

---

## ⚠️ **Known Issues**

**Playlist Menu Scaling:**
- Menu buttons (ADD, REM, SEL, MISC, LIST OPTS) don't scale in double-size mode
- Expected: Will fix when implementing magnetic-window-docking
- Documented in `tasks/magnetic-window-docking/research.md`
- Not blocking for current features

**No Other Known Issues** ✅

---

## 🎓 **Key Learnings from This Session**

### **1. @Observable + @AppStorage Reactivity**
- Don't use `@ObservationIgnored` with `@AppStorage`
- Use `didSet` with `UserDefaults.standard.set()` instead
- Maintains @Observable reactivity

### **2. Window Reference Targeting**
- Don't use `NSApp.keyWindow` for feature toggles
- Capture specific window reference via `WindowAccessor`
- Store in `@State private var dockWindow: NSWindow?`

### **3. Commands Reactivity**
- Use `@Bindable var` not `let` for Commands struct parameters
- Ensures menu labels update in real-time
- Mirrors existing `SkinsCommands` pattern

### **4. Clutter Bar Implementation Pattern**
- State in AppSettings with `didSet` persistence
- Sprite name computed outside button closure for reactivity
- Simple Button (not Toggle) for cleaner code
- Add `@Environment(AppSettings.self)` to view
- Keyboard shortcut in AppCommands with `@Bindable`

### **5. Oracle Code Review Process**
- Review early and often (caught 8 issues before merge)
- Round 1: Dead code, sprite bugs, debug prints
- Round 2: NSApp.keyWindow bug, @Bindable reactivity
- Final: Production-ready code

---

## 📂 **Task Organization**

**Use this workflow for next buttons:**

1. **Research Phase:**
   - Create `tasks/[button-name]/`
   - Create research.md (gather requirements, check webamp)

2. **Planning Phase:**
   - Create plan.md (implementation steps)
   - Create state.md (track current status)
   - Create todo.md (checklist)

3. **Implementation:**
   - Follow the clutter bar button pattern above
   - Update todo.md as you go
   - Commit frequently with good messages

4. **Oracle Review:**
   - Request code review from Oracle
   - Fix any issues found
   - Request final approval

5. **Documentation:**
   - Update README.md with new feature
   - Complete task docs
   - Create PR

**Reference:** See `tasks/double-size-button/` for complete example

---

## 🔧 **Build & Run**

```bash
# Build with Thread Sanitizer
xcodebuild -project MacAmpApp.xcodeproj \
  -scheme MacAmpApp \
  -enableThreadSanitizer YES \
  build

# Or use Xcode MCP:
# build_macos({
#   projectPath: "/Users/hank/dev/src/MacAmp/MacAmpApp.xcodeproj",
#   scheme: "MacAmpApp",
#   extraArgs: ["-enableThreadSanitizer", "YES"]
# })
```

---

## 📝 **Summary**

**MacAmp is now:**
- Modern (Swift 6, @Observable)
- Functional (2/5 clutter buttons working)
- Production-ready (Oracle-reviewed, tested)
- Well-documented (complete task histories)

**Next session:**
- Pick next clutter button (I or V recommended)
- Follow established pattern
- Should take 1-2 hours
- Consult Oracle if needed

**All context preserved in:**
- `tasks/double-size-button/` for implementation patterns
- `tasks/magnetic-window-docking/` for future work
- This file for quick start

---

**Status:** ✅ Ready for next development session
**Recommended:** Implement I button (track info dialog)
**Branch:** `main` (clean, all work merged)

🚀 **Ready to continue!**
