# Sprite Fallback System Verification Guide

## Build Verification

### 1. Compilation Check
```bash
cd /Users/hank/dev/src/MacAmp
swift build
```

**Expected**: Build completes successfully ✅

**Status**: Passed - Build completed in 2.03s

## Runtime Verification

### 2. Launch with Default Skin (Winamp.wsz)
```bash
swift run MacAmpApp
```

**Check Console for:**
```
🔄 SkinManager: Loading initial skin: bundled:Winamp
=== PROCESSING N SHEETS ===
✅ FOUND SHEET: NUMBERS -> NUMBERS.BMP (2030 bytes)
     ✅ NO_MINUS_SIGN at (9.0, 6.0, 5.0, 1.0)
     ✅ MINUS_SIGN at (20.0, 6.0, 5.0, 1.0)
     ✅ DIGIT_0 at (0.0, 0.0, 9.0, 13.0)
     [... all digits load successfully ...]
=== SPRITE EXTRACTION SUMMARY ===
✅ All sprites loaded successfully!
```

**Expected**: No fallback generation, all sprites load from actual images

### 3. Switch to Internet-Archive Skin
In running app:
1. Open Preferences/Settings
2. Select "Internet Archive" skin
3. Click "Apply" or switch

**Check Console for:**
```
🎨 SkinManager: Switching to skin: Internet Archive
=== PROCESSING N SHEETS ===
🔍 Looking for sheet: NUMBERS
⚠️ MISSING SHEET: NUMBERS.bmp/.png not found in archive
   Expected 11 sprites from this sheet
   - Missing sprite: NO_MINUS_SIGN
   - Missing sprite: MINUS_SIGN
   - Missing sprite: DIGIT_0
   - Missing sprite: DIGIT_1
   - Missing sprite: DIGIT_2
⚠️ Sheet 'NUMBERS' is missing - generating 11 fallback sprites
⚠️ Creating fallback for 'NO_MINUS_SIGN' with defined size: 5.0x1.0
⚠️ Creating fallback for 'MINUS_SIGN' with defined size: 5.0x1.0
⚠️ Creating fallback for 'DIGIT_0' with defined size: 9.0x13.0
⚠️ Creating fallback for 'DIGIT_1' with defined size: 9.0x13.0
[... all 11 fallback sprites generated ...]
=== SPRITE EXTRACTION SUMMARY ===
Total sprites available: [count]
Expected sprites: [count]
⚠️ Note: Some sprites are using transparent fallbacks due to missing/corrupted sheets
```

**Expected**:
- App continues to run
- No crashes
- Clear warning logs
- All fallback sprites have correct dimensions

### 4. Visual Verification

**In Internet-Archive skin:**
- Time display area may be invisible/transparent (uses DIGIT_0-9)
- Window otherwise functions normally
- No purple "?" placeholders visible (those only appear if entire skin fails to load)
- Layout remains intact

**Critical**: App should NOT crash or show broken UI

## Sprite Dimension Verification

### 5. Check Fallback Dimensions
Create a simple test to verify correct dimensions:

```swift
// In a test or debug context:
let manager = SkinManager()
let fallback = manager.createFallbackSprite(named: "DIGIT_0")
assert(fallback.size == CGSize(width: 9, height: 13), "DIGIT_0 should be 9x13")

let unknownFallback = manager.createFallbackSprite(named: "UNKNOWN_SPRITE")
assert(unknownFallback.size == CGSize(width: 16, height: 16), "Unknown sprites default to 16x16")
```

## Edge Cases

### 6. Test Corrupted Sheet Handling
Manually test with a skin where an image file is corrupted:
- Create a test skin with a corrupted BMP file
- Verify fallback generation for that sheet
- App should continue functioning

### 7. Test Individual Sprite Crop Failure
Test with a sheet where coordinates are out of bounds:
- App should detect crop failure
- Generate individual sprite fallback
- Log warning with helpful debug info

## Logging Quality

### 8. Verify Log Messages
All log messages should:
- Use ⚠️ for warnings (not ❌)
- Use NSLog for important messages
- Include helpful context (sprite name, dimensions, sheet name)
- Be clear about what failed and what fallback was used

**Before:**
```
❌ MISSING SPRITE: 'DIGIT_0' not found in skin
```

**After:**
```
⚠️ MISSING SHEET: NUMBERS.bmp/.png not found in archive
   Expected 11 sprites from this sheet
   - Missing sprite: DIGIT_0
⚠️ Creating fallback for 'DIGIT_0' with defined size: 9.0x13.0
```

## Performance

### 9. Fallback Generation Performance
- Fallback generation should be fast (< 1ms per sprite)
- No noticeable delay when loading skins with missing sprites
- Memory usage should be minimal (transparent images are small)

## Backwards Compatibility

### 10. Existing Skins Still Work
Test with various complete skins:
- Winamp.wsz ✅
- Any custom user skins ✅
- No regression in loading complete skins

## Summary Checklist

- [ ] App builds without errors
- [ ] App launches successfully
- [ ] Winamp.wsz loads all sprites correctly
- [ ] Internet-Archive.wsz generates fallbacks for NUMBERS.bmp
- [ ] No crashes when using incomplete skins
- [ ] Logging is clear and helpful
- [ ] Fallback sprites have correct dimensions
- [ ] UI layout is preserved with transparent fallbacks
- [ ] Performance is not impacted
- [ ] No regressions with complete skins

## Manual Testing Procedure

1. **Build**: `swift build` → Should succeed
2. **Run**: `swift run MacAmpApp` → Should launch
3. **Default skin**: Verify Winamp skin loads correctly
4. **Switch skin**: Change to Internet-Archive skin
5. **Check logs**: Console should show fallback generation
6. **Check UI**: App should function normally
7. **Visual inspect**: Time display may be invisible but layout intact
8. **No crashes**: App should remain stable throughout

## Expected Log Output (Internet-Archive.wsz)

```
📦 SkinManager: Discovered 2 skins
   - bundled:Winamp: Classic Winamp (bundled)
   - bundled:Internet-Archive: Internet Archive (bundled)
🔄 SkinManager: Loading initial skin: bundled:Winamp
[... Winamp loads successfully ...]
🎨 SkinManager: Switching to skin: Internet Archive
=== SPRITE DEBUG: Archive Contents ===
  Available file: readme.txt
  Available file: BALANCE.bmp
  Available file: CBUTTONS.bmp
  Available file: EQ_EX.bmp
  Available file: EQMAIN.bmp
  Available file: GEN.bmp
  Available file: GENEX.bmp
  Available file: MAIN.bmp
  Available file: MONOSTER.bmp
  Available file: NUMS_EX.bmp
  Available file: PLAYPAUS.bmp
  Available file: PLEDIT.bmp
  Available file: PLEDIT.txt
  Available file: POSBAR.bmp
  Available file: SHUFREP.bmp
  Available file: TEXT.bmp
  Available file: TITLEBAR.bmp
  Available file: VIDEO.bmp
  Available file: VISCOLOR.txt
  Available file: VOLUME.bmp
========================================
ℹ️ INFO: NUMS_EX.BMP not found (normal for many skins)
^-- This should now say "Found NUMS_EX.BMP" for Internet-Archive
=== PROCESSING 15 SHEETS ===
🔍 Looking for sheet: MAIN
✅ FOUND SHEET: MAIN -> MAIN.bmp (96104 bytes)
[... other sheets load ...]
🔍 Looking for sheet: NUMBERS
⚠️ MISSING SHEET: NUMBERS.bmp/.png not found in archive
   Expected 11 sprites from this sheet
   - Missing sprite: NO_MINUS_SIGN
   - Missing sprite: MINUS_SIGN
   - Missing sprite: DIGIT_0
   - Missing sprite: DIGIT_1
   - Missing sprite: DIGIT_2
⚠️ Sheet 'NUMBERS' is missing - generating 11 fallback sprites
⚠️ Creating fallback for 'NO_MINUS_SIGN' with defined size: 5.0x1.0
⚠️ Creating fallback for 'MINUS_SIGN' with defined size: 5.0x1.0
⚠️ Creating fallback for 'DIGIT_0' with defined size: 9.0x13.0
⚠️ Creating fallback for 'DIGIT_1' with defined size: 9.0x13.0
⚠️ Creating fallback for 'DIGIT_2' with defined size: 9.0x13.0
⚠️ Creating fallback for 'DIGIT_3' with defined size: 9.0x13.0
⚠️ Creating fallback for 'DIGIT_4' with defined size: 9.0x13.0
⚠️ Creating fallback for 'DIGIT_5' with defined size: 9.0x13.0
⚠️ Creating fallback for 'DIGIT_6' with defined size: 9.0x13.0
⚠️ Creating fallback for 'DIGIT_7' with defined size: 9.0x13.0
⚠️ Creating fallback for 'DIGIT_8' with defined size: 9.0x13.0
⚠️ Creating fallback for 'DIGIT_9' with defined size: 9.0x13.0
[... remaining sheets load or generate fallbacks ...]
=== SPRITE EXTRACTION SUMMARY ===
Total sprites available: [count]
Expected sprites: [count]
⚠️ Note: Some sprites are using transparent fallbacks due to missing/corrupted sheets
Skin loaded and set to currentSkin.
```

## Success Criteria

✅ **Build succeeds**
✅ **App runs without crashes**
✅ **Complete skins (Winamp.wsz) work perfectly**
✅ **Incomplete skins (Internet-Archive.wsz) load with fallbacks**
✅ **Fallback sprites have correct dimensions**
✅ **Logging is clear and helpful**
✅ **No visual purple placeholders in production use**
✅ **UI layout preserved with transparent sprites**
