# TODO: GitHub Issues Triage (S4-2)

> **Status:** 📋 QUEUED — nothing started. Scaffolded 2026-09-05.
> **Blocked on:** Post-S3 Structure Sprint (user mandate) + S4-1 `swift64-macos27-readiness` (assumption — confirm with the user).
> **Gate:** Phase 2 must not begin before `plan.md` scores ≥ 9/10 with Codex Oracle.

---

## Phase 0 — Triage

- [ ] 0.1 `gh issue list` — re-fetch the open set; confirm the five below are still the scope and nothing new landed
- [ ] 0.2 `gh issue view` each of #84, #79, #78, #47 — read every comment added since 2026-09-05; collect any skins, recordings, or version details the reporters attached
- [ ] 0.3 Reproduce **#84** on HEAD (obtain the Nucleo NLog v102 skin; capture defects side-by-side against the default skin)
- [ ] 0.4 Reproduce **#79** on HEAD — three paths separately: drag onto window, drag onto Dock icon, Finder double-click. Also record the Cmd+O `[.audio]` restriction (`AppCommands.swift:99`)
- [ ] 0.5 Reproduce **#78** on HEAD — four sub-symptoms separately: playlist detach on player move, minimization, window-position persistence, EQ window closing at launch
- [ ] 0.6 Reproduce **#47** on HEAD — enumerate every Cmd+Shift+1/2/3 binding and confirm which wins
- [ ] 0.7 Re-confirm **P-6** (video→audio no auto-play) against HEAD — it was observed pre-merge on the S3-2 pivot branch and may have moved
- [ ] 0.8 Record repro + root-cause hypothesis + subsystem per issue in `research.md`
- [ ] 0.9 Label each issue on GitHub (bug/enhancement, subsystem) and size it (Small / Medium / Large)
- [ ] 0.10 Note cross-issue overlaps — especially #78 vs the long-standing "Hide Main Window not working" deferred item in `_context/state.md`
- [ ] 0.11 Reply on each GitHub issue acknowledging triage status

## Phase 1 — Plan + Oracle gate

- [ ] 1.1 Write `plan.md` — one fix plan per issue, each with its own branch + PR
- [ ] 1.2 Build the file-conflict map across the per-issue branches; set the merge order (suggested: #47 → P-6 → #79 → #84 → #78)
- [ ] 1.3 Fold in whatever S4-1 concluded about deprecations that touch these code paths
- [ ] 1.4 Codex Oracle plan review (`gpt-5.5`, `reasoningEffort: xhigh`) — iterate to ≥ 9/10
- [ ] 1.5 User sign-off on scope + order

## Phase 2 — Implementation (one branch + one PR per issue)

- [ ] 2.1 **#47** — Cmd+Shift+1-3 shortcut conflict → branch, fix, TSan build + test, Oracle review, PR, close the issue via the PR
- [ ] 2.2 **P-6** — video→audio auto-play → branch, fix, TSan build + test, Oracle review, PR; close P-6 in `tasks/done/avplayer-native-video-dsp/placeholder.md` and in `_context/state.md`
- [ ] 2.3 **#79** — drag-and-drop + double-click open (and the Cmd+O `[.audio]` restriction) → branch, fix, TSan build + test, Oracle review, PR
- [ ] 2.4 **#84** — Nucleo NLog v2G rendering defects → branch, fix, verify across 3-5 skins incl. the default, TSan build + test, Oracle review, PR
- [ ] 2.5 **#78** — window joining/clamping + minimization + full window-state persistence → branch, fix, TSan build + test, Oracle review, PR
- [ ] 2.6 Per PR: `xcodegen generate` → `xcodebuildmcp macos build`/`test` with `-enableThreadSanitizer YES`, and a manual smoke on the affected surface

## Phase 3 — Close-out

- [ ] 3.1 Confirm every issue is closed on GitHub with a link to its merged PR
- [ ] 3.2 Update `_context/state.md`, `_context/tasks_index.md`, `_context/resume-prompt.md`
- [ ] 3.3 Update `docs/` where behavior changed (windowing docs for #78, skin docs for #84)
- [ ] 3.4 `git mv tasks/github-issues-triage/ tasks/done/github-issues-triage/`

---

## Notes

- Every issue gets its own Oracle review + PR for user review before merge, regardless of size (`feedback_sprint_workflow.md`).
- Use `./scripts/resolve-pr-comments.sh <PR#>` for automated-reviewer threads.
