# State — window-init-position-bug

- Added `windowDebugLoggingEnabled` to `AppSettings` (defaults to `true`) so QA can flip verbose window instrumentation without recompiling. `WindowCoordinator` now checks this flag before printing, which enables the missing startup logs even in Release builds.
- `WindowCoordinator` gained persistent window geometry:
  - Writes each window’s frame to `UserDefaults` (debounced 150 ms) whenever the user moves/resizes a window.
  - Restores the saved origins (and playlist height) on launch; if no snapshots exist, we re-stack at the classic defaults and immediately persist that baseline.
  - Programmatic moves (initial sizing, double-size transitions, reset) temporarily suppress persistence to avoid thrashing, then flush once the layout settles.
- Initial double-size sizing now bypasses animations so the default-stack calculation uses the final heights; runtime toggles still animate and keep playlist docking intact.
- Attempted `xcodebuild -scheme MacAmpApp -configuration Debug -destination platform=macOS build` for verification, but it failed early because the sandboxed environment is not allowed to talk to CoreSimulator / ~/Library paths (permission denied). No compiled artifacts were produced.
