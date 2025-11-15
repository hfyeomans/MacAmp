# State
- Research complete. Bugs confirmed in `VideoWindowChromeView` titlebar layout and resize gesture state handling.
- Playlist window uses fixed chrome, so video titlebar needs bespoke centering logic anchored to `pixelSize.width / 2`.
- `WindowSnapManager` already exposes `beginProgrammaticAdjustment()` for suspending snap feedback during scripted size updates.
- Implementation pending; need to adjust titlebar sprite positions and refactor resize gesture `@State`.
