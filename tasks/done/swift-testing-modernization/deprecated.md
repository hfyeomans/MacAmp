# Deprecated: Swift Testing Modernization

> **Purpose:** Document deprecated or legacy code patterns discovered during this task
> that have been removed or replaced. Per project conventions, we document here instead
> of adding `// Deprecated` comments in code.

---

## Removed Legacy Patterns

### 1. XCTest Framework Usage (All 9 Test Files) — REMOVED

**What:** `import XCTest`, `XCTestCase` subclasses, `XCTAssert*` assertion families
**Why removed:** Apple's Swift Testing framework (available since Swift 5.9 / Xcode 16) supersedes XCTest for unit and integration tests. Swift Testing provides better diagnostics, parameterized tests, structured concurrency support, and value-type suites.
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
**Status:** Complete. Zero `import XCTest` or `XCTAssert*` calls remain.

### 2. `XCTAssertEqual(_:_:accuracy:)` Pattern — REMOVED

**What:** Floating-point comparisons using `XCTAssertEqual(a, b, accuracy: 0.01)`
**Why removed:** No direct equivalent in Swift Testing.
**Replaced with:** `#expect(abs(a - b) < 0.01)`
**Files affected:** `WindowDockingGeometryTests.swift`, `WindowFrameStoreTests.swift`
**Status:** Complete.

### 3. `guard case` + `XCTFail` Enum Extraction Pattern — REMOVED

**What:** `guard case .foo(let x) = value else { XCTFail("msg"); return }`
**Why removed:** Verbose boilerplate.
**Replaced with:** `guard case` + `Issue.record` (Swift Testing equivalent)
**Files affected:** `PlaylistNavigationTests.swift`, `WindowDockingGeometryTests.swift`
**Status:** Complete.

### 4. `try XCTUnwrap()` Optional Unwrapping — REMOVED

**What:** `let x = try XCTUnwrap(optionalValue)`
**Why removed:** XCTest-specific.
**Replaced with:** `try #require(optionalValue)`
**Files affected:** `PlaylistNavigationTests.swift`, `WindowFrameStoreTests.swift`, `DockingControllerTests.swift`
**Status:** Complete.

### 5. `swift-tools-version: 5.9` in Package.swift — REMOVED

**What:** Pre-Swift 6 tools version
**Why removed:** Does not enforce strict concurrency in SPM builds, mismatched with Xcode's `SWIFT_VERSION = 6.0`
**Replaced with:** `swift-tools-version: 6.2`
**Files affected:** `Package.swift`
**Status:** Complete.

### 6. Multi-Configuration Test Plan with XCTest `selectedTests` — REMOVED

**What:** Test plan with 3 configurations (Core, Concurrency, All) using `selectedTests` with XCTest-style identifiers like `MacAmpTests/AppSettingsTests/testEnsureSkinsDirectoryCreatesStructure`
**Why removed:** XCTest-style identifiers don't match Swift Testing `@Suite` structs, causing all tests to be marked `disabled: true` and 0 tests to run.
**Replaced with:** Single "All" configuration without `selectedTests`, relying on Swift Testing's automatic test discovery.
**Files affected:** `MacAmpApp.xcodeproj/xcshareddata/xctestplans/MacAmpApp.xctestplan`
**Status:** Complete.

---

## Legacy Patterns Still Present (Not Yet Removed)

### 7. `Task.sleep`-Based Test Synchronization — STILL PRESENT

**What:** Using `Task.sleep(nanoseconds:)` or polling loops to wait for async state changes
**Why deprecated:** Brittle under CI load, introduces artificial delays, explicitly discouraged by Swift Testing async guidelines.
**Should be replaced with:** Deterministic async patterns (`confirmation`, async sequence, or observable property change)
**Files affected:** `DockingControllerTests.swift` (300ms sleep), `SkinManagerTests.swift` (50ms polling loop)
**Status:** Deferred. Requires production code changes for deterministic signaling. See `async-test-determinism` follow-up task.
