# Research: WinampMainWindow Layer Decomposition

> **Purpose:** Consolidated findings from Gemini deep research and Oracle (Codex) code review.
> Both sources independently converged on the same target architecture, confirming this is the correct path.

## Problem Statement

WinampMainWindow currently spans two files via a cross-file extension pattern:

| File | Lines | Role |
|------|-------|------|
| `MacAmpApp/Views/WinampMainWindow.swift` | ~386 | Root struct, body, layout coords, some builders |
| `MacAmpApp/Views/WinampMainWindow+Helpers.swift` | ~508 | Scrolling, scrubbing, transport, options menu, remaining builders |

To make the extension pattern work across files, **7 `@State` properties were widened from `private` to `internal`**:

```swift
@State var isScrubbing: Bool = false
@State var wasPlayingPreScrub: Bool = false
@State var scrubbingProgress: Double = 0.0
@State var scrollOffset: CGFloat = 0
@State var scrollTimer: Timer?
@State var pauseBlinkVisible: Bool = true
@State var isViewVisible: Bool = false
```

Plus one menu reference:
```swift
@State var activeOptionsMenu: NSMenu?
```

This is **tactical debt**, not proper architecture. Extensions share the same type, so all `@State` must be `internal` minimum for cross-file access. This defeats SwiftUI's design intent where `@State` is `private` to the owning view.

## Gemini Research Findings

### Why Cross-File Extensions Are Wrong for SwiftUI Views

1. **No recomposition boundary:** Extensions on the same struct are still ONE SwiftUI view body. SwiftUI cannot independently recompute `buildTransportButtons()` vs `buildTrackInfoDisplay()` -- any `@State` or `@Environment` change re-evaluates the *entire* body.

2. **Forced access widening:** Swift requires `internal` minimum for cross-file access within the same module. This is why 7 `@State` vars lost their `private` qualifier.

3. **No dependency isolation:** Every extension method can read every `@Environment` and `@State`. There is no compile-time enforcement that `buildVolumeSlider` only depends on `audioPlayer.volume`.

4. **Lint-driven, not architecture-driven:** The split was done to satisfy `type_body_length` / `file_length` SwiftLint rules, not to create meaningful boundaries.

### Gemini's Recommended Architecture

Separate **child view structs** that receive only what they need:

- Each child struct is a distinct SwiftUI `View` type
- SwiftUI can independently schedule body re-evaluations per child
- Dependencies are explicit through init parameters and `@Binding`
- `@State` stays `private` (or moves to `@Observable` shared state)

### Performance Analysis (Gemini)

Current: Any change to `AudioPlayer`, `PlaybackCoordinator`, `AppSettings`, `SkinManager`, `DockingController`, or `WindowFocusState` triggers full body re-evaluation of the 900-line combined view.

Target: Only the specific child view that depends on the changed value re-evaluates. For example, volume slider change only re-evaluates `MainWindowSlidersLayer`.

## Oracle (Codex) Code Review Findings

### Convergence with Gemini

Oracle independently reached the same conclusions:

1. **@Observable interaction state class** is the correct pattern for shared mutable state that multiple child views need (scrubbing, scrolling, pause blink)
2. **Separate View structs** (not extensions) are required for real recomposition boundaries
3. **Coords should be a standalone type** (not nested struct) since child views need it
4. **Timer logic belongs in the @Observable class**, not scattered across view builders

### Oracle-Specific Observations

- The `scrollTimer` and `pauseBlinkTimer` patterns are awkward as `@State` because Timer invalidation in `onDisappear` is fragile. Moving to `@Observable` class with `deinit` cleanup is more robust.
- `activeOptionsMenu: NSMenu?` is AppKit-specific state that should live in a dedicated presenter, not pollute the SwiftUI view hierarchy.
- The `MenuItemTarget` private class at bottom of Helpers file is already isolated -- it naturally becomes part of `MainWindowOptionsMenuPresenter`.

### Oracle's Dependency Map

```
WinampMainWindow (root)
  |-- @Environment: SkinManager, AudioPlayer, DockingController, AppSettings, PlaybackCoordinator, WindowFocusState
  |-- @State (interaction): 7 vars -> WinampMainWindowInteractionState
  |-- @State (menu): activeOptionsMenu -> MainWindowOptionsMenuPresenter
  |
  |-- MainWindowFullLayer
  |     |-- MainWindowTransportLayer (PlaybackCoordinator)
  |     |-- MainWindowTrackInfoLayer (PlaybackCoordinator.displayTitle, InteractionState.scroll*)
  |     |-- MainWindowIndicatorsLayer (PlaybackCoordinator, AudioPlayer, InteractionState.pauseBlink*)
  |     |-- MainWindowSlidersLayer (AudioPlayer.volume/balance, InteractionState.scrub*)
  |     |-- Clutter bar buttons (AppSettings toggles)
  |     |-- Visualizer (existing VisualizerView)
  |
  |-- MainWindowShadeLayer (minimal: transport, time, titlebar)
```

## Key Design Decisions (Both Sources Agree)

### 1. @Observable over @StateObject

`@Observable` (Swift 5.9+ macro) provides fine-grained property tracking. SwiftUI only re-evaluates views that read the specific property that changed. `@StateObject` + `@Published` would trigger all subscribers on any property change.

### 2. @MainActor Isolation

The interaction state class must be `@MainActor` because:
- Timer scheduling requires main thread
- SwiftUI `@State` equivalent must be main-actor-isolated
- All UI state mutations must happen on main actor

### 3. Coords as Standalone Layout File

`Coords` is currently a nested struct inside `WinampMainWindow`. Child views need these constants. Options:
- (a) Make `Coords` a top-level enum in its own file (chosen)
- (b) Pass coordinates as init parameters (verbose, error-prone)
- (c) Keep nested but use `WinampMainWindow.Coords` (couples children to parent)

Option (a) wins: `WinampMainWindowLayout.swift` with a top-level `WinampMainWindowLayout` enum.

### 4. @Environment Passthrough

Child views can declare their own `@Environment` properties. This means:
- `MainWindowTransportLayer` declares `@Environment(PlaybackCoordinator.self) var playbackCoordinator`
- No need to pass environment objects as init params
- SwiftUI handles injection automatically if child is in the view hierarchy

### 5. Preserve .at() Absolute Positioning

The pixel-perfect Winamp rendering uses `.at(CGPoint)` for absolute positioning within `ZStack(alignment: .topLeading)`. This pattern is preserved in all child views. Each child layer is a `ZStack` overlay at known coordinates.

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Pixel regression during extraction | Visual diff testing with screenshot comparison |
| Timer lifecycle change | @Observable deinit handles cleanup; verify with TSan |
| Menu deallocation | Dedicated presenter holds strong NSMenu reference |
| Build breakage from file moves | Incremental extraction, build after each layer |
| Performance regression | Profile with Instruments before/after; child views should improve perf |

## Files Analyzed

- `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/WinampMainWindow.swift` (386 lines)
- `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/WinampMainWindow+Helpers.swift` (508 lines)
- `/Users/hank/dev/src/MacAmp/MacAmpApp/Windows/WinampMainWindowController.swift` (window controller)
