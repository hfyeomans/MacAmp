# Plan: Codebase-Wide Simplification

> **Description:** Systematic sweep of all 112 .swift files for cross-file DRY violations, dead code, and simplification.
> **Purpose:** Phase 2.5 cleanup before structural decomposition. Reduces code volume before extraction.

---

## Objective

Sweep the entire MacAmp codebase (~112 .swift files) for:
1. **Cross-file DRY violations** — same logic implemented in multiple files
2. **`Result(catching:)` opportunities** — verbose do-catch → Result patterns
3. **Duplicate alert/dialog patterns** — NSAlert setup repeated across files
4. **Dead code across file boundaries** — functions with zero callers outside their file
5. **Common helper extraction** — patterns repeated 3+ times that deserve a shared utility

## Phase 1: Research (Agent Team Sweep)

5 parallel Explore agents, each reading ALL files in their area end-to-end using:
- `sg --lang swift` (ast-grep) for structural pattern matching
- Grep tool for cross-reference counting
- Full file reads to understand context

### Agent Assignments

**audio-agent** — `MacAmpApp/Audio/` (~15 files)
- Skills: `/duplicate-code-investigator` patterns
- Focus: duplicate state-machine patterns, error handling triplets, buffer management
- Tools: ast-grep for `Task { @MainActor`, `guard !isShutdown`, `withUnsafeBufferPointer`

**views-agent** — `MacAmpApp/Views/` (~44 files)
- Skills: `/duplicate-code-investigator` patterns
- Focus: duplicate SwiftUI modifier chains, alert/dialog code, @ViewBuilder patterns
- Tools: ast-grep for `.buttonStyle(.plain)`, `NSAlert()`, `.focusable(false)`

**models-agent** — `MacAmpApp/Models/` (~22 files)
- Focus: dead types, redundant parsing, duplicate struct definitions
- Tools: ast-grep for `struct`, `enum`, `func parse`

**viewmodels-agent** — `MacAmpApp/ViewModels/` (~6 files)
- Focus: duplicate UserDefaults patterns, observation boilerplate, state management
- Tools: ast-grep for `didSet`, `UserDefaults.standard`, `@Observable`

**infra-agent** — `MacAmpApp/Windows/` + `MacAmpApp/Utilities/` + root files (~25 files)
- Focus: duplicate window management, utility functions, dead imports
- Tools: ast-grep for `NSWindow`, `import`, dead code patterns

### Each agent reports:
- ACTIONABLE: fix now (clear DRY violation, dead code, `Result(catching:)`)
- DEFERRED: fix after decomposition (behavior-coupled patterns)
- FALSE POSITIVE: intentional repetition (explain why)

## Phase 2: Synthesis

Plan agent reads all 5 research sections and:
1. Deduplicates cross-agent findings (same pattern found by multiple agents)
2. Groups by fix type (dead code, DRY violation, simplification)
3. Prioritizes: low-risk → high-risk
4. Creates implementation batches (each batch = 1 commit + build + test)

## Phase 3: Implementation

Execute in batches:
- Batch 1: Dead code removal (zero-risk, pure deletion)
- Batch 2: `Result(catching:)` and simple syntax improvements
- Batch 3: Shared helper extraction (moderate risk, changes call sites)
- Batch 4: Cross-file DRY consolidation (highest risk, may change behavior)

Each batch: implement → xcodegen → build → test → commit.
After all batches: Oracle review → push → PR.

## Constraints

- All changes behavior-preserving (learned from Oracle P2/P3 catches in Task 0)
- When two call sites have different fallbacks, PRESERVE the difference (add `fallback:` parameter)
- Do not restructure files — this is simplification, not decomposition
- Do not touch files that are targets of the 5 decomposition tasks unless the simplification is orthogonal
- Single branch: `refactor/codebase-wide-simplification`

## Verification

- XcodeBuildMCP build + test with Thread Sanitizer after each batch
- Oracle review on complete branch before PR
- Duplicate-code-investigator confirmation pass after all fixes
- Manual test: skin switching, audio playback, visualizer, EQ, playlist
