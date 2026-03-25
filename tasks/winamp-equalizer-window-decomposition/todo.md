# Todo: Winamp Equalizer Window Decomposition

> **Description:** Checklist for executing the `WinampEqualizerWindow.swift` decomposition.
> **Updated:** 2026-03-25 (COMPLETE — selective extraction per responsibility sweep)

---

- [x] Produce a responsibility map for `WinampEqualizerWindow.swift`
- [x] ~~Remove dead `thumbWidth` constant~~ — removed in Phase 2.5
- [x] Extract `WinampVerticalSlider` to `Views/Components/WinampVerticalSlider.swift`
- [x] Extract `PresetPickerView` to `Views/Components/EQPresetPickerView.swift` (renamed)
- [x] Add `thumbWidth` parameter to WinampVerticalSlider (was hardcoded)
- [x] Fix thumb offset to use `(width - thumbWidth) / 2` instead of hardcoded 1.5
- [x] Run `xcodegen generate`
- [x] XcodeBuildMCP build (Thread Sanitizer enabled)
- [x] XcodeBuildMCP test — 55/55 pass
- [x] Oracle review — 9/10
- [x] Resolve PR comments (Gemini + CodeRabbit): thumb hardcoding fixed, NUMS_EX lookup fixed
- [x] Push branch → PR #76 → user review → merged
- [x] Update state.md and shared _context/ on completion

## Cancelled (per responsibility sweep)

- ~~Make `EQCoords` internal~~ — not needed (no layer split)
- ~~Create `Views/EqualizerWindow/` subfolder~~ — not needed
- ~~Extract `EQFullLayer.swift`~~ — would be pass-through middleman (Principle 6)
- ~~Extract `EQShadeLayer.swift`~~ — cancelled with full split
- ~~Extract `EQTitlebarButtons.swift`~~ — cancelled with full split
