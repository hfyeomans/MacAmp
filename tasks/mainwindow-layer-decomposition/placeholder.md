# Placeholder: WinampMainWindow Layer Decomposition

> **Purpose:** Document any intentional placeholder or scaffolding code introduced during this task.
> Per project conventions, we use centralized placeholder.md files instead of in-code TODO comments.

## Active Placeholders

*None yet. This file will be updated during implementation if any scaffolding code is introduced.*

## Template

When adding a placeholder entry during implementation, use this format:

```
### [Short Description]
- **File:** `MacAmpApp/Views/MainWindow/[filename].swift`
- **Line:** [approximate line number]
- **Purpose:** [Why this placeholder exists]
- **Status:** Pending | In Progress | Resolved
- **Action:** [What needs to happen to resolve this]
- **Added:** [date]
- **Resolved:** [date, if applicable]
```

## Expected Placeholders

These may arise during phased implementation:

### Coords Typealias (Phase 1)

- **File:** `MacAmpApp/Views/MainWindow/WinampMainWindow.swift`
- **Purpose:** Temporary `typealias Coords = WinampMainWindowLayout` for backward compatibility
  during incremental migration. Allows existing code to compile while child views are extracted.
- **Status:** Pending
- **Action:** Remove typealias after all references are updated to use `WinampMainWindowLayout` directly.

### Parallel Builder Methods (Phase 2)

- **File:** Various child view files
- **Purpose:** During extraction, some builder methods may temporarily exist in both the old extension
  file and the new child view file while wiring is tested.
- **Status:** Pending
- **Action:** Delete duplicates from extension file once child view is verified working.

## Rules

1. NO `// TODO` comments in production code
2. Document all placeholders in this file with file path, line, purpose, status, and action
3. Review during task completion -- all items must be either resolved or explicitly deferred
4. Placeholder entries must be dated when added and when resolved
