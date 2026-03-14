# Placeholder: Swift 6.2 Concurrency Cleanup

> **Purpose:** Track any stubs, placeholders, or incomplete implementations introduced during this task.
> Items here must be resolved before the task is marked complete.
>
> **Created:** 2026-03-13

---

## Active Placeholders

| File:Line | Purpose | Status | Action |
|-----------|---------|--------|--------|
| `AudioPlayer.swift:185` | `MainActor.assumeIsolated` bridge in nonisolated deinit — calls `removeTap()` which is now @MainActor-isolated. Uses `Thread.isMainThread` guard. Oracle flagged as "brittle — relies on thread check, not formal executor provenance." | Temporary (PR 1) | Replace with `isolated deinit` in PR 2 (Step 7), after pipeline adds streamSourceNode/bridge state. Final deinit: `progressTimer?.invalidate(); deactivateStreamBridge(); visualizerPipeline.removeTap()` |
