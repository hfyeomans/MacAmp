# Magnetic Window Docking – Consolidated Research (Archive)

## Sources
- `tasks/magnetic-window-docking/research.md` (primary discovery log)
- Gemini feasibility analysis (8/10 complexity, 10–16 h estimate)
- Claude analytical notes (architecture validation request)
- Codex review updates (`tasks/magnetic-window-docking/CODEX_REVIEW.md`)
- `docs/MACAMP_ARCHITECTURE_GUIDE.md` (`WindowSnapManager`, docking sections)

## Existing Implementation Highlights
- `WindowSnapManager.swift` already provides:
  - Cluster detection via DFS (`windowDidMove` flow lines 90–170)
  - Multi-monitor coordinate normalization
  - Screen-edge snapping and feedback suppression (`isAdjusting`)
  - Registration API that configures windows for the classic Winamp look
- `SnapUtils.SNAP_DISTANCE` is **15 px** (`MacAmpApp/Models/SnapUtils.swift:27`), conflicting with the previously documented 10 px threshold. **FLAG: update documentation or adjust constant.**
- `DockingController` manages visibility/shade state for unified view; will evolve into visibility coordinator inputs.

## Behavioural Targets (from Winamp/Webamp analysis)
- Three independent NSWindows: Main (275×116), Equalizer (275×116), Playlist (height variable, base 275×232).
- Magnetic docking with zero-gap alignment and partial cluster support (e.g., Main+EQ while Playlist detached).
- Screen-edge snapping identical to classic Winamp.
- Double-size mode toggles must resize all docked windows simultaneously without gaps.
- Custom drag regions (title bar mimic) to preserve control hit-testing.

## Constraint Summary
- AppKit coordinate system (bottom-left) vs SwiftUI (top-left) – `WindowSnapManager` already handles translation.
- `WindowSnapManager` assigns itself as window delegate; additional behaviours (close-to-hide, resize) require delegation multiplexing.
- SwiftUI `WindowGroup` auto-lifecycle conflicts with singleton requirement, motivating NSWindowController approach.
- Persistence must account for monitor reconfiguration; prior unified-state storage only tracked stacked panes.

## Open Questions Resolved
- **Architecture:** Coordinator + controllers chosen over pure SwiftUI scenes to avoid duplicate windows and simplify command integration.
- **Snap Logic:** Reuse existing manager; do not reimplement.
- **Scaling:** Use `setContentSize`/frame updates with pre-snap reposition before re-enabling snapping.
- **Performance:** Need profiling but no blocking issues expected; plan includes Instruments pass.

## Research Gaps / Follow-ups
- Confirm playlist resize gestures emit notifications the coordinator can observe.
- Determine whether shading should change snap bounding boxes (likely treat shaded equalizer as 14 px height).
- Validate persistence schema for multiple monitor signatures (store by NSScreen configuration hash).
- Update public documentation once snap threshold decision made.

This archive file serves as the canonical research digest for magnetic docking and should be updated only when new empirical findings emerge.

