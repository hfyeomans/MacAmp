# Placeholders: Swift Testing Modernization

> **Purpose:** Document any intentional placeholder or scaffolding code introduced during
> this task. Per project conventions, we use this file instead of in-code TODO comments.

---

## Current Placeholders

None yet. This file will be updated as implementation proceeds.

### Expected Placeholders

During implementation, the following may be temporarily introduced:

1. **Mixed `import XCTest` + `import Testing`** in Phase 2 (coexistence period)
   - Files: All 8 test files
   - Purpose: Allow incremental assertion migration while keeping `XCTestCase` structure
   - Status: Will be resolved in Phase 3 when `XCTestCase` classes are removed
   - Action: Remove `import XCTest` in Phase 3

2. **`Task.sleep` waits** will remain through Phases 2-4
   - Files: `DockingControllerTests.swift`, `SkinManagerTests.swift`
   - Purpose: Existing async waits kept until Phase 5 replaces them
   - Status: Will be resolved in Phase 5
   - Action: Replace with deterministic async patterns in Phase 5
