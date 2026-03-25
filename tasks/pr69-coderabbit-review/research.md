# Research: PR #69 CodeRabbit Comment Classification

## Scope

Classify 7 CodeRabbit comments on PR #69 for branch `feature/airplay-integration`.

## Context Confirmed

- Working branch: `feature/airplay-integration`
- Worktree clean at review time
- AirPlay Phase 1 was attempted and failed:
  - `AVRoutePickerView` does not route `AVAudioEngine` output on macOS
  - in-app AirPlay UI approach is defunct
- Phase 2 is complete:
  - Now Playing + remote commands implemented
  - `tasks/airplay-integration/state.md` says `Phase 2 COMPLETE (Oracle 9/10)`

## File Findings

### `BUILDING_RETRO_MACOS_APPS_SKILL.md`

- The table around line 7092 is valid and readable.
- Missing blank lines around a Markdown table is style-only, not semantic.

### `tasks/airplay-integration/plan.md`

- Header status still says `Oracle Reviewed (8/10) — Ready for user approval`.
- That is stale after the later failure of Phase 1 and completion of Phase 2.
- The fenced code block in the architecture section has no language identifier.

### `tasks/airplay-integration/research-avplayer-rewrite.md`

- Recommendation still says to stick to `plan.md` Phase 1.3.
- That recommendation is stale because Phase 1.3 was disproven by implementation testing.

### `tasks/airplay-integration/research-gemini-airplay-hal.md`

- Conclusion says `The Plan is Correct` and reinforces Phase 1.3 as the viable path.
- That is stale after the failure discovery.

### `tasks/airplay-integration/state.md`

- Header correctly says `Phase 0 COMPLETE, Phase 1 DEFUNCT, Phase 2 COMPLETE (Oracle 9/10), Phase 3 DEFUNCT`.
- `What's Still Needed` still lists Now Playing, which conflicts with current status.

### `tasks/airplay-integration/todo.md`

- Header status still says `Pending Implementation`.
- The body shows Phase 1 defunct and Phase 2 completed, so the header is stale.
