# Research: Swift Testing Modernization

> **Purpose:** Comprehensive audit findings of the MacAmp test suite, documenting current state,
> framework versions, anti-patterns, coverage gaps, and modernization opportunities against
> Swift 6.0/6.2 and the Swift Testing framework.

---

## 1. Version Landscape

### Installed Toolchain

| Layer | Version | Source |
|---|---|---|
| Swift toolchain | 6.2.4 (swiftlang-6.2.4.1.4) | `swift --version` |
| Target | arm64-apple-macosx26.0 | Xcode 26 |
| Xcode project (`SWIFT_VERSION`) | 6.0 | `project.pbxproj` (all 6 build configs) |
| Package.swift (`swift-tools-version`) | 5.9 | `Package.swift:1` |
| Package.swift (`swiftLanguageMode`) | Not set | Missing entirely |

### Version Mismatch

- **Xcode builds** enforce Swift 6.0 strict concurrency via `SWIFT_VERSION = 6.0` in pbxproj
- **SPM builds** (`swift build` / `swift test`) use tools-version 5.9 with no `swiftLanguageMode`, so strict concurrency is **not enforced** through SPM
- Package.swift needs bumping to `swift-tools-version: 6.0` minimum, which enables strict concurrency by default

---

## 2. Test Suite Inventory

### Summary

| Metric | Value |
|---|---|
| Test files | 8 |
| Total test methods | 23 |
| Framework | 100% legacy XCTest |
| Swift Testing (`import Testing`) | 0% |
| SwiftUI view tests | 0 |
| Production source files | ~85 |
| Estimated testable coverage | ~15-20% |

### All Test Files

| File | Tests | @MainActor | Async | Notes |
|---|---|---|---|---|
| `AppSettingsTests.swift` | 2 | Yes | No | Filesystem tests |
| `AudioPlayerStateTests.swift` | 2 | Yes | Unnecessary `async throws` | State transitions |
| `DockingControllerTests.swift` | 1 | Yes | Yes (Task.sleep wait) | Persistence roundtrip |
| `EQCodecTests.swift` | 3 | No | No | Pure data logic |
| `SkinManagerTests.swift` | 2 | Yes | Yes (polling wait) | Load/error tests |
| `SpriteResolverTests.swift` | 2 | No | No | Digit resolution |
| `PlaylistNavigationTests.swift` | 2 | Yes | Unnecessary `async throws` | Mixed playlist nav |
| `WindowDockingGeometryTests.swift` | 6 | No | No | Pure geometry (best structured) |
| `WindowFrameStoreTests.swift` | 3 | No | No | Codable + UserDefaults |

---

## 3. Per-File Detailed Findings

### 3.1 AppSettingsTests.swift (2 tests)

**Path:** `Tests/MacAmpTests/AppSettingsTests.swift`

**Current:**
- `import XCTest`, `@MainActor final class AppSettingsTests: XCTestCase`
- Tests `ensureSkinsDirectory` create and error paths
- Good use of `defer` for temp directory cleanup

**Issues:**
- `XCTAssertThrowsError` (line 28) doesn't validate specific error type
- Assertions: `XCTAssertTrue`, `XCTAssertEqual`, `XCTAssertThrowsError`

**Migration map:**
- `XCTAssertTrue(fileManager.fileExists(...))` -> `#expect(fileManager.fileExists(...))`
- `XCTAssertEqual(a, b)` -> `#expect(a == b)`
- `XCTAssertThrowsError(try f())` -> `#expect(throws: (any Error).self) { try f() }`
- Could use `struct` suite with temp dir setup in `init`

---

### 3.2 AudioPlayerStateTests.swift (2 tests)

**Path:** `Tests/MacAmpTests/AudioPlayerStateTests.swift`

**Current:**
- `@MainActor final class AudioPlayerStateTests: XCTestCase`
- Tests `stop()` -> `.stopped(.manual)` and `eject()` -> `.stopped(.ejected)`

**Issues:**
- Both marked `async throws` but contain **zero async work** - `player.stop()` and `player.eject()` are synchronous
- **Parameterization candidate:** identical logic, differ only in method + expected state

**Migration map:**
- Drop `async throws`
- Collapse into single `@Test(arguments: zip([...], [...]))` parameterized test
- `XCTAssertEqual` -> `#expect`

---

### 3.3 DockingControllerTests.swift (1 test)

**Path:** `Tests/MacAmpTests/DockingControllerTests.swift`

**Current:**
- `@MainActor final class DockingControllerTests: XCTestCase`
- Tests persistence roundtrip: toggle playlist, wait for debounce, rehydrate

**Issues:**
- **Anti-pattern: `Task.sleep` for synchronization** (line 27, 300ms). Brittle under CI load. The Swift Testing async reference explicitly warns against time-based waits.
- `XCTSkip` for failing `UserDefaults` init misrepresents infrastructure failure as skip
- Only 1 test for a persistence-critical component

**Migration map:**
- `XCTSkip` -> `try #require(UserDefaults(suiteName: suiteName))`
- `XCTAssertFalse/True` -> `#expect(!x)` / `#expect(x)`
- Replace `Task.sleep` debounce with deterministic signal or `confirmation`

---

### 3.4 EQCodecTests.swift (3 tests)

**Path:** `Tests/MacAmpTests/EQCodecTests.swift`

**Current:**
- `final class EQCodecTests: XCTestCase` (no `@MainActor` - correct, pure data)
- Tests EQPreset clamping, EQF parsing rejection, EQF value clamping

**Issues:**
- `XCTAssertTrue(preset.bands.allSatisfy { $0 == -12 })` (line 13) loses diagnostic context - won't show which band failed
- `testEQFParsingClampsValues` uses `?? false` and `?? 0` fallbacks (lines 36-37) that obscure failures. Should unwrap with `#require` first.
- Complex assertion chain in `testEQFParsingClampsValues` could be cleaner

**Migration map:**
- `XCTAssertNil(x)` -> `#expect(x == nil)`
- `XCTAssertNotNil(preset)` + `preset?.` chains -> `let p = try #require(preset)` then assert directly
- `XCTAssertTrue(x.allSatisfy {...})` -> `#expect(x.allSatisfy {...})` (or iterate for better diagnostics)
- `XCTAssertEqual` -> `#expect`

---

### 3.5 SkinManagerTests.swift (2 tests)

**Path:** `Tests/MacAmpTests/SkinManagerTests.swift`

**Current:**
- `@MainActor final class SkinManagerTests: XCTestCase`
- Tests load success (clears error, sets skin) and load failure (sets error)

**Issues:**
- **Anti-pattern: polling loop with `Task.sleep`** (lines 49-56). `waitUntilNotLoading` spins with 50ms intervals. Should use `confirmation` or `AsyncSequence`.
- `XCTSkip` for timeout (line 53) misrepresents timeout as skip rather than failure
- `bundledSkinURL` (lines 30-47) uses `#filePath` path traversal - fragile
- Doesn't validate loaded `Skin` properties, only checks non-nil

**Migration map:**
- `XCTAssertNil(x)` -> `#expect(x == nil)`
- `XCTAssertNotNil(manager.currentSkin)` -> `let skin = try #require(manager.currentSkin)` then validate
- Replace polling with deterministic async wait
- `bundledSkinURL` -> use `Bundle.module` with SPM resource processing

---

### 3.6 SpriteResolverTests.swift (2 tests)

**Path:** `Tests/MacAmpTests/SpriteResolverTests.swift`

**Current:**
- `final class SpriteResolverTests: XCTestCase` (no `@MainActor`)
- Tests digit out-of-range returns nil, digit resolves when image available

**Issues:**
- No `@MainActor` but works with `NSImage` (AppKit) - may need isolation check
- **Parameterization candidate:** `testDigitOutOfRangeReturnsNil` checks 2 values (-1, 10). Parameterize with `@Test(arguments: [-1, 10, 99, -100])`
- `makeEmptySkin()` helper is verbose - good candidate for suite `init`
- Very thin coverage - `SpriteResolver` has many more resolution paths

**Migration map:**
- `XCTAssertNil(x)` -> `#expect(x == nil)`
- `XCTAssertEqual(x, y)` -> `#expect(x == y)`
- Parameterize boundary tests
- Move `makeEmptySkin()` to suite `init`

---

### 3.7 PlaylistNavigationTests.swift (2 tests)

**Path:** `Tests/MacAmpTests/PlaylistNavigationTests.swift`

**Current:**
- `@MainActor final class PlaylistNavigationTests: XCTestCase`
- Tests next/previous track with mixed local+stream playlist

**Issues:**
- Both `async throws` but contain **no async work**
- `guard case` + `XCTFail` pattern (lines 27-29, 56-58) - classic XCTest enum extraction boilerplate
- Duplicate setup boilerplate (lines 10-19 vs 40-51) - identical track creation copy-pasted
- `try XCTUnwrap(URL(...))` used for URL construction

**Migration map:**
- `XCTFail("message")` -> `Issue.record("message")`
- `guard case ... else { XCTFail; return }` -> `try #require` with pattern matching
- `try XCTUnwrap(x)` -> `try #require(x)`
- Factor common setup into suite `init`
- Remove unnecessary `async`

---

### 3.8 WindowDockingGeometryTests.swift (6 tests)

**Path:** `Tests/MacAmpTests/WindowDockingGeometryTests.swift`

**Current:**
- `final class WindowDockingGeometryTests: XCTestCase` (no `@MainActor` - correct, pure geometry)
- Tests attachment detection (below, above, right, none) and origin/frame calculations
- **Best structured test file** - good MARK sections, clear naming

**Issues:**
- `guard case` + `XCTFail` pattern repeated 3 times (lines 17-20, 33-36, 49-52)
- `XCTAssertEqual(_:_:accuracy:)` for floating point - no direct Swift Testing equivalent
- **Parameterization candidate:** below/above/right attachment tests have identical structure
- Missing: no `.left` attachment test, no non-zero offset tests

**Migration map:**
- `guard case` -> `try #require` pattern matching
- `XCTAssertEqual(a, b, accuracy: 0.01)` -> helper or `#expect(abs(a - b) < 0.01)`
- Consider parameterized test for attachment directions
- `XCTAssertNil(x)` -> `#expect(x == nil)`

---

### 3.9 WindowFrameStoreTests.swift (3 tests)

**Path:** `Tests/MacAmpTests/WindowFrameStoreTests.swift`

**Current:**
- `final class WindowFrameStoreTests: XCTestCase` (no `@MainActor` - correct)
- Tests Codable roundtrip, UserDefaults save/load, nil for unknown key

**Issues:**
- `testWindowFrameStoreReturnsNilForUnknownKey` (line 43) has silent `guard ... else { return }` that masks infrastructure failure as a pass
- `try XCTUnwrap(loaded)` -> `try #require(loaded)`
- `XCTAssertEqual(accuracy:)` used 4 times

**Migration map:**
- `guard ... else { return }` -> `try #require(UserDefaults(...))`
- `try XCTUnwrap(x)` -> `try #require(x)`
- `XCTAssertEqual(a, b, accuracy:)` -> `#expect(abs(a - b) < 0.01)`

---

## 4. Cross-Cutting Anti-Patterns

### 4.1 Zero Swift Testing Adoption
All 8 files import `XCTest` and subclass `XCTestCase`. None import `Testing`. This is the single biggest modernization gap.

### 4.2 `async throws` Misuse
4 of 8 files mark tests `async throws` with no async work:
- `AudioPlayerStateTests` (both tests)
- `PlaylistNavigationTests` (both tests)

### 4.3 Time-Based Waiting
2 files use `Task.sleep` for synchronization:
- `DockingControllerTests.waitForDebounce()` - 300ms sleep
- `SkinManagerTests.waitUntilNotLoading()` - 50ms polling loop

The Swift Testing async reference explicitly warns: "Avoid sleeping/time-based waits as primary synchronization."

### 4.4 `guard case` + `XCTFail` Boilerplate
5 occurrences across `PlaylistNavigationTests` (2x) and `WindowDockingGeometryTests` (3x). Swift Testing's `try #require` with pattern matching eliminates this.

### 4.5 Silent Passes on Infrastructure Failure
`WindowFrameStoreTests` line 45: `guard let defaults = ... else { return }` silently passes if UserDefaults init fails.

### 4.6 No Tags, Traits, or Organization
No test categorization, no `.timeLimit`, no `.bug` links, no tags for CI filtering. All 23 tests run flat without structure.

### 4.7 No Parameterized Tests
Identified candidates:
- `AudioPlayerStateTests`: 2 tests with identical logic
- `SpriteResolverTests`: boundary value tests
- `WindowDockingGeometryTests`: 3 attachment direction tests

---

## 5. Coverage Gap Analysis

### Tested Areas (partial coverage)

| Area | Production Files | Test Count | Quality |
|---|---|---|---|
| AppSettings (filesystem) | `AppSettings.swift` | 2 | Good |
| AudioPlayer state | `AudioPlayer.swift` | 2 | Thin |
| DockingController | `DockingController.swift` | 1 | Thin, flaky wait |
| EQ codec/preset | `EQPreset.swift`, `EQF.swift` | 3 | Decent |
| SkinManager | `SkinManager.swift` | 2 | Thin, flaky wait |
| SpriteResolver | `SpriteResolver.swift` | 2 | Very thin |
| Playlist navigation | `AudioPlayer.swift` | 2 | Good |
| Window docking geometry | `WindowDockingGeometry.swift` | 6 | Good coverage |
| WindowFrameStore | `WindowFrameStore.swift` | 3 | Good |

### Completely Untested Areas

| Area | Production Files | Risk |
|---|---|---|
| **PlaybackCoordinator** | `PlaybackCoordinator.swift` | **Critical** - orchestrates dual audio backends |
| **StreamPlayer** | `StreamPlayer.swift` | **Critical** - internet radio playback |
| **VisualizerPipeline** | `VisualizerPipeline.swift` | Medium - real-time audio viz |
| **PlaylistController** | `PlaylistController.swift` | **High** - playlist management logic |
| **M3U Parser** | `M3UParser.swift`, `M3UEntry.swift` | **High** - file format parsing (pure logic, easy to test) |
| **PLEdit Parser** | `PLEditParser.swift` | Medium - skin config parsing |
| **VisColor Parser** | `VisColorParser.swift` | Medium - visualizer color parsing |
| **Skin model** | `Skin.swift`, `ImageSlicing.swift` | Medium - skin data model |
| **Track model** | `Track.swift` | Low - data model |
| **RadioStation** | `RadioStation.swift`, `RadioStationLibrary.swift` | Medium - radio station management |
| **VideoPlaybackController** | `VideoPlaybackController.swift` | Medium - video playback |
| **WindowCoordinator** | `WindowCoordinator.swift`, `+Layout.swift` | **High** - window orchestration |
| **WindowRegistry** | `WindowRegistry.swift` | Medium - window lifecycle |
| **EQPresetStore** | `EQPresetStore.swift` | Medium - preset persistence |
| **SnapUtils** | `SnapUtils.swift` | Low - utility functions |
| **All SwiftUI Views** | 20+ view files | **High** - zero view tests |
| **All Window Controllers** | 5 controller files | Medium - NSWindow integration |

---

## 6. Swift Testing Framework Reference

### Key Migration Mappings (XCTest -> Swift Testing)

```
import XCTest           -> import Testing
XCTestCase class        -> struct suite (or @Suite struct)
func testFoo()          -> @Test func foo()
XCTAssertTrue(x)        -> #expect(x)
XCTAssertFalse(x)       -> #expect(!x)
XCTAssertEqual(a, b)    -> #expect(a == b)
XCTAssertNil(x)         -> #expect(x == nil)
XCTAssertNotNil(x)      -> #expect(x != nil)  or  try #require(x)
try XCTUnwrap(x)        -> try #require(x)
XCTAssertThrowsError    -> #expect(throws: ErrorType.self) { ... }
XCTFail("msg")          -> Issue.record("msg")
XCTSkip("msg")          -> (use .disabled trait or try #require precondition)
XCTestExpectation       -> confirmation("name", expectedCount: N) { ... }
```

### Struct Suite Benefits
- Value semantics prevent accidental state sharing between tests
- Fresh instance per test (automatic isolation)
- `init()` replaces `setUp()`
- No `override` ceremony

### Parameterization
- `@Test(arguments: collection)` for single-input
- `@Test(arguments: collection1, collection2)` for cartesian product
- `@Test(arguments: zip(a, b))` for paired scenarios

### @MainActor Strategy
- XCTest: `@MainActor` on class isolates everything (including test runner)
- Swift Testing: tests run on arbitrary executors by default
- Only apply `@MainActor` to individual test functions that truly need it
- Or apply to suite when ALL tests require main actor isolation

---

## 7. Package.swift Modernization Requirements

### Current State
```swift
// swift-tools-version: 5.9
// No swiftLanguageMode
// No swiftSettings
```

### Required Changes
```swift
// swift-tools-version: 6.0
// swiftLanguageMode: .v6 (default with tools-version 6.0+)
// Add swiftSettings for strict concurrency if needed
```

### Impact
- Bumping to 6.0 enables strict concurrency by default for SPM builds
- May surface concurrency violations currently hidden in SPM-only builds
- Aligns SPM and Xcode build behavior
- Enables `import Testing` in test targets

---

## 8. References

- Swift Testing skill references: `fundamentals.md`, `expectations.md`, `traits-and-tags.md`, `parameterized-testing.md`, `parallelization-and-isolation.md`, `async-testing-and-waiting.md`, `migration-from-xctest.md`
- Apple Swift Testing documentation (Xcode 16+)
- MacAmp CLAUDE.md and AGENTS.md project conventions
- Xcode 26 documentation: `/Applications/Xcode.app/.../AdditionalDocumentation/`
