# State: Unified Audio Pipeline (Custom Stream Decode)

> **Purpose:** Tracks the current state of replacing AVPlayer with a custom stream decode pipeline.

---

## Current Status: PLAN + TODOS COMPLETE — AWAITING ORACLE REVIEW

## Context

This task replaces the AVPlayer-based streaming backend with a custom decode pipeline that feeds PCM into AVAudioEngine. This enables EQ, visualization, and balance for internet radio streams — achieving feature parity with local file playback.

**Parent task:** `tasks/internet-streaming-volume-control/` (Phase 1 complete, Phase 2 MTAudioProcessingTap approach failed)
**Predecessor findings:** `tasks/_context/claude-mistakes-stream-loopback-bridge.md`, `tasks/_context/lessons-dual-backend-dead-end.md`

## Progress

- [x] Research: MTAudioProcessingTap confirmed dead for streams
- [x] Research: CoreAudio Process Tap evaluated and rejected (feedback loop)
- [x] Research: Winamp unified pipeline architecture analyzed
- [x] Research: Deep research system recommends AVSampleBufferAudioRenderer
- [x] Research: Oracle recommends AudioFileStream + AudioConverter pipeline
- [x] Research: Gemini confirms Winamp single-pipeline model
- [x] Research findings documented in research.md
- [x] Lessons learned documented in `tasks/_context/lessons-dual-backend-dead-end.md`
- [ ] Plan written (plan.md)
- [ ] Plan reviewed by Oracle (gpt-5.3-codex, xhigh)
- [ ] Todo list created (todo.md)
- [ ] Implementation
- [ ] Verification

## Key Decisions

1. **Replace AVPlayer for streams** — decode ourselves using AudioFileStream + AudioConverter
2. **Keep LockFreeRingBuffer** — exact same SPSC bridge, reuse as-is
3. **Keep AVAudioSourceNode consumer** — source-agnostic, already built
4. **Keep activateStreamBridge/deactivateStreamBridge** — engine graph switching works
5. **HLS deferred** — Phase 1 targets progressive HTTP streams (90%+ of internet radio)
6. **OGG deferred** — AudioFileStream may not fully support OGG containers

## Reusable Components (from Phase 2 MTAudioProcessingTap work)

- LockFreeRingBuffer (SPSC, Swift Atomics)
- AVAudioSourceNode + makeStreamRenderBlock() (nonisolated static)
- activateStreamBridge() / deactivateStreamBridge() on AudioPlayer
- PlaybackCoordinator bridge lifecycle pattern (simplified)
- Capability flags (supportsEQ/Balance/Visualizer)
- VisualizerView isEngineRendering updates

## Depreciated Components (from Phase 2 MTAudioProcessingTap work)

- LoopbackTapContext (@unchecked Sendable)
- Top-level tap callbacks (loopbackTapInit/Finalize/Prepare/Unprepare/Process)
- StreamPlayer.attachLoopbackTap() / detachLoopbackTap()
- StreamPlayer.currentTapRef
- PlaybackCoordinator.attachBridgeTap()
- bridgeLog() temporary diagnostic function

## Branch

TBD — will create from current `feature/stream-loopback-bridge` or from `main`
