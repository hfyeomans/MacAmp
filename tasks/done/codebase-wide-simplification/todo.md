# Todo: Codebase-Wide Simplification

> **Description:** Checklist for the cross-file simplification sweep.
> **Purpose:** Each phase tracked, build gates enforced.

---

## Phase 1: Research (Agent Team Sweep)

- [x] Create branch `refactor/codebase-wide-simplification`
- [x] Update state.md to IN PROGRESS
- [x] Launch audio-agent: sweep `Audio/` (~15 files)
- [x] Launch views-agent: sweep `Views/` (~44 files)
- [x] Launch models-agent: sweep `Models/` (~22 files)
- [x] Launch viewmodels-agent: sweep `ViewModels/` (~6 files)
- [x] Launch infra-agent: sweep `Windows/` + `Utilities/` + root (~25 files)
- [x] Collect all findings into research.md

## Phase 2: Synthesis

- [x] Plan agent reads all 5 sections, deduplicates, prioritizes
- [x] Group findings into implementation batches
- [x] Oracle review on plan before implementation

## Phase 3: Implementation

### Batch 1: Dead Code Removal
- [x] Remove dead functions (zero cross-file callers)
- [x] Remove dead imports
- [x] Build + test

### Batch 2: Syntax Simplification
- [x] `Result(catching:)` conversions
- [x] Other Swift idiom improvements
- [x] Build + test

### Batch 3: Shared Helper Extraction
- [x] Extract duplicate alert/dialog patterns
- [x] Extract other 3+ occurrence patterns
- [x] Build + test

### Batch 4: Cross-File DRY Consolidation
- [x] Consolidate remaining cross-file duplications
- [x] Build + test

### Batch 5: Deferred Items
- Note: Batch 5 deferred items tracked in placeholder.md

## Final Verification

- [x] XcodeBuildMCP build (Thread Sanitizer enabled)
- [x] XcodeBuildMCP test — all tests pass
- [x] Oracle review on complete branch
- [x] Duplicate-code-investigator confirmation pass
- [ ] Manual test: skins, audio, visualizer, EQ, playlist
- [x] Push branch -> create PR for user review
- [x] Update state.md on completion
