# Phase 7 Watchdog Gate v2 Final Pass Plan

1. Inspect changed gate lifecycle and production writers.
2. Check duplicate callback paths around will/did, cancel, and watchdog fallback.
3. Review tap fallback state split and bypass format predicate.
4. Evaluate atomic ordering and non-atomic C-side state assumptions.
5. Attempt focused test verification through XcodeBuildMCP.
6. Return findings-first review with score and minimum delta.
