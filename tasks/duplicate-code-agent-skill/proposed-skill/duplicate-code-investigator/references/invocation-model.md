# Invocation Model

## Goal

Make the skill easy to remember without forcing it on every task.

## Recommended Defaults

### Explicit Invocation

Use the skill directly when:

- debugging "work happens twice" bugs
- moving stateful calls across queues, actors, callbacks, or lifecycle hooks
- consolidating old and new implementations
- reviewing coordinator or orchestration changes

### Implicit Recommendation

Recommend the skill during planning or review when the task includes:

- race-condition fixes
- duplicate subscriptions or callbacks
- engine graph rewiring
- observer or delegate registration
- multiple code paths that can start, stop, or reconfigure the same subsystem

### Review Mode

When running inside a review flow:

- keep the duplicate-investigator workflow
- prefer review findings over advisory prose
- focus on duplicated execution paths, split ownership, teardown/setup symmetry, and missing choke points
- treat idempotent repetition as a potential false positive unless the same user-visible event can trigger it twice
- mention `rg` / `ast-grep` or equivalent evidence when that makes the finding easier to trust

### Hook Points

This skill is a good fit for:

- planning checklists
- PR review workflows
- retrospective lessons-learned updates

It is not a good fit for:

- trivial one-file edits
- purely cosmetic changes
- tasks with no stateful orchestration

## Codex-Specific Note

If packaging this skill for Codex, prefer `policy.allow_implicit_invocation: true` with a
description that names the trigger conditions clearly. That gives the harness a chance to
surface the skill without requiring perfect user memory.

## Project-Level Reminder Option

To make usage more reliable across harnesses, add a short trigger rule to shared repo guidance:

- before deep debugging of timing, race, or duplicate-work bugs, run the duplicate investigator
- before merging large orchestration refactors, run the duplicate investigator
- during `/review` of orchestration, callback, teardown, or ownership changes, use the duplicate-investigator workflow even if the output format stays in native review form
