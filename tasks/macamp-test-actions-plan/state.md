# State

- Added a MacAmpTests unit test target to `MacAmpApp.xcodeproj`.
- Wired `Tests/MacAmpTests/*.swift` into the new test target sources.
- Added `XCTest.framework` and test bundle product reference.
- Created shared scheme `MacAmpApp.xcscheme` with a Test action referencing a test plan.
- Added `MacAmpApp.xctestplan` with Core/Concurrency/All configurations.
- Updated SpriteResolverTests for Skin initializer signature.
- Test plan runs: Core/Concurrency/All succeeded via `xcodebuild test` using `-only-test-configuration`.
