# Research

## Sources
- docs/README.md (Test Plan Quick Reference)
- docs/IMPLEMENTATION_PATTERNS.md §7 Testing Patterns
- docs/MACAMP_ARCHITECTURE_GUIDE.md §12 Testing Strategies
- MacAmpApp.xcodeproj/xcshareddata/xctestplans/MacAmpApp.xctestplan
- Tests/MacAmpTests (test coverage and grouping)

## Notes
- Shared test plan `MacAmpApp.xctestplan` defines Core, Concurrency, and All configurations.
- Concurrency configuration currently selects:
  - AudioPlayerStateTests
  - DockingControllerTests
  - PlaylistNavigationTests
  - SkinManagerTests
- CLI uses `-only-test-configuration` with `xcodebuild test`.
