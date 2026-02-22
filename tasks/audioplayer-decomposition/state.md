# Task State: AudioPlayer.swift Decomposition

> **Description:** Tracks the current state of the AudioPlayer decomposition task including progress, blockers, and decisions.
> **Purpose:** Single source of truth for task status, updated as implementation progresses.

---

## Current Phase: RESEARCH & PLANNING COMPLETE

## Status: Ready for implementation. Research and plan reviewed. Awaiting approval to begin.

## Branch: TBD (suggested: `refactor/audioplayer-decomposition`)

## Context

- **Origin:** Code review of last 5 PRs (2026-02-18) flagged swiftlint suppressions in AudioPlayer.swift
- **Trigger:** PR #43 added `// swiftlint:disable file_length` and `type_body_length` suppressions
- **Pattern:** Follows WindowCoordinator decomposition (PR #45, 1,357 → 223 lines)
- **File:** `MacAmpApp/Audio/AudioPlayer.swift` — 1,070 lines, 2 swiftlint suppressions

## SwiftLint Violations

| Rule | Threshold (warning/error) | AudioPlayer.swift | Status |
|------|--------------------------|-------------------|--------|
| `file_length` | 600 / 1,200 | 1,070 | Suppressed (line 1) |
| `type_body_length` | 400 / 600 | ~1,040 | Suppressed (line 28) |

## Phases

| # | Phase | Status | Risk | Lines Saved |
|---|-------|--------|------|-------------|
| 1 | Extract EqualizerController | Pending | Low | ~120 |
| 2 | Consolidate visualizer forwarding | Pending | Low | ~70 |
| 3 | Clean up FourCC extension | Pending | Zero | ~12 |
| 4 | Engine transport extraction (optional) | Deferred | Medium-High | ~200 |

## Key Decisions

1. **Facade pattern** — AudioPlayer's public API will not change. All callers continue using `@Environment(AudioPlayer.self)`
2. **EQ extraction first** — Lowest risk, highest self-containment, recommended by research
3. **Phase 4 deferred** — Engine/transport extraction is high-risk due to seek state machine complexity. Only proceed if Phases 1-3 are insufficient
4. **No new @Environment types** — Views won't need to change their environment bindings

## Blockers

None.

## Open Questions

1. Is `String(fourCC:)` extension used anywhere? (Determines delete vs move in Phase 3)
