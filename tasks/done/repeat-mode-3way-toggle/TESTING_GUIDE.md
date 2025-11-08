# Testing Guide - Three-State Repeat Mode (Winamp 5 Fidelity)

**App Status:** ✅ Running
**Build:** Debug with Thread Sanitizer
**Branch:** `repeat-mode-toggle`

---

## Quick Test (5 minutes)

### 1. Visual Test - Button Cycling

1. **Click the repeat button** (next to shuffle button, bottom-left)
2. **Verify cycling:**
   - Click 1: OFF → ALL (button lights up, no badge)
   - Click 2: ALL → ONE (button stays lit, white "1" badge appears)
   - Click 3: ONE → OFF (button dims, badge disappears)
   - Click 4: Cycles back to ALL

**Expected:** Matches Winamp 5 Modern behavior exactly

### 2. Badge Visibility Test

**With repeat mode set to ONE:**
- **Look for white "1" character on repeat button**
- Should be centered in button
- Should have subtle dark shadow/halo
- Should be easily readable

**Expected:** Badge clearly visible

### 3. Keyboard Shortcut Test

1. **Press Ctrl+R** several times
2. **Watch repeat button** change state
3. **Verify menu label** in Windows menu updates

**Expected:** Ctrl+R cycles modes (Off → All → One → Off)

### 4. Options Menu Test

1. **Press Ctrl+O** (or click O button)
2. **Look for repeat options** in menu
3. **Should see:** Three options with checkmark next to active mode
   - Repeat: Off ✓
   - Repeat: All
   - Repeat: One

**Expected:** Menu shows current mode, clicking changes it

---

## Comprehensive Test (15-20 minutes)

### Cross-Skin Badge Test

**Test "1" badge legibility on all skins:**

1. **Classic Winamp** (Cmd+Shift+1)
   - Set repeat to One mode
   - Badge should be visible on green button
   - Rate: Excellent / Good / Poor / Invisible

2. **Internet Archive** (Cmd+Shift+2)
   - Set repeat to One mode
   - Badge should be visible on beige button
   - Shadow should provide contrast
   - Rate: Excellent / Good / Poor / Invisible

3. **Tron Vaporwave** (Cmd+Shift+3)
   - Dark blue button
   - Badge should be very visible
   - Rate: Excellent / Good / Poor / Invisible

4. **Mac OS X** (Cmd+Shift+4)
   - Light gray button
   - Shadow critical for visibility
   - Rate: Excellent / Good / Poor / Invisible

5. **Sony MP3** (Cmd+Shift+5)
   - Silver/white button (WORST CASE)
   - Shadow should make badge legible
   - Rate: Excellent / Good / Poor / Invisible
   - **If invisible:** See "Fixes" section below

6. **KenWood** (Cmd+Shift+6)
   - Black button
   - Badge should be perfect
   - Rate: Excellent / Good / Poor / Invisible

7. **Winamp3 Classified** (Cmd+Shift+7)
   - Dark blue button
   - Badge should be very visible
   - Rate: Excellent / Good / Poor / Invisible

**Pass Criteria:** Minimum "Good" rating on all skins

### Playlist Navigation Test

**Setup:** Create playlist with 5 tracks (drag MP3 files)

**Test Off Mode:**
1. Set repeat to Off (button unlit)
2. Play to track 5
3. Press Next button
4. **Expected:** Playback stops (no track 6)

**Test All Mode:**
1. Set repeat to All (button lit, no badge)
2. Play to track 5
3. Press Next button
4. **Expected:** Jumps to track 1 (wraps around)

**Test One Mode:**
1. Set repeat to One (button lit + "1" badge)
2. Start track 3
3. Press Next button
4. **Expected:** Track 3 restarts from 0:00
5. Let track 3 play to end
6. **Expected:** Track 3 automatically restarts

### Edge Cases

**Single Track:**
1. Clear playlist, add only 1 track
2. **Off mode:** Plays once, stops
3. **All mode:** Replays continuously
4. **One mode:** Replays continuously

**Empty Playlist:**
1. Clear all tracks
2. Set repeat to One
3. Press Next
4. **Expected:** No crash, graceful handling

**Shuffle + Repeat One:**
1. Enable shuffle
2. Set repeat to One
3. Press Next
4. **Expected:** Replays current track (NOT random)

### Persistence Test

1. Set mode to All
2. Quit app (Cmd+Q)
3. Relaunch app
4. **Expected:** Still in All mode (button lit)

### Double-Size Test

1. Set repeat to One (badge visible)
2. Press Ctrl+D (double size)
3. **Expected:**
   - Button scales to 2x (56×30px)
   - Badge scales to 2x (16px font)
   - Badge still centered on button
   - Badge still legible

---

## Fixes for Common Issues

### If "1" Badge Not Visible on Sony MP3

**Try these in order:**

1. **Increase shadow** in WinampMainWindow.swift line ~446:
   ```swift
   .shadow(color: .black.opacity(1.0), radius: 1.5, x: 0, y: 0)
   ```

2. **Adjust position** (if clipping):
   ```swift
   .offset(x: 7, y: 0)  // Move left
   .offset(x: 9, y: 0)  // Move right
   .offset(x: 8, y: -1) // Move up
   ```

3. **Add outline** (stronger contrast):
   ```swift
   ZStack {
       Text("1").offset(x: 7.5, y: 0).foregroundColor(.black)
       Text("1").offset(x: 8.5, y: 0).foregroundColor(.black)
       Text("1").offset(x: 8, y: -0.5).foregroundColor(.black)
       Text("1").offset(x: 8, y: 0.5).foregroundColor(.black)
       Text("1").offset(x: 8, y: 0).foregroundColor(.white)
   }
   ```

### If Badge Clips Button Edge

- Adjust x offset: Try 6, 7, 9, 10
- Adjust y offset: Try -1, -2, 1, 2
- Reduce font: Try 7px or 6px

---

## Success Criteria

**Must Pass:**
- [ ] Button cycles through 3 states visually
- [ ] "1" badge appears ONLY in repeat-one mode
- [ ] Badge legible on ALL 7 skins (min: Good rating)
- [ ] Ctrl+R cycles modes
- [ ] Off mode stops at playlist end
- [ ] All mode wraps to first track
- [ ] One mode replays current track
- [ ] Mode persists across app restart

**If all pass:** ✅ Ready to merge!

---

## Reporting Results

Please test and report:

1. **Badge visibility:** Rate each skin (Excellent/Good/Poor/Invisible)
2. **Behavior:** Confirm Off/All/One modes work as described
3. **Issues found:** Any visual or functional problems
4. **Screenshots:** If possible, capture "1" badge on button

**When testing complete:**
- Report findings
- I'll update README.md
- Create PR and merge to main

---

**App Location:** `/Users/hank/Library/Developer/Xcode/DerivedData/.../Debug/MacAmp.app`
**Status:** ✅ Running and ready for testing
