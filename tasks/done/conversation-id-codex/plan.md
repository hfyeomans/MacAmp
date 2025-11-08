# Plan

## Goal
Explain why `codex-reply` fails with a conversation ID parsing error in MCP workflows and outline viable paths forward.

## Steps
1. Summarize Codex CLI MCP capabilities from local documentation (`README`, CLI help) and record any mention—or lack—of conversation persistence.
2. Inspect Codex MCP runtime artifacts (binary strings, local session store) to confirm the UUID requirement and whether IDs are exported through MCP responses.
3. Describe why `$PREVIOUS_CONVERSATION_ID` stays unset in the current workflow and recommend options (single-shot use, alternative Codex surfaces, or upstream change requests) for multi-turn collaboration.

## Acceptance Criteria
- Root cause of the parsing error is articulated with references to observed evidence.
- Guidance is provided for other agents on how to interact with Codex MCP without hitting the invalid conversation ID issue.
- Any uncertainties or follow-up questions for maintainers are captured.

