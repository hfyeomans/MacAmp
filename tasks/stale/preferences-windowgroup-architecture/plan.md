# Plan

1. Summarize why the current architecture diverges from SwiftUI’s recommended scene-driven model by referencing how `MacAmpApp` instantiates `WindowCoordinator` and where SwiftUI scenes are (and are not) used. Tie this to Question 1 and 2.
2. Analyze the `.defaultLaunchBehavior(.suppressed)` mitigation with respect to how SwiftUI chooses an initial window, and document whether suppression is safe along with its tradeoffs (Question 3).
3. Evaluate risks in state restoration, window management, lifecycle, and memory that stem from bypassing SwiftUI scenes, pointing to the bespoke persistence systems already present (Question 4).
4. Suggest alternative architectural patterns or incremental improvements (e.g., providing at least one SwiftUI-managed scene, using `NSWindowSceneRepresentable`, or bridging `NSWindow` hosting) and provide an overall architecture rating with concrete recommendations (Question 5).
