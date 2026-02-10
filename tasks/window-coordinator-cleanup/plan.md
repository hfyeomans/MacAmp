# Plan: WindowCoordinator Cleanup

> **Purpose:** Implementation plan for resolving 3 deferred LOW priority issues from the WindowCoordinator refactoring Oracle review. Contains phased approach, code changes, and verification steps for each issue.

> **Task:** Resolve 3 LOW priority issues from the WindowCoordinator refactoring Oracle review
> **Branch:** `refactor/window-coordinator-cleanup`
> **Prerequisite:** WindowCoordinator refactoring complete (PR #45 merged)
> **Oracle Review:** gpt-5.3-codex (reasoningEffort: xhigh) - Plan revised per findings

---

## Issue Breakdown

| # | Issue | Complexity | Files Changed |
|---|-------|-----------|---------------|
| 1 | Remove unused `lastVideoAttachment` | Trivial | 1 file |
| 2 | Replace polling loop with observation | Low | 1 file |
| 3 | Safe optional singleton + DockingController DI | Low | 3 files |

**Deferred to:** `tasks/window-coordinator-di-migration/` - Full @Environment migration using WindowCoordinatorProvider wrapper + 20 view conversions (Oracle: too large for LOW cleanup scope)

---

## Phase 1: Remove Unused `lastVideoAttachment` (Trivial)

### What
Remove `private var lastVideoAttachment: VideoAttachmentSnapshot?` from `WindowResizeController.swift` line 9.

### Why
- Declared but never read anywhere in the codebase (Oracle confirmed safe)
- Unlike `lastPlaylistAttachment` which IS actively used for docking memory
- Dead code should be removed, not left as placeholders (per project conventions)

### Files Changed
- `MacAmpApp/Windows/WindowResizeController.swift`: Remove line 9

### Verification
- Build with Thread Sanitizer
- Grep confirms no remaining references

---

## Phase 2: Replace Polling Loop with Observation (Low Complexity)

### What
Replace `presentWindowsWhenReady()` polling loop (50ms interval) with event-driven `withObservationTracking` on SkinManager's `@Observable` properties.

### Why
- SkinManager is `@Observable` with `isLoading`, `currentSkin`, `loadingError` properties
- `withObservationTracking` is already proven in `WindowSettingsObserver.swift`
- Eliminates CPU-wasting polling during app startup
- Immediate response vs up to 50ms latency

### Oracle-Corrected Implementation

**Critical fix (HIGH finding):** The initial implementation wrapped `withObservationTracking` inside `Task { @MainActor }`, creating an async gap. If skin readiness flips before the task runs, no `onChange` fires. Fixed by using synchronous registration with an immediate re-check.

```swift
import Observation  // Required (Oracle LOW finding)

func presentWindowsWhenReady() {
    if canPresentImmediately {
        presentInitialWindows()
        return
    }
    observeSkinReadiness()
}

private func observeSkinReadiness() {
    skinPresentationTask?.cancel()
    // Synchronous registration - no async gap
    withObservationTracking {
        _ = self.skinManager.isLoading
        _ = self.skinManager.currentSkin
        _ = self.skinManager.loadingError
    } onChange: {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.canPresentImmediately {
                self.presentInitialWindows()
            } else {
                self.observeSkinReadiness()
            }
        }
    }
    // Immediate re-check after registration (handles race)
    if canPresentImmediately {
        skinPresentationTask?.cancel()
        presentInitialWindows()
    }
}
```

**Key differences from initial proposal:**
1. `withObservationTracking` called synchronously (not inside a Task)
2. Immediate `canPresentImmediately` re-check after registration
3. `import Observation` added to file
4. `skinPresentationTask` no longer wraps the observation (only used for cancellation tracking if needed)

### Files Changed
- `MacAmpApp/ViewModels/WindowCoordinator+Layout.swift`: Replace `presentWindowsWhenReady()`, add `observeSkinReadiness()`, add `import Observation`

### Verification
- Build with Thread Sanitizer
- Manual test: Launch app, verify windows appear correctly
- Manual test: Verify no visual delay on app startup

---

## Phase 3: Safe Optional Singleton + DockingController DI (Low Complexity)

### What
1. Remove force-unwrap from WindowCoordinator singleton
2. Inject WindowCoordinator into DockingController via stored property

### Why
- Force-unwrapped optional (`!`) crashes on nil access - unsafe
- DockingController should receive dependencies explicitly, not via global singleton
- All existing callers already use optional chaining - zero-risk change

### 3A: Safe Singleton

```swift
// BEFORE:
// swiftlint:disable:next implicitly_unwrapped_optional
static var shared: WindowCoordinator!  // Initialized in MacAmpApp.init()

// AFTER:
static var shared: WindowCoordinator?  // Initialized in MacAmpApp.init()
```

**Note (Oracle MEDIUM finding):** Using `static var shared: WindowCoordinator?` (not `private(set)`) because MacAmpApp.swift assigns to it from outside the module. The `private(set)` would prevent the assignment at `MacAmpApp.swift:42`.

### 3B: DockingController Property Injection

```swift
// DockingController.swift - add property:
@ObservationIgnored weak var windowCoordinator: WindowCoordinator?

// Replace WindowCoordinator.shared with self.windowCoordinator in:
// - togglePlaylist() (line 79)
// - toggleEqualizer() (line 92)
```

**Oracle finding:** Mark as `@ObservationIgnored` to prevent unintended observation tracking of the coordinator through DockingController.

```swift
// MacAmpApp.swift - after WindowCoordinator creation:
WindowCoordinator.shared = coordinator
dockingController.windowCoordinator = coordinator
```

### Files Changed
- `MacAmpApp/ViewModels/WindowCoordinator.swift`: Change `shared` type, remove swiftlint disable
- `MacAmpApp/ViewModels/DockingController.swift`: Add `windowCoordinator` property, replace 2 usages
- `MacAmpApp/MacAmpApp.swift`: Add `dockingController.windowCoordinator = coordinator`

### Verification
- Build with Thread Sanitizer
- Run full test suite
- Manual test: Toggle EQ/Playlist via DockingController (keyboard shortcuts)
- Manual test: All windows render and function correctly

---

## Oracle Review Summary

### Findings Applied to Plan

| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| 1 | **HIGH** | Async registration race in observation | Fixed: synchronous `withObservationTracking` + immediate re-check |
| 2 | **MEDIUM** | Scene `.environment()` won't reach AppKit windows | Deferred: full @Environment migration to separate task |
| 3 | **MEDIUM** | `private(set)` prevents external assignment | Fixed: use `static var shared: WindowCoordinator?` (no `private(set)`) |
| 4 | **MEDIUM** | Post-init rootView replacement risky | Deferred: using WindowCoordinatorProvider in future task |
| 5 | **LOW** | Missing `import Observation` | Fixed: added to plan |
| 6 | **LOW** | Missing environment is runtime, not build-time | Corrected in research.md |

### Scope Decision

Oracle recommended splitting Phase 3C/3D (full @Environment migration) into a separate task. This plan now covers:
- Phase 1: Remove dead code (trivial)
- Phase 2: Observation-based skin readiness (low)
- Phase 3A+3B: Safe optional + DockingController DI (low)

**Deferred to:** `tasks/window-coordinator-di-migration/` (task folder created with full research, plan, and todo)
- WindowCoordinatorProvider wrapper class
- @Environment injection in all 5 window controllers
- View conversion (20 call sites)

---

## Risk Assessment

| Phase | Risk | Mitigation |
|-------|------|-----------|
| 1 | Zero | Property is confirmed unused (Oracle confirmed) |
| 2 | Low | Same pattern as WindowSettingsObserver; race condition fixed per Oracle |
| 3A | Zero | All callers already use optional chaining |
| 3B | Low | Simple property injection, 2 call sites, @ObservationIgnored per Oracle |

---

## Implementation Order

1. Phase 1 (trivial) -> Build + verify
2. Phase 2 (low) -> Build + verify + manual test
3. Phase 3A + 3B (low) -> Build + verify + test suite
4. Post-implementation Oracle review on all changed files
5. Update task documentation (state.md, depreciated.md, todo.md)

---

## Out of Scope

1. **Full @Environment DI migration** (deferred to `tasks/window-coordinator-di-migration/` per Oracle)
2. **WindowSnapManager.shared singleton** (separate concern)
3. **macOS 26 `Observations` AsyncSequence** (requires new minimum target)
4. **Additional unit tests for controllers** (separate task)
