# Plan: Balance Bar Color Fix

> **Purpose:** Implementation plan with step-by-step approach, rationale, and acceptance criteria for fixing the balance slider color gradient.

---

## Overview

Fix the `calculateBalanceFrameOffset()` function in `WinampVolumeSlider.swift` to correctly map balance position to BALANCE.BMP sprite frames. The center position (balance = 0) must display frame 0 (deep green), not frame 14 (yellow).

## Root Cause

The current code assumes green is at frame 14 (middle of the sprite sheet). In reality, both VOLUME.BMP and BALANCE.BMP have green at frame 0 (top) and red at frame 27 (bottom). The webamp reference confirms this layout.

## Implementation Plan

### Step 1: Fix `calculateBalanceFrameOffset()` (Primary Fix)

**File:** `MacAmpApp/Views/Components/WinampVolumeSlider.swift` lines 219-236

**Current (buggy):**
```swift
private func calculateBalanceFrameOffset() -> CGFloat {
    let absBalance = abs(balance)
    let percent = min(max(CGFloat(absBalance), 0), 1)
    let baseFrame = 14  // WRONG: green is frame 0, not 14
    let additionalFrames = Int(round(percent * 13.0))
    let frameIndex = min(27, baseFrame + additionalFrames)
    return -CGFloat(frameIndex) * 15.0
}
```

**Fixed (matching webamp):**
```swift
private func calculateBalanceFrameOffset() -> CGFloat {
    let percent = min(max(CGFloat(abs(balance)), 0), 1)
    let sprite = Int(floor(percent * 27.0))
    let offset = CGFloat(sprite) * 15.0
    return -offset
}
```

**Rationale:** Matches the webamp reference implementation exactly:
- `balance = 0` -> `percent = 0` -> `sprite = 0` -> offset = 0 -> Frame 0 (GREEN)
- `balance = ±0.5` -> `percent = 0.5` -> `sprite = 13` -> offset = -195 -> Frame 13 (mid-gradient)
- `balance = ±1.0` -> `percent = 1.0` -> `sprite = 27` -> offset = -405 -> Frame 27 (RED)

### Step 2: Update Comments

Remove the incorrect comments about frame 14 being green and the mirrored gradient description. Replace with accurate documentation matching the webamp behavior.

### Step 3: Verify with Visual Testing

- Build and run with Thread Sanitizer
- Load default skin
- Drag balance slider to center -> verify deep green
- Drag balance slider to full left -> verify red
- Drag balance slider to full right -> verify red
- Test with 2-3 additional skins to confirm skin-agnostic correctness
- Verify haptic snap-to-center still works

## Files Changed

| File | Change | Impact |
|------|--------|--------|
| `MacAmpApp/Views/Components/WinampVolumeSlider.swift` | Fix `calculateBalanceFrameOffset()` | 1 function, ~6 lines |

## Acceptance Criteria

1. Balance at center (0.0) shows deep green (frame 0 of BALANCE.BMP)
2. Balance at full left (-1.0) shows red (frame 27)
3. Balance at full right (+1.0) shows red (frame 27)
4. Gradient transitions smoothly across all 28 frames
5. Volume slider behavior is unchanged
6. Haptic snap-to-center still functional
7. No Thread Sanitizer warnings
8. Works with default skin and at least 2 additional skins

## Risk Assessment

**Low risk.** This is a single function change affecting only the visual frame offset calculation. No audio, state management, or architectural changes required.
