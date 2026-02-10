# Research: WindowCoordinator Cleanup (3 LOW Priority Issues)

> **Purpose:** Research findings for resolving 3 deferred LOW priority issues from the WindowCoordinator refactoring Oracle review. Contains analysis of each issue, SkinManager loading lifecycle, singleton usage patterns, and @Environment injection feasibility.

> **Source:** Issues identified during WindowCoordinator refactoring Oracle review (2026-02-09)
> **Task ID:** window-coordinator-cleanup
> **Branch:** `refactor/window-coordinator-cleanup`

---

## Issue 1: Polling Loop Optimization

### Current Behavior

`WindowCoordinator+Layout.swift` lines 110-126 poll every 50ms waiting for SkinManager:

```swift
func presentWindowsWhenReady() {
    if canPresentImmediately { presentInitialWindows(); return }
    skinPresentationTask?.cancel()
    skinPresentationTask = Task { @MainActor [weak self] in
        while !self.canPresentImmediately {
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(50))  // POLLING
        }
        if Task.isCancelled { return }
        self.presentInitialWindows()
    }
}
```

### SkinManager Loading Lifecycle

SkinManager is `@Observable` with three relevant properties:
- `isLoading: Bool` - true during async skin load
- `currentSkin: Skin?` - set when load succeeds (line 749)
- `loadingError: String?` - set when load fails (line 601)

State transitions:
1. `loadSkin()` called -> `isLoading = true`, `loadingError = nil`
2. Archive loaded + sprites extracted on background thread
3. `applySkinPayload()` -> `currentSkin = newSkin`, `isLoading = false`
4. OR error occurs -> `loadingError = message`, `isLoading = false`

### Recommended: withObservationTracking

Replace polling with `withObservationTracking` - the same pattern already proven in `WindowSettingsObserver.swift`. Since SkinManager is `@Observable`, property changes automatically trigger the onChange callback.

**Approach: Inline in WindowCoordinator+Layout.swift** (simplest, ~20 lines changed)

**Why not a separate observer class:** This is a one-shot observation (fires once, then done). Unlike WindowSettingsObserver which observes 4 properties continuously, this observes 3 properties until a single condition is met. A separate class would be over-engineering.

**Why not AsyncStream/Combine/NotificationCenter:** SkinManager is already `@Observable`. Using `withObservationTracking` leverages existing infrastructure with zero additional dependencies.

### Oracle Finding: Async Registration Race (HIGH)

The initial proposed implementation wraps `withObservationTracking` inside `Task { @MainActor }`, creating an async gap. If skin readiness flips before the task runs, no `onChange` fires and windows remain hidden.

**Fix:** Use synchronous registration (no wrapping Task), then immediate re-check after registration. See updated implementation in plan.md.

---

## Issue 2: Remove Unused lastVideoAttachment

### Current Code

`WindowResizeController.swift` line 9:
```swift
private var lastVideoAttachment: VideoAttachmentSnapshot?
```

### Analysis

- Declared but **never read** anywhere in the codebase (confirmed via grep)
- `lastPlaylistAttachment` (line 8) IS actively used for docking memory in `makePlaylistDockingContext()`
- `lastVideoAttachment` was intended for future video window docking memory (analogous to playlist) but was never implemented
- The `makeVideoDockingContext()` method (lines 143-169) does NOT use any saved attachment state - it only checks live cluster positions
- **Oracle confirmed:** Safe to remove. It is private and only declared once, with no reads.

### Action

Remove the unused property. If video docking memory is needed in the future, it can be added then with proper read/write implementation.

---

## Issue 3: Migrate Singleton to DI

### Current Code

`WindowCoordinator.swift` line 8:
```swift
static var shared: WindowCoordinator!  // Initialized in MacAmpApp.init()
```

### Usage Analysis (22 call sites)

**SwiftUI View contexts (20 usages) - @Environment eligible:**
- `WinampMainWindow.swift`: 3 usages (minimize, toggle EQ/Playlist visibility)
- `WinampPlaylistWindow.swift`: 6 usages (minimize, hide, resize, preview)
- `WinampEqualizerWindow.swift`: 2 usages (minimize, hide)
- `WinampVideoWindow.swift`: 1 usage (updateVideoWindowSize)
- `WinampMilkdropWindow.swift`: 1 usage (updateMilkdropWindowSize)
- `VideoWindowChromeView.swift`: 4 usages (resize, button handling)
- `MilkdropWindowChromeView.swift`: 2 usages (resize, button handling)
- `WinampPlaylistWindow.swift` (PlaylistWindowActions): 1 usage

**Non-SwiftUI contexts (2 usages) - Need DI injection:**
- `DockingController.swift` line 79: `togglePlaylist()` syncs NSWindow visibility
- `DockingController.swift` line 92: `toggleEqualizer()` syncs NSWindow visibility

### Existing @Environment Pattern

The codebase already injects 8+ models via `@Environment`:
- AppSettings, SkinManager, AudioPlayer, DockingController, PlaybackCoordinator, WindowFocusState, RadioStationLibrary, StreamPlayer

All follow the same pattern in window controllers:
```swift
// WinampMainWindowController.swift:
let rootView = WinampMainWindow()
    .environment(skinManager)
    .environment(audioPlayer)
    .environment(dockingController)
    // etc.
```

### Circular Dependency Challenge

WindowCoordinator creates window controllers during its init. The controllers create SwiftUI views that need WindowCoordinator. But WindowCoordinator doesn't exist yet during init.

```
MacAmpApp.init()
  → WindowCoordinator.init()
    → WindowRegistry(mainController: WinampMainWindowController(...))
      → NSHostingController(rootView: WinampMainWindow().environment(...))
        → View needs WindowCoordinator, but it doesn't exist yet!
  → WindowCoordinator.shared = coordinator  // Too late for views
```

### Oracle Findings on DI Migration

1. **Scene-level `.environment()` won't reach AppKit windows** - Views are created in window controllers, not from MacAmpApp scene body. The `.environment()` chain in MacAmpApp.swift only affects the placeholder WindowGroup, not the NSWindow-hosted views.

2. **Post-init rootView replacement is risky** - Can reset SwiftUI view state, re-trigger onAppear, and requires controller access that WindowRegistry currently hides.

3. **Oracle recommendation:** Use **WindowCoordinatorProvider wrapper** pattern instead of post-init rootView swapping.

4. **Missing `@Environment` is a runtime failure**, not build-time (corrected from initial research).

5. **Scope recommendation:** Phase 3C/3D (@Environment injection + view conversion) is too large for a "LOW cleanup" task. Split into a separate DI migration task. Keep 3A/3B (safe optional + DockingController injection) in this cleanup.

6. **DockingController injection:** Mark coordinator reference as `@ObservationIgnored` to prevent unintended observation tracking.

### Revised Migration Strategy

**In this task (scope-appropriate):**
- 3A: Change `!` to `?` (safe optional)
- 3B: Inject into DockingController via `@ObservationIgnored weak var`

**Deferred to separate task:**
- Full @Environment migration using WindowCoordinatorProvider wrapper
- View conversion from `WindowCoordinator.shared?` to `@Environment`

---

## Dependencies Between Issues

```
Issue 1 (Remove lastVideoAttachment) ← No dependencies, standalone
Issue 2 (Polling → Observation)      ← No dependencies, standalone
Issue 3 (Safe optional + DockingController DI) ← No dependencies on 1 or 2
```

All three issues are independent. Recommended order: 1 → 2 → 3 (simplest to most complex).
