# Swift 6 Features Research

## Sources Consulted
- Swift 6 release notes and WWDC24 session notes that accompanied Xcode 16 betas
- MacAmp internal docs referencing Swift 6 strict concurrency upgrades

## Key Findings

### Concurrency & Actor Isolation
- Swift 6 makes full data-race safety the default: every closure/function is checked for Sendable conformance. Non-Sendable types crossing concurrency domains become compile errors.
- Regional isolation (a refinement of actor isolation) lets the compiler reason about which data belongs to which actor without explicit annotations, reducing over-annotation while still preventing unsafe cross-actor access.
- `@MainActor` (and custom global actors) adoption is effectively mandatory for UI-bound types; Swift 6 enforces isolation on stored properties and synchronous APIs called from actors.
- `@isolated` parameters allow you to temporarily treat references as isolated to an actor, supporting helper APIs such as `func update(@isolated _ actor: some Actor) async`.
- Detached tasks now inherit more context (priority, task-local values) explicitly, but still require `@Sendable` closures.

### Strict Concurrency Checking
- Strict checking is always on; there is no compiler flag to disable it in Swift 6, though `@preconcurrency` and `@unchecked Sendable` remain escape hatches.
- Global mutable state must be wrapped in actors, `@MainActor`, or synchronization primitives; otherwise the compiler emits errors instead of warnings.
- `Sendable` checking expands to stored properties, default arguments, `Result` payloads, and asynchronous sequences.
- Inference improves: many standard library types are now `Sendable`, reducing manual conformances.

### Language Improvements
- Typed throws allow functions to declare the concrete error type: `func load() throws(NetworkError)`. Callers can pattern-match without type erasure. Backward compatibility is preserved because `throws` still means `throws Error`.
- Pack expansions and variadic generics graduate from experimental to supported, simplifying APIs that forward heterogeneous arguments.
- Macro system additions: peer/attached macros gain better diagnostics and can be isolated to specific actors. Swift 6 standard library adds new macros for `@Observable`, `@Attached`, and result builders.
- C++ interoperability improves with direct import of STL containers as Swift generics, plus automatic memory safety wrappers.
- Embedded Swift adds deterministic mode (`-embed-bitcode`) and async task support for microcontrollers.

### Breaking Changes vs Swift 5.x
- Any code that relied on warning-only concurrency diagnostics must be updated; the compiler now errors on nonisolated mutable state, missing `Sendable`, or crossing actors from synchronous contexts.
- Legacy Objective-C entry points with implicitly un-annotated concurrency attributes may need `@preconcurrency` wrappers or explicit global-actor annotations.
- The default Swift language mode in Xcode 16 projects is 6.0, which changes inference for integer/float conversions and enforces stricter `mutating` semantics in macros.
- Some `async` APIs in the Foundation overlay are annotated with typed throws; callers may need `catch` clauses for new error types.

### Migration Strategies
- Compile with Swift 5.10 plus `-strict-concurrency=complete` to surface issues before flipping the project to Swift 6.
- Annotate UI and singleton types with `@MainActor` or custom global actors. Use actors or isolated structs for shared mutable state.
- Audit `Sendable` conformances: prefer value semantics or mark reference types as actors. Use `@unchecked Sendable` only when invariants are manually enforced.
- Use the new `swift-concurrency-checker` (Xcode report) to create a punch list, track fixes in tasks, and rerun as regressions appear.
- Introduce typed throws gradually by adding overloads or protocol refinements; provide bridging APIs for Swift 5 clients until the codebase is fully Swift 6.

## Open Questions
- Need concrete examples from Apple docs for typed throws adoption timeline.
- Determine if embedded Swift improvements matter for MacAmp (probably not, but worth confirming).
