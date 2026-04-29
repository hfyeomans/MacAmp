# Todo: Timer.scheduledTimer Run-Loop Mode Audit

> **Source:** Derived from `tasks/timer-runloop-mode-audit/plan.md` (revised 2026-04-29).
> **Branch:** `fix/timer-runloop-mode-audit`. Cut from `main` at `883d085`.

---

## Pre-flight

- [x] PF.1 Confirm mwvi PR #80 merged to `main` (HEAD `883d085`, two close-out commits past the merge).
- [x] PF.2 `git checkout -b fix/timer-runloop-mode-audit` (done — branch active).
- [x] PF.3 Re-audit at HEAD: `rg -n "Timer\.scheduledTimer|RunLoop\.main\.add" MacAmpApp/` → confirmed inventory = 1 Pattern A + 4 Pattern B + 2 buggy. Original `research.md` was wrong about the marquee being broken; corrected.

## Phase 1 — Pattern B → A conversions (4 callsites)

- [ ] 1.1 `MacAmpApp/Audio/AudioEngineController.swift:207-224` — convert `progressTimer` to Pattern A. Add single-line comment.
- [ ] 1.2 `MacAmpApp/Audio/StreamPlayer.swift:232-244` — convert `elapsedTimer` to Pattern A. Add single-line comment.
- [ ] 1.3 `MacAmpApp/Views/Windows/VideoWindowChromeView.swift:216-234` — convert `metadataScrollTimer` to Pattern A. Add single-line comment. Drop the `if let timer = metadataScrollTimer` guard (no longer needed).
- [ ] 1.4 `MacAmpApp/Views/MainWindow/WinampMainWindowInteractionState.swift:30-53` — convert `scrollTimer` to Pattern A. Add single-line comment. Drop the `if let timer = scrollTimer` guard.
- [ ] 1.5 Build with TSan: `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`. Acceptance: clean.

## Phase 2 — Buggy → A conversions (2 callsites in ButterchurnPresetManager)

- [ ] 2.1 `MacAmpApp/ViewModels/ButterchurnPresetManager.swift:204-213` — convert `cycleTimer` to Pattern A. Add single-line comment.
- [ ] 2.2 `MacAmpApp/ViewModels/ButterchurnPresetManager.swift:232-244` — convert `trackTitleTimer` to Pattern A. Add single-line comment.
- [ ] 2.3 Build with TSan. Acceptance: clean.

## Phase 3 — Verification

- [ ] V.4 Run full test suite with TSan: `xcodebuildmcp macos test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`. Acceptance: 59/59 passing, zero TSan warnings.
- [ ] V.6 Audit re-run: `rg -n "Timer\.scheduledTimer" MacAmpApp/` returns zero in production source. (Test files allowed if any.) Confirms full normalization.
- [ ] V.1 V.2 V.3 — manual qualitative tests are user-facing acceptance criteria; user runs them post-PR. Skip automated verification here per Phase 0 mwvi lesson (gesture-vs-timer interactions can't be exercised in unit tests at acceptable cost).

## Phase 4 — Codex Oracle pre-PR code-review gate

- [ ] 4.1 Run Codex Oracle with `mcp__codex-cli__codex`, model `gpt-5.3-codex`, `reasoningEffort: xhigh`. Pass the diff and ask for review against (a) Pattern correctness, (b) any subtle Sendable/MainActor changes between `scheduledTimer` and manual `Timer(...)`, (c) whether to also extract a `Timer.scheduledOnCommon` helper in this PR vs as a follow-up, (d) commit-message accuracy.
- [ ] 4.2 Apply ACTIONABLE feedback. Consider NITs case-by-case.

## Phase 5 — Commit + PR

- [ ] 5.1 Single commit. Use the message in plan.md §7.
- [ ] 5.2 Re-run the V.4 + V.6 verification on the final tree.
- [ ] 5.3 **STOP and report to user before pushing.** User reviews diff before PR is opened.
- [ ] 5.4 On user go-ahead: `git push -u origin fix/timer-runloop-mode-audit`.
- [ ] 5.5 Open PR with `gh pr create`. Reference mwvi PR #80 and the `feedback_pipeline_end_to_end_diagnosis.md` + `feedback_ast_grep_structural_search.md` lessons.
- [ ] 5.6 Wait for human review.

## Stop Criteria

- TSan flags new race → halt + Oracle.
- Any timer stops firing after conversion → halt; re-check the missing `RunLoop.main.add(...)` line.
- Build fails after any phase → halt and diagnose before proceeding.
- Audit re-run still shows `Timer.scheduledTimer` matches → halt; missed a callsite.
