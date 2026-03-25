# Todo: Codebase-Wide Simplification

> **Description:** Checklist for the cross-file simplification sweep.
> **Purpose:** Each phase tracked, build gates enforced.

---

## Phase 1: Research (Agent Team Sweep)

- [ ] Create branch `refactor/codebase-wide-simplification`
- [ ] Update state.md to IN PROGRESS
- [ ] Launch audio-agent: sweep `Audio/` (~15 files)
- [ ] Launch views-agent: sweep `Views/` (~44 files)
- [ ] Launch models-agent: sweep `Models/` (~22 files)
- [ ] Launch viewmodels-agent: sweep `ViewModels/` (~6 files)
- [ ] Launch infra-agent: sweep `Windows/` + `Utilities/` + root (~25 files)
- [ ] Collect all findings into research.md

## Phase 2: Synthesis

- [ ] Plan agent reads all 5 sections, deduplicates, prioritizes
- [ ] Group findings into implementation batches
- [ ] Oracle review on plan before implementation

## Phase 3: Implementation

### Batch 1: Dead Code Removal
- [ ] Remove dead functions (zero cross-file callers)
- [ ] Remove dead imports
- [ ] Build + test

### Batch 2: Syntax Simplification
- [ ] `Result(catching:)` conversions
- [ ] Other Swift idiom improvements
- [ ] Build + test

### Batch 3: Shared Helper Extraction
- [ ] Extract duplicate alert/dialog patterns
- [ ] Extract other 3+ occurrence patterns
- [ ] Build + test

### Batch 4: Cross-File DRY Consolidation
- [ ] Consolidate remaining cross-file duplications
- [ ] Build + test

## Final Verification

- [ ] XcodeBuildMCP build (Thread Sanitizer enabled)
- [ ] XcodeBuildMCP test — all tests pass
- [ ] Oracle review on complete branch
- [ ] Duplicate-code-investigator confirmation pass
- [ ] Manual test: skins, audio, visualizer, EQ, playlist
- [ ] Push branch -> create PR for user review
- [ ] Update state.md on completion
