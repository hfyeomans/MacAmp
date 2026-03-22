# Deprecated Code & Patterns in WindowCoordinator.swift

> **Purpose:** Track deprecated patterns, legacy code, and code that should be removed rather than marked with inline comments. Per project conventions, we document deprecated/legacy code here instead of adding `// Deprecated` or `// Legacy` comments in source files.

## File: MacAmpApp/ViewModels/WindowCoordinator.swift (1,357 lines)

### Identified Deprecated/Legacy Patterns

| Pattern | Location | Description | Action |
|---------|----------|-------------|--------|
| Recursive `withObservationTracking` | Lines 302-416 | 4x identical boilerplate pattern for settings observation. Replaced in Swift 6.2 by `Observations` AsyncSequence (macOS 26+) and `withContinuousObservationTracking` (SE-0506). | Extract to `WindowSettingsObserver` with generic helper; migrate to `Observations` when macOS 26 is minimum target |
| Force-unwrapped singleton | Line 57 | `static var shared: WindowCoordinator!` is fragile, untestable, and crashes on nil access | Deferred to Phase 4: migrate to proper DI via SwiftUI environment |
| `// NEW:` inline comments | Lines 9-13, 62-76, 88-95, 105-106, 147-167, 195-196, 230-236, etc. | Leftover incremental development comments marking video/milkdrop additions. No longer "new" -- these are production features. | Remove all `// NEW:` comments during refactoring |
| `// CRITICAL FIX #3:` comments | Lines 189, 199 | Historical fix markers that no longer serve a purpose in production code | Remove during refactoring |
| `// NOTE:` removed code comments | Lines 218, 418-421 | Comments documenting removed functionality (setupVideoSizeObserver, resizeVideoWindow) | Remove -- per project conventions, removed code should not leave behind comments |
| Nested `WindowPersistenceDelegate` class | Lines 1329-1344 | Private class nested inside WindowCoordinator; should be a standalone type | Move to `WindowFramePersistence.swift` |
| Nested `PersistedWindowFrame` struct | Lines 1280-1302 | Private Codable struct nested inside WindowCoordinator | Move to `WindowFrameStore.swift` |
| Nested `WindowFrameStore` struct | Lines 1304-1327 | Private struct nested inside WindowCoordinator | Move to own file |
| Duplicate show/hide method pairs | Lines 757-807, 1235-1270 | Two sets of show/hide methods (e.g., `showEQWindow()` + `showEqualizer()`) that do the same thing with slight differences | Consolidate to single set during visibility extraction |

### Stale Comments to Remove

| Comment | Location | Reason |
|---------|----------|--------|
| `// NEW: Video window controller` | Line 62 | Not new, production feature |
| `// NEW: Milkdrop window controller` | Line 63 | Not new, production feature |
| `// NEW: Video window observer` | Line 74 | Not new, production feature |
| `// NEW: Milkdrop window observer` | Line 75 | Not new, production feature |
| `// NEW: Video window size observer` | Line 76 | Not new, production feature |
| `// NEW: Video attachment memory` | Line 88 | Not new, production feature |
| `// NEW: Video window multiplexer` | Line 94 | Not new, production feature |
| `// NEW: Milkdrop window multiplexer` | Line 95 | Not new, production feature |
| `// CRITICAL FIX #3:` | Lines 189, 199 | Historical fix marker |
| `// NOTE: setupVideoSizeObserver removed` | Lines 218, 418-421 | Documenting removed code |

---

## Post-Refactoring Update (2026-02-09)

### ✅ COMPLETED REMOVALS

All patterns listed above have been addressed during the 4-phase refactoring:

| Pattern | Resolution |
|---------|------------|
| Recursive `withObservationTracking` boilerplate | ✅ Extracted to `WindowSettingsObserver.swift` with 4 concrete methods |
| Force-unwrapped singleton | ⏸️ Deferred (Phase 4 skipped DI migration per Oracle recommendation) |
| `// NEW:` inline comments | ✅ All removed during Phase 1-3 extractions |
| `// CRITICAL FIX #3:` comments | ✅ Removed during Phase 2 |
| `// NOTE:` removed code comments | ✅ Removed during Phase 2 |
| Nested `WindowPersistenceDelegate` | ✅ Moved to `WindowFramePersistence.swift` as top-level class |
| Nested `PersistedWindowFrame` | ✅ Moved to `WindowFrameStore.swift` |
| Nested `WindowFrameStore` | ✅ Moved to `WindowFrameStore.swift` |
| Duplicate show/hide methods | ✅ Consolidated in `WindowVisibilityController.swift` |

### New Deprecated Patterns (Replaced by Refactoring)

| Old Pattern | Deprecated | Replacement |
|-------------|------------|-------------|
| **Direct Task property management** | Lines 14-18 (old) | Use dedicated observer types with lifecycle (e.g., `WindowSettingsObserver`) |
| **Inline delegate multiplexer setup** | Lines 433-489 (old) | Use static factory pattern (`WindowDelegateWiring.wire()`) |
| **Inline focus delegate properties** | Lines 19-23 (old) | Collect in struct returned by factory (`WindowDelegateWiring.focusDelegates`) |
| **Persistence forwarding wrappers** | Lines 367-394 (old) | Direct access to composed controller (`framePersistence.method()`) |
| **Layout code in main class** | Lines 206-358 (old) | Extract to extension file (`WindowCoordinator+Layout.swift`) |

### Deprecated Architectural Patterns

**God Object Pattern** → **Facade + Composition**
- **Old**: 1,357-line WindowCoordinator with 10 responsibilities
- **New**: 223-line facade composing 7 focused controllers + 3 pure types + 1 layout extension
- **Why**: Single Responsibility Principle, testability, maintainability, SwiftLint compliance

**Property Forwarding Anti-Pattern** → **Direct Composition**
```swift
// ❌ DEPRECATED: One-line forwarding wrappers
private func schedulePersistenceFlush() {
    framePersistence.schedulePersistenceFlush()
}

// ✅ CURRENT: Direct access to composed property
coordinator.framePersistence.schedulePersistenceFlush()
```

**Inline Task Setup** → **Lifecycle-Aware Observers**
```swift
// ❌ DEPRECATED: Direct Task property in main class
@ObservationIgnored private var alwaysOnTopTask: Task<Void, Never>?

private func setupAlwaysOnTopObserver() {
    alwaysOnTopTask?.cancel()
    alwaysOnTopTask = Task { @MainActor [weak self] in
        withObservationTracking { ... } onChange: { ... }
    }
}

// ✅ CURRENT: Dedicated observer with start/stop lifecycle
private let settingsObserver: WindowSettingsObserver

settingsObserver.start(
    onAlwaysOnTopChanged: { [weak self] isOn in
        self?.updateWindowLevels(isOn)
    }
)
// stop() called in teardown (or tasks auto-terminate via [weak self])
```

**Manual Delegate Wiring** → **Static Factory Pattern**
```swift
// ❌ DEPRECATED: Inline multiplexer + delegate creation
private var mainDelegateMultiplexer: WindowDelegateMultiplexer?
private var mainFocusDelegate: WindowFocusDelegate?
// ... 10 more properties (5 multiplexers + 5 focus delegates)

func wireUpDelegates() {
    let mainMux = WindowDelegateMultiplexer()
    mainMux.add(delegate: WindowSnapManager.shared)
    // ... 30+ lines of repetitive setup for 5 windows
}

// ✅ CURRENT: Static factory returns struct with strong refs
private var delegateWiring: WindowDelegateWiring?

delegateWiring = WindowDelegateWiring.wire(
    registry: registry,
    persistenceDelegate: framePersistence.persistenceDelegate,
    windowFocusState: windowFocusState
)
// Iterates all 5 windows, no boilerplate
```

---

*Finalized after Phase 4 completion. WindowCoordinator.swift: 1,357 → 223 lines (-84%).*
