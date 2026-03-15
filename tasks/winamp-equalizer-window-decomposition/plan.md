# Plan: Winamp Equalizer Window Decomposition

> **Description:** Implementation plan for reducing `WinampEqualizerWindow.swift` and aligning it with the approved feature-first structure.
> **Purpose:** Keep the decomposition bounded, behavior-preserving, and focused on equalizer-window ownership clarity.

---

## Objective

Decompose `MacAmpApp/Views/WinampEqualizerWindow.swift` so the root view becomes a thinner window shell and the equalizer-specific UI pieces gain clearer ownership.

## Candidate Extraction Boundaries

- titlebar and window-shell controls
- EQ control-button group
- slider group and vertical-slider support view
- preset picker UI
- shade-mode rendering and EQ-curve rendering helpers

## Constraints

- Preserve current equalizer window behavior and appearance.
- Do not mix audio-engine changes into this UI decomposition task.
- Keep extracted views feature-owned rather than pushing them into generic global view buckets.

## Verification

- Equalizer window still renders correctly in normal and shade modes
- Sliders still update EQ state correctly
- Preset picker still loads, saves, imports, and applies presets correctly
- Project builds after any file moves and XcodeGen regeneration if needed
