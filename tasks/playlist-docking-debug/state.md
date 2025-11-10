# State

## Implementation Snapshot (2025-11-09)
- `WindowCoordinator.resizeMainAndEQWindows` now builds a `PlaylistDockingContext` before every CTRL+D toggle. The context records the anchor window (`.equalizer` or `.main`) and the attachment edge (`below/above/left/right`). Frames are updated synchronously (no NSAnimation tween) so the resize jump matches Webamp. See `MacAmpApp/ViewModels/WindowCoordinator.swift` lines 258-356.
- `WindowSnapManager` exposes `beginProgrammaticAdjustment`, `endProgrammaticAdjustment`, and `clusterKinds(containing:)` so we can query the current magnetic cluster without relying on heuristics. See `MacAmpApp/Utilities/WindowSnapManager.swift` lines 1-150.
- Main/Equalizer SwiftUI views (`WinampMainWindow` + `WinampEqualizerWindow`) no longer apply `.animation` to their scale effect, so the instantaneous frame snap coming from `WindowCoordinator` is visible in the UI.
- DEBUG instrumentation prints `[ORACLE] Docking source …` plus `playlist move` logs for every toggle. This makes it trivial to diagnose whether the playlist is attached to Main, EQ, or floating.

## Verification
- **Scenario A (stacked Main/EQ/Playlist)**: PASS. Playlist follows EQ through repeated CTRL+D toggles (100% ↔ 200%).
- **Scenario B (playlist docked to Main)**: PASS for left/right/above/below anchors. Logs show `anchor=main` with the expected attachment enum.
- **Scenario C (undocked playlist)**: PASS. Docking context is `nil` and playlist origin stays fixed while Main/EQ resize.
- **Regression**: Removing the `.animation` modifiers eliminated the visual tween so toggles now match the Webamp jump-cut.

## Watchpoints / Follow-ups
- `WindowSnapManager.clusterKinds` still returns `nil` during very early startup until all three NSWindows register. Current fallback (cached attachment + heuristic) is sufficient but we should monitor logs for any residual "window not registered" spam.
- If future auxiliary windows (Milkdrop, video) need to participate in the double-size stack, extract the attachment alignment logic into a helper inside `WindowSnapManager` so we can shift entire clusters together.
