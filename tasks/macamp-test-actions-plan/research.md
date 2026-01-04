# Research

## Existing Tests (Swift Package)
- Tests live in `Tests/MacAmpTests` and import `@testable import MacAmp`.
- Test files:
  - AppSettingsTests.swift (filesystem/temp directory behaviors)
  - AudioPlayerStateTests.swift (state transitions)
  - DockingControllerTests.swift (debounced persistence)
  - EQCodecTests.swift (EQ codec parsing/clamping)
  - PlaylistNavigationTests.swift (track advance logic)
  - SkinManagerTests.swift (skin load success/failure)
  - SpriteResolverTests.swift (sprite resolution edge cases)

## Project/Scheme State
- `MacAmpApp.xcodeproj` contains the `MacAmp` app target but no configured Test action on scheme `MacAmpApp`.
- `xcodebuild test` fails because the scheme is not configured for testing.
- `xcodebuild build` succeeds with current scheme/targets.

## Constraints/Notes
- Tests reference repo-relative paths (e.g., `MacAmpApp/Skins/Winamp.wsz`) rather than bundle resources.
- Some tests are @MainActor and/or async; they rely on async XCTest support in macOS test runner.

## Implication
- To enable `xcodebuild test`, create a unit test target in the Xcode project using `Tests/MacAmpTests` and add it to the `MacAmpApp` scheme Test action (optionally via an `.xctestplan`).
