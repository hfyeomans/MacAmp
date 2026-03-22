# Depreciated: Unified Audio Pipeline

> **Purpose:** Documents code and approaches that have been deprecated or replaced during this task.

---

## MTAudioProcessingTap Approach (From T5 Phase 2)

The following code was built for the MTAudioProcessingTap loopback bridge approach and should be removed when the custom decode pipeline is implemented:

### StreamPlayer.swift
- `LoopbackTapContext` class (lines 12-34) — @unchecked Sendable context for tap callbacks
- `loopbackTapInit()` function — tap initialization callback
- `loopbackTapFinalize()` function — tap cleanup callback
- `loopbackTapPrepare()` function — format capture callback
- `loopbackTapUnprepare()` function — ring buffer flush callback
- `loopbackTapProcess()` function — PCM copy + output zeroing callback
- `attachLoopbackTap()` method — creates and attaches MTAudioProcessingTap
- `detachLoopbackTap()` method — removes tap from AVPlayerItem
- `currentTapRef` property — stored tap reference
- `bridgeLog()` global function — temporary diagnostic logger

### PlaybackCoordinator.swift
- `attachBridgeTap()` method — wires tap to stream with format-ready callback

### Reason for Depreciation
MTAudioProcessingTap does not work with streaming AVPlayerItems. Apple QA1716 confirms AVAudioMix was designed for file-based content only. tapPrepare/tapProcess callbacks never fire for live/streaming sources.

See: `tasks/_context/lessons-dual-backend-dead-end.md` for full analysis.

## AVPlayer-Based StreamPlayer

The entire AVPlayer-based streaming implementation in StreamPlayer.swift will be replaced by the custom decode pipeline. The following are replaced:
- `AVPlayer` instance and lifecycle management
- `AVPlayerItemMetadataOutput` for ICY metadata
- Combine-based status observers (timeControlStatus, itemStatus)
- `play(station:)` / `play(url:)` methods that create AVPlayerItems

Replaced by: `StreamDecodePipeline` actor with URLSession + AudioFileStream + AudioConverter.

## CoreAudio Process Tap Approach (Evaluated, Never Implemented)

The CoreAudio Process Tap (AudioHardwareCreateProcessTap) was researched extensively but never implemented due to:
- Feedback loop risk in same-process capture
- Device UID isolation unreliable per Oracle assessment
- Complexity of aggregate device management

Research preserved in: `tasks/internet-streaming-volume-control/research.md` (Addendum sections)
