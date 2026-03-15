---
name: duplicate-code-investigator
description: |
  Find duplicate code, duplicate execution paths, and competing implementations before or during refactors, bug investigations, and code reviews. Use when work seems to happen twice, a side effect may be triggered from multiple paths, a stateful call was moved across actor or queue boundaries, a repo may contain legacy and new implementations of the same feature, or a large change needs a duplication-risk sweep. This skill creates a dedicated investigator sub-agent, runs deterministic scans with rg and ast-grep, loads modular references for the active language, and returns evidence-ranked findings with consolidation recommendations.
---

# Duplicate Code Investigator

## Overview

Use this skill to catch two different failure modes:

1. Structural duplication
2. Behavioral duplication

Structural duplication includes copied files, near-identical functions, and competing
feature implementations. Behavioral duplication includes duplicate initialization,
duplicate wiring, duplicate subscriptions, or the same stateful side effect triggered
from multiple paths.

Prioritize behavioral duplication when debugging. A duplicated call path is often more
costly than a copied block of text.

Treat `ast-grep` as the primary syntax-aware search engine in any supported language.
Use `rg` for fast inventory and counts. Add clone detectors later only when classic
copy-paste duplication is the dominant need.

## Trigger Conditions

Use this skill when one or more of these conditions hold:

- A bug looks like work is happening twice.
- A function was moved between actor, queue, lifecycle, or callback contexts.
- A refactor introduces a new early call and may have left the old call in place.
- A feature appears to have both legacy and current implementations alive at once.
- A PR changes coordinator logic, view lifecycle hooks, observers, delegates, or engine wiring.
- A task plan includes consolidation, cleanup, architecture simplification, or race-condition debugging.

## Core Workflow

### 1. Load the shared workflow

Read [`references/investigation-workflow.md`](references/investigation-workflow.md).

Then read:

- [`references/patterns-general.md`](references/patterns-general.md)
- the language-specific pattern reference that matches the repo slice you are analyzing
- any repo-specific or bug-class example only if it matches the current problem

If the language-specific reference does not exist yet, continue with the shared workflow
and add the missing reference later.

### 2. Use the current harness adapter

- Codex: read [`references/harness-codex.md`](references/harness-codex.md)
- Claude: read [`references/harness-claude.md`](references/harness-claude.md)
- Gemini: read [`references/harness-gemini.md`](references/harness-gemini.md)

### 3. Create the investigator

Start a dedicated duplicate-code investigator agent or sub-agent before broad code reading.

That agent owns:

- duplicate-path analysis
- structural duplication checks
- choke-point verification
- evidence collection
- false-positive filtering

If the scope is large, allow the investigator to split the repo into 2 focused scans:

- execution-path duplication
- implementation duplication

### 4. Run deterministic scans first

Use [`scripts/inventory_duplicate_paths.sh`](scripts/inventory_duplicate_paths.sh) when the
user already suspects specific risky symbols. This script is a fast first pass, not the
final judgment. Pass `--lang <language>` when the language is known.

### 5. Return ranked findings

Separate output into:

- Confirmed duplicates
- Likely duplicate-path risks
- Intentional repetition / false positives
- Recommended consolidations or choke points

### 6. Adapt to review mode

If the current task is a code review or `/review` flow:

- keep using the duplicate-investigator workflow internally
- emit native review findings instead of the direct-invocation bucket format
- prioritize bugs, regressions, ownership splits, and missing choke points
- include file references and explain the duplicated behavior or split ownership clearly
- mention the key evidence sources or commands when that improves auditability
- do not modify production code

## Evidence Rules

Do not call something a duplicate unless there is evidence.

For every finding:

- cite file paths and lines
- explain whether the duplication is structural or behavioral
- name the shared side effect or ownership boundary involved
- explain why the repetition is unsafe, redundant, or maintenance-heavy

Do not flag a duplicate on naming similarity alone.

## Invocation Model

Read [`references/invocation-model.md`](references/invocation-model.md) before deciding
whether to run this skill explicitly, during planning, or as part of review.

Default recommendation:

- Run explicitly for bug investigations and consolidation tasks.
- Recommend implicitly during planning or review when trigger conditions are present.

## Output Contract

For direct invocation, return:

1. A short statement of the likely duplicate class.
2. The evidence table or bullet list.
3. The safest single-owner or choke-point recommendation.
4. The next verification step.

For review mode:

1. Return standard review findings ordered by severity.
2. Explain the duplicated execution path, split ownership, or competing implementation.
3. Cite the key file references.
4. Mention the main evidence sources or commands if helpful.
5. Keep summaries brief after findings.
