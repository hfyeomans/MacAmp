# Playlist Docking Debug Research

## Context
- Issue occurs inside `MacAmpApp/ViewModels/WindowCoordinator.swift:181-241` when handling double-size toggles.
- `resizeMainAndEQWindows` samples `main.frame`, `eq.frame`, `playlistWindow?.frame` before resizing and tries to infer whether playlist is docked.

## Existing Detection Logic
- Current detection calculates:
  - `playlistTop = playlist.origin.y + playlist.height`
  - `eqBottom = eq.origin.y`
  - `xAligned = abs(playlist.origin.x - eq.origin.x) <= 15`
  - `yAligned = abs(eqBottom - playlistTop) <= 15`
- Hard-coded `15` tolerance mirrors `SnapUtils.SNAP_DISTANCE`.
- Only handles the vertical stack case where playlist sits directly below EQ (top of playlist touching bottom of EQ). No handling for:
  - Playlist docked above EQ.
  - Playlist snapped to EQ's left/right edges (horizontal cluster).
  - Partial overlaps when playlist width differs from EQ.

## Snap Manager Behavior
- `WindowSnapManager` maintains per-window `Box` records in `VirtualScreenSpace` using a top-left coordinate system.
- `boxesAreConnected` (lines 149-172 in `WindowSnapManager.swift`) already checks for all orientations: vertical and horizontal adjacency, as well as touching top/bottom/left/right edges.
- Snap distance is defined centrally in `SnapUtils.SNAP_DISTANCE = 15`.

## Coordinate Verification
- AppKit window frames indeed use bottom-left origin. Therefore:
  - Bottom edge = `frame.origin.y`.
  - Top edge = `frame.origin.y + frame.size.height`.
- Translating to SnapUtils (top-left) occurs only inside `WindowSnapManager`; `resizeMainAndEQWindows` works directly with AppKit coordinates, so comparing playlist top to EQ bottom is correct for stacked layout.

## Likely Failure Modes
1. **Orientation mismatch**: When playlist is docked to EQ's side, `xAligned` fails (left origins differ) even though windows are magnetically connected.
2. **Tolerance drift**: SnapManager uses `< SNAP_DISTANCE` whereas detection uses `<= 15`. If windows are exactly 15 px apart (because of drop shadows or shade mode), detection returns false even though SnapManager still considers them connected (< 15 vs <= 15 difference).
3. **Shade offsets**: Shade height differences may cause `playlistTop` vs `eqBottom` to differ by > 15 even when windows look docked, because shading uses different sprite heights (14 px) but playlist height is 232 px.
4. **Timing**: SnapManager disables adjustments during programmatic resize. If playlist slides slightly (Subpixel), `originalPlaylistFrame` could already include a 1 px gap introduced by previous animation, but logging is absent to confirm.

## References
- `MacAmpApp/ViewModels/WindowCoordinator.swift`
- `MacAmpApp/Utilities/WindowSnapManager.swift`
- `MacAmpApp/Models/SnapUtils.swift`
