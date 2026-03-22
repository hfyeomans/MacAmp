# Plan: WindowCoordinator DI Migration

> **Purpose:** Implementation plan for migrating WindowCoordinator from global singleton access (`WindowCoordinator.shared?`) to proper `@Environment` dependency injection in all SwiftUI Views. Contains phased approach using WindowCoordinatorProvider wrapper pattern.

> **Task:** Migrate 20 SwiftUI View call sites from `WindowCoordinator.shared?` to `@Environment`
> **Status:** Deferred (will begin after `window-coordinator-cleanup` completes)
> **Prerequisite:** `window-coordinator-cleanup` must be complete (safe optional + DockingController DI)
> **Oracle Review:** Approach validated by gpt-5.3-codex (xhigh) during parent task

---

## Overview

| Metric | Value |
|--------|-------|
| Call sites to migrate | 20 |
| Views to modify | 7 |
| Controllers to modify | 5 |
| New files | 1 (WindowCoordinatorProvider.swift) |
| Files modified | 13 |

---

## Phase 1: Create WindowCoordinatorProvider

### What
Create a new `@Observable` wrapper class that holds an optional WindowCoordinator reference.

### Implementation

**New file:** `MacAmpApp/ViewModels/WindowCoordinatorProvider.swift`

```swift
import Observation

/// Provides WindowCoordinator access to SwiftUI Views via @Environment.
/// Created before WindowCoordinator to break the circular dependency:
/// WindowCoordinator creates controllers → controllers create views → views need coordinator.
@Observable
@MainActor
final class WindowCoordinatorProvider {
    var coordinator: WindowCoordinator?
}
```

### Files Changed
- NEW: `MacAmpApp/ViewModels/WindowCoordinatorProvider.swift`

---

## Phase 2: Inject Provider into Window Controllers

### What
Add `WindowCoordinatorProvider` as a parameter to each window controller and inject via `.environment()`.

### Implementation

Each controller's convenience init gains a `coordinatorProvider` parameter:

```swift
// WinampMainWindowController.swift:
convenience init(
    skinManager: SkinManager,
    audioPlayer: AudioPlayer,
    ...,
    coordinatorProvider: WindowCoordinatorProvider  // NEW
) {
    let rootView = WinampMainWindow()
        .environment(skinManager)
        .environment(audioPlayer)
        ...
        .environment(coordinatorProvider)  // NEW
}
```

### WindowCoordinator.init() Changes

```swift
// WindowCoordinator.swift:
let coordinatorProvider = WindowCoordinatorProvider()

registry = WindowRegistry(
    mainController: WinampMainWindowController(
        ...,
        coordinatorProvider: coordinatorProvider  // NEW
    ),
    // ... same for all 5 controllers
)

// After self is fully initialized:
coordinatorProvider.coordinator = self
```

### Files Changed
- `MacAmpApp/Windows/WinampMainWindowController.swift`
- `MacAmpApp/Windows/WinampEqualizerWindowController.swift`
- `MacAmpApp/Windows/WinampPlaylistWindowController.swift`
- `MacAmpApp/Windows/WinampVideoWindowController.swift`
- `MacAmpApp/Windows/WinampMilkdropWindowController.swift`
- `MacAmpApp/ViewModels/WindowCoordinator.swift`

---

## Phase 3: Migrate View Usages (One Window at a Time)

### Migration Pattern

```swift
// BEFORE:
WindowCoordinator.shared?.minimizeKeyWindow()

// AFTER:
@Environment(WindowCoordinatorProvider.self) var coordinatorProvider

coordinatorProvider.coordinator?.minimizeKeyWindow()
```

### Migration Order (simplest → most complex)

| Order | File | Usages | Complexity |
|-------|------|--------|-----------|
| 1 | WinampEqualizerWindow.swift | 2 | Low (button actions only) |
| 2 | WinampVideoWindow.swift | 1 | Low (onAppear only) |
| 3 | WinampMilkdropWindow.swift | 1 | Low (onAppear only) |
| 4 | MilkdropWindowChromeView.swift | 2 | Low (resize actions) |
| 5 | WinampMainWindow.swift | 3 | Medium (includes reactive observation) |
| 6 | VideoWindowChromeView.swift | 4 | Medium (resize + gestures) |
| 7 | WinampPlaylistWindow.swift | 6 | Medium (resize gestures + preview) |

**Build + test after each file migration.**

### Files Changed
- `MacAmpApp/Views/WinampEqualizerWindow.swift`
- `MacAmpApp/Views/WinampVideoWindow.swift`
- `MacAmpApp/Views/WinampMilkdropWindow.swift`
- `MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift`
- `MacAmpApp/Views/WinampMainWindow.swift`
- `MacAmpApp/Views/Windows/VideoWindowChromeView.swift`
- `MacAmpApp/Views/WinampPlaylistWindow.swift`

---

## Phase 4: Cleanup

### What
- Remove remaining `WindowCoordinator.shared` references from Views
- Consider removing `static var shared` entirely if no non-View callers remain
- Oracle review on all changed files

### Verification
- Build with Thread Sanitizer
- Run full test suite
- Manual test: all windows render, button actions work, resize gestures work
- Manual test: DockingController toggle EQ/Playlist (uses property injection from cleanup task)

---

## Risk Assessment

| Risk | Likelihood | Severity | Mitigation |
|------|-----------|----------|-----------|
| Missing environment injection (runtime crash) | Medium | High | Test every window individually |
| Optional chaining on coordinator (nil at body eval) | Low | Medium | Coordinator set before first user interaction |
| @Observable re-render on provider change | Low | Low | Provider only changes once (nil → coordinator) |
| Regression in resize gestures | Low | Medium | Manual test playlist + video resize |

---

## Out of Scope

1. Removing `WindowCoordinator.shared` entirely (may still be needed for edge cases)
2. WindowSnapManager.shared singleton migration
3. macOS 26 Observations AsyncSequence migration
4. Protocol abstractions for WindowCoordinator (not needed yet)
