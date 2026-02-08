# TODO: Balance Bar Color Fix

> **Purpose:** Broken-down task checklist derived from the plan. Each item is a discrete, verifiable unit of work.

---

## Tasks

- [ ] **1. Fix `calculateBalanceFrameOffset()` function**
  - File: `MacAmpApp/Views/Components/WinampVolumeSlider.swift` lines 219-236
  - Replace `baseFrame = 14` logic with webamp-style linear mapping (frame 0 to 27)
  - Use `Int(floor(percent * 27.0))` to match webamp's `Math.floor(percent * 27)`

- [ ] **2. Update function comments**
  - Remove incorrect "frame 14 is green" comments
  - Remove "mirrored gradient" description (gradient is not mirrored, it's linear from 0)
  - Add accurate comment documenting frame 0 = green, frame 27 = red

- [ ] **3. Build and verify no compile errors**
  - Run `xcodebuild -scheme MacAmp -configuration Debug`
  - Ensure no warnings introduced

- [ ] **4. Boundary value verification**
  - Balance = 0.0: sprite = 0 (frame 0, deep green)
  - Balance = ±1.0: sprite = 27 (frame 27, deep red)
  - Balance = ±0.5: sprite = 13 (mid-gradient)
  - Balance = ±(1/27): sprite = 1 (first non-green frame)
  - Verify `floor` quantization at bucket boundaries (no off-by-one)
  - Verify full-red frame appears at exact edge drag positions

- [ ] **5. Visual verification - default skin**
  - Balance at center: deep green
  - Balance at full left: red
  - Balance at full right: red
  - Smooth gradient transition across full range

- [ ] **6. Visual verification - additional skins**
  - Test with at least 2 non-default skins
  - Confirm color gradient behaves correctly with different BALANCE.BMP assets

- [ ] **7. Verify fallback path for missing BALANCE.BMP**
  - Test behavior when skin has no BALANCE.BMP (fallback gradient)
  - Ensure no crash on corrupt/missing sprite sheet

- [ ] **8. Verify volume slider unaffected**
  - Volume slider gradient still works correctly
  - No regression in volume frame offset calculation

- [ ] **9. Verify haptic snap-to-center still works**
  - Balance slider still snaps at 8% threshold
  - Haptic feedback fires on snap

- [ ] **10. Oracle review of final implementation**
  - Have Oracle verify the fix matches webamp reference
  - Confirm no edge cases missed
