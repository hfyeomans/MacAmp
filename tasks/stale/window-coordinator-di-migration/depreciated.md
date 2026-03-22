# Deprecated Code & Patterns: WindowCoordinator DI Migration

> **Purpose:** Tracks deprecated patterns being removed or replaced during this DI migration task. Per project conventions, we document deprecated/legacy code here instead of adding inline comments in source files. Updated as each phase completes.

---

## Patterns to Deprecate

### 1. Direct Singleton Access from SwiftUI Views

**Files:** 7 View files (20 total call sites)
**Status:** Pending migration (task deferred)

```swift
// DEPRECATED: Direct singleton access in SwiftUI Views
WindowCoordinator.shared?.minimizeKeyWindow()
WindowCoordinator.shared?.updateVideoWindowSize(to: size)
WindowCoordinator.shared?.showPlaylistResizePreview(overlay, previewSize: size)
// etc. (20 call sites across 7 files)
```

**Replacement:**
```swift
@Environment(WindowCoordinatorProvider.self) var coordinatorProvider

coordinatorProvider.coordinator?.minimizeKeyWindow()
```

**Files affected:**
- `WinampMainWindow.swift` (3 usages)
- `WinampPlaylistWindow.swift` (6 usages)
- `WinampEqualizerWindow.swift` (2 usages)
- `WinampVideoWindow.swift` (1 usage)
- `WinampMilkdropWindow.swift` (1 usage)
- `VideoWindowChromeView.swift` (4 usages)
- `MilkdropWindowChromeView.swift` (2 usages)

---

## Completed Deprecations

_(Will be updated as each phase completes)_
