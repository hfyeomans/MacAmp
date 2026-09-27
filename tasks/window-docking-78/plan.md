# Plan: Window Docking, Minimize, Persistence, Windowshade & Sleep/Wake (#78)

> **Status:** APPROVED (decisions D1–D5, owner, 2026-09-27). Next: Phase 0 runtime experiments.
> **Branch:** `fix/window-docking-78`.
> **Target:** macOS 27; Swift 6.2 language mode on the Swift 6.4 toolchain; strict concurrency, `@MainActor` UI, `@Observable` state. SwiftUI handles content and menu commands (`Commands`). AppKit `NSWindow` stays for the borderless Winamp windows, because SwiftUI can't do docking, custom shapes or group moves (research §3).
> **Research:** `research.md`. **Verification log:** `verification.md`.

## Goals (acceptance)

1. **Moving the group.** Dragging Main moves every window docked to it, including a Playlist docked under a *closed* EQ (#78). Dragging a docked child detaches it, as in Winamp and Webamp. Shift-drag flips snapping.
2. **Minimize.** Main's minimize button, **Cmd+M** and **Option+M** (Winamp Alt+M) from any MacAmp window minimize the whole player to one Dock tile. Restoring brings every window back in the same arrangement.
3. **Windowshade.** **Ctrl+W** (Winamp) toggles Main windowshade. The Main, EQ and Playlist shade strips look like the skin and every control in them works.
4. **Titlebars.** Titlebar and shade-strip buttons are invisible hit areas over the skin bitmap. They draw only the window's **own** pressed or shade-state sprites, and there are no minimize buttons that aren't in Winamp.
5. **Persistence.** Across launches, each window's position, open/closed state (EQ and Playlist included) and shade state is restored.
6. **Sleep/wake and displays.** After sleep/wake, a display change or launch, no window is unreachable. Docked groups move back on screen **as a unit** and stay docked.
7. **Recovery.** A "Reset Window Positions" command restores the default Winamp stack on the main screen.
8. **No regressions.** Double-size, snapping, always-on-top, focus and the Video/Milkdrop windows keep working. The full TSan suite passes (only the pre-existing #86 may fail).

## Decisions (owner, 2026-09-27)

- **D1: joining.** A closed window keeps its saved frame, still links the docking chain, and moves with the group. The EQ reopens in place.
- **D2: minimize is the Winamp model, reachable from every window.**
  - Winamp and Webamp have two separate modes, verified in Winamp's accelerator table (Winamp 5.02 SDK `lang_b/main.rc:1953,1965`):
    - **Minimize** (`WINAMP_MINIMIZE`, Alt+M, Main's titlebar button) sends the whole player to the taskbar. EQ and Playlist hide with it and everything restores together (Winamp `main_wndproc.cpp:68-108`; Webamp `MINIMIZE_WINAMP`, `webampLazy.tsx:441`).
    - **Windowshade** (`WINAMP_OPTIONS_WINDOWSHADE`, Ctrl+W, per-window shade buttons) collapses a window to its skin's shade strip, the compact "mini player".
  - In MacAmp:
    - **Main's minimize button, Cmd+M and Option+M** from any MacAmp window (Video and Milkdrop included) minimize the whole player.
    - **Ctrl+W** toggles Main windowshade. The existing Cmd+Option+1/2/3 shade shortcuts stay.
- **D3: a lost display.** Windows move to an available screen, docked groups as a unit, and stay there.
- **D4: Winamp extras.**
  - Shift-drag flips snapping.
  - Snap distance changes 15 → **10 px** (Winamp default, `config.h:100`). The same value is the docking-detection tolerance.
- **D5: extra minimize buttons.** Remove the non-Winamp minimize buttons from the EQ and Playlist titlebars. The group can still be minimized with Main's button, Cmd+M or Option+M.
- **Plan review:** no separate review; the single Codex review happens before the PR (Phase 7). The owner can ask for one.

## Design

### A. Docking graph that includes closed windows (D1, D4)

- Today, clusters are computed from visible windows only (`WindowSnapManager.swift:104,366`).
- A new **pure function** `DockGraph.cluster(from:frames:visible:snapDistance:) -> Set<WindowKind>` computes Main's cluster at mouse-down over **all registered windows**. A closed window uses its last saved frame as a connector. The function has no AppKit dependency, so it is unit-testable. `WindowSnapManager` calls it and moves the whole cluster, closed windows included.
- Snapping during a drag still targets visible windows only.
- Shift held at mouse-down flips snapping for that drag.
- `SnapUtils.SNAP_DISTANCE` becomes 10.
- **Re-anchoring:** shade/unshade and double-size change a window's height, so docked neighbours below move by the height delta to stay attached. Winamp does this with `set_aot(1)` (`Set.cpp:914-937`) and Webamp with `withWindowGraphIntegrity` (`actionCreators/windows.ts:22-50`). MacAmp already does it for double-size (`WindowResizeController.swift:105-149`); extend it to shade toggles on Main, EQ and Playlist.
- **System moves:** today the Video, Milkdrop and Playlist resize paths move windows without the `isAdjusting` guard (`WindowResizeController.swift:209-240`, `WinampPlaylistWindow.swift:65,69`). Wrap them so `windowDidMove` doesn't re-cluster.

### B. Visibility and shade persistence (single source of truth)

- `AppSettings` gains persisted `showEqualizerWindow` and `showPlaylistWindow` (`didSet` → UserDefaults, like `showVideoWindow`). `showAllWindows()` honours them.
- EQ shade (local `@State`, `WinampEqualizerWindow.swift:13`) and Playlist shade (`ui.isShadeMode`) become persisted settings. Main shade already persists.
- `DockingController` / `DockLayoutV1` is a second visibility model that is never read at launch and is out of sync (`toggleMain()` never touches the window). Remove it, or reduce it to what's actually used, whichever the Phase 1 audit shows is smaller. Record it in `depreciated.md`.

### C. Screen guard (off-screen recovery, D3)

`WindowScreenGuard` is a new `@MainActor` type owned by `WindowCoordinator`.

**Pure function:** `ScreenClamp.clamp(clusters:frames:screens:) -> [WindowKind: NSRect]`.
- For each docked cluster, and for each lone window:
  - choose the screen whose `visibleFrame` has the largest intersection with the union of the frames, or `NSScreen.main` if none
  - compute **one delta** that brings the union inside that `visibleFrame`, and apply it to every member
- If the union is larger than the screen, pin its top-left corner.

This is Webamp's cluster shift (`ensureWindowsAreOnScreen`) applied per cluster. Winamp's per-window clamp would break stacks.

**Triggers:**
- after launch restore
- on `NSApplication.DidChangeScreenParametersMessage`
- on `NSWorkspace.DidWakeMessage` / `ScreensDidWakeMessage`, as a hint only

All triggers are coalesced by a debounce, `screenSettleDelay`: a named constant with a UserDefaults override, default 0.75 s. The observers use the macOS 27 typed `MainActorMessage` API and keep `ObservationToken`s, which are torn down in `stop()`.

**Moves:** guard moves are wrapped in `isAdjusting` and persisted like any other move.

**Recovery command:** "Reset Window Positions" is a SwiftUI `CommandGroup` item in the Windows menu. It runs the existing default-stack layout on the main screen, then persists. Its shortcut is chosen in Phase 3 so it doesn't clash with existing bindings.

### D. Minimize (D2, D5)

- Main's `BorderlessWindow` gains `.miniaturizable`.
- `BorderlessWindow` overrides `performMiniaturize(_:)`, and validates the menu item, so Cmd+M works from **any** MacAmp window without beeping. Phase 0 experiment 1 settles this.
- `WindowVisibilityController.minimizeKeyWindow()` becomes `minimizeApp()`:
  - record which windows are open
  - `orderOut` the non-Main windows
  - `miniaturize` Main
- On `NSWindow.DidDeminiaturizeMessage` for Main, re-show the recorded set, then run the screen guard.
- Main's minimize button, Cmd+M and Option+M all route through `minimizeApp()`. Only Main gets a Dock tile.

### E. Titlebar buttons: faithful hit areas (D5)

Winamp and Webamp draw titlebar buttons as part of each window's **background bitmap**. The app only places invisible hit areas on top and draws the window's **own** pressed sprite while clicked, plus the shade-state glyph in shade mode.

**Webamp references:**
- Selectors: Main `skinSelectors.ts:254-261,286-288`; EQ `:200-214`; Playlist `:130-135`.
- Positions:
  - Main: minimize, shade and close at x=244/254/264, y=3.
  - EQ: shade x=254, close x=264, with no minimize (`equalizer-window.css:55-67`).
  - Playlist: shade right−12, close right−2, with no minimize (`playlist-window.css:242-254`).
- The playlist's bottom-right mini-transport is pure hit areas (`PlaylistActionArea.tsx:19-23`). MacAmp already does this correctly (`PlaylistBottomControlsView.swift:90-96`), and it is the pattern to reuse.

**MacAmp today:**
- The EQ and Playlist permanently draw the **Main** titlebar's `MAIN_MINIMIZE/SHADE/CLOSE_BUTTON` sprites over their own titlebar art (`WinampEqualizerWindow.swift:136-163`, `PlaylistTitleBarButtons.swift:12-31`), which is wrong for any skin whose Main buttons differ.
- Each adds a minimize button that isn't in the skin (EQ x=244, Playlist right−26). D5 removes them.

**Fix:**
- EQ and Playlist shade and close become hit areas at the Winamp positions, using that window's own pressed or shade-state sprites via `SpriteResolver` semantic IDs.
- Main gets audited to the same pattern.
- The removed minimize buttons are recorded in `depreciated.md`.

### F. Windowshade strips (D2)

Every control in a shade strip is part of the strip's bitmap:
- Buttons are invisible hit areas. Webamp keeps `background: none` even while pressed.
- Only sliders draw a thumb sprite.

The owner notes that some shade-view buttons may not work yet, so this is a **functional** audit as well as a visual one.

| Window | Shade strip (skin) | Controls (Webamp positions) | MacAmp today | Work |
|---|---|---|---|---|
| **Main** | `MAIN_SHADE_BACKGROUND` (`titlebar.bmp`) | Titlebar buttons as in E; the shade glyph uses `MAIN_SHADE_BUTTON_SELECTED`. **Transport** hit areas at top 2, height 10: prev 169 (w7), play 176 (w10), pause 186 (w9), stop 195 (w9), next 204 (w10), eject 215 (w10). **Position** mini-slider at 226,4, 17×7 with a 3×7 thumb (`main-window.css:427-500`). | Transport draws full-size `cbuttons` sprites scaled to 0.6 (`MainWindowShadeLayer.swift:28-56`); the titlebar draws sprites (`:104-133`); no eject; the position slider is unaudited. | Replace with hit areas at those positions; add eject and the position slider if missing; verify every control works. |
| **EQ** | EQ shade strip (`eqmain.bmp`) | Shade (x=254) and close (x=264) hit areas; the pressed shade-state glyph is `EQ_MINIMIZE_BUTTON_ACTIVE`. **Volume** and **balance** mini-sliders with thumb sprites (Webamp `EqualizerShade.tsx:27-28`). | Shade-mode sliders and buttons are unaudited; the titlebar uses `MAIN_*` sprites (E). | Hit areas with EQ's own sprites; working volume and balance sliders. |
| **Playlist** | Playlist shade strip (PLEDIT) | Track title and time text; shade (right−12) and close (right−2) hit areas with `PLAYLIST_*_SELECTED` pressed sprites (`PlaylistShade.tsx:59-71`). | `PlaylistShadeView` reuses `PlaylistTitleBarButtons` (`PlaylistShadeView.swift:33`). | Same fix as E; verify the title and time render and both buttons work. |
| **Video / Milkdrop** | No Winamp shade mode | — | — | Out of scope; they only take part in the group minimize. |

A per-button checklist lives in `verification.md`.

## Phases

| Phase | Work | Verification |
|---|---|---|
| 0 | Runtime experiments 1–6 (research §4, plus the Cmd+M menu-validation check). Uses a debug build with temporary logging, removed before commit. | Findings in `verification.md` §Phase 0; plan adjusted if needed. |
| 1 | B: visibility and shade persistence (EQ, Playlist); `DockingController` cleanup. | Unit tests (settings round-trip, `showAllWindows` honours flags); manual relaunch. |
| 2 | A: `DockGraph` with closed windows keeping the chain; snap distance 10 px; Shift-drag; re-anchor neighbours on shade/unshade; guard the resize moves. | Unit tests (closed EQ, transitive chains, detached child, 10 px tolerance); manual #78 repro. |
| 3 | C: `ScreenClamp`, `WindowScreenGuard`, "Reset Window Positions". | Unit tests (cluster fits/overflows, multi-screen, Dock left, union larger than screen); manual sleep/wake, display unplug, resolution change. |
| 4 | E and F: titlebar and shade-strip hit areas, working shade controls; remove EQ and Playlist minimize (D5). | Per-button checklist in `verification.md`; manual with 3+ skins. |
| 5 | D: group minimize; Cmd+M, Option+M, Ctrl+W. | Manual: button, Cmd+M and Option+M from each window, Ctrl+W, Dock restore, restore then off-screen. |
| 6 | Docs:<br>• fix the two stale `MULTI_WINDOW_ARCHITECTURE.md` statements<br>• document docking, recovery, minimize, windowshade and the shortcuts<br>• fix the triage note (#78 EQ reopens) | Link checker. |
| 7 | Full TSan suite, one Codex review, PR (closes #78). | CI green. |

## Out of scope

- Child-window (`addChildWindow`) docking (research §3).
- Remembering per-display layouts (D3).
- Shade mode for the Video and Milkdrop windows.
- Changes to the Video/Milkdrop resize model beyond guarding their moves with `isAdjusting`.

## Risks

- **Wake timing:** screens may reappear late. Mitigated by debouncing and re-running the guard on every screen-parameter change.
- **Borderless minimize quirks** (beep, a disabled menu item, animation): settled by Phase 0 before any building.
- **Moving closed windows with the group** could surprise someone who parked the EQ elsewhere. It only happens when the EQ was docked when closed, which is the #78 intent.
- **Snap 15 → 10 px:** saved layouts with an 11–15 px gap will no longer count as docked. This is rare, because snapping leaves 0 px gaps; the first Main drag re-snaps within 10 px.
- **Skin variety:** some skins may lack a pressed or shade sprite. `SpriteResolver` falls back to its transparent placeholder, and hit areas still work.
