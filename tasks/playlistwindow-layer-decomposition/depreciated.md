# Depreciated: WinampPlaylistWindow Layer Decomposition

> **Purpose:** Documents code patterns that were deprecated during this task. Per project conventions, we use centralized depreciated.md files instead of inline comments.

---

## Patterns Deprecated (COMPLETED)

### 1. Cross-File Extension for SwiftUI View (WinampPlaylistWindow+Menus.swift)

- **Pattern:** `extension WinampPlaylistWindow` in a separate file containing view builders, helpers, and menu presenters
- **Why deprecated:** Forces access widening from `private` to `internal` on @State vars and computed properties. Does not create SwiftUI recomposition boundaries. Shares body evaluation scope with main file.
- **Replaced by:** Child view structs with explicit dependency injection + PlaylistMenuPresenter struct
- **File deleted:** `MacAmpApp/Views/WinampPlaylistWindow+Menus.swift` (removed in commit cf53dfd)

### 2. Internal @State Access (6 Properties) — ALL FIXED

| Property | Was | Now |
|----------|-----|-----|
| `selectedIndices` | `@State var` (internal) | In `PlaylistWindowInteractionState` (private to root) |
| `menuDelegate` | `@State var` (internal) | `@State private var` in root, passed to presenter |
| `windowWidth` | `var` (internal computed) | `private var` in root |
| `windowHeight` | `var` (internal computed) | `private var` in root |
| `isWindowActive` | `var` (internal computed) | `private var` in root |
| `playlistStyle` | `var` (internal computed) | `private var` in root |

---

## Remaining Debt (Deferred — Out of Scope)

### 3. PlaylistWindowActions Singleton Pattern

- **Pattern:** `PlaylistWindowActions.shared` singleton used as `target:` for `NSMenuItem` actions throughout `PlaylistMenuPresenter`
- **Why debt:** Singleton with mutable `selectedIndices` creates duplicated state. The `@objc` action methods require `NSObject` target/action pattern, which is inherently imperative and doesn't compose with SwiftUI's declarative state.
- **Current state:** 15 references to `.shared` across `PlaylistMenuPresenter` + 1 in `PlaylistBottomControlsView`
- **Scope:** Fixing this requires rearchitecting the AppKit menu bridge (NSMenuItem target/action → SwiftUI action closures). Separate task.
- **Files affected:**
  - `PlaylistMenuPresenter.swift` — 14 `.shared` references as menu item targets
  - `PlaylistBottomControlsView.swift:93` — `PlaylistWindowActions.shared.presentAddFilesPanel()`
  - `PlaylistWindowActions.swift` — singleton definition + `selectedIndices` mutable state

### 4. Manual Selection State Sync

- **Pattern:** `PlaylistWindowActions.shared.selectedIndices = selectedIndices` in `PlaylistMenuPresenter.showRemMenu()` (line 64)
- **Why debt:** Duplicated mutable state between `PlaylistWindowInteractionState.selectedIndices` and `PlaylistWindowActions.shared.selectedIndices`, synced imperatively before menu display
- **Current state:** Mitigated (sync now happens in one place instead of scattered), but not eliminated
- **Scope:** Blocked by singleton pattern (#3 above). When the singleton is replaced, this sync disappears.

---

## Migration Map (COMPLETED)

| Extension Method | Destination | Status |
|-----------------|-------------|--------|
| `buildShadeMode()` | `PlaylistShadeView` | Done |
| `trackTextColor()` | `PlaylistTrackListView` | Done |
| `trackBackground()` | `PlaylistTrackListView` | Done |
| `formatDuration()` | `PlaylistTrackListView` | Done |
| `openFileDialog()` | `PlaylistBottomControlsView` (inline) | Done |
| `handleTrackTap()` | `PlaylistWindowInteractionState` | Done |
| `showAddMenu()` | `PlaylistMenuPresenter` | Done |
| `showRemMenu()` | `PlaylistMenuPresenter` | Done |
| `showMiscMenu()` | `PlaylistMenuPresenter` | Done |
| `showListMenu()` | `PlaylistMenuPresenter` | Done |
| `showSelNotSupportedAlert()` | `PlaylistMenuPresenter` | Done |
| `playlistContentView()` | `PlaylistMenuPresenter` | Done |
| `presentPlaylistMenu()` | `PlaylistMenuPresenter` | Done |
| `buildTitleBarButtons()` | `PlaylistTitleBarButtons` | Done |
