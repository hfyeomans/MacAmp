# Session storage research

## Approach
- Scan the repository for `sessionId` usage to pinpoint where session data is persisted
- Review existing documentation under `tasks/**` that might already describe how sessions are stored

## Findings
- No source files reference `sessionId`, but the Codex MCP investigation (`tasks/conversation-id-codex/research.md`) documents how the CLI itself persists sessions
- Codex writes each interactive session to `~/.codex/sessions/<uuid>.jsonl`; each line is a JSON object containing the prompts/responses for the `sessionId`

## Evidence
- `tasks/conversation-id-codex/research.md` explicitly states “Codex keeps its own session history in `~/.codex/sessions/*.jsonl` with UUIDs …”
