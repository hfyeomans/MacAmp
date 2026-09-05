# Cross-Task State: Execution Coordination

> ⚠️ **S3-2 ARCHITECTURAL PIVOT (2026-05-01 → 2026-05-02 implementation start):** `video-audio-engine-routing` is **PAUSED-AS-REFERENCE** (preserved branch `feat/video-audio-engine-routing`, last commit `5af91eb`, pushed to origin). S3-2 re-attempted as **`avplayer-native-video-dsp`** on branch `feat/avplayer-native-video-dsp`. **Steps 1-3 ✅ (research Oracle 10/10, plan Oracle 9.8/10 incl. ADR-3a containment). Implementation Phases 1-7 ✅ DONE (each Oracle-approved); Phase 8 automated gates ✅ DONE 2026-06-27, hardware/manual gates ⏳ PENDING USER (`tasks/avplayer-native-video-dsp/verification.md`); Phase 9 (UI polish + mandated docs + pre-PR Oracle + PR #C) NOT STARTED. Branch is 73 commits ahead of `main`, pushed to origin at `056c69a` (`origin/feat/avplayer-native-video-dsp` is at the same commit — 0 ahead, 0 behind); unmerged; PR #C not yet opened. (todo 9.12 `git push` being unchecked is a *stale checkbox* — the push already happened.)** **See `tasks/_context/s3-2-pivot.md` for the strategic decision log + step-by-step status — that file is authoritative for current S3-2 status.** The S3 section below now reflects HEAD `056c69a` as of 2026-09-05: line 7's Updated note is explicitly labelled HISTORICAL (it describes the paused engine-routing branch), while the sprint table rows, the per-task Oracle table, and the S3 progress line have all been advanced to the pivot branch's real state.

> **Purpose:** Single source of truth for cross-task execution status, wave progress, and coordination decisions.
> **Date:** 2026-02-21
> **Updated:** 2026-09-05 (staleness sweep against HEAD `056c69a`: S3-2 advanced to the pivot branch's real state — Phases 1-7 ✅, Phase 8 automated gates ✅ / manual + hardware gates pending user, Phase 9 next, branch pushed but unmerged with no PR. Also corrected: test count 68→116, .swift files ~110→~122, AudioPlayer/AudioEngineController/StreamDecodePipeline line counts and their fired growth triggers, the S3 sprint table + conflict map, the S3 progress line, P-6 status, and two new deferred-item rows. **The note that follows is HISTORICAL** — it describes the now-PAUSED `video-audio-engine-routing` branch, on which S3-2 Phase 0 + 1 + 2 were ✅ **all complete**. Phase 2 ships the `MTAudioProcessingTap` wrapper at `MacAmpApp/Audio/VideoAudioTap.swift` (~340 LOC) — C-convention callbacks via `Unmanaged<VideoAudioTapContext>`, AudioConverter handles all four format-edge cases per plan §7.5 (mono duplication via channel map, surround downmix via `kAudioConverterPropertyPerformDownmix=1` + actual source channel layout, non-Float32, sample-rate). 5 commits, Oracle three-pass review converged at **9.3/10** (8.2 → 8.4 → 9.3). 84/84 tests pass with TSan (76 → 84: +4 attach/state, +6 bypass classification, +2 surround layout map). Phase 3 (engine source node + wiring per plan §8) was next on that branch when it was paused 2026-05-01.)
> **Previous:** 2026-04-30 (S3-2 Phase 0 ✅ + Phase 1 ✅ — engine config observer ships; 10 commits on `feat/video-audio-engine-routing`; Path NONE confirmed empirically; manual verification clean across local↔external↔AirPlay.)

### Quick Reference

| Metric | Value |
|--------|-------|
| Current release | v1.3 (2026-03-26) |
| .swift files | ~122 |
| Tests | 116 (all green with TSan at HEAD `056c69a`) |
| Current phase | S3 — S3-1 ✅ merged; S3-2 `avplayer-native-video-dsp` 🔧 IN PROGRESS (Phase 8 automated ✅, manual/hardware gates pending user, Phase 9 next, pushed but no PR); S3-3 / S3-4 queued |
| PRs merged | Highest merged: **#82** `stream-pause-tail` (2026-04-30). Nothing merged since — `main` HEAD is still `9cca40a` (2026-04-30). S3-2 PR (#C) not yet opened. |
| Architecture principles | `tasks/_context/principles.md` |

---

## Current Phase: v1.3 RELEASED — S3 In Progress (S3-2 implementation)

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
| T1 | `audioplayer-decomposition` | **Ph1-4 COMPLETE** (PR #52 + PR #60) | Wave 1 + S1 — MERGED | AudioPlayer 1,143→705 lines. AudioEngineController 413 lines at PR #60 close (**579 lines at HEAD `056c69a`**). Suppressions remain — AudioPlayer.swift is **1,079 lines at HEAD `056c69a`** (705 immediately after PR #60), far above the 600 warning threshold. Phase 5 (seek) deferred — see D8, whose 800-line fallback trigger has now fired. |
| T2 | `playlistwindow-layer-decomposition` | **COMPLETE** | Wave 1 — closed out (task folder at `tasks/done/playlistwindow-layer-decomposition`) | Manual testing items deferred |
| T3 | `mainwindow-layer-decomposition` | **COMPLETE** (PR #54 merged) | Wave 2b — MERGED | None |
| T4 | `lock-free-ring-buffer` | **COMPLETE** (benchmarks deferred) | Wave 1 — MERGED (PR #50, shipped jointly with T6 per D6; squash commit `752a4dd` on `main`) | None — task folder still at `tasks/lock-free-ring-buffer`, not yet moved to `tasks/done/` |
| T5 | `internet-streaming-volume-control` | **Ph1 COMPLETE (merged PR #53)**, Ph2 MTAudioProcessingTap FAILED | Wave 2a — MERGED | Ph2 PIVOTED → new task `unified-audio-pipeline` |
| T7 | `unified-audio-pipeline` | **COMPLETE** (PR #57 merged + hotfix) | Wave 3b — MERGED | Custom decode pipeline. All V1-V14 verified. Post-merge hotfix for P1/P3/P4. |
| T8 | `swift-concurrency-62-cleanup` | **COMPLETE** — PR 1 (PR #56) + PR 2 (PR #58) both merged | Wave 3a + 3c — MERGED | Swift 6.2 complete: isolated deinit, @concurrent, zero nonisolated(unsafe), zero Task.detached. |
| T6 | `swift-testing-modernization` | **COMPLETE** (deferrals noted) | Wave 1 — closed out (task folder at `tasks/done/swift-testing-modernization`) | None |

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
| 3d | T1 Phase 4 (engine transport) | After 3c | ✅ DONE — reassigned to Sprint S1, merged PR #60 (2026-03-22) | Engine boundaries stable after T7+T8 |

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

**Impact (as of this decision, 2026-03-14):** AudioPlayer.swift was at **1,143 lines** (grown from 945 after T7 added stream source node handling and T8 added isolated deinit + @concurrent), approaching the 1,200-line error threshold. PR #60 later cut it to 705; at HEAD `056c69a` it is back to **1,079 lines**. Two swiftlint inline suppressions (`file_length` + `type_body_length`) cannot be removed until Phase 4. Phase 4 should only be pursued after unit tests for the seek state machine are added first.

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

### D-S4: GitHub-issue fixes land after the Structure Sprint (2026-09-05, user)

**D-S4 (2026-09-05, user):** GitHub-issue fixes are sequenced AFTER the Structure Sprint; Swift 6.4/macOS 27 readiness research queued as S4-1 (ordering vs S4-2 = assumption pending user confirmation).

**Rationale:** The user's mandate was that the issue fixes land in the new `.swift` layout, so they are not rebased across a file-move sprint — #78 (window joining/minimization/persistence) touches windowing and benefits most from the moves having landed. S4-1 is placed first on our own inference: its deprecation findings may change how the S4-2 issues are fixed. **That ordering is an assumption, not a user mandate** — confirm before scheduling. S4-1's research half touches no code and may run opportunistically earlier. Full entries in the "Post-Structure-Sprint (S4)" subsection below and in `_context/tasks_index.md`.

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
| T1 swiftlint suppressions (file_length + type_body_length) | audioplayer-decomposition todo.md | N/A | N/A | Still needed — AudioPlayer.swift is **1,079 lines at HEAD `056c69a`** (705 after PR #60), well above the 600 warning threshold. Requires Phase 5 (seek extraction) to remove; see D8 (trigger fired). |
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
| Order-sensitive TSan flake in `VideoTapFallbackTests` | `tasks/phase-7-watchdog-gate-v2-score-confirm` (2026-05-01, paused `video-audio-engine-routing` arc) | Small | Low | No — observed on the paused vaer branch: the fallback tests pass in isolation but can trip TSan depending on test execution order. **Unowned** — never assigned to a task folder or re-checked against the S3-2 pivot branch's 116/116 TSan run. Reconfirm (or retire) during S3-2 Phase 9 full-suite TSan. |
| File-growth re-evaluation triggers have FIRED (2 files) | Recorded thresholds vs HEAD `056c69a` | Medium | Medium | No — but both re-evaluations are now due. `MacAmpApp/Audio/AudioPlayer.swift` = **1,079 lines** vs D8's Option-B ">800 lines during S3" trigger (763 on `main`). `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` = **825 lines** vs the 697 recorded in its deferral row (825 on `main` too — pre-existing, not pivot drift). **Re-evaluate during Structure Sprint mapping**, and only after the S3-2 PR merges. |

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
| ~~Stream pause audio tail~~ | Post-merge Oracle P2 | Small | Low | **✅ DONE** — S3-1B PR #82 merged 2026-04-30 |
| ~~Video audio through AVAudioEngine~~ → in-place AVPlayer tap DSP | unified-audio-pipeline | Medium | Medium | 🔧 IN PROGRESS as S3-2 `avplayer-native-video-dsp` (engine-routing approach abandoned 2026-05-01 — see `_context/s3-2-pivot.md`) |
| macOS 26 passthrough guard | unified-audio-pipeline Phase 2.3 | Small | Low | Deferred — HDMI/optical only |
| Default MainActor isolation | T8 Phase 5 | Medium | Low | Deferred — questionable ROI |

### Manual Testing (Pre-Merge Recommended)

| Item | Source |
|------|--------|
| Playlist: visual rendering, track selection, menus, shade, resize, scroll, keyboard | playlist-decomp todo.md 4.4-4.11 |

### Doc Updates Needed (Post-Merge) — Initial sweep complete; Oracle review found additional issues, fixes applied 2026-03-14.

All doc updates verified complete by sub-agent scan (2026-03-14 sweep — **superseded**: the S3-2 5-agent audit at `tasks/avplayer-native-video-dsp/docs-update-backlog.md` found three flatly-false statements still live in `docs/`, to be fixed in Phase 9.4-9.6):
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

> **Status (2026-09-05):** Wave S3-1 ✅ **COMPLETE** — S3-1A `mainwindow-visualizer-isolation` merged PR #80 (2026-04-28); S3-1B `stream-pause-tail` merged PR #82 (2026-04-30, merge commit `b60fd57`). Post-S3-1A follow-up `timer-runloop-mode-audit` merged PR #81 (2026-04-29). S3-2 pivoted 2026-05-01 from `video-audio-engine-routing` (PAUSED-AS-REFERENCE at `5af91eb`) to **`avplayer-native-video-dsp`**, branch `feat/avplayer-native-video-dsp`, HEAD `056c69a` (2026-06-27), **73 commits ahead of `main`, pushed to origin at `056c69a`; unmerged; PR #C not yet opened**. Steps 1-3 ✅ (research 10/10, plan 9.8/10); implementation **Phases 1-7 ✅ DONE** (Oracle 9.0-10/10 each); **Phase 8 automated gates ✅** (8.1 Debug `-Onone` DSP-core CPU regression guard, 8.3 EQ ≤0.5 dB, 8.4 TSan **116/116**, 8.15 lifecycle) with **hardware/manual gates ⏳ PENDING USER** per `tasks/avplayer-native-video-dsp/verification.md` — 8.1 PASSED as a Debug regression guard; **8.1b (tapProcess 99p ≤10% on Release under Instruments) is UNVERIFIED**. **Phase 9 (UI audit + mandated docs + pre-PR Oracle + PR #C) is next** and may run in parallel with the user's manual gates, but PR #C must follow manual verification. S3-3 / S3-4 still queued behind the S3-2 PR.

**Locked S3 ordering and branch plan:**

| Wave | Step | Task Folder | Branch | PR # | Predecessors | Pre-Plan Spike | Status |
|------|------|-------------|--------|------|--------------|----------------|--------|
| S3-1 | A (parallel) | `done/mainwindow-visualizer-isolation` | `feat/mainwindow-visualizer-isolation` | **#80** | none | `spike/mwvi-volume-drag-profile` (Instruments) | ✅ **MERGED** 2026-04-28 |
| S3-1 | B (parallel) | `done/stream-pause-tail` | `fix/stream-pause-tail` | **#82** | none | none | ✅ **MERGED** 2026-04-30 (merge `b60fd57`) — Oracle 9/10 final, 68/68 TSan tests, manual smoke validated |
| ~~S3-2~~ | ~~sequential~~ | ~~`video-audio-engine-routing`~~ | ~~`feat/video-audio-engine-routing`~~ | ~~C~~ | — | — | ⏸ **PAUSED-AS-REFERENCE** 2026-05-01 at **Phase 7 PARTIAL** — Phases 0/1/2/3/5/6 ✅ Oracle-gated, Phase 4 a deliberate no-op (Path NONE), Phase 7's *code* half shipped (7 commits: SRC quality + 16K ring, watchdog gate v2, HAL default-output listener, burst-gate decoupling; static Oracle 9.2/10) but its *verification* half never ran — all 26 §7.1-§7.6 boxes unchecked and no `verification.md` was ever written. Killed by real-hardware AirPods testing: `AVAudioEngineConfigurationChange` does not fire for that route change, so the watchdog gate could not arm. Branch preserved at `5af91eb` (44 commits ahead of `main`, 110/110 TSan at pause), pushed to origin. The working-tree copy of `tasks/video-audio-engine-routing/state.md` is a pre-Phase-2 snapshot — the accurate record lives on the branch itself. See `_context/s3-2-pivot.md`. |
| S3-2 (pivot) | sequential | `avplayer-native-video-dsp` | `feat/avplayer-native-video-dsp` | C (not opened) | S3-1 merged ✅ + Phase 1 cherry-pick ✅ | `spike/avplayer-inplace-tap-dsp` ✅ done (branch still undeleted — close-out 10.3) | 🔧 **IMPLEMENTING** — HEAD `056c69a` (2026-06-27), 73 commits ahead of `main`, pushed to origin at `056c69a`; unmerged; PR #C not yet opened. Steps 1-3 ✅; **Phases 1-7 ✅** Oracle-approved; **Phase 8 automated gates ✅** (116/116 TSan; 8.1 is a Debug regression guard only — **8.1b production CPU UNVERIFIED**), hardware/manual gates ⏳ **PENDING USER** (`tasks/avplayer-native-video-dsp/verification.md`); **Phase 9 NEXT.** See `_context/s3-2-pivot.md`. |
| S3-3 | sequential | `hls-streaming-support` | `feat/hls-streaming-support` | D | S3-2 (pivot) merged | none (Gemini re-run optional at plan-time) | PLAN APPROVED |
| S3-4 | sequential | `ogg-vorbis-support` | `feat/ogg-vorbis-support` | E | S3-3 merged | `spike/ogg-build-wiring` (0a) + `spike/ogg-local-playback` (0b) | PLAN APPROVED |
| Post-S3-1A | follow-up | `done/timer-runloop-mode-audit` | `fix/timer-runloop-mode-audit` | **#81** | S3-1A merged ✅ | none | ✅ **MERGED** 2026-04-29 (merge commit `ac09dd4`) |

**Cross-task file conflict map:**

> Paths verified against HEAD `056c69a`. The S3-2 column is the **pivot** task `avplayer-native-video-dsp`, not the paused `vaer` branch; the pivot deliberately does **not** route video through `AVAudioEngine`, so `AudioEngineController.swift` is no longer a S3-2 conflict site.

| File | mwvi | spt | S3-2 (avplayer) | hls | ogg |
|------|:---:|:---:|:---:|:---:|:---:|
| `Views/MainWindow/MainWindowFullLayer.swift` | ✓ | | | | |
| `Audio/Streaming/StreamDecodePipeline.swift` | | ✓ | | ✓ | ✓ |
| `Audio/StreamPlayer.swift` | | ✓ | | ✓ | |
| `Audio/Streaming/AudioFileStreamParser.swift` | | | | ✓ | |
| `Audio/Streaming/AudioConverterDecoder.swift` | | ✓ | | | ✓ |
| `Audio/AudioEngineController.swift` | | ✓ | | | ✓ |
| `Audio/AudioPlayer.swift` | | ✓ | ✓ | | ✓ |
| `Audio/PlaybackCoordinator.swift` | | ✓ | ✓ | | |
| `Audio/VideoPlaybackController.swift` | | | ✓ | | |
| `Audio/VideoDSP/*` (VideoTap, VideoTapContext, BiquadCascade, BiquadCoefficientSet, VideoTapVisualizerRender) | | | ✓ | | |
| `Audio/RenderThreadSafe.swift`, `Audio/VisualizerFeed.swift`, `Audio/VisualizerScratchBuffers.swift`, `Utilities/WeakBox.swift` | | | ✓ | | |
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
| `done/mainwindow-visualizer-isolation` ✅ | ✅ 9/9 applied + Phase 0 results appended | ✅ | ✅ | **9.4/10** (plan); **8/10** (post-1B Oracle diagnostic); **9.3/10** (pre-PR code-review gate) | 4 + 1 + 1 → MERGED PR #80 |
| `done/stream-pause-tail` ✅ | ✅ 8/8 applied | ✅ (8 ADRs) | ✅ | **9.1/10** plan; **9/10** final impl | 5 plan + 9 impl → MERGED PR #82 |
| ~~`video-audio-engine-routing`~~ (PAUSED) | ✅ existing | ✅ | ✅ | **9.4/10** | 3 |
| `avplayer-native-video-dsp` (S3-2 pivot) | ✅ + 5 research-notes | ✅ 15 sections, 11+1 ADRs | ✅ | research **10/10**; plan **9.8/10**; implementation Ph2 9.0, Ph3 9.6, Ph4 9.6, Ph5 10, Ph6 9, Ph7 9; **Phase 8 round 1 = 7/10, fixes applied in `944795a`, no post-fix re-score recorded** | 5 research + 5 plan |
| `hls-streaming-support` | ✅ 8/8 applied | ✅ | ✅ | **9.0/10** | 4 |
| `ogg-vorbis-support` | ✅ 10/10 applied | ✅ (22 sections) | ✅ | **9.3/10** | 3 |

**S3 progress:** Wave S3-1 ✅ COMPLETE (mwvi PR #80 + spt PR #82 both merged). S3-2 is now the pivot task `avplayer-native-video-dsp` (vaer PAUSED-AS-REFERENCE) — 🔧 IN PROGRESS: Phases 1-7 ✅, Phase 8 automated gates ✅ with manual/hardware gates pending user, **Phase 9 next**, branch pushed to origin at `056c69a`; unmerged; PR #C not yet opened. S3-3 / S3-4 remain queued behind the S3-2 PR, and the post-S3 Structure Sprint behind all three.

**S3-2 pending items (everything downstream of S3 is gated on these) — as of 2026-09-05:**

| Bucket | Items | Owner |
|--------|-------|-------|
| Phase 8 hardware/manual gates | 8.1b (Release + Instruments **production** CPU — the real ≤10% gate, currently **UNVERIFIED**; expect a PARTIAL result, since Time Profiler reports an aggregate share rather than a literal 99p and `VideoTap.swift:112` samples 1-in-64 into only two bucket counters), 8.2 (Intel build — N/A, no Intel Mac), 8.5-8.14 (≥10 min A/V drift, AirPods 1st-gen / AirPods Pro / AirPlay-1 / AirPlay-2 route changes, HDMI output switch, BT codec switch, optional format re-prepare, 5.1 surround, video↔audio replacement), 8.5b-8.5e (live EQ/preamp/balance drag, seek/scrub, visualizer-mode switch, telemetry readout), plus todo 6.10 (heavy-EQ stress) and 7.9/7.10 (signed-bundle build + 1-min smoke) | **USER** — checklist at `tasks/avplayer-native-video-dsp/verification.md` |
| Phase 9 (not started) | 9.1-9.3 video-window UI audit; 9.4-9.6 mandated docs ("Audio Mechanism Concurrency Contract" in `docs/MACAMP_ARCHITECTURE_GUIDE.md`, "Audio DSP Architecture" in `docs/VIDEO_WINDOW.md`) per `tasks/avplayer-native-video-dsp/docs-update-backlog.md` (⚠️ that backlog's own header constraint is itself stale — it says Swift 6.2 / macOS 26.x+, whereas the toolchain is Xcode 27 / Swift 6.4 and the deployment target is macOS 15.0; do not copy its toolchain language into `docs/`); 9.7-9.8 smoke + full TSan; 9.9-9.10 pre-PR Codex Oracle; 9.11-9.14 commit + `gh pr create` (**PR #C not opened**; 9.12's push is already done — the checkbox is stale) + human review | Claude — may run in parallel with the manual gates; PR #C follows them |
| Post-merge close-out | 10.1-10.8 — update this file, `tasks_index.md`, `resume-prompt.md`; mark `_context/s3-2-pivot.md` RESOLVED; `git mv` the task folder into `tasks/done/`; delete the throwaway `spike/avplayer-inplace-tap-dsp` branch (still present locally, contrary to the spike policy above) | Claude, after PR #C merges |

**Standing rule (todo 8.17, unchecked):** any manual gate FAILURE must produce an ADR amendment + a targeted retry — never a soft-skip.

**Honesty caveat on the CPU gate:** the automated 8.1 that passed is a **Debug (`-Onone`) DSP-core regression guard** (p99 ≈11% / max ≈13% of the 21,333 µs deadline for a synthetic microbenchmark), not the production figure. The plan's real gate is **8.1b** (Release build + Instruments Time Profiler, tapProcess 99p ≤10%) and it has **not** been run. Never compress this to "the CPU gate passed".

**Known open discrepancy:** Phase 2's close is recorded as 85/85 tests in `_context/s3-2-pivot.md:111` and `tasks/avplayer-native-video-dsp/state.md:51`, but as 74/74 in that task's todo (74/74 vs 85/85 discrepancy — open item for Phase 9 pre-PR Oracle). Historical per-phase close counts inside dated blocks (72/85/89/92/93/98/103/110/115) are correct snapshots; only the **current** count is 116/116.

**Open placeholders at HEAD:** P-2 (Mirror `~Copyable` gap), P-3 (`@preconcurrency import AVFoundation`), P-6 (video→audio no auto-play; non-blocking, surfaced in gate 8.14). P-1 (real struct, `24f8a12`), P-4 (Mutex install path, Phase 3) and P-5 (`c040e76`) are RESOLVED.

### Post-S3-1A Follow-Ups (discovered during mwvi)

| Task Folder | Description | Size | Status | Trigger |
|-------------|-------------|------|--------|---------|
| `done/timer-runloop-mode-audit` | Normalized all 6 non-Pattern-A `Timer.scheduledTimer` callsites onto Pattern A (`Timer(timeInterval:...)` + `RunLoop.main.add(.common)`). Original audit (3 buggy) was textually inconsistent — corrected at HEAD: 1 Pattern A + 4 Pattern B + 2 buggy. Scope expanded to 6-callsite consistency pass; the 2 LOW Butterchurn bugs fixed as a side-effect. The marquee freeze claimed HIGH-severity in the original audit was already correct on `main` (Pattern B works functionally). | Small (~36 LOC code + 4 task-doc revisions) | ✅ **MERGED** PR #81, merge commit `ac09dd4` (2026-04-29). Codex Oracle 9/10. CodeRabbit feedback addressed. | Discovered during mwvi diagnosis (2026-04-28). |

**mwvi-derived lessons (cross-task):**

- **End-to-end pipeline diagnosis** — Symptoms manifest at the consumer; root causes often live at the producer. Phase 0 instrumented only the SwiftUI consumer side; the actual root cause was upstream at `VisualizerPipeline.pollTimer`. See `~/.claude/projects/-Users-hank-dev-src-MacAmp/memory/feedback_pipeline_end_to_end_diagnosis.md` and `BUILDING_RETRO_MACOS_APPS_SKILL.md`.
- **ast-grep structural search before edits** — relying on `rg` text matching alone missed a duplicate `videoPlaybackController.volume` write and dead `streamPlayer.volume`/`.balance` properties. See `~/.claude/projects/-Users-hank-dev-src-MacAmp/memory/feedback_ast_grep_structural_search.md`.

### Post-S3-1B `stream-pause-tail` Follow-Ups (discovered during this task — Lows deferred)

| Task | Description | Size | Priority | Status |
|------|-------------|------|:--------:|--------|
| `streamdecodepipeline-stop-generation-guard` | `StreamDecodePipeline.stop()` fires `onTermination?(.userStopped)` without a generation guard. Benign double-fire only when `wasActivelyPlaying=false` is already cleared by callers; not a present bug, but a generation guard would close the theoretical hole. | Trivial | Low | 🟡 DEFERRED |
| `audioconverterdecoder-confinement-doc` | `AudioConverterDecoder.clearQueue()` is decode-queue-confined via `assertConfinement()`, but the assertion is debug-only. Release builds would silently corrupt memory if a future caller invokes it off-queue. Doc gap, not a present bug. | Trivial | Low | 🟡 DEFERRED |

### Post-S3-1A `timer-runloop-mode-audit` Follow-Ups (discovered during this task)

| Task Folder | Description | Size | Status | Trigger |
|-------------|-------------|------|--------|---------|
| `timer-scheduled-on-common-extension` | Extract `Timer.scheduledOnMainCommon(every:repeats:_:)` helper into `MacAmpApp/Utilities/Timer+CommonMode.swift`. Migrate all 7 timer-on-RunLoop callsites in `MacAmpApp/` (`VisualizerPipeline.pollTimer`, `AudioEngineController.progressTimer`, `StreamPlayer.elapsedTimer`, `VideoWindowChromeView.metadataScrollTimer`, `WinampMainWindowInteractionState.scrollTimer`, `ButterchurnPresetManager.cycleTimer`, `.trackTitleTimer`) to use it. Eliminates the 3-line + 1-comment ritual at every callsite and makes the `.common`-mode requirement impossible to forget on new code. | Small-Medium (~30 LOC helper + 7 callsite migrations + `project.yml` resource entry) | 🟡 **DEFERRED** — predecessor `timer-runloop-mode-audit` merged 2026-04-29 ✅; ready when scheduled. Codex Oracle endorsed deferring (Problem-First + API Surface Minimization). Concurrency-checker edge cases possible (`@Sendable` closure capture interactions with existing `[weak self]` and `MainActor.assumeIsolated` patterns) — warrant their own review. Task folder not yet created. | Discovered during `timer-runloop-mode-audit` (2026-04-29). With 7 Pattern-A callsites now in `MacAmpApp/`, AHA Rule-of-Three is exceeded by 4×. |

### Post-S3-2 `avplayer-native-video-dsp` Findings (in-progress task)

| Finding | Description | Size | Status |
|---------|-------------|------|--------|
| Video→audio no auto-play | After a video plays, loading an audio track does not auto-play (user must hit Next/forward). Audio→audio is fine. Discovered during todo 2.40 leak check (2026-05-28). Logged at task level as `tasks/avplayer-native-video-dsp/placeholder.md` P-6. Suspected: `.video→.audio` cleanup leaves transport state that no-ops the `play()`, or async `loadAudioFile` races the immediate `play()`. | Small | 🟡 NON-BLOCKING — **STILL OPEN.** Phase 7 closed 2026-06-26 (Oracle 9/10) without diagnosing it, so the prescribed window has passed. Now carried as an expected known-issue caveat inside Phase 8 manual gate 8.14 (`verification.md`) and as a Phase 9 docs item. Needs a dedicated follow-up task. |

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
| 1 | `streamdecodepipeline-decomposition` | **DEFERRED.** DecodeContext extraction requires `private → internal` (Principle 5). 697 lines at the 2026-03-25 sweep; **825 lines at HEAD `056c69a` (and already 825 on `main`)** — the row's own "if the file grows" re-evaluation trigger has fired. One responsibility, architecturally sound per sweep. Same principle applied to cancel SkinManager Step 4 and VisualizerPipeline. | N/A | **DEFERRED** | Re-evaluate if file grows or gains new responsibility |
| 2 | `winamp-equalizer-window-decomposition` | Selective: extracted WinampVerticalSlider + EQPresetPickerView. Full layer split cancelled (verbose SwiftUI). 616→354 lines. | Small | **COMPLETE** (PR #76) | Done |
| 3 | `visualizerpipeline-decomposition` | ~~4 new files~~ → Cancelled (private @unchecked Sendable surface risk) | N/A | **NO-GO** | N/A |
| 4 | `skinmanager-decomposition` | Steps 1-3 done (ArchiveLoader, Import). Preprocessor removed (skin artifact bug). Step 4 cancelled (visibility leak). 766→454 lines. | Medium | **COMPLETE** (PR #75 merged 2026-03-25) | Done |
| 5 | `audioplayer-seek-extraction` | **DEFERRED (Option C) — ⚠️ FALLBACK TRIGGER FIRED, needs re-evaluation.** 734 lines at decision time; **1,079 lines at HEAD `056c69a`** after S3-2 video-DSP wiring, past the 800-line Option-B threshold. One responsibility (facade). Accept swiftlint suppressions. The Option-B revisit condition ("grows past 800 lines during S3") is **already met**, so the lean SeekController design (direct engine refs, 2 callbacks max) is due for re-evaluation once the S3-2 PR merges. | N/A | **DEFERRED — trigger fired** | Re-evaluate after the S3-2 PR merges |

**Responsibility sweep (2026-03-25, PR #74):** 5-agent SRP + AHA audit of all 109 files. Result: 76 Clean, 26 Justified, 7 Actionable. Applied Swift Architecture & Decomposition principles (Cohesion > LOC, AHA Rule of Three, no visibility leaks, no pass-through middlemen). 4 of 5 original decomposition plans revised or cancelled. See `tasks/responsibility-sweep/research.md`.

**Revised Phase 2b scope:** ~5 new files (was ~18). Dead code cleanup: PresetsButton.swift, WinampButtonStyle.swift, WinampAlertHelper.promptText, SkinBackgroundPreprocessor (caused skin artifacts, removed). New opportunity: WindowSizeState protocol (3x persistence duplication).

**Phase 2c deferred items:** ~~SkinManager sprite extraction loop dedup, NUMS_EX move to SkinSprites.swift~~ — **RESOLVED in PR #76** (`extractSprites` helper + `SkinSprites.numsExSprites`).

### D8: AudioPlayer — Defer seek extraction (Option C, 2026-03-25)

**Decision (2026-03-25):** AudioPlayer.swift (734 lines at the time) stays as-is. **Status 2026-09-05: the Option-B fallback trigger below has fired — the file is 1,079 lines at HEAD `056c69a`.** The responsibility sweep confirmed it has one cohesive responsibility (local audio playback orchestration). The swiftlint suppressions (file_length + type_body_length) are threshold mismatches, not architecture signals.

**Rationale:** Per Principle 1 (Problem-First), there is no concrete failure mode — no merge conflicts, no independent change vectors, no tangled state machines. The seek state (`currentSeekID`, `seekGuardActive`, `isHandlingCompletion`) is tightly coupled to play/stop/onPlaybackEnded. The 6-callback SeekController pattern would create pass-through indirection.

**Fallback (Option B) — ⚠️ TRIGGERED (2026-09-05):** AudioPlayer did grow past 800 lines during S3 — **1,079 lines at HEAD `056c69a`** (763 on `main`), via the S3-2 pivot `avplayer-native-video-dsp` (not the paused `video-audio-engine-routing`). Re-evaluate after the S3-2 PR merges, with a lean SeekController design: give it direct references to `engine` and `videoPlaybackController` instead of callbacks, reducing to ~2 callbacks (`onRequestNextTrack`, `onPlaylistAdvanceRequest`). This eliminates the pass-through middleman concern while still extracting the seek state machine as an atomic unit.

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

### Post-Structure-Sprint (S4) — added 2026-09-05

Two new roadmap tasks, both sequenced **after** the Post-S3 Structure Sprint above (which itself starts only after S3-4 `ogg-vorbis-support` merges). Both task folders were scaffolded 2026-09-05 with the canonical layout (`state.md`, `research.md`, `todo.md`, `placeholder.md`, `depreciated.md`); no research has started in either. See D-S4 above and the "Post-Structure-Sprint (S4)" section of `_context/tasks_index.md`.

| Task Folder | Description | Size | Status | Dependency |
|-------------|-------------|------|--------|------------|
| `swift64-macos27-readiness` (S4-1) | Research-first readiness pass for **Swift 6.4 language mode + macOS 27**. Installed toolchain is Xcode 27.0 (`27A5194q`) / Swift 6.4 on host macOS 27.0 (`26A5425a`); the project pins `SWIFT_VERSION` 6.2, swift-tools-version 6.2 and a macOS 15.0 deployment target, and `project.yml` still declares `xcodeVersion: 26.0` (cosmetic, known). Four research questions: (a) what flips when `SWIFT_VERSION` → 6.4 (concurrency defaults, stdlib additions such as `InlineArray`/`Span`, deprecations, strict-concurrency diagnostics) and what that means for the ADR-3a `@unchecked Sendable` containment and the `Synchronization.Atomic`/`Mutex` usage in `Audio/VideoDSP/`; (b) what's new in SwiftUI on macOS 26/27 that MacAmp can adopt; (c) what macOS 27 adds/deprecates for AppKit (Liquid Glass), toolbars, WebKit-in-SwiftUI (Butterchurn runs in WebKit), AVFoundation/`MTAudioProcessingTap`, AVAudioEngine; (d) whether to raise the deployment target (15 → 26 or 27) and what that unlocks/breaks for skins + windowing. **Key deliverable: a deployment-target ADR.** No code before plan Oracle ≥ 9. | Medium | 📋 **QUEUED** — folder scaffolded 2026-09-05; research not started | Post-S3 Structure Sprint (implementation half only — see the allowance below) |
| `github-issues-triage` (S4-2) | Triage and fix the issues other users filed on `hfyeomans/MacAmp`, so the fixes land in the new post-Structure-Sprint layout. One branch/PR per issue, each Oracle-gated. Issue list below. | Medium-Large | 📋 **QUEUED** — folder scaffolded 2026-09-05; research not started | Post-S3 Structure Sprint (user mandate) + S4-1 (**assumption**) |

**S4-2 issue list (open on `hfyeomans/MacAmp` as of 2026-09-05; `gh issue list` shows no recently closed issues):**

| # | Filed | Author | Title | One-line |
|---|-------|--------|-------|----------|
| #84 | 2026-05-16 | @morozov | Nucleo NLog v2G rendering defects | Classic-skin rendering defects surfaced by the Nucleo NLog v102 skin; everything renders correctly under the default skin |
| #79 | 2026-04-11 | @MatteAce | Can't drag files, or open by doubleclick | Drag onto the window, onto the Dock, and onto the app icon all do nothing. Related UX gap: Cmd+O restricts the open panel to `[.audio]` (`AppCommands.swift:99`) |
| #78 | 2026-04-08 | @Crater-Dude | Windows can't be permanently joined/clamped, no minimization | Moving the player detaches the playlist; minimization doesn't work; wants full window-state persistence (the EQ window closes on every launch). **Likely the largest of the four — touches windowing, so it benefits most from the Structure Sprint having landed** |
| #47 | 2026-02-10 | @hfyeomans | Keyboard shortcut conflict: Cmd+Shift+1-3 (skins vs window toggles) | Same chord bound twice |
| P-6 | 2026-05-28 | internal | Video→audio transition does not auto-play | Folded in from `tasks/avplayer-native-video-dsp/placeholder.md` (non-blocking; surfaced in Phase 8 gate 8.14). Also tracked in the "Post-S3-2 `avplayer-native-video-dsp` Findings" section above |

**Ordering assumption (pending user confirmation).** The user mandated only that the GitHub-issue fixes come *after* the `.swift` rearrangement. Running **S4-1 before S4-2** is our inference: S4-1's deprecation findings may change how the S4-2 issues are fixed, so the reverse order risks reworking fresh fixes. Confirm with the user before scheduling.

**Allowance.** S4-1's **research half touches no code** and may run opportunistically earlier (during S3 or the Structure Sprint); only its implementation half is gated on the Structure Sprint. S4-2 stays hard-gated behind the Structure Sprint.

---

## Future Considerations: HLS Video (Out of Current Roadmap)

> **Naming clarification:** S3-2 (now `avplayer-native-video-dsp`; formerly the paused `video-audio-engine-routing`) addresses local video files only. S3-3 (`hls-streaming-support`) addresses HLS *audio*-only streams (radio `.m3u8` referencing AAC-ADTS segments). **HLS video is not on the roadmap** — neither task touches it. This section captures the constraints and trade-offs for any hypothetical future HLS-video task so we don't re-derive them under deadline pressure.

### Platform constraint (permanent, not negotiable)

`MTAudioProcessingTap` is documented (Apple QA1716) and empirically validated (during T7 unified-audio-pipeline research) to **not fire reliably for streaming AVPlayerItems**. This means HLS video *audio* cannot be intercepted and routed through `AVAudioEngine`. The S3-2 tap-based architecture therefore cannot be extended to HLS video — this is a platform limit, not an engineering choice.

### What HLS video CAN do today / would do in a future task

- AVPlayer plays HLS video natively. A future task would only need to (a) teach `detectMediaType` to probe `.m3u8` contents and distinguish video-bearing from audio-only HLS, and (b) route video-bearing HLS to `VideoPlaybackController` instead of `StreamDecodePipeline`. ~50 LOC.
- HLS video would play with audio, but **without EQ, visualizer, or balance** — the user-visible failure modes that S3-2 fixes for local video would resurface for HLS video. This is the "UI lie" problem (controls visible but silently no-op).

### Three options for future HLS-video work (decision deferred)

1. **Ship with the UI lie** — EQ window and balance slider remain enabled but silently no-op for HLS video. Net regression in UI honesty vs S3-2 goals. **Not recommended** — undoes the consistency win S3-2 buys for local video.

2. **Ship with capability-flag dimming (recommended if/when HLS video is implemented)** — extend `PlaybackCoordinator.supportsAudioProcessing` (the single capability flag introduced by S3-2) with a fourth branch: `if currentMediaType == .video && currentMediaSource == .hls` ⇒ false. EQ window dimmed, balance slider dimmed, visualizer paused. User gets HLS video playback with honest UI affordances. ~50 LOC of new wiring + capability-flag changes; no audio-engine plumbing. Reuses everything S3-2 builds.

3. **Don't ship HLS video at all** — explicitly reject HLS-video URLs at media-type detection time with a non-reconnectable error message. Most pragmatic if HLS video is rarely encountered in real Winamp use (Winamp was historically an audio app). Keeps the codebase smaller, avoids the platform constraint entirely.

### When to revisit

- A user-reported demand signal for HLS video specifically (no current evidence)
- A related task that makes bundling natural (e.g., a future `Features/Video/` consolidation in the post-S3 Structure Sprint)
- macOS / AVFoundation API changes that lift the QA1716 constraint (unlikely; the constraint has been stable since macOS 10.9)

Until one of those triggers, the codebase status quo is: HLS-video URLs hit MacAmp → mishandled by the legacy M3U parser → visible failure (same bug S3-3 fixes for HLS audio, just unfixed for video). Acceptable as a known limitation given there's no evidence of demand.

---

## Resolved Questions

| # | Question | Resolution |
|---|----------|------------|
| 1 | Should T4+T6 be single or separate PRs? | **Single PR** (D6) |
| 2 | Is T1 Phase 4 in scope? | **Deferred** (D3) after T7 (unified-audio-pipeline), then **DONE** — executed in Sprint S1, merged PR #60 (2026-03-22) |
| 3 | Wave 2: one or two Claude instances? | **One instance, two sequential PRs** (D5) |
| 4 | swift-tools-version 6.0 or 6.2? | **6.2** — matches installed toolchain (6.2.4) |

---

## Artifact Inventory

| File | Status |
|------|--------|
| `_context/research.md` | Complete (verified, corrections applied) |
| `_context/plan.md` | Complete (verified, corrections applied) |
| `_context/state.md` | Active (this file — updated 2026-09-05, S3-2 Phase 8 automated gates done / manual pending, Phase 9 next; S3-2 pending-items table + 2 deferred-item rows added; T4 close-out corrected to PR #50; 2 broken table blocks rejoined. Later the same day: **D-S4** + the "Post-Structure-Sprint (S4)" subsection added — S4-1 `swift64-macos27-readiness`, S4-2 `github-issues-triage`, both folders scaffolded) |
