# Task State: AudioPlayer.swift Decomposition

> **Description:** Tracks the current state of the AudioPlayer decomposition task including progress, blockers, and decisions.
> **Purpose:** Single source of truth for task status, updated as implementation progresses.

---

## Current Phase: Phase 4 — Engine + Stream Bridge + Transport Extraction

## Status: Phase 4 extraction COMPLETE. Oracle reviewed. PR pending user review.

## Branch: `refactor/audioplayer-phase4-transport`

## Context

- **Origin:** Code review of last 5 PRs (2026-02-18) flagged swiftlint suppressions in AudioPlayer.swift
- **Phases 1-3:** COMPLETE (PR #52 merged). EqualizerController extracted, visualizer consolidated, FourCC removed.
- **Phase 4:** UNLOCKED by T7 unified audio pipeline merge (2026-03-14). Assigned to Sprint S1.
- **File:** `MacAmpApp/Audio/AudioPlayer.swift` — currently **1,143 lines** (post-T7/T8), 57 lines from swiftlint error threshold.

## Phase 4 Oracle Review (2026-03-22)

Oracle (gpt-5.3-codex, xhigh reasoning) reviewed extraction strategy. Key decisions:

1. **One AudioEngineController** for engine wiring + stream bridge (shared format invariants)
2. **Keep seek state machine in AudioPlayer** — partial move splits one state machine across two owners
3. **Transport must follow nodes** — play/pause/stop touch playerNode directly
4. **Facade preserved** — all AudioPlayer public API signatures unchanged
5. **Tests BEFORE extraction** — add seek characterization tests first

## Architecture Alignment

Phase 4 does **not** conflict with `swift-project-structure-research`:
- New files go to `MacAmpApp/Audio/` (current location)
- Folder moves to `Audio/Playback/` deferred to post-S3 Structure Sprint

## Blockers

None.

## Open Questions

None remaining — Oracle review resolved all architectural questions.
