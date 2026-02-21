# Todo: WinampMainWindow Layer Decomposition

> **Purpose:** Discrete checklist items for implementation. Check off as completed.
> Reference plan.md for detailed descriptions of each item.

## Phase 1: Scaffolding

- [ ] Create `MacAmpApp/Views/MainWindow/` directory
- [ ] Create `WinampMainWindowLayout.swift` -- extract `Coords` to top-level enum
- [ ] Add typealias `Coords = WinampMainWindowLayout` in `WinampMainWindow` for backward compat
- [ ] Build and verify no regressions
- [ ] Create `WinampMainWindowInteractionState.swift` -- @Observable @MainActor class
- [ ] Migrate 7 @State vars to interaction state class properties
- [ ] Migrate `startScrolling()` method to interaction state
- [ ] Migrate `resetScrolling()` method to interaction state
- [ ] Migrate `handlePositionDrag()` method to interaction state
- [ ] Migrate `handlePositionDragEnd()` method to interaction state
- [ ] Migrate `timeDigits(from:)` helper to interaction state or standalone
- [ ] Build and verify no regressions
- [ ] Create `MainWindowOptionsMenuPresenter.swift`
- [ ] Migrate `showOptionsMenu(from:)` to presenter
- [ ] Migrate `buildOptionsMenuItems(menu:)` to presenter
- [ ] Migrate `buildRepeatShuffleMenuItems(menu:)` to presenter
- [ ] Migrate `createMenuItem(...)` to presenter
- [ ] Migrate `MenuItemTarget` class to presenter file (as nested private class)
- [ ] Migrate `activeOptionsMenu` state to presenter
- [ ] Build and verify no regressions

## Phase 2: Extract Child Views

- [ ] Create `MainWindowTransportLayer.swift`
  - [ ] Move `buildTransportPlaybackButtons()` content
  - [ ] Move `buildTransportNavButtons()` content
  - [ ] Wire `openFileDialog` as closure parameter
  - [ ] Build and verify

- [ ] Create `MainWindowTrackInfoLayer.swift`
  - [ ] Move `buildTrackInfoDisplay()` content
  - [ ] Move `buildTextSprites(for:)` content
  - [ ] Wire interaction state for scrollOffset
  - [ ] Build and verify

- [ ] Create `MainWindowIndicatorsLayer.swift`
  - [ ] Move `buildPlayPauseIndicator()` content
  - [ ] Move `buildMonoStereoIndicator()` content
  - [ ] Move `buildBitrateDisplay()` content
  - [ ] Move `buildSampleRateDisplay()` content
  - [ ] Wire pauseBlinkVisible from interaction state
  - [ ] Build and verify

- [ ] Create `MainWindowSlidersLayer.swift`
  - [ ] Move `buildPositionSlider()` content
  - [ ] Move `buildVolumeSlider()` content
  - [ ] Move `buildBalanceSlider()` content
  - [ ] Wire interaction state for scrubbing
  - [ ] Build and verify

- [ ] Create `MainWindowFullLayer.swift`
  - [ ] Compose all child layers
  - [ ] Move `buildTitlebarButtons()` (or keep inline if small)
  - [ ] Move `buildShuffleRepeatButtons()`
  - [ ] Move `buildWindowToggleButtons()`
  - [ ] Move `buildClutterBarOAI()` and `buildClutterBarDV()`
  - [ ] Move `buildTimeDisplay()` and `buildTimeDigits()`
  - [ ] Move `buildSpectrumAnalyzer()`
  - [ ] Build and verify

- [ ] Create `MainWindowShadeLayer.swift`
  - [ ] Move `buildShadeMode()` content
  - [ ] Move `buildShadeTransportButtons()` content
  - [ ] Include shade-mode time display
  - [ ] Include titlebar buttons for shade mode
  - [ ] Build and verify

## Phase 3: Wire Up Root View

- [ ] Rewrite `WinampMainWindow.body` to compose `MainWindowFullLayer` / `MainWindowShadeLayer`
- [ ] Replace 7 @State vars with `@State private var interactionState`
- [ ] Replace `activeOptionsMenu` with `@State private var optionsPresenter`
- [ ] Update `.onAppear` / `.onDisappear` to use interaction state methods
- [ ] Update `.onReceive(pauseBlinkTimer)` to use interaction state
- [ ] Update `.onChange(of: settings.showOptionsMenuTrigger)` to use presenter
- [ ] Update `.sheet(isPresented:)` -- remains on root
- [ ] Move `WinampMainWindow.swift` into `MainWindow/` directory
- [ ] Build and verify no regressions
- [ ] Delete `WinampMainWindow+Helpers.swift`
- [ ] Remove `Coords` typealias if no longer needed
- [ ] Build final: zero warnings, zero errors

## Phase 4: Verification

- [ ] Full build with Thread Sanitizer enabled
- [ ] Visual test: full mode rendering (default skin)
- [ ] Visual test: shade mode rendering (default skin)
- [ ] Visual test: double-size mode
- [ ] Visual test: 3+ different Winamp skins
- [ ] Functional test: all transport buttons
- [ ] Functional test: position slider scrubbing
- [ ] Functional test: volume and balance sliders
- [ ] Functional test: track info scrolling (long title)
- [ ] Functional test: pause blink animation
- [ ] Functional test: options menu (O button + Ctrl+O)
- [ ] Functional test: time display toggle (Ctrl+T)
- [ ] Functional test: clutter bar buttons (O, A, I, D, V)
- [ ] Functional test: shuffle/repeat cycling
- [ ] Functional test: EQ/Playlist window toggles
- [ ] Functional test: minimize, shade, close titlebar buttons
- [ ] Performance: Instruments profile body evaluation count
- [ ] Code review: verify no `internal` @State vars remain
- [ ] Code review: all child views have minimal dependency surface
- [ ] Update Xcode project file if needed for new directory structure
