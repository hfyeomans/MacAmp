# State

- Added debug instrumentation + docking helper per plan; see `MacAmpApp/ViewModels/WindowCoordinator.swift` for the latest code.
- `resizeMainAndEQWindows` now logs frame + tolerance data (DEBUG only) and reuses the helper to determine docking via horizontal overlap + SnapUtils tolerance.
- Outstanding follow-up: consider exposing a public `WindowSnapManager` query to detect playlist/equalizer cluster membership for even richer diagnostics.
