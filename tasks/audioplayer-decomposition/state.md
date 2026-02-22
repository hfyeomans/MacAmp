# Task State: AudioPlayer.swift Decomposition

> **Description:** Tracks the current state of the AudioPlayer decomposition task including progress, blockers, and decisions.
> **Purpose:** Single source of truth for task status, updated as implementation progresses.

---

## Current Phase: COMPLETE — Merged as PR #52

## Status: Phases 1-3 implemented, reviewed (2x Oracle, Gemini, CodeRabbit), merged to main. Phase 4 deferred.

## Branch: `worktree-audioplayer-decomp` (merged)

## Context

- **Origin:** Code review of last 5 PRs (2026-02-18) flagged swiftlint suppressions in AudioPlayer.swift
- **Trigger:** PR #43 added `// swiftlint:disable file_length` and `type_body_length` suppressions
- **Pattern:** Follows WindowCoordinator decomposition (PR #45, 1,357 → 223 lines)
- **File:** `MacAmpApp/Audio/AudioPlayer.swift` — started at 1,095 lines, 2 swiftlint suppressions

## Final Results

| Metric | Before | After |
|--------|--------|-------|
| AudioPlayer.swift | 1,095 lines | 945 lines (**-150**) |
| New files | 0 | 1 (EqualizerController.swift, 195 lines) |
| swiftlint suppressions | 2 | 2 (both still needed at 945/~905 lines) |

## Commits (PR #52)

| # | Phase | Commit | Description |
|---|-------|--------|-------------|
| 1 | Phase 1 | `1b7e76f` | Extract EqualizerController (-93 lines) |
| 2 | Phase 2 | `2fbed90` | Move getFrequencyData to VisualizerPipeline (-47 lines) |
| 3 | Phase 3 | `37c3598` | Remove unused FourCC extension (-18 lines) |
| 4 | Oracle #1 | `8679123` | Private equalizer, didSet handlers |
| 5 | Oracle #2 | `c87aa07` | Deinit safety, eqBands hardening, private visualizerPipeline |
| 6 | CodeRabbit | `dd8866e` | Remove unused imports, private configureEQ |
| 7 | Gemini fix | `b1d8700` | URL-based identity for auto-preset clear task |

## Key Decisions

1. **Facade pattern** — AudioPlayer's public API unchanged. All callers continue using `@Environment(AudioPlayer.self)`
2. **EQ extraction first** — Lowest risk, highest self-containment
3. **Phase 4 deferred** — Engine/transport extraction is high-risk due to seek state machine complexity
4. **No new @Environment types** — Views didn't need to change environment bindings
5. **`equalizer` and `visualizerPipeline` are `private`** — Enforces facade boundary
6. **`didSet` on EQ properties** — Ensures eqNode stays in sync whether set via methods or direct assignment
7. **deinit safety** — `removeTap()` dispatched to main queue when deinit runs off-main-thread
8. **URL-based auto-preset identity** — Prevents flicker on duplicate titles or replays

## Phase 4: Why Deferred

The engine transport extraction (play/pause/stop/seek + engine lifecycle) is deferred because:

1. **Seek state machine complexity** — Three interlocking guard mechanisms (`currentSeekID`, `seekGuardActive`, `isHandlingCompletion`) were extensively debugged across multiple PRs
2. **Tight coupling** — `scheduleFrom()`, `seek()`, `play()`, `pause()`, `stop()` all share mutable state
3. **Completion handler wiring** — `scheduleFrom` uses `seekID` matching to ignore stale completions
4. **Timing-sensitive guards** — Multiple `Task.sleep` delays coordinate guard clearing
5. **Cost/benefit** — 945 lines is above 600 warning but well below 1,200 error

**Recommendation:** Only pursue Phase 4 if unit tests for the seek state machine are added first.

## Blockers

None.

## Open Questions

None remaining.
