# Plan: Swift Testing Modernization

> **Purpose:** Step-by-step implementation plan for migrating the MacAmp test suite from
> legacy XCTest to modern Swift Testing framework, updating Package.swift to Swift 6.0+,
> and expanding test coverage for untested production code.

---

## Overview

Migrate all 8 existing test files (23 tests) from XCTest to Swift Testing, modernize the
Package.swift build configuration, fix async anti-patterns, introduce parameterized tests,
and add new test coverage for critical untested areas.

**Guiding principles:**
- Incremental, reviewable commits per phase
- Never break the build between commits
- Mechanical assertion conversion first, structural changes second
- Verify each phase compiles and passes before moving to the next

---

## Phase 1: Package.swift Modernization

**Goal:** Align SPM build with Xcode's Swift 6.0 language mode.

### Changes:
1. Bump `swift-tools-version: 5.9` -> `swift-tools-version: 6.0`
2. Verify `swiftLanguageMode` defaults to `.v6` (implicit with tools-version 6.0)
3. Run `swift build` and `swift test` to surface any concurrency violations
4. Fix any new compiler errors from strict concurrency enforcement

### Files touched:
- `Package.swift`

### Verification:
- `swift build` succeeds
- `swift test` succeeds
- All 23 existing tests pass

---

## Phase 2: Assertion Migration (Mechanical)

**Goal:** Convert all `XCTAssert*` calls to `#expect` / `#require` while keeping XCTestCase structure.

This is a coexistence phase - files will import both `XCTest` and `Testing` temporarily.

### Per-file conversion:

#### 2.1 AppSettingsTests.swift
- `XCTAssertTrue(x)` -> `#expect(x)`
- `XCTAssertEqual(a, b)` -> `#expect(a == b)`
- `XCTAssertThrowsError(try f())` -> `#expect(throws: (any Error).self) { try f() }`

#### 2.2 AudioPlayerStateTests.swift
- `XCTAssertEqual(a, b)` -> `#expect(a == b)`
- Remove unnecessary `async throws` signatures

#### 2.3 DockingControllerTests.swift
- `XCTAssertFalse(x)` -> `#expect(!x)`
- `XCTAssertTrue(x)` -> `#expect(x)`
- `XCTSkip` -> `try #require` precondition

#### 2.4 EQCodecTests.swift
- `XCTAssertEqual` -> `#expect`
- `XCTAssertTrue` -> `#expect`
- `XCTAssertNil` -> `#expect(x == nil)`
- `XCTAssertNotNil(preset)` + `preset?.` chains -> `let p = try #require(preset)` then direct access

#### 2.5 SkinManagerTests.swift
- `XCTAssertNil` -> `#expect(x == nil)`
- `XCTAssertNotNil` -> `try #require`
- `XCTSkip` for timeout -> actual test failure

#### 2.6 SpriteResolverTests.swift
- `XCTAssertNil` -> `#expect(x == nil)`
- `XCTAssertEqual` -> `#expect`

#### 2.7 PlaylistNavigationTests.swift
- `XCTFail` -> `Issue.record`
- `try XCTUnwrap` -> `try #require`
- `XCTAssertEqual` -> `#expect`
- Remove unnecessary `async throws`

#### 2.8 WindowDockingGeometryTests.swift
- `XCTFail` -> `Issue.record`
- `XCTAssertEqual(a, b, accuracy:)` -> `#expect(abs(a - b) < 0.01)`
- `XCTAssertNil` -> `#expect(x == nil)`
- `XCTAssertEqual` -> `#expect`

#### 2.9 WindowFrameStoreTests.swift
- `try XCTUnwrap` -> `try #require`
- `XCTAssertEqual(accuracy:)` -> `#expect(abs(a - b) < 0.01)`
- `XCTAssertNil` -> `#expect(x == nil)`
- `XCTSkip` -> `try #require`
- Fix silent `guard else { return }` -> `try #require`

### Verification:
- All 23 tests pass with new assertions
- Build with Thread Sanitizer succeeds
- `swift test` succeeds

---

## Phase 3: Suite Modernization

**Goal:** Replace `XCTestCase` classes with Swift Testing `struct` suites.

### Per-file changes:

1. Remove `import XCTest` (replace with `import Testing` only)
2. Replace `final class FooTests: XCTestCase` with `struct FooTests` or `@Suite struct FooTests`
3. Replace `func testFoo()` with `@Test func foo()`
4. Move shared setup into suite `init()` where applicable
5. Add display names where they improve readability: `@Test("description")`
6. Review `@MainActor` placement:
   - Keep on suites where ALL tests need main actor (AppSettings, AudioPlayer, DockingController, SkinManager, PlaylistNavigation)
   - Remove from suites testing pure logic (EQCodec, WindowDockingGeometry, WindowFrameStore, SpriteResolver)

### Specific refactors:
- `PlaylistNavigationTests`: extract shared track setup into `init()`
- `SpriteResolverTests`: move `makeEmptySkin()` to suite stored property via `init()`
- `WindowFrameStoreTests`: extract UserDefaults setup into suite `init()` with `try #require`

### Verification:
- All tests pass
- No `import XCTest` remains (unless coexistence needed)
- Build clean

---

## Phase 4: Parameterization & Deduplication

**Goal:** Collapse duplicate tests into parameterized `@Test(arguments:)`.

### Candidates:

#### 4.1 AudioPlayerStateTests
Collapse 2 tests into 1 parameterized test:
```swift
@Test("State transitions", arguments: [
    (action: "stop", expected: PlaybackState.stopped(.manual)),
    (action: "eject", expected: PlaybackState.stopped(.ejected))
])
func stateTransition(action: String, expected: PlaybackState) { ... }
```

#### 4.2 SpriteResolverTests
Parameterize digit boundary tests:
```swift
@Test("Out-of-range digits return nil", arguments: [-1, 10, 99, -100])
func digitOutOfRange(_ digit: Int) {
    #expect(resolver.resolve(.digit(digit)) == nil)
}
```

#### 4.3 WindowDockingGeometryTests
Parameterize attachment direction tests (below/above/right) using `zip`:
```swift
@Test("Attachment detection", arguments: zip(
    [anchorBelow, anchorAbove, anchorRight],
    [Attachment.below, .above, .right]
))
func attachmentDetected(frames: (NSRect, NSRect), expected: Attachment) { ... }
```

### Verification:
- Same coverage, fewer test methods
- Each parameterized case appears individually in test navigator
- All pass

---

## Phase 5: Async Fixes

**Goal:** Replace time-based waits with deterministic async patterns.

### 5.1 DockingControllerTests
- Replace `Task.sleep(nanoseconds: 300_000_000)` with a deterministic wait
- Options: `confirmation`, observable property change, or async stream

### 5.2 SkinManagerTests
- Replace `waitUntilNotLoading` polling loop with deterministic signal
- Options: `confirmation` on `isLoading` transition, or refactor `SkinManager` to expose async loading API

### Verification:
- Tests pass reliably without time-based waits
- No flakiness under CI load

---

## Phase 6: Tags, Traits & Organization

**Goal:** Add Swift Testing metadata for CI filtering and test organization.

### Tag definitions:
```swift
extension Tag {
    @Tag static var audio: Self
    @Tag static var skin: Self
    @Tag static var window: Self
    @Tag static var persistence: Self
    @Tag static var parsing: Self
}
```

### Tag assignments:
- `AudioPlayerStateTests` -> `.audio`
- `DockingControllerTests` -> `.window, .persistence`
- `EQCodecTests` -> `.audio, .parsing`
- `SkinManagerTests` -> `.skin`
- `SpriteResolverTests` -> `.skin`
- `PlaylistNavigationTests` -> `.audio`
- `WindowDockingGeometryTests` -> `.window`
- `WindowFrameStoreTests` -> `.window, .persistence`

### Traits:
- Add `.timeLimit(.seconds(5))` to async tests (Skin loading, Docking persistence)
- Add `.bug("url")` to any tests covering known issues

### Verification:
- Tags visible in Xcode test navigator
- Can filter test runs by tag

---

## Future Phases (Out of Scope for Initial Migration)

### Phase 7: New Test Coverage (Priority Order)

1. **M3UParser** - Pure logic, easy to test, high value
2. **PLEditParser** - Pure logic, skin config parsing
3. **VisColorParser** - Pure logic, visualizer colors
4. **PlaylistController** - Core playlist management
5. **EQPresetStore** - Preset persistence
6. **PlaybackCoordinator** - Dual backend orchestration (complex, may need mocks)
7. **Track model** - Data model validation
8. **RadioStation/Library** - Station management
9. **SnapUtils** - Utility functions
10. **WindowCoordinator** - Window orchestration (complex, integration-level)

### Phase 8: SwiftUI View Tests

- Evaluate `ViewInspector` or native SwiftUI testing (Xcode 26+)
- Start with pure rendering tests (SkinnedText, TrackInfoView)
- Add interaction tests for buttons/sliders

---

## Risk Assessment

| Risk | Mitigation |
|---|---|
| Package.swift bump breaks SPM build | Fix concurrency errors before proceeding |
| Mixed XCTest/Testing coexistence issues | Phase 2 uses both imports temporarily |
| Parameterization changes test semantics | Verify same assertions, same coverage |
| Async refactors change timing behavior | Run tests multiple times under load |
| `@MainActor` removal exposes races | Keep `@MainActor` where code under test requires it |
