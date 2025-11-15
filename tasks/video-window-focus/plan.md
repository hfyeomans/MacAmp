# Plan: Window Focus Tracking Recommendations

1. **Map requirement to layers**  
   - Use research on the three-layer rule (`docs/MACAMP_ARCHITECTURE_GUIDE.md`) to argue why focus detection belongs in the bridge, not directly in `VideoWindowChromeView`.

2. **Identify reusable infrastructure**  
   - Reference `WindowDelegateMultiplexer` and the delegate slots that `WindowCoordinator` already seeds so we can add a focus-specific delegate without touching NotificationCenter in views.

3. **Propose the concrete pattern**  
   - Describe a Swift 6–friendly `@Observable @MainActor` state model (e.g., `WindowFocusState`) that publishes `{main, eq, playlist, video, milkdrop}` focus booleans.
   - Show how this model is injected via `.environment()` so views just bind to `@Environment(WindowFocusState.self)`.

4. **Explain data flow**  
   - Document how `WindowCoordinator` (Bridge) wires `windowDidBecomeKey` / `windowDidResignKey` events into the focus state and how Presentation reacts by swapping sprites.

5. **Cover alternatives / anti-patterns**  
   - Answer the user’s specific questions (AppSettings vs WindowCoordinator, Swift 6 compliance, three-layer placement, precedent from other windows) with citations back to research files.

6. **Deliver architecture review**  
   - Summarize the recommended approach and enumerate next steps (implement delegate, create focus state object, inject into views).
