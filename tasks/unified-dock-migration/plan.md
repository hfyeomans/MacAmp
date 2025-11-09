## Goal
Restore the critical behavior that lived in `UnifiedDockView` while continuing the multi-window architecture introduced in `WindowCoordinator`.

## Constraints & Inputs

- The coordinator owns instances of `Winamp{Main|Equalizer|Playlist}WindowController` and therefore has access to their `window` properties immediately after initialization.
- `AppSettings` exposes shared state such as `isAlwaysOnTop`, `isDoubleSizeMode`, and material flags.
- Controllers already receive `skinManager`, `audioPlayer`, `dockingController`, `settings`, `radioLibrary`, and `playbackCoordinator` during construction.

## Plan

1. **Skin auto-loading (Critical)**  
   - Add a coordinator-level guard that calls `skinManager.loadInitialSkin()` before windows render.  
   - Ensure this runs exactly once at app launch to keep startup logic centralized.

2. **Always-on-top propagation (Critical)**  
   - Adopt Observable/AppSettings change notifications.  
   - Option A: mark `AppSettings` as `Observable` and store a `@ObservationTracking` relationship so `WindowCoordinator` reacts automatically.  
   - Option B: expose `AppSettingsPublisher` via Combine and let `WindowCoordinator` hold `AnyCancellable`s that adjust each window’s `level`.  
   - Regardless of mechanism, apply the new level to all windows immediately after `WindowCoordinator` is initialized and whenever the setting flips.

3. **Window configuration baseline (Critical)**  
   - Extract the logic that used to live in `configureWindow(_:)` into a reusable helper (e.g., `WinampWindowConfigurator.apply(to:)`).  
   - Invoke it from each `Winamp*WindowController` right after creating the `BorderlessWindow`.  
   - Ensure toolbar removal, title visibility, background dragging behavior, and level defaults match the legacy implementation.

4. **WindowAccessor responsibilities (Important)**  
   - Maintain references to each `NSWindow` inside `WindowCoordinator` (already available via controllers).  
   - When certain settings require dynamic adjustments (e.g., double-size resizing in the future), drive them from coordinator methods instead of view-level `WindowAccessor`.

5. **Double-size scaling (Deferred)**  
   - For independent windows, scaling requires resizing the `contentView` and window frame.  
   - Capture requirements now (per-pane base sizes) but implement after the three-window layout stabilizes.

6. **Animations / Liquid glass backgrounds (Deferred)**  
   - Keep the logic in SwiftUI views for now; future work can reintroduce materials as overlays per pane if desired.

7. **Environment observation strategy (Critical for Day 2)**  
   - Decide on a single mechanism (Observation or Combine) for `WindowCoordinator` to watch `AppSettings`.  
   - Build a small dispatcher that updates each controller/window when relevant properties change.

8. **Borderless window validation (Day 1)**  
   - Confirm subclass overrides cover all cases or determine if we need custom `acceptsFirstMouse`, `canBecomeKey`, etc.  
   - Document optional additions (e.g., forwarding `sendEvent` for keyboard focus quirks).

## Deliverables

- Documentation/migration strategy (current request).  
- Implementation tasks for Day 1 (skin loading + focus) and Day 2 (always-on-top).  
- Follow-up tasks for double-size scaling and animations.
