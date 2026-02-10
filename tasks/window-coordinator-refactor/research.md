# Research: WindowCoordinator Refactoring

## 1. Current State Analysis

### File Under Examination
- **Path:** `MacAmpApp/ViewModels/WindowCoordinator.swift`
- **Size:** 1,357 lines
- **Annotations:** `@MainActor @Observable final class`
- **Singleton Access:** `static var shared: WindowCoordinator!` (force-unwrapped implicitly unwrapped optional)

### Responsibility Inventory (10 Concerns Identified)

| # | Responsibility | Lines (approx) | Coupling |
|---|---------------|----------------|----------|
| 1 | **Window Creation & Init** | 108-300 | NSWindowController, SkinManager, AudioPlayer, DockingController, AppSettings, RadioStationLibrary, PlaybackCoordinator, WindowFocusState |
| 2 | **Window Visibility (Show/Hide/Toggle)** | 748-1278 | NSWindow orderFront/orderOut, observable `isEQWindowVisible` / `isPlaylistWindowVisible` |
| 3 | **Docking Geometry Calculations** | 503-690 | WindowSnapManager, PlaylistDockingContext, VideoAttachmentSnapshot, SnapUtils |
| 4 | **Window Persistence** | 1073-1327 | WindowFrameStore (nested struct), UserDefaults, PersistedWindowFrame (nested Codable struct) |
| 5 | **Settings Observation** | 302-416 | withObservationTracking recursive pattern for `isAlwaysOnTop`, `isDoubleSizeMode`, `showVideoWindow`, `showMilkdropWindow` |
| 6 | **Window Level Management** | 929-936 | NSWindow.Level, `.floating` vs `.normal` |
| 7 | **Delegate Multiplexing** | 240-299 | WindowDelegateMultiplexer, WindowPersistenceDelegate, WindowFocusDelegate, WindowSnapManager |
| 8 | **Window Focus Tracking** | 276-299 | WindowFocusDelegate, WindowFocusState |
| 9 | **Debug Logging** | 883-927 | AppLog.debug calls, `debugLogWindowPositions`, `logDoubleSizeDebug`, `logDockingStage` |
| 10 | **Resize Coordination** | 423-868 | Main/EQ double-size, Playlist resize, Video resize, Milkdrop resize |

### Dependency Graph

```
MacAmpApp.init()
    └── WindowCoordinator.init(skinManager:, audioPlayer:, dockingController:,
                               settings:, radioLibrary:, playbackCoordinator:,
                               windowFocusState:)

Callers via WindowCoordinator.shared:
    ├── WinampMainWindow.swift      → toggleEQWindowVisibility(), togglePlaylistWindowVisibility(),
    │                                  minimizeKeyWindow(), isEQWindowVisible, isPlaylistWindowVisible
    ├── WinampEqualizerWindow.swift  → minimizeKeyWindow(), hideEQWindow()
    ├── WinampPlaylistWindow.swift   → updatePlaylistWindowSize(), minimizeKeyWindow(),
    │                                  hidePlaylistWindow(), showPlaylistResizePreview(),
    │                                  hidePlaylistResizePreview(), playlistWindow
    ├── WinampVideoWindow.swift      → updateVideoWindowSize()
    ├── WinampMilkdropWindow.swift   → updateMilkdropWindowSize()
    ├── VideoWindowChromeView.swift  → showVideoResizePreview(), hideVideoResizePreview(),
    │                                  updateVideoWindowSize()
    ├── MilkdropWindowChromeView.swift → updateMilkdropWindowSize()
    ├── DockingController.swift      → showPlaylistWindow(), hidePlaylistWindow(),
    │                                  showEQWindow(), hideEQWindow()
    └── AppCommands.swift            → (indirect via DockingController + AppSettings toggles)
```

### Public API Surface (Methods + Properties Used Externally)

**Properties (observable):**
- `isEQWindowVisible: Bool`
- `isPlaylistWindowVisible: Bool`
- `mainWindow: NSWindow?`
- `eqWindow: NSWindow?`
- `playlistWindow: NSWindow?`
- `videoWindow: NSWindow?`
- `milkdropWindow: NSWindow?`

**Methods:**
- `minimizeKeyWindow()`
- `closeKeyWindow()`
- `showEQWindow()` / `hideEQWindow()` / `toggleEQWindowVisibility() -> Bool`
- `showPlaylistWindow()` / `hidePlaylistWindow()` / `togglePlaylistWindowVisibility() -> Bool`
- `showVideo()` / `hideVideo()` / `showMilkdrop()` / `hideMilkdrop()`
- `showMain()` / `hideMain()` / `showEqualizer()` / `hideEqualizer()` / `showPlaylist()` / `hidePlaylist()`
- `showAllWindows()`
- `resetToDefaultStack()`
- `updatePlaylistWindowSize(to:)`
- `updateVideoWindowSize(to:)`
- `updateMilkdropWindowSize(to:)`
- `showVideoResizePreview(_:previewSize:)` / `hideVideoResizePreview(_:)`
- `showPlaylistResizePreview(_:previewSize:)` / `hidePlaylistResizePreview(_:)`

### Anti-Patterns Identified

1. **God Object**: Single class handles 10 orthogonal responsibilities
2. **Static Singleton with Force-Unwrap**: `static var shared: WindowCoordinator!` -- fragile, untestable
3. **Recursive `withObservationTracking`**: Used 4 times with identical boilerplate (setupAlwaysOnTopObserver, setupDoubleSizeObserver, setupVideoWindowObserver, setupMilkdropWindowObserver). This pattern is replaced by `Observations` AsyncSequence in Swift 6.2.
4. **Deeply Nested Init**: The `init()` is 192 lines long, doing creation + configuration + registration + observation + persistence -- all in one method
5. **Private Nested Types for Persistence**: `PersistedWindowFrame` and `WindowFrameStore` are nested in the class but could be standalone
6. **Mixed Abstraction Levels**: Same class handles raw NSWindow frame math AND high-level "show video" commands
7. **Duplicate Patterns**: Playlist docking context and Video docking context follow identical patterns but are coded separately

---

## 2. Swift 6.2 / Modern Swift Patterns Research

### 2a. Replacing Recursive `withObservationTracking`

**Current Pattern (fragile, boilerplate-heavy):**
```swift
private func setupAlwaysOnTopObserver() {
    alwaysOnTopTask?.cancel()
    alwaysOnTopTask = Task { @MainActor [weak self] in
        guard let self else { return }
        withObservationTracking {
            _ = self.settings.isAlwaysOnTop
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateWindowLevels(self.settings.isAlwaysOnTop)
                self.setupAlwaysOnTopObserver()  // Recursive re-register
            }
        }
    }
}
```

**Swift 6.2 Replacement -- `Observations` AsyncSequence:**
```swift
// Available in macOS 26+ / Swift 6.2
private func observeAlwaysOnTop() {
    alwaysOnTopTask?.cancel()
    alwaysOnTopTask = Task { @MainActor [weak self] in
        guard let self else { return }
        for await alwaysOnTop in Observations(of: settings, \.isAlwaysOnTop) {
            self.updateWindowLevels(alwaysOnTop)
        }
    }
}
```

**Backward-Compatible Alternative (macOS 15+) -- `withContinuousObservationTracking` (SE-0506):**
```swift
// If SE-0506 lands in Swift 6.x toolchain for macOS 15:
private var alwaysOnTopToken: ObservationTracking.Token?

private func observeAlwaysOnTop() {
    alwaysOnTopToken = withContinuousObservationTracking {
        settings.isAlwaysOnTop
    } onChange: { [weak self] in
        guard let self else { return }
        Task { @MainActor in
            self.updateWindowLevels(self.settings.isAlwaysOnTop)
        }
    }
}
```

**Recommendation:** Since MacAmp targets macOS 15+ (Sequoia) as primary and macOS 26+ (Tahoe) as future, keep the current recursive pattern for now but extract it into a reusable utility. When the macOS 26 minimum is adopted, migrate to `Observations` AsyncSequence.

### 2b. `@Observable` and Composition

Key insight: `@Observable` works with **composition** -- you can have an `@Observable` parent that holds references to `@Observable` children, and SwiftUI will track property access through the chain.

```swift
@Observable final class WindowCoordinator {
    let visibility: WindowVisibilityController  // @Observable child
    let persistence: WindowPersistenceController
    // ...
}

// In SwiftUI view:
let coordinator = WindowCoordinator.shared
if coordinator.visibility.isEQVisible { ... }  // Tracked correctly
```

However, `@Observable` does NOT support protocol conformance for observation. A protocol cannot guarantee that its conforming types use the `@Observable` macro. This means:
- Protocol-based abstractions work for method calls (testability)
- But SwiftUI views must use concrete `@Observable` types for reactive binding
- Solution: Use protocols for method contracts, concrete types for state

### 2c. Extension-Based File Splitting vs. True Type Decomposition

**Extension-Based (cosmetic split):**
- Pros: Zero refactoring risk, no API changes, immediate linting fix
- Cons: Does not reduce complexity, all state still in one type, untestable in isolation
- Pattern: `WindowCoordinator+Visibility.swift`, `WindowCoordinator+Persistence.swift`

**True Type Decomposition (structural split):**
- Pros: Each type has single responsibility, independently testable, clear ownership
- Cons: Requires updating callers, more files to navigate, must handle inter-component communication
- Pattern: Separate `WindowVisibilityController`, `WindowFramePersistence`, `WindowDockingCalculator`

**Hybrid Approach (recommended):**
1. Extract pure logic into separate types (docking geometry, persistence, debug logging)
2. Keep the `WindowCoordinator` as a thin facade that composes extracted types
3. Use extensions for MARK-based organization of remaining coordinator glue
4. Callers continue to use `WindowCoordinator.shared` but access sub-controllers for specific operations

### 2d. Protocol-Oriented Decomposition

Define protocols for testability and API contracts, but implement with concrete `@Observable` types:

```swift
// Protocol for window visibility operations
protocol WindowVisibilityControlling: AnyObject, Sendable {
    var isEQWindowVisible: Bool { get }
    var isPlaylistWindowVisible: Bool { get }
    func showEQWindow()
    func hideEQWindow()
    func toggleEQWindowVisibility() -> Bool
    func showPlaylistWindow()
    func hidePlaylistWindow()
    func togglePlaylistWindowVisibility() -> Bool
    func showVideo()
    func hideVideo()
    func showMilkdrop()
    func hideMilkdrop()
    func showAllWindows()
}

// Protocol for window resize operations
protocol WindowResizeControlling: AnyObject, Sendable {
    func updatePlaylistWindowSize(to pixelSize: CGSize)
    func updateVideoWindowSize(to pixelSize: CGSize)
    func updateMilkdropWindowSize(to pixelSize: CGSize)
    func resizeMainAndEQWindows(doubled: Bool)
}
```

---

## 3. Decomposition Strategy

### 3a. Proposed Architecture: Facade + Focused Controllers

```
WindowCoordinator (facade, ~200 lines)
├── WindowRegistry              (window-to-kind mapping, NSWindow references)
├── WindowVisibilityController  (show/hide/toggle, observable state)
├── WindowFramePersistence      (save/restore via UserDefaults)
├── WindowDockingCalculator     (attachment geometry, snap detection)
├── WindowLevelController       (always-on-top management)
├── WindowResizeController      (double-size, playlist/video/milkdrop resize)
├── WindowDelegateWiring        (multiplexer setup, focus delegates, persistence delegates)
└── WindowSettingsObserver      (reactive observation of AppSettings changes)
```

### 3b. Component Breakdown

#### 1. `WindowRegistry` (~80 lines)
**Responsibility:** Maps NSWindow instances to WindowKind values, provides typed accessors.

```swift
@MainActor
final class WindowRegistry {
    private var windowKinds: [ObjectIdentifier: WindowKind] = [:]

    let mainController: NSWindowController
    let eqController: NSWindowController
    let playlistController: NSWindowController
    let videoController: NSWindowController
    let milkdropController: NSWindowController

    var mainWindow: NSWindow? { mainController.window }
    var eqWindow: NSWindow? { eqController.window }
    // ...

    func window(for kind: WindowKind) -> NSWindow? { ... }
    func kind(for window: NSWindow) -> WindowKind? { ... }
    func allWindows() -> [(WindowKind, NSWindow)] { ... }
    func forEachWindow(_ body: (WindowKind, NSWindow) -> Void) { ... }
}
```

**Why separate:** Window lookup is used by persistence, docking, visibility, and level management. Currently duplicated across methods.

#### 2. `WindowVisibilityController` (~120 lines)
**Responsibility:** Show/hide/toggle windows, track observable visibility state.

```swift
@MainActor
@Observable
final class WindowVisibilityController {
    var isEQWindowVisible: Bool = false
    var isPlaylistWindowVisible: Bool = false

    private let registry: WindowRegistry

    func showEQWindow() { ... }
    func hideEQWindow() { ... }
    func toggleEQWindowVisibility() -> Bool { ... }
    // ... all visibility methods
}
```

**Why separate:** Visibility is the most-used external API. Making it `@Observable` allows SwiftUI views to react to visibility changes directly.

#### 3. `WindowFramePersistence` (~150 lines)
**Responsibility:** Save/restore window frames to UserDefaults.

```swift
@MainActor
final class WindowFramePersistence {
    private let frameStore: WindowFrameStore
    private let registry: WindowRegistry
    private var suppressionCount = 0
    private var flushTask: Task<Void, Never>?

    func persistAllFrames() { ... }
    func applyPersistedPositions(settings: AppSettings) -> Bool { ... }
    func scheduleDebouncedFlush() { ... }
    func beginSuppression() { ... }
    func endSuppression() { ... }
    func performWithoutPersistence(_ work: () -> Void) { ... }
}
```

**Why separate:** Persistence logic is self-contained. The `WindowFrameStore` and `PersistedWindowFrame` structs naturally belong here. The suppression mechanism is an implementation detail of persistence.

#### 4. `WindowDockingCalculator` (~200 lines, pure logic)
**Responsibility:** Compute docking attachment geometry, determine which windows are attached.

```swift
@MainActor
struct WindowDockingCalculator {
    // Pure geometry functions (no NSWindow references -- takes NSRect inputs)

    static func makePlaylistDockingContext(
        mainFrame: NSRect, eqFrame: NSRect, playlistFrame: NSRect?,
        snapManager: WindowSnapManager, lastAttachment: PlaylistAttachmentSnapshot?
    ) -> (PlaylistDockingContext, PlaylistAttachmentSnapshot?)? { ... }

    static func makeVideoDockingContext(
        mainFrame: NSRect, eqFrame: NSRect, playlistFrame: NSRect?, videoFrame: NSRect?,
        snapManager: WindowSnapManager
    ) -> VideoAttachmentSnapshot? { ... }

    static func determineAttachment(
        anchorFrame: NSRect, targetFrame: NSRect, strict: Bool
    ) -> PlaylistDockingContext.Attachment? { ... }

    static func playlistOrigin(
        for attachment: PlaylistDockingContext.Attachment,
        anchorFrame: NSRect, playlistSize: NSSize
    ) -> NSPoint { ... }
}
```

**Why separate:** This is pure geometry math with no side effects. It is the most testable component. Currently interleaved with NSWindow mutation, making it impossible to unit test.

#### 5. `WindowLevelController` (~30 lines)
**Responsibility:** Set window levels (normal vs floating) for all windows.

Small enough to be an extension on WindowCoordinator, or a simple function. Could merge with WindowVisibilityController.

#### 6. `WindowResizeController` (~150 lines)
**Responsibility:** Handle double-size resize, per-window resize, docking-aware resize.

```swift
@MainActor
final class WindowResizeController {
    private let registry: WindowRegistry
    private let persistence: WindowFramePersistence
    private let dockingCalculator: WindowDockingCalculator

    func resizeMainAndEQ(doubled: Bool, animated: Bool, persistResult: Bool) { ... }
    func updatePlaylistWindowSize(to: CGSize) { ... }
    func updateVideoWindowSize(to: CGSize) { ... }
    func updateMilkdropWindowSize(to: CGSize) { ... }
}
```

**Why separate:** Resize logic depends on docking calculations and persistence suppression. By composing DockingCalculator and Persistence, this becomes a clean orchestrator.

#### 7. `WindowSettingsObserver` (~100 lines)
**Responsibility:** Watch AppSettings changes and dispatch to appropriate controllers.

```swift
@MainActor
final class WindowSettingsObserver {
    private let settings: AppSettings
    private var tasks: [Task<Void, Never>] = []

    func startObserving(
        onAlwaysOnTopChanged: @escaping (Bool) -> Void,
        onDoubleSizeChanged: @escaping (Bool) -> Void,
        onVideoVisibilityChanged: @escaping (Bool) -> Void,
        onMilkdropVisibilityChanged: @escaping (Bool) -> Void
    ) { ... }

    func stopObserving() { ... }
}
```

**Why separate:** Observation is pure plumbing. The 4 observer methods are identical in structure (recursive withObservationTracking). Extracting them:
- Eliminates 4x boilerplate by using a generic observation helper
- Makes future migration to `Observations` AsyncSequence trivial (change one function)
- Decouples "what changed" from "what to do about it"

#### 8. `WindowDelegateWiring` (~80 lines)
**Responsibility:** Set up delegate multiplexers, register delegates for persistence/focus/snapping.

This is init-time wiring that runs once. Could be a static factory method or a separate setup function.

### 3c. The Slim Facade

After extraction, `WindowCoordinator` becomes:

```swift
@MainActor
@Observable
final class WindowCoordinator {
    static var shared: WindowCoordinator!

    let registry: WindowRegistry
    let visibility: WindowVisibilityController
    let persistence: WindowFramePersistence
    let resize: WindowResizeController

    // Thin forwarding for backward compatibility:
    var isEQWindowVisible: Bool { visibility.isEQWindowVisible }
    var isPlaylistWindowVisible: Bool { visibility.isPlaylistWindowVisible }
    var mainWindow: NSWindow? { registry.mainWindow }
    // ... etc

    func minimizeKeyWindow() { NSApp.keyWindow?.miniaturize(nil) }
    // ... thin forwards

    init(skinManager: SkinManager, ...) {
        // Create sub-controllers
        registry = WindowRegistry(...)
        visibility = WindowVisibilityController(registry: registry)
        persistence = WindowFramePersistence(registry: registry)
        resize = WindowResizeController(registry: registry, persistence: persistence)

        // Wire delegates
        WindowDelegateWiring.setup(registry: registry, persistence: persistence, ...)

        // Start observers
        settingsObserver.startObserving(
            onAlwaysOnTopChanged: { [weak self] in ... },
            ...
        )

        // Apply layout
        applyInitialWindowLayout()
        presentWindowsWhenReady()
    }
}
```

Target: ~200-250 lines for the facade.

---

## 4. How Other macOS Apps Handle Multi-Window Coordination

### Patterns from the Ecosystem

1. **Apple's Cocoa Design Patterns (NSWindowController per window):**
   - Each NSWindowController manages its own window lifecycle
   - A coordinating object (AppDelegate or custom coordinator) manages cross-window concerns
   - This is what MacAmp already does with `WinampMainWindowController`, etc.

2. **Swindler (tmandry/Swindler):**
   - Uses a `WindowManager` that holds a `WindowObserver` + `WindowStore` (registry)
   - Separates "what windows exist" (store) from "what happened" (observer) from "what to do" (manager)

3. **Rectangle / Spectacle (window managers):**
   - Separate `WindowCalculator` for geometry (pure functions)
   - `WindowManager` for NSWindow manipulation
   - `AccessibilityWrapper` for AX API calls
   - Shows that geometry calculation is always a good extraction target

4. **SwiftUI WindowGroup approach (modern):**
   - Each window scene manages its own lifecycle
   - Cross-window coordination via shared `@Observable` state in the environment
   - MacAmp cannot fully use this pattern because of the custom borderless NSWindow requirements

### Key Takeaway
The universal pattern across successful macOS window management code is:
- **Registry** (what windows exist) is separate from **Logic** (what to do with them)
- **Geometry** (pure math) is separate from **Mutation** (NSWindow.setFrame)
- **Observation** (detecting changes) is separate from **Reaction** (handling changes)

---

## 5. Migration Strategy: Minimal Breaking Changes

### Phase 1: Extract Pure Logic (Zero API Changes)
1. Extract `WindowDockingCalculator` as a struct with static methods
2. Extract `WindowFrameStore` + `PersistedWindowFrame` to their own file
3. Move `PlaylistDockingContext`, `PlaylistAttachmentSnapshot`, `VideoAttachmentSnapshot` to their own file
4. WindowCoordinator calls the extracted types instead of inline logic

**Impact:** Internal refactor only. No callers change.

### Phase 2: Extract Controllers (Thin Forwarding)
1. Create `WindowRegistry` to hold window controllers + kind mapping
2. Create `WindowVisibilityController` with observable state
3. Create `WindowFramePersistence` with suppression logic
4. Create `WindowResizeController`
5. WindowCoordinator forwards to sub-controllers via computed properties

**Impact:** Callers still use `WindowCoordinator.shared.isEQWindowVisible`. The computed property forwards to `visibility.isEQWindowVisible`. Zero breaking changes.

### Phase 3: Extract Observation (Optional, Future)
1. Create `WindowSettingsObserver` with generic observation helper
2. Replace 4 recursive `withObservationTracking` calls with single utility
3. When macOS 26 minimum is adopted, swap to `Observations` AsyncSequence

**Impact:** Internal only.

### Phase 4: Modernize Singleton (Optional, Future)
1. Replace `static var shared: WindowCoordinator!` with proper dependency injection
2. Pass `WindowCoordinator` through SwiftUI environment
3. Remove force-unwrap singleton access from views

**Impact:** Requires updating all callers to use environment injection. Deferred to a separate task.

---

## 6. Testability Improvements

### Currently Untestable
- Docking geometry (intertwined with NSWindow state)
- Persistence (coupled to UserDefaults with no injection point)
- Observation (recursive Task-based, no way to verify)

### After Decomposition
| Component | Testability |
|-----------|------------|
| `WindowDockingCalculator` | Pure functions, fully unit testable with mock NSRects |
| `WindowFrameStore` | Injectable UserDefaults, can test with in-memory defaults |
| `WindowFramePersistence` | Mock WindowRegistry + WindowFrameStore |
| `WindowVisibilityController` | Mock WindowRegistry, verify state changes |
| `WindowSettingsObserver` | Mock AppSettings, verify callback invocations |
| `WindowResizeController` | Mock registry + persistence, verify frame calculations |

---

## 7. File Organization Proposal

```
MacAmpApp/
├── ViewModels/
│   ├── WindowCoordinator.swift            (~200 lines, facade)
│   ├── WindowCoordinator+Layout.swift     (initial layout + default positions, extension)
│   ├── DockingController.swift            (existing, unchanged)
│   └── ...
├── Windows/
│   ├── WindowRegistry.swift               (~80 lines)
│   ├── WindowVisibilityController.swift   (~120 lines)
│   ├── WindowFramePersistence.swift       (~150 lines, includes WindowFrameStore)
│   ├── WindowDockingCalculator.swift      (~200 lines, pure geometry)
│   ├── WindowResizeController.swift       (~150 lines)
│   ├── WindowSettingsObserver.swift       (~100 lines)
│   ├── WindowDelegateWiring.swift         (~80 lines)
│   ├── WindowDockingTypes.swift           (~55 lines, PlaylistDockingContext, snapshots)
│   ├── BorderlessWindow.swift             (existing)
│   ├── WinampMainWindowController.swift   (existing)
│   ├── WinampEqualizerWindowController.swift (existing)
│   ├── WinampPlaylistWindowController.swift  (existing)
│   ├── WinampVideoWindowController.swift     (existing)
│   └── WinampMilkdropWindowController.swift  (existing)
└── Utilities/
    ├── WindowDelegateMultiplexer.swift    (existing, unchanged)
    ├── WindowFocusDelegate.swift          (existing, unchanged)
    └── WindowSnapManager.swift            (existing, unchanged)
```

---

## 8. Recommendations Summary

### Approach: Hybrid Decomposition (True Types + Extensions)

| Priority | Action | Risk | Reward |
|----------|--------|------|--------|
| **P0** | Extract `WindowDockingCalculator` (pure geometry) | Minimal | High testability, ~200 lines removed |
| **P0** | Extract `WindowDockingTypes` (context structs) | None | ~55 lines removed, cleaner imports |
| **P1** | Extract `WindowFramePersistence` + `WindowFrameStore` | Low | ~150 lines removed, testable persistence |
| **P1** | Extract `WindowRegistry` | Low | ~80 lines removed, eliminates duplication |
| **P2** | Extract `WindowVisibilityController` | Medium | ~120 lines removed, clean observable state |
| **P2** | Extract `WindowResizeController` | Medium | ~150 lines removed |
| **P3** | Extract `WindowSettingsObserver` | Low | ~100 lines removed, prepares for Swift 6.2 |
| **P3** | Extract `WindowDelegateWiring` | Low | ~80 lines removed from init |
| **P4** | Modernize singleton to DI | High | Better testability, no force-unwrap |

### Do NOT:
- Split into extensions only (cosmetic, does not address complexity)
- Introduce protocols prematurely (protocol overhead without clear testing need)
- Change the public API surface in Phase 1 or Phase 2 (backward compatibility)
- Use `Observations` AsyncSequence yet (requires macOS 26 minimum)

### Do:
- Start with extracting pure logic (zero risk)
- Use composition within `@Observable` (child objects in observed parent)
- Keep the facade pattern so callers do not change
- Add unit tests for extracted components (especially docking geometry)
- Document extracted types in `docs/MULTI_WINDOW_ARCHITECTURE.md`

---

## 9. Swift 6.2+ Concurrency Audit (via swift-concurrency-expert skill)

### Project Settings
- **Swift Version:** 6.0 (project.pbxproj)
- **Strict Concurrency:** `complete` (all configurations)
- **Approachable Concurrency:** Not yet enabled (Swift 6.2 opt-in)

### Finding 1: Recursive `withObservationTracking` Pattern (4 instances)

**Lines:** 302-322, 335-354, 357-384, 386-416

**Issue:** The recursive pattern creates a new `Task` for each observation cycle. Each nested `Task { @MainActor [weak self] in ... }` inside the `onChange` closure creates a new isolated task that inherits main actor context. This is correct but verbose.

**Swift 6.2 Impact:**
- With approachable concurrency enabled, `Task { }` inherits caller isolation, so `@MainActor` annotation on the nested task becomes redundant (but harmless)
- The `[weak self]` captures are correct and must be preserved to avoid retain cycles
- When macOS 26 minimum is adopted, replace with `Observations` AsyncSequence (eliminates recursion entirely)

**Recommendation:** Extract into a generic helper function during Phase 3. The helper eliminates 4x boilerplate while preserving the exact same semantics:
```swift
func observeProperty<T>(
    on settings: AppSettings,
    read: @escaping (AppSettings) -> T,
    onChange: @escaping @MainActor (T) -> Void
) -> Task<Void, Never>
```

### Finding 2: Task Usage with Weak Self Captures

**Pattern:** `Task { @MainActor [weak self] in ... }`

**Assessment:** Correct. All Task closures use `[weak self]` and `guard let self else { return }`. The `@MainActor` attribute on the Task closure explicitly inherits main actor isolation. With Swift 6.2 approachable concurrency, the `@MainActor` would be inferred (since the enclosing type is `@MainActor`), but keeping it explicit is clearer.

**One concern:** The `skinPresentationTask` (lines 955-965) uses a polling loop:
```swift
while !self.canPresentImmediately {
    if Task.isCancelled { return }
    try? await Task.sleep(for: .milliseconds(50))
}
```
This is a busy-wait that blocks the task (not the main actor, but a task slot). Consider replacing with observation-based waiting in the future.

### Finding 3: @MainActor and @Observable Interaction

**Assessment:** Correct. `WindowCoordinator` is `@MainActor @Observable final class`, which means:
- All stored properties are main-actor isolated
- All methods are main-actor isolated
- `@Observable` macro generates `_$observationRegistrar` that is thread-safe
- `@ObservationIgnored` on Task properties is correct (Tasks don't need observation tracking)

**Swift 6.2 Note:** When approachable concurrency is enabled, `@MainActor` on the class would be inferred for the module. The explicit annotation is still recommended for clarity in a large codebase.

### Finding 4: Deinit Cancellation Pattern

**Lines:** 324-332
```swift
deinit {
    skinPresentationTask?.cancel()
    alwaysOnTopTask?.cancel()
    doubleSizeTask?.cancel()
    persistenceTask?.cancel()
    videoWindowTask?.cancel()
    milkdropWindowTask?.cancel()
    videoSizeTask?.cancel()
}
```

**Issue:** In Swift 6, `deinit` is `nonisolated` by design. However, the properties being accessed (`skinPresentationTask`, etc.) are `@MainActor`-isolated because the class is `@MainActor`. Accessing main-actor-isolated properties from a nonisolated deinit is technically a concurrency violation.

**Why it works today:** With `@ObservationIgnored`, these Task properties opt out of observation tracking, and since `Task.cancel()` is thread-safe (Tasks are Sendable), this is practically safe even if technically violating isolation.

**Swift 6.2 Fix:** When strict concurrency catches this, either:
1. Mark the task properties as `nonisolated(unsafe)` (acknowledges the safety)
2. Use `nonisolated(unsafe) private var tasks: [Task<Void, Never>?]` to group them
3. Move cancellation into an explicit `tearDown()` method called before deallocation

**Recommendation:** During Phase 3 extraction of `WindowSettingsObserver`, move task ownership to that type. Its `deinit` handles cancellation, keeping WindowCoordinator's deinit clean.

### Finding 5: Static Singleton

**Line 57:** `static var shared: WindowCoordinator!`

**Swift 6.2 Impact:** With approachable concurrency, `static var` on a `@MainActor` class is implicitly main-actor-isolated. The force-unwrap is not a concurrency issue but is a fragility concern.

**Recommendation:** Deferred to Phase 4 (DI migration). For now, the singleton is concurrency-safe due to `@MainActor` isolation.

### Summary: Concurrency Compliance Rating

| Aspect | Status | Notes |
|--------|--------|-------|
| `@MainActor` isolation | Pass | Correct on class and all methods |
| `@Observable` usage | Pass | Proper with `@ObservationIgnored` on tasks |
| Task weak self captures | Pass | All closures use `[weak self]` correctly |
| Observation pattern | Functional but Verbose | Extract to helper; migrate to Observations later |
| Deinit isolation | Technically Violating | Safe in practice; fix with nonisolated(unsafe) or extraction |
| Sendable boundaries | Pass | No cross-isolation sends detected |
| Overall | Good | Minor improvements during refactoring |

---

## 10. Sources

### Swift Observation & Concurrency
- [SE-0506: Advanced Observation Tracking](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0506-advanced-observation-tracking.md)
- [Streaming changes with Observations | Swift with Majid](https://swiftwithmajid.com/2025/07/30/streaming-changes-with-observations/)
- [Swift Observations AsyncSequence for State Changes | Use Your Loaf](https://useyourloaf.com/blog/swift-observations-asyncsequence-for-state-changes/)
- [Using Observations to observe @Observable model properties | Donny Wals](https://www.donnywals.com/using-observations-to-observe-observable-model-properties/)
- [@Observable Macro performance increase over ObservableObject | SwiftLee](https://www.avanderlee.com/swiftui/observable-macro-performance-increase-observableobject/)
- [Migrating from Observable Object protocol to Observable macro | Apple](https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro)
- [SwiftUI's Observable macro is not a drop-in replacement | Jesse Squires](https://www.jessesquires.com/blog/2024/09/09/swift-observable-macro/)
- [Protocols with Swift 6: A Powerful Approach for SwiftUI MVVM | Medium](https://anushka-samarasinghe.medium.com/protocols-with-swift-6-a-powerful-approach-for-swiftui-mvvm-86948a9e921a)

### Extension-Based Splitting vs. True Decomposition
- [Splitting swift files into multiple files without extensions | Swift Forums](https://forums.swift.org/t/splitting-swift-files-into-multiple-files-without-the-use-of-extensions/34546)
- [Official ruling on organizing code by splitting large files into Extensions | Swift Forums](https://forums.swift.org/t/what-is-the-official-ruling-on-organizing-code-by-splitting-large-files-into-extensions/12337)
- [Divide Class into Class + Extension (Swift Refactoring) | XP123](https://xp123.com/articles/divide-class-into-class-plus-extension/)
- [Structuring Swift code | Swift by Sundell](https://www.swiftbysundell.com/articles/structuring-swift-code/)
- [Calling private methods from extensions in separate files | Swift Forums](https://forums.swift.org/t/calling-private-methods-from-extensions-in-separate-files/54029)

### macOS Window Management
- [Window Management with SwiftUI 4 | fline.dev](https://www.fline.dev/window-management-on-macos-with-swiftui-4/)
- [NSWindowController | Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nswindowcontroller)
- [Swindler: macOS window management library for Swift](https://github.com/tmandry/Swindler)
- [How to Build macOS Applications with SwiftUI](https://oneuptime.com/blog/post/2026-02-02-swiftui-macos-applications/view)
