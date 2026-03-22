# State

**Last Updated:** 2025-11-16

## Completed
- ✅ Research captured key architectural traits of `MacAmpApp` and `WindowCoordinator`
- ✅ Applied `.defaultLaunchBehavior(.suppressed)` fix to MacAmpApp.swift:69
- ✅ Oracle (Codex) architectural review completed - Rating: 3/5
- ✅ Identified root cause: No SwiftUI Windows, only NSWindows
- ✅ Fix verified safe for production use in v0.8.9 release
- ✅ Notarized and released v0.8.9 with this fix

## Technical Debt Status
**Severity:** Medium (works but fights SwiftUI patterns)
**Impact:**
- No automatic state restoration for main windows
- No ScenePhase awareness for main UI
- Manual window lifecycle management required
- Potential memory leaks from long-lived observers

## Next Steps (Prioritized)
1. **Document the workaround** - Update CLAUDE.md or architecture docs about this pattern
2. **Prototype SwiftUI Window wrapper** - Test if NSViewControllerRepresentable can host existing controllers
3. **Add main SwiftUI Window scene** - At least one Window scene to satisfy SwiftUI architecture
4. **Migrate to scene-based lifecycle** - Eventually use SwiftUI's automatic state restoration

## Blockers
- Magnetic window docking requires direct NSWindow access
- 5-window architecture (Main, EQ, Playlist, Video, Milkdrop) is complex
- Custom focus/persistence logic already working well

## Decision Point
The current fix is **acceptable for production** but should be addressed in a future release to align with SwiftUI best practices and avoid potential lifecycle/memory issues.
