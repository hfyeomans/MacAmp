# Research: Swift File Size Limits and Architecture

**Context:** Evaluating if files remaining at 380-550 lines are "too large" after decomposition, or if taking a hard line on line count is counterproductive compared to architectural cohesion.

---

## 1. SwiftLint Industry Defaults

To understand how hard of a line the Swift community takes on file sizes, we look to the defaults of **SwiftLint**, the industry-standard static analysis tool created by Realm.

*   **`file_length` (Total lines in a `.swift` file):**
    *   Warning: 400 lines
    *   Error: 1,000 lines
*   **`type_body_length` (Lines inside a single `class` or `struct`):**
    *   Warning: 300 lines
    *   Error: 500 lines

**What this tells us:** The community consensus is that a file starting to smell bad around **400 lines**, but it's not considered a hard architectural failure ("Error") until it hits **1,000 lines**. 

---

## 2. Evaluation of Your Decompositions

### `AudioPlayer` (~554 lines)
*   **SwiftLint Status:** Over the 400-line file warning, but well under the 1,000-line error. It is likely over the 500-line `type_body_length` error if the class body itself is > 500 lines.
*   **Rationale Evaluation:** *Excellent.* You are hitting the classic "Facade Pattern" reality. A central orchestrator (`AudioPlayer`) inherently requires routing logic, state properties, and protocol conformances to tie sub-systems (EQ, Visualizer, Streams) together. 
*   **Recommendation:** **Leave it.** Breaking up a cohesive Facade just to satisfy a line-count linter leads to the "Pass-Through Middleman" pitfall (where you create files just to bounce functions). 554 lines for the central nervous system of an audio player is completely reasonable. Use `// swiftlint:disable:next type_body_length` if necessary, or split protocol conformances into extensions in the *same* file to organize it.

### `StreamDecodePipeline` (~380 lines)
*   **SwiftLint Status:** Under the 400-line warning. Passed.
*   **Rationale Evaluation:** *Strong.* The network lifecycle (`start/stop/resume/HTTP handling`) is fundamentally a single state machine. If you extract `handleHTTPResponse` into a separate file, you expose internal state management across file boundaries (`private` -> `internal` leakage).
*   **Recommendation:** **Leave it.** 380 lines for a complete, isolated audio streaming pipeline is actually quite lean. Do not split.

### `SkinManager` (~392 lines)
*   **SwiftLint Status:** Right at the 400-line warning threshold. Passed.
*   **Rationale Evaluation:** Skin parsing is notoriously verbose due to handling XML, ZIP files, and directory paths.
*   **Recommendation:** **Use Extension-Based Splitting (Approach A).** Because `SkinManager` likely has distinct operational phases (e.g., "Discovery" vs. "Parsing/Loading"), moving `scanAvailableSkins` into `SkinManager+Discovery.swift` is a great idea. It keeps the types cohesive but cleans up the navigation. *However*, only do this if it doesn't force you to change a bunch of `private` properties to `internal`. If they must be `internal` to be accessed by the extension in another file, leave it at 392 lines.

---

## 3. The "Hard Line" vs. "Architecture" Debate

**Do you take a hard line on line count?**
**No. Emphatically no.**

The Swift community (and Apple's own frameworks) strongly prefer **Cohesion (Single Responsibility)** over arbitrary line counts. 

Line counts are a *symptom* check, not a disease. A file with 600 lines might be perfectly healthy if it implements a single, complex algorithm (like a stream decoder or a software synthesizer). A file with 150 lines might be an architectural disaster if it mixes UI rendering, network requests, and database saves.

### When to ignore file size rules:
1. **The Facade Pattern:** Central orchestrators (like `AudioPlayer`) naturally grow to 500-800 lines because their single responsibility is *coordination*. 
2. **State Machines:** If extracting code forces you to expose `private` state to `internal` just so the extracted file can read it, **do not extract it**. Encapsulation is more important than file length.

### Conclusion for your Sprint
Your decompositions successfully rescued these files from the 700+ "danger zone." 
* `AudioPlayer` at 554 lines is a massive win. 
* `StreamDecodePipeline` at 380 is perfectly sized.
* `SkinManager` at 392 is fine, with optional extension splitting.

You do not need to push these down to 200 lines. Doing so would likely damage the architecture by fragmenting cohesive state machines.