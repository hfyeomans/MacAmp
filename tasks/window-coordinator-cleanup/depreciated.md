# Deprecated Code & Patterns: WindowCoordinator Cleanup

> **Purpose:** Tracks deprecated patterns being removed or replaced during this cleanup task. Per project conventions, we document deprecated/legacy code here instead of adding inline comments in source files. Updated as each phase completes.

---

## Patterns Deprecated (Completed)

### 1. Polling Loop for Skin Readiness

**File:** `MacAmpApp/ViewModels/WindowCoordinator+Layout.swift`
**Status:** REMOVED

```swift
// DEPRECATED: Polling loop (50ms interval)
skinPresentationTask = Task { @MainActor [weak self] in
    while !self.canPresentImmediately {
        if Task.isCancelled { return }
        try? await Task.sleep(for: .milliseconds(50))  // CPU waste
    }
    self.presentInitialWindows()
}
```

**Replacement:** Synchronous `withObservationTracking` on SkinManager's `@Observable` properties. Event-driven, zero polling, immediate response.

---

### 2. Unused Video Attachment State

**File:** `MacAmpApp/Windows/WindowResizeController.swift`
**Status:** REMOVED

```swift
// DEPRECATED: Dead code - declared but never read
private var lastVideoAttachment: VideoAttachmentSnapshot?
```

**Replacement:** Removed entirely. Oracle confirmed safe (private, single declaration, no reads).

---

### 3. Force-Unwrapped Singleton

**File:** `MacAmpApp/ViewModels/WindowCoordinator.swift`
**Status:** REMOVED

```swift
// DEPRECATED: Force-unwrapped global singleton
// swiftlint:disable:next implicitly_unwrapped_optional
static var shared: WindowCoordinator!
```

**Replacement:** Safe optional `static var shared: WindowCoordinator?`. All callers already use optional chaining.

---

### 4. Direct Singleton Access in DockingController

**File:** `MacAmpApp/ViewModels/DockingController.swift`
**Status:** REMOVED

```swift
// DEPRECATED: Direct singleton access in non-View type
if let coordinator = WindowCoordinator.shared {
```

**Replacement:** `@ObservationIgnored weak var windowCoordinator: WindowCoordinator?` property injected via MacAmpApp.init().

---

### 5. Direct Singleton Access from Views (DEFERRED)

**Files:** All View files using `WindowCoordinator.shared?`
**Status:** Deferred to `tasks/window-coordinator-di-migration/` (task folder created with full research, plan, and todo)

```swift
// DEPRECATED (future): Direct singleton access in SwiftUI Views
WindowCoordinator.shared?.minimizeKeyWindow()
```

**Future replacement:** `@Environment(WindowCoordinator.self)` via WindowCoordinatorProvider wrapper.
**Reason for deferral:** Oracle recommended splitting full @Environment migration into separate task (too large for LOW cleanup scope).

---

## Summary

All 4 in-scope deprecations have been completed. Item 5 (View singleton access) remains deferred to `tasks/window-coordinator-di-migration/`.

**Oracle post-implementation review** (gpt-5.3-codex, xhigh): No code-level correctness issues found. All changes verified for thread safety, retain cycle safety, and observation pattern correctness.
