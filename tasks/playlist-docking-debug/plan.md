# Plan

## Current Situation
- Instrumentation already logs frames/tolerances inside `resizeMainAndEQWindows` (`MacAmpApp/ViewModels/WindowCoordinator.swift:218-345`). Latest double-size traces show `verticalDelta = 116` even when the playlist appears visually attached (see `double-screenshot2.png`).
- Helper `makePlaylistDockingSnapshot` only handles "playlist directly under EQ" using frame math in AppKit coordinates, so any side-docked playlist (like the screenshot) is always considered undocked.
- Because `isPlaylistDocked` is `false`, the playlist never receives the compensating `setFrame` call after the EQ doubles, which produces the perceived gap.
- `WindowSnapManager` already tracks true adjacency via `boxesAreConnected` (`MacAmpApp/Utilities/WindowSnapManager.swift:148-180`) but that knowledge is unused during the resize. `WindowCoordinator` disables the snap manager while animating, so there is no cluster correction step afterward.
- The reference implementation in `webamp_clone` keeps windows glued by capturing the window graph and propagating size deltas through `getPositionDiff` (see `packages/webamp/js/actionCreators/windows.ts:22-78` and `packages/webamp/js/resizeUtils.ts:1-103`).
- Architecture note (`docs/MULTI_WINDOW_ARCHITECTURE.md:1-120`) confirms that the Winamp trio still relies on `WindowCoordinator` + `WindowSnapManager`, so fixing this layer is compatible with the overall SwiftUI scene design for macOS 15+/Swift 6.

## Goals
1. Detect docking/clusters using the same source of truth as snapping (WindowSnapManager) instead of duplicating heuristics.
2. During double-size toggles, translate every window in the EQ cluster by the EQ's height delta so attached panes stay locked regardless of orientation.
3. Keep instrumentation so QA can verify cluster decisions.
4. Verify visually (playlist to the left/right/below EQ) and via debug logs that deltas stay synchronized.

## Proposed Implementation

1. **Expose snap-cluster queries**
   - Add an @MainActor helper on `WindowSnapManager` that returns the current `Set<ObjectIdentifier>` for the cluster containing a given window kind. Internally reuse the existing `buildBoxes()` + `connectedCluster()` logic so tolerances stay unified.
   - Provide a convenience `func windowsConnected(_ first: WindowKind, _ second: WindowKind) -> Bool` for quick checks.

2. **Use cluster data during resize**
   - In `WindowCoordinator.resizeMainAndEQWindows`, ask the snap manager whether the EQ and playlist are connected prior to disabling snapping.
   - If connected, capture the full cluster (could include Main, Playlist, Milkdrop). After computing the EQ's size delta, apply that delta to every window in the cluster by adjusting their frames synchronously inside the animation group.
   - Fallback: if snap manager returns nil (window not registered yet), retain current behavior but log that cluster info was unavailable.

3. **Keep/debug instrumentation**
   - Extend the existing DEBUG log to print whether the playlist/EQ were in the same cluster and list window IDs inside the cluster. This makes future regressions easier to diagnose.

4. **Verification**
   - Scenario A: Playlist docked beneath EQ → toggle "D" twice, confirm in logs that cluster detection is true and playlist's origin changes by ±EQ height.
   - Scenario B: Playlist docked to EQ's left (per `double-screenshot2.png`) → ensure cluster detection still returns true and the playlist moves horizontally/vertically as needed.
   - Scenario C: Playlist floating (undocked) → confirm cluster detection is false and playlist remains untouched.
   - Regression test idea: add automated unit test around `WindowSnapManager` cluster query once windows are represented by mock boxes.

## Dependencies / Notes
- No changes to SwiftUI WindowGroup scenes are required; work stays inside the AppKit bridge.
- This aligns with Webamp's approach (graph-based adjustments), making it easier to reason about parity between projects.
- Future work could move the entire resize logic into `WindowSnapManager` (similar to Webamp's `withWindowGraphIntegrity`) but the above steps are sufficient to fix the immediate docking regression.
