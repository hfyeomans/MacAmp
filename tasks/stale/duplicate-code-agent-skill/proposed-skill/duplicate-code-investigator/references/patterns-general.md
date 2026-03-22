# General Patterns

## Search Stack

Use a combination:

1. `rg` for fast inventory, symbol counts, and broad text search
2. `ast-grep` for syntax-aware structural matching
3. agent reasoning for ownership, side effects, and false-positive filtering
4. optional clone detectors later for classic copy/paste duplication

Do not rely on any single layer.

## What To Search For

Look for code that suggests a side effect or owner:

- `configure`
- `initialize`
- `register`
- `subscribe`
- `observe`
- `attach`
- `connect`
- `activate`
- `deactivate`
- `install`
- `rewire`
- `start`
- `stop`

Then ask whether the same side effect can happen twice or whether two implementations
compete for the same responsibility.

## Preferred Workflow

### 1. Inventory with `rg`

Use `rg` to count and locate call sites, lifecycle hooks, registrations, or suspicious nouns.

### 2. Refine with `ast-grep`

Use `ast-grep` when structure matters:

- same callee in different contexts
- same method reached through multiple owners
- repeated registration or lifecycle wiring
- similar implementations with renamed identifiers

### 3. Judge, do not just count

Multiple call sites are not automatically a bug.

Classify them as:

- intended fan-out
- duplicated behavior
- architecture smell
- false positive

## High-Value Targets

- initialization or teardown
- callbacks and delegates
- lifecycle hooks
- subscriptions and observers
- coordinators and routers
- old and new implementations of the same feature

## Clone Detector Position

Classic clone detectors are useful for:

- copied files
- near-identical functions
- repeated component implementations

They are not enough for:

- duplicate execution paths
- semantic duplicates
- missing choke points

Use them as an optional structural layer, not the core of this skill.
