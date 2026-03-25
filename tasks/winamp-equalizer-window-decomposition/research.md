# Research: Winamp Equalizer Window Decomposition

> **Description:** Responsibility map for decomposing `WinampEqualizerWindow.swift` into child view structs.
> **Updated:** 2026-03-25 (line numbers refreshed post-Phase 2.5 cleanup)

---

## File Overview

**File:** `MacAmpApp/Views/WinampEqualizerWindow.swift`
**Lines:** 617 (down from 626 — Phase 2.5 removed dead `thumbWidth` constant)
**Contains:** 3 View structs + 1 nested coordinate struct + 1 Preview

| Struct | Lines | Role |
|---|---|---|
| `WinampEqualizerWindow` | 6-348 | Root EQ window view (full + shade mode) |
| `WinampVerticalSlider` | 350-489 | Reusable vertical slider component |
| `PresetPickerView` | 491-610 | Popover preset selection UI |

## Imports

- `SwiftUI` — all views
- `AppKit` — `NSOpenPanel`, `NSAlert` for file import/save dialogs
- `UniformTypeIdentifiers` — `UTType` in file import

## Environment Dependencies

| Dependency | Type | Used By |
|---|---|---|
| `SkinManager` | `@Environment` | Sprites throughout |
| `AudioPlayer` | `@Environment` | EQ bands, preamp, presets, toggles |
| `AppSettings` | `@Environment` | `isDoubleSizeMode` |
| `PlaybackCoordinator` | `@Environment` | `supportsAudioProcessing` (dimming) |
| `WindowFocusState` | `@Environment` | `isEqualizerKey` (titlebar active state) |

---

## Section-by-Section Responsibility Map

### EQCoords Constants (lines 22-44) — 23 lines
- **Responsibility:** Pixel-coordinate constants for absolute positioning
- **Key symbols:** `EQCoords` struct — `preampSlider`, `eqSliderPositions`, `onButton`, `autoButton`, `presetsButton`, `minimizeButton`, `shadeButton`, `closeButton`, `graphArea`
- **Extractability:** Extract first — shared by all child views

### File Import Helper (lines 46-60) — 15 lines
- **Responsibility:** NSOpenPanel for .eqf preset file import
- **Key symbols:** `importPresetFromFile()`
- **Extractability:** Should travel with presets section

### Slider Dimensions (lines 62-65) — 4 lines
- **Key symbols:** `sliderWidth`, `sliderHeight`, `thumbHeight`
- **Phase 2.5:** `thumbWidth` removed (was dead code, zero callers)

### Root Body (lines 68-130) — 63 lines
- **Responsibility:** Top-level composition — branches full/shade mode, applies scale/frame
- **Internal coupling:** Calls all builder methods
- **Extractability:** Stays as root — simplified after extraction

### Titlebar Buttons Builder (lines 132-165) — 34 lines
- **Responsibility:** Minimize, shade toggle, close buttons
- **Key symbols:** `buildTitlebarButtons()`
- **Internal coupling:** Mutates `isShadeMode` (needs @Binding if extracted). Called from BOTH full and shade modes.
- **External coupling:** `WindowCoordinator.shared`
- **Extractability:** **Moderate** — shared across modes, needs binding for isShadeMode

### Control Buttons Builder (lines 167-192) — 26 lines
- **Responsibility:** EQ on/off toggle and Auto-EQ toggle
- **Key symbols:** `buildControlButtons()`
- **External coupling:** `audioPlayer.isEqOn`, `audioPlayer.eqAutoEnabled`
- **Extractability:** **Safe** — only reads @Environment audioPlayer

### Preamp Slider Builder (lines 194-210) — 17 lines
- **Responsibility:** Single preamp vertical slider
- **Key symbols:** `buildPreampSlider()`
- **Extractability:** **Safe** — thin wrapper around WinampVerticalSlider

### EQ Band Sliders Builder (lines 212-234) — 23 lines
- **Responsibility:** 10-band equalizer sliders via ForEach
- **Key symbols:** `buildEQSliders()`
- **Extractability:** **Safe** — combine with preamp into EQSlidersLayer

### Presets Button Builder (lines 236-266) — 31 lines
- **Responsibility:** Presets button with popover
- **Key symbols:** `buildPresetsButton()`
- **Internal coupling:** Mutates `showPresetPicker`, calls `showSavePresetDialog()`, `importPresetFromFile()`
- **Extractability:** **Moderate** — needs @State and dialog helpers to travel with it

### Save Preset Dialog (lines 268-284) — 17 lines
- **Responsibility:** NSAlert with text field for saving named preset
- **Key symbols:** `showSavePresetDialog()`
- **Extractability:** Should travel with presets button

### Shade Mode Builder (lines 286-314) — 29 lines
- **Responsibility:** Compact 275x14px shade rendering
- **Key symbols:** `buildShadeMode()`
- **Note:** Shade slider sprites are static placeholders (no interactivity)
- **Extractability:** **Safe** — mirrors MainWindowShadeLayer pattern

### EQ Curve Visualization (lines 316-348) — 33 lines
- **Responsibility:** Draw EQ frequency response curve over graph background
- **Key symbols:** `buildEQCurve()`
- **Extractability:** **Safe** — pure visualization, reads audioPlayer.eqBands

### WinampVerticalSlider (lines 350-489) — 140 lines
- **Responsibility:** Reusable sprite-based vertical slider with grid background, drag, center snapping
- **Key symbols:** Standalone `struct WinampVerticalSlider: View` — fully independent component
- **External coupling:** `SkinManager` via @Environment
- **Extractability:** **Safe — should be extracted to its own file** (no EQ-specific references)

### PresetPickerView (lines 491-610) — 120 lines
- **Responsibility:** Popover UI for browsing, selecting, saving, deleting, importing presets
- **Key symbols:** Standalone `struct PresetPickerView: View` — callback-driven, no @Environment
- **External coupling:** `EQPreset` model only
- **Extractability:** **Safe — should be extracted to its own file** (fully self-contained)

---

## Dead Code

- ~~`thumbWidth` (line 65)~~ — **Removed in Phase 2.5** (was declared but never referenced)

## Duplicated Patterns

- Preamp slider and EQ band sliders share identical WinampVerticalSlider configuration.

## Communication Patterns

- **Environment injection:** Child views inherit @Environment automatically
- **Local state:** `isShadeMode` and `showPresetPicker` are @State on root. Extracted children needing these require @Binding.
- **Callbacks:** PresetPickerView already uses clean callback pattern — exemplary extraction-ready design.
- **Singletons:** `WindowCoordinator.shared` accessed directly (consistent with codebase).

---

## Recommended Extraction Units

Following MainWindow decomposition pattern (root + full layer + shade layer + child views):

| # | Target File | Source | Est. Lines | Risk |
|---|-------------|--------|------------|------|
| 1 | `WinampVerticalSlider.swift` (Views/Components/) | Standalone component | ~140 | Safe |
| 2 | `EQPresetPickerView.swift` | Standalone component | ~120 | Safe |
| 3 | `EQTitlebarButtons.swift` | Titlebar builder | ~34 | Moderate |
| 4 | `EQControlButtons.swift` | Control buttons | ~26 | Safe |
| 5 | `EQSlidersLayer.swift` | Preamp + 10-band | ~40 | Safe |
| 6 | `EQPresetsButton.swift` | Presets + dialogs + import | ~63 | Moderate |
| 7 | `EQCurveView.swift` | Graph visualization | ~33 | Safe |
| 8 | `EQShadeLayer.swift` | Shade mode | ~29 | Safe |

**Post-extraction WinampEqualizerWindow.swift estimate:** ~80-100 lines
