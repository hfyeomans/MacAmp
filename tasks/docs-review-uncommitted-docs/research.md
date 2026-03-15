# Research

- Scope: review uncommitted documentation-oriented changes plus one stale code comment update.
- Primary checks requested:
  - Accuracy of counts, listings, and line totals against the current repository state
  - Correctness of superseded-pattern notes (`dual-backend`, `nonisolated(unsafe)`, `Task.detached`)
  - Remaining stale references
  - Accuracy of the new Swift 6.2 architecture guidance
  - Version consistency across docs
- Evidence sources:
  - `git diff`
  - `git diff --stat`
  - Repository searches (`fd`, `rg`, `sg`)
  - Relevant Swift concurrency guidance from `swift-concurrency-pro`
