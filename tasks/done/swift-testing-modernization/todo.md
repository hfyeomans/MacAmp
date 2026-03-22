# TODOs: Swift Testing Modernization

> **Purpose:** Actionable checklist of all work items organized by phase.
> Check items off as they are completed.

---

## Phase 1: Package.swift Modernization

- [x] Bump `swift-tools-version` from `5.9` to `6.2` (changed scope from 6.0 to 6.2)
- [x] Verify `swiftLanguageMode` defaults correctly
- [x] Xcode build succeeds
- [ ] **DEFERRED** `swift test` — SPM "multiple producers" build error (unrelated to migration)
- [x] Commit: `3acf75e` "build: Bump swift-tools-version to 6.2 and add swift-atomics dependency"

## Phase 2: Assertion Migration

### 2.1 AppSettingsTests.swift
- [x] Add `import Testing`
- [x] Convert `XCTAssertTrue` -> `#expect`
- [x] Convert `XCTAssertEqual` -> `#expect(a == b)`
- [x] Convert `XCTAssertThrowsError` -> `#expect(throws:)`

### 2.2 AudioPlayerStateTests.swift
- [x] Add `import Testing`
- [x] Convert `XCTAssertEqual` -> `#expect(a == b)`
- [x] Remove unnecessary `async throws` from both test signatures

### 2.3 DockingControllerTests.swift
- [x] Add `import Testing`
- [x] Convert `XCTAssertFalse` -> `#expect(!x)`
- [x] Convert `XCTAssertTrue` -> `#expect(x)`
- [x] Convert `XCTSkip` -> `try #require` precondition

### 2.4 EQCodecTests.swift
- [x] Add `import Testing`
- [x] Convert `XCTAssertEqual` -> `#expect`
- [x] Convert `XCTAssertTrue` -> `#expect`
- [x] Convert `XCTAssertNil` -> `#expect(x == nil)`
- [x] Convert `XCTAssertNotNil` + optional chains -> `try #require` + direct access

### 2.5 SkinManagerTests.swift
- [x] Add `import Testing`
- [x] Convert `XCTAssertNil` -> `#expect(x == nil)`
- [x] Convert `XCTAssertNotNil` -> `try #require`
- [x] Fix `XCTSkip` timeout misuse -> proper failure

### 2.6 SpriteResolverTests.swift
- [x] Add `import Testing`
- [x] Convert `XCTAssertNil` -> `#expect(x == nil)`
- [x] Convert `XCTAssertEqual` -> `#expect`

### 2.7 PlaylistNavigationTests.swift
- [x] Add `import Testing`
- [x] Convert `XCTFail` -> `Issue.record`
- [x] Convert `try XCTUnwrap` -> `try #require`
- [x] Convert `XCTAssertEqual` -> `#expect`
- [x] Remove unnecessary `async throws`

### 2.8 WindowDockingGeometryTests.swift
- [x] Add `import Testing`
- [x] Convert `XCTFail` -> `Issue.record`
- [x] Convert `XCTAssertEqual(accuracy:)` -> `#expect(abs(a - b) < 0.01)`
- [x] Convert `XCTAssertNil` -> `#expect(x == nil)`
- [x] Convert `XCTAssertEqual` -> `#expect`

### 2.9 WindowFrameStoreTests.swift
- [x] Add `import Testing`
- [x] Convert `try XCTUnwrap` -> `try #require`
- [x] Convert `XCTAssertEqual(accuracy:)` -> `#expect(abs(a - b) < 0.01)`
- [x] Convert `XCTAssertNil` -> `#expect(x == nil)`
- [x] Fix silent `guard else { return }` -> `try #require`
- [x] Convert `XCTSkip` -> `try #require`

### Phase 2 Verification
- [x] All tests pass with new assertions
- [x] Build with Thread Sanitizer succeeds
- [x] Commit: `033d0e1` "test: Migrate all 9 test files from XCTest to Swift Testing"

## Phase 3: Suite Modernization

### 3.1 Structural changes (all files)
- [x] Remove `import XCTest` from all test files
- [x] Replace `final class FooTests: XCTestCase` -> `struct FooTests` (or `@Suite struct`)
- [x] Replace `func testFoo()` -> `@Test func foo()`
- [x] Add `@Test("display name")` where it improves readability

### 3.2 @MainActor audit
- [x] Keep `@MainActor` on: AppSettingsTests, AudioPlayerStateTests, DockingControllerTests, SkinManagerTests, PlaylistNavigationTests
- [x] Confirm no `@MainActor` needed on: EQCodecTests, WindowDockingGeometryTests, WindowFrameStoreTests, SpriteResolverTests

### 3.3 Setup refactors
- [x] PlaylistNavigationTests: extract shared track setup into `init()`
- [ ] **DEFERRED** SpriteResolverTests: move `makeEmptySkin()` to stored property in `init()`
- [ ] **DEFERRED** WindowFrameStoreTests: extract UserDefaults setup into `init()` with `try #require`

### Phase 3 Verification
- [x] All tests pass
- [x] No `import XCTest` remains
- [x] Commit: `033d0e1` (combined with Phase 2)

## Phase 4: Parameterization

- [ ] **DEFERRED** AudioPlayerStateTests: collapse 2 state transition tests into 1 parameterized test
- [x] SpriteResolverTests: parameterize digit boundary tests with `@Test(arguments: [-1, 10, 99, -100])`
- [ ] **DEFERRED** WindowDockingGeometryTests: parameterize attachment direction tests with `zip`
- [x] EQCodecTests: parameterized (observed in test output with dynamic parameters)
- [x] Verify parameterized cases appear individually in test navigator
- [x] Commit: `55cc422` (combined with Phases 5-6)

## Phase 5: Async Fixes

- [x] DockingControllerTests: added `.timeLimit(.minutes(1))`
- [ ] **DEFERRED** DockingControllerTests: replace `Task.sleep(300ms)` with deterministic wait
- [x] SkinManagerTests: added `.timeLimit(.minutes(1))`
- [ ] **DEFERRED** SkinManagerTests: replace `waitUntilNotLoading` polling loop with `confirmation` or async signal
- [ ] **DEFERRED** Remove all `Task.sleep`-based synchronization from tests
- [ ] **DEFERRED** Run tests 10x to verify no flakiness
- [x] Commit: `55cc422` (combined with Phases 4+6)

## Phase 6: Tags, Traits & Organization

### 6.1 Define tags
- [x] Create `Tests/MacAmpTests/TestTags.swift` with shared tag extensions:
  - `.audio`, `.skin`, `.window`, `.persistence`, `.parsing`, `.concurrency`

### 6.2 Apply tags
- [x] AudioPlayerStateTests -> `.audio`
- [x] DockingControllerTests -> `.window, .persistence`
- [x] EQCodecTests -> `.parsing`
- [x] SkinManagerTests -> `.skin`
- [x] SpriteResolverTests -> `.skin`
- [x] PlaylistNavigationTests -> `.parsing` (changed from planned `.audio`)
- [x] WindowDockingGeometryTests -> `.window`
- [x] WindowFrameStoreTests -> `.window, .persistence`
- [x] LockFreeRingBufferTests -> `.audio`
- [x] LockFreeRingBufferConcurrencyTests -> `.concurrency`

### 6.3 Apply traits
- [x] Add `.timeLimit(.minutes(1))` to async tests (Swift Testing minimum granularity)
- [ ] **DEFERRED** Add `.bug("url")` to any tests covering known issues

### Phase 6 Verification
- [x] Tags visible in Xcode test navigator
- [x] Commit: `55cc422` (combined with Phases 4+5)

---

## Final Verification

- [x] Xcode build clean
- [ ] **DEFERRED** `swift test` all pass (SPM "multiple producers" error)
- [x] Xcode build with Thread Sanitizer clean (40/40 pass, serial)
- [x] No `import XCTest` in any test file
- [x] No `XCTAssert*` calls remain
- [ ] **DEFERRED** No `Task.sleep` waits in tests (still present in 2 files)
- [x] Update `state.md` to reflect completion
- [x] Fix pre-existing test failures (DockingController + PlaylistNavigation)

---

## Deferred Items Summary

| Item | Reason | Follow-up |
|------|--------|-----------|
| `swift test` via SPM | "Multiple producers" build error in SPM package graph; Xcode builds fine | Investigate SPM config separately |
| `Task.sleep` removal (Phase 5) | Requires production code changes for deterministic async signaling; out of scope for pure migration | Create `async-test-determinism` task |
| AudioPlayerStateTests parameterization | 2 tests have different setup; parameterization adds complexity without much gain | Low priority follow-up |
| WindowDockingGeometryTests parameterization | `zip`-based parameterization needs careful enum handling | Low priority follow-up |
| SpriteResolverTests `init()` refactor | Works fine as-is; refactor is cosmetic | Low priority |
| WindowFrameStoreTests `init()` refactor | Works fine as-is; refactor is cosmetic | Low priority |
| `.bug("url")` traits | No tests currently cover known bugs; add as bugs are filed | As needed |
| 10x flakiness run | Tests pass reliably in serial mode; parallel has test host crash (infra issue) | After test host stability fix |
