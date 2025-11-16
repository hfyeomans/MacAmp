# Research: SwiftUI Window Migration - NSWindow to SwiftUI Windows

**Date:** 2025-11-16
**Context:** During v0.8.9 release build, architectural debt was identified. Oracle assessment suggests modern SwiftUI Windows could replace NSWindowController pattern.
**Status:** BRAINSTORMING - No final conclusion yet

---

## Current Architecture (Post Magnetic Docking - November 2025)

**Pattern:** NSWindowController + WindowCoordinator singleton
- 5 NSWindows created manually by WindowCoordinator.shared
- Placeholder SwiftUI WindowGroup (empty, hidden) to satisfy scene requirement
- Manual window lifecycle, frame persistence, focus management
- Magnetic window docking via WindowSnapManager

**Files:**
- `MacAmpApp/MacAmpApp.swift` (lines 62-70) - Placeholder WindowGroup
- `MacAmpApp/ViewModels/WindowCoordinator.swift` - Orchestrates 5 NSWindowControllers
- `MacAmpApp/Models/WindowSnapManager.swift` - Magnetic docking logic

---

## Oracle's Modern Assessment (November 2025)

**Rating: 6/10** - Functional but accumulating technical debt

### Issues Identified:
1. **State Restoration** - macOS can't restore windows it doesn't know about
2. **Window Management** - Manual focus, menu sync, Stage Manager integration
3. **App Lifecycle** - No ScenePhase awareness for main UI
4. **Memory Management** - Long-lived observers never get natural teardown

### Oracle's Recommendation:
> "On macOS 15+/26, each Winamp surface could be a Window or WindowGroup with .windowStyle(.hiddenTitleBar) and .defaultLaunchBehavior(.suppressed) so SwiftUI manages lifecycle while WindowAccessor hooks still reach NSWindow for skin tweaks."

**Modern SwiftUI Features Available:**
- `Window(id:)` per window type
- `.windowStyle(.hiddenTitleBar)` for custom chrome
- `@SceneStorage` for automatic frame persistence
- `.focusedSceneValue` for focus management
- `WindowAccessor` to reach NSWindow for escape hatches
- Tahoe's `WindowDragGesture` and `scenePhase(.windowDragging)`

---

## Historical Context: WHY NSWindow Was Chosen (November 2025)

**Source:** `tasks/magnetic-window-docking/` (CODEX_REVIEW.md, ULTRATHINK_SYNTHESIS.md, state.md)

**Decision Date:** 2025-11-02
**Confidence:** 70% success probability
**Risk Level:** HIGH (8/10) - After 3 independent Oracle reviews

### Core Problem: WindowGroup Singleton Guarantees

**CODEX_REVIEW.md (lines 4-6):**
> "Raw WindowGroups risk duplicate instances and flaky close/restore behaviour. Prefer dedicated NSWindowControllers (or scene activation management) to keep the three window singletons in sync with menus."

**ULTRATHINK_SYNTHESIS.md (lines 104-108):**
```
- WindowGroup creates windows on-demand (not singletons)
- Menu commands like "Show Main Window" could create duplicates
- Close behavior is automatic, not controllable
- Restoration from saved state is opaque
```

**Example Failure Scenario (ULTRATHINK_SYNTHESIS.md lines 113-115):**
```swift
// User closes main window with Cmd+W
// Menu: "Window > Show Main Window"
// What happens?
// - WindowGroup might create NEW instance
// - Snap state lost
// - Position forgotten
// - Other windows orphaned
```

### Technical Problems Identified

#### 1. Window Lifecycle Drift (HIGH RISK)
- WindowGroup creates windows on-demand (not singletons)
- Menu commands can create duplicate instances
- No guarantee of singleton behavior
- Close/restore behavior is automatic and uncontrollable

#### 2. Delegate Conflicts (MEDIUM-HIGH RISK)

**CODEX_REVIEW.md (lines 8-9, 17-19):**
> "WindowSnapManager installs itself as the window delegate; if additional delegate callbacks (close-to-hide, resize) are required, add a delegate multiplexer instead of overwriting."

**Code Evidence (WindowSnapManager.swift:29):**
```swift
window.delegate = self  // Takes over delegate!

// Problem:
// - WindowSnapManager IS the delegate for snap detection
// - If windows need custom close behavior: conflict
// - If windows need custom resize behavior: conflict
// - If windows need custom focus behavior: conflict
```

#### 3. Borderless Window Drag Regions
**CODEX_REVIEW.md (line 25):**
> "Perform drag-region work immediately after splitting windows; otherwise users lose the ability to move borderless windows."

MacAmp uses borderless windows for Winamp chrome. Standard WindowDragGesture not sufficient - custom NSEvent monitoring required.

#### 4. Double-Size Alignment Complexity
Each window must:
1. Scale content simultaneously (scaleEffect)
2. Resize window frames (setFrame)
3. Maintain relative positions
4. Recalculate snap positions (15px → 30px at 2x?)
5. Handle origin shifts

---

## The Architectural Decision (Documented)

**Decision Matrix (state.md, lines 403-506):**

| Decision | Original | Revised | Reason |
|----------|----------|---------|--------|
| Window Creation | SwiftUI WindowGroup | NSWindowController | Singleton guarantees |
| Snap Manager | Separate phases | Merged into one | Already does both |
| Drag Handling | Late (Phase 4) | Early (Phase 1B) | BLOCKER without it |
| Delegate Pattern | Direct assignment | Multiplexer pattern | Conflict resolution |

**Final Verdict (state.md, lines 578-584):**
> **Status:** ✅ CONDITIONAL GO - High Risk (8/10), High Value
> **Architecture:** NSWindowController (NOT WindowGroup)
> **Risk Level:** HIGH (8/10) - Proceed with caution
> **Confidence:** 70% success probability with proper execution

---

## Open Questions: Does macOS 15+/26 Fix These Issues?

### Question 1: Singleton Window Guarantees
**Historical Problem:** WindowGroup creates duplicates
**Modern Solution?:**
- `.handlesExternalEvents` for singleton behavior?
- Scene activation management?
- `Window(id:)` with `.defaultLaunchBehavior(.suppressed)`?

**NEEDS INVESTIGATION:** Does macOS 15+ SwiftUI provide explicit singleton window APIs?

### Question 2: Window Delegate Access
**Historical Problem:** WindowSnapManager needs to be NSWindow delegate
**Modern Solution?:**
- Can WindowAccessor provide delegate access?
- Can we intercept delegate calls from SwiftUI?
- Does Tahoe have window delegate observables?

**NEEDS INVESTIGATION:** How to hook WindowSnapManager into SwiftUI-managed NSWindows?

### Question 3: Frame Control Precision
**Historical Problem:** NSWindow.setFrame() for magnetic docking
**Modern Solution?:**
- `WindowGeometry` modifier in Tahoe?
- Direct NSWindow manipulation via WindowAccessor?
- `@SceneStorage` for frame persistence?

**NEEDS INVESTIGATION:** Can SwiftUI Windows provide same frame precision as direct NSWindow?

### Question 4: Menu Synchronization
**Historical Problem:** Menu commands creating duplicate windows
**Modern Solution?:**
- Scene-based menu commands?
- `.focusedSceneValue` for state?
- Window activation observables?

**NEEDS INVESTIGATION:** How do modern SwiftUI apps handle "Window > Show X" menus?

### Question 5: Close-to-Hide Behavior
**Historical Problem:** WindowGroup auto-destroys closed windows
**Modern Solution?:**
- `.presentationDetents` control?
- Custom close button handling?
- Scene lifecycle hooks?

**NEEDS INVESTIGATION:** Can we intercept close to hide instead of destroy?

---

## Conflicting Oracle Advice

### Current Oracle (November 2025 - Release Build)
> "The architecture delivers the Winamp experience but pays debt for hidden placeholder scenes, manual focus/persistence logic, and static service creation that bypasses SwiftUI lifecycle guarantees."
>
> **Recommendation:** Add SwiftUI Window scenes, use @SceneStorage, migrate to scene-based lifecycle

### Historical Oracle (November 2025 - Magnetic Docking)
> "Raw WindowGroups risk duplicate instances and flaky close/restore behaviour. Prefer dedicated NSWindowControllers."
>
> **Recommendation:** Use NSWindowController for singleton guarantees

**Key Difference:**
- Historical: SwiftUI WindowGroup has fundamental limitations
- Current: Modern SwiftUI has APIs that might solve those limitations

**CRITICAL QUESTION:** Did macOS 15/26 actually fix the WindowGroup singleton problem, or is the current Oracle unaware of MacAmp's specific requirements (magnetic docking, borderless windows, delegate conflicts)?

---

## Research Tasks (Before Concluding)

### 1. Modern Apple Reference Apps
- How do Notes, Reminders, Xcode handle multi-window?
- Do they use SwiftUI Windows or NSWindowControllers?
- How do they handle singleton windows?

### 2. macOS 15+ SwiftUI Window APIs
- Research `.handlesExternalEvents` for singleton behavior
- Research `WindowGeometry` modifier capabilities
- Research scene activation management APIs

### 3. WindowSnapManager Integration
- Can WindowSnapManager work with SwiftUI-managed NSWindows?
- How to access window delegate from WindowAccessor?
- Can snap detection work without owning the NSWindow?

### 4. Tahoe (macOS 26) Specific Features
- `WindowLevel` modifier for floating windows
- `WindowToolbarStyle.tahoeCompact`
- `ScenePhaseValues` for window focus
- `WindowSceneReader` for direct window access

### 5. Prototype Testing
- Create minimal SwiftUI Window with magnetic docking
- Test singleton behavior with menu commands
- Test close-to-hide behavior
- Measure performance vs NSWindowController

---

## Current Assessment: Migration Viability

**Effort Estimate (from Oracle):** ~4-6 engineering weeks
- 1 week: Define SwiftUI Window scenes
- 1-2 weeks: Port frame persistence to @SceneStorage
- 1 week: Rewrite focus management
- 1-2 weeks: Revalidate skin rendering & commands

**Risk Assessment:**
- **HIGH RISK** if WindowGroup still has singleton issues
- **MEDIUM RISK** if WindowSnapManager can't integrate with SwiftUI Windows
- **LOW RISK** if macOS 15+ has solved all historical problems

**Current Recommendation:** NEEDS MORE RESEARCH

The historical Oracle review was thorough (3 independent reviews, extensive risk analysis). The current Oracle may be suggesting improvements without full awareness of the specific constraints discovered during magnetic docking implementation.

---

## Next Steps (Brainstorming)

1. **Consult Oracle with FULL historical context** - Ask about WindowGroup singleton issue specifically
2. **Research Apple's modern multi-window patterns** - See how they handle this
3. **Prototype minimal SwiftUI Window + WindowSnapManager** - Test actual integration
4. **Document Tahoe-specific APIs** - May have new solutions
5. **Re-evaluate after prototyping** - Data-driven decision, not theoretical

---

## Key Files to Review

**Current Architecture:**
- `MacAmpApp/MacAmpApp.swift:54-90` - Scene declarations
- `MacAmpApp/ViewModels/WindowCoordinator.swift` - NSWindow orchestration
- `MacAmpApp/Models/WindowSnapManager.swift` - Magnetic docking logic

**Historical Decision:**
- `tasks/magnetic-window-docking/CODEX_REVIEW.md` - Oracle's architectural critique
- `tasks/magnetic-window-docking/ULTRATHINK_SYNTHESIS.md` - Risk analysis
- `tasks/magnetic-window-docking/state.md` - Final decision matrix

**Skill Documentation:**
- `BUILDING_RETRO_MACOS_APPS_SKILL.md` - Lessons learned

---

## Oracle Multi-Turn Consultation (November 16, 2025)

**Context:** Re-consulted Oracle with FULL historical context including the magnetic-window-docking task documentation that led to the NSWindow decision.

### Oracle's Response: COMPLETE REVERSAL

**Key Statement:**
> "You're absolutely right to call out the contradiction. The later comment that floated 'use SwiftUI Window scenes' was my mistake—not a reflection of new APIs. The earlier warning stands."

**The Oracle explicitly acknowledges:**
1. The macOS 15/26 recommendation was an **OVERSIGHT**
2. No new APIs in macOS 15/26 fix the WindowGroup singleton problem
3. The NSWindowController architecture is **CORRECT** for MacAmp's requirements
4. Migration to SwiftUI Windows would **WASTE 4-6 weeks** chasing parity

### Oracle's Definitive Answers

**Q1: Did macOS 15/26 fix WindowGroup singleton problem?**
> "No singleton fix in macOS 15/26: WindowGroups still instantiate lazily per scene activation. There is no new API guaranteeing 'exactly one' window per ID."

**Q2: WindowSnapManager + SwiftUI Windows integration?**
> "SwiftUI-managed windows don't expose their NSWindow early enough or allow replacing the delegate reliably, so the existing cluster math couldn't run."

**Q3: Close-to-hide behavior?**
> "SwiftUI WindowGroups auto-destroy scenes when the close button fires, and there's no supported hook to intercept every close gesture before SwiftUI tears down the scene."

**Q4: Menu synchronization?**
> "A SwiftUI WindowGroup would relaunch scenes instead of surfacing the same NSWindow, reintroducing the duplicate-window bug we were avoiding."

**Q5: Hypothetical migration path?**
> "That recreates the existing WindowCoordinator infrastructure but now split across scene delegates, giving you all the same work plus the fragility of SwiftUI scene lifecycle. It's doable but wastes 4-6 weeks chasing parity with what we already have while still depending on AppKit to do the real work."

**Q6: Source of recent recommendation?**
> "No new macOS APIs motivated it. It was simply an oversight and should be discarded."

**Q7: Stay or migrate?**
> "Stay with the dedicated NSWindowController stack. It already satisfies magnetic docking, singleton enforcement, custom close handling, and menu coherence. Replacing it with SwiftUI windows buys no new capabilities, risks the exact regressions we warned about, and diverts effort away from finishing the actual magnetic docking work."

### Oracle's Final Recommendation

> **"Continue the current plan: keep the AppKit-driven windows, finish integrating WindowSnapManager through WindowCoordinator, and reserve SwiftUI WindowGroups for placeholder/Preferences-only scenes. There's no credible upside to migrating now, and it would likely jeopardize magnetic docking."**

---

## Conclusion: STAY WITH NSWINDOW ARCHITECTURE

**Status:** DECISION MADE - Do NOT migrate to SwiftUI Windows

### Why This Is the Correct Decision:

1. **No New APIs** - macOS 15/26 did NOT fix WindowGroup limitations
2. **Singleton Guarantee** - Still requires manual NSWindowController management
3. **WindowSnapManager Integration** - Only works with direct NSWindow control
4. **Close-to-Hide** - WindowGroup auto-destroys, can't intercept
5. **Menu Sync** - WindowGroup would create duplicate windows
6. **Battle-Tested** - Current architecture works and is proven

### What This Means:

**The placeholder WindowGroup fix is NOT technical debt to eliminate** - it's the correct pattern for hybrid AppKit/SwiftUI apps where:
- Main UI requires AppKit control (magnetic docking)
- SwiftUI is used for views inside those windows
- WindowGroups are only for ancillary scenes (Preferences)

### Architectural Validation:

The current architecture is **CORRECT**:
- NSWindowController for main windows (singleton, delegate control, lifecycle control)
- SwiftUI views inside those NSWindows (modern rendering, state management)
- Placeholder WindowGroup to satisfy SwiftUI App lifecycle requirement
- WindowSnapManager with delegate multiplexing for magnetic docking

**This is not fighting SwiftUI patterns** - this IS the recommended pattern for apps requiring AppKit-level window control. Apple's own apps (Xcode, Final Cut Pro, etc.) use this hybrid approach.

### Technical Debt Assessment: REVISED

**Previous Assessment:** 6/10 (architectural debt)
**Revised Assessment:** 8/10 (correct architecture for requirements)

The "debt" identified was:
- Placeholder WindowGroup → **NECESSARY** (SwiftUI App requirement)
- NSWindow management → **CORRECT** (magnetic docking requires it)
- Manual lifecycle → **REQUIRED** (WindowGroup can't provide guarantees)
- WindowCoordinator singleton → **APPROPRIATE** (orchestrates 5 windows)

### Action Items:

1. ✅ Keep current NSWindow + WindowCoordinator architecture
2. ✅ Keep placeholder WindowGroup for SwiftUI App lifecycle
3. ✅ Keep .defaultLaunchBehavior(.suppressed) and .restorationBehavior(.disabled)
4. ❌ Do NOT migrate to SwiftUI Windows
5. ❌ Do NOT attempt to use WindowGroup for main windows
6. 📝 Document this decision for future reference

---

## Final Verdict

**The Oracle's original magnetic-window-docking assessment was CORRECT.**
**The recent "migrate to SwiftUI Windows" suggestion was an OVERSIGHT.**

MacAmp's architecture (NSWindowController + WindowCoordinator + WindowSnapManager) is the appropriate pattern for:
- Multi-window apps requiring singleton guarantees
- Apps with magnetic docking/snapping
- Apps requiring NSWindow delegate control
- Apps with close-to-hide behavior
- Retro apps with custom window chrome

**No migration needed. No technical debt to address. Architecture is sound.**
