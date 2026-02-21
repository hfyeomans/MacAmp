# Research: WinampPlaylistWindow Layer Decomposition

> **Purpose:** Documents the architectural debt introduced during the N1-N6 lint cleanup and the proper decomposition pattern to resolve it, based on Oracle audit findings and alignment with the mainwindow-layer-decomposition task.

---

## Status: COMPLETE — Oracle-audited (gpt-5.3-codex, xhigh reasoning, 2026-02-21)

## Problem Statement

During the N1-N6 internet radio fix branch (`fix/internet-radio-n1-n6`), WinampPlaylistWindow.swift had 20 pre-existing SwiftLint violations that blocked committing the N3 comment update. The lint cleanup applied the same tactical cross-file extension pattern previously flagged as architectural debt for WinampMainWindow:

1. Extracted `PlaylistWindowActions` class to its own file (GOOD — proper class extraction)
2. Extracted menus, helpers, and shade mode to `WinampPlaylistWindow+Menus.swift` extension (DEBT — same anti-pattern)
3. Widened 6 properties from `private` to `internal` for cross-file access (DEBT)

## Oracle Audit Findings (commit 5f2cef2)

**Verdict:** Same debt pattern reintroduced on a smaller scale.

### Properties Widened from Private to Internal

| Property | Type | File:Line | Used By Extension |
|----------|------|-----------|-------------------|
| `selectedIndices` | `@State var` | WinampPlaylistWindow.swift:12 | showRemMenu, handleTrackTap |
| `menuDelegate` | `@State var` | WinampPlaylistWindow.swift:15 | All showXxxMenu functions |
| `windowWidth` | `var` (computed) | WinampPlaylistWindow.swift:37 | Menu positioning, shade mode |
| `windowHeight` | `var` (computed) | WinampPlaylistWindow.swift:38 | Menu positioning |
| `isWindowActive` | `var` (computed) | WinampPlaylistWindow.swift:41 | buildShadeMode |
| `playlistStyle` | `var` (computed) | WinampPlaylistWindow.swift:85 | trackTextColor, trackBackground |

### What Was Done Right

`PlaylistWindowActions` extraction to `PlaylistWindowActions.swift` is proper architecture:
- Standalone `@MainActor final class` (not an extension)
- Self-contained AppKit menu action plumbing
- Clean separation of concerns

**Remaining debt in PlaylistWindowActions:** Global singleton + duplicated mutable selection state (`selectedIndices`) synced manually between the view and the actions class.

### Cross-File Extension Anti-Pattern

`WinampPlaylistWindow+Menus.swift` contains:
- `buildShadeMode()` — view builder
- `trackTextColor()`, `trackBackground()` — view helpers
- `formatDuration()`, `openFileDialog()`, `handleTrackTap()` — utilities
- `showAddMenu()`, `showRemMenu()`, `showMiscMenu()`, `showListMenu()` — AppKit menu presenters
- `showSelNotSupportedAlert()` — alert helper
- `playlistContentView()`, `presentPlaylistMenu()` — menu positioning helpers

These should be child view structs or methods on an @Observable state object, not extension methods that force access widening.

## Target Architecture (from Oracle + Gemini convergence)

Same pattern as `mainwindow-layer-decomposition`:

### @Observable Interaction State

```swift
@MainActor
@Observable
final class PlaylistWindowInteractionState {
    var selectedIndices: Set<Int> = []
    var isShadeMode: Bool = false
    var scrollOffset: Int = 0
    var dragStartSize: Size2D?
    var isDragging: Bool = false
    // Timer, keyboard monitor logic moves here
}
```

### Child View Structs

```
MacAmpApp/Views/PlaylistWindow/
  WinampPlaylistWindow.swift            // Root composition + lifecycle
  PlaylistWindowLayout.swift            // Size state constants
  PlaylistWindowInteractionState.swift  // @Observable state
  PlaylistTrackListLayer.swift          // Track list + selection
  PlaylistBottomControlsLayer.swift     // Bottom menu buttons + transport
  PlaylistShadeLayer.swift              // Shade mode
  PlaylistMenuPresenter.swift           // AppKit NSMenu bridge (replaces extension menus)
  PlaylistResizeHandle.swift            // Resize drag gesture
```

### Key Differences from MainWindow Decomposition

| Concern | MainWindow | PlaylistWindow |
|---------|-----------|----------------|
| Layout | Fixed 275x116 | Dynamic resize (segments) |
| Menus | Options menu only | 4 sprite menus (Add, Rem, Misc, List) |
| Selection | None | Multi-select with shift-click |
| State | 7 @State vars | 8 @State vars + resize + scroll |
| Scroll | Text scrolling | Track list scrolling |
| AppKit bridge | NSMenu (options) | NSMenu (4 menus) + NSEvent keyboard monitor |

## Docs Alignment

- `docs/IMPLEMENTATION_PATTERNS.md` (line ~2585, ~2611) — aligns with child component extraction
- `docs/MACAMP_ARCHITECTURE_GUIDE.md` (line ~148, ~173) — aligns on system-level decomposition/layering
- Neither doc explicitly guards against cross-file SwiftUI extension splits as a decomposition strategy
- **Recommendation:** Update IMPLEMENTATION_PATTERNS.md to document the anti-pattern when this or the mainwindow task is implemented

## Sources

- Oracle audit of commit 5f2cef2 (gpt-5.3-codex, xhigh, 2026-02-21)
- Gemini + Oracle architecture research (from mainwindow-layer-decomposition task)
- `tasks/mainwindow-layer-decomposition/research.md` — convergence analysis
- `docs/IMPLEMENTATION_PATTERNS.md`, `docs/MACAMP_ARCHITECTURE_GUIDE.md`
