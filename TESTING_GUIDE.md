# MacAmp Phase 1 Testing Guide

**Date:** 2025-10-12
**Branch:** `swiftui-ui-detail-fixes`
**App Status:** ✅ Running and ready for testing

---

## Current State

✅ **Build:** Successful (both SPM and Xcode)
✅ **Commits:** 2 commits pushed to GitHub
✅ **App:** Launched and running with Classic Winamp skin

**Screenshot:** `/tmp/macamp_test_classic_skin.png` shows app running

---

## Testing Checklist

### 1. Menu Verification (CRITICAL)

**Check menu bar for these menus ONLY:**

- [ ] **MacAmpApp** (app menu - standard)
- [ ] **File** (if present)
- [ ] **Edit** (if present)
- [ ] **View** ← Should have window toggles
- [ ] **Appearance** ← Should have Liquid Glass settings
- [ ] **Skins** ← Should appear ONCE (not duplicated!)
- [ ] **Window** (standard)
- [ ] **Help** (if present)

**Should NOT see:**
- ❌ "Debug" menu (removed)
- ❌ Two "Skins" menus (fixed)

**Action:** Take screenshot showing menu bar

---

### 2. Skins Menu Structure

**Click on "Skins" menu and verify structure:**

```
Skins
├── Current: Classic Winamp          (should show current skin)
├────────────────────────────────
├── Bundled Skins
│   ├── Classic Winamp         ⌘⇧1
│   └── Internet Archive       ⌘⇧2
├────────────────────────────────
├── Import Skin File...        ⌘⇧O
├── Open Skins Folder          ⌘⇧L
├────────────────────────────────
└── Refresh Skins              ⌘⇧R
```

**Expected:**
- [ ] "Current:" shows "Classic Winamp"
- [ ] Two bundled skins listed
- [ ] Keyboard shortcuts visible
- [ ] All menu items enabled

**Action:** Take screenshot of open Skins menu

---

### 3. Skin Switching Test: Classic Winamp → Internet Archive

**Steps:**
1. **Initial state:** App should show Classic Winamp (green digits)
2. **Action:** Press **⌘⇧2** (or click "Internet Archive" in Skins menu)
3. **Expected results:**
   - [ ] All 3 windows update instantly
   - [ ] Digits change from GREEN to WHITE
   - [ ] Main window changes to silver/chrome style
   - [ ] Equalizer window updates
   - [ ] Playlist window updates
   - [ ] No flicker or lag
   - [ ] Time displays correctly (e.g., "00:00")

**Console Output (expected):**
```
🎨 SkinManager: Switching to skin: Internet Archive
⚠️ MISSING SHEET: NUMBERS.bmp/.png not found in archive  ← NORMAL!
   Expected 11 sprites from this sheet
✅ OPTIONAL: Found NUMS_EX.BMP - adding extended digit sprites
=== SPRITE EXTRACTION SUMMARY ===
Total sprites available: [210+]
⚠️ Note: Some sprites are using transparent fallbacks  ← NORMAL!
```

**Action:** Take screenshot after switching to Internet Archive

---

### 4. Skin Switching Test: Internet Archive → Classic Winamp

**Steps:**
1. **Current state:** Internet Archive skin (white digits)
2. **Action:** Press **⌘⇧1**
3. **Expected results:**
   - [ ] Digits change from WHITE to GREEN
   - [ ] All windows update instantly
   - [ ] Returns to classic Winamp style

**Action:** Take screenshot after switching back to Classic

---

### 5. Persistence Test

**Steps:**
1. Switch to Internet Archive skin (⌘⇧2)
2. Verify it's loaded (white digits visible)
3. Quit app (⌘Q)
4. Wait 3 seconds
5. Relaunch app
6. **Expected:** Internet Archive skin loads automatically (NOT Classic Winamp)

**Console Check:**
```
🔄 SkinManager: Loading initial skin: bundled:Internet-Archive
```

**Verification:**
- [ ] App remembers last-used skin
- [ ] Internet Archive loads on startup
- [ ] No need to manually switch again

---

### 6. Skin Import Test

**Steps:**
1. **Prepare:** Download any .wsz file (or use one from tmp/ folder)
2. **Action:** Skins menu → "Import Skin File..." (or press ⌘⇧O)
3. **Expected:** File picker opens filtered to .wsz files
4. **Select:** Choose a .wsz file
5. **Expected results:**
   - [ ] File picker closes
   - [ ] Skin is copied to `~/Library/Application Support/MacAmp/Skins/`
   - [ ] App switches to imported skin automatically
   - [ ] Notification appears: "SkinName imported successfully"
   - [ ] Skins menu now shows imported skin under "My Skins" section

**Test with:** `/Users/hank/dev/src/MacAmp/tmp/Winamp3_Classified_v5.5.wsz`

**Verification:**
```bash
ls -la ~/Library/Application\ Support/MacAmp/Skins/
# Should show: Winamp3_Classified_v5.5.wsz
```

---

### 7. Open Skins Folder Test

**Steps:**
1. **Action:** Skins menu → "Open Skins Folder" (or press ⌘⇧L)
2. **Expected:** Finder window opens to user skins directory
3. **Path:** `~/Library/Application Support/MacAmp/Skins/`

**Verification:**
- [ ] Finder window opens
- [ ] Directory path is correct
- [ ] Any imported skins visible in folder

---

### 8. Refresh Skins Test

**Steps:**
1. **Action:** Manually copy a .wsz file to `~/Library/Application Support/MacAmp/Skins/`
2. **Before refresh:** Skins menu doesn't show new skin
3. **Action:** Skins menu → "Refresh Skins" (or press ⌘⇧R)
4. **Expected:** Menu updates to include new skin

**Verification:**
- [ ] Manually added skins appear after refresh
- [ ] Menu updates dynamically

---

### 9. Rapid Switching Stress Test

**Steps:**
1. Rapidly press ⌘⇧1, ⌘⇧2, ⌘⇧1, ⌘⇧2 (20 times)
2. **Monitor:** Activity Monitor (memory usage)
3. **Expected results:**
   - [ ] No crashes
   - [ ] No significant memory leaks
   - [ ] Switching remains smooth
   - [ ] All windows stay synchronized

---

## Console Log Analysis

### What to Look For

#### Good Signs ✅
```
🔍 Bundle path: .../MacAmpApp.app/Contents/Resources
🔍 Resource URL: .../MacAmpApp.app/Contents/Resources
✅ Found Winamp.wsz at: .../Resources/Winamp.wsz
✅ Found Internet-Archive.wsz at: .../Resources/Internet-Archive.wsz
🎁 Total bundled skins found: 2
📦 SkinManager: Discovered 2 skins
```

#### Normal Warnings (Not Errors!) ⚠️
```
⚠️ MISSING SHEET: NUMBERS.bmp/.png not found in archive
   Expected 11 sprites from this sheet
⚠️ Sheet 'NUMBERS' is missing - generating 11 fallback sprites
✅ OPTIONAL: Found NUMS_EX.BMP - adding extended digit sprites
```

**Why Normal:** Internet Archive uses NUMS_EX instead of NUMBERS

#### Actual Problems (Require Investigation) ❌
```
❌ Skin not found: bundled:Winamp
🎁 Total bundled skins found: 0
❌ FAILED to create image for sheet: MAIN
```

**These indicate real issues** - skins not copying to build output

---

## Screenshot Checklist

### Required Screenshots

1. **Classic Winamp Skin (⌘⇧1)**
   - File: `macamp_classic_skin.png`
   - Should show: Green digits, classic colors
   - Focus on: Time display showing digits clearly

2. **Internet Archive Skin (⌘⇧2)**
   - File: `macamp_internet_archive_skin.png`
   - Should show: White/light digits, chrome style
   - Focus on: Digit color change vs Classic

3. **Skins Menu Open**
   - File: `macamp_skins_menu.png`
   - Should show: Menu structure with both skins
   - Focus on: No duplicates, no Debug menu

4. **After Import (if testing import)**
   - File: `macamp_after_import.png`
   - Should show: "My Skins" section with imported skin
   - Focus on: New skin in menu

---

## Expected Console Output

### App Launch (Classic Winamp)

```
🔍 Bundle path: /Users/hank/Library/Developer/Xcode/DerivedData/MacAmpApp-bkmcccatuvhsmhbgrftfacnjoxld/Build/Products/Debug/MacAmpApp.app/Contents/Resources
🔍 Bundle identifier: com.example.MacAmp
🔍 Resource URL: /Users/hank/Library/Developer/Xcode/DerivedData/MacAmpApp-bkmcccatuvhsmhbgrftfacnjoxld/Build/Products/Debug/MacAmpApp.app/Contents/Resources
🔍 Searching for bundled skin: Winamp.wsz
✅ Found Winamp.wsz at: .../Resources/Winamp.wsz
🔍 Searching for bundled skin: Internet-Archive.wsz
✅ Found Internet-Archive.wsz at: .../Resources/Internet-Archive.wsz
🎁 Total bundled skins found: 2
  📦 bundled:Winamp: Classic Winamp (bundled)
  📦 bundled:Internet-Archive: Internet Archive (bundled)
📦 SkinManager: Discovered 2 skins
   - bundled:Winamp: Classic Winamp (bundled)
   - bundled:Internet-Archive: Internet Archive (bundled)
🔄 SkinManager: Loading initial skin: bundled:Winamp
🎨 SkinManager: Switching to skin: Classic Winamp
Loading skin from .../Resources/Winamp.wsz

=== SPRITE DEBUG: Archive Contents ===
  Available file: MAIN.BMP
  Available file: CBUTTONS.BMP
  Available file: NUMBERS.BMP  ← Classic skin has NUMBERS
  ...
========================================

=== PROCESSING 11 SHEETS ===
🔍 Looking for sheet: MAIN
✅ FOUND SHEET: MAIN -> MAIN.BMP (76854 bytes)
...
✅ FOUND SHEET: NUMBERS -> NUMBERS.BMP (2378 bytes)
   Sheet size: 99.0×13.0
   Extracting 11 sprites:
     ✅ NO_MINUS_SIGN at (9.0, 6.0, 5.0, 1.0)
     ✅ MINUS_SIGN at (20.0, 6.0, 5.0, 1.0)
     ✅ DIGIT_0 at (0.0, 0.0, 9.0, 13.0)
     ...
ℹ️ INFO: NUMS_EX.BMP not found (normal for many skins)

=== SPRITE EXTRACTION SUMMARY ===
Total sprites available: 210
Expected sprites: 210
✅ All sprites loaded successfully!
```

### Skin Switch to Internet Archive (⌘⇧2)

```
🎨 SkinManager: Switching to skin: Internet Archive
Loading skin from .../Resources/Internet-Archive.wsz

=== SPRITE DEBUG: Archive Contents ===
  Available file: MAIN.BMP
  Available file: CBUTTONS.BMP
  Available file: NUMS_EX.BMP  ← Extended numbers!
  Available file: EQ_EX.BMP
  ...
========================================

=== PROCESSING 12 SHEETS ===  ← More sheets than Classic!
🔍 Looking for sheet: NUMBERS
⚠️ MISSING SHEET: NUMBERS.bmp/.png not found in archive
   Expected 11 sprites from this sheet
   - Missing sprite: DIGIT_0
   - Missing sprite: DIGIT_1
   ...
⚠️ Sheet 'NUMBERS' is missing - generating 11 fallback sprites
⚠️ Creating fallback for 'DIGIT_0' with defined size: 9.0x13.0
⚠️ Creating fallback for 'DIGIT_1' with defined size: 9.0x13.0
...

✅ FOUND SHEET: MAIN -> MAIN.BMP
✅ FOUND SHEET: CBUTTONS -> CBUTTONS.BMP
✅ OPTIONAL: Found NUMS_EX.BMP - adding extended digit sprites
✅ FOUND SHEET: NUMS_EX -> NUMS_EX.BMP (2482 bytes)
   Sheet size: 108.0×13.0
   Extracting 12 sprites:
     ✅ NO_MINUS_SIGN_EX at (90.0, 0.0, 9.0, 13.0)
     ✅ MINUS_SIGN_EX at (99.0, 0.0, 9.0, 13.0)
     ✅ DIGIT_0_EX at (0.0, 0.0, 9.0, 13.0)  ← These are what actually render!
     ...

=== SPRITE EXTRACTION SUMMARY ===
Total sprites available: 220  ← More than Classic!
Expected sprites: 220
⚠️ Note: Some sprites are using transparent fallbacks due to missing/corrupted sheets
```

**Important:** The warnings about NUMBERS.bmp are **NORMAL** because this skin uses NUMS_EX instead!

---

## Visual Verification Points

### Classic Winamp Skin (⌘⇧1)

**Digit Color:** 🟢 **Green**
```
Time Display:    [0][0][:][0][5]  ← Green 7-segment style digits
Bitrate:         [1][2][8]        ← Green
Frequency:       [4][4]           ← Green
```

**Overall Appearance:**
- Dark gray/black background
- Teal/cyan visualizer area
- Classic Winamp chrome
- Familiar 1998-era aesthetic

### Internet Archive Skin (⌘⇧2)

**Digit Color:** ⚪ **White/Light Gray**
```
Time Display:    [0][0][:][0][0]  ← White/light digits
Playlist Time:   [0][:][0][0][:][4][2][:][4][0]  ← White/light
```

**Overall Appearance:**
- Silver/chrome aesthetic
- Modern polished look
- Internet Archive branding
- Clean professional style

**Reference:** `Screenshot 2025-10-12 at 3.20.00 PM.png` shows perfect render

---

## Testing Commands

### Keyboard Shortcuts to Test

```
⌘⇧1    Switch to Classic Winamp
⌘⇧2    Switch to Internet Archive
⌘⇧O    Open skin file picker
⌘⇧L    Open skins folder in Finder
⌘⇧R    Refresh skins list
⌘Q     Quit (for persistence testing)
```

### Console Monitoring

**Open Console.app:**
1. Launch Console.app
2. Filter: `process:MacAmpApp`
3. Monitor in real-time while testing

**Or use terminal:**
```bash
log stream --predicate 'process == "MacAmpApp"' --level debug
```

---

## Import Testing Procedure

### Test Skin Available

**Location:** `/Users/hank/dev/src/MacAmp/tmp/Winamp3_Classified_v5.5.wsz`

**This skin has:**
- ✅ NUMBERS.bmp
- ✅ NUMS_EX.bmp (both systems!)
- ✅ Many BMP files (complete skin)

### Import Steps

1. **Trigger import:**
   - Skins menu → "Import Skin File..."
   - OR press ⌘⇧O

2. **File picker appears:**
   - Navigate to `/Users/hank/dev/src/MacAmp/tmp/`
   - Select `Winamp3_Classified_v5.5.wsz`
   - Click "Open"

3. **Expected behavior:**
   - Brief processing pause
   - All windows update to new skin
   - Notification: "Winamp3_Classified_v5.5 imported successfully"

4. **Verify in menu:**
   - Open Skins menu
   - Should see:
     ```
     My Skins
     └── Winamp3_Classified_v5.5    ← Newly imported!
     ```

5. **Verify in filesystem:**
   ```bash
   ls ~/Library/Application\ Support/MacAmp/Skins/
   # Should show: Winamp3_Classified_v5.5.wsz
   ```

---

## Failure Scenarios to Test

### Scenario 1: Import Same Skin Twice

**Steps:**
1. Import Winamp3_Classified_v5.5.wsz
2. Try to import it again
3. **Expected:** Alert appears
   ```
   Skin Already Exists
   A skin named "Winamp3_Classified_v5.5" already exists.
   Do you want to replace it?

   [Replace] [Cancel]
   ```
4. **Test both paths:**
   - Click Cancel → Import aborted
   - Click Replace → Old file replaced, skin reloads

### Scenario 2: Import Corrupted Skin

**Preparation:** Create fake .wsz file
```bash
echo "not a real zip" > /tmp/broken.wsz
```

**Steps:**
1. Try to import broken.wsz
2. **Expected:** Error alert
   ```
   Import Failed
   Could not import "broken": [error description]

   [OK]
   ```
3. **Verification:**
   - App doesn't crash
   - Current skin remains loaded
   - Broken file NOT copied to user directory

---

## Success Criteria

### Phase 1 Complete When:

- ✅ Both bundled skins switch correctly via keyboard shortcuts
- ✅ Digits change color between skins (green vs white)
- ✅ All windows update simultaneously on switch
- ✅ Only ONE Skins menu in menu bar
- ✅ No Debug menu present
- ✅ Skin import works with file picker
- ✅ Imported skins appear in My Skins section
- ✅ Persistence works (last skin loads on restart)
- ✅ Console logs are normal (warnings about NUMBERS.bmp expected)

---

## Known Expected Warnings

### These Are NORMAL - Don't Fix!

```
⚠️ MISSING SHEET: NUMBERS.bmp/.png not found in archive
```
**Reason:** Internet Archive uses NUMS_EX.bmp instead
**Impact:** None - fallbacks created but unused
**Visual:** Digits render perfectly from NUMS_EX

```
⚠️ Note: Some sprites are using transparent fallbacks
```
**Reason:** Different skins have different optional sheets
**Impact:** None - only affects unused UI elements
**Visual:** No visible difference

```
ℹ️ INFO: NUMS_EX.BMP not found (normal for many skins)
```
**Reason:** Classic Winamp uses NUMBERS.bmp instead
**Impact:** None - standard digits work fine
**Visual:** Green digits render correctly

---

## Screenshot Locations

### Automated Captures
- `/tmp/macamp_test_classic_skin.png` - Initial state (Classic Winamp)
- `/tmp/macamp_test_internet_archive.png` - After ⌘⇧2 (if captured)

### User Captures (Please Take)
1. `macamp_menu_bar.png` - Full menu bar showing all menus
2. `macamp_skins_menu_open.png` - Skins menu dropdown
3. `macamp_classic_digits.png` - Close-up of green digits
4. `macamp_internet_archive_digits.png` - Close-up of white digits
5. `macamp_after_import.png` - After importing custom skin

---

## Reporting Results

### If Everything Works

**Report:**
```
✅ All tests passed
✅ Skins switch correctly
✅ Digits change color as expected
✅ Import works perfectly
✅ Persistence confirmed
✅ Ready to merge!
```

### If Issues Found

**Report Format:**
```
Test: [Test name from checklist]
Expected: [What should happen]
Actual: [What actually happened]
Screenshot: [Filename]
Console Log: [Relevant log lines]
```

**Example:**
```
Test: Skin Switching (⌘⇧2)
Expected: Digits change from green to white
Actual: Digits stay green
Screenshot: macamp_digit_bug.png
Console Log: "❌ FAILED to load NUMS_EX sprites"
```

---

## Quick Reference

### App Info
- **Location:** `/Users/hank/Library/Developer/Xcode/DerivedData/MacAmpApp-bkmcccatuvhsmhbgrftfacnjoxld/Build/Products/Debug/MacAmpApp.app`
- **Bundle ID:** com.example.MacAmp
- **Bundled Skins:** 2 (Winamp, Internet-Archive)
- **User Skins Dir:** `~/Library/Application Support/MacAmp/Skins/`

### Documentation
- **Lessons Learned:** `docs/winamp-skins-lessons.md` (comprehensive)
- **Session State:** `SESSION_STATE.md` (current status)
- **This Guide:** `TESTING_GUIDE.md`

---

**Testing Status:** Ready for manual verification
**App Status:** Running and waiting for your input
**Next Action:** Follow checklist above and report findings
