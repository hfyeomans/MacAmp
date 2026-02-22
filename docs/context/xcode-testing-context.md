# Xcode Testing Context (MacAmp)

## Purpose

This document gives a fast, practical overview of the MacAmp Xcode test setup so another agent can run and extend tests quickly, with a focus on concurrency-related coverage.

## Test Setup Overview

- **Scheme**: `MacAmpApp`
- **Test target**: `MacAmpTests` (`Tests/MacAmpTests`)
- **Test framework**: Swift Testing (`import Testing`, `@Suite` structs, `#expect`/`#require` macros)
- **Test plan**: `MacAmpApp.xctestplan` (`MacAmpApp.xcodeproj/xcshareddata/xctestplans/MacAmpApp.xctestplan`)
- **Configuration**: Single "All" configuration (simplified from prior 3-config setup)
- **swift-tools-version**: 6.2
- **Total tests**: 40 (across 10 suites)

## Test Tags

Tests are organized with Swift Testing tags defined in `Tests/MacAmpTests/TestTags.swift`:

| Tag | Suites |
|-----|--------|
| `.audio` | LockFreeRingBufferTests, AudioPlayerStateTests |
| `.concurrency` | LockFreeRingBufferConcurrencyTests |
| `.skin` | SkinManagerTests, SpriteResolverTests |
| `.window` | DockingControllerTests, WindowDockingGeometryTests, WindowFrameStoreTests |
| `.persistence` | DockingControllerTests, WindowFrameStoreTests |
| `.parsing` | EQCodecTests, PlaylistNavigationTests |

## Concurrency-Related Tests

The following suites catch async and thread-safety regressions:

- `AudioPlayerStateTests`: verifies @MainActor playback state transitions for stop/eject.
- `DockingControllerTests`: verifies debounced persistence to UserDefaults using async waits.
- `PlaylistNavigationTests`: verifies next/previous playlist actions across local + stream tracks.
- `SkinManagerTests`: verifies async skin loading and error state updates.
- `LockFreeRingBufferConcurrencyTests`: verifies SPSC ring buffer under concurrent write/read, format changes, and high throughput.

All @MainActor-annotated suites catch UI-bound state regressions and async ordering issues.

## Running Tests (CLI)

```bash
xcodebuild test -project MacAmpApp.xcodeproj -scheme MacAmpApp -destination 'platform=macOS' -testPlan MacAmpApp -derivedDataPath build/DerivedDataTests
```

> **Note:** `swift test` via SPM currently has an unrelated "multiple producers" build error. Use Xcode (`xcodebuild`) for running tests.

## Adding or Updating Tests

1. Add the test file under `Tests/MacAmpTests`.
2. Use `@Suite struct` (not `XCTestCase`) with `import Testing`.
3. Use `@Test` attribute on test functions (not `func test*()` prefix).
4. Use `#expect` / `#require` assertions (not `XCTAssert*`).
5. Apply appropriate tags from `TestTags.swift`.
6. Keep `@MainActor` on suites that touch UI-bound state or SwiftUI models.
7. Add `.timeLimit(.minutes(1))` to async tests.

## References

- `docs/README.md` → Test Plan Quick Reference
- `docs/IMPLEMENTATION_PATTERNS.md` → §7 Testing Patterns
- `docs/MACAMP_ARCHITECTURE_GUIDE.md` → §12 Testing Strategies
