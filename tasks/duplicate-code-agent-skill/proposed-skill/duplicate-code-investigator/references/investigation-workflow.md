# Investigation Workflow

## Goal

Catch both:

- copied or competing implementations
- duplicated execution paths that trigger the same side effect more than once

## Phase 1: Frame the Risk

Classify the report before scanning:

- `STRUCTURAL`: similar files, components, or functions
- `BEHAVIORAL`: same side effect from multiple paths
- `HYBRID`: both are present

High-priority behavioral examples:

- duplicate `configure`, `initialize`, `register`, `attach`, `connect`, `subscribe`, `observe`, `install`, `activate`, `deactivate`, or `rewire` calls
- the same side effect called from multiple lifecycle hooks
- direct calls that bypass the intended coordinator or choke point
- duplicate work triggered from multiple actor or queue contexts

## Phase 2: Pick Investigation Targets

Start with one or more of:

- user-suspected function names
- recently moved or re-ordered calls
- lifecycle hooks
- observer or delegate registration
- coordinator entry points
- old and new implementations of the same feature

If no target is obvious, derive targets from changed files or from stateful method names.

## Phase 3: Run Deterministic Scans

### Fast inventory

Use `rg` for raw call-site counts.

Examples:

```bash
rg -n 'configureFramer\(' MacAmpApp
rg -n 'deactivateStreamBridge\(' MacAmpApp
rg -n 'NotificationCenter\.default\.addObserver' MacAmpApp
```

### Structural checks

Use `ast-grep` as the primary syntax-aware matcher in any supported language.

Load:

- [`patterns-general.md`](patterns-general.md)
- the relevant language-specific pattern reference, for example [`patterns-swift.md`](patterns-swift.md)

Use language-specific patterns only after the broad inventory narrows the field.

#### Swift examples

Examples:

```bash
sg --lang swift -p '$OBJ.configureFramer($$$ARGS)' MacAmpApp
sg --lang swift -p '$OBJ.deactivateStreamBridge()' MacAmpApp
sg --lang swift -p 'Task { @MainActor in $$$BODY }' MacAmpApp
sg --lang swift -p '.onAppear { $$$BODY }' MacAmpApp
sg --lang swift -p '.onChange(of: $$$VALUE) { $$$BODY }' MacAmpApp
```

### Optional large-context pass

If the structural scan finds many plausible paths, use a second pass to summarize intent
and ownership across the broader slice of files. This is where a large-context agent or
Gemini pass can help.

## Phase 4: Judge The Finding

Ask these questions:

1. Do these call sites trigger the same side effect?
2. Are they intentionally idempotent?
3. Should they collapse to one owner or choke point?
4. Are there two live implementations of the same feature?
5. Does one path exist only because an older path was never removed?

Only mark as confirmed if the answer is strong enough to defend in review.

## Phase 5: Recommend The Fix

Prefer:

- one owner
- one choke point
- one implementation
- explicit idempotence where multiple calls are truly required

Recommended fix forms:

- remove stale call site
- route all paths through one coordinator
- consolidate duplicate components
- add invariant comments or tests around single-init behavior

## Output Shape

For each finding, include:

- classification: `STRUCTURAL`, `BEHAVIORAL`, or `HYBRID`
- confidence: `CONFIRMED`, `LIKELY`, or `LOW`
- evidence: file and line references
- impact: correctness, maintenance, or architecture
- recommendation: the single-owner path or consolidation
