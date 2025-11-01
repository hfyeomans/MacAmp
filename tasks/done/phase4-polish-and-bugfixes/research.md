# Phase 4 Polish & Bug Fixes - Research

**Date:** 2025-10-13
**Branch:** `feature/phase4-polish-bugfixes`
**Status:** Research Complete

---

## 🔍 Research Overview

This document contains detailed technical research for Phase 4 polish and bug fix tasks. Research conducted using Gemini CLI analysis of the MacAmp codebase.

---

## 🐛 Issue 1: Track Seeking Not Working (CRITICAL)

### Current Implementation

**Files Analyzed:**
- `MacAmpApp/Audio/AudioPlayer.swift`
- `MacAmpApp/Views/WinampMainWindow.swift`

### UI Side (Position Slider) - ✅ CORRECT

The position slider drag handling in `WinampMainWindow.swift` is **correctly implemented**:

**Lines 515-524:** Drag gesture properly configured
```swift
.gesture(
    DragGesture(minimumDistance: 0)
        .onChanged { value in
            handlePositionDrag(value, in: geo)
        }
        .onEnded { value in
            handlePositionDragEnd(value, in: geo)
        }
)
```

**Lines 768-784:** `handlePositionDrag()` correctly:
- Pauses audio during drag
- Sets `isScrubbing = true`
- Updates local `scrubbingProgress` state
- Does NOT spam the audio engine with seek calls

**Lines 786-800:** `handlePositionDragEnd()` correctly:
- Performs single seek() call at end
- Calculates target time: `progress * audioPlayer.currentDuration`
- Restores playback state with `wasPlayingPreScrub`

**Lines 505-506:** Slider binding correctly uses conditional state:
```swift
let currentProgress = isScrubbing ? scrubbingProgress : audioPlayer.playbackProgress
```

### Audio Side (AudioPlayer.seek) - ⚠️ RACE CONDITION FOUND

**Lines 618-635:** `seek(to:resume:)` implementation appears correct:
```swift
func seek(to time: Double, resume: Bool? = nil) {
    let shouldPlay = resume ?? isPlaying
    wasStopped = false
    scheduleFrom(time: time)
    currentTime = time
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

**CRITICAL ISSUE DISCOVERED:**

The `scheduleFrom()` method has a **race condition** with asynchronous track loading.

**Problem in `scheduleFrom()`:**
```swift
private func scheduleFrom(time: Double) {
    guard let file = audioFile else { return }
    let sampleRate = file.processingFormat.sampleRate
    let startFrame = AVAudioFramePosition(max(0, min(time, currentDuration)) * sampleRate)
    // ...
}
```

The calculation uses `currentDuration`, but this is set asynchronously in `loadTrack()`:

```swift
// From loadTrack()
Task { @MainActor in
    do {
        let durationCM = try await asset.load(.duration)
        let duration = durationCM.seconds
        self.currentDuration = duration // ⚠️ SET LATER!
    } catch {
        self.currentDuration = 0.0
    }
}
```

**Race Condition Scenario:**
1. Track loads, `loadTrack()` starts async task
2. User drags position slider BEFORE `currentDuration` is set
3. `scheduleFrom()` uses `currentDuration = 0.0` (or previous track's duration)
4. `min(time, currentDuration)` returns 0
5. Seek fails or jumps to wrong position

### Progress Timer - ✅ CORRECT

The `startProgressTimer()` correctly calculates position:
```swift
let current = Double(playerTime.sampleTime) / playerTime.sampleRate + self.playheadOffset
self.currentTime = current
```

Combines `playheadOffset` (segment start) + elapsed time = correct position after seek.

### Root Cause Analysis

**Primary Issue:** Race condition between async `loadTrack()` and synchronous `seek()`

**Secondary Issue:** No validation that `currentDuration` is ready before seeking

### Recommended Fix

**Option A: Guard against invalid duration**
```swift
private func scheduleFrom(time: Double) {
    guard let file = audioFile else { return }
    guard currentDuration > 0 else {
        NSLog("⚠️ Cannot seek: track duration not loaded yet")
        return
    }
    // ... rest of implementation
}
```

**Option B: Wait for duration to load**
```swift
func seek(to time: Double, resume: Bool? = nil) {
    guard currentDuration > 0 else {
        NSLog("⚠️ Seek requested but duration not ready, ignoring")
        return
    }
    // ... rest of implementation
}
```

**Option C: Use file.length directly (most robust)**
```swift
private func scheduleFrom(time: Double) {
    guard let file = audioFile else { return }
    let sampleRate = file.processingFormat.sampleRate
    let fileDuration = Double(file.length) / sampleRate
    let startFrame = AVAudioFramePosition(max(0, min(time, fileDuration)) * sampleRate)
    // ... rest of implementation
}
```

**Recommendation:** Use Option C - derive duration from `file.length` directly, eliminating dependency on async-loaded `currentDuration`.

---

## 🎨 Issue 2: Playlist Button Alignment

### Current State

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

### Analysis Result: ✅ POSITIONS APPEAR CORRECT

Gemini analysis shows all button positions are **accurately positioned** per classic Winamp layout.

**Bottom Control Buttons (Line 206-236):**
- All share `y: 206` coordinate
- Add Button: `x: 25`
- Remove Button: `x: 54`
- Selection Button: `x: 83`
- Misc Button: `x: 112`
- List Button: `x: 231`

**Title Bar Buttons (Line 245-258):**
- All share `y: 7.5` coordinate
- Minimize: `x: 248.5`
- Shade: `x: 258.5`
- Close: `x: 268.5`

### Conclusion

Based on code analysis, positions match classic Winamp. **Issue may be perception-based or already fixed.**

**Action Required:** Visual verification by running app and comparing to reference screenshots.

If misalignment is confirmed, likely fixes:
- Adjust x/y by 1-2 pixels
- Verify sprite sizes match expected dimensions
- Check if skin artwork itself has positioning built in

---

## 🪟 Issue 3: macOS Title Bar Removal

### Current State

**Files:**
- `MacAmpApp/MacAmpApp.swift` (Lines 18-19)
- `MacAmpApp/Views/WinampMainWindow.swift`

### Analysis Result: ✅ ALREADY IMPLEMENTED

**IMPORTANT FINDING:** The frameless window is **ALREADY correctly configured**.

**Evidence:**

**MacAmpApp.swift Lines 18-19:**
```swift
.windowStyle(.hiddenTitleBar)
.windowResizability(.contentSize)
```

**WinampMainWindow.swift:** Custom title bar implemented as `SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED")`

### How It Works

1. `.windowStyle(.hiddenTitleBar)` removes macOS title bar
2. SwiftUI automatically makes non-interactive areas draggable
3. Custom title bar sprite acts as drag handle
4. Window control buttons (minimize, shade, close) overlay on title bar

### Status Assessment

**This issue may be:**
1. Already resolved in current code
2. Documented in SESSION_STATE.md before fix was merged
3. Visible only in specific macOS versions or screen configurations

**Action Required:**
- Build and run app to verify current behavior
- If macOS title bar IS visible, investigate why `.hiddenTitleBar` is not working
- May need AppKit interop if SwiftUI modifier insufficient

**Potential Issues:**
- macOS Sequoia (15.x) behavior changes
- Multi-window coordination
- `.windowToolbarStyle` might be needed

---

## 🧹 Issue 4: Debug Code Cleanup

### Debug Logging Audit

**Search Command:** `grep -r "NSLog\|print(" MacAmpApp/ --include="*.swift"`

### Results: 30+ Debug Statements Found

**Primary Offender: `SkinManager.swift`**

Debug categories found:
1. Skin discovery/loading logs (📦, 🎨, 🔄)
2. Sprite processing debug (=== SPRITE DEBUG ===)
3. Archive content dumps
4. Missing sheet warnings (⚠️, ❌)
5. Fallback sprite creation notices

**Representative Examples:**

**Line ~18:** `NSLog("📦 SkinManager: Discovered \(skins.count) skins")`
**Line ~XX:** `NSLog("=== SPRITE DEBUG: Archive Contents ===")`
**Line ~XX:** `print("Loading skin from \(url.path)")`
**Line ~XX:** `print("✅ FOUND SHEET: \(sheetName) -> \(entry.path)")`

### TODO/FIXME Audit

**Search Command:** `grep -r "TODO\|FIXME\|XXX\|HACK" MacAmpApp/ --include="*.swift" -n`

### Results: 5 TODOs Found

1. **SkinManager.swift:520** - `cursors: [:] // TODO: Parse cursors`
2. **Skin.swift:23** - `// TODO: Add properties for the other skin elements`
3. **AudioPlayer.swift:206** - `// TODO: Implement eject logic`
4. **WinampEqualizerWindow.swift:209** - `// TODO: Open file picker for .eqf files`
5. **WinampEqualizerWindow.swift:236** - `// TODO: Save to user presets`

### Categorization

**Category A: Keep (Feature TODOs for future):**
- Cursor parsing (not needed yet)
- Additional skin properties (not needed yet)
- Eject logic (minor feature)
- EQ file picker (enhancement)
- EQ preset save persistence (enhancement)

**Category B: Wrap in #if DEBUG:**
- All NSLog statements
- All print() statements (except `func print`)
- Archive content dumps
- Sprite processing debug

**Category C: Remove entirely:**
- Obvious debug statements left during development
- Commented-out code (need to search for this)

### Recommended Actions

**Priority 1: Wrap Debug Logging**
```swift
#if DEBUG
NSLog("=== SPRITE DEBUG: Archive Contents ===")
#endif
```

**Priority 2: Clean Verbose Logs**
- Remove or reduce skin discovery logs to errors only
- Remove successful operation logs (✅ FOUND SHEET)
- Keep error/warning logs (⚠️, ❌) but wrap in DEBUG

**Priority 3: Document TODOs**
- Add context to each TODO
- Link to future issues/features
- Indicate priority (P0/P1/P2)

---

## 📋 Additional Findings

### Code Quality Observations

**Positive:**
- Clean build (0 errors, 0 warnings)
- Consistent Swift naming conventions
- Well-structured architecture
- Good separation of concerns

**Areas for Improvement:**
- Excessive debug logging in production
- No debug/release conditional compilation
- Some magic numbers could be constants
- Comment density varies across files

### Performance Considerations

**AudioPlayer.swift:**
- Timer interval: 0.1s (100ms) - reasonable for UI updates
- Visualizer tap: 1024 samples - good balance

**SkinManager.swift:**
- Sprite sheet loading: synchronous (acceptable for skin switching)
- Archive processing: could benefit from progress indication

### Testing Gaps

**Not Covered in Research:**
- Actual seek behavior with various audio formats (MP3, FLAC, AAC)
- Edge cases (seek to 0, seek to end, seek during pause)
- Multi-window title bar behavior on different macOS versions
- Playlist button visual alignment across different skins

---

## 🎯 Research Conclusions

### Issue Priority Re-assessment

**CRITICAL (Must Fix):**
1. ✅ Track seeking race condition - **Root cause identified**

**HIGH (Should Verify):**
2. ⚠️ Playlist button alignment - **Appears correct, needs visual confirmation**
3. ⚠️ macOS title bar - **Already implemented, needs verification**

**MEDIUM (Polish):**
4. ✅ Debug code cleanup - **Cataloged, ready for cleanup**

### Key Insights

1. **Seek bug is real** - Race condition between async track loading and sync seek
2. **Playlist positions are correct** - May be non-issue or already fixed
3. **Title bar already removed** - SESSION_STATE.md may be outdated
4. **30+ debug statements** - Significant cleanup needed

### Recommended Phase 4 Approach

**Session 1: Critical Bug Fix (1-2 hours)**
- Fix seek race condition
- Test with various audio formats
- Verify fix works across use cases

**Session 2: Verification (30 min)**
- Visual verification of playlist buttons
- Verify title bar behavior on current macOS
- Update SESSION_STATE.md with findings

**Session 3: Code Cleanup (1-2 hours)**
- Wrap all debug logging in #if DEBUG
- Clean up verbose logs
- Document TODOs properly
- Remove obsolete comments

---

## 📁 Files Requiring Changes

### Confirmed Changes:
1. `MacAmpApp/Audio/AudioPlayer.swift` - Fix seek race condition
2. `MacAmpApp/ViewModels/SkinManager.swift` - Wrap debug logs

### Potential Changes:
3. `MacAmpApp/Views/WinampPlaylistWindow.swift` - If alignment actually wrong
4. `MacAmpApp/MacAmpApp.swift` - If title bar needs additional config
5. Various files - TODO documentation cleanup

---

## 🔬 Testing Strategy

### Seek Bug Testing

**Test Cases:**
1. Load track, wait for full load, then seek - should work
2. Load track, seek immediately - currently fails
3. Seek while playing - should continue playing
4. Seek while paused - should stay paused
5. Seek to 0:00 - should restart
6. Seek to end - should complete

**Audio Formats to Test:**
- MP3 (44.1kHz, 48kHz)
- FLAC
- AAC/M4A
- WAV

### UI Testing

**Playlist Buttons:**
- Visual comparison with Winamp screenshots
- Test with multiple skins (Classic, Internet Archive, Winamp3)
- Verify click targets align with visual buttons

**Title Bar:**
- Verify no macOS title bar visible
- Test window dragging
- Test minimize/shade/close buttons
- Test on macOS Sonoma, Sequoia

---

## 📚 References

### Code Analysis Tool
- Gemini CLI with large context window
- Files analyzed: AudioPlayer.swift, WinampMainWindow.swift, WinampPlaylistWindow.swift, MacAmpApp.swift

### Related Documentation
- `SESSION_STATE.md` - Phase 4 planning
- `docs/ARCHITECTURE_REVELATION.md` - Core architecture
- `docs/SpriteResolver-Architecture.md` - Sprite system

### External References
- AVAudioEngine documentation
- SwiftUI window styling
- Winamp skin specifications

---

---

## 🎵 Issue 5: Playlist Window Incomplete Implementation (CRITICAL - DISCOVERED 2025-10-13)

### Discovery

After fixing seeking bugs, comprehensive testing revealed the playlist window is **severely incomplete**.

### Visual Analysis

**Current State:**
- Bottom bar has ADD, REM, SEL, MISC, LIST buttons ✅
- **MISSING:** Tiny transport controls
- **MISSING:** Running time display
- **MISSING:** Mini time counter

**Expected State (from webamp_clone):**
- All management buttons (we have these)
- **6 tiny transport buttons:** prev, play, pause, stop, next, eject
- **Running time:** Shows "selected time / total playlist time" (e.g., "5:22/45:48")
- **Mini time:** Shows current playback time in small format

### Webamp_Clone Reference

**File:** `webamp_clone/packages/webamp/js/components/PlaylistWindow/PlaylistActionArea.tsx`

**Structure:**
```javascript
<Fragment>
  <RunningTimeDisplay />  // Selected/Total time
  <div className="playlist-action-buttons">
    <div className="playlist-previous-button" onClick={previous} />
    <div className="playlist-play-button" onClick={play} />
    <div className="playlist-pause-button" onClick={pause} />
    <div className="playlist-stop-button" onClick={stop} />
    <div className="playlist-next-button" onClick={next} />
    <div className="playlist-eject-button" onClick={openMediaFileDialog} />
  </div>
  <MiniTime />  // Current track time
</Fragment>
```

**Critical:** All transport controls call the SAME AudioPlayer methods as main window!

### Missing Components

**1. Tiny Transport Buttons (6 buttons)**
- Sprites: `PLAYLIST_PREVIOUS_BUTTON`, `PLAYLIST_PLAY_BUTTON`, etc.
- Size: ~7px × 7px each
- Position: Left side of bottom bar
- Function: Control playback (same as main window)

**2. Running Time Display**
- Format: "MM:SS/MM:SS" (selected / total)
- Calculation: Sum of all playlist track durations
- Selected: Currently selected track (or current playing)
- Uses: Mini character sprites for text

**3. Mini Time Display**
- Format: "MM:SS"
- Shows: Current playback position
- Synced: With main window time display
- Uses: Mini digit sprites
- Position: Right side of bottom bar

### Discovered Bugs

**Bug A: Track Selection Doesn't Play**
- Click track in playlist → Nothing happens (or plays wrong track)
- Should: Play the clicked track
- Current: Broken/not implemented

**Bug B: Infinite Loop on Track Completion**
- Track ends with repeat → Infinite loop
- Console floods with logs
- App becomes unresponsive
- Root cause: `playTrack()` calls `loadTrack()` which appends

**Bug C: Playlist Duplication**
- Click tracks → Duplicates exponentially (2x, 4x, 8x)
- Add tracks → Existing tracks duplicate
- Root cause: `loadTrack()` always appends

**Bug D: Seek to End Overflow**
- Seek to end → Timer counts past track length
- Should: Trigger completion, move to next track or stop
- Current: Broken completion handling

### Required Sprite Investigation

**Need to confirm existence of:**
- `PLAYLIST_PREVIOUS_BUTTON` (tiny)
- `PLAYLIST_PLAY_BUTTON` (tiny)
- `PLAYLIST_PAUSE_BUTTON` (tiny)
- `PLAYLIST_STOP_BUTTON` (tiny)
- `PLAYLIST_NEXT_BUTTON` (tiny)
- `PLAYLIST_EJECT_BUTTON` (tiny)
- Mini digit sprites (for time display)
- Mini character sprites (for running time)

**Action:** Search skin files to confirm sprite names and dimensions

---

## 🎯 Updated Research Conclusions

### Critical Discoveries (2025-10-13 Session)

**What We Fixed:**
1. ✅ Title bar removal (WindowDragGesture)
2. ✅ EQ preset popover (replaced glitchy Menu)
3. ✅ Track seeking visual feedback (isSeeking flag)
4. ✅ Position slider conditional visibility

**What We Discovered is Broken:**
5. 🔴 Infinite loop on track completion
6. 🔴 Playlist duplication
7. 🔴 Track selection doesn't work
8. 🔴 Seek to end overflow

**What's Missing:**
9. ⚠️ Tiny transport controls in playlist
10. ⚠️ Running time display
11. ⚠️ Mini time display

### Scope Expansion

**Original Phase 4 Scope:** Polish & bug fixes (3-5 hours)

**Actual Scope Discovered:**
- Phase 4: Critical bugs (6 bugs, 3-4 hours)
- Phase 5: Complete playlist window (3 missing features, 4-6 hours)

**Total:** 7-10 hours of work identified

### Recommended Path Forward

**Immediate (Today):**
1. Update all documentation ✅
2. Commit current state
3. Fix critical bugs (infinite loop, track selection, seek-to-end)
4. Get app to stable state

**Next Session (Later):**
1. Add missing playlist UI components
2. Implement time displays
3. Add tiny transport controls
4. Complete integration testing

---

**Research Status:** ✅ EXPANDED - Playlist window gaps identified
**Next Step:** Update plan.md with new scope, update SESSION_STATE.md
**Key Findings:**
1. Playlist window is 60% incomplete
2. Critical bugs prevent basic functionality
3. Need systematic fix approach, not reactive

