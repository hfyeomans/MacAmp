# Plan: Window Architecture Assessment

## Objectives
Provide a comprehensive assessment that addresses the six question clusters from the user prompt:
1. Whether migrating from SwiftUI WindowGroups to manual NSWindow coordination was appropriate.
2. Current SwiftUI window capabilities on macOS 15+/26.x and whether they cover docking/focus scenarios.
3. Evaluation of the singleton `WindowCoordinator` pattern versus modern SwiftUI state management.
4. Technical debt scoring plus comparison to a greenfield SwiftUI-first approach and migration effort.
5. Long-term viability of the hybrid NSWindow + SwiftUI-hosted views pattern.
6. Actionable recommendations for both “stay AppKit” and “return to SwiftUI window” paths, highlighting Tahoe APIs to leverage.

## Approach
1. **Summarize Current Architecture**
   - Cite `MacAmpApp.swift` and `WindowCoordinator.swift` to describe the existing placeholder scene + manual NSWindow strategy, including docking, focus, persistence, and the five-window layout.
   - Reference `docs/MACAMP_ARCHITECTURE_GUIDE.md` for context on why the five-window system exists and for metrics demonstrating maturity.

2. **Analyze Modern SwiftUI Capabilities (macOS 15+/26.x)**
   - Document features such as multiple `WindowGroup`, `.windowStyle`, `.windowLevel`, `Window` scene APIs, `WindowAccessor`, `WindowDragGesture`, new Tahoe window APIs.
   - Compare these to MacAmp requirements (multi-window layout, docking, AppKit-level customization, hosting pixel-perfect sprite views).

3. **Evaluate Singleton and Lifecycle Patterns**
   - Assess `WindowCoordinator.shared` vs. SwiftUI scene management patterns (dependency injection, `@Environment`, `@Observable`).

4. **Technical Debt and Migration Effort**
   - Rate architecture 1-10 with justification, identify anti-patterns, and outline differences compared to a modern SwiftUI-only macOS 15+ app.
   - Estimate effort required to migrate to SwiftUI windows, referencing features that would need to be re-engineered.

5. **Hybrid Architecture Assessment & Recommendations**
   - Discuss pros/cons of staying AppKit-based vs. re-embracing SwiftUI windows, referencing modern Apple app practices.
   - Provide actionable steps for both scenarios, including Tahoe-specific APIs/features to adopt (e.g., `WindowSceneBuilder`, new window docking hooks, `Observation`-driven scenes).

6. **Deliverable**
   - Produce a written assessment (delivered via final response) structured with headings per question cluster, referencing specific files/lines where relevant.
   - Include recommendations, migration paths, and references to Apple's best practices/documentation from 2024-2025.
