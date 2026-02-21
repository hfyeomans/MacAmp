# State: WinampMainWindow Layer Decomposition

> **Purpose:** Current status, decisions made, and blockers for this task.
> Updated as implementation progresses.

## Current Status

**Phase:** Pre-implementation (Research + Planning complete)
**Last Updated:** 2026-02-21

## Decisions Made

### D1: Architecture Pattern -- @Observable + Child View Structs

**Decision:** Use `@Observable` interaction state class + separate `View` structs (not extensions).
**Rationale:** Both Gemini and Oracle converged on this independently. Extensions do not create
recomposition boundaries. Separate view types do.
**Status:** Confirmed

### D2: Coords Extraction Strategy

**Decision:** Extract `Coords` to a top-level `WinampMainWindowLayout` enum in its own file.
**Alternatives considered:**
- (a) Pass coordinates as init params -- too verbose, 30+ constants
- (b) Keep nested, reference as `WinampMainWindow.Coords` -- couples children to parent type
- (c) Global enum in own file -- clean, no coupling (chosen)
**Status:** Confirmed

### D3: Timer Ownership

**Decision:** `scrollTimer` lifecycle managed by `WinampMainWindowInteractionState`. The `pauseBlinkTimer`
(Timer.publish) stays on the root view as `.onReceive` modifier, writing to interaction state.
**Rationale:** `Timer.publish` is a Combine publisher that SwiftUI manages via `.onReceive`. It belongs
on the view. The mutable `scrollTimer` (manual Timer) is state, so it belongs in the state class.
**Status:** Confirmed

### D4: Options Menu Isolation

**Decision:** Dedicated `MainWindowOptionsMenuPresenter` class, not part of interaction state.
**Rationale:** NSMenu is AppKit-specific bridging concern, not view interaction state. Keeping it
separate follows single-responsibility principle and keeps the interaction state class focused.
**Status:** Confirmed

### D5: @Environment Passthrough vs Init Injection

**Decision:** Child views declare their own `@Environment` properties for objects they need.
**Rationale:** SwiftUI automatically injects environment objects to all descendants. Passing via init
would be redundant and add boilerplate. The exception is the interaction state class, which is passed
explicitly since it is not in the environment.
**Status:** Confirmed

### D6: File Location

**Decision:** New `MacAmpApp/Views/MainWindow/` subdirectory.
**Rationale:** 10 files for one window is too many for a flat Views/ directory. Subdirectory groups
related files and matches the pattern that could be used for Playlist/EQ windows later.
**Status:** Confirmed

## Open Questions

None currently. All architectural questions resolved during research phase.

## Blockers

None currently.

## Dependencies

- No external dependencies
- No other in-flight tasks touching WinampMainWindow files
- Xcode project file will need directory reference update

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Pixel regression | Medium | High | Screenshot comparison before/after each phase |
| Timer lifecycle bug | Low | Medium | TSan enabled, manual test pause/scroll behavior |
| NSMenu deallocation | Low | High | Presenter holds strong reference (same as current pattern) |
| Xcode project breakage | Low | Low | Build after every file move/create |
| SwiftUI environment not reaching children | Low | Medium | Children are in view hierarchy, auto-inherits |

## Artifact Inventory

| Artifact | Status |
|----------|--------|
| research.md | Complete |
| plan.md | Complete |
| todo.md | Complete |
| state.md | Active (this file) |
| depreciated.md | Complete |
| placeholder.md | Complete (template ready) |
