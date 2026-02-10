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

*Updated during research phase. Will be finalized after refactoring completion.*
