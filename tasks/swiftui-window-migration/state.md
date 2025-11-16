# State: SwiftUI Window Migration Task

**Last Updated:** 2025-11-16
**Status:** ✅ DECISION MADE - Do NOT migrate

---

## Final Decision: STAY WITH NSWINDOW ARCHITECTURE

**Oracle Multi-Turn Consultation Result (November 16, 2025):**

The Oracle, when presented with the full historical context from the magnetic-window-docking task, **completely reversed** its earlier recommendation:

> "You're absolutely right to call out the contradiction. The later comment that floated 'use SwiftUI Window scenes' was my mistake—not a reflection of new APIs. The earlier warning stands."

**Key Findings:**
- ❌ macOS 15/26 did NOT fix WindowGroup singleton problem
- ❌ WindowGroups still instantiate lazily (no singleton guarantee)
- ❌ SwiftUI-managed windows don't expose NSWindow early enough for WindowSnapManager
- ❌ WindowGroups auto-destroy on close (can't intercept for hide behavior)
- ❌ Migration would waste 4-6 weeks chasing parity with no benefit

**Oracle's Final Recommendation:**
> "Stay with the dedicated NSWindowController stack. It already satisfies magnetic docking, singleton enforcement, custom close handling, and menu coherence. There's no credible upside to migrating now, and it would likely jeopardize magnetic docking."

---

## Completed

- ✅ Oracle architectural assessment (current) - Initial recommendation (OVERSIGHT)
- ✅ Historical context research - Found magnetic docking task with 3 Oracle reviews
- ✅ Identified conflicting Oracle advice
- ✅ Re-consulted Oracle with FULL historical context
- ✅ Oracle acknowledged oversight and reversed recommendation
- ✅ Applied placeholder WindowGroup fix for v0.8.9 release (CORRECT pattern)
- ✅ Documented comprehensive decision rationale in research.md
- ✅ **DECISION: Keep NSWindowController architecture**

---

## Architecture Validation

**Current architecture is CORRECT:**
- NSWindowController for main windows → ✅ Singleton guarantee
- WindowCoordinator orchestration → ✅ Appropriate for 5-window management
- WindowSnapManager with delegate multiplexing → ✅ Required for magnetic docking
- Placeholder WindowGroup for SwiftUI App lifecycle → ✅ Necessary pattern
- SwiftUI views inside NSWindows → ✅ Modern rendering with AppKit control

**This is NOT technical debt** - it's the recommended hybrid pattern for apps requiring:
- Singleton windows
- NSWindow delegate control
- Close-to-hide behavior
- Magnetic window docking/snapping
- Custom window chrome

---

## Resolved Questions

1. ✅ **WindowGroup Singleton** - NOT fixed in macOS 15/26
2. ✅ **WindowSnapManager Integration** - ONLY works with direct NSWindow ownership
3. ✅ **Delegate Access** - SwiftUI Windows don't expose NSWindow early enough
4. ✅ **Close-to-Hide** - WindowGroups auto-destroy, no intercept hook
5. ✅ **Menu Sync** - WindowGroup would relaunch scenes (duplicate windows)

---

## Technical Debt Assessment: REVISED

**Previous (uninformed):** 6/10 - "architectural debt"
**Current (informed):** 8/10 - **correct architecture for requirements**

What was perceived as "debt":
- Placeholder WindowGroup → **NECESSARY** pattern for hybrid apps
- Manual NSWindow management → **REQUIRED** for magnetic docking
- WindowCoordinator singleton → **APPROPRIATE** for orchestrating 5 windows
- No SwiftUI-native windows → **CORRECT** given WindowGroup limitations

---

## Action Items

1. ✅ **Keep** current NSWindow + WindowCoordinator architecture
2. ✅ **Keep** placeholder WindowGroup for SwiftUI App lifecycle
3. ✅ **Keep** .defaultLaunchBehavior(.suppressed) and .restorationBehavior(.disabled)
4. ❌ **Do NOT** migrate to SwiftUI Windows (wastes 4-6 weeks, risks magnetic docking)
5. ❌ **Do NOT** attempt to use WindowGroup for main windows
6. ✅ **Document** this decision in BUILDING_RETRO_MACOS_APPS_SKILL.md

---

## Future Considerations

**Only reconsider if Apple ships:**
- Explicit singleton window APIs for WindowGroup
- NSWindow delegate hooks from SwiftUI Window scenes
- Close-to-hide behavior modifiers
- Early NSWindow access from SwiftUI Window lifecycle

**Monitor WWDC 2025/2026** for:
- "Single Instance Window" scene type
- WindowSceneDelegate improvements
- Custom window lifecycle hooks

Until then, the NSWindowController + WindowCoordinator pattern remains the correct approach for MacAmp's requirements.

---

## Task Status: CLOSED

**Result:** Architecture validated, no migration needed
**Outcome:** Oracle oversight corrected, NSWindow pattern confirmed as correct
**Technical Debt:** None identified (architecture is appropriate for requirements)
**Next Steps:** Document pattern in skill guide for future retro macOS apps
