# Research: WindowCoordinator DI Migration

> **Purpose:** Research findings for migrating WindowCoordinator from a global singleton (`WindowCoordinator.shared`) to proper dependency injection via SwiftUI `@Environment`. Contains circular dependency analysis, injection approach comparison, usage audit, and Oracle findings from the parent cleanup task.

> **Task ID:** window-coordinator-di-migration
> **Status:** Deferred (created during `window-coordinator-cleanup`)
> **Parent Task:** `tasks/window-coordinator-cleanup/`
> **Prerequisite:** Complete `window-coordinator-cleanup` first (safe optional + DockingController DI)

---

## Background

During the WindowCoordinator refactoring (PR #45), the Oracle identified `WindowCoordinator.shared!` as a LOW priority issue. The parent cleanup task (`window-coordinator-cleanup`) handles:
- Changing `!` to `?` (safe optional)
- Injecting into DockingController via stored property

This task handles the remaining work: full `@Environment` injection for all 20 SwiftUI View call sites.

---

## The Circular Dependency Problem

WindowCoordinator creates window controllers during its init. The controllers create SwiftUI views that need WindowCoordinator. But WindowCoordinator doesn't exist yet during init.

```
MacAmpApp.init()
  → WindowCoordinator.init()
    → WindowRegistry(mainController: WinampMainWindowController(...))
      → NSHostingController(rootView: WinampMainWindow().environment(...))
        → View needs WindowCoordinator, but it doesn't exist yet!
  → WindowCoordinator.shared = coordinator  // Too late for views
```

This prevents simple `@Environment(WindowCoordinator.self)` injection because the coordinator must be provided before the view body is evaluated, but it doesn't exist when the hosting controller is created.

---

## Approach Comparison

### Option A: Post-init rootView Replacement (NOT RECOMMENDED)

After WindowCoordinator is created, update each NSHostingController's rootView to include `.environment(coordinator)`.

**Problems (Oracle MEDIUM finding):**
- Can reset SwiftUI view state and re-trigger `onAppear` side effects
- Requires controller access that `WindowRegistry` currently hides (controllers are private)
- Each hosting controller has a different generic type parameter, making type-erased updates complex
- Fragile: any change to rootView structure breaks the update

### Option B: WindowCoordinatorProvider Wrapper (RECOMMENDED)

Create an `@Observable` wrapper that's injected before WindowCoordinator exists, then populated after:

```swift
@Observable
@MainActor
final class WindowCoordinatorProvider {
    var coordinator: WindowCoordinator?
}
```

**Flow:**
1. MacAmpApp.init() creates `WindowCoordinatorProvider` (empty)
2. Provider injected into all window controllers via `.environment(provider)`
3. WindowCoordinator created
4. `provider.coordinator = coordinator` (Views now have access)
5. Views use `@Environment(WindowCoordinatorProvider.self) var provider`

**Advantages:**
- No circular dependency
- No rootView replacement
- Provider is `@Observable` - views automatically update when coordinator is set
- Clean, testable, follows existing codebase patterns

**Disadvantages:**
- One level of indirection (`provider.coordinator?.method()`)
- Views still need optional chaining unless coordinator is guaranteed set before first body eval

### Option C: Restructure Creation Flow (CLEANEST but LARGEST)

Move window controller creation out of WindowCoordinator into MacAmpApp:

```swift
// MacAmpApp.init():
let mainController = WinampMainWindowController(...)
let coordinator = WindowCoordinator(registry: WindowRegistry(...))
// Now inject coordinator into controllers' environments
```

**Problems:**
- Major restructuring of init flow
- WindowCoordinator currently creates controllers with specific params
- Breaks encapsulation of WindowCoordinator's internal setup
- Highest risk for regressions

---

## Usage Audit (20 SwiftUI View Call Sites)

### WinampMainWindow.swift (3 usages)

| Line | Context | Usage |
|------|---------|-------|
| 284 | Button action (titlebar) | `WindowCoordinator.shared?.minimizeKeyWindow()` |
| 550 | Computed property | `let coordinator = WindowCoordinator.shared` for EQ/Playlist visibility |
| ~562 | Button action | `coordinator?.toggleEQWindowVisibility()` |

**Note:** Line 550 accesses `isEQWindowVisible` and `isPlaylistWindowVisible` for reactive button sprite selection. With @Environment, this becomes non-optional observation.

### WinampPlaylistWindow.swift (6 usages)

| Line | Context | Usage |
|------|---------|-------|
| 367 | onAppear | `WindowCoordinator.shared?.updatePlaylistWindowSize(to:)` |
| 372 | onChange | `WindowCoordinator.shared?.updatePlaylistWindowSize(to:)` |
| 739 | Button action | `WindowCoordinator.shared?.minimizeKeyWindow()` |
| 755 | Button action | `WindowCoordinator.shared?.hidePlaylistWindow()` |
| 795 | Resize gesture | `WindowCoordinator.shared?.showPlaylistResizePreview()` |
| 816 | Resize gesture | `WindowCoordinator.shared?.hidePlaylistResizePreview()` |

### WinampEqualizerWindow.swift (2 usages)

| Line | Context | Usage |
|------|---------|-------|
| 134 | Button action | `WindowCoordinator.shared?.minimizeKeyWindow()` |
| 154 | Button action | `WindowCoordinator.shared?.hideEQWindow()` |

### WinampVideoWindow.swift (1 usage)

| Line | Context | Usage |
|------|---------|-------|
| 56 | onAppear | `WindowCoordinator.shared?.updateVideoWindowSize(to:)` |

### WinampMilkdropWindow.swift (1 usage)

| Line | Context | Usage |
|------|---------|-------|
| 62 | onAppear | `WindowCoordinator.shared?.updateMilkdropWindowSize(to:)` |

### VideoWindowChromeView.swift (4 usages)

| Line | Context | Usage |
|------|---------|-------|
| 250 | Resize action | `WindowCoordinator.shared?.updateVideoWindowSize(to:)` |
| 269 | Resize action | `WindowCoordinator.shared?.updateVideoWindowSize(to:)` |
| 313 | Resize gesture | `WindowCoordinator.shared?.showVideoResizePreview()` |
| 334 | Resize gesture | `WindowCoordinator.shared?.hideVideoResizePreview()` |

### MilkdropWindowChromeView.swift (2 usages)

| Line | Context | Usage |
|------|---------|-------|
| 182 | Resize action | `WindowCoordinator.shared?.updateMilkdropWindowSize(to:)` |
| 202 | Resize action | `WindowCoordinator.shared?.updateMilkdropWindowSize(to:)` |

---

## Window Controller Environment Chains

Each window controller already injects 7+ models via `.environment()`. Adding the provider is a single additional line per controller:

```swift
// WinampMainWindowController.swift (and 4 siblings):
let rootView = WinampMainWindow()
    .environment(skinManager)
    .environment(audioPlayer)
    .environment(dockingController)
    .environment(settings)
    .environment(radioLibrary)
    .environment(playbackCoordinator)
    .environment(windowFocusState)
    .environment(coordinatorProvider)  // NEW
```

**Controllers to modify (5):**
- `MacAmpApp/Windows/WinampMainWindowController.swift`
- `MacAmpApp/Windows/WinampEqualizerWindowController.swift`
- `MacAmpApp/Windows/WinampPlaylistWindowController.swift`
- `MacAmpApp/Windows/WinampVideoWindowController.swift`
- `MacAmpApp/Windows/WinampMilkdropWindowController.swift`

---

## Oracle Findings (from parent task review)

| # | Severity | Finding | Implication for This Task |
|---|----------|---------|--------------------------|
| 1 | MEDIUM | Scene `.environment()` won't reach AppKit windows | Must inject via window controllers, not MacAmpApp.swift body |
| 2 | MEDIUM | Post-init rootView replacement risky | Use WindowCoordinatorProvider wrapper instead |
| 3 | LOW | Missing @Environment is runtime failure, not build-time | Need thorough testing after migration |
| 4 | - | Oracle scope recommendation | This task is the deferred portion |

---

## Implementation Considerations

### View Pattern After Migration

```swift
// BEFORE:
WindowCoordinator.shared?.minimizeKeyWindow()

// AFTER (with provider):
@Environment(WindowCoordinatorProvider.self) var coordinatorProvider

coordinatorProvider.coordinator?.minimizeKeyWindow()
```

**Note:** Still requires optional chaining because coordinator is set after view creation. However, by the time any user interaction occurs (button press, gesture), the coordinator is guaranteed to be set. The optional chaining is a safety measure, not a real concern.

### Testing Strategy

- Missing `@Environment` injection causes **runtime crash** (not compile-time)
- Must test every window individually after migration
- Use Thread Sanitizer for all builds
- Manual test: all button actions, resize gestures, visibility toggles

### Migration Order

Recommended: migrate one window at a time, build + test after each:
1. WinampEqualizerWindow (simplest, 2 usages)
2. WinampVideoWindow (1 usage)
3. WinampMilkdropWindow (1 usage)
4. WinampMainWindow (3 usages, includes reactive observation)
5. WinampPlaylistWindow (6 usages, includes resize gestures)
6. VideoWindowChromeView (4 usages)
7. MilkdropWindowChromeView (2 usages)
