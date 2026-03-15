# Codex Invocation Guidance For Other Agents

## Purpose

This file is for later updates to agent instruction files such as:

- `~/.claude/CLAUDE.md`
- repo-level `CLAUDE.md`
- `GEMINI.md`
- other agent-system docs that tell a non-Codex agent when and how to consult Codex

Do not edit those files from this task yet. Use this as the source material for later additions.

## Style Source

The current Oracle style source is:

- `/Users/hank/.claude/CLAUDE.md`

That file currently establishes:

- Codex Oracle via `mcp__codex-cli__codex`
- `gpt-5.3-codex`
- `reasoningEffort: xhigh`
- `@` file inclusion syntax
- Oracle as a validation and review tool

This guide extends that pattern rather than replacing it.

## Current Reality

There are three materially different ways to use Codex:

1. Codex MCP one-shot consultation
2. native CLI interactive `codex`
3. native CLI batch `codex exec`

`codex review` is useful too, but in the current local CLI it has an important parser limitation.

## Decision Table

### Use Codex MCP (`mcp__codex-cli__codex`) when:

- another agent wants a one-shot validation pass
- the prompt is self-contained
- the exchange does not depend on multi-turn reply continuity
- the question is review, planning, or implementation validation

Best fit:

- “review these files”
- “validate this plan”
- “look for bugs in this diff summary”
- “check whether this architecture has obvious issues”

### Use interactive `codex --no-alt-screen` when:

- a human or agent wants exploratory back-and-forth
- preserving terminal scrollback matters
- the task needs custom instructions and live iteration
- you want a direct skill invocation rather than plain patch review

Best fit:

- duplicate-investigator sessions
- architecture diagnosis
- guided deep review with clarifying follow-ups

### Use `codex exec` when:

- the prompt is large or carefully specified
- you want deterministic, non-interactive output
- you want full output captured to a file
- you need historical review in a temp worktree
- you need `--add-dir` to expose newer docs or adjacent repos

Best fit:

- scripted review workflows
- durable logs for later comparison
- PR archaeology
- agent-driven review jobs

### Use `codex review` when:

- you want native diff review behavior
- you do not need a custom prompt
- the review base or commit is straightforward

Best fit:

- plain patch review against `origin/main`
- uncommitted review flows

## Current Constraints

### 1. Codex MCP is effectively single-shot

Prior local research found:

- Codex MCP does not surface a reusable `conversation_id`
- downstream `codex-reply` style follow-ups fail without that ID
- practical implication: treat MCP consultations as one-shot requests

Reference:

- [research.md](/Users/hank/dev/src/MacAmp/tasks/done/conversation-id-codex/research.md)

### 2. `codex review` parser mismatch

In the current local CLI:

- `codex review --base <rev> "<prompt>"`
- `codex review --commit <sha> "<prompt>"`

both fail even though help text implies the prompt should be accepted.

Practical implication:

- if you need custom review instructions, prefer `codex exec` or interactive `codex`

### 3. Historical reviews need a worktree

If the target branch no longer exists or the exact review target is a historical merge commit:

- create a temp worktree at that commit
- run `codex exec` or interactive `codex` there
- use `--add-dir` if the review also needs newer task docs from the current checkout

## Recommended Wording For Agent Docs

### Minimal Oracle rule

Use wording like:

> Use Codex Oracle (`mcp__codex-cli__codex`, `gpt-5.3-codex`, `xhigh`) for one-shot code review, plan validation, and implementation verification. Use native CLI `codex` or `codex exec` when the review needs custom prompts, historical snapshots, or durable output capture.

### Duplicate-investigator escalation rule

Use wording like:

> When the task smells like duplicated behavior, split ownership, duplicate initialization/teardown, or stale async handoff, consult Codex with the `duplicate-code-investigator` workflow rather than a generic review prompt.

### MCP limitation rule

Use wording like:

> Treat Codex MCP consultations as single-shot. Do not rely on `conversation_id` or `codex-reply` follow-ups unless upstream behavior changes and is revalidated.

## Copy-Ready Prompt Patterns

### 1. MCP one-shot validation

Use when another agent wants a normal Oracle review:

```text
Review these files and validate correctness, ownership, lifecycle cleanup, Swift concurrency safety, and regression risk.

Context:
- @File1.swift
- @File2.swift
- @tasks/<task-id>/plan.md

Return:
1. findings ordered by severity
2. open assumptions
3. brief validation summary
```

### 2. Duplicate-investigator MCP prompt

Use when another agent suspects duplicate work or split ownership:

```text
Use the duplicate-code-investigator approach for this review.

Focus on:
- duplicate execution paths
- split ownership
- missing choke points
- duplicate setup/teardown
- stale async callbacks after handoff

Context:
- @File1.swift
- @File2.swift
- @tasks/<task-id>/research.md
- @tasks/<task-id>/state.md

Return findings first with file references. Distinguish confirmed duplicate-path issues from likely risks and false positives.
```

### 3. CLI interactive prompt

Use when a human or agent wants a deeper session:

```bash
codex --no-alt-screen "Use \$duplicate-code-investigator to analyze @MacAmpApp/Audio/ for duplicate execution paths, split ownership, missing choke points, and stale async handoff paths. Findings first. Do not modify code."
```

### 4. CLI batch prompt with durable output

Use when the caller wants a saved artifact:

```bash
codex exec "Use \$duplicate-code-investigator to review the changes from <base> to HEAD. Focus on duplicate execution paths, split ownership, missing choke points, stale async callbacks after handoff, and setup/teardown symmetry. Findings first. Do not modify code." | tee /tmp/codex-review.txt
```

### 5. Historical review prompt

Use when the review target is a merged or deleted branch:

```bash
git worktree add /tmp/<name> <sha>
cd /tmp/<name>
codex exec \
  --add-dir /path/to/current/repo \
  "Use \$duplicate-code-investigator to review the changes from <base> to HEAD. Compare against:
- /path/to/current/repo/tasks/<task-id>/research.md
- /path/to/current/repo/tasks/<task-id>/state.md
- /path/to/current/repo/tasks/<task-id>/plan.md

Findings first. Do not modify code." \
  | tee /tmp/codex-historical-review.txt
```

## Anti-Patterns

Do not recommend these patterns in agent docs:

- use MCP and then expect a reusable `conversation_id`
- use `codex review --base ... "<prompt>"` in the current CLI
- ask Codex to review a doc-only diff when the real target is an earlier code patch
- call the duplicate-investigator for trivial cosmetic edits
- frame the duplicate-investigator as only a text-duplication tool

## Proposed Later Additions

When we do edit agent docs later, add guidance in this order:

1. minimal Oracle/Codex routing rule
2. duplicate-investigator escalation rule
3. MCP single-shot caveat
4. one or two copy-ready examples

Keep agent docs concise. Put the longer examples in a linked task or reference file instead of bloating the main instruction file.
