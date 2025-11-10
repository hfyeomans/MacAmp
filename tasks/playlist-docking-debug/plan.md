# Plan

## Current Situation
- `WindowCoordinator` now drives double-size toggles via `PlaylistDockingContext` (anchor + attachment) and repositions the playlist synchronously. No AppKit animation is used, so CTRL+D instantly snaps between 100 % and 200 %.
- `WindowSnapManager` exposes `clusterKinds(containing:)`, `areConnected`, and begin/end programmatic adjustment, letting the coordinator ask for the current magnetic cluster without fighting windowDidMove callbacks.
- Instrumentation prints `[ORACLE] Docking source …` plus per-stage frame dumps, making regression analysis straightforward.
- Manual verification has passed for stacked, side-docked (left/right/above/below), and floating playlists; see `state.md`.

## Goals (Remaining)
1. Keep documentation in sync (architecture, quick-start, README) so future work follows the new docking pipeline.
2. Monitor startup logs to ensure `clusterKinds` only returns `nil` before registration completes; capture any anomalies.
3. Explore sharing the attachment logic with upcoming auxiliary windows (Milkdrop/video) so entire clusters can resize in lockstep.

## Verification Plan (Completed)
- **Scenario A – Stacked Main/EQ/Playlist** → PASS
- **Scenario B – Playlist docked to Main or EQ on any edge** → PASS
- **Scenario C – Playlist undocked** → PASS

## Notes / Future Considerations
- If we add more windows to the magnetic cluster, consider moving the attachment math into `WindowSnapManager` so it can translate entire groups without helper code inside `WindowCoordinator`.
- Automated UI coverage around CTRL+D would prevent regressions; add when time permits.
