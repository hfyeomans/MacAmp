# Plan: WindowCoordinator.swift Refactoring

> **Task:** Decompose the 1,357-line WindowCoordinator god object into focused, maintainable types
> **Strategy:** Facade + Composition with phased migration
> **Goal:** Reduce WindowCoordinator.swift to ~200 lines while preserving the public API surface

---

## Guiding Principles

1. **Zero Breaking Changes**: All callers continue using `WindowCoordinator.shared.method()` unchanged
2. **Extract, Don't Rewrite**: Move existing code into new types; minimize logic changes
3. **Pure Logic First**: Start with the safest extractions (pure geometry, data types)
4. **Build After Each Phase**: Verify build + sanitizer pass before proceeding
5. **10x Engineer Practices**: Single responsibility, composition over inheritance, testability

---

## Phase 1: Extract Pure Types (Zero Risk)

### 1A. Extract `WindowDockingTypes.swift` (~55 lines)

**Move** these private types to a new file in `MacAmpApp/Windows/`:
- `PlaylistAttachmentSnapshot` struct (lines 4-7)
- `VideoAttachmentSnapshot` struct (lines 10-13)
- `PlaylistDockingContext` struct + enums (lines 15-52)

**Change access**: `private` -> `internal` (needed by WindowCoordinator and WindowDockingCalculator)

**Files Changed:**
- NEW: `MacAmpApp/Windows/WindowDockingTypes.swift`
- EDIT: `MacAmpApp/ViewModels/WindowCoordinator.swift` (remove moved types)

### 1B. Extract `WindowDockingCalculator.swift` (~200 lines)

**Move** these methods from WindowCoordinator to a new `@MainActor struct`:
- `makePlaylistDockingContext(mainFrame:eqFrame:playlistFrame:)` (lines 503-547)
- `makeVideoDockingContext(mainFrame:eqFrame:playlistFrame:videoFrame:)` (lines 649-677)
- `determineAttachment(anchorFrame:playlistFrame:strict:)` (lines 549-593)
- `playlistOrigin(for:anchorFrame:playlistSize:)` (lines 595-606)
- `attachmentStillEligible(_:anchorFrame:playlistFrame:)` (lines 608-620)
- `anchorFrame(_:mainFrame:eqFrame:playlistFrame:)` (lines 622-633)
- `liveAnchorFrame(_:)` -> takes WindowRegistry as parameter

**Key design**: Static methods that take NSRect inputs (pure geometry). The `liveAnchorFrame` method requires window references, so it either stays in WindowCoordinator or takes a registry.

**Files Changed:**
- NEW: `MacAmpApp/Windows/WindowDockingCalculator.swift`
- EDIT: `MacAmpApp/ViewModels/WindowCoordinator.swift` (call extracted methods)

### 1C. Extract `WindowFrameStore.swift` (~70 lines)

**Move** these nested types to a new file:
- `PersistedWindowFrame` struct (lines 1280-1302)
- `WindowFrameStore` struct (lines 1304-1327)
- `WindowKind.persistenceKey` extension (lines 1347-1357)

**Files Changed:**
- NEW: `MacAmpApp/Windows/WindowFrameStore.swift`
- EDIT: `MacAmpApp/ViewModels/WindowCoordinator.swift` (remove nested types)

### Phase 1 Verification
```bash
xcodebuild -scheme MacAmp -configuration Debug -enableThreadSanitizer YES build
```
Expected: Build passes, zero behavior change, ~325 lines removed from WindowCoordinator.

---

## Phase 2: Extract Controllers (Low-Medium Risk)

### 2A. Extract `WindowRegistry.swift` (~80 lines)

**Create** a new class that owns:
- All 5 NSWindowController references (moved from WindowCoordinator properties)
- `windowKinds: [ObjectIdentifier: WindowKind]` mapping
- Computed properties: `mainWindow`, `eqWindow`, `playlistWindow`, `videoWindow`, `milkdropWindow`
- `mapWindowsToKinds()` method (lines 1176-1194)
- `windowKind(for:)` method (lines 1196-1198)
- Helper: `window(for kind:) -> NSWindow?`
- Helper: `forEachWindow(_ body:)` for iterating all windows

**WindowCoordinator changes**:
- Replace 5 controller properties + 5 window computed properties with single `let registry: WindowRegistry`
- Forward `mainWindow`, `eqWindow`, etc. via computed properties on facade

**Files Changed:**
- NEW: `MacAmpApp/Windows/WindowRegistry.swift`
- EDIT: `MacAmpApp/ViewModels/WindowCoordinator.swift`

### 2B. Extract `WindowFramePersistence.swift` (~150 lines)

**Create** a new class that owns:
- `WindowFrameStore` instance
- `persistenceSuppressionCount` (lines 78, 1200-1212)
- `WindowPersistenceDelegate` class (lines 1329-1344)
- `persistAllWindowFrames()` (lines 1140-1157)
- `schedulePersistenceFlush()` (lines 1159-1167)
- `handleWindowGeometryChange(notification:)` (lines 1169-1174)
- `applyPersistedWindowPositions()` (lines 1073-1138)
- `beginSuppressingPersistence()` / `endSuppressingPersistence()` / `performWithoutPersistence()` (lines 1200-1212)

**Dependencies**: Takes `WindowRegistry` as init parameter.

**Files Changed:**
- NEW: `MacAmpApp/Windows/WindowFramePersistence.swift`
- EDIT: `MacAmpApp/ViewModels/WindowCoordinator.swift`

### 2C. Extract `WindowVisibilityController.swift` (~120 lines)

**Create** a new `@Observable` class that owns:
- `isEQWindowVisible: Bool` (line 810)
- `isPlaylistWindowVisible: Bool` (line 813)
- All show/hide/toggle methods for EQ, Playlist, Video, Milkdrop, Main (lines 748-1278)
- `showAllWindows()` (lines 1214-1232)
- `focusAllWindows()` (lines 1272-1278)
- `minimizeKeyWindow()` / `closeKeyWindow()` (lines 748-755)

**WindowCoordinator changes**:
- Forward `isEQWindowVisible`, `isPlaylistWindowVisible` via computed properties
- Forward all show/hide methods

**Files Changed:**
- NEW: `MacAmpApp/Windows/WindowVisibilityController.swift`
- EDIT: `MacAmpApp/ViewModels/WindowCoordinator.swift`

### 2D. Extract `WindowResizeController.swift` (~150 lines)

**Create** a new class that owns:
- `resizeMainAndEQWindows(doubled:animated:persistResult:)` (lines 423-501)
- `updatePlaylistWindowSize(to:)` (lines 851-868)
- `updateVideoWindowSize(to:)` (lines 692-713)
- `updateMilkdropWindowSize(to:)` (lines 718-742)
- Resize preview methods (lines 826-848)
- `movePlaylist(using:targetFrame:playlistSize:animated:)` (lines 870-881)
- `moveVideoWindow(using:targetFrame:videoSize:animated:)` (lines 679-690)
- Debug logging methods: `logDoubleSizeDebug()`, `logDockingStage()` (lines 883-910)

**Dependencies**: Takes `WindowRegistry`, `WindowFramePersistence`, uses `WindowDockingCalculator`.

**Files Changed:**
- NEW: `MacAmpApp/Windows/WindowResizeController.swift`
- EDIT: `MacAmpApp/ViewModels/WindowCoordinator.swift`

### Phase 2 Verification
```bash
xcodebuild -scheme MacAmp -configuration Debug -enableThreadSanitizer YES build
```
Expected: Build passes, WindowCoordinator reduced to ~250 lines.

---

## Phase 3: Extract Observation & Wiring (Low Risk)

### 3A. Extract `WindowSettingsObserver.swift` (~100 lines)

**Create** a new class that owns:
- All 4 observation tasks (lines 70-76): `alwaysOnTopTask`, `doubleSizeTask`, `videoWindowTask`, `milkdropWindowTask`
- All 4 `setup*Observer()` methods (lines 302-416)
- Generic observation helper to eliminate boilerplate:

```swift
@MainActor
final class WindowSettingsObserver {
    private var tasks: [String: Task<Void, Never>] = [:]

    func observe<T>(
        _ keyPath: String,
        on settings: AppSettings,
        read: @escaping () -> T,
        onChange: @escaping (T) -> Void
    ) { ... }

    func stopAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    deinit { stopAll() }
}
```

**Files Changed:**
- NEW: `MacAmpApp/Windows/WindowSettingsObserver.swift`
- EDIT: `MacAmpApp/ViewModels/WindowCoordinator.swift`

### 3B. Extract `WindowDelegateWiring.swift` (~80 lines)

**Create** a static setup function or class that handles:
- All 5 `WindowDelegateMultiplexer` creation + delegate registration (lines 240-299)
- All 5 `WindowFocusDelegate` creation (lines 276-297)
- `WindowPersistenceDelegate` registration
- `WindowSnapManager` registration

**Pattern**: Static factory that returns a struct holding all multiplexer/delegate references:

```swift
struct WindowDelegateWiring {
    let multiplexers: [WindowKind: WindowDelegateMultiplexer]
    let focusDelegates: [WindowKind: WindowFocusDelegate]
    let persistenceDelegate: WindowPersistenceDelegate

    static func setup(
        registry: WindowRegistry,
        persistence: WindowFramePersistence,
        focusState: WindowFocusState
    ) -> WindowDelegateWiring { ... }
}
```

**Files Changed:**
- NEW: `MacAmpApp/Windows/WindowDelegateWiring.swift`
- EDIT: `MacAmpApp/ViewModels/WindowCoordinator.swift`

### Phase 3 Verification
```bash
xcodebuild -scheme MacAmp -configuration Debug -enableThreadSanitizer YES build
```
Expected: Build passes, WindowCoordinator reduced to ~200 lines.

---

## Phase 4: Layout Extension (Cosmetic)

### 4A. Create `WindowCoordinator+Layout.swift` (~100 lines)

**Move** init-time layout methods as extension:
- `setDefaultPositions()` (lines 983-1024)
- `resetToDefaultStack()` (lines 1028-1065)
- `applyInitialWindowLayout()` (lines 1067-1071)
- `configureWindows()` (lines 975-981)
- `presentWindowsWhenReady()` / `presentInitialWindows()` (lines 948-973)
- `debugLogWindowPositions()` (lines 912-927)
- `LayoutDefaults` enum (lines 96-100)

These methods need access to WindowCoordinator internals, so they stay as an extension with `internal` access.

**Files Changed:**
- NEW: `MacAmpApp/ViewModels/WindowCoordinator+Layout.swift`
- EDIT: `MacAmpApp/ViewModels/WindowCoordinator.swift`

### Phase 4 Verification
```bash
xcodebuild -scheme MacAmp -configuration Debug -enableThreadSanitizer YES build
```
Expected: WindowCoordinator.swift is ~200 lines (facade + properties + init orchestration).

---

## Final Architecture

```
WindowCoordinator.swift (~200 lines, facade)
├── Composes: WindowRegistry, WindowVisibilityController,
│             WindowFramePersistence, WindowResizeController,
│             WindowSettingsObserver, WindowDelegateWiring
├── Forwards: All public API via computed properties / thin methods
└── Owns: Init orchestration, skin presentation wait, layout application

WindowCoordinator+Layout.swift (~100 lines, extension)
├── setDefaultPositions(), resetToDefaultStack()
├── applyInitialWindowLayout(), configureWindows()
├── presentWindowsWhenReady(), presentInitialWindows()
└── debugLogWindowPositions(), LayoutDefaults

WindowDockingTypes.swift (~55 lines)
├── PlaylistDockingContext, PlaylistAttachmentSnapshot
└── VideoAttachmentSnapshot

WindowDockingCalculator.swift (~200 lines)
├── makePlaylistDockingContext(), makeVideoDockingContext()
├── determineAttachment(), playlistOrigin()
└── attachmentStillEligible(), anchorFrame()

WindowFrameStore.swift (~70 lines)
├── PersistedWindowFrame (Codable)
├── WindowFrameStore (UserDefaults wrapper)
└── WindowKind.persistenceKey extension

WindowRegistry.swift (~80 lines)
├── NSWindowController references (5)
├── WindowKind mapping
└── window(for:), kind(for:), forEachWindow()

WindowVisibilityController.swift (~120 lines)
├── isEQWindowVisible, isPlaylistWindowVisible (@Observable)
├── show/hide/toggle for all windows
└── showAllWindows(), focusAllWindows()

WindowFramePersistence.swift (~150 lines)
├── WindowPersistenceDelegate (NSWindowDelegate)
├── Suppression logic
├── persistAllFrames(), applyPersistedPositions()
└── scheduleDebouncedFlush()

WindowResizeController.swift (~150 lines)
├── resizeMainAndEQWindows(doubled:)
├── updatePlaylistWindowSize(), updateVideoWindowSize(), updateMilkdropWindowSize()
├── Resize preview overlay bridging
└── movePlaylist(), moveVideoWindow()

WindowSettingsObserver.swift (~100 lines)
├── Generic observation helper (withObservationTracking)
├── 4 observed settings: alwaysOnTop, doubleSize, showVideo, showMilkdrop
└── Future: Migrate to Observations AsyncSequence (macOS 26)

WindowDelegateWiring.swift (~80 lines)
├── Multiplexer creation for all 5 windows
├── WindowSnapManager registration
├── WindowFocusDelegate registration
└── WindowPersistenceDelegate registration
```

**Total: ~1,305 lines across 11 files vs. 1,357 lines in 1 file**
**WindowCoordinator.swift: 1,357 -> ~200 lines (-85%)**

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Breaking callers | All public API forwarded via computed properties / thin methods |
| @Observable breaks | Verify SwiftUI reactivity after each phase (EQ/Playlist button states) |
| Docking regression | Manual test: drag windows into cluster, press Ctrl+D, verify playlist stays attached |
| Persistence regression | Test: move windows, restart app, verify positions restored |
| Thread sanitizer | Build with `-enableThreadSanitizer YES` after each phase |
| Access control issues | Extracted types need `internal` access; private helpers may need `package` or forwarding |

---

## Oracle Review (gpt-5.3-codex, reasoningEffort: xhigh)

### Verdicts
- **Phase 1:** REVISE - Only extract truly pure geometry; move stateful docking context logic (snapshot memory + snap-manager querying) to Phase 2
- **Phase 2:** REVISE - Tighten ownership/lifecycle rules; add dependency constraints
- **Phase 3:** REVISE - Redesign deinit strategy; use explicit `start()`/`stop()` lifecycle instead of deinit cancellation
- **Phase 4:** APPROVE

### Critical Revisions Required

**1. Phase 1 Purity Boundary (High Priority)**
`WindowDockingCalculator` was planned as pure static methods, but `makePlaylistDockingContext()` and `makeVideoDockingContext()` depend on:
- `lastPlaylistAttachment` / `lastVideoAttachment` (mutable state)
- `WindowSnapManager.shared.clusterKinds(containing:)` (global singleton query)

**Fix:** Split into two concerns:
- `WindowDockingGeometry` (pure, static) - `determineAttachment()`, `playlistOrigin()`, `attachmentStillEligible()`, `anchorFrame()`
- Keep `makePlaylistDockingContext()` and `makeVideoDockingContext()` in `WindowResizeController` (Phase 2) since they are stateful orchestration

**2. Deinit Isolation Fix (High Priority)**
Don't rely on `deinit` for task cancellation in `WindowSettingsObserver`.

**Fix:** Use explicit lifecycle:
```swift
@MainActor
final class WindowSettingsObserver {
    func start(...) { ... }
    func stop() { tasks.values.forEach { $0.cancel() }; tasks.removeAll() }
    // deinit is empty or assert-only
}
```
Coordinator calls `settingsObserver.stop()` in its own cleanup.

**3. Ownership Clarity (Medium Priority)**
`WindowPersistenceDelegate` must have ONE clear owner: `WindowFramePersistence`.
`WindowDelegateWiring` only attaches it to multiplexers, does not retain it.

**4. Dependency Matrix (Medium Priority)**

```
WindowCoordinator (facade/composition root)
    ├── WindowRegistry              (no dependencies on other extracted types)
    ├── WindowVisibilityController  (depends on: WindowRegistry)
    ├── WindowFramePersistence      (depends on: WindowRegistry, WindowFrameStore)
    ├── WindowResizeController      (depends on: WindowRegistry, WindowFramePersistence, WindowDockingGeometry)
    ├── WindowSettingsObserver      (depends on: AppSettings only)
    └── WindowDelegateWiring        (depends on: WindowRegistry, WindowFramePersistence, WindowFocusState)

NO controller-to-controller dependencies allowed.
All cross-cutting coordination goes through WindowCoordinator facade.
```

**5. Add Minimal Tests During Migration (Medium Priority)**
Instead of deferring all tests:
- Add docking geometry unit test in Phase 1 (pure functions, easy to test)
- Add WindowFrameStore roundtrip test in Phase 1 (Codable encode/decode)

**6. Mark Pure Value Types as Sendable**
`PlaylistDockingContext`, `PlaylistAttachmentSnapshot`, `VideoAttachmentSnapshot`, `PersistedWindowFrame` should be marked `Sendable` for Swift 6.2 forward-compat.

**7. API Parity Checklist**
Before and after each phase, verify all public API surface is forwarded correctly by maintaining a checklist of:
- 7 observable properties
- 19+ public methods
- Ensure no API is accidentally dropped

### Oracle Recommendation
> **REVISE, then proceed.** The core direction is strong and architecturally aligned with MacAmp's Three-Layer Architecture. The Facade + Composition pattern is the right choice. Correct the purity boundary (Finding 1) and deinit lifecycle (Finding 2) before starting implementation.

---

## Out of Scope (Deferred)

1. **Singleton -> DI migration** (separate task)
2. **`Observations` AsyncSequence adoption** (requires macOS 26 minimum)
3. **Broad protocol abstractions** (add only at hard boundaries: WindowSnapManager, frame store)
4. **Full test suite** (follow-up task; but add 2 minimal tests during Phase 1)
