# Complete Hardcoded Sprite Inventory

**Generated:** 2025-10-13
**Total Hardcoded Sprites:** 72 references across 5 files
**Purpose:** Track all sprites that may need semantic migration

---

## 📊 Summary by File

| File | Hardcoded Sprites | Semantic Sprites |
|------|-------------------|------------------|
| WinampMainWindow.swift | 23 | 5 (digits + minus) |
| WinampEqualizerWindow.swift | 14 | 0 |
| WinampPlaylistWindow.swift | 18 | 0 |
| SimpleTestMainWindow.swift | 14 | 0 |
| SimpleSpriteImage.swift | 3 (examples/tests) | 0 |
| **TOTAL** | **72** | **5** |

---

## 🗂️ Categorized Hardcoded Sprite Inventory

### 1. MAIN WINDOW (WinampMainWindow.swift) - 23 sprites

#### Window Structure (3):
```
Line 76:  MAIN_WINDOW_BACKGROUND
Line 81:  MAIN_TITLE_BAR_SELECTED
Line 170: MAIN_SHADE_BACKGROUND
```

#### Transport Buttons - Normal Mode (6):
```
Line 177: MAIN_PREVIOUS_BUTTON
Line 184: MAIN_PLAY_BUTTON
Line 191: MAIN_PAUSE_BUTTON
Line 198: MAIN_STOP_BUTTON
Line 205: MAIN_NEXT_BUTTON
Line 375: MAIN_EJECT_BUTTON
```

#### Transport Buttons - Shade Mode (5):
```
Line 338: MAIN_PREVIOUS_BUTTON
Line 345: MAIN_PLAY_BUTTON
Line 352: MAIN_PAUSE_BUTTON
Line 359: MAIN_STOP_BUTTON
Line 366: MAIN_NEXT_BUTTON
```

#### Window Control Buttons (3):
```
Line 229: MAIN_MINIMIZE_BUTTON
Line 238: MAIN_SHADE_BUTTON
Line 247: MAIN_CLOSE_BUTTON
```

#### Slider Elements (2):
```
Line 411: MAIN_POSITION_SLIDER_BACKGROUND
Line 416: MAIN_POSITION_SLIDER_THUMB
```

#### Feature Buttons (2):
```
Line 459: MAIN_EQ_BUTTON
Line 468: MAIN_PLAYLIST_BUTTON
```

#### Dynamic Characters (2 patterns):
```
Line 524: CHARACTER_\(charCode)     // Track title scrolling text
Line 556: CHARACTER_\(ascii)        // Bitrate display
Line 573: CHARACTER_\(ascii)        // Sample rate display
```

**Notes:**
- Transport buttons duplicated in normal + shade modes (expected)
- All follow MAIN_* naming convention
- Character sprites generated dynamically

---

### 2. EQUALIZER WINDOW (WinampEqualizerWindow.swift) - 14 sprites

#### Window Structure (2):
```
Line 47: EQ_WINDOW_BACKGROUND
Line 52: EQ_TITLE_BAR_SELECTED
```

#### Window Control Buttons (3):
```
Line 94:  MAIN_MINIMIZE_BUTTON
Line 103: MAIN_SHADE_BUTTON
Line 112: MAIN_CLOSE_BUTTON
```

#### Feature Buttons (1):
```
Line 213: EQ_PRESETS_BUTTON
```

#### Shade Mode Window (1):
```
Line 248: EQ_SHADE_BACKGROUND
```

#### Shade Mode Sliders (6):
```
Line 254: EQ_SHADE_VOLUME_SLIDER_LEFT
Line 255: EQ_SHADE_VOLUME_SLIDER_CENTER
Line 256: EQ_SHADE_VOLUME_SLIDER_RIGHT
Line 262: EQ_SHADE_BALANCE_SLIDER_LEFT
Line 263: EQ_SHADE_BALANCE_SLIDER_CENTER
Line 264: EQ_SHADE_BALANCE_SLIDER_RIGHT
```

#### Graph Elements (1):
```
Line 276: EQ_GRAPH_BACKGROUND
```

**Notes:**
- Reuses MAIN_*_BUTTON for window controls (intentional)
- EQ-specific sprites use EQ_* prefix
- Shade mode sliders broken into LEFT/CENTER/RIGHT parts

---

### 3. PLAYLIST WINDOW (WinampPlaylistWindow.swift) - 18 sprites

#### Window Structure - Top (4):
```
Line 44: PLAYLIST_TOP_LEFT_CORNER
Line 49: PLAYLIST_TOP_TILE
Line 54: PLAYLIST_TITLE_BAR
Line 57: PLAYLIST_TOP_RIGHT_CORNER
```

#### Window Structure - Sides (2):
```
Line 64: PLAYLIST_LEFT_TILE
Line 70: PLAYLIST_RIGHT_TILE
```

#### Window Structure - Bottom (2):
```
Line 75: PLAYLIST_BOTTOM_LEFT_CORNER
Line 78: PLAYLIST_BOTTOM_RIGHT_CORNER
```

#### Window Control Buttons (3):
```
Line 209: MAIN_MINIMIZE_BUTTON
Line 217: MAIN_SHADE_BUTTON
Line 223: MAIN_CLOSE_BUTTON
```

#### Playlist Controls (6):
```
Line 116: PLAYLIST_SCROLL_HANDLE
Line 169: PLAYLIST_ADD_FILE
Line 176: PLAYLIST_REMOVE_SELECTED
Line 183: PLAYLIST_CROP
Line 190: PLAYLIST_MISC_OPTIONS
Line 197: PLAYLIST_SORT_LIST
```

#### Shade Mode (1):
```
Line 236: PLAYLIST_TITLE_BAR
```

**Notes:**
- Extensive window chrome sprites (expected for playlist)
- Reuses MAIN_*_BUTTON for window controls
- PLAYLIST_* sprites are playlist-specific

---

### 4. TEST WINDOW (SimpleTestMainWindow.swift) - 14 sprites

**Note:** This is a test/development file, may not be used in production

#### Window Structure (1):
```
Line 13: MAIN_WINDOW_BACKGROUND
```

#### Test Digits (4):
```
Line 29: DIGIT_0
Line 30: DIGIT_1
Line 31: DIGIT_2
Line 32: DIGIT_3
```

#### Transport Buttons (5):
```
Line 42: MAIN_PREVIOUS_BUTTON
Line 47: MAIN_PLAY_BUTTON
Line 52: MAIN_PAUSE_BUTTON
Line 57: MAIN_STOP_BUTTON
Line 62: MAIN_NEXT_BUTTON
```

#### Window Control Buttons (3):
```
Line 73: MAIN_MINIMIZE_BUTTON
Line 74: MAIN_SHADE_BUTTON
Line 75: MAIN_CLOSE_BUTTON
```

**Notes:**
- Test file uses old hardcoded digit approach (not semantic)
- Should be updated to use .digit() for consistency
- Low priority (test file only)

---

### 5. COMPONENT LIBRARY (SimpleSpriteImage.swift) - 3 sprites

**Documentation Examples Only:**
```
Line 22:  DIGIT_0        // Comment example
Line 110: DIGIT_0        // Preview example
Line 111: MISSING_SPRITE // Preview example
```

**Notes:**
- These are in comments/previews, not production code
- No actual hardcoded production usage in this file

---

## 🎨 Sprite Sheet Distribution

### By Source Sprite Sheet:

**CBUTTONS.bmp (6 unique sprites):**
- MAIN_PREVIOUS_BUTTON
- MAIN_PLAY_BUTTON
- MAIN_PAUSE_BUTTON
- MAIN_STOP_BUTTON
- MAIN_NEXT_BUTTON
- MAIN_EJECT_BUTTON

**SHUFREP.bmp (4 unique sprites):**
- MAIN_SHUFFLE_BUTTON (+ _SELECTED variant)
- MAIN_REPEAT_BUTTON (+ _SELECTED variant)
- MAIN_EQ_BUTTON
- MAIN_PLAYLIST_BUTTON

**TITLEBAR.bmp (3 unique sprites):**
- MAIN_MINIMIZE_BUTTON
- MAIN_SHADE_BUTTON
- MAIN_CLOSE_BUTTON

**MAIN.bmp (3 unique sprites):**
- MAIN_WINDOW_BACKGROUND
- MAIN_TITLE_BAR_SELECTED
- MAIN_SHADE_BACKGROUND

**POSBAR.bmp (2 unique sprites):**
- MAIN_POSITION_SLIDER_BACKGROUND
- MAIN_POSITION_SLIDER_THUMB

**MONOSTER.bmp (2 unique sprites):**
- MAIN_MONO (+ _SELECTED variant)
- MAIN_STEREO (+ _SELECTED variant)

**PLAYPAUS.bmp (3 unique sprites):**
- MAIN_PLAYING_INDICATOR
- MAIN_PAUSED_INDICATOR
- MAIN_STOPPED_INDICATOR

**EQMAIN.bmp (4 unique sprites):**
- EQ_WINDOW_BACKGROUND
- EQ_TITLE_BAR_SELECTED
- EQ_GRAPH_BACKGROUND
- EQ_SHADE_BACKGROUND

**EQ_EX.bmp (6 unique sprites):**
- EQ_SHADE_VOLUME_SLIDER_LEFT
- EQ_SHADE_VOLUME_SLIDER_CENTER
- EQ_SHADE_VOLUME_SLIDER_RIGHT
- EQ_SHADE_BALANCE_SLIDER_LEFT
- EQ_SHADE_BALANCE_SLIDER_CENTER
- EQ_SHADE_BALANCE_SLIDER_RIGHT

**PLEDIT.bmp (12 unique sprites):**
- PLAYLIST_TOP_LEFT_CORNER
- PLAYLIST_TOP_TILE
- PLAYLIST_TITLE_BAR
- PLAYLIST_TOP_RIGHT_CORNER
- PLAYLIST_LEFT_TILE
- PLAYLIST_RIGHT_TILE
- PLAYLIST_BOTTOM_LEFT_CORNER
- PLAYLIST_BOTTOM_RIGHT_CORNER
- PLAYLIST_SCROLL_HANDLE
- PLAYLIST_ADD_FILE
- PLAYLIST_REMOVE_SELECTED
- PLAYLIST_CROP
- PLAYLIST_MISC_OPTIONS
- PLAYLIST_SORT_LIST

**TEXT.bmp (dynamic):**
- CHARACTER_[ASCII_CODE] (generated at runtime)

**NUMBERS.bmp / NUMS_EX.bmp:**
- **Already using semantic sprites!** ✅
- .digit(0-9), .minusSign

---

## 🔍 Variant Analysis

### Sprites with KNOWN Variants:

**NUMBERS → NUMS_EX (Already Handled via Semantic):**
- DIGIT_0 ↔ DIGIT_0_EX ✅ Resolved via .digit(0)
- DIGIT_1 ↔ DIGIT_1_EX ✅ Resolved via .digit(1)
- ... (0-9)
- MINUS_SIGN ↔ MINUS_SIGN_EX ✅ Resolved via .minusSign

**Total Known Variants:** 12 (all digits, all handled)

### Sprites WITHOUT Known Variants:

**Searched Entire Codebase:**
- MAIN_PLAY_BUTTON_EX → NOT FOUND
- MAIN_PAUSE_BUTTON_EX → NOT FOUND
- EQ_WINDOW_BACKGROUND_EX → NOT FOUND
- PLAYLIST_TITLE_BAR_EX → NOT FOUND

**Conclusion:** No button/window/indicator variants exist in codebase

**Implication:** Hardcoded names likely match Winamp standard spec

---

## 📋 Migration Candidates (If Phase 4 Proceeds)

### HIGH PRIORITY (If variants found in testing):

**Transport Buttons (6):**
- MAIN_PREVIOUS_BUTTON → .previousButton
- MAIN_PLAY_BUTTON → .playButton
- MAIN_PAUSE_BUTTON → .pauseButton
- MAIN_STOP_BUTTON → .stopButton
- MAIN_NEXT_BUTTON → .nextButton
- MAIN_EJECT_BUTTON → .ejectButton

**Files Affected:** WinampMainWindow.swift (lines 177-375)

### MEDIUM PRIORITY:

**Indicators (3):**
- MAIN_PLAYING_INDICATOR → .playingIndicator
- MAIN_PAUSED_INDICATOR → .pausedIndicator
- MAIN_STOPPED_INDICATOR → .stoppedIndicator

**Mono/Stereo (2):**
- MAIN_MONO → .monoIndicator
- MAIN_STEREO → .stereoIndicator

### LOW PRIORITY (Unlikely to have variants):

**Window Controls (3):**
- MAIN_MINIMIZE_BUTTON
- MAIN_SHADE_BUTTON
- MAIN_CLOSE_BUTTON

**Window Backgrounds (5):**
- MAIN_WINDOW_BACKGROUND
- MAIN_TITLE_BAR_SELECTED
- EQ_WINDOW_BACKGROUND
- EQ_TITLE_BAR_SELECTED
- PLAYLIST_TITLE_BAR

**Reason:** These are structural elements, unlikely to have variants

### SHOULD MIGRATE (Recommended for Minimal Phase 4):

**Dynamic Characters:**
```
Current: SimpleSpriteImage("CHARACTER_\(ascii)")
Target:  SimpleSpriteImage(.character(ascii))
```

**Reason:** Needs fallback handling for missing characters

**Files Affected:**
- WinampMainWindow.swift (lines 524, 556, 573)

---

## 🎯 Migration Effort Estimate

### FULL Phase 4 (Migrate Everything):

**Scope:** All 72 hardcoded sprites
**Files:** 5 Swift files
**Estimated Time:** 4-6 hours
**Complexity:** Medium
**Risk:** Low (backward compatible approach)

**Tasks:**
1. Add all sprite types to SemanticSprite enum (1 hour)
2. Update SpriteResolver with resolution logic (1 hour)
3. Migrate all 72 references (2-3 hours)
4. Test across all skins (1 hour)

### MINIMAL Phase 4 (Only Characters + Fallbacks):

**Scope:** 3 dynamic character references + fallback rendering
**Files:** 2 Swift files (WinampMainWindow, SimpleSpriteImage)
**Estimated Time:** 2-3 hours
**Complexity:** Low
**Risk:** Very low

**Tasks:**
1. Add .character(Int) to SemanticSprite enum (30 min)
2. Add character resolution to SpriteResolver (30 min)
3. Migrate CHARACTER_\(ascii) references (30 min)
4. Add missing sprite fallback rendering (1 hour)
5. Test character display (30 min)

---

## 🚨 Critical Sprites (Must Work)

### Cannot Be Broken:

**Playback Controls (6):**
- MAIN_PLAY_BUTTON ⭐ CRITICAL
- MAIN_PAUSE_BUTTON ⭐ CRITICAL
- MAIN_STOP_BUTTON ⭐ CRITICAL
- MAIN_PREVIOUS_BUTTON
- MAIN_NEXT_BUTTON
- MAIN_EJECT_BUTTON

**Window Controls (3):**
- MAIN_CLOSE_BUTTON ⭐ CRITICAL
- MAIN_MINIMIZE_BUTTON
- MAIN_SHADE_BUTTON

**Window Backgrounds (2):**
- MAIN_WINDOW_BACKGROUND ⭐ CRITICAL
- EQ_WINDOW_BACKGROUND ⭐ CRITICAL

**If ANY of these fail in testing → Phase 4 becomes mandatory**

---

## 📊 Sprite Reuse Analysis

### Sprites Used in Multiple Windows:

**Window Control Buttons (Reused 3x):**
- MAIN_MINIMIZE_BUTTON: Main, EQ, Playlist windows
- MAIN_SHADE_BUTTON: Main, EQ, Playlist windows
- MAIN_CLOSE_BUTTON: Main, EQ, Playlist windows

**Implication:** If migration needed, affects 3 windows per sprite

**Benefits of Semantic:**
- Single point of resolution
- Consistent behavior across windows
- Easier to maintain

---

## 🎯 Testing Priority Matrix

### Must Test in ALL 10 Skins:

**Priority 1 (CRITICAL):**
1. ⭐ MAIN_PLAY_BUTTON - Must work
2. ⭐ MAIN_PAUSE_BUTTON - Must work
3. ⭐ MAIN_STOP_BUTTON - Must work
4. ⭐ MAIN_WINDOW_BACKGROUND - Must render
5. ⭐ MAIN_CLOSE_BUTTON - Must work

**Priority 2 (HIGH):**
6. MAIN_PREVIOUS_BUTTON
7. MAIN_NEXT_BUTTON
8. MAIN_EJECT_BUTTON
9. MAIN_SHUFFLE_BUTTON
10. MAIN_REPEAT_BUTTON

**Priority 3 (MEDIUM):**
11. EQ_WINDOW_BACKGROUND
12. PLAYLIST_TITLE_BAR
13. Volume/Balance/EQ sliders
14. Character display (bitrate, sample rate)

**Priority 4 (LOW):**
15. Shade mode sprites
16. Playlist button sprites
17. Decorative elements

---

## 📝 Notes for Testing

### What to Watch For:

**WORKS:** Button appears, responds to clicks, shows correct state
**BROKEN:** Button invisible, doesn't respond, wrong sprite shown
**PARTIAL:** Button works but visual issues (wrong size, position, etc.)

### Console Errors to Check:

```bash
# Launch MacAmp and check console for:
grep -i "sprite" console.log
grep -i "missing" console.log
grep -i "not found" console.log
```

**Expected:** No errors if sprites are standardized
**Red Flag:** Multiple "sprite not found" errors

### Sprite Name Variants to Look For:

If you see errors like:
```
Could not find sprite: MAIN_PLAY_BUTTON
Available sprites: MAIN_PLAY_BUTTON_CLASSIC, ...
```

**This means:** Variants exist, Phase 4 needed

---

## 🎯 Decision Criteria

### SKIP Phase 4 IF:
- ✅ 10/10 skins: All critical sprites work
- ✅ No console sprite errors
- ✅ No variant sprite names discovered
- ✅ Only known variants are digits (already handled)

### MINIMAL Phase 4 IF:
- ⚠️ 8-9/10 skins work
- ⚠️ Minor character display issues
- ⚠️ Some non-critical sprites missing
- ⚠️ Easy fixes available

### FULL Phase 4 IF:
- ❌ <8/10 skins work
- ❌ Critical buttons broken in some skins
- ❌ Multiple sprite name variants found
- ❌ Widespread compatibility issues

---

## 📁 File References for Migration

### If Phase 4 Needed:

**Primary Files to Modify:**
1. `MacAmpApp/Models/SpriteResolver.swift` - Add new semantic sprite cases
2. `MacAmpApp/Views/WinampMainWindow.swift` - Migrate 23 sprites
3. `MacAmpApp/Views/WinampEqualizerWindow.swift` - Migrate 14 sprites
4. `MacAmpApp/Views/WinampPlaylistWindow.swift` - Migrate 18 sprites
5. `MacAmpApp/Views/Components/SimpleSpriteImage.swift` - Add fallback rendering

**Supporting Changes:**
- Update tests
- Update documentation
- Remove sprite aliasing (already done!)

---

## 🔬 Comparison: Semantic vs Hardcoded

### Current Approach (Hardcoded):

**Pros:**
- ✅ Simple, direct
- ✅ Works perfectly with all 3 test skins
- ✅ Matches Winamp spec literally
- ✅ Easy to understand
- ✅ No abstraction overhead

**Cons:**
- ❌ Breaks if skin uses variant names (unknown if this happens)
- ❌ No fallback if sprite missing
- ❌ String literals (typo-prone, though none found)

### Phase 4 Approach (Semantic):

**Pros:**
- ✅ Handles sprite variants automatically
- ✅ Type-safe (autocomplete, no typos)
- ✅ Centralized sprite knowledge
- ✅ Graceful fallbacks possible
- ✅ Future-proof

**Cons:**
- ❌ More complex codebase
- ❌ Additional abstraction layer
- ❌ Only valuable if variants actually exist
- ❌ 4-6 hours effort

---

## 📊 Recommendation

### Based on Codebase Analysis:

**Current State:** EXCELLENT
- Highly consistent
- Well-structured
- Follows Winamp spec
- Works perfectly

**Phase 4 Necessity:** UNCLEAR (pending user testing)

**Most Likely Outcome:** NOT NEEDED
- Button sprites appear standardized
- All test skins work
- No evidence of variants (except digits, handled)

**Conservative Approach:** MINIMAL Phase 4
- Add character sprite fallback
- Add missing sprite placeholder
- Skip button migration unless testing shows issues

---

## 🎯 Next Steps

**User Action Required:**
1. Download 5-10 diverse skins from https://skins.webamp.org/
2. Test each skin thoroughly
3. Report results using provided template
4. Note any sprite errors or missing elements

**After User Reports:**
1. Analyze findings
2. Make go/no-go decision on Phase 4
3. Create implementation plan if needed
4. Update SESSION_STATE.md with decision

---

**Status:** Investigation Complete, Awaiting User Testing
**Decision:** Data-driven based on real-world skin compatibility
**Prepared For:** Any outcome (skip, minimal, or full Phase 4)
