# Xcode Testing Context (MacAmp)

## Purpose

This document gives a fast, practical overview of the MacAmp Xcode test setup so another agent can run and extend tests quickly, with a focus on concurrency-related coverage.

## Test Setup Overview

- **Scheme**: `MacAmpApp`
- **Test target**: `MacAmpTests` (`Tests/MacAmpTests`)
- **Test plan**: `MacAmpApp.xctestplan` (`MacAmpApp.xcodeproj/xcshareddata/xctestplans/MacAmpApp.xctestplan`)
- **Configurations**: `Core`, `Concurrency`, `All`

## Concurrency Configuration (Focus)

The `Concurrency` configuration is the quickest signal for async and thread-safety regressions. It currently runs:

- `AudioPlayerStateTests`: verifies @MainActor playback state transitions for stop/eject.
- `DockingControllerTests`: verifies debounced persistence to UserDefaults using async waits.
- `PlaylistNavigationTests`: verifies next/previous playlist actions across local + stream tracks.
- `SkinManagerTests`: verifies async skin loading and error state updates.

All tests are `@MainActor`, so they catch UI-bound state regressions and async ordering issues rather than low-level thread races.

## Running Tests (CLI)

Use `-only-test-configuration` with the shared test plan:

```bash
xcodebuild test -project MacAmpApp.xcodeproj -scheme MacAmpApp -destination 'platform=macOS' -testPlan MacAmpApp -only-test-configuration Concurrency -derivedDataPath build/DerivedDataTests
```

Swap `Concurrency` for `Core` or `All` as needed.

## Adding or Updating Concurrency Tests

1. Add the test file/class under `Tests/MacAmpTests`.
2. Add the test class to the `Concurrency` configuration in `MacAmpApp.xctestplan` (or via Xcode: Edit Scheme → Test → Test Plans).
3. Keep `@MainActor` on tests that touch UI-bound state or SwiftUI models.

## References

- `docs/README.md` → Test Plan Quick Reference
- `docs/IMPLEMENTATION_PATTERNS.md` → §7 Testing Patterns
- `docs/MACAMP_ARCHITECTURE_GUIDE.md` → §12 Testing Strategies
