# Plan: WinampMainWindow Layer Decomposition

> **Purpose:** Phased implementation plan for decomposing WinampMainWindow from a cross-file extension
> pattern into proper layer subview decomposition with an @Observable interaction state object.
> Derived from converged Gemini + Oracle research findings.

## Goal

Transform the current 2-file / 894-line extension-based WinampMainWindow into a clean directory of
focused view structs with explicit dependencies, restoring `private` access on all interaction state.

## Target File Structure

```
MacAmpApp/Views/MainWindow/
  WinampMainWindow.swift                    -- root composition + lifecycle only (~80 lines)
  WinampMainWindowLayout.swift              -- Coords constants as top-level enum (~50 lines)
  WinampMainWindowInteractionState.swift    -- @Observable state class (~90 lines)
  MainWindowFullLayer.swift                 -- full-mode ZStack composition (~60 lines)
  MainWindowShadeLayer.swift                -- shade-mode composition (~50 lines)
  MainWindowTransportLayer.swift            -- prev/play/pause/stop/next/eject (~80 lines)
  MainWindowTrackInfoLayer.swift            -- scrolling text, text sprite rendering (~100 lines)
  MainWindowIndicatorsLayer.swift           -- play/pause indicator, mono/stereo, bitrate, sample rate (~80 lines)
  MainWindowSlidersLayer.swift              -- volume, balance, position slider (~90 lines)
  MainWindowOptionsMenuPresenter.swift      -- AppKit NSMenu bridge + MenuItemTarget (~120 lines)
```

**Deleted after migration:**
- `MacAmpApp/Views/WinampMainWindow+Helpers.swift` (entire file)

## Phase 1: Scaffolding (Non-Breaking)

**Goal:** Create new files and types without changing existing behavior.

### 1.1 Create `MainWindow/` Directory

Create `MacAmpApp/Views/MainWindow/` and add it to the Xcode project.

### 1.2 Extract `WinampMainWindowLayout`

Create `WinampMainWindowLayout.swift`:

```swift
import SwiftUI

/// Winamp coordinate constants (from original Winamp and webamp reference).
/// Used by all MainWindow child views for pixel-perfect absolute positioning.
enum WinampMainWindowLayout {
    // Transport buttons (all at y: 88)
    static let prevButton = CGPoint(x: 16, y: 88)
    static let playButton = CGPoint(x: 39, y: 88)
    // ... all existing Coords values
}
```

- Copy all values from `WinampMainWindow.Coords`
- Keep the original `Coords` nested struct as a `typealias` temporarily for compatibility

### 1.3 Create `WinampMainWindowInteractionState`

```swift
import SwiftUI

/// Consolidates interaction state previously scattered as @State vars across
/// WinampMainWindow and its extension. Owned by root view, passed to children.
@MainActor
@Observable
final class WinampMainWindowInteractionState {
    // Scrubbing (position slider drag)
    var isScrubbing: Bool = false
    var wasPlayingPreScrub: Bool = false
    var scrubbingProgress: Double = 0.0

    // Track info scrolling
    var scrollOffset: CGFloat = 0
    var scrollTimer: Timer?

    // Pause blinking
    var pauseBlinkVisible: Bool = true
    var isViewVisible: Bool = false

    // Timer/scrolling logic methods migrate here
    func startScrolling(displayTitle: String, trackInfoWidth: CGFloat) { ... }
    func resetScrolling(displayTitle: String, trackInfoWidth: CGFloat) { ... }
    func handlePositionDrag(_ value: DragGesture.Value, in geometry: GeometryProxy, audioPlayer: AudioPlayer) { ... }
    func handlePositionDragEnd(_ value: DragGesture.Value, in geometry: GeometryProxy, audioPlayer: AudioPlayer) { ... }
    func cleanup() { scrollTimer?.invalidate(); scrollTimer = nil }
}
```

### 1.4 Create `MainWindowOptionsMenuPresenter`

```swift
import SwiftUI
import AppKit

/// Bridges AppKit NSMenu to SwiftUI for the Options (O) button menu.
/// Absorbs MenuItemTarget and menu lifecycle management.
@MainActor
final class MainWindowOptionsMenuPresenter {
    private var activeMenu: NSMenu?

    func showOptionsMenu(from buttonPosition: CGPoint, settings: AppSettings,
                         audioPlayer: AudioPlayer, isDoubleSizeMode: Bool) { ... }

    private func buildOptionsMenuItems(menu: NSMenu, settings: AppSettings,
                                       audioPlayer: AudioPlayer) { ... }
    // MenuItemTarget moves here as nested private class
}
```

## Phase 2: Extract Child View Structs

**Goal:** Create child views that compile alongside existing code. Each gets its own file.

### 2.1 `MainWindowTransportLayer`

```swift
struct MainWindowTransportLayer: View {
    @Environment(PlaybackCoordinator.self) var playbackCoordinator
    let openFileDialog: () -> Void  // closure from parent

    var body: some View { ... }  // prev, play, pause, stop, next, eject
}
```

Dependencies: `PlaybackCoordinator` (environment), `openFileDialog` closure.
Uses: `WinampMainWindowLayout` for button positions.

### 2.2 `MainWindowTrackInfoLayer`

```swift
struct MainWindowTrackInfoLayer: View {
    @Environment(PlaybackCoordinator.self) var playbackCoordinator
    let interactionState: WinampMainWindowInteractionState

    var body: some View { ... }  // scrolling text, buildTextSprites
}
```

Dependencies: `PlaybackCoordinator.displayTitle`, interaction state for scroll offset/timer.

### 2.3 `MainWindowIndicatorsLayer`

```swift
struct MainWindowIndicatorsLayer: View {
    @Environment(PlaybackCoordinator.self) var playbackCoordinator
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(AppSettings.self) var settings
    let pauseBlinkVisible: Bool

    var body: some View { ... }  // play/pause indicator, mono/stereo, bitrate, samplerate
}
```

Dependencies: Playback state for indicator, audio metadata for mono/stereo/bitrate.

### 2.4 `MainWindowSlidersLayer`

```swift
struct MainWindowSlidersLayer: View {
    @Environment(AudioPlayer.self) var audioPlayer
    let interactionState: WinampMainWindowInteractionState

    var body: some View { ... }  // volume, balance, position slider
}
```

Dependencies: `AudioPlayer` for volume/balance bindings, interaction state for scrubbing.

### 2.5 `MainWindowFullLayer`

```swift
struct MainWindowFullLayer: View {
    @Environment(AppSettings.self) var settings
    @Environment(WindowFocusState.self) var windowFocusState
    let interactionState: WinampMainWindowInteractionState
    let optionsPresenter: MainWindowOptionsMenuPresenter
    let openFileDialog: () -> Void

    var body: some View {
        // Compose all child layers
        buildTitlebarButtons()
        MainWindowIndicatorsLayer(pauseBlinkVisible: interactionState.pauseBlinkVisible)
        buildTimeDisplay()
        MainWindowTrackInfoLayer(interactionState: interactionState)
        buildSpectrumAnalyzer()
        MainWindowTransportLayer(openFileDialog: openFileDialog)
        buildShuffleRepeatButtons()
        MainWindowSlidersLayer(interactionState: interactionState)
        buildWindowToggleButtons()
        buildClutterBar()
    }
}
```

Note: Titlebar buttons, shuffle/repeat, EQ/PL toggle, clutter bar, time display, and visualizer
are small enough to remain as `@ViewBuilder` private methods within `MainWindowFullLayer`,
or can be extracted further in a future pass.

### 2.6 `MainWindowShadeLayer`

```swift
struct MainWindowShadeLayer: View {
    @Environment(PlaybackCoordinator.self) var playbackCoordinator
    @Environment(AppSettings.self) var settings
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(WindowFocusState.self) var windowFocusState
    let pauseBlinkVisible: Bool

    var body: some View { ... }  // shade background, mini transport, time, titlebar buttons
}
```

## Phase 3: Wire Up Root View

**Goal:** Replace `WinampMainWindow.body` to compose child layers.

### 3.1 Rewrite Root

```swift
struct WinampMainWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(AppSettings.self) var settings
    @Environment(PlaybackCoordinator.self) var playbackCoordinator
    @Environment(WindowFocusState.self) var windowFocusState
    @Environment(DockingController.self) var dockingController

    @State private var interactionState = WinampMainWindowInteractionState()
    @State private var optionsPresenter = MainWindowOptionsMenuPresenter()

    let pauseBlinkTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .topLeading) {
            SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", ...)
            WinampTitlebarDragHandle(...) { ... }

            if !settings.isMainWindowShaded {
                MainWindowFullLayer(
                    interactionState: interactionState,
                    optionsPresenter: optionsPresenter,
                    openFileDialog: openFileDialog
                )
            } else {
                MainWindowShadeLayer(pauseBlinkVisible: interactionState.pauseBlinkVisible)
            }
        }
        .frame(...)
        // lifecycle modifiers: .onAppear, .onDisappear, .onReceive, .onChange, .sheet
    }
}
```

### 3.2 Restore Private Access

All `@State` replaced by `@State private var interactionState`. The interaction state class
properties are internal to the class but the class itself is private to the root view.

### 3.3 Delete Extension File

Remove `WinampMainWindow+Helpers.swift` entirely. All code has migrated to:
- Interaction methods -> `WinampMainWindowInteractionState`
- View builders -> respective child view structs
- Options menu -> `MainWindowOptionsMenuPresenter`
- `timeDigits(from:)` helper -> utility method on interaction state or standalone function

## Phase 4: Verification

### 4.1 Build Verification
- `xcodebuild -scheme MacAmp -configuration Debug -enableThreadSanitizer YES`
- Zero warnings, zero errors

### 4.2 Visual Verification
- Screenshot comparison: before vs after for full mode and shade mode
- Test with at least 3 different Winamp skins
- Verify double-size mode renders correctly
- Verify shade mode toggle works

### 4.3 Functional Verification
- Transport buttons (play/pause/stop/prev/next/eject)
- Position slider scrubbing (drag, release, resume playback)
- Volume and balance sliders
- Track info scrolling (long titles scroll, short titles static)
- Pause blink animation
- Options menu (O button and Ctrl+O keyboard shortcut)
- Time display toggle (elapsed/remaining)
- Clutter bar buttons (O, A, I, D, V)
- Shuffle/repeat button cycling
- EQ/Playlist window toggle buttons

### 4.4 Performance Verification
- Profile with Instruments: compare body evaluation count before/after
- Expectation: fewer body evaluations due to child view isolation

## Migration Safety Rules

1. **Build after every file extraction** -- never batch multiple extractions without verifying
2. **Keep old code until new code compiles** -- parallel existence during migration
3. **No behavioral changes** -- this is pure structural refactor, zero feature changes
4. **Thread Sanitizer always on** -- catch any timer/concurrency regressions
5. **Visual diff** -- screenshot before starting, compare at each phase boundary
