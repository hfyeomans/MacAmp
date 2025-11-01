# Plan

## Goals
- Simplify and harden state transitions in `AudioPlayer` to prevent regressions during playback, seeking, and completion flows.
- Improve `SkinManager` responsiveness and feedback by clearing stale errors, offloading heavy work, and constraining imports.
- Validate `AppSettings` persistence and filesystem interactions so skins and defaults remain consistent.
- Address supporting validation/performance items (`DockingController`, `EQF`, related helpers) without reintroducing prior misconceptions.

## Scope
### In Scope
- Refactoring to an enum-based playback state machine and related UI bindings.
- Skin manager loading lifecycle adjustments, including background parsing and error management.
- App settings filesystem/error handling plus defaults validation.
- Targeted quality-of-life fixes (docking debounce, EQF parsing, EQPreset clamps, sprite validation).
- Unit and integration test additions covering new logic.

### Out of Scope
- Large-scale architectural shifts beyond the enumerated components.
- UI redesigns or extensive feature additions unrelated to state consistency.
- Non-state-related performance optimisations.

## Workstreams & Steps
### 1. AudioPlayer State Refactor
1. Audit all consumers of `isPlaying`, `isPaused`, `isSeeking`, `wasStopped`, and `trackHasEnded`.
2. Introduce `PlaybackState` enum and single `playbackState` property with computed legacy booleans.
3. Centralise transitions (`transition(to:)`) to handle play, pause, stop, seek, completion, eject, and shuffle/repeat flows.
4. Update completion callbacks (`onPlaybackEnded`, seek handlers) to respect the new state machine.
5. Re-run smoke tests (play/pause/seek/next/prev/shuffle/repeat) to verify regressions.

### 2. SkinManager Lifecycle & Import Guardrails
1. Clear `loadingError` at load start and after success.
2. Extract archive parsing into a background task/actor returning results to the main actor.
3. Add file validation: acceptable extensions, canonical destination path, size threshold, better error messages.
4. Enhance logging to capture failure reasons.
5. Write async unit tests for parsing helper (mock archive inputs) if feasible.

### 3. AppSettings Persistence Hardening
1. Replace `try?` directory creation with throwing helper; surface failures to callers/UI.
2. Validate UserDefaults entries during initialisation; clamp or fallback as needed.
3. Add logging for persistence failures and document expected defaults.
4. Provide tests covering successful and failing directory creation.

### 4. Supporting Fixes
1. Implement debounce on `DockingController` persistence sink; ensure errors bubble to logs.
2. Add strict bounds/size checks to `EQF.parse` and return structured errors.
3. Clamp conversions in `EQPreset`.
4. Add validation to `Skin` and `SpriteResolver` helper methods (guard missing resources/digits).

## Testing Strategy
- **Unit Tests:** AudioPlayer transition tests, EQF parser edge cases, AppSettings directory handling.
- **Integration Tests:** Skin import workflow, DockingController persistence roundtrip.
- **Manual QA:** Playback flows, skin import UI response, docking toggles, preset loading.
- **Instrumentation:** Add temporary logging to monitor state transitions during QA (ensure removed or gated before release).

## Risks & Mitigations
- **State regression risk:** Use exhaustive switch statements and unit tests to lock down transitions.
- **Main/worker hand-off bugs:** Keep background parsing encapsulated; use `MainActor.run` for UI updates.
- **Filesystem failures in production:** Ensure errors propagate to UX and logs; add fallback defaults.

## Dependencies
- Confirmation on desired timer strategy in `AudioPlayer` (keep `Timer` vs migrate to `DispatchSourceTimer`).
- Decision on restoring a dedicated critical-issues document.
- Test environment availability for async/actor-based unit tests.

## Open Questions
1. Do we retain the existing `Timer`-based progress updates or invest in `DispatchSourceTimer`?  
2. Is a separate `critical-issues.md` required for reporting?  
3. What test coverage level is expected before merging (unit only vs integration suite)?

## Next Actions
1. Resolve open questions with stakeholders.
2. Produce implementation TODO checklist aligned with the workstreams.
3. Begin with AudioPlayer refactor once approvals/answers are in place.
