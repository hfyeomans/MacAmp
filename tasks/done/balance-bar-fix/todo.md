# TODO: Balance Bar Color Fix

> **Purpose:** Broken-down task checklist derived from the plan. Each item is a discrete, verifiable unit of work.

---

## Status: COMPLETE - All tasks done, PR #43 merged

## Tasks

- [x] **1. Fix `calculateBalanceFrameOffset()` function**
  - File: `MacAmpApp/Views/Components/WinampVolumeSlider.swift`
  - Replaced `baseFrame = 14` logic with webamp-style linear mapping (frame 0 to 27)
  - Uses `Int(floor(percent * 27.0))` to match webamp's `Math.floor(percent * 27)`

- [x] **2. Update function comments**
  - Removed incorrect "frame 14 is green" comments
  - Removed "mirrored gradient" description
  - Added accurate comment documenting frame 0 = green, frame 27 = red, symmetric via abs(balance)

- [x] **3. Build and verify no compile errors**
  - Build succeeded with no new warnings
  - SwiftLint passed after extracting closure bodies into @ViewBuilder properties

- [x] **4. Boundary value verification**
  - Balance = 0.0: sprite = 0 (frame 0, deep green)
  - Balance = ±1.0: sprite = 27 (frame 27, deep red)
  - Balance = ±0.5: sprite = 13 (mid-gradient)
  - Balance = ±(1/27): sprite = 1 (first non-green frame)
  - `floor` quantization verified correct at all boundaries

- [x] **5. Visual verification - default skin**
  - Balance at center: deep green
  - Balance at full left: red
  - Balance at full right: red
  - Smooth gradient transition across full range

- [x] **6. Visual verification - additional skins**
  - Confirmed color gradient behaves correctly with different BALANCE.BMP assets

- [x] **7. Verify fallback path for missing BALANCE.BMP**
  - Fallback blue gradient renders without crash when BALANCE.BMP is absent

- [x] **8. Verify volume slider unaffected**
  - Volume slider gradient still works correctly
  - No regression in volume frame offset calculation

- [x] **9. Verify haptic snap-to-center**
  - Improved: haptic fires once on entry (not every frame)
  - Threshold widened from 8% to 12% for more noticeable catch
  - User verified feel is good

- [x] **10. Oracle review of final implementation**
  - Oracle (gpt-5.3-codex, xhigh reasoning) confirmed fix matches webamp reference
  - No edge cases missed

## Additional work completed (beyond original plan)

- [x] **11. Persist volume/balance via UserDefaults**
  - Volume and balance now saved on change and restored on launch
  - Default volume 0.75 (audible) when no saved preference exists

- [x] **12. Centralize UserDefaults keys**
  - Added `private enum Keys` to AudioPlayer matching AppSettings pattern
  - PR review feedback addressed

- [x] **13. SwiftLint compliance**
  - Extracted volume/balance slider bodies into @ViewBuilder properties
  - Added inline disables for pre-existing AudioPlayer file/type length violations
