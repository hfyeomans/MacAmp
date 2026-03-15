# Duplicate Code Investigator v1

## Status

Frozen as the first Codex-ready version of the skill.

This is the first version that has:

- an installed Codex skill
- modular references
- a deterministic inventory script
- review-mode behavior
- validation against both current and historical MacAmp audio-pipeline cases

## Canonical Artifacts

- Installed skill:
  `/Users/hank/.codex/skills/public/duplicate-code-investigator/`
- Task snapshot:
  [SKILL.md](/Users/hank/dev/src/MacAmp/.claude/worktrees/duplicate-code-agent-skill/tasks/duplicate-code-agent-skill/proposed-skill/duplicate-code-investigator/SKILL.md)
- Zip artifact:
  [duplicate-code-investigator.zip](/Users/hank/dev/src/MacAmp/.claude/worktrees/duplicate-code-agent-skill/tasks/duplicate-code-agent-skill/dist/duplicate-code-investigator.zip)

## What v1 Is

`duplicate-code-investigator` is a duplicate-execution and split-ownership investigator.

It is designed to catch:

- structural duplication
- duplicate execution paths
- competing implementations
- duplicate initialization and teardown
- stale async handoff paths
- missing choke points or single-owner boundaries

It is not just a copy-paste detector.

## What v1 Is Not

v1 should not be described as:

- a generic clone scanner
- a semantic diff engine
- a general code review replacement
- an always-on hook that runs for every trivial change

The right framing is:

> Use this when work may be happening twice, ownership may be split, or refactors may have left multiple live paths behind.

## Default Search Stack

v1 uses a layered stack:

1. `rg` for fast inventory and call-site counting
2. `ast-grep` as the primary syntax-aware matcher across languages
3. `scripts/inventory_duplicate_paths.sh` for quick symbol-led sweeps
4. investigator reasoning for classification, ownership, and false-positive filtering

Optional later additions:

- `jscpd` or `CPD` for classic token-based clone sweeps
- `semgrep` after local trust-anchor issues are resolved

## When To Use v1

Run it when one or more of these are true:

- a bug looks like work is happening twice
- a function moved between actor, queue, lifecycle, or callback contexts
- a refactor added a new call path and may have left the old path live
- a feature may have both legacy and current implementations alive
- review scope includes coordinator logic, observers, callbacks, setup/teardown, or engine wiring
- the task is architecture cleanup, consolidation, or duplicate-risk analysis

Do not make this the default for cosmetic or obviously local edits.

## Human Usage

### 1. Explicit interactive investigation

Use a fresh Codex session when you want direct analysis instead of patch review:

```text
Use $duplicate-code-investigator to scan this area for duplicate execution paths, split ownership, duplicate initialization/teardown, and competing implementations.

Focus on:
- <symbol or subsystem list>

Do not stop at text duplication. Prioritize behavioral duplication, missing choke points, and stale async handoff paths.

Return:
1. confirmed duplicates
2. likely duplicate-path risks
3. intentional repetition / false positives
4. the safest single-owner or choke-point recommendation for each real issue
```

### 2. `/review` mode

Use a fresh Codex session when you want native review comments but duplicate-investigator reasoning underneath:

```text
/review Focus on duplicate execution paths, split ownership, missing choke points, stale async callbacks after handoff, and setup/teardown symmetry. Use the duplicate-code-investigator workflow internally, but return normal review findings. Mention key evidence sources or commands if helpful.
```

### 3. Historical PR or commit review

When the branch is gone or the review target is a historical merge commit:

```bash
git worktree add /tmp/macamp-pr57-review cf71762
cd /tmp/macamp-pr57-review

codex exec \
  --add-dir /Users/hank/dev/src/MacAmp \
  "Use \$duplicate-code-investigator to review the changes from aad01ea3f02528c3522a669cf60dec2d14f6a42a to HEAD.

Focus on:
- duplicate execution paths
- split ownership
- missing choke points
- stale async callbacks after handoff
- setup/teardown symmetry

Use the duplicate-investigator workflow internally, but return normal review findings.

Compare against:
- /Users/hank/dev/src/MacAmp/tasks/audio-pipeline-duplicate-investigation/research.md
- /Users/hank/dev/src/MacAmp/tasks/audio-pipeline-duplicate-investigation/state.md
- /Users/hank/dev/src/MacAmp/tasks/audio-pipeline-duplicate-investigation/plan.md
- tasks/unified-audio-pipeline/lessons-learned.md

Findings first. Use rg and ast-grep style evidence where helpful. Do not modify code." \
  | tee /tmp/codex-exec-pr57-review-2.txt
```

## Expected Output

### Direct invocation

Expected structure:

1. Confirmed duplicates
2. Likely duplicate-path risks
3. Intentional repetition / false positives
4. Recommended choke points or single owners

### Review mode

Expected structure:

- standard review findings ordered by severity
- concrete file refs
- clear explanation of the duplicated behavior, split ownership, or stale handoff
- brief note about the evidence source when helpful

## Validation Evidence

### Validation 1: current audio-pipeline investigation

The skill found a real behavioral-duplication bug cluster in the add-files flow:

- direct `audioPlayer.addTrack(url:)` paths
- `AudioPlayer` auto-play behavior
- coordinator-initiated playback of the same first track

This was correctly framed as a duplicate-start / split-ownership problem, not a text-clone issue.

Primary task artifacts:

- [research.md](/Users/hank/dev/src/MacAmp/tasks/audio-pipeline-duplicate-investigation/research.md)
- [state.md](/Users/hank/dev/src/MacAmp/tasks/audio-pipeline-duplicate-investigation/state.md)

### Validation 2: fresh-session `/review`

Codex loaded the skill, modular references, and helper resources during `/review`, then returned review findings about bridge teardown ownership and stale handoff risk. This proved the skill could influence `/review` behavior in a fresh session.

### Validation 3: historical PR57 review

The strongest validation came from the historical PR57 run:

- target: merge commit `cf71762`
- method: temp worktree + `codex exec` + `--add-dir`
- result: ranked findings around stale terminal ownership, bridge activation bypassing engine-start guards, and stale async playlist handoff

Recorded result:

- [codex-pr57-review-result.md](/Users/hank/dev/src/MacAmp/.claude/worktrees/duplicate-code-agent-skill/tasks/duplicate-code-agent-skill/codex-pr57-review-result.md)

This run also showed healthy restraint:

- no duplicate `configureFramer` regression claimed in that range
- no confirmed same-event double-teardown bug claimed

## Known Limitations

- `codex review --base <rev> "<prompt>"` and `codex review --commit <sha> "<prompt>"` are broken in the current local CLI despite the help text implying they should work.
- Codex MCP appears to be single-shot for practical purposes because `conversation_id` is not surfaced for follow-up reuse.
- `/review` can be influenced by AGENTS and the installed skill, but it still prefers native review output over the skill’s direct-invocation bucket format.
- v1 is strongest on ownership, lifecycle, and orchestration duplication. It does not yet include a generalized CI-grade clone scan.

## Freeze Decision

Treat the current installed Codex skill and the task snapshot as `v1`.

From this point:

- behavior changes should be tracked as `v1.1+`
- new harness packaging should build on the same core contract
- future work should preserve the core framing:
  duplicate execution and split ownership first, clone detection second
