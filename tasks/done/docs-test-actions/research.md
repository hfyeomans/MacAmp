# Research

## Current Test Assets
- Tests live in `Tests/MacAmpTests` (AppSettingsTests, AudioPlayerStateTests, DockingControllerTests, EQCodecTests, PlaylistNavigationTests, SkinManagerTests, SpriteResolverTests).
- Added Xcode test target `MacAmpTests` and shared test plan `MacAmpApp.xctestplan` with Core/Concurrency/All configurations.
- Shared scheme `MacAmpApp.xcscheme` references the test plan.

## Documentation Locations To Update
- docs/README.md: master index should mention test plan entry points and commands.
- docs/IMPLEMENTATION_PATTERNS.md: Testing Patterns section should include Xcode test plan commands.
- docs/MACAMP_ARCHITECTURE_GUIDE.md: Testing Strategies section should reference MacAmpTests and test plan configurations.

## Test Commands (Xcode)
- Core: `xcodebuild test -project MacAmpApp.xcodeproj -scheme MacAmpApp -destination 'platform=macOS' -testPlan MacAmpApp -only-test-configuration Core`
- Concurrency: same with `-only-test-configuration Concurrency`
- All: same with `-only-test-configuration All`
