# Plan: Window Docking, Minimize, Persistence, Windowshade & Sleep/Wake (#78)

> **Status:** APPROVED (decisions D1–D5, owner, 2026-09-27). **Phases 0–2 ✅.** Next: Phase 3.
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
- **D3: displays coming and going** (revised by the owner, 2026-09-27, after Phase 3 testing).
  - **Lost display:** windows move to an available screen, docked groups as a unit. Stranded groups move together when they fit, keeping their arrangement.
  - **Display returns or is added:** **let macOS return the windows**. macOS remembers each window's display and moves it back; MacAmp doesn't undo that, and only clamps anything still unreachable.
  - This replaces the original "move and keep": restoring the saved layout after a display returned caused a visible jump back.
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

**What Phase 0 showed** (`verification.md` exp 3–4): on wake, macOS first reports a **temporary 1920×1080 screen** and moves every window onto it **one at a time**, which splits docked groups. It posts `didChangeScreenParameters` *before* `didWake`. The real screen returns about 1.3 s after `didWake`, and the last screen change comes about 1.7 s after it. Our `windowDidMove` cluster logic chased these system moves.

**Layout snapshot:** on `NSWorkspace.WillSleepMessage` (and on the first `DidChangeScreenParametersMessage` of a burst while awake), save every window's frame **as the user left it** into `intendedLayout`. Current frames after a transition can't be trusted to show docking.

**Transition mode:** between the snapshot and the settle run, `isScreenTransition = true`. While it is set:
- `WindowSnapManager.windowDidMove` ignores moves, so no cluster chasing.
- `WindowFramePersistence` doesn't save, so the split layout isn't persisted.

**Settle run** (debounced; re-run on every event in the burst):
1. restore `intendedLayout`
2. run `ScreenClamp` per docked cluster against the current screens (D3: groups move as a unit)
3. persist
4. end transition mode once no screen event has arrived for `screenSettleDelay`

**Timing:**
- `screenSettleDelay` is a named constant with a UserDefaults override, **default 1.0 s**.
- Additionally the transition stays open for at least `wakeSettleWindow` (named constant, **default 3.0 s**) after `didWake`, so a lull between the temporary and the real screen can't end it early. Phase 0 measured a 1.3 s lull.
- Restoring then clamping is idempotent, so extra runs are harmless.

**Triggers:**
- after launch restore (restore persisted frames, then clamp)
- `NSApplication.DidChangeScreenParametersMessage`
- `NSWorkspace.WillSleepMessage` for the snapshot
- `NSWorkspace.DidWakeMessage` / `ScreensDidWakeMessage` to start the wake window

The observers use the macOS 27 typed `MainActorMessage` API (`ScreensDidWakeMessage` is an `AsyncMessage`, so it hops to the main actor) and keep `ObservationToken`s, torn down in `stop()`.

**Governing rule (owner, 2026-09-27: "tackle window flow broadly, not in every bespoke way"):** a docked group is **rigid**. Across any display change or sleep/wake it may move as a whole, but its members keep their relative offsets. The cases below differ only in where the group's anchor goes: Main, else the first visible member of main/eq/playlist/video/milkdrop.

**Settle cases (after the owner's Phase 3 test, 2026-09-27):**
- **Same displays** (sleep/wake): restore the snapshot, translated by each display's origin change, then clamp.
- **Display added or returned:** the anchor stays where macOS put it and the other members are placed at their snapshot offsets (`ScreenClamp.rigid`), then clamp. macOS returns windows one by one and not exactly, and the Playlist lost its dock on re-plug. Restoring saved *absolute* frames after the built-in became primary re-based the LG from (0,0) to (1800,−431) and dragged windows onto the built-in display.
- **Display removed:** restore the snapshot so groups stay docked (translated for surviving displays), then clamp; stranded groups move together when they fit (`ScreenClamp.translate` + `clamp`).

The guard tracks display frames by `NSScreen.cgDirectDisplayID` (macOS 26+).

**Moves:** guard moves are wrapped in `isAdjusting` and persisted once the settle run ends.

**Top-edge overlap (owner, 2026-09-27; screenshots 7:26:09 → 7:26:22 → 7:26:33 PM):**
- **Symptom:** dragging Main (with the EQ docked under it) to the very top of the LG makes the EQ slide *under* Main. The EQ's titlebar is hidden behind Main's bottom by about one titlebar, ~28–30 px at double size. Clicking the EQ brings it to the front, overlapping Main.
- **Why it matters:** the group should move as one, so a member was shifted relative to the others.
- **Hypothesis to confirm first with logging:** ~30 px is the LG's menu-bar height (1600 − 1570 `visibleFrame`). Either macOS constrains only one member (e.g. the key window) out of the menu-bar area, or the group snap (`snapWithinUnion` against `visibleFrame`) and per-window placement disagree at the top edge.
- **Fix:** keep the group's relative offsets. Apply one delta to all members and clamp the group's union to the top of `visibleFrame`, sharing the `ScreenClamp` logic.

**Windows taller than the screen:** the Playlist was seen at 1566 px, taller than the usable height. The clamp pins the top edge so the titlebar stays reachable. Phase 3 also traces why the Playlist grew from 900 → 1566 during restore.

**Recovery command:** "Reset Window Positions" is a SwiftUI `CommandGroup` item in the Windows menu. It runs the existing default-stack layout on the main screen, then persists. Its shortcut is chosen in Phase 3 so it doesn't clash with existing bindings.

### D. Minimize (D2, D5)

- Main's `BorderlessWindow` gains `.miniaturizable`.
- `BorderlessWindow` overrides `validateUserInterfaceItem(_:)` to return **true** for `performMiniaturize(_:)`, and overrides `performMiniaturize(_:)` to call `minimizeApp()`. Phase 0 exp 2 showed that without this, Window › Minimize is greyed out on the non-miniaturizable windows and Cmd+M beeps, because the action is never sent. Exp 1 confirmed that `.miniaturizable` on Main minimizes and restores cleanly.
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
| **EQ** | EQ shade strip (`eqmain.bmp`) | Shade/**unshade** (x=254; the baked glyph looks like two small overlapping windows) and close (x=264) hit areas; the pressed shade-state glyph is `EQ_MINIMIZE_BUTTON_ACTIVE`. **Volume** slider at 61,4, 97×6, and **balance** slider at 164,4, 43×6, each with a 3×7 thumb (`equalizer-window.css:11-44`, `EqualizerShade.tsx:27-28`). | **Owner screenshot (2026-09-27):** `buildShadeMode()` uses a centre-aligned `ZStack` with `.at()` children, so everything is misplaced: the unshade button doesn't respond, and the slider thumbs render as three yellow bars in the middle. The sliders are static sprites, not controls. In the screenshot the baked tracks appear at ~x 5–57 and ~208–250 (1×), **not** Webamp's 61–158 / 164–207. Either this skin differs or `EQ_SHADE_BACKGROUND` is cut from the wrong region: **settle it in Design G with the owner.** | Hit areas with EQ's own sprites; working volume and balance sliders. |
| **Playlist** | Playlist shade strip (PLEDIT) | Track title and time text; shade (right−12) and close (right−2) hit areas with `PLAYLIST_*_SELECTED` pressed sprites (`PlaylistShade.tsx:59-71`). | `PlaylistShadeView` reuses `PlaylistTitleBarButtons` (`PlaylistShadeView.swift:33`). | Same fix as E; verify the title and time render and both buttons work. |
| **Video / Milkdrop** | No Winamp shade mode | — | — | Out of scope; they only take part in the group minimize. |

**Dragging shaded windows (owner, 2026-09-27):** none of the three shade views has a `WinampTitlebarDragHandle`. Only the full EQ (`WinampEqualizerWindow.swift:76`) and full Playlist (`WinampPlaylistWindow.swift:153`) views do, so a shaded window can't be moved. In Winamp the whole shade strip, outside its buttons, is the drag area, and a shaded Main still drags its docked group. Add drag handles to the Main, EQ and Playlist shade strips beneath the button hit areas.

A per-button checklist lives in `verification.md`.

### G. Sprite surfacing follow-up (owner, 2026-09-27)

The EQ and Main bitmaps (`eqmain.bmp`, `titlebar.bmp`, `main.bmp`) likely contain sprites MacAmp has never defined, because this area hadn't been worked on. **Do this at the start of Phase 4, before E and F: surface the missing sprites and settle their coordinates together with the owner.** Don't guess coordinates.

**Candidates (name comparison, 2026-09-27).** 11 of the 52 relevant Webamp names in `webamp_clone/packages/webamp/js/skinSprites.ts` have no exact match in `MacAmpApp/Models/SkinSprites.swift`. Some may already exist under another name, so check before adding:
- **EQ titlebar:** `EQ_CLOSE_BUTTON`, `EQ_CLOSE_BUTTON_ACTIVE`, `EQ_MAXIMIZE_BUTTON_ACTIVE_FALLBACK`
- **Main titlebar:** `MAIN_OPTIONS_BUTTON`, `MAIN_OPTIONS_BUTTON_DEPRESSED`
- **Main shade:** `MAIN_SHADE_BUTTON_SELECTED`, `MAIN_SHADE_BUTTON_SELECTED_DEPRESSED`, `MAIN_SHADE_POSITION_BACKGROUND`, `MAIN_SHADE_POSITION_THUMB`, `MAIN_SHADE_POSITION_THUMB_LEFT`, `MAIN_SHADE_POSITION_THUMB_RIGHT`

**Process:**
1. Confirm each against the bitmap: open the default skin's BMP, check it against Webamp's coordinates, and verify with the owner.
2. Add them as `SpriteResolver` semantic IDs; never hard-code sprite names.
3. Record each one in `verification.md`.

## Phases

| Phase | Work | Verification |
|---|---|---|
| 0 | Runtime experiments 1–6 (research §4, plus the Cmd+M menu-validation check). Uses a debug build with temporary logging, removed before commit. | Findings in `verification.md` §Phase 0; plan adjusted if needed. |
| 1 | B: visibility and shade persistence (EQ, Playlist); `DockingController` removed. | Manual relaunch checks. There are no unit tests because `AppSettings` is a singleton over `UserDefaults.standard`, and the app-hosted tests would overwrite the owner's real settings. Full TSan suite. |
| 2 | A: `DockGraph` with closed windows keeping the chain; snap distance 10 px; Shift-drag; re-anchor neighbours on shade/unshade; guard the resize moves. | Unit tests (closed EQ, transitive chains, detached child, 10 px tolerance); manual #78 repro. |
| 3 | C: `ScreenClamp`, `WindowScreenGuard`, "Reset Window Positions". | Unit tests (cluster fits/overflows, multi-screen, Dock left, union larger than screen); manual sleep/wake, display unplug, resolution change. |
| 4 | G (first): surface the missing EQ/Main sprites and settle coordinates with the owner. Then E and F: titlebar and shade-strip hit areas, working shade controls; remove EQ and Playlist minimize (D5). | Per-button checklist in `verification.md`; manual with 3+ skins. |
| 5 | D: group minimize; Cmd+M, Option+M, Ctrl+W. | Manual: button, Cmd+M and Option+M from each window, Ctrl+W, Dock restore, restore then off-screen. |
| 6 | Docs:<br>• fix the two stale `MULTI_WINDOW_ARCHITECTURE.md` statements<br>• document docking, recovery, minimize, windowshade and the shortcuts<br>• fix the triage note (#78 EQ reopens) | Link checker. |
| 7 | Full TSan suite, one Codex review, PR (closes #78). | CI green. |

## Out of scope

- Child-window (`addChildWindow`) docking (research §3).
- Remembering per-display layouts beyond what macOS already does (D3).
- Shade mode for the Video and Milkdrop windows.
- Changes to the Video/Milkdrop resize model beyond guarding their moves with `isAdjusting`.

## Risks

- **Wake timing (measured):** a temporary 1080p screen appears, then the real screen comes back about 1.3 s after `didWake`. Mitigated by the sleep snapshot, transition mode, and the 3 s wake window plus re-running on every event.
- **Borderless minimize quirks** (beep, a disabled menu item, animation): settled by Phase 0 before any building.
- **Moving closed windows with the group** could surprise someone who parked the EQ elsewhere. It only happens when the EQ was docked when closed, which is the #78 intent.
- **Snap 15 → 10 px:** saved layouts with an 11–15 px gap will no longer count as docked. This is rare, because snapping leaves 0 px gaps; the first Main drag re-snaps within 10 px.
- **Skin variety:** some skins may lack a pressed or shade sprite. `SpriteResolver` falls back to its transparent placeholder, and hit areas still work.
