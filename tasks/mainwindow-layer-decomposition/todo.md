# Todo: WinampMainWindow Layer Decomposition

> **Purpose:** Discrete checklist items for implementation. Check off as completed.
> Reference plan.md for detailed descriptions of each item.

## Phase 1: Scaffolding

- [x] Create `MacAmpApp/Views/MainWindow/` directory
- [x] Create `WinampMainWindowLayout.swift` -- extract `Coords` to top-level enum
- [x] Add typealias `Coords = WinampMainWindowLayout` in `WinampMainWindow` for backward compat
- [x] Build and verify no regressions
- [x] Create `WinampMainWindowInteractionState.swift` -- @Observable @MainActor class
- [x] Migrate 7 @State vars to interaction state class properties
- [x] Migrate `startScrolling()` method to interaction state
- [x] Migrate `resetScrolling()` method to interaction state
- [x] Migrate `handlePositionDrag()` method to interaction state
- [x] Migrate `handlePositionDragEnd()` method to interaction state
- [x] Migrate `timeDigits(from:)` helper to interaction state
- [x] Build and verify no regressions
- [x] Create `MainWindowOptionsMenuPresenter.swift`
- [x] Migrate `showOptionsMenu(from:)` to presenter
- [x] Migrate `buildOptionsMenuItems(menu:)` to presenter
- [x] Migrate `buildRepeatShuffleMenuItems(menu:)` to presenter
- [x] Migrate `createMenuItem(...)` to presenter
- [x] Migrate `MenuItemTarget` class to presenter file (as nested private class)
- [x] Migrate `activeOptionsMenu` state to presenter
- [x] Build and verify no regressions

## Phase 1 Extras (Oracle + modernization)

- [x] Fix stale title capture in scrollTimer (Oracle finding: use displayTitleProvider closure)
- [x] Modernize DispatchQueue.main.asyncAfter to Task.sleep in resetScrolling()
- [x] Modernize DispatchQueue.main.asyncAfter to Task.sleep in handlePositionDragEnd()
- [x] Add cancellable scrollRestartTask for rapid track changes
- [x] Remove stale duplicate VideoWindowChromeView.swift (pre-existing build blocker)

## Phase 2: Extract Child Views

- [x] Create `MainWindowTransportLayer.swift`
  - [x] Move `buildTransportPlaybackButtons()` content
  - [x] Move `buildTransportNavButtons()` content
  - [x] Wire `openFileDialog` as closure parameter
  - [x] Build and verify

- [x] Create `MainWindowTrackInfoLayer.swift`
  - [x] Move `buildTrackInfoDisplay()` content
  - [x] Move `buildTextSprites(for:)` content
  - [x] Wire interaction state for scrollOffset
  - [x] Build and verify

- [x] Create `MainWindowIndicatorsLayer.swift`
  - [x] Move `buildPlayPauseIndicator()` content
  - [x] Move `buildMonoStereoIndicator()` content
  - [x] Move `buildBitrateDisplay()` content
  - [x] Move `buildSampleRateDisplay()` content
  - [x] Wire pauseBlinkVisible from interaction state
  - [x] Build and verify

- [x] Create `MainWindowSlidersLayer.swift`
  - [x] Move `buildPositionSlider()` content
  - [x] Move `buildVolumeSlider()` content
  - [x] Move `buildBalanceSlider()` content
  - [x] Wire interaction state for scrubbing
  - [x] Build and verify

- [x] Create `MainWindowFullLayer.swift`
  - [x] Compose all child layers
  - [x] Move `buildTitlebarButtons()` (kept as private builder)
  - [x] Move `buildShuffleRepeatButtons()`
  - [x] Move `buildWindowToggleButtons()`
  - [x] Move `buildClutterBarOAI()` and `buildClutterBarDV()`
  - [x] Move `buildTimeDisplay()` and `buildTimeDigits()`
  - [x] Move `buildSpectrumAnalyzer()`
  - [x] Build and verify

- [x] Create `MainWindowShadeLayer.swift`
  - [x] Move `buildShadeMode()` content
  - [x] Move `buildShadeTransportButtons()` content
  - [x] Include shade-mode time display
  - [x] Include titlebar buttons for shade mode
  - [x] Build and verify

## Phase 3: Wire Up Root View

- [x] Rewrite `WinampMainWindow.body` to compose `MainWindowFullLayer` / `MainWindowShadeLayer`
- [x] Replace 7 @State vars with `@State private var interactionState`
- [x] Replace `activeOptionsMenu` with `@State private var optionsPresenter`
- [x] Update `.onAppear` / `.onDisappear` to use interaction state methods
- [x] Update `.onReceive(pauseBlinkTimer)` to use interaction state
- [x] Update `.onChange(of: settings.showOptionsMenuTrigger)` to use presenter
- [x] Update `.sheet(isPresented:)` -- remains on root
- [x] Move `WinampMainWindow.swift` into `MainWindow/` directory
- [x] Build and verify no regressions
- [x] Delete `WinampMainWindow+Helpers.swift`
- [x] Remove `Coords` typealias (no longer needed — child views use WinampMainWindowLayout directly)
- [x] Build final: zero warnings, zero errors

## Phase 3 Extras (Oracle review)

- [x] Fix shade-mode time display double-offset regression (Oracle finding #2)

## Phase 4: Verification

- [x] Full build with Thread Sanitizer enabled (swift test passes, known flaky test excluded)
- [ ] Visual test: full mode rendering (default skin) — NEEDS MANUAL VERIFICATION
- [ ] Visual test: shade mode rendering (default skin) — NEEDS MANUAL VERIFICATION
- [ ] Visual test: double-size mode — NEEDS MANUAL VERIFICATION
- [ ] Visual test: 3+ different Winamp skins — NEEDS MANUAL VERIFICATION
- [ ] Functional test: all transport buttons — NEEDS MANUAL VERIFICATION
- [ ] Functional test: position slider scrubbing — NEEDS MANUAL VERIFICATION
- [ ] Functional test: volume and balance sliders — NEEDS MANUAL VERIFICATION
- [ ] Functional test: track info scrolling (long title) — NEEDS MANUAL VERIFICATION
- [ ] Functional test: pause blink animation — NEEDS MANUAL VERIFICATION
- [ ] Functional test: options menu (O button + Ctrl+O) — NEEDS MANUAL VERIFICATION
- [ ] Functional test: time display toggle (Ctrl+T) — NEEDS MANUAL VERIFICATION
- [ ] Functional test: clutter bar buttons (O, A, I, D, V) — NEEDS MANUAL VERIFICATION
- [ ] Functional test: shuffle/repeat cycling — NEEDS MANUAL VERIFICATION
- [ ] Functional test: EQ/Playlist window toggles — NEEDS MANUAL VERIFICATION
- [ ] Functional test: minimize, shade, close titlebar buttons — NEEDS MANUAL VERIFICATION
- [ ] Performance: Instruments profile body evaluation count — DEFERRED (post-merge optimization)
- [x] Code review: verify no `internal` @State vars remain
- [x] Code review: all child views have minimal dependency surface
- [ ] Update Xcode project file if needed for new directory structure — N/A (SwiftPM project)
