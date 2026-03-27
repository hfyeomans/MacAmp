# Plan: Responsibility Sweep (SRP + AHA Audit)

> **Description:** Research-only audit of all 110 .swift files for Single Responsibility violations and premature abstractions, guided by Swift Architecture & Decomposition principles.
> **Created:** 2026-03-25
> **Type:** Research (no code changes)

---

## Objective

Evaluate every .swift file in MacAmpApp/ through two lenses:

1. **SRP Lens:** Does this file have a single, cohesive responsibility? Would splitting it improve or damage the architecture?
2. **AHA Lens:** Are there premature abstractions (DRY violations of the Rule of Three) or missing abstractions (3+ duplications without consolidation)?

Also validate the 5 pending decomposition plans against the Swift Architecture & Decomposition Guidelines.

## Guiding Principles

### From Swift Community / Apple Frameworks (Gemini research)

1. **Cohesion Over Line Count:** Never decrease a file's size if doing so forces you to increase coupling. Changing `private` to `internal` just so split files can communicate damages architecture.
2. **Facades and State Machines:** Central orchestrators and complex state machines will naturally be 500+ lines. This is acceptable if they adhere to Single Responsibility. Splitting them creates "Pass-Through Middlemen."
3. **Cognitive Complexity > Physical Size:** A 600-line file of flat switch cases or declarative SwiftUI modifiers has low complexity. It does not need decomposition.
4. **Pass-Through Middleman:** Do not create intermediate files/views that only exist to pass data. Use SwiftUI `@Environment` for injection.
5. **Visibility Leaks:** When extracting, expose minimum surface area. Prefer `fileprivate` over `internal` when types can remain in the same file.
6. **State Fragmentation:** Honor Source of Truth. Don't move @State into a child if the parent still reacts to it.

### From AHA (Avoid Hasty Abstractions) — Oracle-validated

7. **Rule of Three:** Accept duplication until the 3rd occurrence. Only then extract a shared abstraction.
8. **Exception — Safety Invariants:** Threading, lifetime, and FFI invariants may be extracted with only 2 callers (e.g., QueueConfined).
9. **Reject Flag Abstractions:** Abstractions that need boolean flags to serve divergent callers are wrong abstractions. Re-introduce duplication.
10. **Remove Unused APIs:** Don't pre-generalize helper APIs. If a function has 0 callers, delete it.

## Agent Team Structure

5 parallel Explore agents (same as Phase 2.5 sweep):

| Agent | Scope | Est. Files |
|-------|-------|------------|
| audio-agent | `Audio/` + `Audio/Streaming/` | ~15 |
| views-agent | `Views/` + all subfolders | ~42 |
| models-agent | `Models/` + `Skins/` | ~22 |
| viewmodels-agent | `ViewModels/` | ~6 |
| infra-agent | `Windows/` + `Utilities/` + root files | ~25 |

After agents report → Plan agent synthesizes findings.

## Per-File Evaluation Protocol

For each .swift file:

### Step 1: Structural Analysis
- Use `ast-grep` to identify all top-level types (classes, structs, enums, protocols)
- Count methods per type
- Identify protocol conformances
- Note access control distribution (private/fileprivate/internal/public)

### Step 2: SRP Classification
- **State primary responsibility** in one sentence
- **Identify secondary responsibilities** — signals:
  - Multiple unrelated protocol conformances on one type
  - Methods that don't reference the type's core state
  - Static utility methods unrelated to the type's purpose
  - Mixed concerns (UI + networking, model + persistence + presentation)
  - Multiple top-level types with different lifecycles
- **Assess coupling impact** — if a secondary responsibility exists:
  - Would extracting it require `private → internal` visibility changes?
  - Would it create a pass-through middleman?
  - Would it fragment state ownership?
- **Classify:**
  - **Clean** — single responsibility, no action needed
  - **Justified** — multiple concerns but tightly coupled; extraction would damage architecture (per Principle #1)
  - **Actionable** — genuinely separate responsibilities that can be extracted without visibility leaks

### Step 3: Complexity Assessment
- Is the file large because of **cognitive complexity** (nested control flow, interleaved state) or **verbosity** (declarative SwiftUI, flat switch cases, protocol conformance boilerplate)?
- A verbose-but-simple file does NOT need decomposition regardless of line count.

### Step 4: AHA Check
- Flag abstractions in this file with **1-2 callers** that also add indirection (possible premature DRY)
- Flag logic duplicated **3+ times** without a shared abstraction (missing DRY — Rule of Three triggered)
- Exception: safety invariants (threading, memory, FFI) are exempt from Rule of Three

## Decomposition Plan Validation

The 5 target files get additional focused analysis:

### StreamDecodePipeline (697 lines → 3 new files, ~380 residual)
- Are DecodeContext, SessionDelegateProxy, PlaylistResolver genuinely separate responsibilities?
- Does the ~380 residual have a single cohesive responsibility?
- Any visibility leaks required?

### WinampEqualizerWindow (616 lines → 5 new files, ~100 residual)
- Is this file cognitively complex or just verbose SwiftUI?
- Does the MainWindow pattern (child view structs) genuinely improve architecture here?
- Does EQFullLayer become a pass-through middleman?

### VisualizerPipeline (645 lines → 4 new files, ~231 residual)
- Are the 4 extracted types (Types, ScratchBuffers, SharedBuffer, TapHandler) genuinely separate?
- Does SharedBuffer `private → internal` violate Principle #1?

### SkinManager (766 lines → 4 new files, ~392 residual)
- **Known concern:** Plan changes `defaultSkinSpriteCache`, `defaultSkinExtractedSheets`, `defaultSkinPayload` from `private` to `internal`. This is a visibility leak per Principle #5.
- Should SkinManager+Fallback.swift use a different pattern (e.g., `fileprivate`, inout parameters, or remain in the same file)?
- Is the ~392 residual a single responsibility or still multi-responsibility?

### AudioPlayer Seek Extraction (734 lines → 1 new file, ~554 residual)
- **Known concern:** Oracle rated Moderate-High risk. Seek state spans shared mutable state.
- Does SeekController become a pass-through middleman? (AudioPlayer still writes seek state via controller methods)
- Would the ~554 residual be a clean single-responsibility facade?
- Is the callback pattern (6 callbacks from SeekController → AudioPlayer) an acceptable trade-off?

## Output Format

### Per-Agent Report
```markdown
## [Directory Area] — [X files, Y Clean, Z Justified, W Actionable]

### filename.swift (N lines) — [Clean/Justified/Actionable]
- **Primary responsibility:** [one sentence]
- **Secondary responsibilities:** [none / list]
- **Complexity:** [cognitive / verbose]
- **AHA findings:** [none / premature DRY / missing DRY]
- **Action:** [none / recommendation]
```

### Synthesis Report (written to `tasks/responsibility-sweep/research.md`)
1. **Decomposition plan validation** — Proceed/Revise/Cancel verdict per task with reasoning
2. **New actionable findings** — files with genuine SRP violations ranked by severity
3. **AHA findings** — premature abstractions to consider undoing, missing abstractions to consider adding
4. **Statistics** — Clean/Justified/Actionable counts per area + totals
5. **Revised decomposition recommendations** — any plan changes based on findings

## Constraints

- Research only — no code changes
- Each agent reads every file in its scope end-to-end
- Use ast-grep for structural analysis, rg for cross-file coupling checks
- Apply principles consistently — a 200-line file with 2 responsibilities IS worse than a 600-line file with 1
- Do not penalize line count alone — evaluate cognitive complexity
