# Research: Balance Bar Color Fix

> **Purpose:** Contains all research findings, reference implementation analysis, and technical investigation of the balance slider color gradient bug.

---

## Problem Statement

The balance slider's color gradient transition is incorrect at center position (balance = 0). When the slider is at dead center, it should display the deepest green (matching volume slider at 0/leftmost). Instead, it displays yellow, indicating the frame offset calculation is wrong.

**Expected behavior:**
- Full left (-1.0): Red
- Center (0.0): Deep green (same green as volume at 0)
- Full right (+1.0): Red

**Actual behavior:**
- Full left (-1.0): Red (correct)
- Center (0.0): Yellow (WRONG - should be green)
- Full right (+1.0): Red (correct)

---

## BALANCE.BMP Sprite Sheet Layout

The BALANCE.BMP file contains 28 pre-rendered frames stacked vertically:

| Frame Range | Y Position | Color |
|-------------|-----------|-------|
| Frame 0 | y: 0-14 | Deep Green (center/no balance) |
| Frame 1-7 | y: 15-119 | Green to Yellow transition |
| Frame 8-14 | y: 120-224 | Yellow to Orange transition |
| Frame 15-21 | y: 225-329 | Orange to Red transition |
| Frame 22-27 | y: 330-419 | Deep Red (full balance offset) |
| Thumbs | y: 422+ | Thumb sprites (active/inactive) |

**Key insight:** Frame 0 (top of sprite) is GREEN. Frame 27 (bottom) is RED. The gradient flows top-to-bottom from green to red.

---

## Webamp Reference Implementation (CORRECT)

**File:** `webamp_clone/packages/webamp/js/components/MainWindow/MainBalance.tsx` (lines 7-12)

```typescript
export const offsetFromBalance = (balance: number): number => {
  const percent = Math.abs(balance) / 100;        // 0 to 1
  const sprite = Math.floor(percent * 27);        // 0 to 27
  const offset = sprite * 15;                     // 0 to 405
  return offset;
};
```

**Behavior:**
- `balance = 0` -> `percent = 0` -> `sprite = 0` -> `offset = 0` -> **Frame 0 (GREEN)**
- `balance = ±50` -> `percent = 0.5` -> `sprite = 13` -> `offset = 195` -> **Frame 13 (Yellow/Orange)**
- `balance = ±100` -> `percent = 1.0` -> `sprite = 27` -> `offset = 405` -> **Frame 27 (RED)**

The webamp implementation starts at frame 0 (green) and progresses linearly to frame 27 (red) based on distance from center.

---

## Winamp Maki Script Reference

**File:** `webamp_clone/packages/webamp-modern/assets/winamp_classic/scripts/balance.m` (lines 24-32)

```maki
Balance.onSetPosition(int newpos)
{
  int v = newpos;
  if (newpos==127) anlBalance.gotoFrame(15);
  if (newpos<127) v = (27-(newpos/127)*27);
  if (newpos>127) v = ((newpos-127)/127)*27;
  anlBalance.gotoFrame(v);
}
```

Note: The Maki script uses a different frame numbering for the Modern skin. The Classic skin behavior (which MacAmp recreates) follows the webamp pattern.

---

## MacAmp Current Implementation (BUGGY)

**File:** `MacAmpApp/Views/Components/WinampVolumeSlider.swift` (lines 219-236)

```swift
private func calculateBalanceFrameOffset() -> CGFloat {
    let absBalance = abs(balance)  // 0.0 to 1.0
    let percent = min(max(CGFloat(absBalance), 0), 1)

    // BUG: Assumes green is at frame 14 (middle of sprite sheet)
    // ACTUAL: Green is at frame 0 (top of sprite sheet)
    let baseFrame = 14  // <-- THIS IS WRONG
    let additionalFrames = Int(round(percent * 13.0))  // Only uses 13 of 27 frames
    let frameIndex = min(27, baseFrame + additionalFrames)

    return -CGFloat(frameIndex) * 15.0
}
```

**Bug behavior:**
- `balance = 0` -> `baseFrame = 14` + `0` = **Frame 14 (YELLOW)** -- should be Frame 0 (GREEN)
- `balance = ±0.5` -> `baseFrame = 14` + `7` = **Frame 21 (Orange/Red)**
- `balance = ±1.0` -> `baseFrame = 14` + `13` = **Frame 27 (RED)** -- correct by coincidence

**Root cause:** The code incorrectly assumes green is in the middle of the sprite sheet (frame 14). In reality, green is at frame 0 (top), matching the volume slider's VOLUME.BMP layout where frame 0 is also green.

---

## Volume Slider Reference (CORRECT - for comparison)

**File:** `MacAmpApp/Views/Components/WinampVolumeSlider.swift` (lines 88-94)

```swift
private func calculateVolumeFrameOffset() -> CGFloat {
    let percent = min(max(CGFloat(volume), 0), 1)
    let sprite = Int(round(percent * 28.0))  // 0 to 28
    let frameIndex = min(27, max(0, sprite - 1))  // Clamp to 0-27
    let offset = CGFloat(frameIndex) * 15.0
    return -offset
}
```

Volume at 0 -> frame 0 (green). This is correct. The balance slider should follow the same sprite sheet layout.

---

## Sprite Definitions

**File:** `MacAmpApp/Models/SkinSprites.swift` (lines 134-146)

```swift
"VOLUME": [
    Sprite(name: "MAIN_VOLUME_BACKGROUND", x: 0, y: 0, width: 68, height: 420),
    Sprite(name: "MAIN_VOLUME_THUMB", x: 15, y: 422, width: 14, height: 11),
    Sprite(name: "MAIN_VOLUME_THUMB_SELECTED", x: 0, y: 422, width: 14, height: 11),
],

"BALANCE": [
    Sprite(name: "MAIN_BALANCE_BACKGROUND", x: 9, y: 0, width: 38, height: 420),
    Sprite(name: "MAIN_BALANCE_THUMB", x: 15, y: 422, width: 14, height: 11),
    Sprite(name: "MAIN_BALANCE_THUMB_ACTIVE", x: 0, y: 422, width: 14, height: 11),
],
```

Both sprite sheets are 420px tall (28 frames x 15px). Both have frame 0 at the top (green).

---

## Key Files

| File | Role | Lines |
|------|------|-------|
| `MacAmpApp/Views/Components/WinampVolumeSlider.swift` | Balance slider implementation (bug location) | 219-236 |
| `MacAmpApp/Views/WinampMainWindow.swift` | Balance slider integration | 540-545 |
| `MacAmpApp/Models/SkinSprites.swift` | Sprite coordinate definitions | 141-146 |
| `MacAmpApp/Models/SpriteResolver.swift` | Semantic sprite resolution | 233-246 |
| `webamp_clone/packages/webamp/js/components/MainWindow/MainBalance.tsx` | Reference implementation | 7-12 |

---

## Conclusion

The fix is straightforward: replace the `baseFrame = 14` approach with the webamp-style linear mapping from frame 0 to frame 27 based on `abs(balance)`. This matches:
1. The actual BALANCE.BMP sprite sheet layout (green at top, red at bottom)
2. The webamp reference implementation
3. The volume slider's own frame calculation pattern
