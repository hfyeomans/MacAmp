# TODO

1. **Documented Rollout**  
   - Update `docs/MULTI_WINDOW_ARCHITECTURE.md`, `docs/MULTI_WINDOW_QUICK_START.md`, and `docs/README.md` to describe the new `WindowCoordinator`/`WindowSnapManager` double-size pipeline and instant animation change.

2. **Startup Telemetry**  
   - Add a lightweight log counter (or QA checklist) to flag if `clusterKinds` returns `nil` after all three NSWindows register. This guards against regressions when the docking stack expands.

3. **Future Windows**  
   - Prototype extending the attachment logic to upcoming visualizer windows (Milkdrop, Video). Capture the plan in docs once design is settled.

4. **Automation Hook**  
   - Consider adding a UI test harness (AX client) that toggles CTRL+D and asserts playlist offsets so docked behavior stays covered.
