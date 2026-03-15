# Codex Adapter

## Purpose

Use Codex sub-agents to turn this skill into an active investigation workflow.

## Recommended Pattern

1. Create one dedicated explorer agent for duplicate-code investigation.
2. Keep the main agent focused on integration, task state, and final judgment.
3. Create a second explorer only if the scope is large enough to justify a split.

Suggested split:

- Agent 1: behavioral duplication and call-path analysis
- Agent 2: structural duplication and competing implementations

## Codex-Specific Mechanism

Use `spawn_agent` with `agent_type: "explorer"` for investigation passes.

Give the agent:

- repo path or narrowed directories
- the suspected symbols or subsystems
- the question: "where can the same side effect happen twice?"
- the evidence standard from the shared workflow

## Minimal Prompt Shape

Use a prompt like:

```text
Act as a duplicate-code investigator. Focus on duplicated execution paths first, then
structural duplication. Search these paths: <paths>. Investigate these risky symbols:
<symbols>. Return confirmed duplicates, likely risks, false positives, and the safest
single-owner or choke-point recommendation with file references.
```

## Packaging Note

For Codex UI integration, `agents/openai.yaml` can:

- set a user-facing skill name
- provide a default prompt
- allow implicit invocation when trigger phrases match

The actual sub-agent creation still belongs in the skill instructions, not the YAML.
