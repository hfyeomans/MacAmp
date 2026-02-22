# Lessons Learned: Stream Loopback Bridge (T5 Phase 2)

> **Purpose:** Documents all mistakes, crashes, Oracle findings, and corrective guidance from the failed first attempt at implementing the T5 Phase 2 Loopback Bridge. This file exists to prevent repeating the same errors on the second attempt.

---

## Summary

The first implementation attempt deviated from the documented plan in `tasks/internet-streaming-volume-control/plan.md` and `todo.md`. Instead of following the plan step-by-step, the implementer "got creative" and made assumptions about audio formats, engine wiring, and Swift concurrency that led to crashes, silent audio, and wasted iteration cycles. The Oracle (gpt-5.3-codex, xhigh reasoning) was consulted twice and identified critical issues.

**Root cause pattern:** Improvising implementation details instead of following the plan's explicit code patterns and the codebase's established conventions.

---

## Critical Mistakes (Ordered by Severity)

### 1. CRASH: @MainActor Isolation in Render Block (Swift 6.2)

**What happened:** The AVAudioSourceNode render block was defined as a closure inside `activateStreamBridge()`, a method on `@MainActor AudioPlayer`. In Swift 6.2 strict concurrency, closures inherit isolation from their enclosing context. CoreAudio calls the render block on `com.apple.audio.IOThread.client`. The Swift runtime checked `@MainActor` isolation via `swift_task_isCurrentExecutorWithFlagsImpl` → `dispatch_assert_queue` on the main queue → **EXC_BREAKPOINT (SIGTRAP)**.

**Crash signature:**
```
Thread 23 Crashed:: com.apple.audio.IOThread.client
0  libdispatch.dylib      _dispatch_assert_queue_fail
3  libswift_Concurrency   _swift_task_checkIsolatedSwift
5  MacAmp.debug.dylib     closure #1 in AudioPlayer.activateStreamBridge
```

**Fix:** Extract the render block into a `nonisolated private static func makeStreamRenderBlock()` — same pattern already proven in `VisualizerPipeline.makeTapHandler()` in this codebase. The static context breaks @MainActor isolation inheritance.

**Rule:** In Swift 6.2, ANY closure defined inside a `@MainActor` class method that will execute on another thread MUST be extracted to a `nonisolated static` method. This applies to:
- AVAudioSourceNode render blocks
- AVAudioEngine tap handlers (already handled by VisualizerPipeline.makeTapHandler)
- MTAudioProcessingTap callbacks (already top-level functions, so no issue)
- Any `@Sendable` or `@convention(c)` closure

### 2. SILENT AUDIO: Wrong Source Node Format (Non-Interleaved vs Interleaved)

**What happened:** Used `AVAudioFormat(standardFormatWithSampleRate:channels:)` for the source node, which creates a **non-interleaved** format (separate channel buffers). But the ring buffer stores **interleaved** data `[L0,R0,L1,R1,...]`. Added a scratch buffer and manual de-interleaving in the render block to bridge the mismatch. This produced garbled data — Butterchurn visualization worked (tolerant of format issues) but no audible audio and spectrum analyzer showed wrong data.

**What the plan said:** Step 2.3 explicitly shows `ringBuffer.read(into: audioBufferList, count: frameCount)` — reading DIRECTLY into the buffer list with NO intermediate scratch buffer. This only works with **interleaved** format (single buffer matching ring buffer layout).

**Fix (from Oracle):** Use interleaved block format for the source node:
```swift
let blockFormat = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: sampleRate,
    channels: 2,
    interleaved: true  // Matches ring buffer layout
)
```

Then connect to the EQ with the **device graph format** (non-interleaved at device sample rate):
```swift
let deviceFormat = audioEngine.outputNode.inputFormat(forBus: 0)
let graphFormat = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: deviceFormat.sampleRate,
    channels: 2,
    interleaved: false  // Engine's native format
)
audioEngine.connect(sourceNode, to: eqNode, format: graphFormat)
```

The engine auto-converts between interleaved (source block format) and non-interleaved (graph format) including sample rate conversion if the stream rate differs from the hardware rate.

**Rule:** Stream audio format is NOT the same as local file format or video format. The source node block format must match what the render block produces (interleaved, matching ring buffer). The graph connection format must match what the engine expects (non-interleaved, device sample rate).

### 3. CRASH: Format Mismatch Error -10868

**What happened:** Initially tried to hot-swap engine nodes with `audioEngine.connect(sourceNode, to: eqNode, format: streamFormat)` while the engine was RUNNING. Error -10868 (`kAudioUnitErr_FormatNotSupported`) because the engine had stale format state from a previous configuration.

**Fix:** Stop and reset the engine before rewiring, same pattern as the existing `rewireForCurrentFile()`:
```swift
if audioEngine.isRunning {
    audioEngine.stop()
    audioEngine.reset()
}
```

**Plan deviation:** The plan said "engine never stops" (Step 2.4a). This was aspirational but not achievable with AVAudioEngine's format negotiation model. The proven pattern in this codebase (`rewireForCurrentFile`) always stops/resets before reconfiguring. The brief silence is acceptable for radio.

### 4. MISSING: Mixer→Output Connection After Reset

**What happened:** After `audioEngine.reset()`, the implicit `mainMixerNode→outputNode` connection may be broken. Audio data flows through the engine (visualizer tap picks it up) but never reaches the output node (speakers).

**Fix (from Oracle):** Explicitly verify and restore the mixer→output connection after reset:
```swift
if audioEngine.outputConnectionPoints(for: audioEngine.mainMixerNode, outputBus: 0).isEmpty {
    audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)
}
```

---

## Oracle Review Findings (P1 — Must Fix)

### Finding 1: Stream→Stream Ring Buffer Race

**Issue:** `PlaybackCoordinator.setupLoopbackBridge()` flushes a reused ring buffer before the previous stream's tap producer is guaranteed quiesced. `LockFreeRingBuffer.flush()` explicitly requires producer quiescence. Rapid stream A→B switching is unsafe.

**Fix:** Always call `teardownLoopbackBridge()` (which detaches the tap, stopping the producer) BEFORE `setupLoopbackBridge()` in all stream play methods:
```swift
func play(station: RadioStation) async {
    teardownLoopbackBridge()  // Quiesce producer first
    audioPlayer.stop()
    streamPlayer.stop()
    setupLoopbackBridge()     // Now safe to flush/reuse ring buffer
    await streamPlayer.play(station: station)
    streamPlayer.attachLoopbackTap()
}
```

### Finding 2: Stream Error Leaves Bridge Inconsistent

**Issue:** When the stream errors, `StreamPlayer.handlePlaybackError()` sets `error` but doesn't tear down the bridge. `audioPlayer.isBridgeActive` remains true, `isEngineRendering` stays true, visualizer keeps polling empty data.

**Mitigation:** Capability flags already handle this correctly — `isStreamBackendActive` returns false on error (via `streamPlayer.error == nil` check), so controls un-dim. The bridge producing silence on an errored stream is acceptable (user must stop/retry anyway). Full bridge teardown on error could be added but is P2.

### Finding 3: Scratch Buffer Use-After-Free Risk

**Issue:** The render block captured a raw `UnsafeMutablePointer<Float>` (scratch buffer), and teardown could free it while a render cycle was in-progress.

**Resolution:** Eliminated entirely in the corrected implementation. No scratch buffer needed when using interleaved format — read directly into audioBufferList.

---

## Patterns That MUST Be Followed

### 1. Follow VisualizerPipeline.makeTapHandler() for All RT Closures

Any closure that runs on a real-time audio thread and is defined in a `@MainActor` context must use the `nonisolated static func` pattern:
```swift
nonisolated private static func makeStreamRenderBlock(...) -> AVAudioSourceNodeRenderBlock {
    return { isSilence, _, frameCount, audioBufferList -> OSStatus in
        // Real-time safe code here
    }
}
```

### 2. Follow rewireForCurrentFile() for Engine Graph Changes

The existing codebase pattern for reconfiguring AVAudioEngine:
```swift
if audioEngine.isRunning {
    audioEngine.stop()
    audioEngine.reset()
}
audioEngine.disconnectNodeOutput(oldNode)
audioEngine.disconnectNodeOutput(eqNode)
audioEngine.connect(newNode, to: eqNode, format: ...)
audioEngine.connect(eqNode, to: mainMixerNode, format: nil)
audioEngine.prepare()
startEngineIfNeeded()
```

Do NOT attempt hot-swap while the engine is running. The codebase has never done this successfully.

### 3. Use Interleaved Block Format for AVAudioSourceNode

When the data source (ring buffer) is interleaved:
- Source node block format: `interleaved: true` at stream sample rate
- Graph connection format: `interleaved: false` at device sample rate
- Engine handles conversion automatically

### 4. macOS 26 SDK API Changes

`MTAudioProcessingTapCreate` now takes `MTAudioProcessingTap?` (direct) instead of `Unmanaged<MTAudioProcessingTap>?`. The `currentTapRef` property and `audioTapProcessor` assignment must use the direct type, not `Unmanaged` wrapping.

---

## Deviations from Plan That Failed

| Deviation | What Plan Said | What Was Done | Result |
|-----------|---------------|---------------|--------|
| Source node format | Read directly into audioBufferList (implies interleaved) | Used non-interleaved "standard" format + scratch buffer + manual de-interleave | Silent audio, wrong visualizer data |
| Engine hot-swap | "Engine never stops" (Step 2.4a) | Tried connecting with engine running | Crash -10868 |
| Render block isolation | (implicit: follow existing patterns) | Defined closure inline in @MainActor method | Crash EXC_BREAKPOINT on audio thread |
| Bridge state machine | "Define starting/active/failed/teardown" (2.0c) | Simplified to boolean `isBridgeActive` | Missed edge cases (stream error, rapid switching) |
| Stream→stream ordering | (implicit: teardown before setup) | Called `setupLoopbackBridge()` before tearing down previous tap | Ring buffer race condition |

---

## Deviations That Were Correct

| Deviation | Why It Was Needed |
|-----------|------------------|
| Mono→stereo upmixing in tap callback | Plan didn't mention mono streams. Defensive addition — most streams are stereo but mono does exist. |
| `nonisolated static func` for render block | Swift 6.2 strict concurrency enforcement not anticipated in plan. Required by runtime. |
| macOS 26 MTAudioProcessingTap API change | SDK changed from `Unmanaged<>` to direct type. Not in plan since plan predated SDK update. |
| Always-stereo ring buffer | Ring buffer created with 2 channels. Tap upmixes mono if needed. Simpler than dynamic channel matching. |

---

## Correct Implementation Sequence (For Second Attempt)

Follow the plan's execution blocks exactly:

### Block 1: StreamPlayer MTAudioProcessingTap
- Top-level `@convention(c)` callbacks (already nonisolated by nature)
- `LoopbackTapContext: @unchecked Sendable` with `nonisolated(unsafe)` mutable state
- `attachLoopbackTap()` / `detachLoopbackTap()`
- Handle mono→stereo upmixing in tapProcess
- Always-stereo ring buffer (report ring buffer channelCount in onFormatReady, not stream channelCount)
- macOS 26 API: use `MTAudioProcessingTap?` directly, not `Unmanaged<>`

### Block 2: AudioPlayer AVAudioSourceNode + Graph Switching
- `nonisolated private static func makeStreamRenderBlock()` — NEVER define inline
- Interleaved block format matching ring buffer layout
- Graph format: non-interleaved at device sample rate
- Stop/reset engine before rewiring (follow `rewireForCurrentFile` pattern)
- Verify mixer→output connection after reset
- Volume/balance via `AVAudioMixing` protocol (`.volume`, `.pan` on source node)
- Update `volume`/`balance` didSet to also set `streamSourceNode?.volume/pan`
- `isEngineRendering` computed property for visualizer gating

### Block 3: PlaybackCoordinator Bridge Lifecycle
- `setupLoopbackBridge()` / `teardownLoopbackBridge()`
- ALWAYS `teardownLoopbackBridge()` before `setupLoopbackBridge()` in ALL stream play methods
- Full sequence: teardown → stop both backends → setup bridge → play stream → attach tap
- Capability flags: `!isStreamBackendActive || audioPlayer.isBridgeActive`

### Block 4: VisualizerView + AudioPlayer Visualization
- Replace `audioPlayer.isPlaying` with `audioPlayer.isEngineRendering` in VisualizerView
- Update `getFrequencyData` and `snapshotButterchurnFrame` guards

### Block 5: Verify
- Build with TSan
- Manual testing per V2.1–V2.14

---

## Key Technical Facts (Verified)

1. `AVAudioFormat(standardFormatWithSampleRate:channels:)` creates **non-interleaved** Float32
2. `AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate:, channels:, interleaved: true)` creates **interleaved** Float32
3. AVAudioEngine accepts interleaved AVAudioSourceNode and auto-converts to non-interleaved for downstream nodes
4. `audioEngine.reset()` may break the implicit `mainMixerNode→outputNode` connection — verify and restore
5. `audioEngine.outputNode.inputFormat(forBus: 0)` gives the device's hardware format (sample rate, channels)
6. In Swift 6.2, closures in `@MainActor` methods inherit isolation — audio thread render blocks will crash at runtime
7. `LockFreeRingBuffer.flush()` requires producer quiescence — detach tap before flushing
8. AVAudioSourceNode conforms to `AVAudioMixing` — has `.volume` and `.pan` properties directly
9. `MTAudioProcessingTapCreate` in macOS 26 SDK uses direct `MTAudioProcessingTap?`, not `Unmanaged<>`

---

## Oracle Consultation Summary

### Review 1: Implementation Review (Grade: C)
- P1: Stream→stream ring buffer race (flush before producer quiesced)
- P1: Engine never stops not met for STREAM→LOCAL
- P1: Stream error leaves bridge inconsistent
- P1: Scratch buffer UAF risk during teardown
- P2: Known overrun race in ring buffer (accepted by design)

### Review 2: Format Guidance
- Use **interleaved block format** for source node (matches ring buffer)
- Connect to EQ with **device graph format** (non-interleaved, device sample rate)
- Engine auto-converts between block format and graph format
- Silence likely from wrong AudioBufferList interpretation, not routing
- Verify mixer→output connection after `reset()`

---

## Process Failures

1. **Did not follow the plan.** The plan explicitly showed `ringBuffer.read(into: audioBufferList)` — direct read, no scratch buffer. Implementer assumed non-interleaved format and added unnecessary complexity.

2. **Did not follow existing codebase patterns.** `VisualizerPipeline.makeTapHandler()` already solved the @MainActor isolation problem. `rewireForCurrentFile()` already showed the engine stop/reset pattern. Both were ignored in favor of "creative" approaches.

3. **Did not consult Oracle early enough.** The Oracle was consulted AFTER implementation, not during planning. Had it been consulted before writing the source node format code, the interleaved vs non-interleaved issue would have been caught immediately.

4. **Marked todo items as complete prematurely.** All Phase 2 items were marked `[x]` before testing proved they worked correctly.

5. **Did not build and test incrementally.** The entire bridge was implemented in one pass before any runtime testing. Incremental build/test after each block would have caught the @MainActor crash at Block 2 instead of after all blocks were complete.
