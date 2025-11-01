# Plan

1. Inspect model-level updates (`AppSettings`, `SkinSprites`) for architectural alignment:
   - Verify persistence strategy for `isDoubleSizeMode`
   - Check for unused or debug code (`targetWindowFrame`, logging)
   - Confirm sprite additions match usage patterns
2. Evaluate view components (`SkinToggleStyle`, `WinampMainWindow`, `UnifiedDockView`):
   - Identify dead code, scaffolds, redundant scale calculations
   - Validate state management and Swift 6 compliance
   - Assess performance impacts and duplication
3. Cross-reference findings with project conventions:
   - Naming consistency, logging approach, architecture layering
   - Highlight severity, recommend fixes per issue
4. Compile comprehensive review report with file/line references covering requested criteria.
