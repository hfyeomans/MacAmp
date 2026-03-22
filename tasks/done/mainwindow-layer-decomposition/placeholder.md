# Placeholder: WinampMainWindow Layer Decomposition

> **Purpose:** Document any intentional placeholder or scaffolding code introduced during this task.
> Per project conventions, we use centralized placeholder.md files instead of in-code TODO comments.

## Resolved Placeholders

### Coords Typealias (Phase 1 → Phase 3)

- **File:** `MacAmpApp/Views/MainWindow/WinampMainWindow.swift`
- **Purpose:** Temporary `typealias Coords = WinampMainWindowLayout` for backward compatibility
  during incremental migration.
- **Status:** Resolved
- **Action:** Typealias removed when old WinampMainWindow.swift was deleted in Phase 3.
  All child views reference `WinampMainWindowLayout` directly.
- **Added:** 2026-02-22
- **Resolved:** 2026-02-22

### Parallel Builder Methods (Phase 2)

- **Purpose:** During extraction, builder methods existed in both old extension and new child views.
- **Status:** Resolved
- **Action:** Old extension file deleted in Phase 3. No duplicate code remains.
- **Added:** 2026-02-22
- **Resolved:** 2026-02-22

## Active Placeholders

None. All scaffolding has been resolved.

## Rules

1. NO `// TODO` comments in production code
2. Document all placeholders in this file with file path, line, purpose, status, and action
3. Review during task completion -- all items must be either resolved or explicitly deferred
4. Placeholder entries must be dated when added and when resolved
