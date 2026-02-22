# Tasks Index

> **Purpose:** Index of all currently open (non-done) tasks in `tasks/`. Each entry notes the task name, purpose, creation date, last activity, and current status.
>
> **Today:** 2026-02-22
> **Excludes:** `tasks/done/` and `tasks/depreciated/`

---

## Legend

| Status | Meaning |
|--------|---------|
| ✅ COMPLETE | Work done, may need commit/merge/close |
| 🔄 IN PROGRESS | Active implementation underway |
| ⏸ BLOCKED | Waiting on prerequisite task or decision |
| 🟡 DEFERRED | Postponed to future milestone |
| 📋 PLANNED | Research/planning done, awaiting implementation |
| 🔍 RESEARCH | Early-stage research/analysis task |
| 📄 REFERENCE | Documentation/analysis artifact, not an implementation task |

---

## Active / Recent Tasks (Last 30 days)

| Task | Purpose | Created | Last Activity | Days Idle | Status |
|------|---------|---------|---------------|-----------|--------|
| `internet-radio-n1-n6-fixes` | Fix 6 issues (1 HIGH, 2 MEDIUM, 3 LOW) in internet radio streaming infrastructure discovered during Oracle validation | 2026-02-21 | 2026-02-21 | 0 | ✅ COMPLETE — All 6 fixes implemented, Oracle-verified, merged in PR #49 |
| `mainwindow-layer-decomposition` | Decompose WinampMainWindow from cross-file extension pattern to proper layer subview decomposition with @Observable interaction state object | 2026-02-21 | 2026-02-21 | 0 | 📋 PLANNED — Research complete (Gemini + Oracle converged), 4-phase plan written, awaiting implementation approval |
| `playlistwindow-layer-decomposition` | Decompose WinampPlaylistWindow from cross-file extension pattern to proper layer subview decomposition; same architectural pattern as mainwindow task | 2026-02-21 | 2026-02-22 | 0 | ✅ COMPLETE — Wave 1. 4 phases done, Oracle reviewed, PR merged. Extension deleted, 7 child views created. |
| `swift-testing-modernization` | Migrate all 9 test files (40 tests) from XCTest to Swift Testing framework; bump Package.swift to 6.2; add parameterized tests, tags, time limits | 2026-02-21 | 2026-02-22 | 0 | ✅ COMPLETE — Wave 1. 6 phases done, Oracle reviewed, PR merged. Task.sleep removal deferred. |
| `audioplayer-decomposition` | Extract EqualizerController from AudioPlayer.swift using facade pattern (Phases 1-3) | 2026-02-07 | 2026-02-22 | 0 | ✅ COMPLETE — Wave 1. Phases 1-3 done (1,070→945 lines), Phase 4 deferred (seek state machine risk). PR merged. |
| `internet-streaming-volume-control` | Add volume control + EQ capability for internet radio streams; includes Loopback Bridge architecture for Phase 2 | 2026-02-09 | 2026-02-21 | 1 | 📋 PLANNED — Wave 2 (Ph1) + Wave 3 (Ph2). N1-N6 resolved, Wave 1 prereqs merged. Ready for Phase 1. |
| `internet-radio-review` | Oracle code review of internet radio streaming infrastructure; produces N1-N6 issue list | 2026-11-01 | 2026-02-21 | 1 | 📄 REFERENCE — Validation complete post-memory-optimization; findings drive `internet-streaming-volume-control` |
| `memory-cpu-optimization` | Reduce memory usage and CPU overhead; SPSC audio thread, lazy skin loading, peak-memory reduction | 2026-02-14 | 2026-02-14 | 8 | ✅ COMPLETE — All phases verified, committed in PR #48 |
| `window-coordinator-cleanup` | Clean up `WindowCoordinator.swift` — remove dead code, fix threading, improve structure | 2026-02-09 | 2026-02-09 | 13 | ✅ COMPLETE — Pending manual testing + commit |
| `window-coordinator-refactor` | Extract `WindowRegistry`, `WindowFramePersistence`, `WindowVisibilityController` from `WindowCoordinator` | 2026-02-09 | 2026-02-09 | 13 | ✅ COMPLETE — All 4 phases committed, production-ready |
| `window-coordinator-di-migration` | Migrate `WindowCoordinator` to dependency-injection pattern | 2026-02-09 | 2026-02-09 | 13 | 🟡 DEFERRED — Research + plan done; blocked on prerequisite task completion |
| `lock-free-ring-buffer` | Implement a lock-free SPSC ring buffer for audio thread safety; prerequisite for `internet-streaming-volume-control` Phase 2 | 2026-02-09 | 2026-02-22 | 0 | ✅ COMPLETE — Wave 1. 17 tests (14 unit + 3 concurrency), Oracle reviewed x2, PR merged. Benchmarks deferred. |
| `airplay-integration` | Add AirPlay audio output routing + Now Playing integration | 2026-02-07 | 2026-02-07 | 12 | 📋 PLANNED — Research complete, Oracle reviewed (8.5/10), awaiting user approval |

---

## January 2026 Tasks

| Task | Purpose | Created | Last Activity | Days Idle | Status |
|------|---------|---------|---------------|-----------|--------|
| `phase-8-6-audioenginecontroller-analysis` | Deep analysis of `AudioEngineController` architecture; Phase 8.6 of audio refactor | 2026-02-07 | 2026-01-11 | 39 | 📄 REFERENCE — Analysis complete, findings documented |
| `phase-8-5-visualizerpipeline-review` | Review of `VisualizerPipeline` extraction; Phase 8.5 of audio refactor | 2026-02-07 | 2026-01-11 | 39 | 📄 REFERENCE — Review complete, no code changes required |
| `oracle-validation-audioplayer-refactor` | Oracle validation of AudioPlayer refactor results; verify metrics and API naming | 2026-02-07 | 2026-01-11 | 39 | ⏸ BLOCKED — Mismatch between docs (`savePreset(:for:)`) and code (`savePreset(_:forTrackURL:)`) requires resolution |
| `butterchurn-data-flow-verification` | Verify Butterchurn/MilkDrop data flow from `VisualizerPipeline` through `AudioPlayer` to `ButterchurnBridge` | 2026-02-07 | 2026-01-11 | 39 | 📄 REFERENCE — Flow mapped, guard conditions identified, verification guidance delivered |
| `code-optimization` | Code simplification sweep on `code-simplification` branch | 2026-01-11 | 2026-01-11 | 39 | 🔍 RESEARCH — State incomplete; current phase unclear |
| `concurrency-review` | Swift concurrency audit; findings documented | 2026-11-01 | 2026-01-11 | 39 | 📄 REFERENCE — Findings only (`findings.md`), no state file |
| `swift6-concurrency-review` | Swift 6 strict concurrency review of Butterchurn/MilkDrop code | 2026-01-05 | 2026-01-05 | 45 | 📄 REFERENCE — Review findings to be delivered; no code changes required |
| `milk-drop-video-support` | Full MilkDrop + Video window feature: chrome, titlebar, resize, Butterchurn rendering | 2025-11-08 | 2026-01-05 | 45 | 🔄 IN PROGRESS — Days 1-2 complete; multiple sub-tasks partially done |
| `xcode-testing-context` | Set up Xcode testing context document for MacAmp test suite | 2026-01-04 | 2026-01-04 | 46 | ✅ COMPLETE — Doc created at `docs/context/xcode-testing-context.md` |
| `macamp-test-actions-plan` | Add MacAmpTests target, test plan, and shared scheme to Xcode project | 2026-01-04 | 2026-01-04 | 46 | ✅ COMPLETE — Test target, scheme, and `.xctestplan` wired |
| `docs-test-actions` | Update architecture docs (README, IMPLEMENTATION_PATTERNS, MACAMP_ARCHITECTURE_GUIDE) with test plan references | 2026-01-04 | 2026-01-04 | 46 | ✅ COMPLETE — All doc updates applied |

---

## December 2025 Tasks

| Task | Purpose | Created | Last Activity | Days Idle | Status |
|------|---------|---------|---------------|-----------|--------|
| `memory-management-analysis` | Audit and fix audio tap lifecycle, visualizer buffer allocations, timer leaks, skin extraction memory | 2026-11-01 | 2026-01-03 | 47 | ✅ COMPLETE — Fixes implemented; may be superseded by `memory-cpu-optimization` |
| `review-amp-code-review-report` | Review and respond to external amp code-review report | 2026-01-04 | 2025-12-28 | 53 | 📄 REFERENCE — Review completed |
| `playlist-window-resize` | Implement playlist window resize behavior with proper sprite stretching | 2026-11-01 | 2025-12-16 | 65 | ✅ COMPLETE — Phases 3-5 done + playlist visualizer implemented |
| `playlist-resize` | Research/analysis artifact for playlist resize implementation | 2025-12-16 | 2025-12-16 | 65 | 📄 REFERENCE — Status unclear; overlaps with `playlist-window-resize` |
| `code-review-sweep` | Broad code review sweep across codebase | 2025-12-14 | 2025-12-14 | 67 | 🔄 IN PROGRESS — Phases 1-3 complete |

---

## November 2025 Tasks

| Task | Purpose | Created | Last Activity | Days Idle | Status |
|------|---------|---------|---------------|-----------|--------|
| `window-architecture-assessment` | Assess overall window architecture; produce recommendations | 2025-11-16 | 2025-11-16 | 95 | 📄 REFERENCE — Assessment complete |
| `swiftui-window-migration` | Research whether to migrate NSWindow to SwiftUI WindowGroup | 2025-11-16 | 2025-11-16 | 95 | ✅ CLOSED — Decision: do NOT migrate |
| `preferences-windowgroup-architecture` | Plan preferences window using SwiftUI WindowGroup architecture | 2025-11-16 | 2025-11-16 | 95 | 📄 REFERENCE — Technical debt noted |
| `window-focus-tracking` | Implement focus tracking across Winamp windows | 2025-11-15 | 2025-11-15 | 96 | 🔍 RESEARCH — Only `TODO.md` present |
| `video-window-sprites` | Sprite sheet analysis and coordinate fixes for video window chrome | 2025-11-15 | 2025-11-15 | 96 | 🔍 RESEARCH — No state file found |
| `video-window-review` | Review video window implementation for correctness | 2025-11-15 | 2025-11-15 | 96 | 🔍 RESEARCH — Initial review pass started |
| `video-window-focus` | Fix focus handling for video window | 2025-11-15 | 2025-11-15 | 96 | 🔍 RESEARCH — No state file found |
| `swift-6-features` | Research and document Swift 6 language features for team awareness | 2025-11-15 | 2025-11-15 | 96 | ✅ COMPLETE — Research + explanation delivered |
| `o-i-buttons-review` | Review O (Options) and I (Info) button implementation (persistence, SwiftUI wiring, NSMenu) | 2025-11-15 | 2025-11-15 | 96 | 📋 PLANNED — Research complete, awaiting detailed review findings |
| `milkdrop-window-precision-fixes` | Pixel-precise layout fixes for MilkDrop window sprites and drag handle | 2025-11-15 | 2025-11-15 | 96 | ⏸ BLOCKED — Needs QA/user verification in running app |
| `milkdrop-window-layout` | Fix GEN sprite layout (left-side fill tiles, redundant overlays, bottom corners) | 2025-11-15 | 2025-11-15 | 96 | 📋 PLANNED — Fixes applied, follow-up items remain |
| `milkdrop-titlebar` | Fix MilkDrop titlebar sprite layout and section widths | 2025-11-15 | 2025-11-15 | 96 | ✅ COMPLETE — Section widths corrected, manual verification needed |
| `milkdrop-rendering-bug` | Fix Butterchurn/MilkDrop rendering (missing `test.html`, silent load failures) | 2025-11-15 | 2025-11-15 | 96 | ⏸ BLOCKED — Code fix applied, runtime verification required |
| `milkdrop-gen-sprites` | Analyze and correct GEN sprite coordinate system for MilkDrop window | 2025-11-15 | 2025-11-15 | 96 | 📋 PLANNED — Coordinates corrected, awaiting flip-logic implementation decision |
| `milkdrop-chrome-alignment` | Fix MilkDrop chrome positioning (titlebar slices, bottom tri-part joint) | 2025-11-15 | 2025-11-15 | 96 | ⏸ BLOCKED — Layout fixed, needs in-app visual verification |
| `focus-ring-eq-pl-fixes` | Fix focus ring appearance and EQ/PL button behavior | 2025-11-15 | 2025-11-15 | 96 | 🔍 RESEARCH — Committed on `feature/video-milkdrop-windows` branch (commit `1306b2e`) |
| `five-window-docs` | Documentation guidance for five-window architecture (main, EQ, playlist, video, MilkDrop) | 2025-11-15 | 2025-11-15 | 96 | 📋 PLANNED — Guidance produced; user to implement doc updates |
| `default-skin-fallback` | Extract and cache Winamp.wsz as default skin fallback for missing sheet resources | 2025-11-15 | 2025-11-15 | 96 | 📋 PLANNED — Research + plan done, awaiting architectural sign-off |
| `audio-video-playback-bug` | Fix bug where old completion handler fires during seek, causing incorrect playback state | 2025-11-15 | 2025-11-15 | 96 | 📋 PLANNED — Root cause identified (`playerNode.stop()` seek ID race), awaiting implementation |
| `window-init-position-bug` | Fix window initial position regression | 2025-11-10 | 2025-11-10 | 101 | 🔍 RESEARCH — No state file found |
| `window-default-position-regression` | Fix default window position regression | 2025-11-10 | 2025-11-10 | 101 | 🔍 RESEARCH — No state file found |
| `winamp-titlebar-regression` | Fix Winamp titlebar visual regression | 2025-11-10 | 2025-11-10 | 101 | 🔍 RESEARCH — No state file found |
| `playlist-resize-analysis` | Analysis artifact for playlist resize; quick reference and README | 2025-11-10 | 2025-11-10 | 101 | 📄 REFERENCE — Research artifact |
| `playlist-docking-debug` | Debug playlist window docking behavior | 2025-11-10 | 2025-11-10 | 101 | 🔍 RESEARCH — No state file found |
| `phase-4-regression-analysis` | Analyze regressions introduced in Phase 4 | 2025-11-10 | 2025-11-10 | 101 | 📄 REFERENCE — Analysis complete |
| `main-eq-stack-bug` | Fix bug in main/EQ window stacking order | 2025-11-10 | 2025-11-10 | 101 | 🔍 RESEARCH — No state file found |
| `magnetic-window-cluster-regression` | Fix regression in magnetic window cluster behavior | 2025-11-10 | 2025-11-10 | 101 | 🔍 RESEARCH — No state file found |
| `magnetic-docking-foundation` | Foundation implementation for magnetic window docking system | 2025-11-10 | 2025-11-10 | 101 | 🔄 IN PROGRESS — Day 1 80% complete; code ready, needs Xcode project integration |
| `custom-drag-analysis` | Analyze custom drag gesture implementation for magnetic docking | 2025-11-10 | 2025-11-10 | 101 | 🔍 RESEARCH — No state file found |
| `session-storage-location` | Determine correct session/state storage location | 2025-11-07 | 2025-11-07 | 104 | 🔍 RESEARCH — No state file found |
| `oscilloscope-toggle` | Add oscilloscope visualizer toggle | 2025-11-07 | 2025-11-07 | 104 | ✅ COMPLETE — Merged to main (PR #27) |
| `oi-button-bugfix-review` | Bug-fix review for O/I buttons (separate from `o-i-buttons-review`) | 2025-11-02 | 2025-11-07 | 104 | 🔍 RESEARCH — No state file found |
| `magnetic-window-docking` | Research and implement magnetic window snapping/docking | 2025-10-23 | 2025-11-02 | 109 | 🟡 DEFERRED — Deferred to P3 (post-1.0) as of 2025-10-23 |

---

## October 2025 Tasks

| Task | Purpose | Created | Last Activity | Days Idle | Status |
|------|---------|---------|---------------|-----------|--------|
| `track-title-display` | Implement scrolling track title display in main window | 2026-11-01 | 2025-10-31 | 111 | 🔍 RESEARCH — No clear status |
| `track-title-display-bug` | Fix bug in track title display rendering | 2026-11-01 | 2025-10-31 | 111 | 🔍 RESEARCH — No clear status |
| `playlist-navigation-bug` | Fix playlist navigation (next/previous track) bug | 2026-11-01 | 2025-10-31 | 111 | 🔍 RESEARCH — No clear status |
| `oracle-playback-review` | Oracle review of audio playback implementation | 2026-11-01 | 2025-10-31 | 111 | 📄 REFERENCE — Review complete |
| `internet-radio` | Implement internet radio streaming (HTTP/HTTPS) | 2025-10-31 | 2025-10-31 | 111 | ✅ COMPLETE — All fixes applied, user tested, ready for PR |
| `internet-radio-file-types` | Add internet radio file type support (M3U, PLS) | 2026-11-01 | 2025-10-31 | 111 | ✅ COMPLETE — M3U phases 1-4 done; remote streams deferred to P5 |
| `internet-radio-arch-review` | Architecture review for internet radio implementation | 2026-11-01 | 2025-10-31 | 111 | 📄 REFERENCE — Review complete |
| `window-focus-warning` | Investigate and fix window focus compiler/runtime warning | 2026-11-01 | 2025-10-29 | 113 | 🔍 RESEARCH — No state file found |
| `swift-modernization-recommendations` | Produce Swift modernization recommendations (pixel-perfect sprites, concurrency) | 2026-11-01 | 2025-10-29 | 113 | 🔄 IN PROGRESS — Phase 1 complete, Phase 2 ready to start |
| `playlist-drag-and-drop` | Implement drag-and-drop reordering in playlist | 2026-11-01 | 2025-10-29 | 113 | 🔍 RESEARCH — No state file found |
| `openpanel-mainactor-analysis` | Analyze `NSOpenPanel` `@MainActor` isolation issue | 2026-11-01 | 2025-10-29 | 113 | 📄 REFERENCE — Analysis complete |
| `playlist-sprite-adjustments` | Adjust playlist window sprite coordinates for correct rendering | 2025-10-28 | 2025-10-28 | 114 | ✅ COMPLETE — Fix applied, ready to commit |
| `playlist-menu-system` | Implement playlist context menu system + multi-select | 2025-10-23 | 2025-10-28 | 114 | ✅ COMPLETE — Menus + multi-select done |
| `m3u-file-support` | Add M3U playlist file parsing and loading | 2025-10-24 | 2025-10-24 | 118 | ✅ COMPLETE — Remote streams deferred |
| `distribution-setup` | Set up app distribution (notarization, Sparkle, DMG) | 2025-10-24 | 2025-10-24 | 118 | 📄 REFERENCE — Guide documents at `distribution-guide.md`, `testflight-beta-testing.md` |
| `distributable-app-build` | Build distributable `.app` / `.dmg` artifact | 2025-10-24 | 2025-10-24 | 118 | 🔍 RESEARCH — Only `research.md` present |
| `window-management-docking-analysis` | Analyze window management and docking architecture | 2025-10-23 | 2025-10-23 | 119 | 📄 REFERENCE — Analysis complete (`analysis.md`) |
| `security-vulnerability-analysis` | Security audit of MacAmp codebase | 2025-10-23 | 2025-10-23 | 119 | 📄 REFERENCE — Analysis + compliance status documented |

---

## Standalone Task Files (not in folders)

| File | Purpose | Notes |
|------|---------|-------|
| `liquid-glass-shimmer-bug.md` | Bug report for Liquid Glass shimmer effect | Standalone markdown, no task folder |
| `spectrum-analyzer-architecture-report.md` | Architecture report for spectrum analyzer | Standalone markdown, no task folder |
| `winamp-skin-research-2025.md` | Research notes on Winamp skin formats (2025) | Standalone markdown, no task folder |
| `PRIORITY_MAPPING.md` | Priority mapping for tasks/features | Standalone reference |

---

## Summary Statistics

| Category | Count |
|---------|-------|
| Total open task folders | ~79 |
| ✅ COMPLETE (needs close/commit/merge) | ~19 |
| 🔄 IN PROGRESS | ~5 |
| 📋 PLANNED (ready to implement) | ~13 |
| ⏸ BLOCKED | ~4 |
| 🟡 DEFERRED | ~2 |
| 📄 REFERENCE (analysis/review artifacts) | ~15 |
| 🔍 RESEARCH (unclear/early stage) | ~20 |

---

## High Priority Actionable Tasks

These tasks are ready to act on and have the most impact:

1. **`internet-streaming-volume-control`** — N1-N6 blockers resolved (PR #49), ready for Phase 1 implementation.
2. **`mainwindow-layer-decomposition`** — Research complete, 4-phase plan written. High architectural impact.
3. **`playlistwindow-layer-decomposition`** — Research complete, 4-phase plan written. Same pattern as mainwindow.
4. **`audioplayer-decomposition`** — Research/plan approved, high architectural impact. Start implementation.
5. **`window-coordinator-cleanup`** — Complete, just needs manual testing + commit.
6. **`airplay-integration`** — Research done, awaiting user approval to begin.
7. **`lock-free-ring-buffer`** — Prerequisite for streaming Phase 2.
8. **`oracle-validation-audioplayer-refactor`** — API naming mismatch needs resolution.
