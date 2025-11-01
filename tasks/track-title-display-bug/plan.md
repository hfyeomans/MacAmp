## Plan
1. Update `MacAmpApp` to keep a stable `PlaybackCoordinator` instance instead of recreating one on every render.
   - Introduce a stored `@State` (or equivalent) property for the coordinator.
   - Initialize the coordinator with the same `AudioPlayer` and `StreamPlayer` instances already managed by the app.
2. Inject this stable coordinator into the environment in `UnifiedDockView` so all views share the same stateful object.
3. Double-check for any other code paths that relied on the old computed property and ensure they now point to the stored coordinator.
4. Validate manually (or via logs/UI if possible) that `displayTitle` reflects the active track and no longer falls back to `"MacAmp"` during local playback.
