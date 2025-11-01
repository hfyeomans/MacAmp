# Current State

- Research complete: confirmed active window composition flows in `MacAmpApp/MacAmpApp.swift`, `MacAmpApp/Views/UnifiedDockView.swift`, and `MacAmpApp/Views/DockingContainerView.swift` only instantiate Winamp-prefixed window views.
- Verified via `rg` that modern window variants (`MainWindowView`, `PlaylistWindowView`, `EqualizerWindowView`) have no call sites outside their definitions/previews.
- Confirmed legacy slider components (`VolumeSliderView`, `BalanceSliderView`, `EQSliderView`, `BaseSliderControl`) are only referenced by the unused modern windows.
- `SimpleTestMainWindow` has no references from production code; exists as standalone test harness.
- Ready to draft verification summary and recommendations.
