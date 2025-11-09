# Magnetic Window Phase 3 Review — Research

## WindowSnapManager (`MacAmpApp/Utilities/WindowSnapManager.swift`)
- `@MainActor` singleton that both tracks native window drags (`NSWindowDelegate.windowDidMove`) and drives custom drags from SwiftUI.
- Stores weak references to the three Winamp windows, plus `lastOrigins` to calculate user deltas and a guard flag (`isAdjusting`) that suppresses delegate recursion.
- Custom drag path (`beginCustomDrag`/`updateCustomDrag`/`endCustomDrag`) converts AppKit bottom-left coordinates into a top-left "virtual screen" space spanning every attached `NSScreen`. Clusters move via the stored `baseBoxes`, while `SnapUtils.snapToMany` + `snapWithin` ensure against drift.
- Screen clamping currently treats the union of monitors as a single bounding rectangle (`VirtualScreenSpace.bounds`), which may allow windows to enter gaps when displays are vertically offset.

## Drag Capture Stack
- `TitlebarDragCaptureNSView` (`MacAmpApp/Views/Shared/TitlebarDragCaptureView.swift`) forwards mouse events to `WindowSnapManager`. It tracks the initial screen-point, emits cumulative deltas, and flips `isDragging` but does not override `acceptsFirstMouse`, so inactive windows require two clicks before dragging.
- `WinampTitlebarDragHandle` (`MacAmpApp/Views/Shared/WinampTitlebarDragHandle.swift`) composes the invisible capture layer with the sprite art inside a fixed-size, top-leading `ZStack`. Content is `allowsHitTesting(false)` so all events go to the capture view.

## Window Orchestration
- `WindowCoordinator` (`MacAmpApp/ViewModels/WindowCoordinator.swift`) is `@Observable @MainActor` and is instantiated once from `MacAmpApp`. It builds three `NSWindowController`s, applies default borderless configuration, stacks windows at hard-coded positions, and waits for `SkinManager` before presenting.
- Always-on-top sync uses `withObservationTracking` on `AppSettings.isAlwaysOnTop`, respawning the observer task whenever the preference toggles. The initial presentation task polls every 50 ms until `skinManager` reports ready, but it does not currently respect cancellation (loop ignores `Task.isCancelled`).
- Delegate multiplexers (`WindowDelegateMultiplexer`) sit between the windows and actual delegates so `WindowSnapManager` (and future handlers) can observe `NSWindowDelegate` callbacks simultaneously.

## Window Controllers & Configuration
- Each Winamp window gets its own `NSWindowController` (`MacAmpApp/Windows/Winamp{Main,Equalizer,Playlist}WindowController.swift`) that instantiates a `BorderlessWindow`, injects the SwiftUI view through an `NSHostingController`, and applies shared chrome tweaks via `WinampWindowConfigurator`.
- `WinampWindowConfigurator` standardizes the style mask, mouse move acceptance, translucency, and installs a nearly transparent backing layer to avoid hit-testing gaps. `BorderlessWindow` overrides `canBecomeKey`/`canBecomeMain` so borderless windows behave like standard ones.

## SwiftUI Views
- `WinampMainWindow.swift` recreates the full chrome with absolute positioning helpers. Track info scrolling relies on an imperative `Timer` that mutates `scrollOffset`, and the timer is restarted via `resetScrolling()` even when the incoming text no longer needs scrolling.
- `WinampEqualizerWindow.swift` mirrors Winamp's EQ layout, exposes shade mode, and uses `NSOpenPanel` + `UniformTypeIdentifiers` to import `.eqf` presets.
- `WinampPlaylistWindow.swift` composes the playlist chrome (tiles, titlebar handle, controls) and delegates menu actions to `PlaylistWindowActions`, an `@MainActor` helper that marshals open panels, alerts, and playlist mutations.

## Utilities
- `WindowDelegateMultiplexer.swift` forwards every `NSWindowDelegate` callback to an array of delegates, using AND semantics for `windowShouldClose` so all listeners must consent.
- `SnapUtils.swift` holds the float math for magnetic snapping (overlap detection, bounding boxes, screen clamp, etc.) and is used both by the delegate path and the custom drag loop.
