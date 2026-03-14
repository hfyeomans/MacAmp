# State: Unified Audio Pipeline (Custom Stream Decode)

> **Purpose:** Tracks the current state of replacing AVPlayer with a custom stream decode pipeline.

---

## Current Status: 🔄 IN PROGRESS — Phases 1.1-1.9 complete, stream sputtering + visualizer remain

## Cross-Task Dependencies

```
swift-concurrency-62-cleanup PR 1 (T8) → MERGE
    ↓ (establishes SWIFT_VERSION 6.2)
unified-audio-pipeline (T7) → this task → MERGE
    ↓ (AudioPlayer has final shape)
swift-concurrency-62-cleanup PR 2 (T8) → AudioPlayer isolated deinit + @concurrent → MERGE
```

**Prerequisite:** `swift-concurrency-62-cleanup` PR 1 must merge first. It upgrades
`SWIFT_VERSION` to 6.2, enabling `isolated deinit`, `@concurrent`, and fixing the
nonisolated-async-stays-on-caller behavioral change.

**Post-task:** `swift-concurrency-62-cleanup` PR 2 adds AudioPlayer `isolated deinit`
covering the final shape (including streamSourceNode/bridge from this task).

## Context

This task replaces the AVPlayer-based streaming backend with a custom decode pipeline that feeds
PCM into AVAudioEngine. This enables EQ, visualization, and balance for internet radio streams —
achieving feature parity with local file playback.

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
- [x] Plan written (plan.md)
- [x] Plan updated with Swift 6.2 adoption notes (2026-03-13)
- [ ] Plan reviewed by Oracle (gpt-5.3-codex, xhigh)
- [x] Todo list created (todo.md)
- [x] Todo updated with Swift 6.2 items (2026-03-13)
- [ ] Implementation (blocked on T8 PR 1 merge)
- [ ] Verification

## Key Decisions

1. **Replace AVPlayer for streams** — decode ourselves using AudioFileStream + AudioConverter
2. **Keep LockFreeRingBuffer** — exact same SPSC bridge, reuse as-is
3. **Keep AVAudioSourceNode consumer** — source-agnostic, already built
4. **Keep activateStreamBridge/deactivateStreamBridge** — engine graph switching works
5. **HLS deferred** — Phase 1 targets progressive HTTP streams (90%+ of internet radio)
6. **OGG deferred** — AudioFileStream may not fully support OGG containers
7. **Swift 6.2 adopted** — `isolated deinit` for StreamPlayer, `@MainActor @Sendable` callbacks,
   task naming, decode stays on serial DispatchQueue (not nonisolated async)
8. **NSObject dropped from StreamPlayer** — no longer needed without AVPlayer delegate
9. **AudioPlayer bridge cleanup idempotent** — pre-planned for future `isolated deinit` (T8 PR 2)

## Swift 6.2 Updates (2026-03-13)

| # | Item | Plan Section | Status |
|---|------|-------------|--------|
| 1 | nonisolated-async-stays-on-caller risk | Phase 1.4, Risk Assessment | Updated |
| 2 | URLSession.asyncBytes must use @concurrent helper | Phase 1.4 | Updated |
| 3 | StreamPlayer drops NSObject + adds `isolated deinit` | Phase 1.5 | Updated |
| 4 | Callbacks use `@MainActor @Sendable` | Phase 1.4 | Updated |
| 5 | StreamDecodePipeline wording: `@MainActor` class not actor | Files table, Phase 1.4, Commit strategy | Updated |
| 6 | C API Unmanaged note corrected (not "same as VisualizerPipeline") | Phase 1.2/1.3 | Updated |
| 7 | AudioPlayer bridge idempotent for future `isolated deinit` | Phase 1.7 | Updated |
| 8 | Risk assessment: nonisolated-async replaces C-callback-isolation | Risk Assessment | Updated |
| 9 | Task naming for orphan-task debugging | V12 | Updated |
| 10 | Type isolation annotations for new files | Swift 6.2 section | Added |

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

## Architecture Notes (Swift 6.2 Impact)

1. **Decode queue is the critical isolation boundary.** All AudioFileStream/AudioConverter work
   runs on a serial DispatchQueue, NOT in nonisolated async methods. This is immune to the 6.2
   nonisolated-async-stays-on-caller change because DispatchQueue dispatch is explicit.

2. **StreamPlayer drops NSObject.** This is a type-system change — StreamPlayer becomes a plain
   `@MainActor @Observable final class` instead of inheriting NSObject. Any code that casts
   StreamPlayer to NSObject or AnyObject will break. The delegate proxy for URLSession is a
   separate lightweight NSObject, not StreamPlayer itself.

3. **AudioPlayer bridge cleanup must be idempotent.** `deactivateStreamBridge()` will be called
   from both explicit `stop()` paths AND from the future `isolated deinit`. If it's not safe to
   call when bridge is already inactive, double-deactivation will crash.

4. **VisualizerPipeline.removeTap() is now MainActor-isolated** (changed by T8 PR 1). The
   pipeline task doesn't call removeTap() directly — it goes through AudioPlayer.deactivateStreamBridge()
   which calls removeVisualizerTapIfNeeded(). No conflict.

## Future Work Identified During This Task

| Item | Description | Priority |
|------|-------------|----------|
| Video audio through AVAudioEngine | Video files use AVPlayer → system audio (no EQ/visualizer/balance). Solution: MTAudioProcessingTap (works for local files, unlike streams). Separate task. | Medium |
| Milkdrop/Butterchurn loading regression | Pre-existing: WebContent sandbox issues prevent Butterchurn from loading. Unrelated to pipeline. Separate investigation. | Low |
| AVAudioEngineConfigurationChange | No handler for output device/sample rate changes mid-session. Could leave graph in stale format state. | Low |

## Branch

`feature/unified-audio-pipeline` (created from `main` after T8 PR 1 merge)
