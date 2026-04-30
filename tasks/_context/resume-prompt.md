# S3 Resume Prompt

> **Purpose:** One-stop pickup file for resuming MacAmp Sprint S3 work in a fresh Claude Code session. Update this file's "Current State" + "Active Work Queue" sections after each PR merge so it always reflects HEAD.
>
> **How to use:** In a new session, paste:
> *"Read `tasks/_context/resume-prompt.md` and follow it. Start with the next active task."*

---

## Current State (update after each PR merge)

**Last update:** 2026-04-30 (S3-2 Phase 0 + 1 + 2 ✅ — MTAudioProcessingTap wrapper ships at 9.3/10; `feat/video-audio-engine-routing` has 17 commits; Phase 3 next).
**Main HEAD:** `07a3ee8` — `docs(_context): capture HLS video constraints + future-work options`.
**feat/video-audio-engine-routing HEAD:** `749b91d` — `fix(audio): clear stale channel layout on tap reattach` (rebased onto main).
**Tests:** 84/84 passing on the feat branch (TSan ON; +12 from Phase 2: +4 attach/state, +6 bypass classification, +2 surround layout map).
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

**Status:** Phase 0 + 1 + 2 ✅ all complete (2026-04-30). **Phase 3 (engine source node + wiring per plan §8) is next.**

**Phase 0 outcome (commit `1d4eca1` on main):** Path NONE — frequency-locked clocks across all 5 corpus files (slope mean -0.75 ms/sec, 95% CI [-6.4, +4.9]). Constant -200 ms phase offset is AVPlayer pipeline depth, not perceptible drift. Plan §9 Phase 4 collapses to no-op. Plan §7.5 AudioConverter is **load-bearing** (not optional) — without resampling, 44.1 kHz audio plays as discontinuous bursts every ~76 ms.

**Phase 1 outcome (10 commits + 2 closeout on `feat/video-audio-engine-routing`):** Engine configuration change observer ships. Output-route changes (Control Center, AirPlay, HDMI hot-plug, sleep/wake) trigger graceful engine recovery for local-file + stream paths. Manually verified across local↔external↔AirPlay routing. 72/72 tests pass with TSan. Three Oracle-driven follow-up commits address all HIGH-priority review items.

**Phase 2 outcome (5 commits, ending at `749b91d`):** `MacAmpApp/Audio/VideoAudioTap.swift` (~340 LOC) ships per plan §7. C-convention callbacks via `Unmanaged<VideoAudioTapContext>`; `MTAudioProcessingTap` CFType auto-managed by Swift bridging (no manual `Unmanaged` for the tap itself, only for the context). AudioConverter handles all four format-edge cases per plan §7.5: mono duplication (channel map `[0,0]`), surround downmix (`kAudioConverterPropertyPerformDownmix=1` + actual source `AudioChannelLayout` from `CMAudioFormatDescriptionGetChannelLayout`, AAC-tag fallback when metadata absent), non-Float32 conversion, sample-rate resampling. Oracle three-pass review converged at **9.3/10** (8.2 → 8.4 → 9.3). 76 → 84 tests with TSan: +4 attach/state, +6 bypass classification, +2 surround layout map.

**Architectural notes (relevant for Phase 3 implementation):**
- AsyncSequence-based notification observation (`NotificationCenter.notifications(named:object:)`) — modern Swift 6.2 pattern; future similar work follows it.
- `PreReconfigureSnapshot` has split state ownership: bridge flags are MacAmp-owned (authoritative); `wasPlaying` / `currentTime` are best-effort placeholders that AudioPlayer overrides with its own state. Phase 3 candidate refactor: narrow the type to bridge-flags-only.
- Reconfigure cancellation contract: `AudioPlayer.cancelPendingReconfigure()` called at start of `play`/`pause`/`stop`/`seek`/`playTrack` — Phase 3 video-bridge teardown should also call it.
- `VideoAudioTap.attach(to:)` is **async** (uses `loadTracks(withMediaType:)` and `load(.formatDescriptions)` — non-deprecated successors). Plan §7.3 specced sync; the modern Swift 6.2 alternatives are async, so the signature shifted. Phase 3 wires this into a `Task { ... }` after AVPlayerItem is `.readyToPlay`.
- `MTAudioProcessingTap` CFType is auto-managed in Swift 6.2 (not `Unmanaged`). Plan §7.3 specced manual `Unmanaged` lifecycle — only the `VideoAudioTapContext` clientInfo needs it.
- Tap watchdog (Phase 5) must check **BOTH** `tap.lastCallbackHostTime` (host-time stall) AND `tap.fallbackRequested` (immediate-engage on AudioConverter creation failure). Documented on the public properties; flagged in state.md Phase 2 follow-ups.
- HAL log noise (`!obj`, `!dev`, `'nope'`) on AirPlay→built-in transitions is OS-level device-teardown chatter, not MacAmp-actionable.

**Branch:** `feat/video-audio-engine-routing` (rebased onto main HEAD `07a3ee8`) → PR target #C.
**Predecessors:** S3-1A ✅ + S3-1B ✅ + Phase 0 ✅ + Phase 1 ✅ + Phase 2 ✅ all complete.
**Successors:** S3-3 (`hls-streaming-support`) gated on this merge.

**Phase 3 (engine source node + wiring per plan §8) is next:**
- Add `videoSourceNode`, `videoRingBuffer`, `isVideoBridgeActive` fields to `AudioEngineController` (parallel to `streamSourceNode`).
- Implement `activateVideoBridge(ringBuffer:sampleRate:)` / `deactivateVideoBridge()` with mutual exclusion against the stream bridge.
- Modify `AudioPlayer.playTrack` video branch (lines 354-360 area): build ring, instantiate `VideoAudioTap`, `await tap.attach(to:)`, set `playerItem.audioMix = mix`, `engine.activateVideoBridge(...)`, `player.volume = 0`.
- Modify `VideoPlaybackController.loadVideo` and `cleanup` per plan §3.5 (or have AudioPlayer handle the tap externally — plan flexible).
- Wire `wasVideoBridge` to a real flag in `PreReconfigureSnapshot`; fill in TODO comments at `AudioEngineController.handleEngineWillReconfigure` / `handleEngineDidReconfigure`.

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

Open `tasks/video-audio-engine-routing/` (S3-2). Read all 6 canonical files (`research.md`, `plan.md`, `todo.md`, `state.md`, `placeholder.md`, `depreciated.md`). Required reading on the **feat branch** (where Phase 0/1/2 closed):
- `state.md` — full Phase 0/1/2 outcome including 17-commit list, architectural notes, follow-ups deferred to Phase 3
- `plan.md §6.3` — split state ownership + cancellation contract (Phase 1 contract)
- `plan.md §7` — MTAudioProcessingTap spec (Phase 2 implementation lives at `MacAmpApp/Audio/VideoAudioTap.swift`)
- `plan.md §8` — engine source node + wiring spec (Phase 3 — what comes next)
- `todo.md` Phase 1 + Phase 2 — all items marked [x]; reads as a closeout record
- `research.md` Phase 0 results — Path NONE; AudioConverter is load-bearing
- `MacAmpApp/Audio/VideoAudioTap.swift` itself — read the doc comments at the top of the file and on `attach(to:)` / `detach()` / `lastCallbackHostTime` / `fallbackRequested`. Phase 3 is the consumer.

**Phase 0 + Phase 1 + Phase 2 are done.** Skip them. Phase 4 (sync strategy) is a no-op per todo §4.NONE. **Phase 3 (engine source node + wiring per plan §8) is next.**

**Branch already exists:** `feat/video-audio-engine-routing` is rebased onto main HEAD `07a3ee8` and has 17 commits (10 Phase-1 + closeout + 5 Phase-2). Switch to it (`git checkout feat/video-audio-engine-routing`).

Phase 3 sketch (per plan §8):
- Modify `MacAmpApp/Audio/AudioEngineController.swift`: add `videoSourceNode`, `videoRingBuffer`, `isVideoBridgeActive` fields parallel to the stream bridge; add `makeVideoRenderBlock`; implement `activateVideoBridge(ringBuffer:sampleRate:)` / `deactivateVideoBridge()` with mutual exclusion against the stream bridge; extend `setVolume`/`setBalance` to forward to `videoSourceNode`. Fill the Phase 1 TODO comments at `handleEngineWillReconfigure` / `handleEngineDidReconfigure` (wire `wasVideoBridge` to a real flag).
- Modify `MacAmpApp/Audio/AudioPlayer.swift` video branch in `playTrack`: build ring buffer (capacity 4096, channels 2), instantiate `VideoAudioTap`, **`await tap.attach(to:)`** (note: async signature), assign `playerItem.audioMix = mix`, call `engine.activateVideoBridge(...)`, set `player.volume = 0`. Update `stop()` to deactivate video bridge + detach tap. Update `isEngineRendering` to include video bridge.
- Modify `MacAmpApp/Audio/VideoPlaybackController.swift` per plan §3.5 — extend `loadVideo` to accept optional tap (or have AudioPlayer wire externally), add `detachAudioTap()` that sets `playerItem.audioMix = nil` BEFORE calling `tap.detach()` (essential ordering), unify cleanup.
- Tests: `Tests/MacAmpTests/AudioEngineControllerVideoBridgeTests.swift` per todo §3.6.
- Phase 3 does NOT add the watchdog — that's Phase 5.

Standard pickup process from step 7 onward:
- TSan-on builds + tests after each commit per `feedback_xcodebuildmcp_workflow.md`.
- Per-step commits with build+test between (the established Phase 1 cadence).
- Match the modern Swift 6.2 idioms from Phase 1: `@preconcurrency import` for unannotated frameworks, `Task.sleep(for: Duration)`, `isolated deinit`, AsyncSequence over block-based observers where applicable.
- Codex Oracle review at end of phase per the existing pattern (Phase 1 closed at 9.5/10; Phase 2 at 9.3/10; aim for ≥9/10 at end of Phase 3).

Stop and report back to me before pushing the PR — I'll review before merge.

> **Optional sub-track:** `timer-scheduled-on-common-extension` — extract a `Timer.scheduledOnMainCommon` helper, migrate all 7 Pattern-A timer callsites. Predecessor `timer-runloop-mode-audit` (PR #81) is merged ✅; this task does not block any S3 wave. Task folder doesn't exist yet — create it on pickup using the same 6-file canonical layout.
