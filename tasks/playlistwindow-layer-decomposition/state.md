# State: WinampPlaylistWindow Layer Decomposition

> **Purpose:** Tracks the current state of the task including progress, blockers, and decisions.

---

## Current Status: PLANNED — Research complete, awaiting implementation approval

## Origin

Oracle architectural audit (gpt-5.3-codex, xhigh, 2026-02-21) of commit 5f2cef2 on branch `fix/internet-radio-n1-n6` confirmed that the WinampPlaylistWindow lint cleanup repeated the same cross-file extension anti-pattern flagged for WinampMainWindow.

## Progress

- [x] Architectural debt identified by Oracle audit
- [x] Research synthesized from Oracle + Gemini findings
- [x] Plan written (4-phase: scaffolding, extract, wire, verify)
- [x] Todo checklist created
- [ ] User approval
- [ ] Implementation
- [ ] Verification

## Key Decisions

1. **Separate task** from mainwindow-layer-decomposition — different window concerns (playlist menus, selection, scroll/resize, AppKit menu bridge)
2. **Same architectural pattern** — @Observable interaction state + child view structs
3. **PlaylistWindowActions.swift kept** — proper class extraction, not extension debt
4. **PlaylistWindowActions singleton debt deferred** — shared selectedIndices sync can be addressed separately

## Files Affected

| File | Current State | Target |
|------|--------------|--------|
| `WinampPlaylistWindow.swift` | ~516 lines, 6 widened properties | ~120 lines, all private |
| `WinampPlaylistWindow+Menus.swift` | ~200 lines extension | DELETED |
| `PlaylistWindowActions.swift` | ~240 lines (good) | Kept as-is |
| New child views | — | 5-6 new files |
| `PlaylistWindowInteractionState.swift` | — | New @Observable state |
| `PlaylistMenuPresenter.swift` | — | New menu builder |

## Blockers

None. Can be implemented independently.

## Sibling Task

`tasks/mainwindow-layer-decomposition/` — same architectural pattern, can share learnings. Implementation order doesn't matter; either can go first.
