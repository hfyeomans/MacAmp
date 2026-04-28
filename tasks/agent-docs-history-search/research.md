# Research: Agent Docs History Search

## Scope

- Search `tasks/` for task artifacts that reference agent-instruction or multi-agent workflow work.
- Focus on material references to `AGENTS.md`, `CLAUDE`, and `GEMINI`.
- Exclude routine feature-task mentions where Gemini was only used as a research assistant unless they clearly connect to agent workflow or instruction-file setup.

## Initial Findings

- Broad text search across `tasks/` returns many incidental `Gemini` mentions from feature research.
- Strong candidate task folders for the user's question:
  - `tasks/done/agents-md-tightening/`
  - `tasks/stale/duplicate-code-agent-skill/`
- Additional directly relevant task:
  - `tasks/done/xcodegen-infrastructure/`
- Possible contextual references also exist in `tasks/_context/`, but those appear to be coordination notes about running Claude instances rather than dotfiles or linked instruction files.

## Narrowed Relevant Tasks

### Primary

- `tasks/done/agents-md-tightening/`
  - Directly about consolidating and syncing project and user-level `AGENTS.md`.
  - Captures the user-level `/Users/hank/.codex/AGENTS.md` promotion, backup, and later tightening pass.
- `tasks/stale/duplicate-code-agent-skill/`
  - Directly about cross-harness agent packaging and invocation across Codex, Claude, and Gemini.
  - Includes explicit references to `~/.claude/CLAUDE.md`, `GEMINI.md`, linked reference docs, harness adapters, and a recommendation to keep main agent docs concise and link out to longer task/reference files.

### Secondary

- `tasks/done/xcodegen-infrastructure/`
  - Not an agent-doc task by itself, but it explicitly records that `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` were updated together for the `xcodegen generate` workflow.

### Contextual Only

- `tasks/_context/`
  - Contains coordination notes about Claude instances and Gemini research, but not the clearest evidence of the distributed agent-doc setup itself.
