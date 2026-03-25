# Plan: Winamp Equalizer Window Decomposition

> **Description:** Implementation plan for decomposing `WinampEqualizerWindow.swift` (626 lines) into child view structs.
> **Updated:** 2026-03-24 (Oracle review v2 — consolidated tiny files, fixed EQCoords visibility)

---

## Objective

Reduce `WinampEqualizerWindow.swift` from 626 to ~100 lines by extracting child views and standalone components, following the proven MainWindow decomposition pattern.

## Extraction Plan

### Step 1: Make `EQCoords` accessible (prerequisite)

Change `EQCoords` from `private struct` to `internal struct` (or move to its own file). All extracted child views need these pixel coordinates.

**Decision:** Keep `EQCoords` in the root file as `internal struct`. It's small (23 lines) and logically belongs to the window. Child views access it via the type name.

Remove dead `thumbWidth` constant (zero callers).

### Step 2: Extract `WinampVerticalSlider.swift` to `Views/Components/` (Safe, ~149 lines)

Move the entire `WinampVerticalSlider` struct. Fully independent reusable component.

### Step 3: Extract `EQPresetPickerView.swift` to `Views/EqualizerWindow/` (Safe, ~120 lines)

Move `PresetPickerView`, rename to `EQPresetPickerView`. Fully self-contained callback API.

Create `Views/EqualizerWindow/` subfolder.

### Step 4: Extract `EQFullLayer.swift` (Safe, ~200 lines)

**Oracle-guided consolidation:** Instead of 5 tiny files (EQControlButtons, EQSlidersLayer, EQCurveView, EQPresetsButton, EQTitlebarButtons), consolidate the full-mode content into a single `EQFullLayer` view struct. This mirrors `MainWindowFullLayer` — one file for all full-mode content.

Contains:
- ON/AUTO control buttons (was EQControlButtons, ~26 lines)
- Preamp + 10-band sliders (was EQSlidersLayer, ~40 lines)
- EQ curve visualization (was EQCurveView, ~33 lines)
- Presets button + save dialog + file import (was EQPresetsButton, ~63 lines)
- Titlebar buttons (was EQTitlebarButtons, ~34 lines)

`@Binding var isShadeMode` passed from parent for shade toggle. Slider dimensions included as local constants.

### Step 5: Extract `EQShadeLayer.swift` (Safe, ~29 lines)

Move shade mode builder. References titlebar button logic from `EQFullLayer` — or extract shared titlebar as a tiny helper within `EQFullLayer` that both modes call.

**Alternative:** If shade and full share titlebar buttons, extract `EQTitlebarButtons.swift` as a standalone shared view (~34 lines). This is the ONE case where a tiny file is justified — it's genuinely shared across two modes.

### Step 6: Slim root view

`WinampEqualizerWindow.swift` retains: @Environment declarations, @State for `isShadeMode`, `EQCoords` struct (internal), root `body` (if/else full/shade), frame/scale logic, #Preview. ~100 lines.

## New Files Created

| File | Location | Lines | Source |
|------|----------|-------|--------|
| `WinampVerticalSlider.swift` | `Views/Components/` | ~149 | Reusable component |
| `EQPresetPickerView.swift` | `Views/EqualizerWindow/` | ~120 | Standalone preset picker |
| `EQFullLayer.swift` | `Views/EqualizerWindow/` | ~200 | All full-mode content (consolidated) |
| `EQShadeLayer.swift` | `Views/EqualizerWindow/` | ~29 | Shade mode |
| `EQTitlebarButtons.swift` | `Views/EqualizerWindow/` | ~34 | Shared titlebar (full + shade) |

**Total new files: 5** (down from 8 — consolidated per Oracle guidance)
**Residual WinampEqualizerWindow.swift: ~100 lines**

## Visibility Changes

| Symbol | Current | After | Justification |
|--------|---------|-------|---------------|
| `EQCoords` | `private struct` | `internal struct` | Accessed by child views in separate files |

## Constraints

- Preserve current equalizer window behavior and appearance in both modes
- Do not mix audio-engine changes into this UI decomposition
- Decompose in place: `Views/EqualizerWindow/` subfolder (root stays in `Views/`)
- @Environment propagation — child views inherit automatically
- @Binding only for `isShadeMode` (titlebar buttons)
- Remove trivially dead code (`thumbWidth`)

## Verification

- Equalizer window renders correctly in normal and shade modes
- All 10 EQ band sliders + preamp slider update correctly
- ON/AUTO buttons toggle state correctly
- Preset picker: browse, select, save, delete, import all work
- EQ curve visualization tracks slider positions
- Double-size mode scaling works
- `xcodegen generate` + XcodeBuildMCP build + test pass
