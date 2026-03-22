# Research: Main+EQ stacking bug

## Observations
- `WindowCoordinator.resizeMainAndEQWindows` (MacAmpApp/ViewModels/WindowCoordinator.swift:181) rescales both NSWindows independently by keeping each title bar fixed via `origin.y -= delta`. This preserves individual top edges and causes overlap when the main window doubles because the equalizer never repositions relative to the new main bottom.
- Playlist repositioning logic already exists but only triggers when the playlist is docked (x within 15 px and gap <= 15 px). This behavior ensures manually placed playlists remain untouched.
- `UnifiedDockView` (tmp/UnifiedDockView.swift) demonstrates desired layout: windows are rendered inside a `VStack(alignment: .leading, spacing: 0)` ordered by `docking.sortedVisiblePanes`. Scaling uses `.scaleEffect(scale, anchor: .topLeading)` so every pane keeps its top-left anchor while the stack handles downstream offsets.
- Winamp base sizes are centralized in `WinampSizes` (MacAmpApp/Views/Components/SimpleSpriteImage.swift:98). Double-size mode multiplies these by `scale` (1 or 2), matching `UnifiedDockView` behavior.
- Docking expectations: playlist stays at user-specified height unless it's magnetically docked to EQ. EQ should remain magnetically attached to main window, mirroring stacked arrangement from unified view.

## Key requirements inferred
1. Main window anchor should stay fixed at title bar (current behavior is correct for main window only).
2. EQ and playlist must be positioned relative to the window above them to emulate VStack's stacking with zero spacing.
3. Playlist movement should continue to respect docking detection (only move when already snapped).
4. No mention of animation for multi-window scenario; existing unified view animation is limited to SwiftUI stack.
