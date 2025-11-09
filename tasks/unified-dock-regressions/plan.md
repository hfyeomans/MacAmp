# Implementation Plan

1. **Gate NSWindow presentation on skin readiness**
   - Extend `WindowCoordinator` with a stored `skinManager` reference and a `skinPresentationTask`.
   - Add a computed helper (e.g., `isSkinReady`) that checks both `skinManager.currentSkin` and `isLoading`.
   - During initialization, defer `showAllWindows()` until `isSkinReady` becomes true: if a skin already exists (e.g., when relaunching after choosing a skin) present immediately; otherwise spin up a `Task` that polls on the main actor (with short sleeps) until the load completes, then call a new `presentWindows()` helper that activates the app, orders all windows front, and marks an internal `hasPresentedInitialWindows` flag to avoid duplicate work.
   - Cancel the task in `deinit` to avoid stray work items.

2. **Ensure borderless windows forward first-click events**
   - Update `BorderlessWindow` to override `acceptsFirstMouse(for:)` and return `true`, matching the follow-up noted in the migration research. This lets the very first click both activate the window and deliver the control event instead of forcing a second click.
   - While touching this file, keep existing `canBecomeKey`/`canBecomeMain` overrides intact.

3. **Make presentation explicit about focus**
   - After the windows are shown (either immediately or after skin load), call `NSApp.activate(ignoringOtherApps: true)` and ensure each window’s content view becomes the first responder by setting `window.makeFirstResponder(window.contentView)` right after ordering it front. This mirrors the implicit activation that SwiftUI handled inside `UnifiedDockView` and keeps controls receptive.

4. **Verification**
   - Add a light-weight state note (`tasks/unified-dock-regressions/state.md`) capturing that initial presentation is now gated and that first-click activation has been addressed.
   - Manual QA guidance: launch app and confirm there is no blank chrome before the skin appears and that a single click on buttons/sliders triggers behavior while the app is inactive (no “click once to focus” lag).
