# Code Design Principles: DRY, WET, and AHA

Understanding when to duplicate code and when to abstract it is one of the most critical skills in software engineering. The industry consensus has shifted away from dogmatic adherence to DRY towards a more pragmatic approach championed by leading engineers like Sandi Metz, Dan Abramov, and Kent C. Dodds.

---

## 1. DRY: Don't Repeat Yourself
**The Principle:** Every piece of knowledge must have a single, unambiguous, authoritative representation within a system.
**The Goal:** Maintainability. If a business rule changes, you only have to update it in one place.

**The Pitfall: "Premature Abstraction"**
When applied too strictly, DRY leads developers to extract code that *looks* similar but actually serves different business domains. When those domains inevitably evolve in different directions, developers are forced to add `if/else` flags to the shared abstraction to handle the divergence. 
*   *Result:* The code becomes a fragile, unreadable "condition-laden procedure" (spaghetti code).

---

## 2. WET: Write Everything Twice (or "We Enjoy Typing")
**The Principle:** A counter-movement to strict DRY. It suggests that duplication is a temporary tool for discovery.

**The Philosophy of Sandi Metz**
Sandi Metz famously stated: > *"Duplication is far cheaper than the wrong abstraction."*

Her argument is that developers are psychologically resistant to deleting complex abstractions. If you create a bad abstraction (DRYing too early), the codebase will suffer for years. If you leave code duplicated (WET), it is very easy to refactor it later once the true pattern emerges. If you find yourself trapped in a wrong abstraction, her advice is: *"The fastest way forward is back"* (inline the code, re-introduce the duplication, and delete the abstraction).

**Dan Abramov and "The WET Codebase"**
Dan Abramov (co-creator of Redux) argues that strictly following DRY often leads to "accidental coupling." When you extract a helper function for two different UI components just because they happen to use the same margin or color today, you tightly couple them. When one component needs to change tomorrow, you break the other. Abramov advocates for "wasting time" by writing things out explicitly to preserve decoupling.

---

## 3. AHA: Avoid Hasty Abstractions
**The Principle:** Coined by Kent C. Dodds (influenced by Cher Scarlett and Sandi Metz), AHA is the modern middle ground. It states: **Optimize for change first, not DRYness.**

**Core Tenets of AHA:**
1.  **Wait for Evidence:** Don't abstract just because you see two similar pieces of code. Wait until you understand *how* they are going to change.
2.  **The Rule of Three:** A practical heuristic. You are allowed to write the exact same logic twice (WET). But the *third* time you need it, a true pattern has been proven. That is when you refactor into a shared abstraction (DRY).

---

## Summary: When to use which?

### Use WET (Duplication) When:
*   **In Discovery:** You are building a new feature and don't yet know how the requirements will evolve.
*   **Accidental Similarity:** Two UI components currently look identical, but belong to completely different features (e.g., a "Submit Payment" button and a "Delete Account" button). Keep them separate so they can change safely.
*   **Tests:** Tests should be "DAMP" (Descriptive And Mock-free Phrases). Duplicating setup code in tests is usually better than hiding it in complex helpers, because a failing test needs to be immediately readable from top to bottom.

### Use DRY (Abstraction) When:
*   **The Rule of Three:** You have written the exact same block of code three times in three different places.
*   **Core Business Knowledge:** Math formulas, tax calculations, or domain constants (like API URLs). If the tax rate changes, it must change globally.
*   **Design Systems:** Reusable, stateless UI primitives (like `WinampSlider` or `WinampFont`) that are guaranteed to be uniform across the entire app.