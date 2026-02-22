# Cross-Task State: Execution Coordination

> **Purpose:** Single source of truth for cross-task execution status, wave progress, and coordination decisions.
> **Date:** 2026-02-21
> **Updated:** 2026-02-21 (post-Oracle verification — all findings applied)

### Quick Reference

| Metric | Value |
|--------|-------|
| Tasks | 6 (T1-T6) |
| Plans complete | 6 of 6 |
| Blocking actions | None — all resolved |
| Waves | 3 |
| Branches | 6 |
| PRs | 5 (Wave 1: 3, Wave 2: 2; Wave 3 PR count TBD) |
| Current wave | Not started (approved, ready to launch) |

---

## Current Phase: ALL PRE-FLIGHT COMPLETE — READY TO LAUNCH

All 6 tasks have completed research and planning. All pre-flight items resolved. Awaiting worktree creation and Claude instance launch.

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
| T1 | `audioplayer-decomposition` | Plan complete (Ph1-3) | Wave 1 — ready | None |
| T2 | `playlistwindow-layer-decomposition` | Plan complete | Wave 1 — ready | None |
| T3 | `mainwindow-layer-decomposition` | Plan complete | Wave 2b — blocked on T5 Ph1 | T5 Phase 1 must merge first |
| T4 | `lock-free-ring-buffer` | Plan complete | Wave 1 — ready | None |
| T5 | `internet-streaming-volume-control` | Plan complete | Wave 2a (Ph1), Wave 3 (Ph2) | Ph1: needs T1 merge preferred; Ph2: needs T4 merge |
| T6 | `swift-testing-modernization` | Plan complete | Wave 1 — ready | None (swift-tools-version: 6.2) |

---

## Wave Execution Status

### Wave 1: Parallel Refactoring (3 worktrees)

| Worktree | Task(s) | Branch | Status | Claude Instance |
|----------|---------|--------|--------|----------------|
| A | T1 Phases 1-3 (AudioPlayer decomp) | `refactor/audioplayer-decomposition` | Not started | Instance 1 |
| B | T2 (PlaylistWindow decomp) | `refactor/playlistwindow-decomposition` | Not started | Instance 2 |
| C | T4 + T6 (Ring buffer + Swift Testing) | `infra/ring-buffer-and-testing` | Not started | Instance 3 |

**Merge order:** Sequential (T1 first, T4+T6 second, T2 third) — required for clean `project.pbxproj` resolution. See research.md Section 7.

**Pre-flight:** All items complete. T4 plan.md written. T6 swift-tools-version decided: **6.2**.

### Wave 2: Sequential Feature + Refactoring

| Step | Task | Branch | Status | Depends On |
|------|------|--------|--------|-----------|
| 2a | T5 Phase 1 (Volume routing) | `feature/stream-volume-control` | Not started | Wave 1 merges (T1 especially) |
| 2b | T3 (MainWindow decomp) | `refactor/mainwindow-decomposition` | Not started | T5 Phase 1 merge |

**Merge strategy:** Two separate PRs for traceability and revertability. T5 Ph1 merges first; T3 merges after verification that T5 Ph1 is not regressed.

### Wave 3: Advanced Audio Pipeline

| Step | Task | Branch | Status | Depends On |
|------|------|--------|--------|-----------|
| 3a | T5 Phase 2 (Loopback Bridge) | `feature/stream-loopback-bridge` | Not started | T4 merge + T5 Ph1 merge |
| 3b | T1 Phase 4 (optional) | Combine with T5 Ph2 or defer | Not started | T1 Ph1-3 merge + T5 Ph2 |

---

## Key Decisions

### D1: T5 Phase 1 before T3

**Decision:** internet-streaming-volume-control Phase 1 completes BEFORE mainwindow-layer-decomposition begins.

**Rationale:** Trade-off analysis (see research.md Section 5). T5 Phase 1 modifies a small number of symbol bindings in WinampMainWindow.swift (`buildVolumeSlider`, `audioPlayer.volume/balance` bindings). T3 restructures the entire file into child views. The plan-stability benefit of doing T5 first outweighs the critical-path cost. Alternative (T3 first) was considered and documented but rejected.

### D2: T4 + T6 combined worktree

**Decision:** Lock-free ring buffer and Swift Testing modernization share a worktree and branch.

**Rationale:** Both modify Package.swift (T4 adds swift-atomics dependency, T6 bumps tools-version). Combining avoids merge conflicts. Trade-off: couples two unrelated risk domains. Mitigated by internal sequencing (T6 Ph1 -> T4 -> T6 Ph2-6).

**Alternative considered:** Tiny shared prep PR for Package.swift, then separate branches. Rejected — adds process overhead for minimal gain.

### D3: T1 Phase 4 deferred

**Decision:** AudioPlayer engine transport extraction (Phase 4, medium-high risk) is deferred until after T5 Phase 2 or combined with it.

**Rationale:** Both T1 Phase 4 and T5 Phase 2 restructure AudioPlayer's engine internals. Doing Phase 4 first would invalidate Phase 2's plan. Doing Phase 2 first makes Phase 4's extraction scope clearer.

### D4: Sequential pbxproj merge order

**Decision:** Wave 1 worktrees merge in order: T1 (smallest) -> T4+T6 (medium) -> T2 (largest).

**Rationale:** All file-creating tasks modify `project.pbxproj` (explicit file references, 1,017-line file). Sequential merge with smallest-first minimizes conflict surface at each step. Conflicts are mechanical (file reference additions), not semantic.

### D5: Separate PRs for Wave 2

**Decision:** T5 Phase 1 and T3 are separate PRs, not combined.

**Rationale:** T3 is a massive structural refactor. T5 Ph1 is a feature change. Combining them into one PR makes reversion difficult if T3 introduces regressions. Separate PRs preserve revertability and make review tractable.

### D6: T4+T6 as single PR

**Decision:** T4 and T6 ship as a single PR from the combined branch.

**Rationale:** Both are infrastructure changes (no production behavior change). Package.swift changes are interdependent. Single PR reduces review overhead and merge complexity.

---

## Resolved Questions (from initial planning)

| # | Question | Resolution |
|---|----------|------------|
| 1 | Should T4+T6 be single or separate PRs? | **Single PR** (D6) — infrastructure changes, shared Package.swift |
| 2 | Is T1 Phase 4 in scope? | **Deferred** (D3) — revisit after T5 Phase 2 |
| 3 | Wave 2: one or two Claude instances? | **One instance, two sequential PRs** (D5) — same instance carries context |
| 4 | swift-tools-version 6.0 or 6.2? | **6.2** — matches installed toolchain (6.2.4) |

---

## Artifact Inventory

| File | Status |
|------|--------|
| `_context/research.md` | Complete (verified, corrections applied) |
| `_context/plan.md` | Complete (verified, corrections applied) |
| `_context/state.md` | Active (this file, verified) |
