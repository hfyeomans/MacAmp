# Oracle Prompt: VIDEO Window Resize Jitter & Left Gap

Copy this entire prompt to use with Oracle in another window:

---

@MacAmpApp/Views/Windows/VideoWindowChromeView.swift @MacAmpApp/Views/WinampVideoWindow.swift @MacAmpApp/Models/VideoWindowSizeState.swift @MacAmpApp/Models/Size2D.swift @MacAmpApp/ViewModels/WindowCoordinator.swift @MacAmpApp/Views/Components/SimpleSpriteImage.swift

CRITICAL VIDEO WINDOW RESIZE ISSUES:

**ISSUE 1: Severe Jitter During Drag Resize**

USER INSIGHT: "The snap to 25x29 segments is forcing the jittering as it tries to snap up from a previous segment and size."

Symptom: Incredible jitter when dragging resize handle. Every segment boundary crossing causes visible jitter as SwiftUI re-renders entire complex chrome.

What Works: 1x/2x buttons resize instantly with zero jitter
What's Broken: Drag resize unusably jittery

**ISSUE 2: Blank Gap on Left Edge**

Screenshot shows persistent blank/gap section on left edge at all sizes. Chrome should be flush with window edge at x=0.

---

**CURRENT IMPLEMENTATION:**

Drag gesture updates sizeState.size on every segment boundary:
- Triggers full VideoWindowChromeView.body re-evaluation
- All @ViewBuilder functions re-execute (titlebar, borders, bottom bar)
- All computed properties recalculate
- All ForEach loops re-render sprites
- All SimpleSpriteImage lookups happen
- Result: Expensive layout recalculation = jitter

NSWindow sync only on drag end (not during drag)
- Buttons work smoothly
- Drag is jittery

---

**QUESTIONS:**

1. Should we STOP updating size during drag entirely?
   - Show visual preview only (overlay/outline)?
   - Commit size only on drag end?
   - How to show quantized snapping visually without re-rendering chrome?

2. Is SwiftUI body re-evaluation the jitter source?
   - Every segment cross = full chrome rebuild
   - Can we batch/throttle size updates to 60fps?
   - Use withAnimation(.none) or transaction?

3. Left gap - fractional coordinates or padding?
   - NSWindow.frame.origin fractional?
   - NSHostingView adding insets?
   - ZStack alignment issue?

4. Should we use Canvas for chrome during drag?
   - Pre-render chrome at current size
   - During drag: only update Canvas frame (cheap)
   - After drag: rebuild actual chrome components?

5. What's webamp's actual secret?
   - CSS updates don't trigger layout recalc?
   - React batching different from SwiftUI?
   - Fundamental difference in rendering model?

---

**FILES TO ANALYZE:**
@MacAmpApp/Views/Windows/VideoWindowChromeView.swift
@MacAmpApp/Views/WinampVideoWindow.swift
@MacAmpApp/Models/VideoWindowSizeState.swift
@MacAmpApp/ViewModels/WindowCoordinator.swift

Provide production-ready solution for smooth quantized resize in SwiftUI with sprite-based chrome.
