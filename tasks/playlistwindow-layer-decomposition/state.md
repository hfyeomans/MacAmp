# State: WinampPlaylistWindow Layer Decomposition

> **Purpose:** Tracks the current state of the task including progress, blockers, and decisions.

---

## Current Status: COMPLETE

## Origin

Oracle architectural audit (gpt-5.3-codex, xhigh, 2026-02-21) of commit 5f2cef2 on branch `fix/internet-radio-n1-n6` confirmed that the WinampPlaylistWindow lint cleanup repeated the same cross-file extension anti-pattern flagged for WinampMainWindow.

## Progress

- [x] Architectural debt identified by Oracle audit
- [x] Research synthesized from Oracle + Gemini findings
- [x] Plan written (4-phase: scaffolding, extract, wire, verify)
- [x] Todo checklist created
- [x] User approval
- [x] Phase 1: Scaffolding (PlaylistWindowInteractionState + PlaylistMenuPresenter)
- [x] Phase 2: Extract child view structs (5 views)
- [x] Phase 3: Wire root composer, restore private access, delete extension
- [x] Phase 4: Final verification (clean build + TSan)

## Key Decisions

1. **Separate task** from mainwindow-layer-decomposition — different window concerns (playlist menus, selection, scroll/resize, AppKit menu bridge)
2. **Same architectural pattern** — @Observable interaction state + child view structs
3. **PlaylistWindowActions.swift kept** — proper class extraction, not extension debt
4. **PlaylistWindowActions singleton debt deferred** — shared selectedIndices sync can be addressed separately
5. **Background chrome kept in root** — `buildCompleteBackground()` is tightly coupled to sizeState with 90+ lines of sprite tiling; extracting it would add parameter passing overhead without clarity benefit
6. **menuDelegate kept as @State in root** — still needed as `NSMenuDelegate` bridge; passed to `PlaylistMenuPresenter` via init

## Files Changed

| File | Before | After |
|------|--------|-------|
| `WinampPlaylistWindow.swift` | ~530 lines, 6 widened properties | 230 lines, all private |
| `WinampPlaylistWindow+Menus.swift` | ~264 lines extension | DELETED |
| `PlaylistWindowActions.swift` | ~237 lines (good) | Kept as-is |
| `PlaylistWindow/PlaylistWindowInteractionState.swift` | — | 47 lines (new) |
| `PlaylistWindow/PlaylistMenuPresenter.swift` | — | 197 lines (new) |
| `PlaylistWindow/PlaylistTrackListView.swift` | — | 84 lines (new) |
| `PlaylistWindow/PlaylistBottomControlsView.swift` | — | 120 lines (new) |
| `PlaylistWindow/PlaylistShadeView.swift` | — | 42 lines (new) |
| `PlaylistWindow/PlaylistResizeHandle.swift` | — | 65 lines (new) |
| `PlaylistWindow/PlaylistTitleBarButtons.swift` | — | 33 lines (new) |
| `MacAmpApp.xcodeproj/project.pbxproj` | — | Updated: removed extension, added PlaylistWindow group |

## Verification

- Clean build with Thread Sanitizer: PASSED
- Zero compilation errors
- Zero playlist-related warnings
- All @State/@Environment properties private
- No widened access modifiers (only `body` is non-private)
- Oracle review (gpt-5.3-codex, xhigh): 3 low-severity findings, all fixed
  - Removed unused PlaybackCoordinator environment from root
  - Tightened interaction state access control (private(set))
  - Added [weak self] capture in keyboard monitor closure
- Oracle completeness check: no dropped behavior

## Commits

1. `47b5d76` - Phase 1: Add PlaylistWindowInteractionState and PlaylistMenuPresenter
2. `f955a99` - Phase 2: Extract 5 child view structs
3. `cf53dfd` - Phase 3: Wire child views, delete extension, update Xcode project
4. `0ad1c9d` - docs: Update task files to reflect completed decomposition
5. `47de639` - refactor: Address Oracle review findings

## Blockers

None. Task complete.

## Sibling Task

`tasks/mainwindow-layer-decomposition/` — same architectural pattern, can share learnings.
