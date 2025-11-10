# Magnetic Docking vs Video/Milkdrop Sequencing

**Date**: 2025-11-09  
**Author**: Codex agent  
**Context**: Oracle flagged `plan.md` as B- because it still embeds visualization views in `WinampMainWindow`. This memo evaluates sequencing options for magnetic docking vs Video/Milkdrop delivery.

---

## Option Comparison

| Option | Scope | Timeline (est.) | Technical Debt | UX Impact | Notes |
| --- | --- | --- | --- | --- | --- |
| **A. Video/Milkdrop first, no docking** | Build two new NSWindows (Video & Milkdrop) while leaving Main/EQ/Playlist inside unified window | 12 days (matches revised Oracle estimate in `ORACLE_FEEDBACK.md`) | Low for the new windows if we use `WindowGroup(id:)` + `WindowAccessor` from day one, but Main/EQ/Playlist still need future extraction | Inconsistent: 3 panes locked together, 2 float freely | Acceptable only if we document the temporary UX gap and ensure new windows already register with `WindowSnapManager` for future snapping |
| **B. Magnetic docking first** | Break Main/EQ/Playlist out into NSWindows and finish magnetic snapping, then add Video/Milkdrop | 18–22 days (10–12 for docking + 8–10 for V/M per user estimates) | Minimal once completed; Video/Milkdrop work happens on the final architecture | Cohesive once both phases ship, but users wait longer for the V button | Best if we must guarantee consistent UX before exposing new windows |
| **C. Combined implementation** | Extract Main/EQ/Playlist, finish magnetic docking, and add Video + Milkdrop in the same cycle | 15–20 days (shared infrastructure reduces duplicate effort) | Lowest overall because every window is built on the final architecture immediately | Cohesive: users see five independent, snapping windows in one release | Requires the biggest focused push but eliminates back-to-back refactors |

---

## Key Findings

1. `WinampMainWindow` is still a single SwiftUI scene that composes every pane inside one NSWindow (`MacAmpApp/Views/WinampMainWindow.swift:4-196`). Adding Video/Milkdrop as child views keeps us stuck in the NO-GO state Oracle highlighted.
2. `DockingController` today only tracks visibility and shade for in-window panes (`MacAmpApp/ViewModels/DockingController.swift:6-118`). It cannot be "extended" to multi-window docking without redesign because it assumes a single stacked coordinate system.
3. We already have a `WindowSnapManager` that performs true NSWindow magnetic snapping, but it only knows about `.main`, `.playlist`, `.equalizer` (`MacAmpApp/Utilities/WindowSnapManager.swift:4-136`). Extending its `WindowKind` enum and registration points is straightforward once each pane lives in its own `WindowGroup` scene.
4. `docs/MULTI_WINDOW_ARCHITECTURE.md` recommends dedicated `WindowGroup(id:)` scenes plus a `WindowStateStore` for persistence (`docs/MULTI_WINDOW_ARCHITECTURE.md:1-148`). That pattern gives us direct NSWindow handles (via `WindowAccessor`) while keeping the SwiftUI scene graph declarative.

---

## Recommendation

- **Primary**: Pursue **Option C**. Spin up `WindowGroup` scenes for Main, Playlist, Equalizer, Video, and Milkdrop together, wire them all through the shared `WindowStateStore`, and register each NSWindow with `WindowSnapManager`. This lets us implement docking rules once and keeps user-visible behavior consistent. Expect a focused 3-week sprint with a hardening/stabilization buffer.
- **Fallback**: If we must ship the V button sooner, Option A can be acceptable, but only if we:
  1. Implement Video/Milkdrop as independent `WindowGroup` scenes now.
  2. Register those NSWindows with an extended `WindowSnapManager` even if they temporarily float (we can disable snapping until more windows exist).
  3. Document the temporary UX mismatch and schedule the Main/EQ/Playlist extraction immediately afterward.

Given the emphasis on "do this right" and Oracle's NO-GO, shipping Video/Milkdrop without delivering true multi-window infrastructure should be treated as a last resort.

---

## Sequencing Implications

1. **Technical Debt**
   - Option A introduces UX debt, but not code debt if we build on the new window architecture from the start.
   - Options B/C retire both UX and architectural debt before users see the new feature.

2. **DockingController Strategy**
   - Keep the existing type for visibility/shade toggles, but introduce a new `WindowKind` enum that mirrors `WindowSnapManager`. The controller becomes a thin registry that maps pane state to actual NSWindow instances (`docs/MULTI_WINDOW_ARCHITECTURE.md:703-735`).
   - Magnetic behavior should migrate fully into `WindowSnapManager`, which already handles clusters/snapping for arbitrary windows. We just need to extend `WindowKind` and ensure every window registers on appear/disappear.

3. **Architectural Approach**
   - `WindowGroup(id:)` + `WindowAccessor` remains the preferred pattern. It keeps window lifecycle declarative and still lets us call AppKit APIs for snapping, placement, or chrome customization. NSWindowController should be reserved for legacy AppKit stacks; we do not need it here per the architecture guide.

4. **Risks**
   - **Option A**: inconsistent UX, additional QA runs after docking lands.
   - **Option B**: longer time-to-user value, more churn in the short term.
   - **Option C**: largest single push; requires tight coordination across window extraction, snapping, and the new visualization stack.

5. **Go / No-Go**
   - **Recommended GO** only after we commit to Option C (or B if capacity is constrained). Proceeding with Option A should be explicitly tagged as a temporary deviation with a follow-up docking milestone scheduled immediately.

