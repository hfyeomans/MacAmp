# State: Swift Testing Modernization

> **Purpose:** Track the current state of this task including what has been completed,
> what is in progress, and what is blocked.

---

## Current Status: Phases 1-6 COMPLETE

### Completed
- [x] Full audit of all 8 test files (23 tests)
- [x] Swift version landscape analysis (toolchain 6.2.4, Xcode 6.0, SPM 5.9)
- [x] Per-file migration mapping
- [x] Anti-pattern identification (5 cross-cutting issues)
- [x] Coverage gap analysis (~85 production files, ~15-20% covered)
- [x] 6-phase implementation plan written
- [x] Research documented in research.md
- [x] Plan documented in plan.md
- [x] Phase 1: Package.swift bumped to swift-tools-version 6.2
- [x] Phase 2: Assertion migration (XCTest → #expect/#require)
- [x] Phase 3: Suite modernization (XCTestCase → @Suite structs)
- [x] Phase 4: Parameterization (SpriteResolverTests, EQCodecTests)
- [x] Phase 5: Async fixes (.timeLimit(.minutes(1)) for async tests)
- [x] Phase 6: Tags & traits (TestTags.swift with 6 shared tags)
- [x] TSan verification (serial, all ring buffer + unit tests pass)

### Commits

1. `3acf75e` — Package.swift bump to swift-tools-version 6.2 + swift-atomics
2. `033d0e1` — XCTest to Swift Testing migration (Phases 2+3)
3. Phase 4-6 commit (pending) — Tags, parameterization, time limits, pbxproj, test plan

### Test Plan Changes

- Simplified from 3 configurations (Core, Concurrency, All) to 1 (All)
- Removed stale `selectedTests` using XCTest identifiers
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

### Files Modified (Phases 2-6)

- All 9 test files in `Tests/MacAmpTests/` migrated
- `Tests/MacAmpTests/TestTags.swift` — New shared tag definitions
- `MacAmpApp.xcodeproj/project.pbxproj` — File membership for new files + swift-atomics package
- `MacAmpApp.xcodeproj/xcshareddata/xctestplans/MacAmpApp.xctestplan` — Simplified

### Pre-existing Test Failures (not caused by migration)

1. `DockingControllerTests/persistenceRoundtrip()` — Crash (pre-existing)
2. `PlaylistNavigationTests/previousTrackReturnsLocalWhenBackingUpFromStream()` — Assertion failure (pre-existing)

### Key Decisions Made

- Bumped to swift-tools-version 6.2 (not 6.0) per user preference
- Async fixes limited to `.timeLimit(.minutes(1))` (Swift Testing minimum granularity)
- New test coverage (Phase 7) deferred to separate task
- `#expect` macro conflicts with swift-atomics `.load(ordering:)` — workaround: extract to local variable
