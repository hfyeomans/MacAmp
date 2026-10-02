# Deprecated: Lock-Free Ring Buffer

> **Purpose:** Documents any deprecated or legacy code discovered during this task. Code marked for removal should be listed here instead of using inline `// Deprecated` comments per project conventions.

---

## Deprecated Code Findings

_No deprecated code was introduced or discovered during this task. The ring buffer is a new implementation._

## Production Code Issues Discovered (Not Deprecated, But Noted)

### 1. DockingController Debounce — `try?` Swallows Task Cancellation

**File:** `MacAmpApp/ViewModels/DockingController.swift:38-40`
**What:** The debounce task uses `try? await Task.sleep(...)` which swallows `CancellationError`, allowing `persist()` to execute even when the task was cancelled by a newer toggle.
**Impact:** Brief window of stale state persisted before correct state overwrites it. Functionally safe but logically incorrect.
**Recommendation:** Use `guard !Task.isCancelled else { return }` after the sleep, or replace `try?` with `do/try/catch`.
**Status:** Not fixed in this task — separate concern from ring buffer work.
