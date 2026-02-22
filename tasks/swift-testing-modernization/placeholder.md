# Placeholders: Swift Testing Modernization

> **Purpose:** Document any intentional placeholder or scaffolding code introduced during
> this task. Per project conventions, we use this file instead of in-code TODO comments.

---

## Current Placeholders

### 1. `Task.sleep` Waits in Async Tests — STILL PRESENT

**Files:**
- `Tests/MacAmpTests/DockingControllerTests.swift:23` — `Task.sleep(nanoseconds: 300_000_000)` waiting for debounce
- `Tests/MacAmpTests/SkinManagerTests.swift:53-61` — `waitUntilNotLoading` polling loop with 50ms sleep

**Purpose:** Temporary synchronization while waiting for async state changes. Works but is brittle under CI load.
**Status:** Deferred to `async-test-determinism` follow-up task.
**Action:** Replace with deterministic async patterns:
- DockingController: Expose a `persistenceComplete` async signal or use `confirmation`
- SkinManager: Publish loading state changes via `AsyncStream` or add `onLoadComplete` callback

## Resolved Placeholders

### 2. Mixed `import XCTest` + `import Testing` (Phase 2 coexistence) — RESOLVED

**What:** Both imports present during incremental migration.
**Status:** Resolved in Phase 3. All `import XCTest` removed.

### 3. `.timeLimit(.minutes(1))` Granularity — ACCEPTED

**What:** Swift Testing only supports `.minutes()` granularity for time limits, not `.seconds()`.
**Status:** Accepted as framework limitation. Tests that previously had `.seconds(5)` or `.seconds(10)` now use `.minutes(1)`.
