# Design: Duplicate Code Investigator

## Recommendation

Create one portable skill concept named `duplicate-code-investigator`.

That skill should always create or emulate a dedicated investigator agent before broad code reading. The investigator's job is not generic code review. Its job is to answer one narrow question:

> Where can the same side effect, responsibility, or feature implementation happen twice?

## What This Skill Must Catch

### Structural duplication

- copied or near-copied functions
- competing feature implementations
- legacy and current components both alive

### Behavioral duplication

- duplicate initialization
- duplicate lifecycle wiring
- duplicate observer or delegate registration
- the same stateful method called from multiple actor, queue, or callback contexts
- coordinator bypasses that recreate the same side effect elsewhere

Behavioral duplication is the higher-value target. That is the bug class that cost hours in the unified audio pipeline.

## Agent Model

### Core role

Use one specialized investigator agent or sub-agent with this contract:

- prioritize duplicated side effects over copied text
- inventory suspicious symbols and orchestration paths
- search structurally first, reason second
- separate confirmed duplicates from likely risks and false positives
- recommend the safest single owner or choke point

### Scaling rule

If the scope is large, split into 2 investigator passes:

1. execution-path duplication
2. implementation duplication

Do not split further unless the repo slice is truly large. Too many agents will dilute the judgment.

## Cross-Harness Shape

### Shared core

Keep these portable:

- trigger conditions
- investigation workflow
- evidence rules
- output contract
- invocation model

### Codex

- Package the skill with `agents/openai.yaml`.
- Set `policy.allow_implicit_invocation: true`.
- In `SKILL.md`, instruct Codex to create an explorer sub-agent for the investigation.
- Consider Codex Automations later for periodic duplicate-risk sweeps after the core skill proves useful.

### Claude

- Reuse the same investigator role and workflow.
- Bind it through Claude's specialized-agent or sub-agent mechanism rather than Codex YAML.
- This is the strongest local candidate for a "don't rely on memory" hook path.
- Claude’s documented `isolation: worktree` option is a strong fit for high-risk duplicate investigations that may involve edits.

### Gemini

- Use deterministic local scans first.
- Then run a dedicated Gemini pass over narrowed `@path` inputs.
- Gemini now has first-class Agent Skills and extension packaging for commands, hooks, sub-agents, and skills.
- Recommended Gemini path:
  - start with a project skill plus custom command
  - promote to a full extension if we want hooks or a reusable distributed package

## Invocation Strategy

Use 3 layers, in this order:

### 1. Explicit use

Run the skill directly for:

- "work happens twice" bugs
- race fixes involving moved calls
- consolidation tasks
- architecture cleanup

### 2. Planning recommendation

Surface the skill during planning when the task mentions:

- queue or actor moves
- observers or callbacks
- delegates
- coordinator rewiring
- multiple implementations

### 3. Review hook

Recommend it during review for PRs touching orchestration, lifecycle hooks, or stateful setup and teardown.

Do not run it by default for small cosmetic work.

## Detection Stack

### Deterministic first pass

- `rg` for repo-wide inventory
- `ast-grep` for Swift structural matches
- helper script for quick symbol-driven scans

### Large-context second pass

- Codex explorer agent or Gemini pass for synthesis

### Optional future pass

- `semgrep` once the local certificate issue is resolved
- classic clone detectors only if copied-text duplication becomes the dominant need
- CPD or jscpd if we want broad structural clone scanning in CI

## Why A Single Tool Is Not Enough

Clone-detection tools are good at classic copy/paste and near-miss clones. They are not sufficient for duplicated execution paths, duplicated initialization, or semantically equivalent orchestration bugs.

That means the agent should combine:

- classic duplicate scanning
- AST-based structural rules
- investigator reasoning over side effects and ownership boundaries

## Evidence Threshold

A finding should only be labeled `CONFIRMED` when it has:

- multiple concrete call sites or implementations
- a clear shared side effect or overlapping responsibility
- a defensible explanation for why the duplication is unsafe or redundant

Otherwise label it `LIKELY` or `LOW`.

## Worktree Recommendation

Yes, this effort fits a dedicated worktree well.

Recommended usage:

- keep the prototype and design work on `feature/duplicate-code-agent-skill`
- open another session against this worktree if you want uninterrupted skill work
- keep unrelated implementation work on separate branches and worktrees

Important constraint:

- avoid editing the same files from two sessions at once, even across different worktrees, unless you are deliberately coordinating a merge
