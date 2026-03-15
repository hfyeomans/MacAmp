# Gemini Adapter

## Purpose

Adapt the workflow for Gemini CLI or Gemini-based repo analysis.

## Local Evidence

The repo already uses Gemini CLI prompt files with `@path` inclusion syntax for large-context
analysis. That is enough to support a duplicate-investigator pass even without proving an
identical sub-agent mechanism locally.

This adapter therefore contains an explicit inference:

- Inference: if Gemini does not expose the same sub-agent primitive as Codex or Claude in the
  active harness, emulate the specialized agent by running a dedicated Gemini investigation pass
  with a reusable prompt and a narrowed set of paths.

## Recommended Pattern

1. Run the deterministic local scan first.
2. Feed Gemini the narrowed file set with `@path` syntax.
3. Ask Gemini to behave as a duplicate-code investigator for that one pass.
4. Use Gemini for large-scope reasoning, not as the first detector.

## Prompt Requirements

Ask Gemini to:

- prioritize duplicate execution paths
- explain whether multiple call sites share the same side effect
- identify competing implementations
- propose one choke point or owner
- label uncertainty explicitly

## Good Fit

Use Gemini when:

- the suspected duplication spans many files
- ownership is unclear
- you want a second-pass synthesis after `rg` and `ast-grep`

Avoid using Gemini as the only detector for this problem class.
