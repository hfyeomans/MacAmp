# S3 Resume Prompt

> **Purpose:** One-stop pickup file for resuming MacAmp Sprint S3 work in a fresh Claude Code session. Update this file's "Current State" + "Active Work Queue" sections after each PR merge so it always reflects HEAD.
>
> **How to use:** In a new session, paste:
> *"Read `tasks/_context/resume-prompt.md` and follow it. Start with the next active task."*

---

## Current State (update after each PR merge)

**Last update:** 2026-04-30 (S3-2 Phase 0 + 1 + 2 + 3 ✅ — engine source node + AudioPlayer wiring ships at **9.5/10 final** after a 3-commit regression-fix arc post real-video manual test; `feat/video-audio-engine-routing` has 30 commits; Phase 5 next, Phase 4 is no-op).
**Main HEAD:** `9cca40a` — `docs(_context): close out Phase 2; advance vaer to Phase 3-next` (will advance once Phase 3 closeout commit lands on main).
**feat/video-audio-engine-routing HEAD:** `d112e1b` — `fix(audio): clear videoLoadTask after Task body claims active load` (rebased onto main).
**Tests:** 90/90 passing on the feat branch (TSan ON; +6 from Phase 3: +4 video-bridge state-machine, +2 video-render-block). Manual video verified: frame displays, single audio path, slider clean, EQ + spectrum analyzer respond. Milkdrop deferred to Phase 6 per plan §11.3.
**PRs merged total:** 80. Phase 3 work continues to land on the feat branch; no PR opened yet.

**Most recent docs commits on main:**
- `07a3ee8` HLS video future-work doc (S3-2 vs S3-3 naming clarification + 3 options for hypothetical HLS-video work)
- `9fa0238` `*.m4v` gitignore
- `5dea7d3` Phase 0 status sweep
- `1d4eca1` Phase 0 spike findings — Path NONE selected; plan §9 Phase 4 = no-op; plan §7.5 AudioConverter is load-bearing

**Most recent task closed:** `tasks/done/stream-pause-tail/` (S3-1B, PR #82, merged 2026-04-30, merge commit `b60fd57`). Atomic silence gate on the `AVAudioSourceNode` render block + producer-quiesce barrier (gate→clearQueue→ring flush in one decode-queue block) + seqlock + CAS in `LockFreeRingBuffer.read()` eliminates the ~0.7 s pause-tail and closes the consumer-side render-vs-flush race. `userPaused` flag suppresses reconnect-during-pause; `resume()` switches on pipeline state for safe live-edge restart with explicit bridge teardown. 9 implementation review iterations (Codex Oracle final 9/10 + parallel code-reviewer agent pass that caught a `deinit` task-leak Oracle missed). All 7 manual scenarios validated on real SomaFM stream. Two Lows deferred (see `_context/state.md` "Post-S3-1B Follow-Ups"): `StreamDecodePipeline.stop()` generation guard and `AudioConverterDecoder.clearQueue()` confinement-doc gap.

**Previous closeout:** `tasks/done/timer-runloop-mode-audit/` (Post-S3-1A follow-up, PR #81, 2026-04-29). Pattern A normalization across the codebase. Deferred sub-follow-up `timer-scheduled-on-common-extension` pre-tracked.

---

## Active Work Queue (ordered — start at the top)

### 1. IN PROGRESS — `tasks/video-audio-engine-routing/` (S3-2)

**Status:** Phase 0 + 1 + 2 + 3 ✅ all complete (2026-04-30). **Phase 5 (tap-failure watchdog per plan §10) is next; Phase 4 is no-op per Phase 0 Path NONE.**

**Phase 0 outcome (commit `1d4eca1` on main):** Path NONE — frequency-locked clocks across all 5 corpus files (slope mean -0.75 ms/sec, 95% CI [-6.4, +4.9]). Constant -200 ms phase offset is AVPlayer pipeline depth, not perceptible drift. Plan §9 Phase 4 collapses to no-op. Plan §7.5 AudioConverter is **load-bearing** (not optional) — without resampling, 44.1 kHz audio plays as discontinuous bursts every ~76 ms.

**Phase 1 outcome (10 commits + 2 closeout on `feat/video-audio-engine-routing`):** Engine configuration change observer ships. Output-route changes (Control Center, AirPlay, HDMI hot-plug, sleep/wake) trigger graceful engine recovery for local-file + stream paths. Manually verified across local↔external↔AirPlay routing. 72/72 tests pass with TSan. Three Oracle-driven follow-up commits address all HIGH-priority review items.

**Phase 2 outcome (5 commits, ending at `749b91d`):** `MacAmpApp/Audio/VideoAudioTap.swift` (~340 LOC) ships per plan §7. C-convention callbacks via `Unmanaged<VideoAudioTapContext>`; `MTAudioProcessingTap` CFType auto-managed by Swift bridging. AudioConverter handles all four format-edge cases (mono duplication, surround downmix with `PerformDownmix=1` + actual source layout, non-Float32, sample-rate). Oracle three-pass review converged at **9.3/10**.

**Phase 3 outcome (6 implementation commits + 3 regression-fix commits, ending at `d112e1b`):** Engine source node wired into the graph. `AudioEngineController` gains `videoSourceNode` / `videoRingBuffer` / `isVideoBridgeActive` parallel to the stream bridge, plus mutual exclusion across the three engine paths and reconfigure-refresh of the video graph format. `AudioPlayer.playTrack` video branch refactored into `startVideoTrack(track)` which spawns a stored Task (`videoLoadTask`) that awaits `VideoAudioTap.attach(to:)` before activating the engine bridge. `VideoPlaybackController.loadVideo` is now async, accepts an `audioTap:` parameter, and runs a post-await `self.player === newPlayer` guard. Two-tier stale defence: tap-identity at AudioPlayer level (`videoAudioTap === tap`) closes same-URL replay; player-identity at VideoPlaybackController level closes mid-await player swap. `videoLoadTask` is cancelled by `tearDownVideoBridge()` (stop/playTrack-switch/eject/isolated deinit) and cleared via `defer` after the identity guard passes (so completed loads don't permanently block resume). Implementation-Oracle: 8.4 → 9.2 → 9.4. Real-video manual test then surfaced three regressions resolved by the fix arc: (a) `@ObservationIgnored` on `VideoPlaybackController.player` blocked SwiftUI re-render after the async player assignment — removed; (b) volume slider un-muted AVPlayer while bridge was active (double audio) — gated `volume.didSet` forwarding on `engine.isVideoBridgeActive != true`; (c) `videoLoadTask` never cleared after normal completion — `defer` fix. Regression-fix Oracle: 7 → 8 → **9.5**. Phase 3 final 9.5/10. Manual video verified: frame displays, single audio path, slider clean, EQ + spectrum analyzer respond. Milkdrop intentionally deferred to Phase 6 per plan §11.3 (`snapshotButterchurnFrame` is gated on `currentMediaType == .audio`; Phase 6 swaps to a bridge-aware guard).

**Architectural notes (relevant for Phase 5 implementation):**
- AsyncSequence-based notification observation (`NotificationCenter.notifications(named:object:)`) — modern Swift 6.2 pattern; future similar work follows it.
- `PreReconfigureSnapshot.wasVideoBridge` is wired to the real flag now. The TODO comments in `handleEngineWillReconfigure` / `handleEngineDidReconfigure` are filled.
- Reconfigure cancellation contract: `AudioPlayer.cancelPendingReconfigure()` called at start of `play`/`pause`/`stop`/`seek`/`playTrack`. `tearDownVideoBridge()` cancels `videoLoadTask` on the same teardown paths.
- `VideoAudioTap.attach(to:)` is **async** — Phase 3 wraps this in a stored Task (`videoLoadTask`). Phase 5 watchdog should expect the Task is in-flight during the asset-load gap and not engage fallback before the first tap callback.
- Tap watchdog (Phase 5) must check **BOTH** `tap.lastCallbackHostTime` (host-time stall) AND `tap.fallbackRequested` (immediate-engage on AudioConverter creation failure). Documented on the public properties; flagged in state.md Phase 2/3 follow-ups.
- Phase 5 watchdog must use **tap identity**, not URL, for "is this the active tap?" — same lesson as Phase 3 stale checks. URL equality fails for same-URL replay.
- HAL log noise (`!obj`, `!dev`, `'nope'`) on AirPlay→built-in transitions is OS-level device-teardown chatter, not MacAmp-actionable.

**Branch:** `feat/video-audio-engine-routing` (rebased onto main HEAD `07a3ee8`) → PR target #C.
**Predecessors:** S3-1A ✅ + S3-1B ✅ + Phase 0 ✅ + Phase 1 ✅ + Phase 2 ✅ + Phase 3 ✅ all complete.
**Successors:** S3-3 (`hls-streaming-support`) gated on this merge.

**Phase 5 (tap-failure watchdog + fallback per plan §10) is next:**
- Add `videoTapWatchdogTask: Task<Void, Never>?` to AudioPlayer; `videoTapFallbackActive: Bool = false`.
- Watchdog checks every 250 ms: `(now - tap.lastCallbackHostTime) > 1000 ms` AND `videoPlaybackController.isPlaying` AND `engine.isVideoBridgeActive` — OR `tap.fallbackRequested == true` (engage immediately).
- Use tap identity (`videoAudioTap === tap`) to ensure the watchdog ignores stale taps after teardown.
- Fallback sequence (must run on @MainActor in this exact order, per plan §10.2): cancel watchdog → set `videoTapFallbackActive = true` → log error → `engine.deactivateVideoBridge()` → `videoPlaybackController.detachAudioTap()` → clear `videoAudioTap` / `videoRingBuffer` → restore `videoPlaybackController.player.volume = audioPlayer.volume` → reset `seekGuardActive = false`.
- Reset `videoTapFallbackActive = false` at start of `playTrack` (per-track fresh slate).
- Volume.didSet: forward to `videoPlaybackController.volume` only when `videoTapFallbackActive` (Phase 6 finalizes — Phase 5 gate is sufficient).

### 2. DEFERRED — `timer-scheduled-on-common-extension`

Sub-follow-up of `timer-runloop-mode-audit` (now merged). Extract a `Timer.scheduledOnMainCommon(every:repeats:_:)` helper into `MacAmpApp/Utilities/Timer+CommonMode.swift` and migrate all 7 timer-on-RunLoop callsites in `MacAmpApp/` to use it. With 7 Pattern-A callsites now in the codebase, AHA Rule-of-Three is exceeded by 4× — the helper is the natural next step.

**Predecessor:** `timer-runloop-mode-audit` PR #81 ✅ merged 2026-04-29.
**Task folder:** not yet created (centrally tracked in `tasks/_context/state.md` "Post-S3-1A `timer-runloop-mode-audit` Follow-Ups" section).
**Risk:** `@Sendable` closure migration may surface concurrency-checker edge cases at callsites using `[weak self]` + `MainActor.assumeIsolated` — warrants per-site review.
**When to start:** any time after S3-1B; not blocking any S3 wave.

---

## S3 work map (current state — refresh on each merge)

```
S3-1A mwvi  ✅ MERGED (PR #80, merge commit 7f3d76f, 2026-04-28)
     │
     ├──► S3-1B spt                       ←── PR #82  ✅ MERGED (merge commit b60fd57, 2026-04-30)
     │       │
     │       ▼
     │    S3-2 vaer                       ←── PR #C   🔧 IN PROGRESS (Phase 0/1/2 ✅; Phase 3 engine source node + wiring next)
     │       │
     │       ▼
     │    S3-3 hls                        ←── PR #D
     │       │
     │       ▼
     │    S3-4 ogg                        ←── PR #E
     │           └── runs spike/ogg-build-wiring (0a) + spike/ogg-local-playback (0b) FIRST
     │
     └──► timer-runloop-mode-audit         ←── PR #81  ✅ MERGED (merge commit ac09dd4, 2026-04-29)
              │
              ▼
          timer-scheduled-on-common-extension   ←── PR #H   ⏸ DEFERRED (predecessor merged ✅; ready when scheduled)
```

**Spike policy (default — do NOT deviate without explicit reason):** each Phase 0 spike runs at its parent task's pickup time on a throwaway branch, findings written to that task's `research.md`, branch deleted. Do NOT run `spike/vaer-av-drift-measurement`, `spike/ogg-build-wiring`, or `spike/ogg-local-playback` early. The vaer drift spike is the kill-switch on whether vaer is feasible at all (>100 ms drift → cancel task), but its strategic value of running early is not worth the workflow break.

**Post-S3:** Structure Sprint (file-move consolidation per `_context/state.md` D-STRUCTURE decision 2026-03-15). Don't start it until S3 closes.

---

## Standard Pickup Process (apply per task)

Every S3 task — main task or spike — follows this sequence:

1. **Read `tasks/_context/state.md`** for cross-task coordination state, file-conflict matrix, and current sprint status.
2. **Read `tasks/_context/principles.md`** — the 7 decomposition principles (Problem-First, Cohesion>LOC, State Ownership, AHA Rule of Three, API Surface, No Pass-Through, ADR + Kill Switch).
3. **Read all 6 canonical files** in the task folder: `research.md`, `plan.md`, `todo.md`, `state.md`, `placeholder.md`, `depreciated.md`.
4. **Re-read every "Files Affected" source at HEAD** to reconcile line-number drift since the plan was written. Verify the plan/todo references still match the code.
5. **Confirm `git status` is clean.** If pending changes exist, commit them as a `chore:` before cutting the new branch.
6. **Cut branch from `main`:** `git checkout main && git pull && git checkout -b <branch-name>`.
7. **Execute `todo.md` phases in order.** TSan-on builds + tests after each phase (per `feedback_xcodebuildmcp_workflow.md` memory):
   ```bash
   xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'
   xcodebuildmcp macos test  --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'
   ```
   Note: TSan is per-invocation only — no session-default works (see `feedback_tsan_xcodebuildmcp_cli.md`).
8. **Use `ast-grep` (`sg --lang swift -p '<pattern>'`)** before editing setter chains, call graphs, or member-access patterns. `rg` text search alone misses duplicates and dead writes (see `feedback_ast_grep_structural_search.md`).
9. **For diagnostic work on pipelines** (producer → transport → consumer): instrument at least two stages, not just the symptom site (see `feedback_pipeline_end_to_end_diagnosis.md`).
10. **Run Codex Oracle pre-PR code-review gate** (`mcp__codex-cli__codex`, model `gpt-5.3-codex`, `reasoningEffort: xhigh`). Apply ACTIONABLE feedback. Consider NITs case-by-case.
11. **Push + `gh pr create`.** Wait for human review before merging.
12. **Post-merge close-out** (model after the mwvi close-out commit `0358a25`):
    - Update task `state.md` to MERGED with PR link + merge commit.
    - `git mv tasks/<task>/ tasks/done/<task>/` (preserves history).
    - Update `tasks/_context/state.md` (Quick Reference, sprint table, follow-up section if any).
    - Update `tasks/_context/tasks_index.md`.
    - **Update this file** (`tasks/_context/resume-prompt.md`) — bump "Current State" section, advance "Active Work Queue" by removing the merged task and promoting the next task in line.
    - Single `chore: close out <task> (PR #X)` commit.

---

## Persistent Project Memories (auto-loaded by session start hook)

Index lives at `~/.claude/projects/-Users-hank-dev-src-MacAmp/memory/MEMORY.md`. Notable memories that apply directly to S3 work:

- **`feedback_pipeline_end_to_end_diagnosis.md`** — Symptoms manifest at the consumer; root causes often live at the producer. Instrument both ends of any data pipeline before diagnosing. Five operational rules; cross-references the same meta-principle as ast-grep.
- **`feedback_ast_grep_structural_search.md`** — Use `sg --lang swift -p` for structural enumeration before edits; `rg` text search misses duplicates / dead writes / pass-through middlemen.
- **`feedback_xcodebuildmcp_workflow.md`** — Always xcodegen + XcodeBuildMCP build AND test (not just `swift build`/`test`) after adding/moving files. TSan must be passed per-invocation.
- **`feedback_sprint_workflow.md`** — Every sprint task gets Oracle review + PR for user review before merge, regardless of size.
- **`feedback_architecture_principles.md`** — The 7 decomposition principles (project-canonical at `tasks/_context/principles.md` and `.ai-shared/principles.md`).

---

## Project-Specific Lessons Reference

`BUILDING_RETRO_MACOS_APPS_SKILL.md` is the canonical lessons-learned doc. Most relevant for current work:

- **`feedback_pipeline_end_to_end_diagnosis.md`** — directly applicable to `stream-pause-tail`: the pause-tail bug is a producer-vs-consumer pipeline issue (silence-gate at consumer + producer-quiesce). Instrument both ends before diagnosing.
- **Part 23 — Lesson: RunLoop Mode Discipline in Feeding Pipelines (April 2026)** — historical context for the merged `timer-runloop-mode-audit` (PR #81) and direct guidance for the deferred follow-up `timer-scheduled-on-common-extension`. Includes the audit-habit shell snippet to enumerate all `Timer.scheduledTimer` callsites and verify each is followed by `RunLoop.main.add(timer, forMode: .common)`.
- **Part 21 — Video/Milkdrop Window Patterns** (Pattern 3: `Task { @MainActor in }` for Timer/Observer Closures) — relevant whenever modifying timer closures.

---

## First Action for the Resuming Agent

Open `tasks/video-audio-engine-routing/` (S3-2). Read all 6 canonical files (`research.md`, `plan.md`, `todo.md`, `state.md`, `placeholder.md`, `depreciated.md`). Required reading on the **feat branch** (where Phase 0/1/2/3 closed):
- `state.md` — full Phase 0/1/2/3 outcome including 24-commit list, architectural notes, follow-ups deferred to Phase 5/6
- `plan.md §6.3` — split state ownership + cancellation contract (Phase 1 contract)
- `plan.md §7` — MTAudioProcessingTap spec (Phase 2 implementation at `MacAmpApp/Audio/VideoAudioTap.swift`)
- `plan.md §8` — engine source node + wiring spec (Phase 3 implementation at `MacAmpApp/Audio/AudioEngineController.swift` + `MacAmpApp/Audio/AudioPlayer.swift` + `MacAmpApp/Audio/VideoPlaybackController.swift`)
- `plan.md §10` — tap-failure watchdog spec (Phase 5 — what comes next)
- `todo.md` Phase 1/2/3 — all items marked [x]; reads as a closeout record
- `research.md` Phase 0 results — Path NONE; AudioConverter is load-bearing
- `MacAmpApp/Audio/VideoAudioTap.swift` — read doc comments on `attach(to:)` / `detach()` / `lastCallbackHostTime` / `fallbackRequested`. Phase 5 watchdog reads both atomic accessors.
- `MacAmpApp/Audio/AudioPlayer.swift` `startVideoTrack` / `tearDownVideoBridge` / `videoLoadTask` — Phase 5 watchdog wires alongside this (cancelled by tearDownVideoBridge, identity-checked against `videoAudioTap`).

**Phase 0 + Phase 1 + Phase 2 + Phase 3 are done.** Skip them. Phase 4 (sync strategy) is a no-op per todo §4.NONE. **Phase 5 (tap-failure watchdog + fallback per plan §10) is next.**

**Branch already exists:** `feat/video-audio-engine-routing` is rebased onto main HEAD `07a3ee8` and has 30 commits (10 Phase-1 + 1 Phase-1 closeout + 5 Phase-2 + 1 Phase-2 closeout + 6 Phase-3 + 1 Phase-3 task-folder closeout + 1 Phase-3 _context closeout + 3 regression-fix + 1 doc closeout). Switch to it (`git checkout feat/video-audio-engine-routing`).

Phase 5 sketch (per plan §10):
- AudioPlayer fields: `videoTapWatchdogTask: Task<Void, Never>?` and `videoTapFallbackActive: Bool = false`. Reset both at the start of `playTrack` (per-track fresh slate).
- Watchdog body: every 250 ms while `engine.isVideoBridgeActive && videoPlaybackController.isPlaying`, check (a) `(mach_absolute_time() - tap.lastCallbackHostTime) > 1_000_000_000 ns` (1s host-time stall) — convert via mach_timebase, OR (b) `tap.fallbackRequested == true` (engage immediately). Use the captured `tap` reference and verify `videoAudioTap === tap` each tick; bail if a newer track replaced the tap.
- Start watchdog when `engine.activateVideoBridge` succeeds inside `startVideoTrack`. Stop watchdog inside `tearDownVideoBridge` (alongside `videoLoadTask?.cancel()`).
- Fallback sequence (must run on @MainActor in this exact order, per plan §10.2): idempotency guard `guard !videoTapFallbackActive else { return }` → cancel watchdog → set `videoTapFallbackActive = true` → log error → `engine.deactivateVideoBridge()` → `videoPlaybackController.detachAudioTap()` → clear `videoAudioTap` / `videoRingBuffer` → restore `videoPlaybackController.player?.volume = volume` → reset `seekGuardActive = false` (do NOT bump `currentSeekID`, no scheduled segment to invalidate).
- Volume `didSet`: forward to `videoPlaybackController.volume` only when `videoTapFallbackActive` (Phase 6 finalizes per plan §11.6 — Phase 5 gate is sufficient for now).
- Tests: `Tests/MacAmpTests/VideoTapFallbackTests.swift` per todo §5.4 (fallback idempotency, host-time stall trigger, fallbackRequested-immediate trigger).
- Phase 5 does NOT update the capability flag surface — that's Phase 6.

Standard pickup process from step 7 onward:
- TSan-on builds + tests after each commit per `feedback_xcodebuildmcp_workflow.md`.
- Per-step commits with build+test between (the established Phase 1/2/3 cadence).
- Match the modern Swift 6.2 idioms used in Phase 1/3: `@preconcurrency import` for unannotated frameworks, `Task.sleep(for: Duration)`, `isolated deinit`, AsyncSequence over block-based observers where applicable.
- Codex Oracle review at end of phase per the existing pattern (Phase 1 closed at 9.5/10; Phase 2 at 9.3/10; Phase 3 at 9.5/10 final after regression-fix arc; aim for ≥9/10 at end of Phase 5).

Stop and report back to me before pushing the PR — I'll review before merge.

> **Optional sub-track:** `timer-scheduled-on-common-extension` — extract a `Timer.scheduledOnMainCommon` helper, migrate all 7 Pattern-A timer callsites. Predecessor `timer-runloop-mode-audit` (PR #81) is merged ✅; this task does not block any S3 wave. Task folder doesn't exist yet — create it on pickup using the same 6-file canonical layout.
