# Todo: AudioPlayer Seek Extraction

Updated: 2026-10-02

Checklist for SS-1, derived from `plan.md`.

## Re-evaluation

- [x] Seek coupling map (`research.md`, at `b3894d9`)
- [ ] Re-measure the seek map and SwiftLint counts at post-OGG HEAD (34 guard-var references at `b3894d9`)
- [ ] Seek characterization tests: seek while playing, seek while paused, seek to end, rapid seeks, stream no-op
- [ ] `AudioPlayer`-level test for a user action during a pending engine reconfigure (`cancelPendingReconfigure`)
- [ ] Pre-decomposition gate (`tasks/_context/principles.md`) and go/no-go ADR on Option B with its kill switch

## If go

- [ ] Branch `refactor/audioplayer-seek-extraction`; set `state.md` to IN PROGRESS
- [ ] Create `Audio/SeekController.swift` with non-optional init dependencies (engine, `videoPlaybackController`)
- [ ] Move the atomic unit in one commit (`plan.md` step 3)
- [ ] Route `playTrack`, `loadAudioFile`, `play`, `pause`, `stop` and the engine-reconfigure handlers through the new guard API
- [ ] `xcodegen generate`; build and test with Thread Sanitizer
- [ ] Manual checks (`plan.md` Verification)
- [ ] In a separate commit, once the characterization tests pass: replace the guard `Task.sleep` delays with one structured guard-clear (`placeholder.md`)
- [ ] One `/codex:review --base main`; fix what affects correctness
- [ ] PR for owner review

## SwiftLint suppressions (moved from `audioplayer-decomposition`)

- [ ] Decide thresholds vs a further split (`plan.md` step 5)
- [ ] Remove `// swiftlint:disable file_length` (`AudioPlayer.swift:1`), or record the decision to keep it
- [ ] Remove `// swiftlint:disable:this type_body_length` (`AudioPlayer.swift:9`), or record the decision to keep it

## Close-out

- [ ] Update `state.md` and `tasks/_context/` with the outcome
