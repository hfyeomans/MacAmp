# Phase 7 Watchdog Gate V2 Score Confirm Plan

1. Inspect commit `9825b4f` and the touched files.
2. Verify each prior finding:
   - Late gated fallback flag leakage.
   - Converter bypass predicate looseness.
   - Sticky `requiresConverter` on tap re-prepare.
3. Run a duplicate-path sweep around watchdog fallback ownership and tap classification ownership.
4. Run XcodeBuildMCP tests, including a TSan pass.
5. Return review-style findings first if any blocker remains; otherwise provide score confirmation.
