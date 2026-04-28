# Todo: MainWindow Visualizer Isolation

> **Source:** Derived from `tasks/mainwindow-visualizer-isolation/plan.md` and `research.md`.
> **Sprint:** S3, Wave S3-1, Worktree A. Branch: `feat/mainwindow-visualizer-isolation`.
> **Status (2026-04-28):** Implementation complete; V.1 PASS; pending Oracle gate + PR.

---

## Phase 0 — Instruments Spike (COMPLETE)

Branch: `spike/mwvi-volume-drag-profile` (throwaway, deleted post-capture).

- [x] 0.1 Create throwaway branch from `main`. ✓
- [x] 0.2 Build with TSan disabled and Debug config. ✓
- [x] 0.3 Add temporary `os_signpost(.event, …)` calls. ✓
- [x] 0.4 Open Instruments → SwiftUI template + os_signpost instrument. ✓
- [x] 0.5 Capture T1 (volume control): FullLayer=506, SlidersLayer=507, VisualizerView=1,514. ✓
- [x] 0.6 Capture T2 (volume drag): FullLayer=459, SlidersLayer=1,239, VisualizerView=1,298. ✓
- [x] 0.7 Capture T3 (balance control): FullLayer=631, SlidersLayer=632, VisualizerView=1,907. ✓
- [x] 0.8 Capture T4 (balance drag): FullLayer=568, SlidersLayer=1,443, VisualizerView=1,652. ✓
- [x] 0.9 Aggregate ratios: T2/T1 = 0.91× / 0.86× FullLayer/VisualizerView; T4/T3 = 0.90× / 0.87×. ✓
- [x] 0.10 Decision rule: both axes within ±20% AND visual freeze observed → Mechanism B (per plan §4.2 row 2). ✓
- [x] 0.11 Stop criteria: not triggered at Phase 0 (no Heisenbug, no Mechanism C alone). ✓
- [x] 0.12 Signpost edits reverted; clean tree verified. ✓
- [x] 0.13 Phase 0 results appended to research.md (commit `5d693c0`). ✓
- [x] 0.14 Spike branch deleted; never pushed (verified). ✓

**Acceptance criterion:** ✅ MET. Phase 0 results section present in `research.md`; spike branch deleted; Phase 1 scope was decided.

> **Lesson:** The Phase 0 instrumentation only measured the consumer (SwiftUI views). The actual root cause was at the **producer** (`VisualizerPipeline.pollTimer`). The Mechanism-B verdict was internally consistent with the data captured but the data was incomplete. See state.md "Lessons Learned" and `feedback_pipeline_end_to_end_diagnosis.md` memory.

---

## Phase 1A — Extraction (SKIPPED per Phase 0 verdict)

Phase 0 ruled out Mechanism A (FullLayer body rate within ±20% of control during drag — no parent invalidation spike). Phase 1A would have created a `MainWindowVisualizerLayer` recomposition boundary that addresses parent invalidation, which is not the issue here. Plan §4.2 row 2 explicitly says "Phase 1B only — Skip extraction" for Mechanism B. Skipped intentionally.

---

## Phase 1B — UserDefaults persistence on drag-end (COMPLETE)

Branch: `feat/mainwindow-visualizer-isolation`. Commit `f806465`.

- [x] 1B.1 Confirmed Option B-i unblocked. Only "hidden caller" was 2 unit tests in `AudioPlayerStateTests.swift` — these test the persistence contract, not gesture-rate didSet behavior. Updated to call new `commitVolumeToDefaults()` / `commitBalanceToDefaults()` API. ✓
- [x] 1B.2 Removed `UserDefaults.standard.set(volume, forKey: Keys.volume)` from `volume.didSet`; `didSet` now only propagates to engine + video controller. ✓
- [x] 1B.3 Added `internal func commitVolumeToDefaults()` on AudioPlayer with doc comment listing approved callers. ✓
- [x] 1B.4 Added `func commitVolume() { audioPlayer.commitVolumeToDefaults() }` to PlaybackCoordinator. ✓
- [x] 1B.5 Added `var onDragEnded: (() -> Void)?` to WinampVolumeSlider; invoked in `.onEnded`. ✓
- [x] 1B.6 Wired `onDragEnded: { playbackCoordinator.commitVolume() }` in MainWindowSlidersLayer. ✓
- [x] 1B.7 Verified no gesture-state flag in Audio/ or Models/ via `rg`. Zero hits. ✓
- [x] 1B.8 API surface audit: new internal API is exactly the 4 expected funcs + 2 onDragEnded properties. No visibility widening. ✓
- [x] 1B.9 Mirrored balance per Phase 0 (Mechanism B confirmed on balance axis): added `commitBalanceToDefaults`, `commitBalance`, and balance-slider `onDragEnded`. ✓
- [x] 1B.10 TSan build clean; all 57 tests pass. ✓
- [x] 1B.11 Committed: `f806465 fix(audio-player): commit volume/balance UserDefaults persistence on drag-end`. ✓

**Phase 1B acceptance criterion:** ✅ MET (UserDefaults writes only fire on drag-end, verified by behavior + test). However, Phase 1B alone did not eliminate the visualizer freeze — see Phase 1B+ extension below.

---

## Phase 1B+ — Idempotent routing + dead-write removal + slider pixel-step coalescing (COMPLETE)

> **Trigger:** V.1 Path A retest #2 after Phase 1B showed the freeze persisting with tiny flicker. Halt + Oracle consultation per plan §11 stop criterion.
>
> Codex Oracle (gpt-5.3-codex, xhigh) review identified two latent defects beyond the freeze itself:
> 1. `videoPlaybackController.volume` was being set twice per tick in `PlaybackCoordinator.setVolume` (once via `audioPlayer.volume.didSet`, once explicitly).
> 2. `StreamPlayer.volume` / `.balance` were stored-only with **zero readers anywhere** (verified structurally with ast-grep).
>
> Fix shipped per Oracle's Option 4. Branch: `feat/mainwindow-visualizer-isolation`. Commit `309a02f`.

- [x] 1B+.1 Removed `StreamPlayer.volume` / `.balance` dead stored properties. ✓
- [x] 1B+.2 Removed init sync of dead properties in `PlaybackCoordinator.init`. ✓
- [x] 1B+.3 Added idempotent guard in `PlaybackCoordinator.setVolume` / `.setBalance` (`guard audioPlayer.volume != vol else { return }`). ✓
- [x] 1B+.4 Removed duplicate `audioPlayer.videoPlaybackController.volume = vol` in `setVolume` (didSet handles it). ✓
- [x] 1B+.5 Removed dead `streamPlayer.volume / .balance` writes from `setVolume` / `setBalance`. ✓
- [x] 1B+.6 Added pixel-step coalescing in `WinampVolumeSlider.updateVolume` (`guard abs(volume - newVolume) >= 1.0 / Float(sliderWidth) else { return }`). ✓
- [x] 1B+.7 Added pixel-step coalescing in `WinampBalanceSlider.handleDrag` (after snap-to-center logic preserves haptic). ✓
- [x] 1B+.8 Updated misleading "zero cost on idle players" comment. ✓
- [x] 1B+.9 TSan build clean; all 57 tests pass. ✓
- [x] 1B+.10 Committed: `309a02f fix(audio-player): idempotent volume/balance routing, dead-write removal, slider pixel-step coalescing`. ✓

**Phase 1B+ acceptance criterion:** ✅ MET (defects removed, tests pass). However, the freeze STILL persisted as a tiny flicker. V.1 retest #2 again showed near-freeze. Per plan §11, halted + escalated to Gemini deep research.

---

## Phase 1C — VisualizerPipeline run-loop-mode fix (THE ACTUAL FREEZE FIX) (COMPLETE)

> **Diagnosis source:** Gemini deep research (1M context window) synthesizing Apple docs, WWDC 21 session 10047 (Explore TimelineView), Swift Forums on RunLoop mode behavior during gestures, and macOS 26 (Tahoe) Liquid Glass rendering changes.
>
> **Root cause:** `VisualizerPipeline.startPollTimer` used `Timer.scheduledTimer(withTimeInterval:repeats:block:)` which adds the timer to the run loop in `.default` mode. During an active `DragGesture`, the main run loop switches to `.eventTracking` mode — `.default`-mode timers pause. The visualizer's own consumer-side timer (`Timer.publish(... in: .common)`) kept firing and re-evaluating the body, but the data source `pollVisualizerData()` never ran, so `levels` (read by VisualizerView) stayed stale. Body fires → identical visual output → looks frozen.
>
> Branch: `feat/mainwindow-visualizer-isolation`. Commit `6a6bbf2`.

- [x] 1C.1 Read `VisualizerPipeline.startPollTimer` at HEAD; confirmed Gemini's diagnosis structurally. ✓
- [x] 1C.2 Replaced `Timer.scheduledTimer(...)` with `Timer(...)` + `RunLoop.main.add(timer, forMode: .common)`. ✓
- [x] 1C.3 TSan build clean; all 57 tests pass. ✓
- [x] 1C.4 Committed: `6a6bbf2 fix(visualizer-pipeline): poll timer in .common run-loop mode`. ✓

**Phase 1C acceptance criterion:** ✅ MET. V.1 Path A retest #3 PASSED on all four axes (V1–V4).

> **Note:** The original plan's Phase 1C was "promote `VisualizerView.updateTimer` to `@State`" as a fallback for Mechanism C. That was not the actual fix — `VisualizerView.updateTimer` already used `.common` mode correctly. The fix lives upstream at the producer (`VisualizerPipeline.pollTimer`).

---

## V.1 Verification Trace (COMPLETE)

Path A — qualitative (per Oracle V.1 acceptance bar):

- [x] V.1 Build Debug, TSan-OFF (matches Phase 0 spike conditions for like-for-like). ✓
- [x] V.1.1 V1 — volume slider drag ~10 s → spectrum animates throughout. ✓
- [x] V.1.2 V2 — volume slider click-and-hold without motion ~5 s → spectrum animates. ✓
- [x] V.1.3 V3 — balance slider drag ~10 s → spectrum animates. ✓
- [x] V.1.4 V4 — balance slider click-and-hold without motion ~5 s → spectrum animates. ✓

**Acceptance:** ✅ all four pass. Path B (formal Instruments re-trace with signposts) deemed unnecessary — V.1 Path A satisfies plan §9.1 acceptance.

---

## Phase 1C (original plan — `@State` Timer.publish promotion) — NOT FIRED

The original plan's Phase 1C was a fallback for "Mechanism C alone." Phase 0 ruled out Mechanism C, and the actual root cause was upstream at the producer (`VisualizerPipeline.pollTimer`), not in `VisualizerView.updateTimer`'s identity. The Phase 1C steps as written above (promote `let updateTimer` to `@State`) were therefore not executed — they would not have addressed the actual bug. The new run-loop-mode fix took its semantic place under the same heading number, intentionally.

---

## Documentation

- [x] D.1 Update `tasks/mainwindow-visualizer-isolation/state.md` to IMPLEMENTATION COMPLETE — V.1 PASS. ✓
- [x] D.2 Update `tasks/_context/state.md`: Sprint S3-1A row → IN PROGRESS / pending Oracle gate; resolved deferred-items entry. **(Pending — see task #24.)**
- [x] D.3 Update `docs/IMPLEMENTATION_PATTERNS.md` — `Timer.scheduledTimer` example in the VisualizerPipeline pattern needs the `.common`-mode correction. **(Pending — see task #32.)**
- [x] D.4 Update `docs/MILKDROP_WINDOW.md` — `audioTimer` example currently shows the buggy pattern. **(Pending — see task #33.)**
- [x] D.5 Update `BUILDING_RETRO_MACOS_APPS_SKILL.md` with the lesson on RunLoop mode mismatch in feeding pipelines. **(Pending — see task #34.)**
- [ ] D.6 No reference to `buildSpectrumAnalyzer()` was renamed in this task (Phase 1A skipped) — confirm `docs/MULTI_WINDOW_ARCHITECTURE.md` and `docs/MACAMP_ARCHITECTURE_GUIDE.md` accuracy stays consistent.

---

## PR

- [ ] P.1 Run Codex Oracle code-review gate on diff `main..feat/mainwindow-visualizer-isolation` (3 commits: `f806465`, `309a02f`, `6a6bbf2`) before pushing. Apply ACTIONABLE feedback.
- [ ] P.2 Push branch: `git push -u origin feat/mainwindow-visualizer-isolation`.
- [ ] P.3 Open PR #A with body summarizing all 3 commits + Phase 0 → V.1 narrative (off-plan diagnostic detour included).
- [ ] P.4 Request human review.
- [ ] P.5 On merge: confirm `feat/video-audio-engine-routing` (S3-2) is unblocked once `stream-pause-tail` (worktree B) also merges. (plan §12.2)
- [ ] P.6 Track follow-up: codebase-wide `Timer.scheduledTimer` run-loop-mode audit task (`tasks/timer-runloop-mode-audit/`) — 6 other callsites likely have the same bug.

---

## Stop Criteria Reminder

Halt the task and consult Oracle if any of these triggers fire (plan §11.1, pre-merge):

- Phase 0 returns Heisenbug or Mechanism C alone.
- Phase 1A measurement (V.1) shows `VisualizerView.body` rate ≥120% of control during drag, even after 1B was applied.
- TSan flags new races introduced by this work.
- Manual repro still shows freezing after both 1A and 1B.
- Phase 1A diff exceeds 30 net lines.

**Pre-merge halt procedure (plan §11.1):**

1. Stash or `git checkout -b wip/<context-tag>` to preserve work first.
2. **Decide Path A (default) or Path B (discard impl) per plan §11.1.** Default: A. Path B requires maintainer sign-off.
3. **Path A:** append halt findings to `research.md` on `feat/mainwindow-visualizer-isolation`, commit. No reset. Done.
4. **Path B (cherry-pick, the only Path B variant):**
   - 4.a Append halt findings to `research.md`, commit. Capture SHA: `FINDINGS_SHA=$(git rev-parse HEAD)`.
   - 4.b `git reset --hard <pre-impl-sha>` to discard implementation + findings commit (findings still in reflog).
   - 4.c `git cherry-pick "$FINDINGS_SHA"` to reapply findings on top of the reset branch.
5. **Forbidden:** editing findings into the working tree without committing, then `git reset --hard` — destroys uncommitted findings. Do not use this sequence.
6. Do NOT delete the feature branch.
7. Report back to the user before any further code changes.

**Post-merge regression:** follow plan §13 Rollback Plan, not the pre-merge procedure above.
