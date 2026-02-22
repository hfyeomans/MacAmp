# Cross-Task Execution Plan

> **Purpose:** Master plan coordinating 6 MacAmp tasks across waves, worktrees, and Claude instances.
> Answers: what order, what's parallel, what blocks what, and what invalidates what.
> **Date:** 2026-02-21
> **Validated by:** Oracle (gpt-5.3-codex, xhigh reasoning) x2 — initial analysis + verification pass (corrections applied)

### Quick Reference

| Metric | Value |
|--------|-------|
| Tasks | 6 (T1-T6) |
| Plans complete | 6 of 6 |
| Pending before start | None — all resolved |
| Waves | 3 |
| Branches | 6 |
| PRs | 5 (Wave 1: 3, Wave 2: 2, Wave 3: TBD) |
| Max parallel worktrees | 3 (Wave 1) |
| Semantic file conflicts | T1+T5 (AudioPlayer), T3+T5 (MainWindow), T4+T6 (Package) |
| pbxproj strategy | Sequential merge: A -> C -> B |

---

## Executive Summary

Six planned tasks decompose into **3 execution waves**. Wave 1 runs 3 worktrees in parallel with a defined sequential merge order for `project.pbxproj` conflict resolution. Wave 2 is sequential (semantic file conflicts on WinampMainWindow.swift). Wave 3 depends on Wave 1's ring buffer output.

```
Wave 1 (PARALLEL — 3 worktrees, 3 Claude instances)
├── Worktree A: T1 Phases 1-3 (AudioPlayer decomposition)
├── Worktree B: T2 (PlaylistWindow decomposition)
└── Worktree C: T4 + T6 (Ring buffer + Swift Testing)

    ──── sequential merge: A first, then C, then B ────
    ──── pbxproj conflicts resolved at each merge step ────

Wave 2 (SEQUENTIAL — 1 Claude instance, 2 separate PRs)
├── PR 1: T5 Phase 1 (Stream volume routing)
└── PR 2: T3 (MainWindow decomposition)

    ──── merge each PR sequentially ────

Wave 3 (SEQUENTIAL — 1 Claude instance)
└── T5 Phase 2 (Loopback Bridge)
    └── Optional: T1 Phase 4 (Engine transport extraction)
```

**Total: 6 branches across 3 waves, 5 PRs**

---

## Prerequisites (All Resolved)

| Prerequisite | Required By | Status | Resolved In |
|-------------|-------------|--------|-------------|
| N1-N6 internet radio fixes | T5 Phase 1 | **DONE** | PR #49 |
| VisualizerPipeline SPSC refactor | T5 Phase 2 | **DONE** | PR #48 |
| T4 plan.md written | T4 implementation | **DONE** | Written 2026-02-21 from existing research |
| T6 swift-tools-version decision | T6 Phase 1 | **DONE** | User decided: **6.2** |

---

## Wave 1: Parallel Infrastructure & Refactoring

### Timing: Immediate — all pre-flight items resolved

### Pre-Flight Checklist

- [x] User approves cross-task plan
- [x] T4 plan.md written
- [x] T6 swift-tools-version decided: **6.2**
- [ ] 3 git worktrees created from `main` HEAD
- [ ] 3 Claude instances launched (one per worktree)

---

### Worktree A: AudioPlayer Decomposition (T1 Phases 1-3)

**Branch:** `refactor/audioplayer-decomposition`
**Claude Instance:** Dedicated instance in separate terminal
**Estimated effort:** Medium (3 phases, ~200 lines moved, 1 new file)
**pbxproj impact:** 1 new file (EqualizerController.swift) — minimal

| Phase | What | Files | Risk |
|-------|------|-------|------|
| 1 | Extract EqualizerController | AudioPlayer.swift, new EqualizerController.swift | Low |
| 2 | Consolidate visualizer forwarding | AudioPlayer.swift, VisualizerPipeline.swift | Low |
| 3 | Clean up FourCC extension | AudioPlayer.swift | Zero |

**Phase 4 explicitly excluded** — deferred to Wave 3 or later (architectural conflict with T5 Phase 2).

**Verification:**
- Build + run with Thread Sanitizer
- All EQ functions work (10 bands, preamp, presets, auto-EQ)
- Visualizer renders correctly
- swiftlint suppressions reduced (target: 0-1 remaining)

---

### Worktree B: PlaylistWindow Decomposition (T2)

**Branch:** `refactor/playlistwindow-decomposition`
**Claude Instance:** Dedicated instance in separate terminal
**Estimated effort:** Medium (4 phases, 6-8 new files, 2 deleted)
**pbxproj impact:** 6-8 new files, 2 deleted — significant. Merges last in Wave 1.

| Phase | What | Files | Risk |
|-------|------|-------|------|
| 1 | Create PlaylistWindowInteractionState + PlaylistMenuPresenter | New files | Low |
| 2 | Extract 5-6 child views | New files | Low |
| 3 | Rewrite root, restore private access, delete extension | WinampPlaylistWindow.swift, DELETE +Menus.swift | Medium |
| 4 | Verification | N/A | N/A |

**Verification:**
- Build + run with Thread Sanitizer
- Visual comparison: playlist renders identically with 3+ skins
- Track selection, double-click play, menu operations, shade mode, resize, scroll
- Zero lint violations without suppressions

---

### Worktree C: Ring Buffer + Swift Testing (T4 + T6)

**Branch:** `infra/ring-buffer-and-testing`
**Claude Instance:** Dedicated instance in separate terminal
**Estimated effort:** Medium-High
**pbxproj impact:** 1-3 new files (ring buffer + test files)

**Why combined:** Both modify Package.swift — T4 adds swift-atomics dependency, T6 bumps swift-tools-version. Combining avoids Package.swift merge conflicts.

#### Internal Sequencing (within worktree)

```
Step 1: T6 Phase 1 — Bump Package.swift to swift-tools-version 6.0 (or 6.2)
Step 2: T4 — Add swift-atomics to Package.swift, implement LockFreeRingBuffer + tests
Step 3: T6 Phases 2-6 — Migrate test assertions, suites, parameterization, async, tags
```

This order ensures all Package.swift changes happen coherently.

#### T4: Lock-Free Ring Buffer

| Step | What | Files |
|------|------|-------|
| 1 | Write plan.md (currently placeholder) | tasks/lock-free-ring-buffer/plan.md |
| 2 | Add swift-atomics to Package.swift | Package.swift |
| 3 | Implement LockFreeRingBuffer | New: MacAmpApp/Audio/LockFreeRingBuffer.swift |
| 4 | Unit tests (write/read, wrap-around, underrun, overrun, generation ID) | New test file |
| 5 | Concurrent stress tests | New test file |
| 6 | Performance benchmarks (<1us latency) | New test file |

#### T6: Swift Testing Modernization

| Phase | What | Files |
|-------|------|-------|
| 1 | Bump Package.swift to 6.0+ | Package.swift |
| 2 | Assertion migration (XCTAssert -> #expect/#require) | All 9 test files |
| 3 | Suite modernization (XCTestCase -> struct) | All 9 test files |
| 4 | Parameterization | AudioPlayerStateTests, SpriteResolverTests, WindowDockingGeometryTests |
| 5 | Async fixes | DockingControllerTests, SkinManagerTests |
| 6 | Tags & traits | All test files + new tag extension |

**Verification:**
- `swift build` and `swift test` both pass
- Ring buffer: all unit tests, stress tests, benchmarks pass
- All 23+ tests pass with new Swift Testing assertions
- Build with Thread Sanitizer succeeds

---

## Wave 1 Merge

### Sequential Merge Order (required for pbxproj)

```
1. Merge Worktree A (T1) — 1 new file, smallest pbxproj change
   └── Full build + test on main

2. Merge Worktree C (T4+T6) — Package.swift + 1-3 new files
   └── Resolve pbxproj conflicts (mechanical)
   └── Full build + test on main

3. Merge Worktree B (T2) — 6-8 new files, 2 deleted
   └── Resolve pbxproj conflicts (mechanical)
   └── Full build + test on main
```

**Post-merge verification:** Full build + `swift test` + Thread Sanitizer on main after all 3 merges.

---

## Wave 2: Sequential Feature + Refactoring

### Timing: After all Wave 1 merges complete

### Step 2a: Internet Streaming Volume Control Phase 1 (T5 Ph1)

**Branch:** `feature/stream-volume-control`
**PR:** Separate PR (for revertability)
**Claude Instance:** Can reuse any Wave 1 instance
**Estimated effort:** Low (~100 lines changed across 5 files)
**pbxproj impact:** None (no new files)

| Step | What | Files |
|------|------|-------|
| 1.1 | Add volume/balance properties to StreamPlayer | StreamPlayer.swift |
| 1.2-1.3 | Route volume/balance through PlaybackCoordinator | PlaybackCoordinator.swift |
| 1.4 | Add capability flags (supportsEQ, supportsBalance, supportsVisualizer) | PlaybackCoordinator.swift |
| 1.5 | Reroute volume slider binding through coordinator | WinampMainWindow.swift |
| 1.6 | Remove video volume from AudioPlayer.volume didSet | AudioPlayer.swift |
| 1.7 | Dim EQ UI during stream playback | WinampEqualizerWindow.swift |
| 1.8 | Dim balance slider + reroute binding | WinampMainWindow.swift |
| 1.9 | Apply persisted volume on stream start | StreamPlayer.swift |

**Note on AudioPlayer.swift post-T1 merge:** After T1 merge (Wave 1), EQ methods have moved to EqualizerController.swift. T5 Ph1 Step 1.6 modifies `AudioPlayer.volume` didSet, which remains in AudioPlayer.swift (not extracted by T1). Locate by symbol name (`var volume: Float` with `didSet`) — surrounding code will have changed due to T1's extractions.

**Verification:**
- Volume slider controls stream volume (immediate effect)
- Volume persists across stream/local switches
- EQ/balance dimmed during streams
- Local file playback unchanged (no regression)

---

### Step 2b: MainWindow Layer Decomposition (T3)

**Branch:** `refactor/mainwindow-decomposition`
**PR:** Separate PR (large structural refactor — isolated for clean review/revert)
**Claude Instance:** Same as Step 2a (carries context from T5 Ph1)
**Estimated effort:** Medium (4 phases, 8-10 new files)
**pbxproj impact:** 8-10 new files, 1 deleted — significant

| Phase | What | Files |
|-------|------|-------|
| 1 | Scaffolding (Layout, InteractionState, OptionsMenuPresenter) | 3 new files |
| 2 | Extract child views (Transport, TrackInfo, Indicators, Sliders, Full, Shade) | 6 new files |
| 3 | Rewrite root, restore private access, delete extension | WinampMainWindow.swift, DELETE +Helpers.swift |
| 4 | Verification | N/A |

**T5 Phase 1 integration notes:** T3 must account for T5 Phase 1's changes when extracting:
- Volume slider binding now routes through PlaybackCoordinator (T5 Step 1.5) — moves to `MainWindowSlidersLayer`
- Balance slider binding routes through coordinator + capability check (T5 Step 1.8) — moves to `MainWindowSlidersLayer`
- EQ/playlist toggle buttons and capability-aware UI — moves to appropriate child views

**Verification:**
- Build + run with Thread Sanitizer
- Visual comparison: main window renders identically with 3+ skins in full and shade mode
- All transport, slider, menu, and indicator functions work
- Volume/balance still route through coordinator (T5 Phase 1 not regressed)
- Stream capability flags still correctly dim controls
- Zero lint violations

---

## Wave 2 Merge

```
1. Merge T5 Ph1 PR (`feature/stream-volume-control`)
   └── Full build + test on main
   └── Manual test: stream volume works

2. Merge T3 PR (`refactor/mainwindow-decomposition`)
   └── Full build + test on main
   └── Verify T5 Ph1 not regressed (stream volume still works)
```

---

## Wave 3: Advanced Audio Pipeline

### Timing: After Wave 2 merge (T4 ring buffer + T5 Ph1 both available)

### T5 Phase 2: Loopback Bridge

**Branch:** `feature/stream-loopback-bridge`
**Claude Instance:** Dedicated instance
**Estimated effort:** High (new MTAudioProcessingTap, engine graph switching, real-time thread safety)
**pbxproj impact:** Minimal (ring buffer already added in T4)

| Step | What | Files |
|------|------|-------|
| 2.1 | Integrate LockFreeRingBuffer | Import from T4 (already in project) |
| 2.2 | Implement MTAudioProcessingTap on StreamPlayer | StreamPlayer.swift |
| 2.3 | Create AVAudioSourceNode for stream injection | AudioPlayer.swift |
| 2.4 | Wire stream source node into engine graph | AudioPlayer.swift |
| 2.5 | Update capability flags (all true with bridge) | PlaybackCoordinator.swift |
| 2.6 | Update VisualizerView playback state check | VisualizerView.swift |
| 2.7 | Handle ABR format changes | StreamPlayer.swift |

**Prerequisites (all met by this point):**
- T4 (ring buffer) merged and tested in Wave 1
- T1 Phases 1-3 merged (cleaner AudioPlayer facade) in Wave 1
- T5 Phase 1 merged (capability flags infrastructure) in Wave 2

**Optional: T1 Phase 4 (Engine Transport Extraction)**
If desired, T1 Phase 4 can be done AFTER T5 Phase 2 or combined with it. Both touch engine internals — combining gives clearer extraction boundaries since the engine graph now has two source paths (playerNode + streamSourceNode).

---

## Complete Dependency Graph

```
                    ┌──────────────────────────────────────────┐
                    │              WAVE 1 (parallel)            │
                    │                                          │
                    │  T1 Ph1-3 ─── Worktree A                │
                    │  T2 ───────── Worktree B                │
                    │  T4 + T6 ──── Worktree C                │
                    │                                          │
                    └──────────────┬───────────────────────────┘
                                   │
                    sequential merge (A → C → B)
                    pbxproj resolved at each step
                                   │
                    ┌──────────────▼───────────────────────────┐
                    │           WAVE 2 (sequential)            │
                    │                                          │
                    │  T5 Ph1 ──── PR #1 (volume routing)     │
                    │      │                                   │
                    │      ▼                                   │
                    │  T3 ──────── PR #2 (mainwindow decomp)  │
                    │                                          │
                    └──────────────┬───────────────────────────┘
                                   │
                    ┌──────────────▼───────────────────────────┐
                    │           WAVE 3 (sequential)            │
                    │                                          │
                    │  T5 Ph2 ──── Loopback Bridge            │
                    │      │                                   │
                    │      ▼                                   │
                    │  T1 Ph4 ──── (optional, deferred)       │
                    │                                          │
                    └──────────────────────────────────────────┘
```

---

## What Interferes, Blocks, or Overlaps

| Relationship | Type | Detail |
|-------------|------|--------|
| T4 -> T5 Phase 2 | **Hard dependency** | Ring buffer is prerequisite |
| T5 Ph1 -> T5 Ph2 | **Hard dependency** | Capability flags needed |
| N1-N6 -> T5 Ph1 | **Hard dependency (resolved)** | PR #49 merged |
| T1 + T5 | **File conflict** | Both modify AudioPlayer.swift — T1 first |
| T3 + T5 Ph1 | **File conflict** | Both modify WinampMainWindow.swift — T5 Ph1 first |
| T4 + T6 | **File conflict** | Both modify Package.swift — combined in one branch |
| T1 Ph4 + T5 Ph2 | **Architectural conflict** | Both restructure engine internals — Ph4 deferred |
| T1, T2, T3, T4 | **pbxproj conflict** | All create files — sequential merge with mechanical resolution |

## What Makes Plans Obsolete If Done in Wrong Order

| If this runs first | This plan becomes stale | Reason | Severity |
|-------------------|------------------------|--------|----------|
| T3 (MainWindow decomp) | T5 Ph1 plan | Volume/balance binding locations move to child view files | HIGH — plan update required |
| T5 Ph2 (Loopback Bridge) | T1 Ph4 plan | Engine graph has new source routing Ph4 doesn't account for | MEDIUM — Ph4 already deferred |
| T5 (any phase) | T1 Ph1 plan symbol locations | T5 modifies `AudioPlayer.volume` didSet; surrounding code shifts | LOW — symbols findable by name |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| pbxproj merge conflicts in Wave 1 | **HIGH** | **LOW** | Sequential merge order; conflicts are mechanical |
| T5 Ph1 plan symbol locations shift after T1 | MEDIUM | LOW | T1 doesn't change AudioPlayer public API; locate by symbol name (`var volume`, `didSet`) |
| T3 accidentally regresses T5 Ph1 changes | MEDIUM | MEDIUM | Separate PRs; T3 plan notes coordinator bindings; verify stream volume after T3 |
| T4 plan writing delays Wave 1 start | MEDIUM | MEDIUM | Write T4 plan before launching worktrees; can be done quickly from existing research |
| T1 Ph4 invalidated by T5 Ph2 | HIGH | LOW | Ph4 explicitly deferred; decision after Ph2 |
| Package.resolved conflicts | LOW | LOW | Combined T4+T6 branch handles all SPM changes |
| Ring buffer (T4) takes longer than expected | MEDIUM | HIGH | T5 Ph2 blocked; all other tasks unaffected |
| T6 swift-tools-version bump surfaces concurrency violations | MEDIUM | MEDIUM | Fix violations in T6 branch before merging; doesn't affect other worktrees |

---

## Checklist for Starting Execution

- [x] User approves this cross-task plan
- [x] User decides swift-tools-version: **6.2**
- [x] T4 plan.md written from existing research.md
- [ ] Create 3 git worktrees from `main` HEAD
- [ ] Launch 3 Claude instances (one per worktree)
- [ ] Each instance reads its task's plan.md and begins execution
- [ ] Track progress in individual task state.md files
- [ ] When all 3 complete: merge sequentially (A -> C -> B), resolve pbxproj at each step
