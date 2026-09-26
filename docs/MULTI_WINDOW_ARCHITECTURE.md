# MacAmp Multi-Window Architecture (macOS 27+)

## Executive Summary

MacAmp's five Winamp windows (Main, Equalizer, Playlist, Video, Milkdrop) are borderless `NSWindow`s, each owned by an `NSWindowController` subclass and hosting SwiftUI through `NSHostingController`. `WindowCoordinator` creates and coordinates them; it is a thin Facade over focused controllers (registry, persistence, visibility, resize/docking, settings observation, delegate wiring). The SwiftUI scene graph holds only a hidden placeholder `WindowGroup` and the Preferences window.

An earlier research proposal to give Video and Milkdrop their own SwiftUI `WindowGroup(id:)` scenes with per-window state models (`VideoVisualizerState`, `WindowStateStore`, `VisualizerCommands`) was not adopted; none of those types exist. Window-specific details live in [VIDEO_WINDOW.md](VIDEO_WINDOW.md), [MILKDROP_WINDOW.md](MILKDROP_WINDOW.md) and [PLAYLIST_WINDOW.md](PLAYLIST_WINDOW.md).

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [WindowCoordinator Architecture](#windowcoordinator-architecture)
3. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
4. [Quick Reference](#quick-reference)

---

## Architecture Overview

### Current MacAmp Architecture

- **App Entry Point**: `MacAmpApp.swift`. `init()` creates the long-lived models, loads the initial skin, creates `WindowFocusState`, then creates `WindowCoordinator` (assigned to `WindowCoordinator.shared` and `dockingController.windowCoordinator`).
- **Scene-Level State**: `SkinManager`, `AudioPlayer`, `DockingController`, `AppSettings` (`AppSettings.instance()`), `RadioStationLibrary`, `StreamPlayer`, `PlaybackCoordinator` and `WindowFocusState`, stored as `@State` in the App struct.
- **Scenes**: a `WindowGroup(id: "main-placeholder")` with a hidden `EmptyView` (launch suppressed, restoration disabled) to satisfy SwiftUI's main-scene requirement, an empty `Settings` scene, and `WindowGroup("Preferences", id: "preferences")`. `.commands` installs `AppCommands` and `SkinsCommands`.
- **Environment Injection**: each window controller injects the shared models into its root view with `.environment(...)` (see the window docs for each window's list).
- **Window infrastructure**:
  - `MacAmpApp/Utilities/WinampWindowConfigurator.swift` – shared NSWindow configuration (`apply(to:)`, `installHitSurface(on:)`)
  - `MacAmpApp/Windows/BorderlessWindow.swift` – borderless window subclass used by every controller
  - `MacAmpApp/Utilities/WindowSnapManager.swift` – magnetic snapping and clusters
  - `MacAmpApp/Utilities/WindowDelegateMultiplexer.swift` – fans `NSWindowDelegate` callbacks out to snap, persistence and focus delegates
  - `MacAmpApp/ViewModels/DockingController.swift` – pane visibility (Main, Playlist, Equalizer) for the menu commands

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
- Acyclic dependency graph: no controller-to-controller dependencies
- @Observable observation chaining: computed property forwarding preserves SwiftUI reactivity

**Why not Actor-based isolation**:
- All window operations must run on the main thread (AppKit requirement)
- @MainActor annotation provides the same isolation guarantee as an actor
- Actors would add unnecessary suspension points for purely main-thread work

### File Structure and Responsibilities

```
MacAmpApp/ViewModels/
    WindowCoordinator.swift           (218 lines) -- Facade + composition root
    WindowCoordinator+Layout.swift    (129 lines) -- Layout, presentation, debug logging

MacAmpApp/Windows/
    WindowRegistry.swift              ( 83 lines) -- Window ownership + lookup
    WindowFramePersistence.swift      (147 lines) -- Frame persistence + suppression
    WindowVisibilityController.swift  (145 lines) -- Show/hide/toggle + @Observable state
    WindowResizeController.swift      (305 lines) -- Resize + docking-aware layout
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
| `WindowFramePersistence` | Save/restore/suppress frames; Video and Milkdrop restore origin only | Yes | No |
| `WindowVisibilityController` | Show/hide/toggle for all windows | Yes | Yes |
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

NO controller-to-controller dependencies.
All cross-cutting coordination goes through WindowCoordinator facade.
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
}
```

`WindowCoordinator` uses an `isolated deinit`, so it can call the `@MainActor` `stop()` directly. The `[weak self]` captures above still let any in-flight observer task end via `guard let self`.

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

## Common Pitfalls & Solutions

- **Set `contentViewController`, never `contentView`,** on the hosting window; setting `contentView` releases the `NSHostingController` and breaks the SwiftUI lifecycle.
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
