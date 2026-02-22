# TODOs: Swift Testing Modernization

> **Purpose:** Actionable checklist of all work items organized by phase.
> Check items off as they are completed.

---

## Phase 1: Package.swift Modernization

- [ ] Bump `swift-tools-version` from `5.9` to `6.0` in `Package.swift`
- [ ] Verify `swiftLanguageMode` defaults correctly (implicit with tools-version 6.0+)
- [ ] Run `swift build` and fix any strict concurrency errors
- [ ] Run `swift test` and confirm all 23 tests still pass
- [ ] Commit: "build: Bump swift-tools-version to 6.0 for strict concurrency"

## Phase 2: Assertion Migration

### 2.1 AppSettingsTests.swift
- [ ] Add `import Testing`
- [ ] Convert `XCTAssertTrue` -> `#expect`
- [ ] Convert `XCTAssertEqual` -> `#expect(a == b)`
- [ ] Convert `XCTAssertThrowsError` -> `#expect(throws:)`

### 2.2 AudioPlayerStateTests.swift
- [ ] Add `import Testing`
- [ ] Convert `XCTAssertEqual` -> `#expect(a == b)`
- [ ] Remove unnecessary `async throws` from both test signatures

### 2.3 DockingControllerTests.swift
- [ ] Add `import Testing`
- [ ] Convert `XCTAssertFalse` -> `#expect(!x)`
- [ ] Convert `XCTAssertTrue` -> `#expect(x)`
- [ ] Convert `XCTSkip` -> `try #require` precondition

### 2.4 EQCodecTests.swift
- [ ] Add `import Testing`
- [ ] Convert `XCTAssertEqual` -> `#expect`
- [ ] Convert `XCTAssertTrue` -> `#expect`
- [ ] Convert `XCTAssertNil` -> `#expect(x == nil)`
- [ ] Convert `XCTAssertNotNil` + optional chains -> `try #require` + direct access

### 2.5 SkinManagerTests.swift
- [ ] Add `import Testing`
- [ ] Convert `XCTAssertNil` -> `#expect(x == nil)`
- [ ] Convert `XCTAssertNotNil` -> `try #require`
- [ ] Fix `XCTSkip` timeout misuse -> proper failure

### 2.6 SpriteResolverTests.swift
- [ ] Add `import Testing`
- [ ] Convert `XCTAssertNil` -> `#expect(x == nil)`
- [ ] Convert `XCTAssertEqual` -> `#expect`

### 2.7 PlaylistNavigationTests.swift
- [ ] Add `import Testing`
- [ ] Convert `XCTFail` -> `Issue.record`
- [ ] Convert `try XCTUnwrap` -> `try #require`
- [ ] Convert `XCTAssertEqual` -> `#expect`
- [ ] Remove unnecessary `async throws`

### 2.8 WindowDockingGeometryTests.swift
- [ ] Add `import Testing`
- [ ] Convert `XCTFail` -> `Issue.record`
- [ ] Convert `XCTAssertEqual(accuracy:)` -> `#expect(abs(a - b) < 0.01)`
- [ ] Convert `XCTAssertNil` -> `#expect(x == nil)`
- [ ] Convert `XCTAssertEqual` -> `#expect`

### 2.9 WindowFrameStoreTests.swift
- [ ] Add `import Testing`
- [ ] Convert `try XCTUnwrap` -> `try #require`
- [ ] Convert `XCTAssertEqual(accuracy:)` -> `#expect(abs(a - b) < 0.01)`
- [ ] Convert `XCTAssertNil` -> `#expect(x == nil)`
- [ ] Fix silent `guard else { return }` -> `try #require`
- [ ] Convert `XCTSkip` -> `try #require`

### Phase 2 Verification
- [ ] All 23 tests pass with new assertions
- [ ] `swift test` passes
- [ ] Build with Thread Sanitizer succeeds
- [ ] Commit: "test: Migrate assertions from XCTAssert to #expect/#require"

## Phase 3: Suite Modernization

### 3.1 Structural changes (all files)
- [ ] Remove `import XCTest` from all test files
- [ ] Replace `final class FooTests: XCTestCase` -> `struct FooTests` (or `@Suite struct`)
- [ ] Replace `func testFoo()` -> `@Test func foo()`
- [ ] Add `@Test("display name")` where it improves readability

### 3.2 @MainActor audit
- [ ] Keep `@MainActor` on: AppSettingsTests, AudioPlayerStateTests, DockingControllerTests, SkinManagerTests, PlaylistNavigationTests
- [ ] Confirm no `@MainActor` needed on: EQCodecTests, WindowDockingGeometryTests, WindowFrameStoreTests, SpriteResolverTests

### 3.3 Setup refactors
- [ ] PlaylistNavigationTests: extract shared track setup into `init()`
- [ ] SpriteResolverTests: move `makeEmptySkin()` to stored property in `init()`
- [ ] WindowFrameStoreTests: extract UserDefaults setup into `init()` with `try #require`

### Phase 3 Verification
- [ ] All tests pass
- [ ] No `import XCTest` remains
- [ ] Build clean with `swift test`
- [ ] Commit: "test: Modernize test suites to Swift Testing structs"

## Phase 4: Parameterization

- [ ] AudioPlayerStateTests: collapse 2 state transition tests into 1 parameterized test
- [ ] SpriteResolverTests: parameterize digit boundary tests with `@Test(arguments: [-1, 10, 99, -100])`
- [ ] WindowDockingGeometryTests: parameterize attachment direction tests (below/above/right) with `zip`
- [ ] Verify each parameterized case appears individually in test navigator
- [ ] Commit: "test: Introduce parameterized tests for duplicate test logic"

## Phase 5: Async Fixes

- [ ] DockingControllerTests: replace `Task.sleep(300ms)` with deterministic wait pattern
- [ ] SkinManagerTests: replace `waitUntilNotLoading` polling loop with `confirmation` or async signal
- [ ] Remove all `Task.sleep`-based synchronization from tests
- [ ] Run tests 10x to verify no flakiness
- [ ] Commit: "test: Replace time-based waits with deterministic async patterns"

## Phase 6: Tags, Traits & Organization

### 6.1 Define tags
- [ ] Create tag extensions (in a shared file or per-suite):
  - `.audio`, `.skin`, `.window`, `.persistence`, `.parsing`

### 6.2 Apply tags
- [ ] AudioPlayerStateTests -> `.audio`
- [ ] DockingControllerTests -> `.window, .persistence`
- [ ] EQCodecTests -> `.audio, .parsing`
- [ ] SkinManagerTests -> `.skin`
- [ ] SpriteResolverTests -> `.skin`
- [ ] PlaylistNavigationTests -> `.audio`
- [ ] WindowDockingGeometryTests -> `.window`
- [ ] WindowFrameStoreTests -> `.window, .persistence`

### 6.3 Apply traits
- [ ] Add `.timeLimit(.seconds(5))` to async tests (SkinManager, DockingController)
- [ ] Add `.bug("url")` to any tests covering known issues

### Phase 6 Verification
- [ ] Tags visible in Xcode test navigator
- [ ] Can filter by tag in test plan
- [ ] Commit: "test: Add Swift Testing tags and traits for CI filtering"

---

## Final Verification

- [ ] `swift build` clean
- [ ] `swift test` all pass
- [ ] Xcode build with Thread Sanitizer clean
- [ ] No `import XCTest` in any test file (unless justified)
- [ ] No `XCTAssert*` calls remain
- [ ] No `Task.sleep` waits in tests
- [ ] Update `state.md` to reflect completion
