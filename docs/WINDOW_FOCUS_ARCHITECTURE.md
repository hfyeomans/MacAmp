# Window Focus State Architecture

**Version:** 1.1.0
**Date:** 2026-09-25
**Component:** WindowFocusState System

---

## Executive Summary

`WindowFocusState` tracks which MacAmp window (Main, Equalizer, Playlist, Video, Milkdrop) is key, so each window can draw the Winamp active titlebar when focused and the inactive variant otherwise.

### Architecture Position

```
PRESENTATION  Window views: WinampMainWindow, WinampEqualizerWindow, WinampPlaylistWindow,
              VideoWindowChromeView, MilkdropWindowChromeView (read focus → titlebar sprites)
BRIDGE        WindowFocusState (@Observable), WindowFocusDelegate (NSWindowDelegate adapter),
              WindowDelegateWiring (creates and retains delegates)
MECHANISM     NSWindow didBecomeKey / didResignKey, WindowDelegateMultiplexer
```

---

## Component Architecture

### WindowFocusState Model

`MacAmpApp/Models/WindowFocusState.swift`

```swift
@Observable
@MainActor
final class WindowFocusState {
    var isMainKey: Bool = true       // main window starts focused
    var isEqualizerKey: Bool = false
    var isPlaylistKey: Bool = false
    var isVideoKey: Bool = false
    var isMilkdropKey: Bool = false

    var hasAnyFocus: Bool {
        isMainKey || isEqualizerKey || isPlaylistKey || isVideoKey || isMilkdropKey
    }
}
```

`@Observable` gives per-property SwiftUI invalidation (a view reading only `isVideoKey` doesn't update when `isMainKey` changes). Focus is transient and not persisted.

### WindowFocusDelegate

`MacAmpApp/Utilities/WindowFocusDelegate.swift`: a `@MainActor final class WindowFocusDelegate: NSObject, NSWindowDelegate`, initialized with `(kind: WindowKind, focusState: WindowFocusState)`.

- `windowDidBecomeKey` sets every flag to `kind == <that window>`, so exactly one window is marked key.
- `windowDidResignKey` clears only this window's flag (all flags can be false when the app is inactive).

---

## Integration Pattern

### 1. App-Level Initialization

`MacAmpApp.init()` (`MacAmpApp/MacAmpApp.swift`) creates one `WindowFocusState`, stores it in `@State`, and passes it to `WindowCoordinator(…, windowFocusState:)`.

### 2. Window Controllers

`WindowCoordinator.init` passes the state to every window controller (`WinampMainWindowController`, `WinampEqualizerWindowController`, `WinampPlaylistWindowController`, `WinampVideoWindowController`, `WinampMilkdropWindowController`). Each injects it into its SwiftUI root with `.environment(windowFocusState)` before wrapping it in an `NSHostingController`.

### 3. Delegate Wiring

At the end of `WindowCoordinator.init`, `WindowDelegateWiring.wire(registry:persistenceDelegate:windowFocusState:)` (`MacAmpApp/Windows/WindowDelegateWiring.swift`) runs once for all five windows. For each existing window it:

1. registers the window with `WindowSnapManager.shared`
2. creates a `WindowDelegateMultiplexer` and adds, in order: `WindowSnapManager.shared`, the `WindowPersistenceDelegate` (if any), and a new `WindowFocusDelegate(kind:focusState:)`
3. sets `window.delegate = multiplexer`

`NSWindow.delegate` is weak, so the returned `WindowDelegateWiring` holds the multiplexers and focus delegates strongly; the coordinator stores it as `delegateWiring`.

### 4. View Layer Usage

```swift
@Environment(WindowFocusState.self) private var windowFocusState
private var isWindowActive: Bool { windowFocusState.isVideoKey }
```

| View | Flag | Active / inactive sprites |
|------|------|---------------------------|
| `WinampMainWindow` | `isMainKey` | `MAIN_TITLE_BAR_SELECTED` / `MAIN_TITLE_BAR` |
| `WinampEqualizerWindow` | `isEqualizerKey` | `EQ_TITLE_BAR_SELECTED` / `EQ_TITLE_BAR` |
| `WinampPlaylistWindow` | `isPlaylistKey` | `_SELECTED` variants (`PLAYLIST_TOP_TILE_SELECTED`, `PLAYLIST_TOP_LEFT_SELECTED` vs `PLAYLIST_TOP_LEFT_CORNER`) |
| `VideoWindowChromeView` | `isVideoKey` | `VIDEO_TITLEBAR_*_ACTIVE` / `_INACTIVE` |
| `MilkdropWindowChromeView` | `isMilkdropKey` | `_SELECTED` suffix; `GEN_TEXT_SELECTED_` letters |

---

## WindowDelegateMultiplexer

`MacAmpApp/Utilities/WindowDelegateMultiplexer.swift` keeps an array of `NSWindowDelegate`s (`add(delegate:)`) and forwards each event (move, resize, become/resign main and key, will close, miniaturize/deminiaturize, …) to all of them via optional chaining. This lets focus tracking coexist with snapping (`WindowSnapManager`) and frame persistence (`WindowPersistenceDelegate`).

---

## State Flow

```
User clicks Video window
  → NSWindow becomes key → multiplexer.windowDidBecomeKey
      ├─ WindowSnapManager.shared
      ├─ WindowPersistenceDelegate
      └─ WindowFocusDelegate(.video): isVideoKey = true, all others false
  → @Observable invalidates views reading those flags
  → VideoWindowChromeView redraws with *_ACTIVE titlebar; previously focused window redraws inactive
```

---

## Adding a New Window

1. Add a case to `WindowKind` (`MacAmpApp/Utilities/WindowSnapManager.swift`)
2. Add an `is<Name>Key` property to `WindowFocusState` (and to `hasAnyFocus`)
3. Update both switches in `WindowFocusDelegate`
4. Add the window to the `windowKinds` list in `WindowDelegateWiring.wire`
5. Pass `windowFocusState` to the window controller and inject it with `.environment(windowFocusState)`
6. Read the flag in the view via `@Environment(WindowFocusState.self)`

Rules: use the single app-wide instance from the environment (never create a local `WindowFocusState`), and derive sprite choice with a computed property rather than caching focus in `@State`.

---

## Troubleshooting

**Window doesn't change titlebar on focus:** confirm the window is in `WindowDelegateWiring`'s `windowKinds` list and exists when `wire` runs, that `window.delegate` is still the multiplexer, that the `WindowKind` matches, and that the view receives `WindowFocusState` from the environment.

**More than one window shows active:** check for a second `WindowFocusState` instance, or a view reading the wrong flag.

---

## Design Alternatives Considered

- **NotificationCenter:** decoupled but string-based and harder to test; delegates are type-safe.
- **Combine publishers:** more machinery than a few booleans need; `@Observable` suffices.
- **`NSApp.keyWindow` only:** not observable from SwiftUI and has timing issues.

---

## References

- [MACAMP_ARCHITECTURE_GUIDE.md](MACAMP_ARCHITECTURE_GUIDE.md) §3 (Three-Layer Architecture)
- [IMPLEMENTATION_PATTERNS.md](IMPLEMENTATION_PATTERNS.md) §2 (State Management)
- [MULTI_WINDOW_ARCHITECTURE.md](MULTI_WINDOW_ARCHITECTURE.md)
