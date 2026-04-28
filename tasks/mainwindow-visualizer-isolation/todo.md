# Todo: MainWindow Visualizer Isolation

> **Source:** Derived from `tasks/mainwindow-visualizer-isolation/plan.md` and `research.md`.
> **Sprint:** S3, Wave S3-1, Worktree A. Branch: `feat/mainwindow-visualizer-isolation`.
> Phases gated by Phase 0 results — see plan.md §4 decision rule.

---

## Phase 0 — Instruments Spike (REQUIRED)

Branch: `spike/mwvi-volume-drag-profile` (throwaway, never pushed).

- [ ] 0.1 Create throwaway branch from `main`: `git checkout main && git pull && git checkout -b spike/mwvi-volume-drag-profile`. (plan §4)
- [ ] 0.2 Build with TSan disabled and Debug config: `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","NO","-configuration","Debug"]}'`. (plan §4.1 step 2)
- [ ] 0.3 Add temporary `os_signpost(.event, …)` calls (subsystem `com.macamp.spike`, category `swiftui-body`) to the top of `MainWindowFullLayer.body`, `MainWindowSlidersLayer.body`, and `VisualizerView.body`. Do NOT commit. (plan §4.1 step 3)
- [ ] 0.4 Open Instruments → SwiftUI template (or Time Profiler + os_signpost track). Launch the built MacAmp from Instruments. (plan §4.1 step 4)
- [ ] 0.5 Capture **T1 (volume control):** play a known-good local file, wait 5 s, record 30 s with no slider interaction. (plan §4.1 step 6)
- [ ] 0.6 Capture **T2 (volume drag):** start fresh recording, drag volume slider continuously for 30 s, stop. (plan §4.1 step 7)
- [ ] 0.7 Capture **T3 (balance control):** start fresh recording, 30 s of playback, no slider interaction. (plan §4.1 step 8)
- [ ] 0.8 Capture **T4 (balance drag):** start fresh recording, drag balance slider continuously for 30 s, stop. (plan §4.1 step 9)
- [ ] 0.9 Aggregate the four traces; compute T2-vs-T1 and T4-vs-T3 body evaluation rate ratios per signpost. (plan §4.2)
- [ ] 0.10 Determine dominant mechanism per plan §4.2 decision rule. Apply rule independently to volume axis (T2/T1) and balance axis (T4/T3); take union of Phase 1 scopes if they disagree.
- [ ] 0.11 Apply stop criteria (plan §11.1): if Heisenbug or Mechanism C alone, halt and consult Oracle before any Phase 1 work.
- [ ] 0.12 **Cleanup (mandatory before committing):** revert all signpost edits added in 0.3 (e.g., `git checkout -- MacAmpApp/Views/...` for the three modified files). Run `git status` and confirm working tree is clean of code edits before continuing. (plan §4.3)
- [ ] 0.13 Switch to `feat/mainwindow-visualizer-isolation` branch (create from `main` if it does not yet exist) and append a "Phase 0 — Spike Results" section to `tasks/mainwindow-visualizer-isolation/research.md` with: Instruments tool versions, raw T1-T4 evaluation counts, T2/T1 and T4/T3 ratios, dominant mechanism per axis, resulting Phase 1 scope. Commit. (plan §4.3)
- [ ] 0.14 Delete spike branch: `git branch -D spike/mwvi-volume-drag-profile`. Verify it was never pushed: `git ls-remote --heads origin 'spike/*'` should return zero rows; double-check with `git branch -r | rg 'spike/'` (also expected: zero rows). (plan §4.3, §12.1)

**Acceptance criterion:** research.md has a populated "Phase 0 — Spike Results" section on `feat/mainwindow-visualizer-isolation`; spike branch is deleted; Phase 1 scope is decided.

---

## Phase 1A — Extraction (executes only if Phase 0 → Mechanism A or A+B)

Branch: `feat/mainwindow-visualizer-isolation`.

- [ ] 1A.1 Create file `MacAmpApp/Views/MainWindow/MainWindowVisualizerLayer.swift` with the exact content in plan §5.1. (plan §5.1)
- [ ] 1A.2 In `MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift` line 33, replace `buildSpectrumAnalyzer()` with `MainWindowVisualizerLayer()`. (plan §5.2 edit 1)
- [ ] 1A.3 In `MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift`, delete lines 132-140 (the `// MARK: - Spectrum Analyzer` divider and the `buildSpectrumAnalyzer()` helper). (plan §5.2 edit 2)
- [ ] 1A.4 Run `xcodegen generate`. (plan §5.3)
- [ ] 1A.5 Build with TSan: `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`. Acceptance: clean build, zero new warnings.
- [ ] 1A.6 Diff sanity check (`git diff --stat main`): expected ~17 lines added (new `MainWindowVisualizerLayer.swift`: ~16 lines + 1-line callsite replacement in `MainWindowFullLayer.swift`) and ~8 lines removed (deletion of the `// MARK: - Spectrum Analyzer` divider plus the `buildSpectrumAnalyzer()` helper in `MainWindowFullLayer.swift`). If the cumulative `+ - ` count exceeds 30 net (additions + deletions / 2 ≥ 30), halt per plan §11.1 trigger 6.
- [ ] 1A.7 Commit: "fix(main-window): extract MainWindowVisualizerLayer to isolate visualizer recomposition".

**Acceptance criterion:** App builds clean with TSan; diff matches the anticipated size in plan §8 Files Inventory.

---

## Phase 1B — UserDefaults persistence debounce (executes only if Phase 0 → Mechanism B or A+B)

Branch: `feat/mainwindow-visualizer-isolation` (same branch as 1A; separate commits).

> **Design contract (plan §6.1):** persistence is *call-site-driven*, not flag-driven. No transient gesture state is added to `AudioPlayer`. Use Option B-i (single chosen sub-variant); only fall back to B-ii if B-i is blocked by a discovered constraint.

- [ ] 1B.1 Confirm Option B-i is unblocked (e.g., no other code path that depends on `volume.didSet` writing to `UserDefaults`). If a hidden caller exists, halt and re-evaluate. Document the choice in the commit message.
- [ ] 1B.2 In `MacAmpApp/Audio/AudioPlayer.swift:65-71`, **remove** the `UserDefaults.standard.set(volume, forKey: Keys.volume)` line from `volume.didSet`. `didSet` retains only the audio-graph propagation (`engine?.setVolume(volume)`, `videoPlaybackController.volume = volume`). (plan §6.1 Option B-i, point 1)
- [ ] 1B.3 Add a new `internal func commitVolumeToDefaults()` method on `AudioPlayer` that performs `UserDefaults.standard.set(volume, forKey: Keys.volume)`. Doc comment must list approved callers per plan §6.1 point 3: `PlaybackCoordinator.commitVolume()` (and any existing init-time persistence path if applicable). (plan §6.1 point 3)
- [ ] 1B.4 In `MacAmpApp/Audio/PlaybackCoordinator.swift` near line 193 (next to `setVolume(_:)`), add `func commitVolume() { audioPlayer.commitVolumeToDefaults() }`. No other behavior. (plan §6.1 point 2)
- [ ] 1B.5 In `MacAmpApp/Views/Components/WinampVolumeSlider.swift`, add an optional closure parameter `var onDragEnded: (() -> Void)? = nil` to `WinampVolumeSlider`. In `volumeInteractionArea`'s `.onEnded { _ in isDragging = false }` (`WinampVolumeSlider.swift:64-66`), invoke `onDragEnded?()`. (plan §6.1 point 4)
- [ ] 1B.6 In `MacAmpApp/Views/MainWindow/MainWindowSlidersLayer.swift:46-54`, pass `onDragEnded: { playbackCoordinator.commitVolume() }` when constructing `WinampVolumeSlider`. (plan §6.1 point 4)
- [ ] 1B.7 Verify no `isVolumeDragActive` (or equivalent gesture-state flag) was added to `AudioPlayer`, `EqualizerController`, `PlaybackCoordinator`, or any model-layer file. Grep: `rg -n "isVolumeDragActive|volumeDragInProgress|volumeIsDragging" MacAmpApp/Audio/ MacAmpApp/Models/`. Acceptance: zero hits. (plan §6.1 point 5)
- [ ] 1B.8 Audit the diff for Principle 5 (API Surface): expected new `internal` API surface is exactly (a) `AudioPlayer.commitVolumeToDefaults()`, (b) `PlaybackCoordinator.commitVolume()`, and (c) one new optional stored property `WinampVolumeSlider.onDragEnded: (() -> Void)? = nil` (which expands the synthesized memberwise initializer of `WinampVolumeSlider` by exactly one labeled parameter). No previously-`private` symbol gains broader visibility. Document any deviation in the PR body. (plan §10 Risks; plan §6.1)
- [ ] 1B.9 Mirror the same plumbing for the balance slider **only if** Phase 0 evidence supports it (i.e., T4 vs T3 indicated Mechanism B for balance). Otherwise leave balance as-is and add a one-line note to the PR body explaining the deferral. (plan §6.2)
- [ ] 1B.10 Build with TSan: `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`. Acceptance: clean.
- [ ] 1B.11 Commit as a separate commit from 1A: `fix(audio-player): commit volume UserDefaults persistence on drag-end`.

**Acceptance criterion:** During a sustained volume drag, `UserDefaults.standard.set(...)` for `volume` fires exactly once (on drag-end), verified via a temporary `os_log` in `commitVolumeToDefaults` or a breakpoint. Remove the temporary instrumentation before commit. Independently confirm via grep that no gesture-state flag was added to `AudioPlayer` (per 1B.7).

---

## Phase 1C — Timer promotion fallback (executes only if Phase 0 → Mechanism C alone, very unlikely)

- [ ] 1C.1 Halt and consult Oracle before proceeding (plan §11 stop criterion 2).
- [ ] 1C.2 If Oracle approves: in `MacAmpApp/Views/VisualizerView.swift:38`, convert `let updateTimer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()` to `@State private var updateTimer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()`. Verify `.onReceive(updateTimer)` still subscribes correctly.
- [ ] 1C.3 Build + manual smoke test: visualizer animates at 30 fps idle and during drag.
- [ ] 1C.4 Commit: "fix(visualizer): promote update timer to @State for stable identity".

**Acceptance criterion:** `VisualizerView.body` evaluation count during drag returns to control baseline.

---

## Verification

- [ ] V.1 Repeat Phase 0 measurement protocol on `feat/mainwindow-visualizer-isolation` (post-fix). Capture control + drag traces for volume and balance. (plan §9.1)
- [ ] V.2 Append "Phase 1 — Verification Trace" section to `research.md` with raw counts and pass/fail per the §9.1 table. Acceptance: all three rows pass within ±20% bounds.
- [ ] V.3 Manual repro checklist (plan §9.2):
  - [ ] V.3.a TSan build is clean.
  - [ ] V.3.b Local file plays; spectrum bars animate at ~30 fps idle.
  - [ ] V.3.c Volume slider drag for 5 s — bars continue animating.
  - [ ] V.3.d Balance slider drag for 5 s — bars continue animating.
  - [ ] V.3.e Double-size mode (Ctrl+D) — both drag tests pass.
  - [ ] V.3.f Skin #2 loaded — volume drag passes; VISCOLOR palette correct.
  - [ ] V.3.g Skin #3 loaded — volume drag passes.
  - [ ] V.3.h Click visualizer area — mode cycling spectrum → oscilloscope → none → spectrum still works.
  - [ ] V.3.i Toggle shade mode — main-window visualizer disappears; toggle back — reappears and animates.
  - [ ] V.3.j Shade + playlist visualizer enabled — playlist-window visualizer untouched and animates.
- [ ] V.4 Regression sweep (plan §9.3):
  - [ ] V.4.a `xcodebuildmcp macos test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — full 57-test suite passes, zero TSan warnings.
  - [ ] V.4.b No new build-log warnings vs. `main`.
  - [ ] V.4.c Skin reload propagates VISCOLOR change into spectrum bars.
- [ ] V.5 If Phase 1B fired: instrument-confirm `UserDefaults` write fires once on drag-end (acceptance criterion in §1B above).

---

## Documentation

- [ ] D.1 Update `tasks/mainwindow-visualizer-isolation/state.md`: status PLANNED → IN PROGRESS at Phase 0 start; → PHASE 1 LOCAL after verification passes; → MERGED post-PR-merge.
- [ ] D.2 Update `tasks/_context/state.md`:
  - [ ] D.2.a Mark "MainWindowVisualizerLayer isolation" deferred-items entry (lines 142-165) as resolved with PR link.
  - [ ] D.2.b Update Sprint S3 ordering table at lines 294-301: mark `mainwindow-visualizer-isolation` row as MERGED with PR #.
  - [ ] D.2.c Update per-task plan + todo status table (around lines 327-335): set this task's row to "MERGED" with final Oracle plan score.
  - [ ] D.2.d If Phase 1B fired, add a one-line note to "From Wave 2b — Future Optimization" deferred-items entry that the volume UserDefaults debounce was completed as part of this task.
- [ ] D.3 No `docs/` updates required — this is a localized fix, not an architecture change. Confirm no `docs/MULTI_WINDOW_ARCHITECTURE.md` or `docs/MACAMP_ARCHITECTURE_GUIDE.md` reference to `buildSpectrumAnalyzer()` exists; if found, replace with `MainWindowVisualizerLayer`.

---

## PR

- [ ] P.1 Push branch: `git push -u origin feat/mainwindow-visualizer-isolation`.
- [ ] P.2 Open PR with title and body skeleton from plan §12.3. Fill in the conditional sections based on which phases fired.
- [ ] P.3 Run `pr-review-toolkit:review-pr` skill on the PR. Address all ACTIONABLE comments via `scripts/resolve-pr-comments.sh`. (plan §12.4)
- [ ] P.4 Run Codex Oracle review on the diff (`codex-oracle-workflow` skill, model `gpt-5.5`, reasoningEffort `xhigh`). Apply ACTIONABLE feedback.
- [ ] P.5 Request human review.
- [ ] P.6 On merge: confirm `feat/video-audio-engine-routing` (S3-2) is unblocked once `stream-pause-tail` (worktree B) also merges. (plan §12.2)

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
