# Cross-Task State: Execution Coordination

> **Purpose:** Single source of truth for cross-task execution status, wave progress, and coordination decisions.
> **Date:** 2026-02-21
> **Updated:** 2026-04-28 (S3-1A `mainwindow-visualizer-isolation` implementation complete + V.1 PASS; pending Oracle gate + PR. New follow-up task: `timer-runloop-mode-audit`.)
> **Previous:** 2026-04-27 (S3 plans + todos all Oracle-approved ≥ 9/10. 5 task folders implementation-ready.)

### Quick Reference

| Metric | Value |
|--------|-------|
| Current release | v1.3 (2026-03-26) |
| .swift files | ~110 |
| Tests | 57 |
| Current phase | S3 planning |
| PRs merged | 77 total |
| Architecture principles | `tasks/_context/principles.md` |

---

## Current Phase: v1.3 RELEASED — S3 Planning

**v1.3 released 2026-03-26** — Now Playing, LIST OPTS, stream timer, 12 bug fixes.
Post-S2 decomposition complete: SkinManager 766→454, EQ Window 616→354, dead code removed.
Responsibility sweep confirmed codebase is architecturally sound (76 Clean, 26 Justified, 7 Actionable).

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

**Wave 3 Pivot:** MTAudioProcessingTap does not work with streaming AVPlayerItems (Apple QA1716). CoreAudio Process Tap rejected (feedback loop). New approach: replace AVPlayer with custom URLSession + AudioFileStream + AudioConverter pipeline feeding PCM into existing AVAudioEngine graph. See: `tasks/done/unified-audio-pipeline/` and `tasks/_context/depreciated/lessons-dual-backend-dead-end.md`.

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
| ~~Precompute spectrum band coefficients~~ | memory-cpu-optimization todo.md 4.2→5.7 | N/A | N/A | **Done.** `GoertzelCoefficients` struct caches per sample rate. |
| NSMenu "Internal inconsistency" warnings | S1 manual testing (2026-03-22) | Small | Low | No — harmless AppKit menu hierarchy warnings for system-injected text menus (Font, Spelling, Substitutions, etc.). Pre-existing, not caused by any sprint work. Common in SwiftUI+AppKit bridging apps. |
| Real-time VBR bitrate display | S1 manual testing (2026-03-22) | Medium | Low | No — Feature request: Winamp classic updates bitrate display in real-time during VBR playback. MacAmp currently reads bitrate once at track load (MetadataLoader). Would require periodic re-reading from the engine during playback. Evaluate as a Winamp fidelity feature. |
| LockFreeRingBuffer "High throughput" flaky overrun threshold | PR #64 (2026-03-22) | Small | Low | No — Wrapped with `withKnownIssue(isIntermittent: true)`. Root cause: overrun count is non-deterministic under task scheduling contention. Threshold (chunksToWrite/2) too tight for loaded CI. Needs either a relaxed threshold or a redesigned stress test that measures throughput without a hard overrun cap. |

| Early-project preprocessing/workarounds audit | PR #75 (2026-03-25) | Small | Medium | No — `SkinBackgroundPreprocessor` (digit blackout) was unnecessary and caused visual artifacts on non-black skins. Removed in PR #75. Scan codebase for similar early-project workarounds that may no longer be needed (defensive preprocessing, hardcoded pixel fixups, manual coordinate hacks that sprites now handle). |
| Accessibility: custom sliders need adjustable a11y elements | PR #76 CodeRabbit (2026-03-25) | Medium | Medium | No — WinampVerticalSlider, WinampVolumeSlider, WinampBalanceSlider all use custom DragGesture without exposing adjustable accessibility traits. Should add `.accessibilityAdjustableAction` for VoiceOver. |
| Accessibility: EQPresetPickerView import footer should be a Button | PR #76 CodeRabbit (2026-03-25) | Small | Low | No — Import footer uses `onTapGesture` on an HStack, not keyboard-accessible. Replace with `Button` for keyboard/VoiceOver support. |

**Context (Hide Main Window):** The "Hide Main" menu item (`AppCommands.swift:13`) calls `DockingController.toggleMain()` which only toggles an internal `panes[idx].visible` boolean. This boolean is not wired to actually hide/show the NSWindow. `WindowVisibilityController.hideMain()` exists and calls `registry.mainWindow?.orderOut(nil)` but is never invoked by the toggle path. Pre-existing — not caused by T3 decomposition.

**Context (spm-multiple-producers-fix):** ✅ RESOLVED (2026-03-22). Resolved by Wave 3 swift-tools-version 6.2 upgrade. 55 tests passing.

### From Wave 3 — Pivot + Deferred Items

| Item | Source | Size | Priority | Blocks Future? |
|------|--------|------|----------|----------------|
| ~~T5 Phase 2 MTAudioProcessingTap~~ | N/A | N/A | N/A | **Reverted.** Replaced by T7. |
| ~~UI dimming un-dim~~ | N/A | N/A | N/A | **Done.** Completed in T7. |
| ~~os_workgroup integration~~ | N/A | N/A | N/A | ✅ COMPLETE — PR #66 (S2) |
| ~~Network auto-reconnect~~ | N/A | N/A | N/A | ✅ COMPLETE — PR #61 (S1) |
| ~~docs/ folder update~~ | N/A | N/A | N/A | ✅ COMPLETE — 2026-03-14 |
| HLS streaming support | unified-audio-pipeline Phase 3 | Large | Low | → S3 |
| OGG Vorbis support | unified-audio-pipeline Phase 2.4 | Medium | Low | → S3 |
| Stream pause audio tail | Post-merge Oracle P2 | Small | Low | → S3 |
| Video audio through AVAudioEngine | unified-audio-pipeline | Medium | Medium | → S3 (deferred from S2) |
| macOS 26 passthrough guard | unified-audio-pipeline Phase 2.3 | Small | Low | Deferred — HDMI/optical only |
| Default MainActor isolation | T8 Phase 5 | Medium | Low | Deferred — questionable ROI |

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
| `os-workgroup-integration` | Apple Silicon os_workgroup for audio render thread | Small | ✅ COMPLETE — PR #66 merged (2026-03-22). Oracle 8.5/10. ObjC shim + per-block join/leave on decode queue. | None |
| `stream-track-counter` | Stream elapsed timer + playlist position + auto-play consolidation + crash guard | Medium | ✅ COMPLETE — PR #68 merged (2026-03-23). Oracle 8/10. Anchor-based timer, "3/15" position, auto-play through coordinator, loadAudioFile crash guard. | None |
| `playlist-list-operations` | NEW LIST, LOAD LIST, SAVE LIST buttons in playlist window | Medium | ✅ COMPLETE — PR #67 merged (2026-03-22). Oracle 9/10. M3UWriter, generation token, background I/O. | None |
| `airplay-integration` | ~~AirPlay routing~~ + Now Playing + remote commands | Medium | ✅ COMPLETE — PR #69 merged (2026-03-24). Phase 1 (AirPlay triggers) DEFUNCT — AVRoutePickerView incompatible with AVAudioEngine on macOS. Phase 2 (Now Playing + remote commands) Oracle 9/10. | None |

**S2 deferral (2026-03-22):** `video-audio-engine-routing` moved to S3. A/V sync risk needs Gemini deep research before implementation.
**S2 AirPlay finding (2026-03-24):** AVRoutePickerView on macOS routes per-AVPlayer only, cannot redirect AVAudioEngine. In-app AirPlay triggers abandoned. Engine config observer deferred (still needed for system Control Center route changes). Now Playing + remote commands shipped independently.

**Sprint S2: COMPLETE (4/4 tasks merged)**

### Sprint S3: LOW-MEDIUM Priority — Edge Cases + Optimization + Video Routing

> **Status (2026-04-28):** S3-1A `mainwindow-visualizer-isolation` implementation complete + V.1 PASS — pending Oracle code-review gate + PR. Other S3 tasks (S3-1B through S3-4) still PLAN APPROVED, awaiting their wave order.

**Locked S3 ordering and branch plan:**

| Wave | Step | Task Folder | Branch | PR # | Predecessors | Pre-Plan Spike | Status |
|------|------|-------------|--------|------|--------------|----------------|--------|
| S3-1 | A (parallel) | `mainwindow-visualizer-isolation` | `feat/mainwindow-visualizer-isolation` | A | none | `spike/mwvi-volume-drag-profile` (Instruments) | **IN PROGRESS** — V.1 PASS, pending Oracle gate + PR |
| S3-1 | B (parallel) | `stream-pause-tail` | `fix/stream-pause-tail` | B | none | none | PLAN APPROVED |
| S3-2 | sequential | `video-audio-engine-routing` | `feat/video-audio-engine-routing` | C | S3-1 merged | `spike/vaer-av-drift-measurement` | PLAN APPROVED |
| S3-3 | sequential | `hls-streaming-support` | `feat/hls-streaming-support` | D | S3-2 merged | none (Gemini re-run optional at plan-time) | PLAN APPROVED |
| S3-4 | sequential | `ogg-vorbis-support` | `feat/ogg-vorbis-support` | E | S3-3 merged | `spike/ogg-build-wiring` (0a) + `spike/ogg-local-playback` (0b) | PLAN APPROVED |
| Post-S3-1A | follow-up | `timer-runloop-mode-audit` | `fix/timer-runloop-mode-audit` | G | S3-1A merged | none | PLANNED — see "Post-S3-1A Follow-Ups" below |

**Cross-task file conflict map:**

| File | mwvi | spt | vaer | hls | ogg |
|------|:---:|:---:|:---:|:---:|:---:|
| `Views/MainWindow/MainWindowFullLayer.swift` | ✓ | | | | |
| `Audio/StreamDecodePipeline.swift` | | ✓ | | ✓ | ✓ |
| `Audio/StreamPlayer.swift` | | ✓ | | ✓ | |
| `Audio/AudioFileStreamParser.swift` | | | | ✓ | |
| `Audio/AudioConverterDecoder.swift` | | ✓ | | | ✓ |
| `Audio/AudioEngineController.swift` | | ✓ | possibly | | ✓ |
| `Audio/AudioPlayer.swift` | | ✓ | | | ✓ |
| `Audio/PlaybackCoordinator.swift` | | ✓ | | | |
| `Audio/VideoPlaybackController.swift` | | | ✓ | | |
| `Audio/MetadataLoader.swift` | | | | | ✓ |
| `Package.swift` / `project.yml` | | | | | ✓ |

**Hard ordering constraints:**
- `mwvi` and `spt` are non-overlapping → parallel as Wave S3-1 (sequential merge: A first, B second).
- `hls`, `ogg`, and `spt` all modify `StreamDecodePipeline.swift` → strict serial.
- `ogg` is last because it touches Package.swift + project.yml + vendored C deps and includes the chained-format `onFormatReady` gap fix that benefits from a stable pipeline.

**Spike policy:** All Phase 0 spikes run on throwaway branches; findings are written back to research.md; branches are deleted.

**Oracle gate:** Each plan.md is iterated with Oracle (`mcp__codex-cli__codex`, `gpt-5.5`, `reasoningEffort: xhigh`) until score ≥ 9/10 before implementation begins.

**Per-task plan + todo status (all complete, all Oracle-approved ≥ 9/10):**

| Task Folder | research.md | plan.md | todo.md | Oracle plan score | Iterations |
|-------------|------------|---------|---------|-------------------|:---:|
| `mainwindow-visualizer-isolation` | ✅ 9/9 applied + Phase 0 results appended | ✅ | ✅ | **9.4/10** (plan); **8/10** (post-1B Oracle diagnostic) | 4 + 1 |
| `stream-pause-tail` | ✅ 8/8 applied | ✅ (8 ADRs) | ✅ | **9.1/10** | 5 |
| `video-audio-engine-routing` | ✅ existing | ✅ | ✅ | **9.4/10** | 3 |
| `hls-streaming-support` | ✅ 8/8 applied | ✅ | ✅ | **9.0/10** | 4 |
| `ogg-vorbis-support` | ✅ 10/10 applied | ✅ (22 sections) | ✅ | **9.3/10** | 3 |

**S3 is implementation-ready.** S3-1A (mwvi) is in progress; S3-1B (spt) onwards still queued.

### Post-S3-1A Follow-Ups (discovered during mwvi)

| Task Folder | Description | Size | Status | Trigger |
|-------------|-------------|------|--------|---------|
| `timer-runloop-mode-audit` | Audit + fix the 3 remaining `Timer.scheduledTimer` callsites that schedule on `.default` mode and pause during gestures (`WinampMainWindowInteractionState.scrollTimer` HIGH; `ButterchurnPresetManager.cycleTimer` + `.trackTitleTimer` LOW). 4 other callsites already use `.common` correctly. Mirrors mwvi commit `6a6bbf2`. | Small (~30-40 lines diff) | PLANNED — runs after mwvi PR #A merges | Discovered during mwvi diagnosis (2026-04-28). Same gesture-pause bug pattern, 3 separate user-visible defects (most prominently the Winamp marquee scroll). |

**mwvi-derived lessons (cross-task):**

- **End-to-end pipeline diagnosis** — Symptoms manifest at the consumer; root causes often live at the producer. Phase 0 instrumented only the SwiftUI consumer side; the actual root cause was upstream at `VisualizerPipeline.pollTimer`. See `~/.claude/projects/-Users-hank-dev-src-MacAmp/memory/feedback_pipeline_end_to_end_diagnosis.md` and `BUILDING_RETRO_MACOS_APPS_SKILL.md`.
- **ast-grep structural search before edits** — relying on `rg` text matching alone missed a duplicate `videoPlaybackController.volume` write and dead `streamPlayer.volume`/`.balance` properties. See `~/.claude/projects/-Users-hank-dev-src-MacAmp/memory/feedback_ast_grep_structural_search.md`.

### Post-S2 / Pre-S3 Architecture Follow-Ons: Hybrid Dedup + Decomposition (6 tasks)

> **Phasing (Gemini + Oracle, 2026-03-24):**
> - **Phase 2a:** Intra-file dedup & simplification (Task 0 — prerequisite for all extractions)
> - **Phase 2b:** Structural extraction (Tasks 1-5 — sequential, one branch/PR each)
> - **Phase 2c:** Cross-file dedup (deferred to after extraction or Structure Sprint)
>
> After Phase 2a merges, all 5 decomposition plans are refreshed (line numbers change).

| # | Task Folder | Description | Size | Status | Dependency |
|---|-------------|-------------|------|--------|------------|
| 0 | `intra-file-dedup-simplification` | First-pass dedup: consolidate intra-file duplications + remove dead code in 4 implementation targets (excludes AudioPlayer) | Small-Medium | COMPLETE (PR #71 merged 2026-03-24) | None — runs first |
| 0.5 | `codebase-wide-simplification` | Codebase-wide dead code + DRY consolidation (-732 lines, 6 files deleted, 4 utilities created) | Medium | COMPLETE (PR #72 merged 2026-03-24) | After Task 0 |
| 1 | `streamdecodepipeline-decomposition` | **DEFERRED.** DecodeContext extraction requires `private → internal` (Principle 5). File is 697 lines, one responsibility, architecturally sound per sweep. Same principle applied to cancel SkinManager Step 4 and VisualizerPipeline. | N/A | **DEFERRED** | Re-evaluate if file grows or gains new responsibility |
| 2 | `winamp-equalizer-window-decomposition` | Selective: extracted WinampVerticalSlider + EQPresetPickerView. Full layer split cancelled (verbose SwiftUI). 616→354 lines. | Small | **COMPLETE** (PR #76) | Done |
| 3 | `visualizerpipeline-decomposition` | ~~4 new files~~ → Cancelled (private @unchecked Sendable surface risk) | N/A | **NO-GO** | N/A |
| 4 | `skinmanager-decomposition` | Steps 1-3 done (ArchiveLoader, Import). Preprocessor removed (skin artifact bug). Step 4 cancelled (visibility leak). 766→454 lines. | Medium | **COMPLETE** (PR #75 merged 2026-03-25) | Done |
| 5 | `audioplayer-seek-extraction` | **DEFERRED (Option C).** 734 lines, one responsibility (facade). Accept swiftlint suppressions. Revisit as Option B (lean SeekController with direct engine refs, 2 callbacks max) only if AudioPlayer grows past 800 lines during S3 or a new responsibility emerges. | N/A | **DEFERRED** | Re-evaluate during S3 |

**Responsibility sweep (2026-03-25, PR #74):** 5-agent SRP + AHA audit of all 109 files. Result: 76 Clean, 26 Justified, 7 Actionable. Applied Swift Architecture & Decomposition principles (Cohesion > LOC, AHA Rule of Three, no visibility leaks, no pass-through middlemen). 4 of 5 original decomposition plans revised or cancelled. See `tasks/responsibility-sweep/research.md`.

**Revised Phase 2b scope:** ~5 new files (was ~18). Dead code cleanup: PresetsButton.swift, WinampButtonStyle.swift, WinampAlertHelper.promptText, SkinBackgroundPreprocessor (caused skin artifacts, removed). New opportunity: WindowSizeState protocol (3x persistence duplication).

**Phase 2c deferred items:** ~~SkinManager sprite extraction loop dedup, NUMS_EX move to SkinSprites.swift~~ — **RESOLVED in PR #76** (`extractSprites` helper + `SkinSprites.numsExSprites`).

### D8: AudioPlayer — Defer seek extraction (Option C, 2026-03-25)

**Decision:** AudioPlayer.swift (734 lines) stays as-is. The responsibility sweep confirmed it has one cohesive responsibility (local audio playback orchestration). The swiftlint suppressions (file_length + type_body_length) are threshold mismatches, not architecture signals.

**Rationale:** Per Principle 1 (Problem-First), there is no concrete failure mode — no merge conflicts, no independent change vectors, no tangled state machines. The seek state (`currentSeekID`, `seekGuardActive`, `isHandlingCompletion`) is tightly coupled to play/stop/onPlaybackEnded. The 6-callback SeekController pattern would create pass-through indirection.

**Fallback (Option B):** If AudioPlayer grows past 800 lines during S3 (e.g., `video-audio-engine-routing`) or gains a genuinely new responsibility, revisit with a lean SeekController design: give it direct references to `engine` and `videoPlaybackController` instead of callbacks, reducing to ~2 callbacks (`onRequestNextTrack`, `onPlaylistAdvanceRequest`). This eliminates the pass-through middleman concern while still extracting the seek state machine as an atomic unit.

**Kill switch:** If the lean design still requires fragmenting state ownership across SeekController and AudioPlayer, cancel entirely.

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
| `_context/state.md` | Active (this file — updated 2026-03-24, Task 0 + 0.5 merged) |
