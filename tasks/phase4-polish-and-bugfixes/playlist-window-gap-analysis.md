# Playlist Window - Gap Analysis & Implementation Plan

**Date:** 2025-10-13
**Status:** 🔴 CRITICAL - Multiple bugs discovered
**Priority:** Must plan before implementing

---

## 🎯 Step Back & Assessment

We've been fixing bugs reactively. We need to **stop, analyze, and plan** the complete playlist window implementation.

---

## 📸 Visual Comparison

### Current State (MacAmp)
![Current](Screenshot 2025-10-13 at 3.31.20 PM.png)

**Bottom Bar Contains:**
- ✅ ADD button (adds files)
- ✅ REM button (remove selected)
- ✅ SEL button (selection management)
- ✅ MISC button (misc options)
- ✅ LIST button (list management)
- ❌ NO transport controls
- ❌ NO time display

### Expected State (Webamp Reference)
![Expected](Screenshot 2025-10-13 at 3.33.25 PM.png)

**Bottom Bar Should Contain:**
- ✅ Playlist management buttons (ADD, REM, SEL, MISC, LIST) - we have these
- ❌ **Tiny transport controls** (prev, play, pause, stop, next, eject) - MISSING!
- ❌ **Running time display** ("selected time / total playlist time") - MISSING!
- ❌ **Mini time display** (current track time in mini format) - MISSING!

---

## 🔍 Webamp_Clone Analysis

### File Structure

**Playlist Action Area:** `PlaylistActionArea.tsx`

Components used:
1. `<RunningTimeDisplay />` - Shows "5:22/45:48" format
2. Tiny transport buttons:
   - `playlist-previous-button`
   - `playlist-play-button`
   - `playlist-pause-button`
   - `playlist-stop-button`
   - `playlist-next-button`
   - `playlist-eject-button`
3. `<MiniTime />` - Shows current track time

**Key Insight:** These controls call the SAME actions as main window!
```javascript
const play = useActionCreator(Actions.play);  // Same as main window
const pause = useActionCreator(Actions.pause);
const stop = useActionCreator(Actions.stop);
```

---

## 🐛 Current Bugs Identified

### Bug 1: Infinite Loop on Track End (CRITICAL)
- **Status:** Attempted fix with re-entrancy guard
- **Cause:** `playTrack()` → `stop()` → triggers completions
- **Impact:** App unusable with repeat mode
- **Needs:** Proper playback completion handling

### Bug 2: Playlist Duplication (CRITICAL)
- **Status:** Partially fixed with `addTrack()` refactor
- **Cause:** Multiple code paths adding same track
- **Impact:** Playlist grows exponentially
- **Needs:** Complete track management refactor

### Bug 3: Clicking Playlist Track Doesn't Play (HIGH)
- **Status:** Reported by user
- **Cause:** Track selection doesn't trigger playback
- **Impact:** Can't select different tracks
- **Needs:** Proper track selection handling

### Bug 4: Missing Transport Controls (HIGH)
- **Status:** Not implemented
- **Cause:** Playlist window incomplete
- **Impact:** No playlist-level playback control
- **Needs:** Add tiny transport buttons

### Bug 5: Missing Time Displays (MEDIUM)
- **Status:** Not implemented
- **Cause:** Playlist window incomplete
- **Impact:** No time information in playlist
- **Needs:** Add RunningTimeDisplay and MiniTime

### Bug 6: Seek to End Issues (HIGH)
- **Status:** Partially addressed
- **Cause:** Completion logic not handling all cases
- **Impact:** Timer counts past track length
- **Needs:** Proper end-of-track handling

---

## 📋 Missing Playlist Features

### Bottom Bar Components (Missing)

**1. Tiny Transport Controls**
- Previous button (◀◀) - 7px × 7px
- Play button (▶) - 7px × 7px
- Pause button (||) - 7px × 7px
- Stop button (■) - 7px × 7px
- Next button (▶▶) - 7px × 7px
- Eject button (⏏) - 7px × 7px

**Position:** Left side of bottom bar
**Sprites:** `PLAYLIST_*_BUTTON` (tiny versions)
**Function:** Control playback from playlist window

**2. Running Time Display**
- Format: "MM:SS/MM:SS" (selected / total)
- Example: "5:22/45:48"
- Shows: Currently selected track time / Total playlist time
- Position: Center-left of bottom bar
- Uses: Mini character sprites

**3. Mini Time Display**
- Format: "MM:SS"
- Example: "5:22"
- Shows: Current playback position
- Position: Right side of bottom bar
- Uses: Mini digit sprites
- **Synced with main window time display**

---

## 🏗️ Architecture Issues

### Current Problems

**1. Tight Coupling**
- Main window has its own time display
- Playlist should share state, not duplicate

**2. Incomplete State Management**
- No "selected track" concept
- No "total playlist time" calculation
- No mini time rendering

**3. Missing Sprite Definitions**
- Need tiny transport button sprites
- Need mini digit sprites
- Need mini character sprites

---

## 📐 Implementation Plan (DRAFT)

### Phase A: Stop the Bleeding (IMMEDIATE)
**Goal:** Fix critical bugs preventing basic use

**Tasks:**
1. ✅ Add re-entrancy guard to `onPlaybackEnded()` (DONE)
2. ⏸️ Fix `playTrack()` to not trigger infinite loop
3. ⏸️ Fix track selection in playlist to actually play clicked track
4. ⏸️ Prevent seek-to-end from counting past track length

**Estimated Time:** 2-3 hours
**Blocker:** Must fix before adding new features

### Phase B: Complete Playlist Bottom Bar (NEXT)
**Goal:** Add all missing UI components

**Tasks:**
1. Add tiny transport controls (6 buttons)
2. Add running time display (selected/total)
3. Add mini time display (current time)
4. Wire all controls to AudioPlayer
5. Ensure synchronization with main window

**Estimated Time:** 4-6 hours
**Dependencies:** Phase A must be complete

### Phase C: Polish & Integration (LATER)
**Goal:** Make everything work together

**Tasks:**
1. Ensure track selection works
2. Ensure playlist operations work
3. Test repeat/shuffle modes
4. Visual polish

**Estimated Time:** 2-3 hours

---

## 🎯 Recommended Approach

### Option 1: Fix Critical Bugs First ⭐ RECOMMENDED
1. **Today:** Fix infinite loop + track selection
2. **Tomorrow:** Add missing playlist UI components
3. **Later:** Polish and test

**Pros:**
- Get to stable state quickly
- Can use app while building features
- Incremental progress

**Cons:**
- Still incomplete playlist window
- Need another session

### Option 2: Complete Refactor Now
1. **Today:** Fix ALL bugs + add ALL features
2. Full playlist window implementation

**Pros:**
- Complete solution
- No half-done state

**Cons:**
- 6-8 hour session
- High risk of introducing new bugs
- Fatigue

---

## 🚨 My Recommendation

### STOP AND PLAN

**What We Should Do NOW:**

1. **Document all bugs** in a tracking file ✅ (this file)
2. **Create detailed implementation plan** for playlist window
3. **Prioritize critical fixes** vs feature additions
4. **Get approval** before coding
5. **Commit current working state** (title bar, EQ, seeking basics)
6. **Create new branch** for playlist fixes

**Why This Approach:**

- ✅ Prevents more reactive bug-fixing
- ✅ Ensures we understand complete scope
- ✅ Allows proper time estimation
- ✅ Preserves working features
- ✅ Systematic vs. chaotic

---

## 📊 Scope Assessment

### What Works ✅
- Main window playback controls
- Volume/balance sliders
- EQ with popover presets
- Time display in main window
- Spectrum visualizer
- Skin switching
- Title bar dragging

### What's Broken 🔴
- Playlist track selection
- Repeat mode (infinite loop)
- Seek to end (timer overflow)
- Track completion logic

### What's Missing 🟡
- Playlist transport controls
- Playlist time displays
- Proper track management
- Playlist UI sprites

---

## 🎯 Proposed Next Steps

**Step 1: Immediate (Today - 30 min)**
- Create comprehensive playlist implementation plan
- Document ALL missing features
- Estimate time for complete implementation
- Get user approval on approach

**Step 2: Critical Bug Fix (Today - 2 hours)**
- Fix infinite loop completely
- Fix track selection
- Fix seek-to-end properly
- Commit as "Phase 4.5 - Critical Playlist Fixes"

**Step 3: Feature Implementation (Next Session - 4-6 hours)**
- Add all missing playlist UI components
- Implement time displays
- Add tiny transport controls
- Full integration testing
- Commit as "Phase 5 - Complete Playlist Window"

---

## 📝 Questions for User

1. **Priority:** Fix bugs first, or complete playlist window in one go?
2. **Timeline:** Can we split this into two sessions?
3. **Scope:** Should we aim for pixel-perfect webamp parity?
4. **Testing:** Do you want to test each fix, or wait for complete implementation?

---

**Status:** 🛑 PAUSED FOR PLANNING
**Next Action:** Get user input on approach
**Estimated Total Work:** 6-8 hours for complete playlist window
