# Research Notes

## Inputs Reviewed
- tasks/code-duplication-analysis/README.md (summary of duplicates and orphaned code)
- tasks/code-duplication-analysis/detailed-findings.md (file-by-file details)
- Source tree cross-references via `rg`

## Key Questions
1. Are the modern SwiftUI window variants (`MainWindowView`, `PlaylistWindowView`, `EqualizerWindowView`) referenced anywhere in the active app flow?
2. Are legacy slider components (`VolumeSliderView`, `BalanceSliderView`, `EQSliderView`, `BaseSliderControl`) invoked by production views?
3. Is `SimpleTestMainWindow` reachable from production code?

## Evidence Collected
- `UnifiedDockView` and `DockingContainerView` only instantiate `WinampMainWindow`, `WinampPlaylistWindow`, and `WinampEqualizerWindow`.
- `rg "PlaylistWindowView"`, `rg "MainWindowView"`, and `rg "EqualizerWindowView"` locate definitions and Xcode project entries but no call sites outside their own files.
- `VolumeSliderView`, `BalanceSliderView`, and `EQSliderView` are solely referenced inside the unused modern window files.
- `BaseSliderControl` has no references outside its own file.
- `SimpleTestMainWindow` is not referenced outside its file/Xcode project metadata.

## Outstanding Checks
- Confirm no runtime dynamic lookup (e.g., string-based view loading) that could reach legacy views. None detected in search of `"MainWindowView"`, `"PlaylistWindowView"`, `"EqualizerWindowView"` strings or reflective APIs.

