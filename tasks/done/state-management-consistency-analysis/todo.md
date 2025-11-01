# TODO

## AudioPlayer State Refactor
- [x] Inventory every consumer of `isPlaying`, `isPaused`, `isSeeking`, `wasStopped`, `trackHasEnded`
- [x] Introduce `PlaybackState` enum with single `@Published playbackState`
- [x] Replace direct flag mutations with `transition(to:)` helper
- [x] Update completion/seek handlers to respect the new state machine
- [x] Verify playback workflows manually (play/pause/seek/next/prev/shuffle/repeat)

## SkinManager Enhancements
- [x] Clear `loadingError` at start/end of skin loads
- [x] Move archive parsing into background helper returning to `MainActor`
- [x] Add path + size validation and improved error feedback during import
- [x] Extend logging around load/import outcomes
- [x] Add integration test for successful and failing skin imports

## AppSettings Hardening
- [x] Replace `try?` directory logic with throwing `ensureSkinsDirectory`
- [x] Validate defaults when initialising published properties
- [x] Log/propagate persistence failures for skin directory and defaults
- [x] Cover directory success/failure via tests

## Supporting Fixes
- [x] Debounce `DockingController` persistence sink and log errors
- [x] Add bounds checks + clamping in `EQF.parse`
- [x] Clamp `EQPreset` conversions
- [x] Add guardrails to `Skin` bundle lookups and `SpriteResolver` digit helpers

## Deferred / Follow-Up
- [ ] Reintroduce Auto EQ generation with safe analysis pipeline (see `notes/auto-eq-issues.md`)

## Testing & QA
- [x] Implement integration test for docking persistence roundtrip
- [x] Add high-value unit tests (AudioPlayer state transitions, EQF parsing edge cases)
- [x] Run manual QA checklist (playback, skin import, docking toggles)
