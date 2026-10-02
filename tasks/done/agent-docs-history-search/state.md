# State: Agent Docs History Search

## Status

- Complete.

## Decisions

- Treat `tasks/done/agents-md-tightening/` and `tasks/stale/duplicate-code-agent-skill/` as primary candidates.
- Treat `_context` and feature-task Gemini mentions as secondary unless they reference instruction files or agent packaging directly.
- Add `tasks/done/xcodegen-infrastructure/` as a secondary but direct reference because it records coordinated updates to `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md`.

## Findings

- `tasks/done/agents-md-tightening/` is the clearest completed task about the AGENTS setup.
- `tasks/stale/duplicate-code-agent-skill/` is the clearest unfinished task about Codex/Claude/Gemini coordination, packaging, and linked supporting docs.
- `tasks/done/xcodegen-infrastructure/` is a direct but narrower reference to the triad of agent docs being updated together.
