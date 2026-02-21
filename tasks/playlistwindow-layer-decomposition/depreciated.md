# Depreciated: WinampPlaylistWindow Layer Decomposition

> **Purpose:** Documents code patterns that will be deprecated during this task. Per project conventions, we use centralized depreciated.md files instead of inline comments.

---

## Patterns to be Deprecated

### 1. Cross-File Extension for SwiftUI View (WinampPlaylistWindow+Menus.swift)

- **Pattern:** `extension WinampPlaylistWindow` in a separate file containing view builders, helpers, and menu presenters
- **Why deprecated:** Forces access widening from `private` to `internal` on @State vars and computed properties. Does not create SwiftUI recomposition boundaries. Shares body evaluation scope with main file.
- **Replaced by:** Child view structs with explicit dependency injection + PlaylistMenuPresenter struct
- **File to delete:** `MacAmpApp/Views/WinampPlaylistWindow+Menus.swift`

### 2. Internal @State Access (6 Properties)

| Property | Current | Target |
|----------|---------|--------|
| `selectedIndices` | `@State var` (internal) | Moves to `PlaylistWindowInteractionState` |
| `menuDelegate` | `@State var` (internal) | Moves to `PlaylistMenuPresenter` |
| `windowWidth` | `var` (internal computed) | Restored to `private var` |
| `windowHeight` | `var` (internal computed) | Restored to `private var` |
| `isWindowActive` | `var` (internal computed) | Restored to `private var` |
| `playlistStyle` | `var` (internal computed) | Restored to `private var` or passed to child views |

### 3. Manual Selection State Sync

- **Pattern:** `PlaylistWindowActions.shared.selectedIndices = selectedIndices` (manual sync before menu display)
- **Why deprecated:** Duplicated mutable state between view and singleton, synced imperatively
- **Replaced by:** Single source of truth in `PlaylistWindowInteractionState`, passed to menu presenter

## Migration Map

| Extension Method | Destination |
|-----------------|-------------|
| `buildShadeMode()` | `PlaylistShadeView` (child struct) |
| `trackTextColor()` | `PlaylistTrackListView` (child struct) |
| `trackBackground()` | `PlaylistTrackListView` (child struct) |
| `formatDuration()` | `PlaylistTrackListView` (child struct) |
| `openFileDialog()` | Root view (thin wrapper) |
| `handleTrackTap()` | `PlaylistWindowInteractionState` |
| `showAddMenu()` | `PlaylistMenuPresenter` |
| `showRemMenu()` | `PlaylistMenuPresenter` |
| `showMiscMenu()` | `PlaylistMenuPresenter` |
| `showListMenu()` | `PlaylistMenuPresenter` |
| `showSelNotSupportedAlert()` | `PlaylistMenuPresenter` |
| `playlistContentView()` | `PlaylistMenuPresenter` |
| `presentPlaylistMenu()` | `PlaylistMenuPresenter` |
