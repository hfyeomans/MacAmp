# Research: Window Docking, Minimize, Persistence & Sleep/Wake (#78)

> Issue [#78](https://github.com/hfyeomans/MacAmp/issues/78) (@Crater-Dude, 2026-04-08): the player and playlist can't be moved together without detaching the playlist ("can't be permanently joined/clamped"); minimize doesn't work; window state isn't persisted (the EQ has to be closed on every launch).
>
> Owner addition (2026-09-26): after the Mac sleeps and wakes, windows that were apart can end up off-screen and can't be recovered. Docked windows should still be docked after wake.
>
> Sources: three read-only research passes on 2026-09-26 covering MacAmp code (file:line), Webamp and Winamp, and the macOS 27 SDK.

## 1. How MacAmp works today (branch base `0d6e258`)

| Area | Finding | Where |
|---|---|---|
| Windows | All five windows are `BorderlessWindow` with `styleMask: [.borderless]`; Playlist is `[.borderless, .resizable]`. None has `.miniaturizable`. `isRestorable = false`. There are no child windows; windows stay together only through the snap manager. | `Windows/BorderlessWindow.swift:4-6`, `WinampPlaylistWindowController.swift:10`, `Utilities/WinampWindowConfigurator.swift:11-36` |
| Docking | Docking isn't stored anywhere. Clusters are recomputed from geometry at mouse-down: windows within 15 px count as connected (`SnapUtils.SNAP_DISTANCE`), and only **visible** windows are considered. | `SnapUtils.swift:27`, `WindowSnapManager.swift:104,166-198,366` |
| Drag | `beginCustomDrag`: Main drags its connected cluster. Every other window drags alone, so dragging a docked window detaches it. | `WindowSnapManager.swift:237-243` |
| #78 root cause | With the EQ closed, the Playlist sits 116 px (232 px at double size) below Main, so it isn't in Main's cluster and stays behind. | geometry above |
| System moves | `windowDidMove` moves the cluster for any move not bracketed by `isAdjusting`, including moves the system makes. The cluster is computed after the moved window has already left, so a system relocation can split a group. Some resize paths aren't bracketed either. | `WindowSnapManager.swift:74-163`, `WindowResizeController.swift:209-240`, `WinampPlaylistWindow.swift:65,69` |
| Frame persistence | `WindowFrame.<kind>` JSON, with a 150 ms debounce on move and resize. On restore there is **no on-screen check**. | `WindowFrameStore.swift:50-63`, `WindowFramePersistence.swift:45-121` |
| Visibility persistence | Only Video and Milkdrop visibility persist. `showAllWindows` always opens the EQ and Playlist. `DockingController`/`DockLayoutV1` is a second visibility model that is never read at launch and is out of sync (`toggleMain()` never touches the window). | `AppSettings.swift:42-43,256-270`, `WindowVisibilityController.swift:119-125`, `ViewModels/DockingController.swift:74` |
| Shade persistence | EQ shade is local `@State` and Playlist shade is `ui.isShadeMode`; neither persists. Main shade does. | `WinampEqualizerWindow.swift:13` |
| Minimize | The sprite minimize buttons call `NSApp.keyWindow?.miniaturize(nil)` on a window without `.miniaturizable`, which does nothing or beeps. That affects only the key window, never the group. Cmd+M sends `performMiniaturize:` to the same windows. | `WindowVisibilityController.swift:21-23` |
| Sleep/wake/screens | **Nothing is handled.** No screen-parameter, wake or `windowDidChangeScreen` observers, no clamp to `visibleFrame`, and no `constrainFrameRect` override. Off-screen frames are persisted and restored as they are. There is no "reset window positions" command. | whole app |
| Tests | Only `DockLayoutV1` round-trip, `WindowDockingGeometry` and `WindowFrameStore` tests. Snap clusters, restore, visibility and clamping are untested. | `Tests/MacAmpTests` |

The code also contradicts the docs in two places:
- `MULTI_WINDOW_ARCHITECTURE.md` says "never set `contentView`", but the Main, EQ and Playlist controllers set it.
- The same doc describes `DockingController` as the visibility model, but it isn't wired to the windows.

The triage note (`tasks/github-issues-triage/state.md:30`) has the EQ complaint backwards: the EQ *reopens* on every launch.

## 2. What Webamp and Winamp do

Winamp facts come from the Nullsoft source (2.25 and 5.x, with the same docking code). They were read to learn the behaviour; none of it is copied.

- **Neither has an explicit "join" feature.** Attachment is worked out from geometry each time the main window is pressed, and it is never saved.
  - Webamp: `snapUtils.ts:151-167`, `WindowManager.tsx:125-138`.
  - Winamp: `Ui.cpp:280-305`.
- **Only a Main drag moves the group.** Dragging the EQ or Playlist moves that window alone, which detaches it; it then re-snaps.
  - Webamp: `WindowManager.tsx:65-79`.
  - Winamp: `Equi.cpp:329-343`, `Peui.cpp:590-594`.
- **"Attached" is a transitive closure over visible windows.**
  - Winamp requires edges to touch exactly (`DOCK.cpp:89-107`).
  - Webamp counts windows within 15 px as touching (`WindowManager.tsx:10-15`).
  - A closed window breaks the chain in both, so MacAmp's #78 behaviour matches the originals.
- **Winamp defaults:**
  - Snapping is on, snap distance is 10 px, and keep-on-screen is on (`config.h:100,103`).
  - Holding Shift during a drag flips snapping.
- **Off-screen recovery:**
  - Webamp's `ensureWindowsAreOnScreen` (`actionCreators/windows.ts:237-298`) shifts **all windows by one offset** if their combined bounding box fits the viewport, so the layout is kept. Otherwise it stacks and centres them. It runs on viewport resize and on state load.
  - Winamp clamps **each window** to its monitor on display change (250 ms timer) and at startup (`Set.cpp:949-1030`). That can break a docked stack.
- **Minimize:** Winamp's minimize button minimizes Main and hides the EQ and Playlist. There is one taskbar button, and restoring shows the whole set again (`main_wndproc.cpp:68-108`). Windowshade is a separate per-window collapse.
- **Persisted state:**
  - Winamp saves the frame plus the open and shade flags for each window (`wx`, `wy`, `eq_open`, `pe_open`, `windowshade`, `eq_ws`, `pe_width`/`pe_height`, `dsize`), and never saves attachment.
  - Webamp saves position, size, open and shade per window (`reducers/windows.ts:238-256`).
- **Neither** has a "reset window positions" command.

## 3. Apple APIs for macOS 27 / Swift 6.4 (SDK-verified unless marked)

- **Keeping windows on screen:**
  - AppKit's `constrainFrameRect(_:to:)` only constrains **titled** windows, and only their top edge, so borderless windows need our own clamp.
  - Clamp against `NSScreen.visibleFrame`, which excludes the menu bar and Dock (NSScreen.h:39-40).
  - Choose the screen with the largest intersection, falling back to `NSScreen.main`.
- **Notifications:**
  - `NSApplication.didChangeScreenParametersNotification`, delivered on the main actor.
  - `NSWorkspace.didWakeNotification` and `screensDidWakeNotification`, observed on `NSWorkspace.shared.notificationCenter`.
  - `NSWindow.didChangeScreenNotification`.
- **Typed notifications, new in the macOS 27 SDK:**
  - `NSApplication.DidChangeScreenParametersMessage`, `NSWindow.DidMoveMessage`, `DidMiniaturizeMessage`, `DidDeminiaturizeMessage` and `NSWorkspace.DidWakeMessage` are `MainActorMessage`s.
  - `ScreensDidWakeMessage` is an `AsyncMessage`, so hop to the main actor.
  - API shape: `NotificationCenter.default.addObserver(of:for:)` returns an `ObservationToken`.
- **Wake timing (inferred):** displays often re-enumerate after `didWake`, and `NSScreen.screens` can briefly be incomplete. Treat wake as a hint and clamp after `didChangeScreenParameters` or a short debounce.
- **Minimize:**
  - Needs `.miniaturizable` in the style mask.
  - `performMiniaturize(_:)` beeps when the window has no minimize button, which is likely for borderless windows (inferred). Call `miniaturize(_:)` directly, and route Cmd+M by overriding `performMiniaturize` in `BorderlessWindow`.
- **Child windows (`addChildWindow`):** children follow the parent's moves, which suits Main-drags-group. The costs:
  - it has to be a strict tree, re-parented on every dock or undock
  - the stacking order is fixed
  - focus gets tricky
  - it conflicts with the existing custom drag and snapping

  Not recommended as the docking model (inferred; untested).
- **Persistence:** `isRestorable` state restoration suits titled windows only and doesn't capture docking or visibility. `setFrameAutosaveName` saves frames only. Keep the existing UserDefaults stores.
- **SwiftUI can't replace the AppKit windows:** relative `WindowPlacement` positions are `@available(macOS, unavailable)`, and nothing in SwiftUI provides custom shapes, snapping or group moves. SwiftUI stays the content layer, and the menu command can use SwiftUI `Commands`.

## 4. Runtime experiments still needed

Now tracked, with results, in `verification.md` §Phase 0 (experiments 1–6).
