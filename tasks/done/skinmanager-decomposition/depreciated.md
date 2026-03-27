# Depreciated Code: SkinManager Decomposition

> **Description:** Code removed during this task that was originally thought necessary.

---

## SkinBackgroundPreprocessor (DELETED — PR #75)

**File:** `MacAmpApp/ViewModels/SkinBackgroundPreprocessor.swift` (42 lines)

**What it did:** Drew two black rectangles over the MAIN_WINDOW_BACKGROUND sprite to mask baked-in "00:00" digit positions in some skins.

**Why it was removed:** The digit sprites render on top at the exact same positions, making the preprocessing unnecessary. Worse, the black rectangles were wider than the digit sprites (22px and 24px vs 9px digits), causing visible black artifacts on skins with non-black backgrounds (e.g., retrowave/purple skins).

**Lesson:** Early-project workarounds should be re-evaluated as the rendering pipeline matures. Scan for similar defensive preprocessing that sprites now handle natively.

## PresetsButton.swift (DELETED — PR #75)

**File:** `MacAmpApp/Views/PresetsButton.swift` (146 lines)

**What it did:** Alternative EQ preset selection UI using EqfPreset/EQFCodec with folder-based EQF file loading.

**Why it was removed:** Superseded by PresetPickerView (now EQPresetPickerView) inside WinampEqualizerWindow.swift, which uses the newer EQPreset model. Zero callers — never instantiated by any view.

## WinampButtonStyle.swift (DELETED — PR #75)

**File:** `MacAmpApp/Views/Components/WinampButtonStyle.swift` (37 lines)

**What it did:** Provided a `WinampButtonStyle` ButtonStyle and `.winampButton()` View extension to replace manual `.buttonStyle(.plain).focusable(false)`.

**Why it was removed:** Created but never adopted. The manual `.buttonStyle(.plain).focusable(false)` pattern appears 39 times across view files but none use WinampButtonStyle. Zero callers.

## WinampAlertHelper.promptText (DELETED — PR #75)

**What it did:** Text input prompt using NSAlert with NSTextField accessory view.

**Why it was removed:** Zero callers. Pre-generalized API that was never used. The existing `showSavePresetDialog()` in WinampEqualizerWindow builds its own NSAlert with text field directly.
