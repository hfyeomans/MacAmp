# Magnetic Window Docking – Codex Review

## Architecture
- Phase 2 & 3 in the existing plan rebuild snapping logic that already exists; consolidate around integrating `WindowSnapManager` and spend the saved effort on drag regions, persistence, and lifecycle plumbing.
- Raw `WindowGroup`s risk duplicate instances and flaky close/restore behaviour. Prefer dedicated `NSWindowController`s (or scene activation management) to keep the three window singletons in sync with menus.
- Introduce a main-actor `WindowCoordinator` that owns the three window references, surfaces visibility to commands, and feeds `WindowSnapManager` before removing `UnifiedDockView`.

## WindowSnapManager
- **FLAG:** Snap distance is hard-coded to 15 px in `SnapUtils` (`MacAmpApp/Models/SnapUtils.swift:27`), conflicting with the 10 px documented threshold. Update either the constant or the docs/todos to avoid regression.
- The manager already performs cluster detection, edge snapping, and multi-display transforms; integration should just register windows and avoid duplicating algorithms.
- Add resize or layout hooks so playlist resizing, shading, and double-size transitions keep clusters flush.

## Double-Size Mode
- Each decoupled window must drive its `NSWindow` frame on toggle; otherwise AppKit crops the scaled content. Synchronize `setContentSize` calls and adjust origins to keep docked stacks aligned.
- Inject a post-scale correction through `WindowSnapManager` (or a manual cluster recompute) because scale animations do not fire move notifications.

## State Management
- Keep `WindowCoordinator` on the main actor with weak `NSWindow` references to avoid retain cycles. Ensure menu toggles round-trip through the coordinator so visibility and persistence stay coherent.
- `WindowSnapManager` installs itself as the window delegate; if additional delegate callbacks (close-to-hide, resize) are required, add a delegate multiplexer instead of overwriting.

## Risk Assessment
- Overall risk is closer to 8/10 (High). Key risks: window lifecycle drift, double-size alignment bugs, delegate conflicts, drag UX regression once title bars vanish, and persistence restoring off-screen clusters after monitor changes. Each needs explicit mitigation (singleton controllers, coordinated resize routine, delegate hub, early drag prototype, bounds normalization).

## Implementation Order
- Perform drag-region work immediately after splitting windows; otherwise users lose the ability to move borderless windows.
- Merge “snap detection” and “group movement” into a single integration phase using the existing manager, freeing time for menu/state plumbing and resize reconciliation.

## Testing
- Add unit coverage for `SnapUtils`/`WindowSnapManager` cluster math to protect the snap threshold and cluster behaviour.
- Expand manual tests to cover double-size toggles while docked/detached, shading transitions, close/reopen flows, and monitor hot-plug scenarios.
- Consider XCUI smoke tests for rapid drag cycles to catch performance regressions.

## Final Scores & Recommendations
- Feasibility: **7/10** (achievable, but lifecycle/state work increases effort over the documented 8/10).
- Implementation Risk: **High**.
- Time: **12–18 hours** after factoring lifecycle controllers, drag regions, and persistence edge cases.
- Top actions: (1) pick and document the window lifecycle strategy before coding; (2) integrate the existing snap manager instead of recreating it; (3) prototype the double-size toggle with docked windows to verify alignment and performance.

