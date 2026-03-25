# Research: Codebase-Wide Simplification

> **Description:** Findings from agent team sweep of all 112 .swift files.
> **Purpose:** Evidence base for the simplification plan. Each agent writes its findings here.

---

## Research Sources

- Task 0 (intra-file dedup): identified cross-file patterns to defer (sprite loops, alert duplication)
- Gemini review (PR #71): flagged `Result(catching:)` and duplicate alert patterns
- Oracle reviews (2026-03-24): P2 viscolor fallback, P3 pledit fallback — both behavior-preserving regressions from naive dedup
- Duplicate-code-investigator (Task 0): 4 items deferred to Phase 2c

## Known Cross-File Patterns (from prior work)

### From Task 0 duplicate-code-investigator (deferred to Phase 2c)

| Finding | Files | Description |
|---------|-------|-------------|
| S1: Sprite extraction loops | SkinManager (3 locations) | Similar autoreleasepool + cropping loops — behavior-coupled to fallback/cache |
| S4: showNotificationAlert vs presentAlert | SkinManager | Both create NSAlert with same window-lookup; sync vs async |
| D3: stopInternal+setState+onTermination | StreamDecodePipeline (3 locations) | Error handling triplet with different error construction |
| E2: Titlebar button modifier chain | WinampEqualizerWindow (3x) | Identical SwiftUI modifier chains |

### From Gemini PR Review

| Pattern | Example | Scope |
|---------|---------|-------|
| `Result(catching:)` | `do { result = .success(try ...) } catch { result = .failure(error) }` | Codebase-wide |
| Duplicate alert construction | NSAlert setup + present pattern | Multiple View files |

## Agent Findings

*To be populated by parallel agent team sweep.*

### Audio Agent Findings
*Pending*

### Views Agent Findings
*Pending*

### Models Agent Findings
*Pending*

### ViewModels Agent Findings
*Pending*

### Infrastructure Agent Findings
*Pending*
