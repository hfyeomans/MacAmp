# Codex MCP conversation ID research

## Prompt
- Investigate why `codex-reply` fails with `Failed to parse conversation_id` when another agent tries to respond to Codex MCP output.

## Findings
- The local Codex CLI documentation (`~/.nvm/versions/node/v23.11.0/lib/node_modules/@openai/codex/README.md`) confirms the `codex mcp` and `codex mcp-server` entry points but does not document multi-turn conversation support or conversation identifiers.
- Running `codex --help` / `codex mcp --help` shows no options for enabling conversation persistence, implying conversations may be session-scoped only.
- Inspecting the packaged Codex binary strings (`strings …/vendor/aarch64-apple-darwin/codex/codex`) exposes internal errors such as `Missing arguments for codex-reply tool-call; the conversation_id and prompt fields are required` and `Failed to parse conversation_id`, confirming `codex-reply` demands a UUID formatted as `urn:uuid:…`.
- The MCP error we observed arises because the placeholder `$PREVIOUS_CONVERSATION_ID` is left untouched—Codex did not return a `conversation_id` field in its MCP `response.create` payload, so the downstream agent lacks a UUID to pass back.
- MCP spec allows servers to omit `conversation_id` when they do not support follow-up responses; under that condition the client must treat the exchange as single-shot. Codex appears to behave this way in MCP mode, so attempts to reuse `$PREVIOUS_CONVERSATION_ID` will always fail.
- Codex keeps its own session history in `~/.codex/sessions/*.jsonl` with UUIDs (e.g., `c4532b10-7528-4b05-9c51-23da81b6357a`), but those IDs are not surfaced through the MCP transport for external reuse.

## Open Questions
- Is there an undocumented configuration flag to force Codex MCP to advertise `conversation_id`? No evidence yet—needs confirmation from upstream docs/maintainers.
- If multi-turn replies are required, should the workflow switch to `codex exec --json` (which may emit conversation IDs) instead of the MCP bridge?

