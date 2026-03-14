# Plan

1. Inspect each modified file for actor isolation, deinit semantics, and `@concurrent` usage.
2. Trace call sites to confirm no accidental `self` capture or MainActor state access in `@concurrent` functions.
3. Verify Sendable constraints of all values crossing `@concurrent` boundaries.
4. Scan repository for remaining `Task.detached` calls.
5. Run a build to validate Swift 6.2 strict-concurrency compilation.
6. Produce review findings ordered by severity with line references.
