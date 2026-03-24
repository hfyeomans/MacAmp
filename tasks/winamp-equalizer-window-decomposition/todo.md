# Todo: Winamp Equalizer Window Decomposition

> **Description:** Checklist for executing the `WinampEqualizerWindow.swift` decomposition.
> **Updated:** 2026-03-24 (Oracle review v2 — consolidated files, fixed EQCoords visibility)

---

- [x] Produce a responsibility map for `WinampEqualizerWindow.swift`
- [ ] Create branch `refactor/winamp-equalizer-window-decomposition`
- [ ] Update state.md to IN PROGRESS
- [ ] Make `EQCoords` internal (was private)
- [ ] Remove dead `thumbWidth` constant
- [ ] Create `Views/EqualizerWindow/` subfolder
- [ ] Extract `WinampVerticalSlider` to `Views/Components/WinampVerticalSlider.swift`
- [ ] Extract `PresetPickerView` to `Views/EqualizerWindow/EQPresetPickerView.swift` (rename)
- [ ] Extract full-mode content to `Views/EqualizerWindow/EQFullLayer.swift` (consolidated: controls, sliders, curve, presets, titlebar)
- [ ] Extract shade mode to `Views/EqualizerWindow/EQShadeLayer.swift`
- [ ] Extract shared titlebar buttons to `Views/EqualizerWindow/EQTitlebarButtons.swift` (with @Binding isShadeMode)
- [ ] Run `xcodegen generate`
- [ ] XcodeBuildMCP build (Thread Sanitizer enabled)
- [ ] XcodeBuildMCP test
- [ ] Oracle review on extraction
- [ ] Manual test: EQ window normal + shade mode, sliders, presets, curve, double-size
- [ ] Push branch -> create PR for user review
- [ ] Update state.md and shared _context/ on completion
