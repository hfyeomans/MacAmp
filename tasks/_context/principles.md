# Architecture Decomposition Principles

> **Source:** Synthesized from Swift community guidelines (Gemini), Oracle review, AHA/WET/DRY literature, and lessons learned from MacAmp Phase 2 cleanup.
> **Created:** 2026-03-25

---

## The 7 Principles

### 1. Problem-First, Not Cleanup-First
No refactor without a concrete failure mode or cost. "This file is 700 lines" is not a problem statement. "This file has 3 responsibilities that change independently and cause merge conflicts" is.

### 2. Cohesion Over Line Count
Never decrease a file's size if doing so forces increasing coupling. A 600-line file with one responsibility is better than three 200-line files that leak private state to communicate. SwiftLint limits are heuristics for catching God Objects, not hard laws.

### 3. State Ownership Is Sacred
Never extract behavior that weakens a single source of truth. If splitting a file requires the new file to write state that the original file also reads/reacts to, the split fragments state. Keep state machines cohesive.

### 4. Rule of Three (AHA)
Accept duplication until the 3rd occurrence. Only then extract a shared abstraction. **Exception:** Safety invariants (threading, lifetime, FFI) may be extracted with 2 callers. **Rejection criterion:** If the abstraction needs boolean flags to serve divergent callers, it's a wrong abstraction — re-introduce duplication.

### 5. API Surface Minimization
No visibility widening (`private → internal`) unless ownership and contracts are explicitly redefined. If an extraction requires exposing previously-private state, evaluate whether the extraction is the right boundary. Prefer `fileprivate` when types can remain in the same file.

### 6. No Pass-Through Middlemen
Reject modules that only forward calls without adding policy, invariants, or transformation. In SwiftUI, use `@Environment` for dependency injection rather than drilling through intermediate views.

### 7. ADR + Kill Switch
Every decomposition gets a short Architecture Decision Record: what problem it solves, what trade-offs it accepts, and when to stop (rollback/cancel criteria). If the decomposition doesn't clearly improve the architecture, don't do it.

---

## Pre-Decomposition Gate Checklist

Before ANY structural decomposition work:

- [ ] **Problem statement written** — what concrete failure mode or cost does this solve?
- [ ] **Non-goals listed** — what are we explicitly NOT trying to fix?
- [ ] **Principles contract approved** — which of the 7 principles apply and how?
- [ ] **Responsibility map exists** — who owns mutable state, side effects, invariants?
- [ ] **Complexity assessed** — is the file cognitively complex or just verbose?
- [ ] **Candidate split scored** on: cohesion gain, state risk, visibility impact, pass-through risk
- [ ] **Public/internal API delta listed** — what visibility changes are required?
- [ ] **Stop criteria defined** — when should we NOT decompose?

**Hard gate:** If items 1-5 are incomplete, no structural edits proceed.

---

## Cognitive vs Physical Complexity

| Type | Example | Action |
|------|---------|--------|
| High cognitive, high LOC | Interleaved state machine + UI + networking in one file | Decompose by responsibility |
| High cognitive, low LOC | Dense 200-line algorithm with nested conditionals | Simplify control flow, don't split |
| Low cognitive, high LOC | 600 lines of flat SwiftUI modifiers or switch cases | Leave alone (verbose ≠ complex) |
| Low cognitive, low LOC | Clean 150-line focused utility | Leave alone |

---

## DRY/WET/AHA Decision Tree

```
Is the logic duplicated?
├── No → Leave it alone
└── Yes → How many times?
    ├── 1st time → Write it (WET is fine)
    ├── 2nd time → Accept the duplication, keep components decoupled
    └── 3rd+ time → Now extract a shared abstraction (DRY)
        └── Does the abstraction need behavior flags?
            ├── Yes → Wrong abstraction. Keep WET.
            └── No → Good abstraction. Extract it.

Exception: Safety invariants (threading/FFI) → extract at 2nd occurrence.
```
