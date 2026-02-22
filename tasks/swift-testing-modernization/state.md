# State: Swift Testing Modernization

> **Purpose:** Track the current state of this task including what has been completed,
> what is in progress, and what is blocked.

---

## Current Status: COMPLETE (Phases 1-6, with deferrals noted)

### Completed
- [x] Full audit of all 8 test files (23 tests → now 40 with ring buffer tests)
- [x] Swift version landscape analysis (toolchain 6.2.4, Xcode 6.0, SPM 5.9)
- [x] Per-file migration mapping
- [x] Anti-pattern identification (5 cross-cutting issues)
- [x] Coverage gap analysis (~85 production files, ~15-20% covered)
- [x] 6-phase implementation plan written
- [x] Research documented in research.md
- [x] Plan documented in plan.md
- [x] Phase 1: Package.swift bumped to swift-tools-version 6.2
- [x] Phase 2: Assertion migration (XCTest → #expect/#require) — all 9 files
- [x] Phase 3: Suite modernization (XCTestCase → @Suite structs) — all 9 files
- [x] Phase 4: Parameterization (SpriteResolverTests, EQCodecTests)
- [x] Phase 5: Time limits (`.timeLimit(.minutes(1))` on async tests)
- [x] Phase 6: Tags & traits (TestTags.swift with 6 shared tags across 10 suites)
- [x] Pre-existing test failures fixed (DockingController + PlaylistNavigation)
- [x] TSan verification (serial, 40/40 tests pass)
- [x] Oracle end-to-end code review

### Commits

1. `3acf75e` — Package.swift bump to swift-tools-version 6.2 + swift-atomics
2. `033d0e1` — XCTest to Swift Testing migration (Phases 2+3)
3. `55cc422` — Phases 4-6: tags, parameterization, time limits, pbxproj, test plan, ring buffer hardening
4. `3bd5bec` — Fix two pre-existing test failures (DockingController + PlaylistNavigation)

### Test Plan Changes

- Simplified from 3 configurations (Core, Concurrency, All) to 1 (All)
- Removed stale `selectedTests` using XCTest identifiers that disabled all tests
- Disabled code coverage to reduce overhead
- Set `parallelizable: true` for Swift Testing discovery

### Tags Applied

| Tag | Suites |
|-----|--------|
| `.audio` | LockFreeRingBufferTests, AudioPlayerStateTests |
| `.concurrency` | LockFreeRingBufferConcurrencyTests |
| `.skin` | SkinManagerTests, SpriteResolverTests |
| `.window` | DockingControllerTests, WindowDockingGeometryTests, WindowFrameStoreTests |
| `.persistence` | DockingControllerTests, WindowFrameStoreTests |
| `.parsing` | EQCodecTests, PlaylistNavigationTests |

### Files Modified

- All 9 test files in `Tests/MacAmpTests/` migrated from XCTest to Swift Testing
- `Tests/MacAmpTests/TestTags.swift` — New shared tag definitions (6 tags)
- `MacAmpApp.xcodeproj/project.pbxproj` — File membership for new files + swift-atomics
- `MacAmpApp.xcodeproj/xcshareddata/xctestplans/MacAmpApp.xctestplan` — Simplified
- `MacAmpApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` — Updated

### Key Decisions Made

- Bumped to swift-tools-version 6.2 (not 6.0) per user preference
- Async fixes limited to `.timeLimit(.minutes(1))` — Swift Testing minimum granularity
- `Task.sleep` waits kept in 2 files (DockingController, SkinManager) — deterministic replacement deferred
- New test coverage (Phase 7) deferred to separate task
- `#expect` macro conflicts with swift-atomics `.load(ordering:)` — workaround: extract to local var
- PlaylistNavigationTests tagged `.parsing` (not `.audio`) for more accurate categorization
- EQCodecTests tagged `.parsing` only (dropped `.audio` — tests codec logic, not audio playback)
