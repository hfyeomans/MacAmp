# Plan

## Goal
Enable `xcodebuild test` for the `MacAmpApp` scheme by wiring existing Swift Package tests into the Xcode project and defining clear test actions (grouped runs) that can be invoked from CI or locally.

## Proposed Test Actions (for MacAmpApp scheme)
1. **Core Unit Tests (deterministic)**
   - AppSettingsTests
   - EQCodecTests
   - SpriteResolverTests
   - Purpose: fast, side‑effect‑light validation of pure logic and parsing.

2. **Concurrency/Async Unit Tests**
   - AudioPlayerStateTests
   - DockingControllerTests
   - PlaylistNavigationTests
   - SkinManagerTests
   - Purpose: exercises Task-based flows, debounce persistence, async loading.

3. **Full Suite**
   - All tests in `MacAmpTests`.
   - Purpose: pre‑release/CI gate.

## Implementation Steps
1. **Add a unit test target** to `MacAmpApp.xcodeproj` named `MacAmpTests`.
   - Sources: `Tests/MacAmpTests/*.swift`.
   - Dependencies: link against `MacAmp` target (`@testable import MacAmp`).
   - No host application required (pure unit tests).

2. **Create an XCTest plan** (optional but recommended) `MacAmpApp.xctestplan`.
   - Configurations:
     - `Core` (AppSettingsTests, EQCodecTests, SpriteResolverTests)
     - `Concurrency` (AudioPlayerStateTests, DockingControllerTests, PlaylistNavigationTests, SkinManagerTests)
     - `All` (entire MacAmpTests bundle)

3. **Update scheme** `MacAmpApp` to include Test action.
   - Use the new test plan and enable the desired configuration.

## Example Commands After Wiring
- Core tests:
  - `xcodebuild test -project MacAmpApp.xcodeproj -scheme MacAmpApp -destination 'platform=macOS' -testPlan MacAmpApp -testPlanConfig Core`
- Concurrency tests:
  - `xcodebuild test -project MacAmpApp.xcodeproj -scheme MacAmpApp -destination 'platform=macOS' -testPlan MacAmpApp -testPlanConfig Concurrency`
- Full suite:
  - `xcodebuild test -project MacAmpApp.xcodeproj -scheme MacAmpApp -destination 'platform=macOS' -testPlan MacAmpApp -testPlanConfig All`

## Notes
- Tests reference repo file paths (e.g., `MacAmpApp/Skins/Winamp.wsz`), so the test runner should run from the repo root and keep those files present.
- Once the test target exists, the scheme’s Test action will no longer fail due to “not configured for test action.”
