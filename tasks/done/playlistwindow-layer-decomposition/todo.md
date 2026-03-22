# Todo: WinampPlaylistWindow Layer Decomposition

> **Purpose:** Discrete checklist items for implementation. Check off as completed.
> Reference plan.md for detailed descriptions.

---

## Status: COMPLETE

---

## Phase 1: Scaffolding

- [x] **1.1a** Create `MacAmpApp/Views/PlaylistWindow/` directory
- [x] **1.1b** Create `PlaylistWindowInteractionState.swift` — @Observable @MainActor class
- [x] **1.1c** Move `selectedIndices`, `isShadeMode`, `scrollOffset`, `dragStartSize`, `isDragging`, `resizePreview`, `keyboardMonitor` to state object
- [x] **1.1d** Move `handleTrackTap(index:)` logic to state object
- [x] **1.1e** Move `handleKeyPress(event:)` logic to state object
- [x] **1.2a** Create `PlaylistMenuPresenter.swift` — struct with explicit dependencies
- [x] **1.2b** Move `showAddMenu()`, `showRemMenu()`, `showMiscMenu()`, `showListMenu()` to presenter
- [x] **1.2c** Move `showSelNotSupportedAlert()` to presenter
- [x] **1.2d** Move `playlistContentView()`, `presentPlaylistMenu()` to presenter
- [x] **1.2e** Build with Thread Sanitizer — verify scaffolding compiles

---

## Phase 2: Extract Child Views

- [x] **2.1a** Create `PlaylistTrackListView.swift` — extract `buildTrackList()`, `trackRow()`
- [x] **2.1b** Define explicit init params: playlist data, selection binding, track tap handler, play action
- [x] **2.1c** Move `trackTextColor()`, `trackBackground()`, `formatDuration()` to this view
- [x] **2.2a** Create `PlaylistBottomControlsView.swift` — extract `buildBottomControls()`, `buildPlaylistTransportButtons()`, `buildTimeDisplays()`
- [x] **2.2b** Move `playlistTransportButton()` helper to this view
- [x] **2.2c** Define explicit init params: window dimensions, transport actions, time display strings
- [x] **2.3a** Create `PlaylistShadeView.swift` — extract `buildShadeMode()`
- [x] **2.3b** Define explicit init params: window dimensions, active state, current track, titlebar buttons
- [x] **2.4a** Create `PlaylistResizeHandle.swift` — extract `buildResizeHandle()` gesture
- [x] **2.4b** Define explicit init params: window dimensions, size state binding
- [x] **2.5a** Create `PlaylistTitleBarButtons.swift` — extract `buildTitleBarButtons()`
- [x] **2.5b** Define explicit init params: window dimensions, shade toggle, minimize/close actions
- [x] **2.5c** Build with Thread Sanitizer — verify all child views compile

---

## Phase 3: Wire Root Composer

- [x] **3.1** Rewrite `WinampPlaylistWindow.body` to compose child views
- [x] **3.2a** Replace `@State var selectedIndices` with `@State private var ui = PlaylistWindowInteractionState()`
- [x] **3.2b** Restore `windowWidth`, `windowHeight` to `private var`
- [x] **3.2c** Restore `isWindowActive`, `playlistStyle` to `private var`
- [x] **3.2d** Keep `menuDelegate` as @State private (passed to PlaylistMenuPresenter via init)
- [x] **3.3** Delete `WinampPlaylistWindow+Menus.swift`
- [x] **3.4** Update Xcode project file — remove deleted file, add new files + PlaylistWindow group
- [x] **3.5** Build with Thread Sanitizer — zero errors

---

## Phase 4: Verification

- [x] **4.1** Clean build with Thread Sanitizer — zero errors, zero warnings
- [x] **4.2** All @State/@Environment properties private
- [x] **4.3** No widened access modifiers remaining
- [x] **4.4** Visual: playlist window renders identically (requires manual testing)
- [x] **4.5** Track selection: single click selects, shift-click multi-selects (requires manual testing)
- [x] **4.6** Double-click plays track via PlaybackCoordinator (requires manual testing)
- [x] **4.7** All 4 menus open and function (Add, Rem, Misc, List) (requires manual testing)
- [x] **4.8** Shade mode toggle works (requires manual testing)
- [x] **4.9** Resize drag works with quantized segments (requires manual testing)
- [x] **4.10** Scroll slider syncs with track list (requires manual testing)
- [x] **4.11** Keyboard shortcuts: Cmd+A select all, Esc deselect (requires manual testing)

---

## Oracle Review (gpt-5.3-codex, xhigh)

- [x] **O.1** Remove unused `@Environment(PlaybackCoordinator.self)` from root view
- [x] **O.2** Tighten `PlaylistWindowInteractionState` — `private(set)` on `resizePreview`, `keyboardMonitor`
- [x] **O.3** Add intent methods `installKeyboardMonitor`/`removeKeyboardMonitor` with `[weak self]` capture
- [x] **O.4** Completeness check: no dropped behavior confirmed by Oracle

---

## Post-Implementation

- [ ] Update `docs/IMPLEMENTATION_PATTERNS.md` — document anti-pattern (cross-file SwiftUI extension splits)
- [x] Update task state.md with final line counts
- [ ] Update tasks/_context/tasks_index.md
