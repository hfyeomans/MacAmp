# Deprecated: Swift Testing Modernization

> **Purpose:** Document deprecated or legacy code patterns discovered during this task
> that are being removed or replaced. Per project conventions, we document here instead
> of adding `// Deprecated` comments in code.

---

## Legacy Patterns Being Replaced

### 1. XCTest Framework Usage (All 8 Test Files)

**What:** `import XCTest`, `XCTestCase` subclasses, `XCTAssert*` assertion families
**Why deprecated:** Apple's Swift Testing framework (available since Swift 5.9 / Xcode 16) supersedes XCTest for unit and integration tests. Swift Testing provides better diagnostics, parameterized tests, structured concurrency support, and value-type suites.
**Replaced with:** `import Testing`, `struct` suites with `@Suite`, `@Test` functions, `#expect` / `#require` assertions
**Files affected:**
- `Tests/MacAmpTests/AppSettingsTests.swift`
- `Tests/MacAmpTests/AudioPlayerStateTests.swift`
- `Tests/MacAmpTests/DockingControllerTests.swift`
- `Tests/MacAmpTests/EQCodecTests.swift`
- `Tests/MacAmpTests/SkinManagerTests.swift`
- `Tests/MacAmpTests/SpriteResolverTests.swift`
- `Tests/MacAmpTests/PlaylistNavigationTests.swift`
- `Tests/MacAmpTests/WindowDockingGeometryTests.swift`
- `Tests/MacAmpTests/WindowFrameStoreTests.swift`

### 2. `XCTAssertEqual(_:_:accuracy:)` Pattern

**What:** Floating-point comparisons using `XCTAssertEqual(a, b, accuracy: 0.01)`
**Why deprecated:** No direct equivalent in Swift Testing. Replaced with explicit expression.
**Replaced with:** `#expect(abs(a - b) < 0.01)` or a small helper function
**Files affected:** `WindowDockingGeometryTests.swift`, `WindowFrameStoreTests.swift`

### 3. `guard case` + `XCTFail` Enum Extraction Pattern

**What:** `guard case .foo(let x) = value else { XCTFail("msg"); return }`
**Why deprecated:** Verbose boilerplate. Swift Testing's `try #require` with pattern matching is cleaner.
**Replaced with:** `try #require` or `#expect` with enum case matching
**Files affected:** `PlaylistNavigationTests.swift`, `WindowDockingGeometryTests.swift`

### 4. `try XCTUnwrap()` Optional Unwrapping

**What:** `let x = try XCTUnwrap(optionalValue)`
**Why deprecated:** XCTest-specific. Swift Testing equivalent is `try #require(optionalValue)`.
**Replaced with:** `try #require(optionalValue)`
**Files affected:** `PlaylistNavigationTests.swift`, `WindowFrameStoreTests.swift`

### 5. `Task.sleep`-Based Test Synchronization

**What:** Using `Task.sleep(nanoseconds:)` or polling loops to wait for async state changes
**Why deprecated:** Brittle under CI load, introduces artificial delays, explicitly discouraged by Swift Testing async reference.
**Replaced with:** Deterministic async patterns (confirmation, async sequence, or observable property change)
**Files affected:** `DockingControllerTests.swift`, `SkinManagerTests.swift`

### 6. `swift-tools-version: 5.9` in Package.swift

**What:** Pre-Swift 6 tools version
**Why deprecated:** Does not enforce strict concurrency in SPM builds, mismatched with Xcode's `SWIFT_VERSION = 6.0`
**Replaced with:** `swift-tools-version: 6.0`
**Files affected:** `Package.swift`
