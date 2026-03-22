# Codex PR57 Review Result

## Scope

Historical review of PR57 merge commit `cf71762` with:

- historical code snapshot in `/tmp/macamp-pr57-review`
- installed `duplicate-code-investigator` skill
- current repo task docs provided through `--add-dir /Users/hank/dev/src/MacAmp`

## Assessment

This is the strongest Codex validation so far.

Why:

- the run targeted the real audio-pipeline patch instead of a later docs-only diff
- the agent explicitly used the duplicate-investigator workflow
- the run delegated duplicate-path analysis to an explorer agent
- the main agent validated findings with `rg` / `ast-grep` style evidence
- the output returned ranked findings instead of generic prose

## Findings Reported

### High

- Natural stream termination lacks a coordinator-owned choke point.
- Result: radio ownership can remain stale and the UI can present a fake-playing state.

Key refs:

- `StreamDecodePipeline.swift#L283`
- `StreamPlayer.swift#L142`
- `PlaybackCoordinator.swift#L127`
- `PlaybackCoordinator.swift#L54`
- `PlaybackCoordinator.swift#L263`
- `StreamDecodePipeline.swift#L194`
- `StreamPlayer.swift#L109`

### Medium

- `activateStreamBridge()` bypasses the engine-start hard gate.
- Result: bridge can be marked active and capabilities enabled without a running engine.

Key refs:

- `AudioPlayer.swift#L463`
- `lessons-learned.md#L147`
- `AudioPlayer.swift#L836`
- `AudioPlayer.swift#L838`
- `AudioPlayer.swift#L844`
- `PlaybackCoordinator.swift#L88`

### Medium

- Playlist resolution is a stale async handoff path outside pipeline-owned teardown.
- Result: old playlist fetch can continue after stop/source switch.

Key refs:

- `StreamDecodePipeline.swift#L84`
- `StreamDecodePipeline.swift#L321`
- `StreamDecodePipeline.swift#L213`

## Negative Findings

- No duplicate `configureFramer` regression found in this range.
- No confirmed same-event double-teardown bug found.
- Bridge teardown fan-out still exists and still indicates missing single-owner lifecycle design.

## Conclusion

The skill is doing the intended job:

- behavioral duplication analysis
- choke-point / ownership reasoning
- async handoff analysis
- false-positive restraint

This is materially stronger than plain clone detection and stronger than the earlier docs-only `/review` tests.
