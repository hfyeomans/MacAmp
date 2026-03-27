# Swift Architecture & Decomposition Guidelines

These principles govern file sizing, code decomposition, and architectural refactoring in Swift projects.

## 1. Cohesion Over Line Count
*   **The Prime Directive:** Never decrease a file's size if doing so forces you to increase coupling. If splitting a 500-line file requires changing `private` state to `internal` just so the new files can communicate, the split has damaged the architecture.
*   **Line Counts are Heuristics:** SwiftLint's default limits (400 line warning, 1,000 line error) are heuristics to catch "God Objects" (files that do everything). They are not hard laws.
*   **Facades and State Machines:** Central orchestrators (Facades) and complex State Machines will naturally be larger (500+ lines). This is acceptable as long as they adhere to a Single Responsibility. Splitting them artificially creates "Pass-Through Middlemen" and fragments state.

## 2. Advanced Complexity Metrics
*   **Physical Size vs. Mental Load:** Evaluate files based on *Cognitive Complexity* (how hard the control flow is for a human to read) and *Cyclomatic Complexity* (how many independent testing paths exist), rather than purely physical line count. 
*   **Verbose vs. Complex:** A 600-line file composed of flat `switch` cases or declarative SwiftUI modifiers takes up space but has low complexity. It does not strictly need decomposition.

## 3. The Refactoring Workflow (Decomposition vs. Deduplication)
*   **Clean Up First (Intra-component):** Before moving code to new files, deduplicate highly localized logic that shares the same `private` state. This prevents creating redundant files.
*   **Move First, Deduplicate Later (Inter-component):** For architectural duplication across different domains, extract the code exactly as written into new files first. Once the new structure is established and compiling, identify the shared logic and extract it into a common utility or service. Mixing structural moves with logical rewrites causes cognitive overload and masks test failures.

## 4. Avoiding Decomposition Pitfalls
*   **The Pass-Through Middleman:** Do not create intermediate files or views that only exist to pass data from a parent to a child. Use SwiftUI's `@Environment` to inject state directly where it is needed.
*   **Visibility Leaks:** When extracting a helper struct, expose only the absolute minimum required surface area. Use `fileprivate` if the types can remain in the same file, rather than lazily defaulting to `internal`.
*   **State Fragmentation:** Honor the "Source of Truth" rule. Do not move a `@State` variable into a new child file if the parent still needs to react to it. Keep state at the highest necessary level and pass it down via `@Binding`.

## 5. The WET Principle (Write Everything Twice)
*   **Duplication > Wrong Abstraction:** Strict adherence to DRY (Don't Repeat Yourself) often leads to premature abstraction, resulting in rigid functions with excessive boolean flags.
*   **The Rule of Three:** Write it once to get it working. Write it twice (WET) and accept the duplication to keep components decoupled. Only refactor into a shared DRY abstraction when you need the exact logic a *third* time, proving a stable pattern has emerged.