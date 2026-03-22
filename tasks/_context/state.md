# Cross-Task State: Execution Coordination

> **Purpose:** Single source of truth for cross-task execution status, wave progress, and coordination decisions.
> **Date:** 2026-02-21
> **Updated:** 2026-03-15 (Wave 3 complete; architecture rollout tasks extended through post-S2 / pre-S3)

### Quick Reference

| Metric | Value |
|--------|-------|
| Tasks | 8 (T1-T8) |
| Plans complete | 6 of 6 |
| Blocking actions | None — all resolved |
| Waves | 3 |
| Branches | 6 |
| PRs | 8 (Wave 1: 3 merged, Wave 2a: PR #53 merged, Wave 2b: PR #54 merged, Wave 3: PR #56, PR #57, PR #58 merged) |
| Current wave | Wave 3 COMPLETE; Sprint S1 planning and follow-on tasks queued |

---

## Current Phase: WAVE 3 COMPLETE — All T7/T8 tasks merged

Wave 2 complete: T5 Phase 1 merged PR #53 (2026-02-22), T3 merged PR #54 (2026-02-22).
Wave 3 pivoted: T5 Phase 2 MTAudioProcessingTap failed → replaced by T7 (unified-audio-pipeline).
New task T8 (swift-concurrency-62-cleanup) added as prerequisite for T7.

**Execution order (2026-03-13):**
1. T8 PR 1: Swift 6.2 foundation (SWIFT_VERSION upgrade + isolated deinit + DispatchQueue cleanup)
2. T7: Unified audio pipeline (custom stream decode, benefits from 6.2)
3. T8 PR 2: AudioPlayer isolated deinit + @concurrent (post-pipeline, final shape)

---

## Completed Prerequisites

| Prerequisite | Resolved In | Impact |
|-------------|-------------|--------|
| N1-N6 internet radio fixes | PR #49 (merged 2026-02-21) | Unblocks T5 Phase 1 |
| VisualizerPipeline SPSC refactor | PR #48 (merged 2026-02-14) | Provides template for T4 ring buffer; unblocks T5 Phase 2 |
| T5 Phase 1 (stream volume routing) | PR #53 (merged 2026-02-22) | Unblocks T3 mainwindow decomposition |
| T3 (mainwindow layer decomposition) | PR #54 (merged 2026-02-22) | Wave 2 complete; unblocks Wave 3 |

---

## Task Status Overview

| ID | Task | Internal Status | Cross-Task Status | Blocker |
|----|------|----------------|-------------------|---------|
| T1 | `audioplayer-decomposition` | **Ph1-4 COMPLETE** (PR #52 + PR #60) | Wave 1 + S1 — MERGED | AudioPlayer 1,143→705 lines. AudioEngineController 413 lines. Suppressions remain (705 > 600 warning). Phase 5 (seek) deferred. |
| T2 | `playlistwindow-layer-decomposition` | **COMPLETE** | Wave 1 — done, awaiting PR | Manual testing items deferred |
| T3 | `mainwindow-layer-decomposition` | **COMPLETE** (PR #54 merged) | Wave 2b — MERGED | None |
| T4 | `lock-free-ring-buffer` | **COMPLETE** (benchmarks deferred) | Wave 1 — done, awaiting PR | None |
| T5 | `internet-streaming-volume-control` | **Ph1 COMPLETE (merged PR #53)**, Ph2 MTAudioProcessingTap FAILED | Wave 2a — MERGED | Ph2 PIVOTED → new task `unified-audio-pipeline` |
| T7 | `unified-audio-pipeline` | **COMPLETE** (PR #57 merged + hotfix) | Wave 3b — MERGED | Custom decode pipeline. All V1-V14 verified. Post-merge hotfix for P1/P3/P4. |
| T8 | `swift-concurrency-62-cleanup` | **COMPLETE** — PR 1 (PR #56) + PR 2 (PR #58) both merged | Wave 3a + 3c — MERGED | Swift 6.2 complete: isolated deinit, @concurrent, zero nonisolated(unsafe), zero Task.detached. |
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

### Wave 2: Sequential Feature + Refactoring — COMPLETE

| Step | Task | Branch | Status | Depends On |
|------|------|--------|--------|-----------|
| 2a | T5 Phase 1 (Volume routing) | `feature/stream-volume-control` | **MERGED** (PR #53, 2026-02-22) | Wave 1 merges (done) |
| 2b | T3 (MainWindow decomp) | `refactor/mainwindow-decomposition` | **MERGED** (PR #54, 2026-02-22) | T5 Phase 1 merge (done) |

**Merge strategy:** Two separate PRs. T5 Ph1 merges first; T3 merges after verification.

### Wave 3: Swift 6.2 + Unified Audio Pipeline — COMPLETE

| Step | Task | Branch | Status | Depends On |
|------|------|--------|--------|-----------|
| 3a | T8 PR 1 (Swift 6.2 foundation) | `feature/swift-concurrency-62-cleanup` | ✅ MERGED — PR #56 (2026-03-14) | Wave 2 merges (done) |
| 3b | T7 (Unified Audio Pipeline) | `feature/unified-audio-pipeline` | ✅ MERGED — PR #57 + hotfix | T8 PR 1 merge (done) |
| 3c | T8 PR 2 (AudioPlayer deinit + @concurrent) | `feature/swift-concurrency-62-cleanup-pr2` | ✅ MERGED — PR #58 | T7 merge (done) |
| 3d | T1 Phase 4 (engine transport) | After 3c | DEFERRED | Engine boundaries stable after T7+T8 |

**Wave 3 execution is strictly sequential:** Each step depends on the previous merge.
T8 is split across 3a and 3c because AudioPlayer.swift is modified by both T8 and T7.

**Wave 3 Pivot:** MTAudioProcessingTap does not work with streaming AVPlayerItems (Apple QA1716). CoreAudio Process Tap rejected (feedback loop). New approach: replace AVPlayer with custom URLSession + AudioFileStream + AudioConverter pipeline feeding PCM into existing AVAudioEngine graph. See: `tasks/unified-audio-pipeline/` and `tasks/_context/lessons-dual-backend-dead-end.md`.

**T1 Phase 4 status:** Still desired but must wait until unified pipeline lands. The engine transport boundaries will change when streamSourceNode receives PCM from a custom decode pipeline instead of a loopback tap. Extracting transport BEFORE the pipeline change would require re-extraction afterward.

---

## Key Decisions

### D1: T5 Phase 1 before T3

**Decision:** internet-streaming-volume-control Phase 1 completes BEFORE mainwindow-layer-decomposition begins.

**Rationale:** Trade-off analysis (see research.md Section 5). T5 Phase 1 modifies a small number of symbol bindings in WinampMainWindow.swift (`buildVolumeSlider`, `audioPlayer.volume/balance` bindings). T3 restructures the entire file into child views. The plan-stability benefit of doing T5 first outweighs the critical-path cost. Alternative (T3 first) was considered and documented but rejected.

### D2: T4 + T6 combined worktree

**Decision:** Lock-free ring buffer and Swift Testing modernization share a worktree and branch.

**Rationale:** Both modify Package.swift (T4 adds swift-atomics dependency, T6 bumps tools-version). Combining avoids merge conflicts. Trade-off: couples two unrelated risk domains. Mitigated by internal sequencing (T6 Ph1 -> T4 -> T6 Ph2-6).

### D3: T1 Phase 4 — swiftlint suppressions remain (UNLOCKED for S1)

**Decision:** AudioPlayer engine transport extraction (Phase 4, medium-high risk) was deferred until T7 unified-audio-pipeline landed. T7 merged (PR #57, 2026-03-14) — Phase 4 is now UNLOCKED and assigned to Sprint S1.

**Rationale:** The seek state machine has three interlocking guards (`currentSeekID`, `seekGuardActive`, `isHandlingCompletion`) that were extensively debugged across multiple PRs. The transport methods (`play`/`pause`/`stop`/`seek`/`scheduleFrom`) share tight mutable state coupling, and completion handlers use seekID matching to ignore stale completions. Multiple timing-sensitive `Task.sleep` delays coordinate guard clearing.

**Impact:** AudioPlayer.swift is now at **1,143 lines** (grew from 945 after T7 added stream source node handling and T8 added isolated deinit + @concurrent). Now approaching the 1,200-line error threshold. Two swiftlint inline suppressions (`file_length` + `type_body_length`) cannot be removed until Phase 4. Phase 4 should only be pursued after unit tests for the seek state machine are added first.

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

### From Wave 2b — Future Optimization

| Item | Source | Size | Priority | Blocks Future Waves? |
|------|--------|------|----------|---------------------|
| MainWindowVisualizerLayer isolation | T3 mainwindow-decomposition | Small | Medium | No — performance optimization |

**Context:** During T3 manual testing, the spectrum analyzer pauses during volume slider drag. This is pre-existing behavior caused by `VisualizerView()` being rendered inline in `MainWindowFullLayer.body` — volume changes trigger full body re-evaluation including the visualizer. The fix is to extract `VisualizerView` into a dedicated `MainWindowVisualizerLayer` struct, creating a SwiftUI recomposition boundary that isolates visualizer rendering from slider state changes.

**Architecture path:**
```text
Current (MainWindowFullLayer.body):
  Group {
    MainWindowSlidersLayer(...)  ← reads audioPlayer.volume (own View boundary)
    VisualizerView()             ← INLINE, no boundary, re-evaluates with parent
  }

Target (MainWindowFullLayer.body):
  Group {
    MainWindowSlidersLayer(...)  ← reads audioPlayer.volume (own View boundary)
    MainWindowVisualizerLayer()  ← NEW View struct, own recomposition boundary
  }
```

`MainWindowVisualizerLayer` would only declare `@Environment` dependencies it actually reads (likely none — `VisualizerView` reads from the audio pipeline directly). This means volume/balance slider drags would NOT trigger its body re-evaluation.

---

### From Wave 1 — Future Tasks Needed

| Item | Source | Size | Priority | Blocks Future? |
|------|--------|------|----------|----------------|
| ~~T1 Phase 4: Engine transport extraction~~ | audioplayer-decomposition todo.md | Large | **DONE** | ✅ COMPLETE — PR #60 merged (2026-03-22). AudioPlayer 1,143→705 lines. AudioEngineController 413 lines. |
| T1 swiftlint suppressions (file_length + type_body_length) | audioplayer-decomposition todo.md | N/A | N/A | Still needed at 705 lines (above 600 warning). Requires Phase 5 (seek extraction) to remove. |
| T1 manual verification (EQ bands, presets, auto-EQ, visualizers) | audioplayer-decomposition todo.md (6 items) | Small | Low | No — functional, just not formally verified post-decomposition |
| Hide Main Window not working | T3 manual testing (pre-existing) | Small | Low | No |
| T3 Instruments body evaluation profiling | mainwindow-layer-decomposition todo.md | Small | Low | No — performance optimization |
| PlaylistWindowActions singleton rearchitecture | playlist-decomp depreciated.md | Large | Low | No |
| Manual selection state sync fix | playlist-decomp depreciated.md | Small | Low | No — blocked by singleton fix |
| T2 doc updates (IMPLEMENTATION_PATTERNS.md anti-pattern, tasks_index) | playlistwindow-layer-decomposition todo.md (2 items) | Small | Low | No |
| ~~`spm-multiple-producers-fix`~~ | infra-ring-testing todo.md + lock-free-ring-buffer + swift-testing | Small-Medium | **RESOLVED** | ~~**Yes — blocks `swift test` via CLI for ALL tasks**~~ Resolved by Wave 3 (swift-tools-version 6.2). CLI tests pass. |
| `async-test-determinism` (Task.sleep removal from 2 test files) | swift-testing todo.md (8 items) | Medium | Low | No — tests pass but use non-deterministic waits |
| Swift Testing parameterization improvements | swift-testing todo.md (4 items) | Small | Low | No — code quality |
| Ring buffer performance benchmarks | lock-free-ring-buffer todo.md (3 items) | Small | Low | No |
| Ring buffer AudioBufferList overload tests | lock-free-ring-buffer todo.md | Small | Low | No — add during T7 |
| DockingController debounce `try?` fix | lock-free-ring-buffer deprecated.md | Small | Low | No |
| Gate verbose sprite logging behind `#if DEBUG` | memory-cpu-optimization todo.md 4.1 | Small | Low | No |
| Precompute spectrum band coefficients | memory-cpu-optimization todo.md 4.2 | Small | Low | No — performance optimization |
| NSMenu "Internal inconsistency" warnings | S1 manual testing (2026-03-22) | Small | Low | No — harmless AppKit menu hierarchy warnings for system-injected text menus (Font, Spelling, Substitutions, etc.). Pre-existing, not caused by any sprint work. Common in SwiftUI+AppKit bridging apps. |
| Real-time VBR bitrate display | S1 manual testing (2026-03-22) | Medium | Low | No — Feature request: Winamp classic updates bitrate display in real-time during VBR playback. MacAmp currently reads bitrate once at track load (MetadataLoader). Would require periodic re-reading from the engine during playback. Evaluate as a Winamp fidelity feature. |

**Context (Hide Main Window):** The "Hide Main" menu item (`AppCommands.swift:13`) calls `DockingController.toggleMain()` which only toggles an internal `panes[idx].visible` boolean. This boolean is not wired to actually hide/show the NSWindow. `WindowVisibilityController.hideMain()` exists and calls `registry.mainWindow?.orderOut(nil)` but is never invoked by the toggle path. Pre-existing — not caused by T3 decomposition.

**Context (spm-multiple-producers-fix):** ✅ RESOLVED (2026-03-22). The error no longer reproduces — resolved by Wave 3 swift-tools-version 6.2 upgrade. `swift test` passes (40 tests, 11 suites). CLI test runs are unblocked.

### From Wave 3 — Pivot + Deferred Items

| Item | Source | Size | Priority | Blocks Future? |
|------|--------|------|----------|----------------|
| ~~T5 Phase 2 MTAudioProcessingTap code — REVERTED~~ | feature/stream-loopback-bridge commit 987b2f3 | N/A | N/A | **STALE** — Code reverted. Replaced by T7 unified pipeline. No action needed. |
| ~~UI dimming un-dim for streams~~ | unified-audio-pipeline plan.md | Small | Part of T7 | **STALE** — Completed as part of T7 merge. Capability flags already updated. |
| HLS streaming support | unified-audio-pipeline Phase 3 | Large | Low | → Sprint S3 task: `hls-streaming-support` |
| OGG Vorbis support | unified-audio-pipeline Phase 2.4 | Medium | Low | → Sprint S3 task: `ogg-vorbis-support` |
| os_workgroup integration | unified-audio-pipeline Phase 2.2 | Small | Medium | → Sprint S2 task: `os-workgroup-integration` |
| macOS 26 passthrough guard | unified-audio-pipeline Phase 2.3 | Small | Low | Remains deferred — only affects HDMI/optical output devices. |
| Network auto-reconnect | unified-audio-pipeline Phase 2.1 | Medium | HIGH | → Sprint S1 task: `network-auto-reconnect` |
| Stream pause audio tail | Post-merge Oracle P2 (deferred) | Small | Low | → Sprint S3 task: `stream-pause-tail` |
| Default MainActor isolation (T8 Phase 5) | swift-concurrency-62-cleanup research.md | Medium | Low | Remains deferred — questionable ROI. |
| Video audio through AVAudioEngine | unified-audio-pipeline/state.md | Medium | Medium | → Sprint S2 task: `video-audio-engine-routing` |
| ~~docs/ folder update for unified pipeline~~ | unified-audio-pipeline/state.md | Medium | Medium | **DONE** — All docs updated and verified (2026-03-14). |

### Manual Testing (Pre-Merge Recommended)

| Item | Source |
|------|--------|
| Playlist: visual rendering, track selection, menus, shade, resize, scroll, keyboard | playlist-decomp todo.md 4.4-4.11 |

### Doc Updates Needed (Post-Merge) — Initial sweep complete; Oracle review found additional issues, fixes applied 2026-03-14.

All doc updates verified complete by sub-agent scan:
- `docs/MACAMP_ARCHITECTURE_GUIDE.md` — ✅ Unified pipeline §4 + §9, EqualizerController listed
- `docs/IMPLEMENTATION_PATTERNS.md` — ✅ 3 audio patterns + stream bridge lifecycle
- `docs/PLAYLIST_WINDOW.md` — ✅ PlaylistWindow/ subdirectory referenced
- `docs/README.md` — ✅ Swift Testing + swift-tools-version 6.2
- `tasks/_context/tasks_index.md` — ✅ T7 + T8 added, statuses updated
- `BUILDING_RETRO_MACOS_APPS_SKILL.md` — ✅ Lesson #27 present

---

## Sprint Plan (Post-Wave 3)

> **Naming:** "Sprints" (S1-S3) to differentiate from Waves 1-3.
> **Created:** 2026-03-14
> **Context:** All Wave 1-3 work complete. These Sprints organize the remaining deferred items plus new feature requests.

### Sprint S1: HIGH Priority — Infrastructure + Stability

| Task Folder | Description | Size | Status | Dependency |
|-------------|-------------|------|--------|------------|
| `spm-multiple-producers-fix` | Fix SwiftPM "multiple producers" blocking `swift test` CLI | Small-Medium | ✅ COMPLETE — resolved by Wave 3 (2026-03-22) | None |
| `audioplayer-decomposition` Phase 4 | Extract AudioEngineController from AudioPlayer.swift | Large | ✅ COMPLETE — PR #60 merged (2026-03-22) | AudioPlayer 1,143→705 lines. New AudioEngineController 413 lines. 53 tests. |
| `network-auto-reconnect` | Auto-reconnect dropped internet radio streams with exponential backoff | Medium | ✅ COMPLETE — PR #61 merged (2026-03-22) | Exponential backoff 1s→16s, max 10 attempts. Typed error classification. User-friendly error display. |
| `xcode-butterchurn-webcontent-diagnosis` | Fix Butterchurn/MilkDrop not rendering (XcodeGen migration dropped Butterchurn resources) | Medium | ✅ COMPLETE — PR #63 merged (2026-03-22) | Root cause: missing resource in project.yml. Also fixed EQ on/off persistence. |

| Hotfix: VBR duration alignment | Fix seek bar drift on VBR/compressed files (P2 from PR #60) | Small | ✅ COMPLETE — PR #62 merged (2026-03-22) | Engine file duration as single source of truth for audio progress. |

**Sprint S1 COMPLETE (2026-03-22).** 4 tasks + 1 hotfix, 4 PRs merged (#60, #61, #62, #63). 53 tests.

**Key outcomes:**
- AudioPlayer decomposed: 1,143→705 lines, new AudioEngineController (413 lines)
- Internet radio auto-reconnect with exponential backoff and typed error classification
- Butterchurn/MilkDrop rendering restored (XcodeGen resource gap)
- EQ on/off state persistence, VBR duration alignment, user-friendly stream error display

**Lessons learned:**
- XcodeGen migration must audit all "Copy Bundle Resources" — non-code resources outside `sources:` path are silently dropped
- `swift build`/`swift test` hide resource issues — always verify with XcodeBuildMCP + manual app launch
- Don't chase console errors before verifying basics (resources in bundle)
- macOS 26 Tahoe WebContent sandbox errors are noisy but non-fatal (WebKit bug 302212)

**Structure policy overlay:** Use `tasks/swift-project-structure-research/` as the placement-policy reference during Sprints S1-S3. Do not run a broad repo restructure during S1-S3. Apply the new ownership model only where sprint tasks already touch files. All file-move consolidation is deferred to the post-S3 Structure Sprint (D-STRUCTURE decision 2026-03-15). Decomposition tasks (post-S2/pre-S3) should split files in place, not move them to target folders.

### Sprint S0: DOCS FIRST — Documentation Hygiene (COMPLETE)

| Task Folder | Description | Size | Status | Dependency |
|-------------|-------------|------|--------|------------|
| `docs-implementation-patterns-update` | Cross-file SwiftUI anti-pattern + full docs audit for staleness | Small | ✅ COMPLETE — PR #59 merged (2026-03-14) | None |

### Sprint S2: MEDIUM Priority — Features + Polish

| Task Folder | Description | Size | Status | Dependency |
|-------------|-------------|------|--------|------------|
| `os-workgroup-integration` | Apple Silicon os_workgroup for audio render thread | Small | PLANNED | None |
| `video-audio-engine-routing` | Route video audio through AVAudioEngine (MTAudioProcessingTap) | Medium | PLANNED | None |
| `stream-track-counter` | Track position counter in main window + playlist window for streams | Small-Medium | PLANNED | None |
| `playlist-list-operations` | NEW LIST, LOAD LIST, SAVE LIST buttons in playlist window | Medium | PLANNED | None |
| `airplay-integration` | AirPlay output routing + Now Playing integration | Medium | RESEARCH DONE | Awaiting user approval |

### Sprint S3: LOW Priority — Edge Cases + Optimization

| Task Folder | Description | Size | Status | Dependency |
|-------------|-------------|------|--------|------------|
| `mainwindow-visualizer-isolation` | SwiftUI recomposition boundary for visualizer during slider drag | Small | PLANNED | None — demoted from Medium: small scope, pre-existing behavior, no functional impact |
| `stream-pause-tail` | Fix ~0.7s audio tail after pausing stream (ring buffer flush) | Small | PLANNED | None |
| `hls-streaming-support` | Add HLS protocol to stream decode pipeline | Large | PLANNED | None |
| `ogg-vorbis-support` | Add OGG Vorbis codec (needs libvorbis or pure Swift decoder) | Medium | PLANNED | None |

### Post-S2 / Pre-S3 Architecture Follow-Ons: Decomposition Only (Created, Not Yet Sprinted)

| Task Folder | Description | Size | Status | Dependency |
|-------------|-------------|------|--------|------------|
| `skinmanager-decomposition` | Decompose `SkinManager.swift` (split large file into smaller pieces) | Medium | PLANNED | Start after Sprint S2 stabilizes |
| `visualizerpipeline-decomposition` | Decompose `VisualizerPipeline.swift` (split large file) | Medium | PLANNED | Start after Sprint S2 stabilizes |
| `streamdecodepipeline-decomposition` | Decompose `StreamDecodePipeline.swift` (split large file) | Medium | PLANNED | Start after Sprint S2 stabilizes |
| `winamp-equalizer-window-decomposition` | Decompose `WinampEqualizerWindow.swift` (split large file) | Medium | PLANNED | Start after Sprint S2 stabilizes |
| `audioplayer-seek-extraction` | Extract seek state machine from AudioPlayer.swift (Phase 5 — deferred from S1 per Oracle) | Medium | PLANNED | Start after Sprint S2 stabilizes. Removes last 2 swiftlint suppressions. |

**AudioPlayer note:** Phase 4 (PR #60, S1) extracted AudioEngineController. The seek state machine remains in AudioPlayer (719 lines, 2 suppressions). `audioplayer-seek-extraction` is now a dedicated post-S2 task to complete the decomposition. The Oracle deferred this from Phase 4 because partial move of the seek state machine across two owners was too risky.

**Decomposition readiness note:** The 5 post-S2 decomposition tasks are backlog-ready (scope, constraints, verification defined) but not implementation-ready. Each task's first step is "produce a responsibility map" — the detailed symbol/method-level extraction tables will be created when S2 stabilizes and the target files have their final shape. This is intentional: S2 tasks (`os-workgroup-integration`, `video-audio-engine-routing`) may modify these files, so premature extraction planning would be wasted.

### Post-S3 Structure Sprint: All Consolidation (D-STRUCTURE decision 2026-03-15)

All file-move consolidation work is deferred to a single dedicated "Structure Sprint" after S3 completes. This replaces the previous plan of weaving consolidation incrementally through post-S1 and post-S2 phases.

| Task Folder | Description | Size | Status | Dependency |
|-------------|-------------|------|--------|------------|
| `windowing-structure-consolidation` | Move generic window files into `Windowing/` | Medium | DEFERRED to post-S3 | Was post-S1; deferred per D-STRUCTURE |
| `milkdrop-feature-consolidation` | Move Milkdrop/Butterchurn files into `Features/Milkdrop/` | Medium | DEFERRED to post-S3 | Was post-S1; deferred per D-STRUCTURE |
| *(not yet created)* | `Features/` consolidation (Video, EQ, Playlist) | Medium | NOT CREATED | Post-S3 |
| *(not yet created)* | `Audio/` consolidation (existing files → ownership boundaries) | Medium | NOT CREATED | Post-S3 |
| *(not yet created)* | `App/`, `Core/`, `Shared/` consolidation | Medium | NOT CREATED | Post-S3 |

**Rationale:** File moves touch `project.yml`, imports, bundle resource paths, and test references — inherently a "stop the world" operation that conflicts with active feature branches. Decomposition first (S1-S3) makes files smaller and easier to move. One focused post-S3 pass is lower risk and higher coherence than scattered moves interleaved with feature work. The placement policy from `swift-project-structure-research` remains active during S1-S3 (new files go to the right place).

**Planning gap (address when post-S3 starts):** The target layout is defined in `swift-project-structure-research/plan.md` but the Structure Sprint still needs: (1) a complete source-to-target mapping for all files, (2) an execution order with dependencies between consolidation areas, (3) task folders for the 3 uncreated areas, (4) XcodeGen/project.yml migration analysis, (5) decisions on ambiguous files that could belong to multiple boundaries. Do not create these until S3 is done — decomposition will create new files and S1-S3 features will modify existing ones.

---

## Resolved Questions

| # | Question | Resolution |
|---|----------|------------|
| 1 | Should T4+T6 be single or separate PRs? | **Single PR** (D6) |
| 2 | Is T1 Phase 4 in scope? | **Deferred** (D3) — after T7 (unified-audio-pipeline); engine boundaries change with streamSourceNode |
| 3 | Wave 2: one or two Claude instances? | **One instance, two sequential PRs** (D5) |
| 4 | swift-tools-version 6.0 or 6.2? | **6.2** — matches installed toolchain (6.2.4) |

---

## Artifact Inventory

| File | Status |
|------|--------|
| `_context/research.md` | Complete (verified, corrections applied) |
| `_context/plan.md` | Complete (verified, corrections applied) |
| `_context/state.md` | Active (this file — updated 2026-03-15) |
