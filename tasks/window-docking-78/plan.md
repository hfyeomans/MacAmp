# Plan: Window Docking, Minimize, Persistence & Sleep/Wake (#78)

> **Status:** APPROVED DECISIONS D1–D4 (2026-09-27). Next: Phase 0 runtime experiments.
> **Branch:** `fix/window-docking-78`. **Target:** macOS 27, Swift 6.2 language mode on the Swift 6.4 toolchain, strict concurrency, `@MainActor` UI, `@Observable` state. SwiftUI for content and commands; AppKit (`NSWindow`) stays for the borderless Winamp windows (see research §3).
> **Research:** `research.md`.

## Goals (acceptance)

1. **Moving the group.** Dragging Main moves every window docked to it, including a Playlist docked under a *closed* EQ (#78). Dragging a docked child still detaches it, as in Winamp and Webamp.
2. **Minimize.** The minimize button and Cmd+M minimize MacAmp, and the windows come back together in the same arrangement.
3. **Persistence.** Across launches, MacAmp restores each window's position, whether it is open (EQ and Playlist included), and its shade state.
4. **Sleep/wake and displays.** After sleep/wake, a display change or launch, no window is left unreachable. Docked groups move back on screen **as a unit** and stay docked.
5. **Recovery command.** A "Reset Window Positions" command restores the default Winamp stack on the main screen.
6. **No regressions.** Double-size, shade, snapping, always-on-top, focus and the Video/Milkdrop windows keep working. Tests pass under TSan.

## Decisions (owner, 2026-09-27)

- **D1 = (a):** a closed window keeps its saved frame, still links the docking chain, and moves with the group. The EQ reopens in place.
- **D2 = Winamp model, extended to every window.**
  - In Winamp and Webamp only the Main window has a minimize button, and it minimizes the whole player: EQ and Playlist hide with it and everything restores together (Winamp `main_wndproc.cpp:68-108`; Webamp `MINIMIZE_WINAMP` → host callback, `webampLazy.tsx:441`).
  - The EQ and Playlist have only shade and close. Webamp's "EQ_MINIMIZE" sprite is its shade toggle (`skinSelectors.ts:201`).
  - MacAmp: the Main minimize button, MacAmp's EQ and Playlist minimize hit areas (`WinampEqualizerWindow.swift:137`, `WinampPlaylistWindow.swift:51,109`), and Cmd+M from **any** MacAmp window (Video and Milkdrop included) all minimize the whole player to one Dock tile and restore it together.
  - Windowshade stays the compact "mini player".
- **D3 = (a):** when a display is lost, move windows to an available screen (docked groups as a unit) and keep them there.
- **D4 = both:**
  - Holding Shift during a drag flips snapping.
  - Snap distance changes 15 → **10 px** (Winamp default, `config.h:100`). The same value is the docking-detection tolerance.
- **Plan review:** skipped as a separate step to save a review round. The one Codex review happens before the PR (Phase 7). The owner can ask for a plan review.

## Design

### A. Docking graph that includes closed windows (D1a)

Today, clusters are computed from visible windows only (`WindowSnapManager.swift:104,366`). The change:
- Compute Main's cluster at mouse-down over **all registered windows**. A closed window uses its last saved frame and acts as a connector.
- Move the whole cluster, closed windows included, so their saved frames stay attached.

The cluster logic moves into a **pure function**: `DockGraph.cluster(from:frames:visible:snapDistance:) -> Set<WindowKind>`. It works on plain frame values and has no AppKit dependency, so it can be unit-tested. `WindowSnapManager` calls it.

Snapping during a drag still targets visible windows only.

### B. Visibility and shade persistence (single source of truth)

- `AppSettings` gains persisted `showEqualizerWindow` / `showPlaylistWindow` (didSet → UserDefaults, like `showVideoWindow`).
- `showAllWindows()` honors them.
- EQ shade becomes a persisted setting instead of local `@State`. Playlist shade persists through its existing model.
- `DockingController`/`DockLayoutV1`'s visibility role is out of sync and never read at launch. Either delete it or reduce it to what's actually used, whichever the audit in Phase 1 shows is smaller, and record the removal in `depreciated.md`.

### C. Screen guard (off-screen recovery)

`WindowScreenGuard` is a new `@MainActor` type owned by `WindowCoordinator`.

**Pure function:** `ScreenClamp.clamp(clusters:frames:screens:) -> [WindowKind: NSRect]`.
- For each docked cluster, and for each lone window:
  - choose the screen whose `visibleFrame` has the largest intersection with the union of the frames, or `NSScreen.main` if none
  - compute **one delta** that brings that union inside the chosen `visibleFrame`, and apply it to every member
- If the union is larger than the screen, pin its top-left corner.

This is Webamp's cluster shift applied per cluster; Winamp's per-window clamp would break stacks.

**Triggers:**
- after launch restore
- on `NSApplication.DidChangeScreenParametersMessage`
- on `NSWorkspace.DidWakeMessage` / `ScreensDidWakeMessage`, as a hint only

All triggers are coalesced by a debounce, `screenSettleDelay`: a named constant with a UserDefaults override, default 0.75 s. The macOS 27 typed `MainActorMessage` observers use `ObservationToken`s that are torn down in `stop()`.

**Rules for moves:**
- Guard moves are wrapped in `isAdjusting`, so `windowDidMove` doesn't re-cluster mid-move.
- The resize paths that aren't wrapped today get the same treatment.
- Guard moves are persisted like any other move (D3a).

**Recovery command:** "Reset Window Positions" (SwiftUI `CommandGroup` in the Windows menu, with a shortcut to confirm) runs the existing default-stack layout on the main screen, then persists.

### D. Minimize (D2: Winamp model, every window)

- `BorderlessWindow` gains `.miniaturizable`, and overrides `performMiniaturize(_:)` to call `miniaturize(_:)` so Cmd+M doesn't beep. Experiment 1 decides whether `.miniaturizable` goes on Main only or on all windows.
- `WindowVisibilityController.minimizeKeyWindow()` becomes `minimizeApp()`:
  - record which windows are open
  - `orderOut` the non-Main windows
  - `miniaturize` Main
- On `NSWindow.DidDeminiaturizeMessage` for Main, re-show the recorded set, then run the screen guard.
- The Main sprite button, the EQ and Playlist minimize hit areas, and Cmd+M from any MacAmp window (via `BorderlessWindow.performMiniaturize`) all route through `minimizeApp()`. Only Main gets a Dock tile.

## Phases

| Phase | Work | Verification |
|---|---|---|
| 0 | Runtime experiments 1–5 (research §4), using a debug build and temporary logging that is removed before commit | Findings recorded in `research.md` |
| 1 | B: visibility and shade persistence; `DockingController` cleanup | Unit tests (settings round-trip, `showAllWindows` honours flags); manual relaunch |
| 2 | A: `DockGraph` pure function plus cluster including closed windows; bracket unguarded moves | Unit tests (graph with closed EQ, transitive chains, detached child); manual #78 repro |
| 3 | C: `ScreenClamp` pure function plus `WindowScreenGuard` plus the Reset command | Unit tests (cluster fits/overflows, multi-screen, Dock left, union larger than screen); manual sleep/wake, display unplug, resolution change |
| 4 | D: minimize | Manual: button, Cmd+M, Dock restore, restore then off-screen |
| 5 | D4: Shift-drag flips snapping; `SNAP_DISTANCE` 15 → 10 (and docs) | Unit tests (snap and cluster at 10 px); manual |
| 6 | Docs: fix the two stale `MULTI_WINDOW_ARCHITECTURE.md` statements, document docking, recovery and minimize; fix the triage note | Link checker |
| 7 | Full TSan suite, one Codex review, PR (closes #78) | CI green |

## Out of scope

- Child-window (`addChildWindow`) docking (research §3).
- Remembering per-display layouts (D3b).
- Changes to the Video/Milkdrop resize model beyond wrapping their moves in `isAdjusting`.

## Risks

- **Wake timing:** screens may reappear late. Mitigated by debouncing and re-running the guard on every screen-parameter change.
- **Borderless minimize quirks:** mitigated by experiment 1 before building.
- **Moving closed windows with the group** could surprise a user who deliberately parked the EQ elsewhere. It only happens if the EQ was docked when closed, which is the #78 intent.
