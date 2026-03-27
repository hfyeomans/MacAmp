# Deep Research: Swift File Sizes, Complexity, and Linting

**Context:** Going beyond raw line counts to understand the architectural reasons *why* a file might be large, how SwiftLint measures complexity, and whether strict adherence to line limits is beneficial.

---

## 1. Beyond Line Count: The Metrics that Matter

SwiftLint (and modern static analysis) looks at more than just `file_length`. True code complexity is measured by how hard it is to read and test the code, not just how many lines it takes up on a screen.

### Cyclomatic Complexity (`cyclomatic_complexity`)
*   **What it measures:** The number of linearly independent paths through your code (how many `if`, `else`, `for`, `while`, `guard`, and `case` statements exist).
*   **Why it matters:** A function with a cyclomatic complexity of 10 requires 10 distinct unit tests to achieve 100% branch coverage. 
*   **The SwiftUI Trap:** SwiftUI `View` bodies often have low cyclomatic complexity (they are declarative) but can still trigger `type_body_length` warnings simply due to verbose styling modifiers.

### Cognitive Complexity (`cognitive_complexity`)
*   **What it measures:** How hard it is for a *human* to understand the control flow. 
*   **Why it matters:** This penalizes deep nesting. An `if` inside an `if` inside a `for` loop is penalized heavily, whereas a flat 20-case `switch` statement (which is easy for a human to read) is barely penalized.

### Coupling vs. Cohesion (The Architectural Metric)
*   **Cohesion (High is Good):** Do the functions in this file all relate to the same central purpose? (e.g., `StreamDecodePipeline` managing a single network stream lifecycle).
*   **Coupling (Low is Good):** How much does this file rely on the internal state of other files? 

**The Golden Rule of Decomposition:**
If splitting a 500-line highly cohesive file into two 250-line files forces you to increase the coupling between them (e.g., changing 5 `private` properties to `internal` so the new file can read them), **the split has damaged the architecture.**

---

## 2. Re-evaluating Your Specific Files

With these advanced metrics in mind, let's look at your files again:

### `AudioPlayer` (~554 lines)
*   **Architectural Role:** The Facade / Central Orchestrator. 
*   **Why it's big:** Facades inherently have high line counts because their job is to compose other systems (EQ, Visualizer, Stream, Local playback). They are the "glue."
*   **Complexity Check:** A Facade usually has *low* Cyclomatic Complexity because it just forwards calls (e.g., `func play() { engine.play() }`). It takes up lines, but it doesn't have deep, nested `if/else` logic.
*   **Verdict:** **Still firmly agree to leave it.** Splitting a Facade just to reduce line count creates "pass-through" files, which actually *increases* Cognitive Complexity because developers have to jump through 3 files to trace a single `play()` command.

### `StreamDecodePipeline` (~380 lines)
*   **Architectural Role:** Complex State Machine.
*   **Why it's big:** Network audio streaming requires handling HTTP headers, byte parsing, ring buffer management, and error recovery. This inherently requires a lot of state (`private var isReconnecting`, `private var bufferFill`).
*   **Complexity Check:** If you extract the HTTP response handling to a new file, that new file needs to mutate the parent's `bufferFill` state. You break encapsulation.
*   **Verdict:** **Leave it.** The file is highly cohesive. The 380 lines belong together. 

### `SkinManager` (~392 lines)
*   **Architectural Role:** Parser / File System Manager.
*   **Why it's big:** Parsing XML, unzipping `.wsz` files, and traversing directories requires a lot of boilerplate Swift code (`FileManager.default...`, `do/catch` blocks).
*   **Complexity Check:** Parsing code often has high Cyclomatic Complexity due to many `guard let` failure paths. 
*   **Verdict:** **Borderline, but acceptable.** Extracting the Discovery phase (`SkinManager+Discovery.swift`) is still a good idea here because finding files on a disk is conceptually different from parsing the bytes of an XML file. They have low coupling to each other.

---

## 3. The "Hard Line" Conclusion

**Is the SwiftLint `file_length` rule "right"?**
The SwiftLint defaults (Warning at 400, Error at 1000) are **heuristics, not laws.** They exist to flag "God Objects" (files that do everything).

You should **not** take a hard line on file size if the file represents a single, cohesive architectural unit (like a Facade or a State Machine).

**When to take a hard line:**
Take a hard line when a file violates the **Single Responsibility Principle (SRP)**. If your 600-line `AudioPlayer` file also contained the logic for *parsing the skin XML* or *drawing the UI buttons*, then you must split it, regardless of how tightly coupled it feels. 

**Your Decompositions:**
You have successfully separated concerns. `AudioPlayer` only handles audio orchestration. `SkinManager` only handles skins. They are no longer God Objects. The fact that they rest comfortably in the 300-500 line range is a sign of a healthy, appropriately-sized architectural boundary in a complex macOS desktop app.