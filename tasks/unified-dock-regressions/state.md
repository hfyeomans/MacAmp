# State

- Implementation complete.
  - `WindowCoordinator` now defers `showAllWindows()` until `SkinManager` finishes its initial load (or fails) via a gated presentation task, and explicitly activates/focuses the NSWindows once.
  - `BorderlessWindow` accepts the first mouse click so buttons and sliders receive input immediately, even when the app was inactive.
- Pending verification: build + manual test to confirm there’s no skin flash on launch and that one click triggers controls.
