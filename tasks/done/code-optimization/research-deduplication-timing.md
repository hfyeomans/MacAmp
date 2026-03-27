# Research: Deduplication Timing in Swift Refactoring

**Question:** Is it better to deduplicate and simplify code *before* file moves? Does breaking up code into new files obscure relationships and make deduplication harder?

---

## Evaluation of the Concern

Your concern is highly valid and represents a classic software engineering debate: **"Clean up then move" vs. "Move then clean up."**

You are correct that breaking up code *can* obscure relationships. If you have two nearly identical 50-line functions sitting right next to each other in a 700-line file, the duplication is obvious. If you move one function to `FileA.swift` and the other to `FileB.swift`, you might never notice the duplication again.

However, the "best practice" answer depends entirely on the *type* of duplication you are dealing with.

## When to Deduplicate BEFORE Moving (The "Clean Up First" Approach)

You should deduplicate **before** extracting to new files when:

1. **The duplication is highly localized (Intra-component):**
   * *Example:* A massive `WinampMainWindow.swift` has three different 40-line `buildButton()` functions scattered inside it.
   * *Why before?* Because if you extract the views first, you might accidentally create three slightly different new files (`PlayButton.swift`, `PauseButton.swift`, `StopButton.swift`) instead of realizing you just needed one generic `WinampButton.swift`.

2. **The code is heavily coupled to shared local state:**
   * *Example:* Two functions both modify the same 4 `private @State` variables.
   * *Why before?* If you try to extract them first, you will run into massive `private` -> `internal` visibility leaks. It is much easier to combine them into one clean function while they still live next to the state they modify.

## When to Deduplicate AFTER Moving (The "Move First" Approach)

You should deduplicate **after** extracting to new files when:

1. **The duplication exists across architectural boundaries (Inter-component):**
   * *Example:* You realize `MainWindow.swift` and `PlaylistWindow.swift` both have identical logic for parsing a specific skin sprite.
   * *Why after?* Until you extract the window logic into its own domain, you don't have a clear "Core" or "Utilities" folder to put the shared logic into. Moving the files clarifies the architecture, making it obvious where the new deduplicated `SkinParserService` should live.

2. **The file is simply too large to hold in your head (Cognitive Overload):**
   * *Example:* A 783-line file where you have to scroll for 15 seconds to see how `init()` relates to `deinit`.
   * *Why after?* Trying to rewrite complex logic inside a massive file is error-prone. By slicing the file into smaller, targeted files first (even if they contain duplicated logic), you reduce cognitive load. You can then look at the smaller files side-by-side in Xcode and cleanly extract the duplicate logic.

## The Recommended Hybrid Workflow for MacAmp

Given you are dealing with 600-800 line files in a SwiftUI app, the safest, most professional workflow is a **Hybrid Approach**:

1. **Phase 2a: Intra-file Deduplication (Clean Up First)**
   * Scan the 700-line file. Are there obvious duplicated ViewBuilders? Repeated helper functions? 
   * **Action:** Consolidate them *inside* the massive file first. Do the easy, obvious dedupes where the relationship is highly visible.
2. **Phase 2b: Structural Extraction (The Moves)**
   * Extract the logical chunks (structs, classes) into their new files exactly as they are. Make the project compile.
3. **Phase 2c: Cross-file Deduplication (Clean Up After)**
   * Now that the files are isolated, look for duplication *between* the newly created files. Extract that shared logic into a common `Components/` or `Utilities/` folder.

### Summary
Your intuition is spot on: moving code *does* hide relationships. You should perform a "first pass" deduplication of obvious, locally-related code *before* you split the file to prevent creating redundant new files. But major architectural deduplication usually requires the structural clarity that only comes *after* the split.

---

## The WET Principle vs. DRY

There is absolutely a "WET" principle, and it is a critical counter-balance to DRY (Don't Repeat Yourself). 

**WET** stands for **"Write Everything Twice"** (or sometimes jokingly "We Enjoy Typing" or "Waste Everyone's Time").

### The Core Philosophy
The WET principle is championed most famously by software engineer Sandi Metz, who coined the rule:
> *"Duplication is far cheaper than the wrong abstraction."*

While DRY aims to eliminate redundancy to make global changes easier, strict adherence to DRY often leads to **Premature Abstraction**. Developers see two blocks of code that *look* similar and immediately merge them into a single function. But if those two blocks actually represent different *business domains*, they will evolve differently. Suddenly, that single "DRY" function requires 5 different boolean flags to handle the divergent use cases, becoming a rigid, unreadable mess.

### The "Rule of Three" Compromise
The modern consensus bridges the gap using the "Rule of Three":
1. **Write it once:** Just get it working.
2. **Write it twice (WET):** If you need it again, copy-paste it. Accept the duplication. This keeps the two components decoupled and easy to read.
3. **Refactor (DRY):** If you need it a *third* time, a true pattern has emerged. Now it is safe to extract it into a shared, DRY abstraction.

### When to stay WET in MacAmp
If you are decomposing your 700-line files and you see two UI components that look similar but serve totally different contexts (e.g., a "Next Track" button vs. a "Scroll Forward" button), **stay WET**. Leave them duplicated in their respective files. Only DRY them into a `SharedWinampButton` if a third use case appears or if maintaining the duplication becomes actively painful.