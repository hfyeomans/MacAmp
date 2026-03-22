# Plan: Duplicate Code Agent Skill

## Objective

Produce a reusable, cross-harness design for a duplicate-code skill rooted in a specialized investigator agent, with enough specificity to implement it for Codex first and adapt it for Claude and Gemini.

## Deliverables

1. Task research documenting the failure mode and requirements.
2. Cross-harness skill and agent design.
3. Recommended invocation model:
   - explicit skill call
   - planning-stage reminder/check
   - optional PR/review hook
4. Initial skill package scaffold and references for Codex-first implementation.
5. Worktree guidance for running this effort in parallel sessions.

## Design Principles

1. Optimize for finding duplicated behavior, not just copied text.
2. Prefer deterministic scripts for repeated searches.
3. Keep the skill portable by separating:
   - shared investigation workflow
   - harness-specific agent invocation instructions
4. Require evidence, not vibes. Every finding should cite call sites, owners, or repeated structures.

## Planned Work

### Phase 1: Research and Constraints

- Capture the audio-pipeline incident and prior duplication analyses.
- Inventory available local tools and existing skill conventions.
- Identify harness-specific agent binding options for Codex, Claude, and Gemini.

### Phase 2: Skill/Agent Architecture

- Define the specialized agent contract.
- Define what inputs the agent expects.
- Define the layered duplicate-detection workflow.
- Define output format and confidence rules.

### Phase 3: Invocation Model

- Decide how the skill should be used explicitly.
- Decide how to inject it into planning / review flows without relying on memory.
- Decide what lightweight trigger heuristics should recommend running it.

### Phase 4: Initial Packaging

- Create a Codex-first skill skeleton.
- Add shared references for the investigation workflow.
- Add harness notes for Claude and Gemini adaptation.

## Initial Recommendation Direction

Use a portable core design:

- shared skill concept: `duplicate-code-investigator`
- shared investigation workflow and evidence rules
- harness-specific adapters:
  - Codex: skill plus spawned explorer/worker agent
  - Claude: skill plus specialized agent / sub-agent instructions
  - Gemini: prompt pack or command wrapper that delegates large-scope scans

## Risks

- Overfitting to text duplication and missing behavioral duplication.
- Making the skill too heavyweight to run routinely.
- Tying the design too tightly to one harness.
- Producing noisy false positives that teams will learn to ignore.
