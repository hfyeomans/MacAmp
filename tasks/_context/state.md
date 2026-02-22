# Cross-Task State: Execution Coordination

> **Purpose:** Single source of truth for cross-task execution status, wave progress, and coordination decisions.
> **Date:** 2026-02-21
> **Updated:** 2026-02-22 (Wave 1 complete, code reviews done, fixes applied)

### Quick Reference

| Metric | Value |
|--------|-------|
| Tasks | 6 (T1-T6) |
| Plans complete | 6 of 6 |
| Blocking actions | None — all resolved |
| Waves | 3 |
| Branches | 6 |
| PRs | 5 (Wave 1: 3, Wave 2: 2; Wave 3 PR count TBD) |
| Current wave | Wave 2a IN PROGRESS (T5 Phase 1 complete, T3 next) |

---

## Current Phase: WAVE 2a — T5 Phase 1 COMPLETE

T5 Phase 1 (stream volume routing + capability flags) implemented and Oracle-reviewed. Awaiting PR merge before T3 (mainwindow decomposition) can begin.

---

## Completed Prerequisites

| Prerequisite | Resolved In | Impact |
|-------------|-------------|--------|
| N1-N6 internet radio fixes | PR #49 (merged 2026-02-21) | Unblocks T5 Phase 1 |
| VisualizerPipeline SPSC refactor | PR #48 (merged 2026-02-14) | Provides template for T4 ring buffer; unblocks T5 Phase 2 |

---

## Task Status Overview

| ID | Task | Internal Status | Cross-Task Status | Blocker |
|----|------|----------------|-------------------|---------|
| T1 | `audioplayer-decomposition` | **Ph1-3 COMPLETE**, Ph4 deferred | Wave 1 — done, awaiting PR | swiftlint suppressions remain (945 lines, needs Ph4) |
| T2 | `playlistwindow-layer-decomposition` | **COMPLETE** | Wave 1 — done, awaiting PR | Manual testing items deferred |
| T3 | `mainwindow-layer-decomposition` | Plan complete | Wave 2b — blocked on T5 Ph1 | T5 Phase 1 must merge first |
| T4 | `lock-free-ring-buffer` | **COMPLETE** (benchmarks deferred) | Wave 1 — done, awaiting PR | None |
| T5 | `internet-streaming-volume-control` | **Ph1 COMPLETE**, Ph2 deferred | Wave 2a — done, awaiting PR | Ph2: needs T5 Ph1 merge (Wave 3) |
| T6 | `swift-testing-modernization` | **COMPLETE** (deferrals noted) | Wave 1 — done, awaiting PR | None |

---

## Wave Execution Status

### Wave 1: Parallel Refactoring (3 worktrees) — COMPLETE

| Worktree | Task(s) | Branch | Status | Commits | Code Review |
|----------|---------|--------|--------|---------|-------------|
| A | T1 Phases 1-3 | `worktree-audioplayer-decomp` | **COMPLETE** | 5 (3 phases + 2 Oracle fixes) | 2 issues fixed |
| B | T2 | `worktree-playlist-decomp` | **COMPLETE** | 7 (3 phases + Oracle fixes + docs) | Clean |
| C | T4 + T6 | `worktree-infra-ring-testing` | **COMPLETE** | 6 (Package + ring buffer + testing migration + fixes) | 4 issues fixed |

**Merge order:** Sequential (A first, C second, B third) — for clean `project.pbxproj` resolution.

### Wave 2: Sequential Feature + Refactoring — IN PROGRESS

| Step | Task | Branch | Status | Depends On |
|------|------|--------|--------|-----------|
| 2a | T5 Phase 1 (Volume routing) | `feature/stream-volume-control` | **COMPLETE** (2 commits, Oracle reviewed) | Wave 1 merges (done) |
| 2b | T3 (MainWindow decomp) | `refactor/mainwindow-decomposition` | Not started | T5 Phase 1 merge |

**Merge strategy:** Two separate PRs. T5 Ph1 merges first; T3 merges after verification.

### Wave 3: Advanced Audio Pipeline — NOT STARTED

| Step | Task | Branch | Status | Depends On |
|------|------|--------|--------|-----------|
| 3a | T5 Phase 2 (Loopback Bridge) | `feature/stream-loopback-bridge` | Not started | T4 merge + T5 Ph1 merge |
| 3b | T1 Phase 4 (engine transport) | After T5 Ph2 | Not started | T5 Ph2 complete |

---

## Key Decisions

### D1: T5 Phase 1 before T3

**Decision:** internet-streaming-volume-control Phase 1 completes BEFORE mainwindow-layer-decomposition begins.

**Rationale:** Trade-off analysis (see research.md Section 5). T5 Phase 1 modifies a small number of symbol bindings in WinampMainWindow.swift (`buildVolumeSlider`, `audioPlayer.volume/balance` bindings). T3 restructures the entire file into child views. The plan-stability benefit of doing T5 first outweighs the critical-path cost. Alternative (T3 first) was considered and documented but rejected.

### D2: T4 + T6 combined worktree

**Decision:** Lock-free ring buffer and Swift Testing modernization share a worktree and branch.

**Rationale:** Both modify Package.swift (T4 adds swift-atomics dependency, T6 bumps tools-version). Combining avoids merge conflicts. Trade-off: couples two unrelated risk domains. Mitigated by internal sequencing (T6 Ph1 -> T4 -> T6 Ph2-6).

### D3: T1 Phase 4 deferred — swiftlint suppressions remain

**Decision:** AudioPlayer engine transport extraction (Phase 4, medium-high risk) is deferred until after T5 Phase 2 or combined with it.

**Rationale:** The seek state machine has three interlocking guards (`currentSeekID`, `seekGuardActive`, `isHandlingCompletion`) that were extensively debugged across multiple PRs. The transport methods (`play`/`pause`/`stop`/`seek`/`scheduleFrom`) share tight mutable state coupling, and completion handlers use seekID matching to ignore stale completions. Multiple timing-sensitive `Task.sleep` delays coordinate guard clearing.

**Impact:** AudioPlayer.swift remains at 945 lines (above 600-line warning, below 1,200-line error). Two swiftlint inline suppressions (`file_length` + `type_body_length`) cannot be removed until Phase 4. Phase 4 should only be pursued after unit tests for the seek state machine are added first.

**Does NOT block Waves 2-3:**
- Wave 2 (T5 Ph1): Modifies `volume` didSet and coordinator routing — does not touch engine transport
- Wave 2 (T3): Restructures WinampMainWindow — unrelated to AudioPlayer
- Wave 3 (T5 Ph2): Adds `streamSourceNode` and engine graph switching. Phase 4 would extract the same internals, so Phase 4 must come AFTER T5 Ph2 to get clearer extraction boundaries

### D4: Sequential pbxproj merge order

**Decision:** Wave 1 worktrees merge in order: T1 (smallest) -> T4+T6 (medium) -> T2 (largest).

**Rationale:** All file-creating tasks modify `project.pbxproj` (explicit file references, 1,017-line file). Sequential merge with smallest-first minimizes conflict surface at each step.

### D5: Separate PRs for Wave 2

**Decision:** T5 Phase 1 and T3 are separate PRs, not combined.

**Rationale:** T3 is a massive structural refactor. T5 Ph1 is a feature change. Separate PRs preserve revertability.

### D6: T4+T6 as single PR

**Decision:** T4 and T6 ship as a single PR from the combined branch.

**Rationale:** Both are infrastructure changes. Package.swift changes are interdependent.

---

## Deferred Items Inventory

### From Wave 1 — Future Tasks Needed

| Item | Source | Size | Priority | Blocks Future Waves? |
|------|--------|------|----------|---------------------|
| T1 Phase 4: Engine transport extraction | audioplayer-decomposition | Large | Medium | No — schedule after T5 Ph2 |
| PlaylistWindowActions singleton rearchitecture | playlist-decomp depreciated.md | Large | Low | No |
| Manual selection state sync fix | playlist-decomp depreciated.md | Small | Low | No — blocked by singleton fix |
| `async-test-determinism` (Task.sleep removal) | swift-testing todo.md | Medium | Low | No |
| `spm-multiple-producers-fix` | infra-ring-testing todo.md | Small-Medium | Medium | Blocks `swift test` via CLI |
| Ring buffer performance benchmarks | lock-free-ring-buffer todo.md | Small | Low | No |
| Ring buffer AudioBufferList overload tests | lock-free-ring-buffer todo.md | Small | Low | No — add during T5 Ph2 |
| DockingController debounce `try?` fix | lock-free-ring-buffer deprecated.md | Small | Low | No |

### Manual Testing (Pre-Merge Recommended)

| Item | Source |
|------|--------|
| Playlist: visual rendering, track selection, menus, shade, resize, scroll, keyboard | playlist-decomp todo.md 4.4-4.11 |

### Doc Updates Needed (Post-Merge)

| Doc | Update |
|-----|--------|
| `docs/MACAMP_ARCHITECTURE_GUIDE.md` | Add EqualizerController.swift + LockFreeRingBuffer.swift to Audio/ listing; note facade pattern |
| `docs/IMPLEMENTATION_PATTERNS.md` | Document cross-file SwiftUI extension anti-pattern + correct child-view pattern |
| `docs/PLAYLIST_WINDOW.md` | Update for new PlaylistWindow/ subdirectory |
| `docs/README.md` | Update test framework (XCTest → Swift Testing, swift-tools-version 6.2) |
| `tasks/_context/tasks_index.md` | Mark T1 Ph1-3, T2, T4, T6 as complete |

---

## Resolved Questions

| # | Question | Resolution |
|---|----------|------------|
| 1 | Should T4+T6 be single or separate PRs? | **Single PR** (D6) |
| 2 | Is T1 Phase 4 in scope? | **Deferred** (D3) — after T5 Ph2; swiftlint suppressions remain at 945 lines |
| 3 | Wave 2: one or two Claude instances? | **One instance, two sequential PRs** (D5) |
| 4 | swift-tools-version 6.0 or 6.2? | **6.2** — matches installed toolchain (6.2.4) |

---

## Artifact Inventory

| File | Status |
|------|--------|
| `_context/research.md` | Complete (verified, corrections applied) |
| `_context/plan.md` | Complete (verified, corrections applied) |
| `_context/state.md` | Active (this file — updated 2026-02-22) |
