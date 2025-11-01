# Double Rendering Investigation - Summary

## 🎯 ROOT CAUSE IDENTIFIED

**The double rendering of time display digits is caused by pre-rendered static digits in the skin's MAIN.BMP background image.**

## What's Happening

1. **Background Layer**: `MAIN_WINDOW_BACKGROUND` sprite includes the full 275×116px window
   - If MAIN.BMP has digits drawn at coordinates (39, 26), they are rendered as part of the background
   - These digits are STATIC (don't update)

2. **Dynamic Layer**: Your new semantic sprite system renders on top
   - `SimpleSpriteImage(.digit(n), ...)` renders at the same coordinates (39, 26)
   - These digits UPDATE correctly as time progresses

3. **Result**: Two sets of digits visible at the same location!

## Architecture is CORRECT ✅

- Only `WinampMainWindow.swift` is in the rendering path
- Uses semantic sprites correctly (`.digit()`, `.character()`, `.minusSign`)
- `MainWindowView.swift` is NOT being used (obsolete experimental UI)
- Shade mode logic is correct (only one branch executes)

## Why It Affects All Skins

If your test skins (Classic Winamp, Internet Archive, Winamp3) all have "00:00" or "88:88" placeholder digits baked into their MAIN.BMP files at the time display coordinates, they will all show this issue.

## Solutions (Pick One)

### Option A: Mask Time Display Area (Quick Fix) ⭐ RECOMMENDED
Add a black rectangle to clear static digits before rendering dynamic ones:

```swift
// In buildTimeDisplay(), before rendering digits:
Color.black
    .frame(width: 48, height: 13)
    .at(Coords.timeDisplay)

// Then render dynamic digits on top
```

### Option B: Split Background Sprite (Clean Solution)
Modify `MAIN_WINDOW_BACKGROUND` sprite definition to exclude time display area, render it in pieces.

### Option C: Edit Skin Files (Proper Solution)
Edit MAIN.BMP files directly to have blank/black pixels at time display coordinates (39, 26) to (87, 39).

### Option D: Smart Background Rendering
Check if skin has static digits in background, conditionally skip rendering background at time display region.

## Next Steps

1. **Verify the hypothesis:**
   ```bash
   open /Users/hank/dev/src/MacAmp/tmp/Internet-Archive/MAIN.bmp
   open /Users/hank/dev/src/MacAmp/tmp/Winamp3_Classified_v5.5/main.bmp
   ```
   Look at coordinates (39, 26) for static digits

2. **Implement quick fix (Option A):**
   Add masking rectangle in `buildTimeDisplay()` method

3. **Test across all skins:**
   Verify fix works for Classic, Internet Archive, Winamp3

## Files Analyzed

- ✅ `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/WinampMainWindow.swift` - Active, uses semantic sprites
- ✅ `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/UnifiedDockView.swift` - Confirmed single instance
- ✅ `/Users/hank/dev/src/MacAmp/MacAmpApp/MacAmpApp.swift` - Entry point verified
- ⚠️ `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/MainWindowView.swift` - NOT in use (legacy)
- ✅ `/Users/hank/dev/src/MacAmp/MacAmpApp/Models/SpriteResolver.swift` - Working correctly
- ✅ `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Components/SimpleSpriteImage.swift` - Working correctly

## Report Location

Full detailed analysis: `/Users/hank/dev/src/MacAmp/tasks/sprite-resolver-architecture/double-rendering-report.md`
