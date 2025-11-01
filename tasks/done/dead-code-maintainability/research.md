# Research Notes

## Focus
- Address outstanding duplication references in tasks/code-duplication-analysis/README.md sections 5.1 (Maintainability Impact) and 5.3 (Complexity Impact).
- Verify status of prior TODO `// TODO: Implement eject logic` to report outcome.

## Findings
- `tasks/code-duplication-analysis/README.md` still flags "High" duplication due to multiple window implementations. After removing modern window variants, `DockingContainerView.swift` remains in the project but is unused; it duplicates logic now handled by `UnifiedDockView`.
- `DockingContainerView.swift` references only itself and project metadata entries; no active code uses it (`rg "DockingContainerView("` only matches preview in the file itself).
- Removing this file will further reduce duplicate window implementations, satisfying first bullet in sections 5.1 and 5.3.
- The TODO comment `// TODO: Implement eject logic` previously called out in `AudioPlayer.swift` has been replaced with a concrete `eject()` implementation that clears playlist state (commit 41e4cce).
