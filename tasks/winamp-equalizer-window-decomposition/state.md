# State: Winamp Equalizer Window Decomposition

> **Description:** Tracks readiness and progress for the `WinampEqualizerWindow.swift` decomposition task.
> **Updated:** 2026-03-24 (S2 complete, responsibility map done, plan implementation-ready)

---

## Status

READY TO START. Responsibility map and implementation plan complete.

## Scheduling

- No S2 dependencies on this file — unchanged at 626 lines.
- Execution order: **Task 3 of 5** (follows proven MainWindow decomposition pattern)

## Current Line Count

626 lines (unchanged from planning time)

## Key Decision

- Decompose into new `Views/EqualizerWindow/` subfolder (7 files) + 1 to existing `Views/Components/`
- Root file stays in `Views/WinampEqualizerWindow.swift` at ~80-100 lines
- WinampVerticalSlider is reusable, goes to Components/ (not EQ-specific)
- PresetPickerView renamed to EQPresetPickerView for clarity
- thumbWidth dead code removed during extraction (safe)
- Shade mode static slider placeholders documented as pre-existing in placeholder.md
