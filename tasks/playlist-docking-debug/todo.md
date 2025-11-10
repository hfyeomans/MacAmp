# TODO

1. **Expose cluster queries in WindowSnapManager**
   - Add an @MainActor API (e.g., `cluster(for kind: WindowKind) -> Set<WindowKind>` or boolean convenience) that reuses the existing `connectedCluster` logic so docking detection matches snap tolerances.
   - Include DEBUG logging when the cluster cannot be computed (window unregistered) so the coordinator can fall back gracefully.

2. **Consume cluster info during double-size resize**
   - In `WindowCoordinator.resizeMainAndEQWindows`, ask the snap manager whether EQ and Playlist share a cluster before disabling snapping.
   - If connected, capture all affected NSWindows and translate them by the EQ height delta inside the animation group; retain current behavior when no cluster is available.

3. **Extend instrumentation**
   - Update the existing DEBUG printout to show cluster membership (window kinds and boolean flag) so QA can confirm why the playlist was or was not moved.

4. **Verification pass**
   - Manually test three layouts: playlist below EQ, playlist to the left/right (per `double-screenshot2.png`), and playlist floating. Confirm logs and on-screen behavior stay in sync.
   - Document the verification results in `state.md` and capture any remaining edge cases for future work.
