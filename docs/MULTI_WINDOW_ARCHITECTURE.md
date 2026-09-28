# MacAmp Multi-Window Architecture (macOS 27+)

## Executive Summary

MacAmp's five Winamp windows (Main, Equalizer, Playlist, Video, Milkdrop) are borderless `NSWindow`s, each owned by an `NSWindowController` subclass and hosting SwiftUI through `NSHostingController`. `WindowCoordinator` creates and coordinates them; it is a thin Facade over focused controllers (registry, persistence, visibility, resize/docking, settings observation, delegate wiring). The SwiftUI scene graph holds only a hidden placeholder `WindowGroup` and the Preferences window.

An earlier research proposal to give Video and Milkdrop their own SwiftUI `WindowGroup(id:)` scenes with per-window state models (`VideoVisualizerState`, `WindowStateStore`, `VisualizerCommands`) was not adopted; none of those types exist. Window-specific details live in [VIDEO_WINDOW.md](VIDEO_WINDOW.md), [MILKDROP_WINDOW.md](MILKDROP_WINDOW.md) and [PLAYLIST_WINDOW.md](PLAYLIST_WINDOW.md).

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [WindowCoordinator Architecture](#windowcoordinator-architecture)
3. [Docking, Recovery, Minimize & Windowshade](#docking-recovery-minimize--windowshade)
4. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
5. [Quick Reference](#quick-reference)

---

## Architecture Overview

### Current MacAmp Architecture

- **App Entry Point**: `MacAmpApp.swift`. `init()` creates the long-lived models, loads the initial skin, creates `WindowFocusState`, then creates `WindowCoordinator` (assigned to `WindowCoordinator.shared` and passed to `AppCommands`).
- **Scene-Level State**: `SkinManager`, `AudioPlayer`, `WindowCoordinator`, `AppSettings` (`AppSettings.instance()`), `RadioStationLibrary`, `StreamPlayer`, `PlaybackCoordinator` and `WindowFocusState`, stored as `@State` in the App struct.
- **Scenes**: a `WindowGroup(id: "main-placeholder")` with a hidden `EmptyView` (launch suppressed, restoration disabled) to satisfy SwiftUI's main-scene requirement, an empty `Settings` scene, and `WindowGroup("Preferences", id: "preferences")`. `.commands` installs `AppCommands` and `SkinsCommands`.
- **Environment Injection**: each window controller injects the shared models into its root view with `.environment(...)` (see the window docs for each window's list).
- **Window infrastructure**:
  - `MacAmpApp/Utilities/WinampWindowConfigurator.swift` – shared NSWindow configuration (`apply(to:)`, `installHitSurface(on:)`)
  - `MacAmpApp/Windows/BorderlessWindow.swift` – borderless window subclass used by every controller
  - `MacAmpApp/Utilities/WindowSnapManager.swift` – magnetic snapping and clusters
  - `MacAmpApp/Utilities/WindowDelegateMultiplexer.swift` – fans `NSWindowDelegate` callbacks out to snap, persistence and focus delegates
  - `MacAmpApp/Models/DockGraph.swift`, `MacAmpApp/Models/ScreenClamp.swift` – pure docking and on-screen geometry (see [Docking, Recovery, Minimize & Windowshade](#docking-recovery-minimize--windowshade))

Shared-state rules (singleton `@Observable @MainActor` models with `didSet` persistence, three-layer split) are covered in the [Architecture Guide](MACAMP_ARCHITECTURE_GUIDE.md#three-layer-architecture-deep-dive) and the [Five-Window NSWindowController Stack](MACAMP_ARCHITECTURE_GUIDE.md#five-window-nswindowcontroller-stack) section.

### Instant Double-Size Docking Pipeline

1. `AppSettings.isDoubleSizeMode` toggles via Ctrl+D / "D" button.
2. `WindowSettingsObserver` detects the change via recursive `withObservationTracking` and fires the `onDoubleSizeChanged` callback.
3. `WindowCoordinator` forwards to `WindowResizeController.resizeMainAndEQWindows()`, which captures the live frames for Main, EQ, Playlist and Video.
4. `makePlaylistDockingContext()` queries `WindowSnapManager.clusterKinds(containing: .playlist)` to discover the current magnetic cluster. If the playlist is touching the EQ (checked first) or Main window, it derives an attachment (`below`, `above`, `left`, `right` with an offset) plus the anchor using `WindowDockingGeometry` pure functions; otherwise it falls back to a heuristic or the last remembered attachment. `makeVideoDockingContext()` does the same for the Video window.
5. Main and EQ resize synchronously (no animation). While `WindowSnapManager` is in programmatic adjustment mode and `WindowFramePersistence` has suppressed writes, the playlist and video windows are re-aligned to their anchor frames, preserving the Winamp stack. Playlist and Video keep their own size.
6. DEBUG logging prints `[DOCKING] source: ...` so QA can see which anchor drove the adjustment.

Any window registered with `WindowSnapManager` (via `WindowDelegateWiring`) can take part: the resize controller asks for its cluster membership and keeps it attached to its anchor.

| File | Role |
|------|------|
| `WindowSettingsObserver.swift` | Detects `isDoubleSizeMode` change |
| `WindowResizeController.swift` | Orchestrates resize + docking context |
| `WindowDockingGeometry.swift` | Pure geometry (attachment detection, origin calculation) |
| `WindowDockingTypes.swift` | Value types (`PlaylistDockingContext`, `PlaylistAttachmentSnapshot`, `VideoAttachmentSnapshot`) |
| `WindowFramePersistence.swift` | Suppresses persistence during programmatic moves |

---

## WindowCoordinator Architecture

### Rationale

`WindowCoordinator` used to be a 1,357-line object with ten unrelated responsibilities (controller ownership, kind mapping, frame persistence, visibility for five windows, double-size resize with docking, settings observation, delegate wiring, docking geometry, docking value types, layout/presentation). It was decomposed so each concern can change and be tested on its own.

### Architecture Decision: Facade + Composition

**Why Facade + Composition (chosen)**:
- Callers keep using `WindowCoordinator.shared.method()`; the Facade forwards to the controllers
- No protocol overhead: controllers are concrete types (one implementation each)
- Acyclic dependency graph: controllers share `WindowRegistry`, `WindowFramePersistence` and `AppSettings` as services but never depend on each other
- @Observable observation chaining: computed property forwarding preserves SwiftUI reactivity

**Why not Actor-based isolation**:
- All window operations must run on the main thread (AppKit requirement)
- @MainActor annotation provides the same isolation guarantee as an actor
- Actors would add unnecessary suspension points for purely main-thread work

### File Structure and Responsibilities

```
MacAmpApp/ViewModels/
    WindowCoordinator.swift           (260 lines) -- Facade + composition root, group minimize
    WindowCoordinator+Layout.swift    (129 lines) -- Layout, presentation, debug logging

MacAmpApp/Windows/
    WindowRegistry.swift              ( 83 lines) -- Window ownership + lookup
    WindowFramePersistence.swift      (160 lines) -- Frame persistence + suppression
    WindowScreenGuard.swift           (181 lines) -- Sleep/wake + display-change recovery
    WindowVisibilityController.swift  (160 lines) -- Show/hide/toggle + @Observable state
    WindowResizeController.swift      (311 lines) -- Resize + docking-aware layout
    WindowSettingsObserver.swift      (113 lines) -- Settings observation lifecycle
    WindowDelegateWiring.swift        ( 54 lines) -- Delegate setup static factory
    WindowDockingTypes.swift          ( 50 lines) -- Value types (Sendable)
    WindowDockingGeometry.swift       (109 lines) -- Pure geometry (nonisolated)
    WindowFrameStore.swift            ( 65 lines) -- UserDefaults wrapper (injectable)
```

| Type | Responsibility | @MainActor | @Observable |
|------|----------------|:----------:|:-----------:|
| `WindowCoordinator` | Composition root, API forwarding | Yes | Yes |
| `WindowCoordinator+Layout` | Init-time layout, skin-ready presentation, debug | Yes (inherited) | -- |
| `WindowRegistry` | Owns the 5 NSWindowControllers, window↔kind mapping, `liveAnchorFrame` | Yes | No |
| `WindowFramePersistence` | Save/restore/suppress frames; restores keep the saved top edge; Video and Milkdrop restore their whole saved frame | Yes | No |
| `WindowScreenGuard` | Keeps windows reachable across sleep/wake and display changes; `clampOnScreen()` | Yes | No |
| `WindowVisibilityController` | Show/hide/toggle for all windows; group minimize | Yes | Yes |
| `WindowResizeController` | Double-size resize, docking context, playlist/video/milkdrop size updates, resize previews | Yes | No |
| `WindowSettingsObserver` | Observes `isAlwaysOnTop`, `isDoubleSizeMode`, `showVideoWindow`, `showMilkdropWindow` | Yes | No |
| `WindowDelegateWiring` | Static factory: per window, registers with `WindowSnapManager` and installs a `WindowDelegateMultiplexer` (snap manager, persistence delegate, `WindowFocusDelegate`) | Yes (struct) | No |
| `WindowDockingTypes` | Value types for docking context | No (Sendable) | No |
| `WindowDockingGeometry` | Pure geometry calculations | nonisolated | No |
| `WindowFrameStore` | JSON-encoded frames in UserDefaults, key `WindowFrame.<kind>` | No | No |

### Dependency Graph (Acyclic)

```
WindowCoordinator (facade / composition root)
    |
    +-- WindowRegistry                (no dependencies on other extracted types)
    |
    +-- WindowFramePersistence        (depends on: WindowRegistry, WindowFrameStore, AppSettings)
    |
    +-- WindowScreenGuard             (depends on: WindowRegistry, WindowFramePersistence)
    |
    +-- WindowVisibilityController    (depends on: WindowRegistry, AppSettings)
    |
    +-- WindowResizeController        (depends on: WindowRegistry, WindowFramePersistence)
    |       |
    |       +-- uses WindowDockingGeometry (static, pure functions)
    |       +-- uses WindowDockingTypes (value types)
    |
    +-- WindowSettingsObserver        (depends on: AppSettings only)
    |
    +-- WindowDelegateWiring          (depends on: WindowRegistry, WindowPersistenceDelegate, WindowFocusState)

WindowRegistry, WindowFramePersistence and AppSettings are shared services;
controllers never depend on each other or on WindowCoordinator.
All cross-cutting coordination goes through the WindowCoordinator facade.
```

When coordination is required (for example, suppressing persistence during resize), the Facade orchestrates it by calling the controllers in sequence.

### @MainActor Isolation Boundaries

Every type that touches `NSWindow` or other AppKit objects is `@MainActor` (`WindowCoordinator` and `WindowVisibilityController` are also `@Observable`). Two are intentionally not:

- **`WindowDockingGeometry`**: `nonisolated struct` with static methods taking `NSRect` and returning `NSRect`/`NSPoint`. No side effects; callable from any isolation domain.
- **`WindowDockingTypes`**: `Sendable` value types (`PlaylistAttachmentSnapshot`, `VideoAttachmentSnapshot`, `PlaylistDockingContext`).

`WindowCoordinator+Layout.swift` inherits `@MainActor` from the base type.

### Swift 6.2 Concurrency Patterns

#### Recursive withObservationTracking

`WindowSettingsObserver` uses the one-shot observation pattern for `@Observable` objects outside SwiftUI view bodies:

```swift
// WindowSettingsObserver.swift
private func observeAlwaysOnTop() {
    tasks["alwaysOnTop"]?.cancel()  // Cancel existing before creating new
    tasks["alwaysOnTop"] = Task { @MainActor [weak self] in
        guard let self else { return }
        withObservationTracking {
            _ = self.settings.isAlwaysOnTop  // Register property access
        } onChange: { [weak self] in  // Weak capture on the @Sendable onChange closure
            Task { @MainActor in  // Nested Task for @Sendable boundary
                guard let self, self.handlers != nil else { return }
                self.handlers?.onAlwaysOnTopChanged(self.settings.isAlwaysOnTop)
                self.observeAlwaysOnTop()  // Re-establish (recursive)
            }
        }
    }
}
```

- **`[weak self]` on the outer Task and on `onChange`** (not the nested Task's capture list), so the closure never holds `self` strongly; `WindowCoordinator+Layout.observeSkinReadiness()` uses the same shape.
- **`self.handlers != nil` guard**: no re-registration after `stop()`.
- **Explicit `start(...)` / `stop()` lifecycle**: `start` installs the four handlers and observers; `stop` cancels all tasks and clears the handlers.

`Observations` (macOS 26+, so available at the macOS 27 minimum) could replace this pattern; it is not adopted yet:

```swift
for await _ in Observations(\.isAlwaysOnTop, on: settings) {
    handlers?.onAlwaysOnTopChanged(settings.isAlwaysOnTop)
}
```

#### Isolated deinit

```swift
// WindowCoordinator.swift
isolated deinit {
    settingsObserver.stop()
    screenGuard.stop()
    if let deminiaturizeToken { NotificationCenter.default.removeObserver(deminiaturizeToken) }
}
```

`WindowCoordinator` uses an `isolated deinit`, so it can call the `@MainActor` `stop()` methods directly. The `[weak self]` captures above still let any in-flight observer task end via `guard let self`.

#### @Observable Observation Chaining

`WindowCoordinator` forwards visibility state from `WindowVisibilityController` through computed properties:

```swift
var isEQWindowVisible: Bool {
    get { visibility.isEQWindowVisible }
    set { visibility.isEQWindowVisible = newValue }
}
```

SwiftUI views observe `WindowCoordinator`; the `@Observable` macro tracks the computed property access and chains it through to `WindowVisibilityController`. Without the forwarding, SwiftUI would not see visibility changes.

#### Debounced Persistence with Cancellation

```swift
// WindowFramePersistence.swift
func schedulePersistenceFlush() {
    guard persistenceSuppressionCount == 0 else { return }
    persistenceTask?.cancel()
    persistenceTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }
        self?.persistAllWindowFrames()
    }
}
```

`try? await Task.sleep` swallows the cancellation error, so the `Task.isCancelled` check after the sleep is what stops a superseded flush from writing.

### File Organization Principles

1. **Facade stays in `ViewModels/`**: `WindowCoordinator` and its layout extension are consumed by SwiftUI views as an `@Observable` model.
2. **Controllers live in `Windows/`**, next to the window controllers and `BorderlessWindow`.
3. **Pure types are nonisolated**: `WindowDockingGeometry` and `WindowDockingTypes` can be called from any context and unit-tested directly (`WindowDockingGeometryTests`).
4. **Static factories for complex construction**: `WindowDelegateWiring.wire(registry:persistenceDelegate:windowFocusState:)` returns an immutable struct holding strong references to the multiplexers and focus delegates (`NSWindow.delegate` is weak).
5. **Injectable dependencies**: `WindowFrameStore(defaults:)` takes a `UserDefaults`, so tests use isolated suites (`WindowFrameStoreTests`).

Refactor plan and final state: `tasks/done/window-coordinator-refactor/`.

---

## Docking, Recovery, Minimize & Windowshade

### Docking

- **Groups are geometric.** Two windows are docked when an edge of one is within `SnapUtils.SNAP_DISTANCE` (10 px, Winamp's default) of an edge of the other and they overlap along the other axis. `DockGraph` (pure, `Models/DockGraph.swift`) computes groups with `cluster(from:boxes:)` / `clusters(boxes:)`.
- **Closed windows keep the chain.** A Main drag moves every window docked to it, including hidden ones (`WindowSnapManager.beginCustomDrag` builds boxes with `includeHidden: true`), so a closed EQ still links Main to the Playlist under it and reopens in place.
- **Shift at mouse-down** turns off snapping to other windows for that drag, and Main moves alone, without its group; the screens still contain the drag.
- **Menu bar:** a drag keeps the group's top edge out of each screen's menu-bar strip (`VirtualScreenSpace.menuBarStrips`).
- **Shade/unshade re-anchoring.** Shading keeps a window's top edge and changes its height. `WindowSnapManager.windowDidResize` moves the windows docked below it (`DockGraph.dockedBelow`) by the height change so the chain stays attached. A window hanging from a window that doesn't move (e.g. Milkdrop under a Video window docked beside Main) stays with it, as does anything hanging from it.
- Programmatic moves are bracketed with `WindowSnapManager.beginProgrammaticAdjustment()` / `endProgrammaticAdjustment()` (nestable); the snap manager ignores moves inside a bracket and re-records frames when it closes.

### Persistence

- **Frames:** `WindowFrameStore` JSON per window, written 150 ms after the last move or resize. Restores keep the saved **top** edge, because the restored height can differ from the saved one (shade, the Playlist height clamp). Video and Milkdrop restore their whole saved frame: their size comes from their SwiftUI content after the restore, and until then the window can be 0 high.
- **Visibility and shade:** `AppSettings` `showEqualizerWindow`, `showPlaylistWindow`, `showVideoWindow`, `showMilkdropWindow`, `isMainWindowShaded`, `isEqualizerWindowShaded`, `isPlaylistWindowShaded`. `WindowVisibilityController` reads and writes these; `showAllWindows()` honours them at launch.

### Off-Screen Recovery (`WindowScreenGuard`)

At launch, and after every settle below, `clampOnScreen()` moves each docked group (and each lone window) back onto a screen as one unit (`ScreenClamp.clamp`): one offset per group; stranded groups that fit together move together; a group larger than the screen keeps its left and top edges visible.

The guard observes `NSApplication` `.didChangeScreenParameters` and `NSWorkspace` `.willSleep` / `.didWake` (macOS 27 typed notifications). A transition snapshots the layout and suppresses snapping and persistence until the screens settle: 1 s after the last screen event, and at least 3 s after wake, because a temporary 1920×1080 screen appears before the real display returns (UserDefaults overrides `screenSettleDelay`, `wakeSettleWindow`). Then:

| Displays after settling | What happens |
|---|---|
| Same displays (sleep/wake) | Snapshot restored, translated per display if the displays were re-based (e.g. a primary-display change) |
| A display was added or returned | macOS returns windows to their display one at a time; each docked group is re-formed rigidly around its anchor (Main, else the first visible member) where macOS put it |
| A display was removed | Snapshot restored so groups stay docked; stranded groups are moved together |

Displays are tracked by `NSScreen.cgDirectDisplayID`. **Options › Reset Window Positions** restores the default stack and clamps it on screen.

### Minimize

Winamp minimizes the whole player. `WindowCoordinator.minimizeApp()` forwards to `WindowVisibilityController.minimizeGroup()`, which hides the other open windows (without changing their persisted visibility) and minimizes Main, the only `.miniaturizable` window and the owner of the player's single Dock tile. On Main's `.didDeminiaturize` the hidden windows that are still open in `AppSettings` return, and the coordinator's `onGroupRestored` hook clamps the group on screen. While the group is minimized, turning a window on only updates its setting; it comes back with Main. "Show Main" restores the group.

`BorderlessWindow` overrides `performMiniaturize(_:)` to call `minimizeApp()`, and `validateUserInterfaceItem(_:)` enables it only when Main is visible and not minimized (`canMinimizeApp`), so Window › Minimize (Cmd+M) works from every MacAmp window instead of beeping. Option+M is disabled the same way while Main is hidden.

### Titlebars and Windowshade Strips

Titlebar and shade-strip buttons are part of the skin bitmaps, so they are `SkinHitButton`s: invisible hit areas that draw only the skin's pressed sprite while held. Each window uses its own sprites (TITLEBAR, EQMAIN/EQ_EX, PLEDIT). EQ and Playlist have only shade and close, as in Winamp. Every shade strip is draggable outside its controls.

| Window | Shade strip (14 px) |
|---|---|
| Main | Options (Winamp menu → Options menu), transport and eject, position mini-slider, TEXT.BMP mini time (click toggles remaining), 38×5 mini visualizer following the visualizer mode, minimize/unshade/close |
| EQ | Volume and balance sliders (3×7 thumbs chosen by thirds), unshade/close |
| Playlist | Current title and track length in TEXT.BMP characters, width-only resize grip, unshade/close; the width follows the Playlist's size |

### Window Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+M, Option+M | Minimize the player (from any MacAmp window) |
| Ctrl+W | Toggle Main windowshade |
| Cmd+Option+1 / 2 / 3 | Shade/unshade Main / Playlist / EQ |
| Cmd+Shift+1 / 2 / 3 | Show/hide Main / Playlist / EQ |
| Ctrl+V, Ctrl+K | Show/hide Video, Milkdrop |
| Ctrl+D | Double size |
| Ctrl+A | Always on top |
| Shift (held at mouse-down) | Drag Main alone, without snapping to other windows |

---

## Common Pitfalls & Solutions

- **Set `contentViewController`** on the hosting window. Main, EQ and Playlist then also assign `contentView = hostingController.view` (the same view, so harmless); never assign a different view as `contentView`, which releases the `NSHostingController` and breaks the SwiftUI lifecycle.
- **Keep delegates alive.** `NSWindow.delegate` is weak, so `WindowDelegateWiring` (and `WindowFramePersistence.persistenceDelegate`) hold the multiplexers and delegates strongly.
- **Bracket programmatic frame changes** with `WindowSnapManager.shared.beginProgrammaticAdjustment()` / `endProgrammaticAdjustment()` and persistence suppression, or the snap manager and frame store react to your own moves.
- **Stay on the main actor.** Window and model types are `@MainActor`; hop with `Task { @MainActor in … }` or `MainActor.run` from background work, and use `[weak self]` in long-lived closures and tasks.
- **Retain `NSMenu`s** you pop up (e.g. in `@State` or an instance variable) until they close.
- **Don't drive SwiftUI bodies from per-frame audio data.** Visualizers pull from `VisualizerPipeline` on timers instead of observing values that change every buffer.

---

## Quick Reference

### Adding a New Window

1. Add a `WindowKind` case (`WindowSnapManager.swift`) and its `persistenceKey` (`WindowFrameStore.swift`).
2. Write an `NSWindowController` subclass: `BorderlessWindow`, `WinampWindowConfigurator.apply(to:)`, root view with `.environment(...)` injection, `contentViewController = NSHostingController(...)`, `installHitSurface(on:)`.
3. Own it in `WindowRegistry` (controller, window accessor, kind mapping, `forEachWindow`).
4. `WindowDelegateWiring` then registers it with `WindowSnapManager` and installs the delegate multiplexer (snap, persistence, focus).
5. Add an `is<Name>Key` flag to `WindowFocusState` and a case in `WindowFocusDelegate`.
6. Add show/hide to `WindowVisibilityController` (forwarded by `WindowCoordinator`), an `AppSettings.show<Name>Window` flag observed by `WindowSettingsObserver`, and a command in `AppCommands`.
7. Decide how `WindowFramePersistence.applyPersistedWindowPositions()` restores it and whether `WindowResizeController` should keep it docked on double-size.

### Key Principles

1. **One NSWindowController per Winamp window**, configured in its initializer via `WinampWindowConfigurator`
2. **@Observable @MainActor** for window and model types
3. **WindowCoordinator is a Facade**: add behaviour to the focused controller, forward from the Facade
4. **Debounce frame persistence** (150 ms) and suppress it during programmatic moves
5. **Weak references** for delegates/targets and in long-lived closures
