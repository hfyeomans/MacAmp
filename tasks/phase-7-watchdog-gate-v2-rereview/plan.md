# Phase 7 Watchdog Gate v2 Re-review Plan

1. Inspect the changed watchdog gate lifecycle and all call sites that mutate `pendingReconfigureSnapshot`.
2. Run duplicate-path checks around observer will/did, cancellation paths, watchdog demotion, and fallback flag clearing.
3. Review Swift concurrency and atomic usage for the render-thread/main-actor flag handoff.
4. Attempt focused test verification with XcodeBuildMCP.
5. Return findings-first review with severity, answers to the seven specific questions, and score.
