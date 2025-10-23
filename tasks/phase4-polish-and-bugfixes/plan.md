# Phase 4 Polish & Bug Fixes - Implementation Plan

**Date:** 2025-10-13
**Branch:** `feature/phase4-polish-bugfixes`
**Status:** Planning Complete
**Estimated Time:** 3-5 hours total

---

## 🎯 Phase 4 Goals

**Primary Objectives:**
1. ✅ Fix critical track seeking bug
2. ✅ Clean up debug logging for production
3. ✅ Verify and fix any remaining UI issues

**Success Criteria:**
- Track seeking works reliably across all audio formats
- No debug output in production builds
- Clean, professional codebase ready for release
- All UI elements properly aligned

---

## 📋 Implementation Task List

### Task 0: Remove macOS Title Bar ✅ COMPLETED

**Priority:** P0 - User Request
**Time Spent:** 2 hours
**Status:** ✅ COMPLETE (2025-10-13)

**See:** `tasks/phase4-polish-and-bugfixes/title-bar-solution.md` for complete documentation.

**Summary:**
- Removed macOS title bar completely using `.windowStyle(.hiddenTitleBar)` + `window.isMovableByWindowBackground = false`
- Implemented `WindowDragGesture()` on all three title bars (Main, Equalizer, Playlist)
- All sliders work independently without moving window
- Smooth window dragging via title bars only

**Future Enhancement:** Independent window movement with magnetic docking (see Task 0B below)

---

### Task 1: Fix EQ Preset Menu Interaction 🔴 CRITICAL

**Priority:** P0 - Critical Bug
**Estimated Time:** 1 hour
**Files:** `MacAmpApp/Views/WinampEqualizerWindow.swift`

#### Problem Summary

The EQ "Presets" button shows a menu with "Load" and "Save" options, but clicking "Load" sometimes doesn't show the submenu with preset list. Instead, the menu "jumps" or "fidgets" and doesn't display properly.

#### Root Cause (Hypothesis)

SwiftUI Menu behavior issue with nested menus:
- Nested Menu within Menu may have interaction conflicts
- Menu positioning near window edges
- macOS menu system timing issues

#### Investigation Steps

1. **Reproduce the issue:**
   - Open Equalizer window
   - Click "Presets" button
   - Try clicking "Load" multiple times
   - Note when it works vs when it glitches

2. **Check menu structure:**
   - Review Menu nesting in buildPresetsButton()
   - Check if menuStyle affects behavior
   - Test button positioning (near edge?)

3. **Test alternatives:**
   - Try Picker instead of nested Menu
   - Test with different menuIndicator settings
   - Try onTapGesture vs Menu

#### Solution Options

**Option A: Replace nested Menu with custom popover**
```swift
@State private var showPresetPicker = false

Button {
    showPresetPicker.toggle()
} label: {
    SimpleSpriteImage("EQ_PRESETS_BUTTON", width: 44, height: 12)
}
.popover(isPresented: $showPresetPicker) {
    VStack {
        Text("Load Preset").font(.headline)
        Divider()
        ForEach(EQPreset.builtIn) { preset in
            Button(preset.name) {
                audioPlayer.applyEQPreset(preset)
                showPresetPicker = false
            }
        }
    }
    .padding()
}
```

**Option B: Use single-level Menu with sections**
```swift
Menu {
    Section("Load Preset") {
        ForEach(EQPreset.builtIn) { preset in
            Button(preset.name) {
                audioPlayer.applyEQPreset(preset)
            }
        }
    }

    Section {
        Button("Save...") {
            showSavePresetDialog()
        }
    }
} label: {
    SimpleSpriteImage("EQ_PRESETS_BUTTON", width: 44, height: 12)
}
```

**Option C: Fix existing Menu with delays**
```swift
Menu {
    Menu("Load") {
        ForEach(EQPreset.builtIn) { preset in
            Button(preset.name) {
                // Add small delay to let menu dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    audioPlayer.applyEQPreset(preset)
                }
            }
        }
    }
    // ...
}
.menuStyle(.borderlessButton)
.menuIndicator(.visible) // Try making indicator visible
```

#### Testing Plan

1. **Test each option:**
   - Implement solution
   - Click "Presets" 10 times rapidly
   - Verify menu shows consistently
   - Test near window edges
   - Test with different macOS versions

2. **User interaction testing:**
   - Load preset successfully
   - Save preset successfully
   - Menu dismisses properly
   - No visual glitches

#### Success Criteria

- ✅ "Load" submenu appears reliably every time
- ✅ No jumping or fidgeting behavior
- ✅ Smooth menu transitions
- ✅ Works near window edges
- ✅ Presets load correctly when selected

---

### Task 2: Fix Track Seeking Race Condition 🔴 CRITICAL

**Priority:** P0 - Critical Bug
**Estimated Time:** 1-2 hours
**Files:** `MacAmpApp/Audio/AudioPlayer.swift`

#### Problem Summary

Race condition between async `loadTrack()` and synchronous `seek()`:
- `currentDuration` is set asynchronously after track loads
- `scheduleFrom()` depends on `currentDuration` being valid
- If user seeks before duration loads, seek uses stale/zero duration
- Results in seek failure or wrong position

#### Solution: Use Direct File Length

**Implementation Steps:**

1. **Modify `scheduleFrom()` to use `file.length` directly**
   - Location: `AudioPlayer.swift` (private func scheduleFrom)
   - Replace: `min(time, currentDuration)`
   - With: `min(time, Double(file.length) / sampleRate)`

2. **Add guard clause for safety**
   - Ensure `audioFile` is valid
   - Log warning if seek attempted without loaded file

3. **Add seek validation in `seek()` method**
   - Guard against seeking when no file loaded
   - Provide clear error message

#### Code Changes

**File: `MacAmpApp/Audio/AudioPlayer.swift`**

**Change 1: Update scheduleFrom() (lines ~400-450)**

```swift
private func scheduleFrom(time: Double) {
    guard let file = audioFile else {
        #if DEBUG
        NSLog("⚠️ scheduleFrom: No audio file loaded")
        #endif
        return
    }

    let sampleRate = file.processingFormat.sampleRate

    // NEW: Use file.length directly instead of currentDuration
    // This eliminates race condition with async track loading
    let fileDuration = Double(file.length) / sampleRate
    let startFrame = AVAudioFramePosition(max(0, min(time, fileDuration)) * sampleRate)

    let totalFrames = file.length
    let framesRemaining = max(0, totalFrames - startFrame)

    // Store the new starting time for progress tracking
    playheadOffset = Double(startFrame) / sampleRate

    // Stop the player and clear existing buffers
    playerNode.stop()

    // Schedule the new segment if there's audio left to play
    if framesRemaining > 0 {
        playerNode.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: AVAudioFrameCount(framesRemaining),
            at: nil,
            completionHandler: { [weak self] in
                DispatchQueue.main.async { self?.onPlaybackEnded() }
            }
        )
    } else {
        onPlaybackEnded()
    }
}
```

**Change 2: Add validation to seek() (lines ~618-635)**

```swift
func seek(to time: Double, resume: Bool? = nil) {
    // Guard: Ensure file is loaded
    guard audioFile != nil else {
        #if DEBUG
        NSLog("⚠️ seek: Cannot seek - no audio file loaded")
        #endif
        return
    }

    let shouldPlay = resume ?? isPlaying
    wasStopped = false
    scheduleFrom(time: time)
    currentTime = time

    // Safe calculation: if currentDuration not yet loaded, scheduleFrom handles it
    playbackProgress = currentDuration > 0 ? time / currentDuration : 0

    if shouldPlay {
        startEngineIfNeeded()
        playerNode.play()
        startProgressTimer()
        isPlaying = true
        isPaused = false
    } else {
        isPlaying = false
        progressTimer?.invalidate()
    }
}
```

#### Testing Plan

**Test Scenarios:**

1. **Immediate Seek After Load**
   - Load new track
   - Immediately drag position slider (before 1 second)
   - Expected: Seek works correctly
   - Previously: Would fail or seek to 0

2. **Seek While Playing**
   - Start playback
   - Drag position slider to middle
   - Expected: Audio jumps to new position, continues playing

3. **Seek While Paused**
   - Pause playback
   - Drag position slider
   - Expected: Position changes, stays paused

4. **Seek to Start (0:00)**
   - Play track
   - Drag slider to beginning
   - Expected: Track restarts from beginning

5. **Seek to End**
   - Play track
   - Drag slider to end
   - Expected: Track completion triggers, next track or stop

6. **Multiple Audio Formats**
   - Test with: MP3 (44.1kHz), MP3 (48kHz), FLAC, AAC/M4A
   - Expected: All formats seek correctly

**Testing Commands:**
```bash
swift build
.build/debug/MacAmpApp

# Then in app:
# 1. Load audio file
# 2. Immediately drag position slider
# 3. Verify audio seeks
# 4. Check console for any warnings
```

---

### Task 3: Debug Logging Cleanup 🟢 POLISH

**Priority:** P1 - Code Quality
**Estimated Time:** 1-2 hours
**Files:** Multiple (primarily `SkinManager.swift`)

#### Problem Summary

30+ debug logging statements throughout codebase:
- NSLog and print() statements
- Verbose operational logging
- Archive debugging dumps
- No conditional compilation for debug vs. production

#### Solution: Conditional Compilation + Cleanup

**Implementation Strategy:**

1. **Wrap all debug logs in #if DEBUG blocks**
2. **Convert operational logs to errors-only**
3. **Remove verbose success messages**
4. **Keep critical error/warning logs**

#### Code Changes

**File: `MacAmpApp/ViewModels/SkinManager.swift`**

This file has the most debug logging. Apply pattern throughout:

**Pattern to Apply:**

```swift
// BEFORE:
NSLog("📦 SkinManager: Discovered \(skins.count) skins")
for skin in skins {
    NSLog("   - \(skin.id): \(skin.name) (\(skin.source))")
}

// AFTER:
#if DEBUG
NSLog("📦 SkinManager: Discovered \(skins.count) skins")
for skin in skins {
    NSLog("   - \(skin.id): \(skin.name) (\(skin.source))")
}
#endif
```

**Categories:**

**Category A: Wrap in #if DEBUG (Keep for Development)**
- Skin discovery logs
- Archive content dumps
- Sprite processing debug
- Successfully found sheet messages
- Verbose operational logs

**Category B: Keep Unconditionally (Critical Errors/Warnings)**
- Missing required sprites (⚠️)
- Failed operations (❌)
- User-facing errors
- Fallback creation notices (if impacting functionality)

**Category C: Remove Entirely**
- Redundant success messages
- "Loading skin from..." messages
- "✅ FOUND SHEET" messages (DEBUG only)

#### Specific Changes

**SkinManager.swift Changes:**

1. **Skin Discovery (Lines ~XX):**
```swift
#if DEBUG
NSLog("📦 SkinManager: Discovered \(skins.count) skins")
for skin in skins {
    NSLog("   - \(skin.id): \(skin.name) (\(skin.source))")
}
#endif
```

2. **Archive Debug Dump (Lines ~XX):**
```swift
#if DEBUG
NSLog("=== SPRITE DEBUG: Archive Contents ===")
for entry in archive.entries {
    NSLog("  Available file: \(entry.path)")
}
NSLog("========================================")
#endif
```

3. **Sheet Processing (Lines ~XX):**
```swift
#if DEBUG
NSLog("=== PROCESSING \(sheetsToProcess.count) SHEETS ===")
#endif

for (sheetName, sprites) in sheetsToProcess {
    #if DEBUG
    NSLog("🔍 Looking for sheet: \(sheetName)")
    #endif

    // Keep error logs unconditionally:
    if entry == nil {
        NSLog("⚠️ MISSING SHEET: \(sheetName).bmp/.png not found in archive")
        NSLog("   Expected \(sprites.count) sprites from this sheet")
        for sprite in sprites {
            NSLog("   - Missing sprite: \(sprite.name)")
        }
        createFallbackSprites(for: sprites, sheetName: sheetName)
    }
}
```

4. **Success Messages:**
```swift
// BEFORE:
print("✅ FOUND SHEET: \(sheetName) -> \(entry.path) (\(data.count) bytes)")
print("   Sheet size: \(sheetImage.size.width)x\(sheetImage.size.height)")

// AFTER:
#if DEBUG
print("✅ FOUND SHEET: \(sheetName) -> \(entry.path) (\(data.count) bytes)")
print("   Sheet size: \(sheetImage.size.width)x\(sheetImage.size.height)")
#endif
```

5. **Optional Features (Lines ~XX):**
```swift
if numsExEntry != nil {
    #if DEBUG
    NSLog("✅ OPTIONAL: Found NUMS_EX.BMP - adding extended digit sprites")
    #endif
} else {
    #if DEBUG
    NSLog("ℹ️ INFO: NUMS_EX.BMP not found (normal for many skins)")
    #endif
}
```

#### Complete File Review

Apply same pattern to all files with debug logging:
- `MacAmpApp/Audio/AudioPlayer.swift` (if any)
- `MacAmpApp/Views/*.swift` (if any)
- Any other files with NSLog/print statements

**Review Command:**
```bash
grep -r "NSLog\|print(" MacAmpApp/ --include="*.swift" | grep -v "func print"
```

---

### Task 4: UI Verification & Fixes 🟡 VERIFICATION

**Priority:** P2 - Visual Polish
**Estimated Time:** 30 minutes - 1 hour
**Files:** TBD based on findings

#### 3A: Verify Playlist Button Alignment

**Status:** Code analysis shows correct positions, needs visual verification

**Steps:**

1. **Build and run app:**
```bash
swift build
.build/debug/MacAmpApp
```

2. **Open playlist window:**
   - Press `Cmd+Shift+P` or use menu

3. **Visual inspection:**
   - Compare buttons to reference Winamp screenshots
   - Check alignment with Classic skin
   - Test with Internet Archive skin
   - Verify click targets match visual buttons

4. **If misaligned:**
   - Take screenshots of current vs. expected
   - Adjust coordinates in `WinampPlaylistWindow.swift`
   - Test adjustment with multiple skins

**Reference Coordinates (Current):**

Bottom buttons (y: 206):
- Add: x: 25
- Remove: x: 54
- Selection: x: 83
- Misc: x: 112
- List: x: 231

Title bar buttons (y: 7.5):
- Minimize: x: 248.5
- Shade: x: 258.5
- Close: x: 268.5

**If Adjustment Needed:**

File: `MacAmpApp/Views/WinampPlaylistWindow.swift`

```swift
// Adjust by ±1-2 pixels if needed
SimpleSpriteImage("PLAYLIST_ADD_FILE", width: 22, height: 18)
    .position(x: 25 + adjustmentX, y: 206 + adjustmentY) // Add offsets
```

#### 3B: Verify macOS Title Bar Removal

**Status:** Code shows `.hiddenTitleBar` already configured, verify behavior

**Steps:**

1. **Launch app and check:**
   - Is macOS title bar visible above Winamp title bar?
   - Can you drag window by Winamp title bar?
   - Do minimize/shade/close buttons work?

2. **Expected behavior:**
   - NO macOS title bar visible
   - Only Winamp's custom title bar sprite
   - Dragging title bar moves window
   - Window control buttons functional

3. **If macOS title bar IS visible:**

**Possible causes:**
- macOS version behavior change (Sequoia)
- Multi-window interference
- NSWindow configuration needed

**Potential fixes:**

**Option A: Add .windowToolbarStyle**
```swift
// File: MacAmpApp/MacAmpApp.swift
WindowGroup {
    UnifiedDockView()
        .environmentObject(skinManager)
        .environmentObject(audioPlayer)
        .environmentObject(dockingController)
        .environmentObject(settings)
}
.windowStyle(.hiddenTitleBar)
.windowToolbarStyle(.unifiedCompact(showsTitle: false))  // ADD THIS
.windowResizability(.contentSize)
```

**Option B: AppKit NSWindow configuration**
```swift
// May need custom NSWindow wrapper
extension NSWindow {
    func makeFrameless() {
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        styleMask.insert(.fullSizeContentView)
    }
}
```

**Option C: Custom WindowStyle**
```swift
struct FramelessWindowStyle: WindowStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WindowAccessor { window in
                window?.titlebarAppearsTransparent = true
                window?.titleVisibility = .hidden
            })
    }
}
```

**Decision:** Only implement if issue confirmed by testing.

---

### Task 5: TODO Documentation Cleanup 🟢 POLISH

**Priority:** P2 - Documentation
**Estimated Time:** 30 minutes
**Files:** 5 files with TODOs

#### Current TODOs

1. **SkinManager.swift:520** - `cursors: [:] // TODO: Parse cursors`
2. **Skin.swift:23** - `// TODO: Add properties for the other skin elements`
3. **AudioPlayer.swift:206** - `// TODO: Implement eject logic`
4. **WinampEqualizerWindow.swift:209** - `// TODO: Open file picker for .eqf files`
5. **WinampEqualizerWindow.swift:236** - `// TODO: Save to user presets`

#### Actions

**All TODOs are future enhancements - keep with improved documentation:**

**Pattern to Apply:**

```swift
// BEFORE:
// TODO: Parse cursors

// AFTER:
// TODO (P3): Parse cursors from CURSORS.TXT for custom cursor support
// Not critical - most skins use default cursors
// See: https://wiki.winamp.com/wiki/Skinning/Cursors
```

**File-by-File Updates:**

**1. SkinManager.swift:520**
```swift
cursors: [:]  // TODO (P3): Parse CURSORS.TXT for custom skin cursors
               // Most skins don't define custom cursors, system default is fine
               // Priority: Low - Enhancement only
```

**2. Skin.swift:23**
```swift
// TODO (P2): Add properties for additional skin elements as needed:
// - Regional information (skinInfo.txt)
// - Custom fonts (if skin specifies)
// - Animation metadata (some skins have animated elements)
// Priority: Medium - Implement when supporting advanced skins
```

**3. AudioPlayer.swift:206**
```swift
// TODO (P2): Implement eject logic
// Should: Clear playlist, stop playback, reset UI
// Winamp behavior: Eject button clears current track
// Priority: Medium - Nice-to-have feature
```

**4. WinampEqualizerWindow.swift:209**
```swift
// TODO (P2): Implement EQ preset file picker
// Should: Open file dialog for .eqf files, import presets
// Format: Winamp EQ preset format (.eqf)
// Priority: Medium - Enhancement for power users
```

**5. WinampEqualizerWindow.swift:236**
```swift
// TODO (P1): Implement EQ preset persistence
// Should: Save user presets to disk (JSON or .eqf format)
// Storage: ~/Library/Application Support/MacAmp/EQPresets/
// Priority: High - Expected feature for EQ
// Related: Also need Load functionality (line 209)
```

---

## 🔄 Implementation Order

### Phase 4.1: Critical Fixes (Session 1)
**Estimated: 2-3 hours**

1. ✅ Fix EQ preset menu interaction
   - Fix nested menu glitching issue
   - Test menu reliability
   - Verify all presets load correctly

2. ✅ Fix track seeking race condition
   - Modify `scheduleFrom()` in AudioPlayer.swift
   - Add validation guards
   - Test all scenarios

3. ✅ Basic testing
   - Test immediate seek after load
   - Test various audio formats
   - Verify no regressions

### Phase 4.2: Verification (Session 2)
**Estimated: 30 min - 1 hour**

4. ✅ Visual verification
   - Launch app, test UI
   - Check playlist button alignment
   - Verify title bar behavior

5. ✅ Fix confirmed issues only
   - Only make changes if issues confirmed
   - Test fixes immediately

### Phase 4.3: Polish (Session 3)
**Estimated: 1-2 hours**

6. ✅ Debug logging cleanup
   - Wrap all debug logs in #if DEBUG
   - Review and clean SkinManager.swift
   - Check all other files

7. ✅ TODO documentation
   - Update all 5 TODOs with context
   - Add priority levels
   - Add implementation notes

8. ✅ Final verification
   - Build in release mode (if applicable)
   - Verify no debug output
   - Clean build test

---

## 🧪 Testing Strategy

### Automated Testing
- Clean build: `swift build`
- No warnings expected
- No errors expected

### Manual Testing

**Critical Path:**
1. Launch app
2. Load audio file (MP3, FLAC, etc.)
3. Immediately seek (drag position slider)
4. Verify audio jumps correctly
5. Test seek while playing
6. Test seek while paused

**UI Verification:**
1. Visual inspection of all windows
2. Button alignment check
3. Title bar check
4. Skin switching test

**Debug Verification:**
1. Build in debug mode: `swift build`
2. Run: `.build/debug/MacAmpApp`
3. Verify debug logs appear in console

4. Build in release mode (if applicable): `swift build -c release`
5. Run: `.build/release/MacAmpApp`
6. Verify NO debug logs in console

---

## 📝 Documentation Updates

### Files to Update After Implementation

1. **SESSION_STATE.md**
   - Mark Phase 4 tasks as complete
   - Update known issues list
   - Document any remaining issues

2. **tasks/phase4-polish-and-bugfixes/state.md**
   - Track implementation progress
   - Document test results
   - Note any blockers or changes

3. **CHANGELOG.md** (if exists) or create one
   - Document bug fixes
   - List improvements
   - Version bump (if applicable)

---

## 🚀 Deployment Checklist

Before marking Phase 4 complete:

- [ ] Track seeking works reliably
- [ ] All test scenarios pass
- [ ] Multiple audio formats tested
- [ ] Playlist buttons visually aligned
- [ ] Title bar behavior correct
- [ ] No debug output in release builds
- [ ] All TODOs properly documented
- [ ] Code review complete
- [ ] Documentation updated
- [ ] Clean build (0 warnings)

---

## 🔧 Rollback Plan

If issues arise during implementation:

**Option 1: Revert specific changes**
```bash
git checkout HEAD -- MacAmpApp/Audio/AudioPlayer.swift
```

**Option 2: Revert entire branch**
```bash
git checkout main
git branch -D feature/phase4-polish-bugfixes
```

**Option 3: Create fix branch**
```bash
git checkout -b fix/seek-hotfix
# Make minimal fix
```

---

## 📊 Success Metrics

### Must Have:
- ✅ Seek works immediately after load
- ✅ Seek works across all audio formats
- ✅ No debug output in console (production)

### Should Have:
- ✅ Clean codebase (wrapped debug logs)
- ✅ UI elements properly aligned
- ✅ TODOs documented

### Nice to Have:
- ✅ Zero TODOs without context
- ✅ Performance profiling
- ✅ Edge case handling

---

## 🎯 Next Steps After Plan Approval

1. Create `state.md` to track progress
2. Begin Task 1: Fix seeking race condition
3. Test thoroughly
4. Move to Task 2-4 based on findings
5. Update documentation
6. Prepare for merge to main

---

---

## 🔮 Future Tasks (Post-Phase 4)

### Task 0B: Independent Window Movement with Magnetic Docking

**Priority:** P3 - Enhancement
**Estimated Time:** 4-6 hours
**Status:** ⏸️ DEFERRED (Future Phase)

**Goal:** Allow each window (Main, Equalizer, Playlist) to be dragged independently and "snap" together like classic Winamp.

**Current State:** All three windows are in a unified VStack (UnifiedDockView), so they move as one unit when dragging any title bar.

**Desired Behavior:**
1. Each window can be dragged independently
2. Windows magnetically "snap" together when dragged near each other
3. Snapped windows move together as a group
4. Window arrangement persists across app launches
5. Matches classic Winamp docking behavior

**Implementation Plan:**

**Step 1: Separate WindowGroups**
- Break `UnifiedDockView` into three separate `WindowGroup` definitions
- Create MainWindow, EqualizerWindow, PlaylistWindow as independent windows
- Each has its own window lifecycle

**Step 2: Magnetic Snapping Logic**
- Implement `DockingController` to track window positions
- Detect when windows are within "snap distance" (e.g., 10 pixels)
- Automatically adjust positions to create perfect alignment
- Visual feedback when snapping occurs

**Step 3: Group Movement**
- When windows are snapped together, detect drag on any title bar
- Move all snapped windows together maintaining relative positions
- Smooth animation for group movement

**Step 4: Persistence**
- Save window arrangement to UserDefaults/AppStorage
- Store: position, snapped state, visible/hidden
- Restore arrangement on app launch

**Files to Modify:**
- `MacAmpApp/MacAmpApp.swift` - Create separate WindowGroups
- `MacAmpApp/ViewModels/DockingController.swift` - Add magnetic snapping logic
- `MacAmpApp/Views/WinampMainWindow.swift` - Track position changes
- `MacAmpApp/Views/WinampEqualizerWindow.swift` - Track position changes
- `MacAmpApp/Views/WinampPlaylistWindow.swift` - Track position changes

**Research Needed:**
- Multi-window coordination in SwiftUI/AppKit
- NSWindow positioning API
- Magnetic snapping algorithms
- Window grouping patterns
- Reference: Original Winamp docking behavior

**SwiftUI APIs to Use:**
- `WindowGroup` with separate IDs
- `NSWindow.frame` for position tracking
- Window position notifications
- Custom window delegate for movement detection

**Challenges:**
1. Coordinating multiple independent windows
2. Detecting relative positions efficiently
3. Smooth animation during snapping
4. Handling window minimize/close with grouped windows
5. Cross-platform considerations (if supporting multiple macOS versions)

**Success Criteria:**
- ✅ Each window draggable independently
- ✅ Windows snap together within 10px
- ✅ Snapped windows move as a group
- ✅ Window arrangement persists
- ✅ Smooth, native-feeling behavior

**References:**
- Original Winamp for Windows docking behavior
- macOS window management APIs
- SwiftUI multi-window coordination patterns

---

**Plan Status:** ✅ UPDATED WITH NEW TASKS
**Tasks:** 6 total (0 complete, 1 in progress, 5 pending)
**Estimated Total Time:** 4-7 hours (Phase 4)
**Current:** Task 0 complete (title bar removal)
**Next Action:** Task 1 - Fix EQ preset menu, then Task 2 - Fix seeking bug
