# Todo: GitHub Issues Triage (S4-2)

Updated: 2026-10-02

Starts after the Structure Sprint and S4-1 merge (D-S4). Scope, order and review process live in `state.md`.

## Phase 0: Triage

- [ ] 0.1 `gh issue list`: confirm the open set (#47, #79, #84, #88) and check for new issues
- [ ] 0.2 `gh issue view` #47, #79 and #84: read new comments; collect attached skins, recordings and version details
- [ ] 0.3 Reproduce #47: enumerate every Cmd+Shift+1/2/3 binding and confirm which wins
- [ ] 0.4 Re-confirm P-6 on HEAD
- [ ] 0.5 Reproduce #79: drop on the window, Dock icon and app icon; Finder double-click; "Open With"; Cmd+O with a video file
- [ ] 0.6 Reproduce #84 with the Nucleo NLog v102 skin, side by side with the default skin
- [ ] 0.7 Confirm the `timeControlStatus` residual on HEAD
- [ ] 0.8 Record repro, hypothesis and subsystem per item in `research.md`
- [ ] 0.9 Label and size each issue on GitHub; reply on each with its triage status

## Phase 1: Plan

- [ ] 1.1 Write `plan.md`: one fix plan, branch and PR per item
- [ ] 1.2 Build the file-conflict map across the branches and set the merge order (default: #47, P-6, #79, #84)
- [ ] 1.3 Fold in S4-1's deprecation conclusions for these code paths
- [ ] 1.4 Owner sign-off on scope and order

## Phase 2: Fixes (one branch and PR each)

- [ ] 2.1 #47 shortcut conflict
- [ ] 2.2 P-6 video-to-audio auto-play; close P-6 in `tasks/done/avplayer-native-video-dsp/placeholder.md` and `tasks/_context/deferred.md`; remove the known-issue notes from `docs/VIDEO_WINDOW.md`
- [ ] 2.3 `timeControlStatus` residual, with P-6 or on its own branch per `plan.md`
- [ ] 2.4 #79: audio and video document types, drop handling, Cmd+O content types
- [ ] 2.5 #84 skin rendering; verify across 3-5 skins including the default
- [ ] 2.7 RemoteLayerTreeDisplayLinkClient warnings, only if they recur without a debugger
- [ ] 2.8 Per PR: `xcodegen generate`, `xcodebuildmcp macos build` and `test` with `--json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`, a manual smoke test of the affected surface, then one exhaustive `/codex:review --base main`; the owner merges

## Phase 3: Close-out

- [ ] 3.1 Close each issue with a link to its merged PR
- [ ] 3.2 Update the skin docs for #84 and the `_context` files
- [ ] 3.3 `git mv tasks/github-issues-triage tasks/done/`
