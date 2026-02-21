# Todo: WinampPlaylistWindow Layer Decomposition

> **Purpose:** Discrete checklist items for implementation. Check off as completed.
> Reference plan.md for detailed descriptions.

---

## Status: PLANNED — Awaiting implementation approval

---

## Phase 1: Scaffolding

- [ ] **1.1a** Create `MacAmpApp/Views/PlaylistWindow/` directory
- [ ] **1.1b** Create `PlaylistWindowInteractionState.swift` — @Observable @MainActor class
- [ ] **1.1c** Move `selectedIndices`, `isShadeMode`, `scrollOffset`, `dragStartSize`, `isDragging`, `resizePreview`, `keyboardMonitor` to state object
- [ ] **1.1d** Move `handleTrackTap(index:)` logic to state object
- [ ] **1.1e** Move `handleKeyPress(event:)` logic to state object
- [ ] **1.2a** Create `PlaylistMenuPresenter.swift` — struct with explicit dependencies
- [ ] **1.2b** Move `showAddMenu()`, `showRemMenu()`, `showMiscMenu()`, `showListMenu()` to presenter
- [ ] **1.2c** Move `showSelNotSupportedAlert()` to presenter
- [ ] **1.2d** Move `playlistContentView()`, `presentPlaylistMenu()` to presenter
- [ ] **1.2e** Build with Thread Sanitizer — verify scaffolding compiles

---

## Phase 2: Extract Child Views

- [ ] **2.1a** Create `PlaylistTrackListView.swift` — extract `buildTrackList()`, `trackRow()`
- [ ] **2.1b** Define explicit init params: playlist data, selection binding, track tap handler, play action
- [ ] **2.1c** Move `trackTextColor()`, `trackBackground()`, `formatDuration()` to this view
- [ ] **2.2a** Create `PlaylistBottomControlsView.swift` — extract `buildBottomControls()`, `buildPlaylistTransportButtons()`, `buildTimeDisplays()`
- [ ] **2.2b** Move `playlistTransportButton()` helper to this view
- [ ] **2.2c** Define explicit init params: window dimensions, transport actions, time display strings
- [ ] **2.3a** Create `PlaylistShadeView.swift` — extract `buildShadeMode()`
- [ ] **2.3b** Define explicit init params: window dimensions, active state, current track, titlebar buttons
- [ ] **2.4a** Create `PlaylistResizeHandle.swift` — extract `buildResizeHandle()` gesture
- [ ] **2.4b** Define explicit init params: window dimensions, size state binding
- [ ] **2.5a** Create `PlaylistTitleBarButtons.swift` — extract `buildTitleBarButtons()`
- [ ] **2.5b** Define explicit init params: window dimensions, shade toggle, minimize/close actions
- [ ] **2.5c** Build with Thread Sanitizer — verify all child views compile

---

## Phase 3: Wire Root Composer

- [ ] **3.1** Rewrite `WinampPlaylistWindow.body` to compose child views
- [ ] **3.2a** Replace `@State var selectedIndices` with `@State private var ui = PlaylistWindowInteractionState()`
- [ ] **3.2b** Restore `windowWidth`, `windowHeight` to `private var`
- [ ] **3.2c** Restore `isWindowActive`, `playlistStyle` to `private var`
- [ ] **3.2d** Remove `menuDelegate` @State (moves to menu presenter)
- [ ] **3.3** Delete `WinampPlaylistWindow+Menus.swift`
- [ ] **3.4** Update Xcode project file — remove deleted file, add new files
- [ ] **3.5** Build with Thread Sanitizer — zero errors

---

## Phase 4: Verification

- [ ] **4.1** Visual: playlist window renders identically (compare screenshots)
- [ ] **4.2** Track selection: single click selects, shift-click multi-selects
- [ ] **4.3** Double-click plays track via PlaybackCoordinator
- [ ] **4.4** All 4 menus open and function (Add, Rem, Misc, List)
- [ ] **4.5** Shade mode toggle works
- [ ] **4.6** Resize drag works with quantized segments
- [ ] **4.7** Scroll slider syncs with track list
- [ ] **4.8** Keyboard shortcuts: Cmd+A select all, Esc deselect
- [ ] **4.9** SwiftLint: zero violations on all playlist files
- [ ] **4.10** No regressions in main window or EQ window
- [ ] **4.11** Oracle review of final architecture

---

## Post-Implementation

- [ ] Update `docs/IMPLEMENTATION_PATTERNS.md` — document anti-pattern (cross-file SwiftUI extension splits)
- [ ] Update task state.md with final line counts
- [ ] Update tasks/_context/tasks_index.md
