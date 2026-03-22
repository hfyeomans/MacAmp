# Todo: AudioPlayer Seek Extraction

> **Description:** Track actionable work items for extracting the seek state machine from AudioPlayer.swift.
> **Purpose:** Each item is a discrete, verifiable unit of work. Items are checked off as completed.

---

- [ ] Wait for S2 tasks to stabilize (os-workgroup-integration, video-audio-engine-routing may modify AudioPlayer)
- [ ] Expand seek characterization tests (current 13 tests cover observable state; add tests for seek-specific behavior)
- [ ] Produce a responsibility map of seek state machine coupling points
- [ ] Decide extraction target: new SeekController or expand AudioEngineController
- [ ] Extract seek state machine as atomic unit (all guards + shouldIgnoreCompletion + seek + seekToPercent + onPlaybackEnded)
- [ ] Update playTrack/stop to call through controller for seek guard management
- [ ] Oracle review on extraction
- [ ] XcodeBuildMCP build + test
- [ ] Verify AudioPlayer under 600 lines
- [ ] Remove `// swiftlint:disable file_length`
- [ ] Remove `// swiftlint:disable:this type_body_length`
- [ ] Run swiftlint — zero violations without suppressions
- [ ] Push branch → create PR for user review
