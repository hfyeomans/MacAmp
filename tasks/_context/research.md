# Cross-Task Research: Dependency & Conflict Analysis

> **Purpose:** Documents file-level conflicts, architectural dependencies, and parallelization analysis across 6 planned MacAmp tasks.
> **Date:** 2026-02-21
> **Validated by:** Oracle (gpt-5.3-codex, xhigh reasoning) x2 — initial analysis + verification pass
> **Sources:** Oracle, file explorer agent, all 6 task research/plan/state documents, Xcode project file analysis

### Quick Reference

| Metric | Value |
|--------|-------|
| Tasks | 6 (T1-T6) |
| Plans complete | 6 of 6 |
| Resolved prerequisites | 4 (N1-N6 PR #49, SPSC PR #48, T4 plan written, T6 version: 6.2) |
| Pending decisions | 0 |
| Execution waves | 3 |
| Branches | 6 |
| Expected PRs | 5 (Wave 1: 3, Wave 2: 2; Wave 3 PR count TBD) |
| File conflict pairs (semantic) | 3 (T1+T5, T3+T5, T4+T6) |
| File conflict pairs (pbxproj) | 6 (all file-creating task pairs) |

---

## 1. Task Inventory

| ID | Task | Internal Status | Scope | Risk |
|----|------|----------------|-------|------|
| T1 | `audioplayer-decomposition` | Research + plan complete | AudioPlayer.swift 1,070 -> ~680 lines (facade pattern) | Low (Ph1-3), Med-High (Ph4) |
| T2 | `playlistwindow-layer-decomposition` | Research + plan complete | WinampPlaylistWindow ~516 -> ~120 lines (child views) | Low |
| T3 | `mainwindow-layer-decomposition` | Research + plan complete | WinampMainWindow ~894 -> ~80 lines (child views) | Medium |
| T4 | `lock-free-ring-buffer` | Research complete, **plan pending** | New SPSC ring buffer + swift-atomics dependency | Medium |
| T5 | `internet-streaming-volume-control` | Research + plan complete | Phase 1: volume routing; Phase 2: Loopback Bridge | Ph1: Low, Ph2: High |
| T6 | `swift-testing-modernization` | Research + plan complete | 9 test files XCTest -> Swift Testing, Package.swift bump | Low |

### Prerequisites (Completed)

| Prerequisite | Status | Resolved In |
|-------------|--------|-------------|
| N1-N6 internet radio fixes (T5 blocker) | **RESOLVED** | PR #49 (merged 2026-02-21) |
| VisualizerPipeline SPSC refactor (T5 Ph2 prereq) | **RESOLVED** | PR #48 (merged 2026-02-14) |

---

## 2. File-Level Conflict Matrix

### Production Files Touched Per Task

| File | T1 | T2 | T3 | T4 | T5 Ph1 | T5 Ph2 | T6 |
|------|----|----|----|----|--------|--------|----|
| `AudioPlayer.swift` | **MODIFY** | | | | **MODIFY** | **MODIFY** | |
| `VisualizerPipeline.swift` | **MODIFY** | | | | | (indirect) | |
| `StreamPlayer.swift` | | | | | **MODIFY** | **MODIFY** | |
| `PlaybackCoordinator.swift` | | | | | **MODIFY** | **MODIFY** | |
| `WinampMainWindow.swift` | | | **REWRITE** | | **MODIFY** | | |
| `WinampMainWindow+Helpers.swift` | | | **DELETE** | | | | |
| `WinampPlaylistWindow.swift` | | **REWRITE** | | | | | |
| `WinampPlaylistWindow+Menus.swift` | | **DELETE** | | | | | |
| `WinampEqualizerWindow.swift` | | | | | **MODIFY** | | |
| `VisualizerView.swift` | | | | | | **MODIFY** | |
| `Package.swift` | | | | **MODIFY** | | | **MODIFY** |
| `Package.resolved` | | | | **MODIFY** | | | (possible) |
| **`project.pbxproj`** | **MODIFY** | **MODIFY** | **MODIFY** | **MODIFY** | | | |
| New: `EqualizerController.swift` | **CREATE** | | | | | | |
| New: `LockFreeRingBuffer.swift` | | | | **CREATE** | | | |
| New: `Views/MainWindow/*.swift` (8-10) | | | **CREATE** | | | | |
| New: `Views/PlaylistWindow/*.swift` (6-8) | | **CREATE** | | | | | |
| 9 test files | | | | | | | **MODIFY** |

### Critical Overlaps (2+ tasks touching same file)

| File | Tasks | Severity | Notes |
|------|-------|----------|-------|
| **`project.pbxproj`** | T1 + T2 + T3 + T4 | **HIGH** | All file-creating tasks modify Xcode project file. Explicit `PBXFileReference` + `PBXBuildFile` entries required for each new file. |
| **AudioPlayer.swift** | T1 + T5 | **HIGH** | T1 extracts EQ methods, T5 removes video volume didSet + adds sourceNode |
| **WinampMainWindow.swift** | T3 + T5 Ph1 | **HIGH** | T3 restructures entire file, T5 reroutes volume/balance bindings |
| **Package.swift** | T4 + T6 | **MEDIUM** | T4 adds swift-atomics dependency, T6 bumps tools-version |
| **Package.resolved** | T4 + T6 | **LOW** | T4 adds swift-atomics resolution; T6 tools-version bump may re-resolve |
| **VisualizerPipeline.swift** | T1 + T5 Ph2 | **LOW** | T1 moves getFrequencyData in, T5 uses it — complementary |

### project.pbxproj Impact Detail

The Xcode project (`MacAmpApp.xcodeproj/project.pbxproj`, 1,017 lines) uses **explicit file references** (not folder references). Each new/deleted/moved file requires:
- A `PBXFileReference` entry (file registration)
- A `PBXBuildFile` entry (build phase inclusion)
- A `PBXGroup` `children` array update (directory structure)

| Task | Files Added | Files Deleted | pbxproj Sections Affected |
|------|-----------|--------------|--------------------------|
| T1 | 1 (EqualizerController.swift) | 0 | PBXFileReference, PBXBuildFile, Audio group |
| T2 | 6-8 (PlaylistWindow child views) | 2 (extension + possible moves) | PBXFileReference, PBXBuildFile, Views group, new PlaylistWindow group |
| T3 | 8-10 (MainWindow child views) | 1 (+Helpers.swift) | PBXFileReference, PBXBuildFile, Views group, new MainWindow group |
| T4 | 1-3 (buffer + tests) | 0 | PBXFileReference, PBXBuildFile, Audio group |

**pbxproj conflicts are mechanical** (adding/removing entries), never semantic. They are resolvable but annoying. Mitigation: sequential merge with explicit pbxproj resolution at each step.

---

## 3. Pairwise Conflict Analysis (All 15 Pairs)

### Oracle Assessment (gpt-5.3-codex, xhigh)

| Pair | Result | Shared Files |
|------|--------|-------------|
| T1 + T2 | **Parallel (pbxproj caution)** | project.pbxproj only |
| T1 + T3 | **Parallel (pbxproj caution)** | project.pbxproj only |
| T1 + T4 | **Parallel (pbxproj caution)** | project.pbxproj only |
| T1 + T5 | **CONFLICT** | AudioPlayer.swift, VisualizerPipeline.swift |
| T1 + T6 | **Safe parallel** | None |
| T2 + T3 | **Parallel (pbxproj caution)** | project.pbxproj only |
| T2 + T4 | **Parallel (pbxproj caution)** | project.pbxproj only |
| T2 + T5 | **Safe parallel** | None |
| T2 + T6 | **Safe parallel** | None |
| T3 + T4 | **Parallel (pbxproj caution)** | project.pbxproj only |
| T3 + T5 | **CONFLICT** | WinampMainWindow.swift |
| T3 + T6 | **Safe parallel** | None |
| T4 + T5 | **Sequential (dependency)** | T5 Phase 2 depends on T4 output |
| T4 + T6 | **Merge risk** | Package.swift, Package.resolved |
| T5 + T6 | **Safe parallel** | None |

**Correction from verification pass:** Original analysis claimed "zero file overlap" for Wave 1 worktrees. This is incorrect — `project.pbxproj` is shared by all file-creating tasks. Updated all pairwise classifications to reflect this.

---

## 4. Ordering Constraint Analysis

### Hard Dependencies (Must-Sequence)

1. **T4 -> T5 Phase 2:** Ring buffer is a prerequisite for Loopback Bridge
2. **T5 Phase 1 -> T5 Phase 2:** Capability flags infrastructure needed before bridge
3. **N1-N6 fixes -> T5 Phase 1:** Internet radio infrastructure must work before adding volume routing. **Status: RESOLVED in PR #49.**

### Soft Dependencies (Recommended Sequence)

4. **T1 Phases 1-3 before T5:** Cleaner AudioPlayer facade gives T5 a more stable surface
5. **T5 Phase 1 before T3:** See trade-off analysis in Section 5
6. **T4 before or with T6:** Package.swift/Package.resolved coordination

### No Dependencies (Fully Independent)

7. **T2:** Zero production file overlap with any other task (pbxproj only)
8. **T6 (test files):** Zero production code overlap with any task

---

## 5. Plan Invalidation Risk Analysis

### What happens if Task X is done first?

| If done first | Impact on other tasks |
|---------------|----------------------|
| T1 (AudioPlayer decomp) | **Positive** for T5 — cleaner facade to work against. T5 locates symbols by name (e.g. `var volume: Float`), not position. |
| T2 (Playlist window) | **No impact** on any other task (pbxproj conflict is mechanical) |
| T3 (MainWindow decomp) | **Invalidates T5 Phase 1 plan references** — volume/balance binding locations move from WinampMainWindow.swift to MainWindowSlidersLayer.swift. T5 plan update required but functional intent unchanged. |
| T4 (Ring buffer) | **No impact** on any other task (enables T5 Phase 2) |
| T5 Phase 1 (Volume) | **Small impact on T3** — T3 must account for new coordinator bindings during extraction (~5 lines of binding changes). Easily absorbed since T3 moves all bindings to child views anyway. |
| T5 Phase 2 (Bridge) | **Moderate impact on T1 Phase 4** — both restructure engine/transport internals |
| T6 (Swift Testing) | **No impact** on any other task |

### T3 vs T5 Phase 1 Ordering: Trade-Off Analysis

This is a **trade-off, not a hard rule**. Both orderings are viable.

**Option A: T5 Phase 1 FIRST, then T3 (chosen)**

| Pro | Con |
|-----|-----|
| T5 Ph1 plan works as-written (targets symbols in WinampMainWindow.swift) | T3 lands on critical path (blocked by T5 Ph1) |
| T3 naturally absorbs T5's small binding changes during restructuring | Adds latency to total execution time |
| Lower coordination risk — T5 author doesn't need to know T3's new structure | |

**Option B: T3 FIRST, then T5 Phase 1 (Oracle's alternative)**

| Pro | Con |
|-----|-----|
| T3 runs in Wave 1 (off critical path), reduces total execution time | T5 Ph1 plan needs updating: binding refs move to child view files |
| T5 gets cleaner, smaller child view targets to modify | T5 implementer must understand T3's new directory/file structure |
| Child view isolation = more precise changes | More coordination overhead |

**Decision: Option A (T5 Ph1 first).** The plan-stability benefit outweighs the critical-path cost. T5 Ph1 is small (~100 lines, <1 day effort). The alternative saves time on paper but introduces plan-update overhead and coordination risk that could cost more than it saves. The key advantage: T5 Ph1's plan references specific symbols (`buildVolumeSlider`, `audioPlayer.volume` binding, `audioPlayer.balance` binding) in WinampMainWindow.swift. After T3, these symbols would live in child view files (`MainWindowSlidersLayer.swift`) requiring the T5 plan to be rewritten with new file targets.

---

## 6. Parallelization Strategy

### Can Use Separate Worktrees Simultaneously

| Worktree A | Worktree B | Worktree C | Safe? |
|-----------|-----------|-----------|-------|
| T1 | T2 | T4+T6 | **YES** — pbxproj-only overlap (mechanical merge) |

All other Wave 1 combinations are also viable, but the above is the chosen configuration.

**Important:** "Safe" means no semantic file conflicts. All file-creating worktrees will modify `project.pbxproj` — this requires sequential merge with mechanical conflict resolution. See Section 7 for merge strategy.

### Cannot Run in Parallel

| Task A | Task B | Reason |
|--------|--------|--------|
| T1 | T5 | Both modify AudioPlayer.swift (semantic conflict) |
| T3 | T5 Ph1 | Both modify WinampMainWindow.swift (semantic conflict) |
| T4 | T5 Ph2 | Sequential dependency (ring buffer prerequisite) |

### Agent Teams vs Separate Instances

| Approach | Best For | Tasks |
|----------|----------|-------|
| **Separate Claude instances + worktrees** | Isolated tasks with pbxproj-only overlap | T1, T2, T4+T6 (Wave 1) |
| **Sequential in same instance** | Semantic file conflicts | T5 Ph1 then T3 (Wave 2) |
| **Single instance after merges** | Complex dependencies | T5 Ph2 (Wave 3) |

---

## 7. pbxproj Merge Strategy

### Problem

Wave 1 has 3 worktrees that all create new files, each adding entries to `project.pbxproj`. Merging in any order will produce pbxproj conflicts on the 2nd and 3rd merges.

### Solution: Sequential Merge with Designated Integration Order

1. **Merge Worktree A (T1) first** — smallest pbxproj change (1 new file). Clean merge.
2. **Merge Worktree C (T4+T6) second** — 1-3 new files + Package.swift changes. Resolve pbxproj mechanically.
3. **Merge Worktree B (T2) third** — largest pbxproj change (6-8 new files, 2 deletes). Resolve pbxproj mechanically.

**Why this order:** Smallest-first reduces the amount of existing pbxproj content that conflicts with. T4+T6 before T2 because Package.swift changes should land before large structural changes.

### Conflict Resolution Process

pbxproj conflicts are always mechanical:
- `PBXFileReference` section: accept both sides (both add new entries to a flat list)
- `PBXBuildFile` section: accept both sides (both add new entries to a flat list)
- `PBXGroup` children arrays: combine children from both sides into the correct group

No semantic judgment required. Can be automated with `xcodebuild` project regeneration if needed.

---

## 8. Sources

- Oracle (gpt-5.3-codex, xhigh reasoning) — initial pairwise analysis + verification pass (C+ grade, corrections applied)
- File explorer agent — file path verification, conflict matrix construction
- Xcode project analysis — confirmed explicit `PBXFileReference` file management (1,017-line pbxproj)
- Task documents: All 6 tasks' research.md, plan.md, state.md files
- tasks_index.md — current task status inventory
- PR #49 — N1-N6 internet radio fixes (T5 prerequisite, resolved)
- PR #48 — Memory/CPU optimization (T5 Ph2 SPSC prerequisite, resolved)
