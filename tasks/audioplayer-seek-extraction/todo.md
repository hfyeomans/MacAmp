# Todo: AudioPlayer Seek Extraction

> **Description:** Checklist for extracting the seek state machine from AudioPlayer.swift.
> **Updated:** 2026-03-24 (Oracle review v2 — expanded callback contract)

---

- [x] Wait for S2 tasks to stabilize (COMPLETE — S2 merged, AudioPlayer at 740 lines)
- [x] Produce a responsibility map of seek state machine coupling points
- [ ] Create branch `refactor/audioplayer-seek-extraction`
- [ ] Update state.md to IN PROGRESS
- [ ] Expand seek characterization tests before extraction
  - [ ] Seek during playback → position updates + resumes
  - [ ] Seek while paused → position updates + stays paused
  - [ ] Seek at end-of-track → completion handling
  - [ ] Rapid seeks → only last seek takes effect
  - [ ] Seek during stream (no-op) → guard behavior
- [ ] Create `Audio/SeekController.swift` with:
  - [ ] 3 seek state properties (currentSeekID, seekGuardActive, isHandlingCompletion)
  - [ ] shouldIgnoreCompletion(from:)
  - [ ] seekToPercent(_:resume:) with video delegation
  - [ ] seek(to:resume:) core implementation
  - [ ] onPlaybackEnded(fromSeekID:) with full callback contract
  - [ ] Public API: invalidateSeekID(), activateSeekGuard(), clearSeekGuard()
  - [ ] 6 callbacks: onTransition, onProgressUpdate, onRequestNextTrack, onPlaylistAdvanceRequest, onPlaybackFinished, onRemoveVisualizerTap
- [ ] Wire callbacks in AudioPlayer.init (weak self captures)
- [ ] Update AudioPlayer.playTrack to use SeekController
- [ ] Update AudioPlayer.loadAudioFile to use SeekController
- [ ] Update AudioPlayer.play/pause/stop to use SeekController
- [ ] Run `xcodegen generate`
- [ ] XcodeBuildMCP build (Thread Sanitizer enabled)
- [ ] XcodeBuildMCP test — all seek tests pass
- [ ] Oracle review on extraction
- [ ] Verify AudioPlayer.swift under 600 lines
- [ ] Remove `// swiftlint:disable file_length`
- [ ] Remove `// swiftlint:disable:this type_body_length`
- [ ] Run swiftlint — zero violations without suppressions
- [ ] Manual test: seek during play, seek while paused, rapid seeks, stream (no seek), remote command seek
- [ ] Push branch -> create PR for user review
- [ ] Update state.md and shared _context/ on completion
