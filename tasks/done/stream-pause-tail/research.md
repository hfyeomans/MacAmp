# Research: Stream Pause Tail

> **Purpose:** Eliminate the audible tail (~683 ms – 1.5 s depending on stream sample rate) that continues after pausing an internet radio stream. Cause: decoded PCM still in the SPSC ring buffer when AVAudioSourceNode keeps reading until drained.

**Status:** Research complete (2026-04-27). Ready for plan.md.
**Sprint:** S3 (LOW). **Source:** Oracle P2 / future-work entry post-merge of `tasks/done/unified-audio-pipeline/` (PR #57).

---

## Current Architecture (the pause path)

```
URLSession → ICYFramer → AudioFileStreamParser → AudioConverterDecoder
    → LockFreeRingBuffer (32 768 frames @ stream rate)
    → AVAudioSourceNode render block → EQ → mixer → output
```

End-to-end on user pause:

1. `PlaybackCoordinator.pause()` (`PlaybackCoordinator.swift:250-260`) — for `.radioStation`, calls `streamPlayer.pause()`.
2. `StreamPlayer.pause()` (`StreamPlayer.swift:116-125`) — cancels reconnect, stops elapsed timer, calls `pipeline.pause()`. Does **not** touch the bridge or the ring buffer. Sets `isPlaying = false`.
3. `StreamDecodePipeline.pause()` (`StreamDecodePipeline.swift:227-231`) — guards on `.playing`, calls `dataTask?.suspend()`, transitions to `.paused`. **Nothing flushes the ring buffer.**
4. `AudioEngineController` render block (`AudioEngineController.swift:277-303`) — `makeStreamRenderBlock` reads `ringBuffer.read(...)` every callback (~5–11 ms) and zero-fills only on underrun. Engine and source node remain running. `streamSourceNode` has no `pause()` API.
5. `LockFreeRingBuffer` (`LockFreeRingBuffer.swift:140-149`) — only mutation surface is `flush(newGeneration:)` which equalises `readHead = writeHead`. Doc warns *"caller must ensure the producer is quiesced before calling."* `flush` is currently called only from `StreamDecodePipeline.start(...)` after a full teardown.

Local files use a different path (`AudioPlayer.pause` → `AVAudioPlayerNode.pause()`), which is sample-accurate — no tail.

---

## Root Cause Analysis

Ring buffer capacity = 32 768 frames × 2ch (`StreamPlayer.swift:98,134,340`). Tail length scales inversely with sample rate:

| Rate | Tail |
|------|------|
| 48 000 Hz | 683 ms |
| 44 100 Hz | 743 ms (matches "~0.7 s") |
| 32 000 Hz | 1024 ms |
| 22 050 Hz | 1486 ms |

Steady-state fill is near full because the decoder runs ahead of the consumer (HTTP throughput >> playback rate, then rate-limited by overrun drop-oldest).

Secondary contributors:
1. **`AudioConverterDecoder` output buffer** — 4 096 frames pre-allocated (`AudioConverterDecoder.swift:60`), ≤ 93 ms @ 44.1 kHz.
2. **`AudioConverterDecoder.packetQueue`** — split-and-enqueued compressed packets awaiting `decode()`. Typically one MP3 frame (~26 ms); for AAC up to a few hundred ms during a burst.
3. **In-flight URLSession delegate callbacks** — `dataTask.suspend()` is asynchronous; `onData` callbacks already on the delegate operationQueue dispatch into `decodeQueue` *after* MainActor's `pause()` returns.
4. **Hardware output latency** — 5–25 ms.

**Total upper bound for unmitigated tail ≈ `ringFillFrames/sampleRate + 120 ms + outputLatency`.** The ring buffer dominates.

---

## Solution Options

| | Option | Latency to silence | Resume | Concurrency | Verdict |
|---|---|---|---|---|---|
| **A** | Flush ring buffer (after producer-quiesce) | ≤ 1 render quantum (~11 ms) once flush completes | Producer must refill — needs prebuffer warmup | Requires producer fully quiesced before flush; see "Quiescing the producer" | Sound, but quiesce is not free — see below |
| **B** | Atomic silence flag in render block | One render callback | Clear flag → instant | Trivial — single relaxed atomic load on RT thread | Sound; alone leaves stale audio in ring on resume |
| **C** | Disconnect/detach source node on graph | One callback after disconnect | Reconnect with explicit formats; risk -10868 (T7 Lesson 4) | High — graph mutation while engine running | **Reject** — fragile after T7 |
| **D** | `streamSourceNode.volume = 0` | One callback (volume ramp may apply) | Restore — race with `setVolume(_:)` (`AudioEngineController.swift:262-265`) | Conflicts with user volume routing | **Reject** — conflicts with existing routing |

(Note for D: visualizer tap is on `mainMixerNode`, so a node-volume drop *would* attenuate the visualizer too — a previous draft was wrong about this.)

---

## Recommendation

**Adopt Option A (producer-quiesce + ring-buffer flush) with a thin Option-B atomic silence gate.**

Rationale:
1. A reuses the existing, documented `LockFreeRingBuffer.flush(newGeneration:)` primitive — no SPSC redesign.
2. The atomic silence gate (B) closes any race between "decoder quiesced" and "flush completed" at the cost of one relaxed atomic load per render callback (≈ 1 ns vs ~10 ms quantum).
3. C and D are rejected (graph mutation risk; volume-routing conflict).

**Pause sequence:**
```
StreamPlayer.pause():
  1. set userPaused = true                          (suppress reconnect — see Risk)
  2. setStreamSilenced(true)                        (atomic — instant render-block silence)
  3. pipeline.pauseByUser():
       dataTask.suspend()
       decodeQueue.sync {
           isPausedByUser = true                    (drop gate for late delegate callbacks)
           decoder.clearQueue()                     (drop in-flight packets)
           ringBuffer.flush(newGeneration: false)
       }
  4. set state .paused
```

**Resume sequence:**
```
StreamPlayer.resume():
  1. clear userPaused
  2. pipeline.resumeByUser():
       decodeQueue.sync { isPausedByUser = false; prebufferOnResumeFrames = 0 }
       dataTask.resume()
  3. await prebuffer warmup: availableFrames >= 8192 (≈ 185 ms @ 44.1 kHz)
     OR 1 s hard timeout (treat as terminated → re-issue pipeline.start(url:))
  4. setStreamSilenced(false)                       (render block resumes reading)
```

**Quiescing the producer (Oracle item #1).** A bare `decodeQueue.sync { }` from MainActor is *not* sufficient: URLSession delegate callbacks (`onResponse`, `onData`) run on the delegate operationQueue and dispatch into `decodeQueue` via `context?.handleIncomingData(data)` (`StreamDecodePipeline.swift:537,690`). After the sync returns, late callbacks could still enqueue and write to the ring buffer. Resolution: add an `isPausedByUser` flag to `DecodeContext` (decode-queue-confined, same pattern as `isShutdown` at `StreamDecodePipeline.swift:469`). Set inside the same `decodeQueue.sync` as the flush; checked by `handleIncomingData` and the decode loop to drop work.

**Resume warmup (Oracle item #3).** `formatReadyFired` is one-shot — it does *not* re-arm on resume. Add a `prebufferOnResumeFrames` counter that resets on resume, and an `onPrebufferReady` callback the pipeline fires when the threshold is met. StreamPlayer awaits this (with 1 s hard timeout) before clearing the silence gate.

---

## Files Changed

| File | Change |
|------|--------|
| `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` | Add `pauseByUser()`/`resumeByUser()`. Inside `decodeQueue.sync`: set `isPausedByUser`, call `decoder.clearQueue()`, `ringBuffer.flush(newGeneration: false)`. `handleIncomingData` short-circuits while flag set. Add `prebufferOnResumeFrames` counter + `onPrebufferReady` callback. |
| `MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift` | Add decode-queue-confined `clearQueue()` (drop `packetQueue` + in-flight `currentInputBuffer*`). |
| `MacAmpApp/Audio/StreamPlayer.swift` | `pause()` sets new `userPaused` flag (suppress reconnect), calls `pipeline.pauseByUser()`, sets engine silence gate true. `resume()` waits for `onPrebufferReady` (or timeout) then clears silence gate. `handleTermination` checks `userPaused` and skips `attemptReconnect()` until resume. |
| `MacAmpApp/Audio/AudioEngineController.swift` | `makeStreamRenderBlock` factory takes a `ManagedAtomic<UInt8>` silence gate. While set, zero-fill and return `noErr` with `isSilence = true`. New `setStreamSilenced(_:)` method. Gate created in `activateStreamBridge`, dropped in `deactivateStreamBridge`. |
| `MacAmpApp/Audio/AudioPlayer.swift` | Forwarder method `setStreamSilenced(_:)` to engine controller. |
| `MacAmpApp/Audio/PlaybackCoordinator.swift` | Wire `audioPlayer.setStreamSilenced(_:)` setter into StreamPlayer at bridge activation (similar to existing `onFormatReady` injection at `PlaybackCoordinator.swift:155-163`), OR add direct `setStreamSilenced` forward — see Open Question 1. |
| `MacAmpApp/Audio/LockFreeRingBuffer.swift` | No structural change. Update class doc to note producer-quiesce now spans `dataTask.suspend()` + `isPausedByUser` decode-queue gate. |
| `Tests/MacAmpTests/StreamPauseTailTests.swift` (new) | Five tests, see Verification below. |

Out of scope: SPSC redesign (Principle 5 — keep ring buffer surface minimal); engine graph mutation (Principle 3 — state ownership remains in `AudioEngineController`).

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Late URLSession delegate callback writes to ring buffer after `decodeQueue.sync` returns | High without gate | Stale frames re-appear when silence gate clears | `isPausedByUser` flag on DecodeContext (set inside same sync as flush, checked by `handleIncomingData`). |
| **Reconnect-while-paused (current bug)** — `wasActivelyPlaying` is not cleared by `pause()`. If socket dies during pause, `handleTermination` triggers `attemptReconnect()`, showing "Connecting…" while user is paused (`StreamPlayer.swift:188,116,272`). | High | Surprise re-buffering; UX bug | Add `userPaused` guard checked in `handleTermination`. On resume after socket death, re-issue `pipeline.start(url:)` rather than `dataTask.resume()`. **Fix as part of this task.** |
| TSan false positive on `flush` writing both heads | Low | Test noise | Already documented benign in `LockFreeRingBuffer.swift`. Producer is fully quiesced (suspend + decode-queue gate) before flush. |
| Resume hiccup while ring re-fills | Expected | Audible 50–300 ms gap | Prebuffer-on-resume counter, threshold 8192 frames, 1 s hard timeout. |
| Long pause → server has closed but socket has not yet errored | Medium | Resume produces silence forever | 1 s prebuffer timeout → fall through to fresh `pipeline.start(url:)`. |
| Atomic load on every render callback | Trivial | None | Same `ManagedAtomic` primitive `LockFreeRingBuffer` already uses; relaxed-load cost is negligible. |
| Pause issued during `.connecting`/`.buffering` (no decoded audio yet) | Medium | Silence gate set with empty buffer | Existing `pipeline.stop()` path already handles this (`StreamPlayer.swift:121-122`). Silence gate is a no-op. |
| Pause spam | Medium | Rapid flag flips | Counter and flag operations are confined to single serial `decodeQueue`. |
| Engine config change mid-pause | Low | Same as today | Out of scope (tracked by `video-audio-engine-routing` task). |

**Overall regression risk: LOW–MEDIUM.** No graph mutation, no SPSC redesign, but two new behavioural rules (`userPaused` reconnect-suppression; prebuffer-warmup-on-resume) interact with the existing reconnect state machine — focused tests required.

---

## Verification Approach

1. **Render-block timestamp hook.** `@testable` hook on `AudioEngineController` recording two host-time timestamps in the render block: last non-silent frame, first silent frame after gate set. Delta = measured tail length.
2. **End-to-end loopback recording.** Play a 1 kHz tone via local mock HTTP/MP3 server; pause; capture system audio with BlackHole. Measure trailing audio in Audacity. Validate at 22.05 / 44.1 / 48 kHz.
3. **Swift Testing unit tests** in `Tests/MacAmpTests/StreamPauseTailTests.swift`:
   - `silenceGateProducesZeros` — synthetic ring buffer + render block factory; assert silence flag forces zero output and `isSilence = true`.
   - `pauseDuringBuffering` — `pause()` before `formatReadyFired`; assert no crash, no flush of empty buffer, state transitions correctly.
   - `pauseSpam` — 20 alternating `pause()`/`resume()` within 200 ms; assert no deadlock or leaked state.
   - `longPauseSuppressesReconnect` — `pause()` then simulate `handleStreamComplete(error: NSURLErrorNetworkConnectionLost)`; assert `attemptReconnect()` not called, `isReconnecting` stays false; on subsequent `resume()` expect fresh `pipeline.start(...)`.
   - `tailLengthBound` — drive full pipeline with synthetic producer at 44.1 kHz, fill ring, call `pause()`; assert silence within ≤ 1 render quantum (≈ 11.6 ms) and zero subsequent non-zero frames.
4. **TSan run.** `xcodebuildmcp macos test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — zero new warnings.

**Acceptance criteria:**
- Tail < 25 ms (≤ 1 render quantum + hardware latency) at all three sample rates.
- Resume latency < 500 ms to first audible frame.
- No reconnect events fire while user is paused, even if upstream socket dies.

---

## Open Questions

1. **Wiring `setStreamSilenced(_:)` end-to-end.** Forwarder on `AudioPlayer` (simplest) vs closure injected into StreamPlayer at bridge activation. Plan-phase decision.
2. **`userPaused` flag location.** Recommend `StreamPlayer` (policy layer) over `StreamDecodePipeline` (mechanism layer).
3. **Live-edge vs paused-snapshot on resume after long pause.** Recommend live-edge reconnect for pauses > 5 s — matches Winamp radio expectation. Plan-phase decision.
4. **Same gate for reconnect's bridge-teardown path?** No — reconnect already creates a fresh `LockFreeRingBuffer` (`StreamPlayer.swift:340-342`). Keep gate narrow to user-pause.
5. **Local-file pause path?** No work — `AVAudioPlayerNode.pause()` is sample-accurate.

---

## Oracle Validation Summary

**Reviewer:** Codex CLI (`mcp__codex-cli__codex`, `gpt-5.3-codex`, `reasoningEffort: xhigh`).
**Date:** 2026-04-27. **Forwarded:** this research.md plus six audio source files.

Oracle returned 8 items. All ACTIONABLE items were incorporated:

| # | Severity | Issue | Resolution |
|---|----------|-------|------------|
| 1 | ACTIONABLE-High | `decodeQueue.sync {}` alone does not block late URLSession delegate callbacks | Added `isPausedByUser` decode-queue gate set inside same sync as flush, checked by `handleIncomingData`. |
| 2 | ACTIONABLE-High | `wasActivelyPlaying` not cleared on pause → reconnect can fire while user paused | Added explicit `userPaused` guard; documented as current bug to fix in this task. New test `longPauseSuppressesReconnect`. |
| 3 | ACTIONABLE-Medium | Resume warmup is not "implicitly handled" — `formatReadyFired` is one-shot | Replaced with explicit `prebufferOnResumeFrames` counter that resets on resume + 1 s hard timeout. |
| 4 | ACTIONABLE-Medium | Tail-length numbers were inconsistent (26 ms vs 93 ms) | Unified secondary contributors and produced single ≤ 120 ms upper bound. |
| 5 | ACTIONABLE-Medium | "Generation bump evicts in-flight render frame" claim was incorrect | Removed; atomic silence gate is the actual mechanism. |
| 6 | ACTIONABLE-Medium | Files Changed missed `AudioConverterDecoder`, `AudioPlayer`, possibly `PlaybackCoordinator` | Inventory updated; Open Question 1 added for plan-phase wiring decision. |
| 7 | FALSE-POSITIVE-CANDIDATE | Option D claim "visualizer continues to display bars" overstated | Corrected; verdict on D unchanged. |
| 8 | NITPICK | Sample-rate variability in tail math | Added 22.05/32/44.1/48 kHz table. |

**Verdict:** Approved for plan phase. Items #1 and #2 elevate the implementation from "small" to "small but state-machine-sensitive" — plan must include explicit state-transition diagrams for the new `userPaused` and `isPausedByUser` flags, plus the five edge-case tests above.
