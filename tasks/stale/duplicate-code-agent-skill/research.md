# Research: Duplicate Code Agent Skill

## Goal

Design a cross-harness skill and specialized sub-agent that helps catch duplicate code and duplicated execution paths early, before they turn into multi-hour debugging sessions.

## Inputs Reviewed

- `tasks/unified-audio-pipeline/state.md`
- `tasks/unified-audio-pipeline/lessons-learned.md`
- `BUILDING_RETRO_MACOS_APPS_SKILL.md`
- `tasks/done/code-duplication-analysis/README.md`
- `tasks/done/code-duplication-analysis/detailed-findings.md`
- `tasks/done/code-duplication-verification/research.md`
- Local tool availability in this environment

## Primary Incident To Learn From

The unified audio pipeline work hit a costly failure mode:

- The ICY framer was configured twice.
- The first call site was correct and early.
- The second call site ran later from a different isolation domain.
- The second call reset byte-counting state mid-stream.
- The observable symptom was stream corruption, not an obvious duplicate-call error.

This is the important lesson: the skill cannot only look for copy-pasted text. It also needs to investigate duplicated behavior, duplicated orchestration, and multiple live call paths that should collapse to one choke point.

## Concrete Lessons Extracted

From `BUILDING_RETRO_MACOS_APPS_SKILL.md`:

- Prevention rule: when moving a function call to fix a race, grep for all call sites and remove the original.
- Debugging method explicitly includes a duplicate-call search after isolating data-path problems.
- Critical invariants should often imply single-call ownership, for example:
  - configure exactly once
  - deactivate only at the choke point
  - rewire through one path

From the earlier code-duplication tasks:

- The repo has already seen classical duplication too:
  - duplicate window implementations
  - duplicate slider implementations
  - orphaned modern and legacy variants
- Prior duplication work used search and cross-reference verification rather than a packaged, reusable investigator workflow.

## What The Skill Must Detect

### 1. Structural Duplication

- near-identical files
- near-identical functions
- duplicate UI components
- copy-pasted logic blocks

### 2. Behavioral Duplication

- the same side effect triggered from multiple paths
- the same initialization/configuration function called from two isolation domains
- duplicate engine-graph rewiring
- double registration, subscription, observer, callback, or delegate hookup

### 3. Architectural Smells That Create Duplication Risk

- two implementations of the same feature alive at once
- missing choke points
- mutation performed outside the intended owner
- duplicated orchestration spread across coordinator, view, and service layers

## Local Tooling Findings

Available:

- `fd`
- `rg`
- `ast-grep`
- `jq`
- `yq`
- `semgrep`
- `gemini`

Not available:

- `jscpd`
- `pmd`

Implication:

- The first version should rely on `rg`, `ast-grep`, and `semgrep`, wrapped by deterministic scripts where useful.
- Swift-specific structural matching should prefer `ast-grep`.
- The skill should not depend on heavyweight third-party clone detectors being installed.

## Tooling Reliability Notes

- `ast-grep` is the strongest dependable local primitive for Swift structural searches.
- `semgrep` is installed, but an explorer pass reported local trust-anchor issues. Treat it as optional until that environment problem is fixed.
- `gemini` is available and already used in this repo through prompt files with `@path` syntax. That makes Gemini a good second-pass analyzer for large file sets after deterministic scans narrow the scope.

## Harness Findings

### Codex

- The Codex skill system supports `agents/openai.yaml` metadata.
- `policy.allow_implicit_invocation: true` is the closest built-in hook for surfacing the skill without perfect user memory.
- The actual sub-agent behavior still belongs in `SKILL.md`, where the skill can instruct Codex to use `spawn_agent`.

### Claude

- Local evidence supports dedicated Claude agent files, skills, slash commands, and hook-capable workflows.
- This makes Claude a strong candidate for both:
  - an explicit duplicate-investigator agent
  - a reminder or auto-trigger path that does not rely entirely on user memory
- The portable part is still the investigator role definition and evidence rules, not the Codex metadata file.

### Gemini

- Local evidence supports Gemini CLI prompt packs and `@path`-scoped large-context analysis.
- Local evidence also suggests Gemini command-wrapper patterns through extension commands.
- Inference: if native sub-agent support is unavailable or weaker in the active Gemini harness, emulate the specialized agent by running a dedicated Gemini investigator pass or command wrapper after local scans.

## Recommended Packaging Direction

Use one portable skill concept with two layers:

1. Shared core:
   - trigger conditions
   - duplicate-investigation workflow
   - evidence rules
   - invocation model
2. Harness adapters:
   - Codex adapter
   - Claude adapter
   - Gemini adapter

This keeps the logic portable while accepting that sub-agent invocation is harness-specific.

## Current Recommendation

- Codex: skill plus spawned explorer agent
- Claude: skill plus dedicated agent, with hooks as the best available memory aid
- Gemini: agent skill plus extension-level command, hook, or sub-agent when needed

## External Landscape Research

### Codex

External docs confirm the local direction:

- OpenAI positions skills as reusable bundles of instructions, resources, and scripts.
- Skills can be used explicitly or automatically based on the task.
- Codex now treats skills as portable across the app, CLI, and IDE extension.
- OpenAI’s public skills catalog explicitly frames the model as "write once, use everywhere."

Implication:

- A duplicate-code skill is a good product fit for Codex.
- The right Codex packaging remains:
  - one portable skill
  - metadata for discovery
  - sub-agent spawning in the skill workflow itself

### Claude Code

Anthropic’s current docs go further than our local assumptions:

- Claude Code supports custom subagents with separate context windows, custom prompts, tool restrictions, and independent permissions.
- Subagents can preload skills.
- Subagents can be isolated in a temporary git worktree.
- Claude Code also supports hooks that run deterministically at lifecycle events instead of relying on the model to remember a policy.

Implication:

- Claude is a strong target for a dedicated duplicate-investigator subagent.
- Claude hooks are the best documented path for "don’t rely on memory."
- A hook could remind or enforce duplicate-investigator usage for prompts or tool events matching race-condition / duplicate-work risk.

### Gemini CLI

Current Gemini docs are stronger than the older repo-local evidence:

- Gemini CLI has first-class Agent Skills based on the same open standard.
- Gemini autonomously activates skills with `activate_skill`.
- Gemini extensions can package custom commands, hooks, sub-agents, and agent skills together.

Implication:

- Gemini can support more than a prompt pack.
- There are 2 reasonable Gemini packaging levels:
  - lightweight: project skill plus custom command
  - full: extension containing skill, command, and optional hook/sub-agent

## Duplicate Detection Tooling Landscape

### Structural clone detectors

Two mature options stood out:

- PMD CPD: copy/paste detector with Swift support
- jscpd: token-based duplicate detector with very broad language support

These are useful for:

- copied files
- near-identical functions
- repeated component implementations

These are weak for:

- duplicate execution paths
- semantically equivalent but differently written logic
- duplicate wiring spread across callbacks, actors, or coordinators

### Structural rule engines

- `ast-grep` is a strong fit for repo-local, language-aware structural checks.
- It supports atomic, relational, and composite rules, which is exactly what we need to express "same call inside different contexts" and "this side effect should only occur under one owner."
- `semgrep` is also expressive for pattern-based search and custom rules, but in this environment it remains operationally secondary until the local certificate issue is resolved.

### Research literature

The broader clone-detection literature distinguishes:

- Type-1: exact clones
- Type-2: renamed / lightly edited clones
- Type-3: near-miss clones with added or removed statements
- Type-4: semantic clones with the same behavior but different syntax

Implication:

- No single off-the-shelf duplicate detector will reliably catch the bug class we care about.
- Our `configureFramer()` incident is closer to behavioral duplication and Type-4 risk than classic copy/paste duplication.
- The skill should therefore use layered evidence:
  - clone detector or token scanner for structural duplication
  - AST rules for structural/architectural patterns
  - dedicated agent reasoning for behavioral duplication

## Updated Overall Conclusion

The external research strengthens the original plan rather than replacing it.

Best current architecture:

1. Portable core skill using the open skills model
2. Dedicated duplicate-investigator agent or sub-agent
3. Deterministic first-pass scans
4. Harness-specific automation surface:
   - Codex: implicit invocation and, later, automations
   - Claude: hooks plus subagents
   - Gemini: extensions with agent skills, commands, hooks, and optional sub-agents

## Working Hypothesis

This should be a specialized investigator agent, not just a static checklist skill.

The skill should:

1. Spawn a sub-agent specialized in duplicate detection.
2. Give that agent a layered workflow:
   - inventory likely duplicate surfaces
   - search for structurally similar code
   - search for repeated call sites of stateful functions
   - identify missing choke points / single-owner violations
   - produce ranked findings with evidence
3. Return both:
   - concrete duplicates
   - changes to architecture or process that would have prevented them

## Open Questions

1. How should the skill bind to a specialized agent in Codex, Claude, and Gemini without depending on one harness only?
2. Should the agent run only on explicit invocation, or also via planning hooks / retros / PR-review sweeps?
3. Should the first deliverable be:
   - a portable research/spec skill
   - an executable skill with scripts
   - or both?
4. What minimum evidence threshold should the agent require before labeling something a true duplicate?
