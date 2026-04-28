# Todo: Timer.scheduledTimer Run-Loop Mode Audit

> **Source:** Derived from `tasks/timer-runloop-mode-audit/plan.md`.
> **Branch:** `fix/timer-runloop-mode-audit`. Run after mwvi PR #A merges.

---

## Pre-flight

- [ ] PF.1 Confirm mwvi PR #A merged to `main`. If not, wait — both touch related concerns and merging in order keeps `_context/state.md` cleanly synced.
- [ ] PF.2 `git checkout main && git pull && git checkout -b fix/timer-runloop-mode-audit`.
- [ ] PF.3 Re-run the audit: `rg -n "Timer\.scheduledTimer" MacAmpApp/`. Confirm the 3 buggy callsites still match `tasks/timer-runloop-mode-audit/research.md` (no drift since plan was written).

## Phase 1 — Fix `WinampMainWindowInteractionState.scrollTimer` (HIGH severity)

- [ ] 1.1 Read `MacAmpApp/Views/MainWindow/WinampMainWindowInteractionState.swift:25-50` at HEAD.
- [ ] 1.2 Convert `Timer.scheduledTimer` to manual `Timer(timeInterval:repeats:block:)` + `RunLoop.main.add(timer, forMode: .common)` + `scrollTimer = timer`. Pattern matches mwvi commit `6a6bbf2`.
- [ ] 1.3 Add a single-line comment explaining `.common`-mode requirement (so the next contributor doesn't regress).
- [ ] 1.4 Build with TSan: `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`. Acceptance: clean.

## Phase 2 — Fix `ButterchurnPresetManager.cycleTimer` and `.trackTitleTimer` (LOW severity, both)

- [ ] 2.1 Read `MacAmpApp/ViewModels/ButterchurnPresetManager.swift:200-260` at HEAD.
- [ ] 2.2 Convert `cycleTimer` (line 208) to manual-Timer + `.common` add.
- [ ] 2.3 Convert `trackTitleTimer` (line 239) to manual-Timer + `.common` add.
- [ ] 2.4 Add single-line `.common`-mode comment on each.
- [ ] 2.5 Build with TSan. Acceptance: clean.

## Phase 3 — Verification

- [ ] V.1 Run `MacAmp.app` Debug build. Play a local file. Drag the volume slider continuously for 5 s — confirm the main-window marquee title text continues scrolling. Acceptance: ✅ scroll persists during drag.
- [ ] V.2 Open Milkdrop window. Set Butterchurn cycle interval to 5 s for testing. Wait for a cycle. Then drag the volume slider for ~6 s spanning a cycle tick. Confirm preset still cycles. Acceptance: ✅ cycle ticks.
- [ ] V.3 Trigger a track-title overlay (Butterchurn track-title-overlay-on-track-change setting). Drag a slider for ≥ refresh interval. Confirm the title overlay refreshes. Acceptance: ✅ overlay refreshes.
- [ ] V.4 Run full test suite with TSan: `xcodebuildmcp macos test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`. Acceptance: 57/57 passing, zero TSan warnings.

## Phase 4 — Audit re-run

- [ ] 4.1 Re-run `rg -n "Timer\.scheduledTimer" MacAmpApp/` and confirm the 3 buggy callsites no longer match the pattern.
- [ ] 4.2 Confirm via structural search: `sg --lang swift -p 'Timer.scheduledTimer($$$)'` should now return only the converted-but-still-named callsites with their explicit `.common`-add pattern.

## Phase 5 — Commit + PR

- [ ] 5.1 Decide single-commit vs three-atomic-commits based on diff size. If under ~30 lines total, single commit fine.
- [ ] 5.2 Run Codex Oracle code-review gate on the diff. Apply ACTIONABLE feedback.
- [ ] 5.3 Push: `git push -u origin fix/timer-runloop-mode-audit`.
- [ ] 5.4 Open PR. Reference mwvi PR #A in the body and the `feedback_pipeline_end_to_end_diagnosis.md` lesson.
- [ ] 5.5 Request human review.

## Stop Criteria

- TSan flags new race → halt + Oracle.
- Marquee still frozen during drag after Phase 1 fix → halt; there's a second cause.
- Build fails after any phase → halt and diagnose before proceeding.
