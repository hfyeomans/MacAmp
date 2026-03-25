# State: Winamp Equalizer Window Decomposition

> **Description:** Tracks readiness and progress for the `WinampEqualizerWindow.swift` decomposition task.
> **Updated:** 2026-03-25 (line numbers refreshed post-Phase 2.5 cleanup)

---

## Status

READY TO START. Plans refreshed with current line numbers.

## Scheduling

- Phase 2.5 cleanup landed (PR #72): `thumbWidth` removed.
- Execution order: **Task 2 of 5** (follows proven MainWindow decomposition pattern)

## Current Line Count

616 lines (down from 626 — Phase 2.5 removed dead `thumbWidth`)

## Key Decision

- Decompose into new `Views/EqualizerWindow/` subfolder + 1 to existing `Views/Components/`
- Root file stays in `Views/WinampEqualizerWindow.swift` at ~80-100 lines
- WinampVerticalSlider is reusable, goes to Components/ (not EQ-specific)
- PresetPickerView renamed to EQPresetPickerView for clarity
- ~~thumbWidth dead code removed during extraction~~ — already removed in Phase 2.5
- Shade mode static slider placeholders documented as pre-existing in placeholder.md
