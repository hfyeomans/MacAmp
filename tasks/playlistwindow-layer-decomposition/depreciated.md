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

### 3. Manual Selection State Sync — MITIGATED

- **Pattern:** `PlaylistWindowActions.shared.selectedIndices = selectedIndices` (manual sync before menu display)
- **Why deprecated:** Duplicated mutable state between view and singleton, synced imperatively
- **Current state:** Sync still happens in `PlaylistMenuPresenter.showRemMenu()` since `PlaylistWindowActions` is an `NSObject` singleton used by AppKit menu targets. Full fix deferred to separate task.

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
