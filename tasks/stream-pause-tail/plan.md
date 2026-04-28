# Plan: Stream Pause Tail

> **Status:** PLANNING — awaiting Oracle gate (target ≥ 9/10).
> **Created:** 2026-04-27
> **Sprint:** S3, Wave **S3-1 Worktree B** (parallel with `mainwindow-visualizer-isolation` Worktree A).
> **Branch:** `fix/stream-pause-tail`
> **PR target:** PR #B (merges sequentially after PR #A from `mwvi`).
> **Predecessors:** none. Parallel start with `mainwindow-visualizer-isolation`.
> **Successors (file-conflict aware):** `hls-streaming-support` (S3-3) and `ogg-vorbis-support` (S3-4) both touch `StreamDecodePipeline.swift` and `StreamPlayer.swift`. See §11.1 for the explicit shared-anchor conflict map and rebase order. Changes here are localized but NOT purely additive: `pause()` / `resume()` bodies are rewritten, and `pipeline.onStateChange` semantics gain a new branch — successor rebases must accept these.
> **Source of truth:** `tasks/stream-pause-tail/research.md` (Oracle-validated 8/8).

---

## 1. Problem Statement

Two concrete failure modes, both observed in the shipped codebase:

### 1a. Audible tail after user pauses an internet radio stream
When the user pauses a running stream, audio continues for ~683 ms – 1.5 s before going silent. Root cause: `LockFreeRingBuffer` is steady-state near-full at 32 768 frames (`StreamPlayer.swift:98`); the producer-side path `dataTask?.suspend()` (`StreamDecodePipeline.swift:229`) only stops new HTTP bytes — already-decoded PCM remains in the ring and is drained by the engine render block (`AudioEngineController.swift:277-303`) at ~5–11 ms per callback. Tail length scales inversely with stream sample rate (44.1 kHz → ~743 ms; 22.05 kHz → ~1486 ms). Verified failure: every Winamp-style "pause this radio station" interaction has audible bleed.

### 1b. Spurious "Connecting…" UI during a long pause
`StreamPlayer.pause()` (`StreamPlayer.swift:116-125`) does not clear `wasActivelyPlaying` (set at `StreamPlayer.swift:188`). If the underlying socket dies while the user is paused (server timeout, network blip, suspended `dataTask` GC'd by URLSession), `handleTermination(_:)` (`StreamPlayer.swift:272-286`) sees `wasActivelyPlaying == true && isReconnectable == true` and fires `attemptReconnect()` (`StreamPlayer.swift:273-274,305-344`). The user sees the title flip to "Connecting…" while still paused, and on resume the reconnect backoff timer is in flight — surprising re-buffering UX.

Both bugs are user-visible regressions of the stream-vs-local-file pause parity introduced by the unified pipeline (T7, PR #57). Local file pause via `AVAudioPlayerNode.pause()` is sample-accurate (no tail), so the gap is asymmetric and noticeable.

---

## 2. Non-Goals

- **NOT** removing the pause UX or replacing it with stop. Pause is a Winamp-fidelity feature.
- **NOT** changing live-stream resume into historical-replay. Streams remain live-edge.
- **NOT** redesigning `LockFreeRingBuffer` SPSC contract. The existing `flush(newGeneration:)` primitive is reused (Principle 5 — minimize API surface).
- **NOT** mutating the AVAudioEngine graph on pause. Lessons #4 and #5 from `tasks/done/unified-audio-pipeline/lessons-learned.md` (-10868 risk) — graph mutation is rejected (Option C in research.md).
- **NOT** applying the silence gate to local-file pause. `AVAudioPlayerNode.pause()` is already sample-accurate.
- **NOT** applying the silence gate to the reconnect path (reconnect already creates a fresh ring buffer at `StreamPlayer.swift:340-342`; gate stays narrow to user-pause — research.md Open Question 4).
- **NOT** enabling EQ/balance changes during the silenced render. Both remain wired the same way; silenced output is just zeros.
- **NOT** changing reconnect policy semantics for socket failures during *active playback* (`wasActivelyPlaying` still drives reconnect when the user has not paused).
- **NOT** changing `isReconnectable(_:)` classification of any termination reason.

---

## 3. Pre-Decomposition Gate Checklist (per `tasks/_context/principles.md`)

This task is **behavior-bug + small extraction**, not structural decomposition. We still complete the gate:

- [x] **1. Problem statement written** — see §1 (audible tail + spurious reconnect).
- [x] **2. Non-goals listed** — see §2.
- [x] **3. Principles contract approved:**
  - **P1 Problem-First:** both failures are concrete, user-visible, reproducible.
  - **P2 Cohesion > Line Count:** changes are localized to existing owners. No new files split state machines.
  - **P3 State Ownership Sacred:** `userPaused` lives in `StreamPlayer` (policy layer); `isPausedByUser` lives in `DecodeContext` (mechanism, queue-confined); silence gate atomic lives in `AudioEngineController` alongside the bridge state it gates. Each piece of new state has exactly one owner and one writer.
  - **P4 Rule of Three (AHA):** silence-gate atomic is a **safety invariant** (RT thread coordination) — exception clause permits extraction at first occurrence. No flag-driven abstraction is introduced.
  - **P5 API Surface Minimization:** no `private→internal` widening on `LockFreeRingBuffer` (Open Question 4 close-out: gate stays narrow). New `setStreamSilenced(_:)` is a forwarder, no internal state widening on `AudioEngineController`. `ringBuffer.flush(newGeneration: false)` is already a documented public method.
  - **P6 No Pass-Through Middlemen:** `AudioPlayer.setStreamSilenced(_:)` is a thin forwarder; it is justified by the same facade pattern the file already uses (`activateStreamBridge`, `deactivateStreamBridge`, `setVolume`) — no new middleman layer is introduced. PlaybackCoordinator does **not** add a passthrough — it owns the wiring decision and forwards via the existing facade.
  - **P7 ADR + Kill Switch:** see §10 (Stop Criteria) and §12 (Rollback Plan).
- [x] **4. Responsibility map exists:** see §6.5.
- [x] **5. Complexity assessed:** changes affect existing ~700-line files (`StreamDecodePipeline`, `AudioEngineController`) without new files. Largest insertion: ~50 LOC of state-machine wiring across two files plus ~80 LOC of new tests. Cognitive complexity stays bounded — only one new state-machine flag per layer.
- [x] **6. Candidate split scored:** No structural split is proposed. The only "extraction" is a single atomic primitive (`streamSilenceGate`) inside `AudioEngineController`. Score: cohesion gain HIGH (RT-safe primitive lives next to render block), state risk LOW (single writer = MainActor `setStreamSilenced`, single reader = render block), visibility impact NONE (private), pass-through risk NONE (forwarder is a facade method).
- [x] **7. Public/internal API delta listed:**
  - `AudioPlayer`: + `func setStreamSilenced(_ silenced: Bool)` (internal — facade pattern). + `var isStreamSilenceGateActive: Bool { get }` (internal, debug/test only).
  - `AudioEngineController`: + `func setStreamSilenced(_ silenced: Bool)` (internal). + `var isStreamSilenceGateActive: Bool { get }` (internal, debug/test only).
  - `StreamDecodePipeline`: + `func pauseByUser()` and `+ func resumeByUser()` (internal). + `var onPrebufferReady: (@MainActor @Sendable () -> Void)?` (internal). Existing `pause()`/`resume()` retained but become **call-site-private** (only `pauseByUser()`/`resumeByUser()` are wired in).
  - `AudioConverterDecoder`: + `func clearQueue()` (internal, decode-queue-confined).
  - `LockFreeRingBuffer`: NO API change. Doc string updated only.
  - `StreamPlayer.pause()` signature unchanged. New private state: `userPaused: Bool`, `prebufferReadyContinuation: CheckedContinuation<Void, Never>?`, `silenceGateForwarder: (@MainActor (Bool) -> Void)?`.
- [x] **8. Stop criteria defined** — see §10.

**Hard gate cleared.** Items 1–5 complete; structural-edit gate is satisfied even though this is primarily behavioral.

---

## 4. Architecture Decision Record (ADR)

### ADR-SPT-1: Hybrid Option A + thin Option B
**Decision:** Producer-quiesce + ring-buffer flush (Option A) **plus** a relaxed-load atomic silence gate read in the render block (Option B).
**Drivers:** Option A alone has a quiesce window where late URLSession delegate callbacks could write past the flush. Option B alone leaves stale frames in the ring at resume time. Together: gate gives instant silence (≤ 1 render quantum, ~11 ms), flush evicts the stale window, prebuffer warmup re-fills before unmuting.
**Trade-off accepted:** one relaxed atomic load per render callback (~1 ns on Apple Silicon — negligible vs. ~10 ms render quantum).
**Kill switch:** see §10.

### ADR-SPT-2: `userPaused` lives in `StreamPlayer`, `isPausedByUser` lives in `DecodeContext`
**Decision:** Two separate flags, one per layer. `StreamPlayer.userPaused` is policy ("the user wants pause"). `DecodeContext.isPausedByUser` is mechanism ("the decode queue should drop incoming work"). They are written together in the pause sequence but serve different consumers.
**Why not one flag?** Crossing the MainActor → decode-queue boundary requires a queue-confined mirror; merging would either widen `DecodeContext` Sendable surface or require `@MainActor` reads on the decode queue (forbidden — research.md root-cause analysis).
**Principle 3 compliance:** each flag has a single writer in its owning layer; no shared mutable state.

### ADR-SPT-3: Silence gate is owned by `AudioEngineController`
**Decision:** The `ManagedAtomic<UInt8>` gate is created in `activateStreamBridge`, captured into the render block factory, and dropped in `deactivateStreamBridge`. Lifetime exactly matches the bridge.
**Why not StreamPlayer or AudioPlayer?** The render block is built in `AudioEngineController.makeStreamRenderBlock` and is the only consumer. Co-locating the gate eliminates a cross-actor capture and matches the same pattern used for the ring buffer.
**Side effect:** when the bridge is deactivated and re-activated (reconnect path), a fresh atomic is created — no stale state carry-over.

### ADR-SPT-4: Wiring of `setStreamSilenced` (resolves research.md Open Question 1)
**Decision:** **Forwarder on `AudioPlayer`.** `AudioPlayer.setStreamSilenced(_:)` calls `engine.setStreamSilenced(_:)`. `PlaybackCoordinator` exposes a closure to `StreamPlayer` at construction:
```swift
self.streamPlayer.silenceGateForwarder = { [weak self] silenced in
    self?.audioPlayer.setStreamSilenced(silenced)
}
```
**Why this over closure-injected-at-bridge-activation?** The bridge can be inactive when `pause()` runs (research Risk row 8: "Pause issued during .connecting/.buffering"). A forwarder defined at coordinator init is always available; the engine internally no-ops when the bridge is inactive. This matches the existing `setVolume`/`setBalance` pattern.
**Principle 6 compliance:** the forwarder is a *facade* method on `AudioPlayer`, the same pattern used by `activateStreamBridge`, `deactivateStreamBridge`, `setVolume`, `setBalance`. Not a new pass-through layer.

### ADR-SPT-5: Live-edge on resume after long pause (resolves Open Question 3)
**Decision:** **Best-effort first; live-edge fallback after timeout.** Resume tries `dataTask.resume()`; if `prebufferOnResumeFrames` does not reach 8 192 frames (~185 ms @ 44.1 kHz) within 1 s, treat the connection as terminated and re-issue `pipeline.start(url:)` with a fresh ring buffer (live-edge reconnect). This matches Winamp 5 radio expectations: short pauses keep the existing socket; long pauses reconnect to live.
**Single threshold:** No 5 s "always live" branch — the 1 s prebuffer timeout subsumes it. If the socket is healthy after a 30 s pause, it will refill in <1 s; if it is dead, the timeout fires once and reconnect begins.

### ADR-SPT-6: Latent reconnect-during-pause bug fixed in this PR
**Decision:** Bundle the `userPaused` reconnect-suppression fix into this task's PR (research Risk row 2). It is part of the same state machine and the same edge-case test set; deferring it would leave a half-correct pause state machine.

---

## 5. Implementation Phases

Each phase is individually reviewable and individually testable. Tests are introduced in Phase 8 but referenced from earlier phases for traceability.

### Phase 1 — `LockFreeRingBuffer` doc-only update (Principle 5: minimize)
**File:** `MacAmpApp/Audio/LockFreeRingBuffer.swift`
**Lines:** existing doc on `flush(newGeneration:)` at `LockFreeRingBuffer.swift:136-149`.
**Change:** doc-only. Append:
> Producer-quiesce contract for stream pause: caller must (a) call `dataTask.suspend()`, (b) submit a barrier sync to the decode queue that sets `DecodeContext.isPausedByUser = true` and clears the decoder packet queue, and (c) only then call `flush(newGeneration: false)` from inside that same sync block. Late URLSession delegate callbacks already enqueued on the delegate operationQueue will be no-ops because they consult `isPausedByUser` before writing to the ring.

**No structural change.** No `flush(newGeneration: false)` API addition (already exists at `LockFreeRingBuffer.swift:140`).
**Verification:** Phase 8 test `silenceGateProducesZeros` covers the documented contract at unit-test level.

---

### Phase 2 — Silence gate atomic primitive in `AudioEngineController`
**File:** `MacAmpApp/Audio/AudioEngineController.swift`

**2.1 Add bridge-scoped silence gate (Principle 3 — one writer, one reader).**
At class scope alongside `streamSourceNode` (`AudioEngineController.swift:32-34`), add:
```swift
private var streamSilenceGate: ManagedAtomic<UInt8>?
```
Add `import Atomics` at the top of the file (currently uses `import AVFoundation` only — `LockFreeRingBuffer.swift` already pulls in Atomics, so the package is wired).

**2.2 Update render-block factory to read the gate.**
Replace `makeStreamRenderBlock(ringBuffer:)` (`AudioEngineController.swift:277-303`) with:
```swift
private nonisolated static func makeStreamRenderBlock(
    ringBuffer: LockFreeRingBuffer,
    silenceGate: ManagedAtomic<UInt8>
) -> AVAudioSourceNodeRenderBlock {
    { isSilence, _, frameCount, outputData in
        let ablPointer = UnsafeMutableAudioBufferListPointer(outputData)
        guard ablPointer.count == 1,
              let firstBuffer = ablPointer.first,
              firstBuffer.mNumberChannels == 2,
              let data = firstBuffer.mData else {
            isSilence.pointee = ObjCBool(true)
            return noErr
        }

        let floatPtr = data.assumingMemoryBound(to: Float.self)
        let channelCount = Int(firstBuffer.mNumberChannels)
        let frames = Int(frameCount)

        // Silence gate: relaxed load, render-thread-safe.
        if silenceGate.load(ordering: .relaxed) != 0 {
            memset(floatPtr, 0, frames * channelCount * MemoryLayout<Float>.size)
            isSilence.pointee = ObjCBool(true)
            return noErr
        }

        let framesRead = ringBuffer.read(into: floatPtr, frameCount: frames)
        if framesRead < frames {
            let remainingSamples = (frames - framesRead) * channelCount
            let offset = framesRead * channelCount
            memset(floatPtr + offset, 0, remainingSamples * MemoryLayout<Float>.size)
        }
        isSilence.pointee = ObjCBool(framesRead == 0)
        return noErr
    }
}
```
Allocate the gate in `activateStreamBridge` BEFORE calling the factory (`AudioEngineController.swift:325`):
```swift
let gate = ManagedAtomic<UInt8>(0)
streamSilenceGate = gate
let renderBlock = Self.makeStreamRenderBlock(ringBuffer: ringBuffer, silenceGate: gate)
```
Drop in `deactivateStreamBridge` (`AudioEngineController.swift:399-401`):
```swift
streamSilenceGate = nil
```

**2.3 Add gate setter (single writer = MainActor).**
After `setBalance(_:)` (`AudioEngineController.swift:267-270`):
```swift
/// Silence the stream render block. Atomic; safe to call before the bridge is active (no-op).
/// Producer side (decode queue) MUST be quiesced and ring buffer flushed BEFORE clearing.
func setStreamSilenced(_ silenced: Bool) {
    streamSilenceGate?.store(silenced ? 1 : 0, ordering: .releasing)
}

#if DEBUG
var isStreamSilenceGateActive: Bool {
    (streamSilenceGate?.load(ordering: .relaxed) ?? 0) != 0
}
#endif
```

**Tests:** `silenceGateProducesZeros` (Phase 8). Manual: set gate, observe muted output.

---

### Phase 3 — Producer-quiesce hooks in `StreamDecodePipeline`
**File:** `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift`

**3.1 Add `isPausedByUser` to `DecodeContext` (queue-confined).**
After `private var isShutdown: Bool = false` (`StreamDecodePipeline.swift:469`):
```swift
private var isPausedByUser: Bool = false
```

**3.2 Gate `handleIncomingData` on the new flag.**
At `StreamDecodePipeline.swift:537-557`, replace the body's first guard:
```swift
func handleIncomingData(_ data: Data) {
    decodeQueue.async { [self] in
        guard !isShutdown, !isPausedByUser else { return }
        // ... existing body
    }
}
```
Also gate the inner `while decoder.hasQueuedPackets` loop in `handlePackets(...)` (`StreamDecodePipeline.swift:642-644`):
```swift
while decoder.hasQueuedPackets {
    guard !isShutdown, !isPausedByUser else { break }
    // ... existing
}
```

**3.3 Add decode-queue-confined `setPausedByUser(_:)` and `resetPrebufferTracking(...)` to `DecodeContext` — strict ordering enforced (Oracle item #1 fidelity, research.md root-cause analysis).**
Inserted before `shutdown()` (`StreamDecodePipeline.swift:561`):
```swift
/// Set the user-pause gate. Drops late URLSession callbacks that arrive after pause.
///
/// **Ordering invariant (research.md root-cause analysis, Oracle item #1):** within the
/// same decodeQueue.async block, in this exact order:
///   1. set isPausedByUser = true                  (gate raised — late callbacks short-circuit)
///   2. decoder?.clearQueue()                      (drop in-flight compressed packets)
///   3. ringBuffer.flush(newGeneration: false)     (drop decoded PCM)
/// The serial decode queue guarantees no other handleIncomingData / handlePackets executes
/// between steps. By the time `flush` runs, the producer is fully quiesced for this context.
func setPausedByUser(_ paused: Bool, completion: @escaping @Sendable () -> Void) {
    decodeQueue.async { [self] in
        guard !isShutdown else { completion(); return }
        isPausedByUser = paused                     // step 1: gate first
        if paused {
            decoder?.clearQueue()                   // step 2
            ringBuffer.flush(newGeneration: false)  // step 3
        }
        completion()
    }
}

/// Reset prebuffer state on resume so onPrebufferReady can fire again.
func resetPrebufferTracking(completion: @escaping @Sendable () -> Void) {
    decodeQueue.async { [self] in
        guard !isShutdown else { completion(); return }
        prebufferedFrames = 0
        prebufferReadyFiredOnResume = false
        completion()
    }
}
```

**3.4 Add `prebufferReadyFiredOnResume` and `onPrebufferReady` plumbing to `DecodeContext`.**
After `private var formatReadyFired: Bool = false` (`StreamDecodePipeline.swift:467`):
```swift
private var prebufferReadyFiredOnResume: Bool = true   // start at "true" so it doesn't fire on first stream
```
Add a callback and a separate threshold:
```swift
private static let resumePrebufferThreshold: Int = 8192

private let onPrebufferReady: @Sendable (UInt64) -> Void
```
Wire it through the existing `init` (`StreamDecodePipeline.swift:481-495`) — add `onPrebufferReady` parameter, store it.

In `handlePackets` after `prebufferedFrames += framesWritten` (`StreamDecodePipeline.swift:647`):
```swift
if !prebufferReadyFiredOnResume && prebufferedFrames >= Self.resumePrebufferThreshold {
    prebufferReadyFiredOnResume = true
    onPrebufferReady(generation)
}
```
The existing `formatReadyFired` first-format-ready path (`StreamDecodePipeline.swift:649-652`) is **untouched**. It continues to fire once per stream via the larger 16 384-frame threshold (`prebufferThreshold` at `StreamDecodePipeline.swift:475`).

**3.5 Pipeline-level `pauseByUser()` / `resumeByUser()` — await decode-queue barrier.**
Replace `pause()` / `resume()` (`StreamDecodePipeline.swift:227-237`) with async-barrier variants. The MainActor caller must await the decode-queue completion to guarantee the silence gate stays raised until ring + decoder are fully drained — otherwise a render-block overlap could observe stale frames between gate-set and flush completion.

```swift
func pause() {
    // Legacy sync entry — kept for source-compat. Issues an async barrier under the hood.
    // Internal callers SHOULD use pauseByUser() to await ordering.
    Task { @MainActor [weak self] in await self?.pauseByUser() }
}

func resume() {
    Task { @MainActor [weak self] in await self?.resumeByUser() }
}

func pauseByUser() async {
    guard case .playing = state else { return }
    if Task.isCancelled { return }
    dataTask?.suspend()
    // Await decode-queue barrier: gate-set + decoder.clearQueue + ring.flush in same block.
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        guard let ctx = decodeContext else { cont.resume(); return }
        ctx.setPausedByUser(true) { cont.resume() }
    }
    if Task.isCancelled { return }
    // Re-check state: a concurrent stop() could have torn down the pipeline mid-await.
    guard case .playing = state else { return }
    setState(.paused)
}

func resumeByUser() async {
    guard case .paused = state else { return }
    // Cancellation fence #1: bail before the first decode-queue barrier if a stop()
    // arrived since this task was scheduled.
    if Task.isCancelled { return }
    // Reset prebuffer tracking BEFORE clearing pause flag so the first incoming bytes
    // count against the resume threshold (not stale pre-pause counter).
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        guard let ctx = decodeContext else { cont.resume(); return }
        ctx.resetPrebufferTracking { cont.resume() }
    }
    if Task.isCancelled { return }
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        guard let ctx = decodeContext else { cont.resume(); return }
        ctx.setPausedByUser(false) { cont.resume() }
    }
    if Task.isCancelled { return }
    // Re-check state: a concurrent stop()/handleTermination could have torn down
    // the pipeline mid-await. dataTask?.resume() on a cancelled task is harmless,
    // but setState(.playing) on a torn-down pipeline would emit a stale callback.
    guard case .paused = state else { return }
    dataTask?.resume()
    // Pipeline returns to .playing here for URLSession-state consistency.
    // StreamPlayer keeps isBuffering=true until prebuffer warmup completes —
    // the user-visible "playing" transition happens in startResumeWarmup() when
    // the silence gate is dropped. wasActivelyPlaying is NOT touched on resume:
    // it remains true (sticky from initial play), so a socket death during the
    // warmup window still routes through handleTermination's userPaused/active
    // checks correctly.
    setState(.playing)
}
```

**Why barrier is required (research item #1 fidelity):** the MainActor pause path sets the engine's silence gate before quiescing the producer. Without the barrier, the producer-quiesce decode-queue block races with delivery of any late packets currently in flight from the URLSession delegate queue. The barrier guarantees that by the time `pauseByUser` returns to its caller (StreamPlayer.pause), the ring buffer is empty and `isPausedByUser=true` on the decode queue — so any URLSession delegate callback dispatched after the barrier completes is a no-op.

**3.6 Wire `onPrebufferReady` from `DecodeContext` → pipeline → MainActor callback.**
Add to `StreamDecodePipeline` (alongside `onFormatReady` at line 56):
```swift
var onPrebufferReady: (@MainActor @Sendable () -> Void)?
```
In `startDirectStream` (`StreamDecodePipeline.swift:144-175`), pass to `DecodeContext`:
```swift
onPrebufferReady: { [weak self] gen in
    Task { @MainActor [weak self] in
        guard let self, gen == self.generation else { return }
        self.onPrebufferReady?()
    }
},
```

**Verification:** Phase 8 tests `pauseDuringBuffering`, `pauseSpam`. Manual: pause active stream — `Console.app` shows `setPausedByUser(true)` log immediately, no further `handlePackets` activity until `resumeByUser`.

---

### Phase 4 — `AudioConverterDecoder.clearQueue()`
**File:** `MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift`

After `enqueue(...)` (`AudioConverterDecoder.swift:130-133`):
```swift
/// Drop all queued packets and the in-flight input buffer.
/// Called from the decode queue when user pauses, to prevent stale audio
/// from continuing through the pipeline after pause.
/// Idempotent — safe to call when already empty.
func clearQueue() {
    assertConfinement()
    packetQueue.removeAll()
    freeCurrentInput()
}
```
Note: `dispose()` (`AudioConverterDecoder.swift:231-239`) already does `packetQueue.removeAll() + freeCurrentInput()`. We don't reuse `dispose()` because that also tears down the converter. **Principle 4 compliance:** this is the **second** caller of the same internal pattern; safety-invariant exception applies (decode-queue confinement). Extract `clearQueue()` rather than duplicating the two-line pattern at the user-pause call site.

**Verification:** unit test in Phase 8 `pauseDuringBuffering` — enqueue 5 packets, call `clearQueue`, assert `hasQueuedPackets == false`.

---

### Phase 5 — `StreamPlayer` orchestration & resume warmup
**File:** `MacAmpApp/Audio/StreamPlayer.swift`

**5.1 Add private state.**
Near other `@ObservationIgnored` blocks (`StreamPlayer.swift:64-69`):
```swift
@ObservationIgnored private var userPaused: Bool = false
@ObservationIgnored private var prebufferReadyContinuation: CheckedContinuation<Void, Never>?
@ObservationIgnored private var resumeWarmupTask: Task<Void, Never>?
@ObservationIgnored private var isResumeWarming: Bool = false

/// Serializes async pipeline transport calls (pauseByUser / resumeByUser / start) to
/// prevent rapid pause→resume→pause from racing across MainActor hops. Each new transport
/// dispatch chains onto this task so the order observed by URLSession + decode queue
/// matches the call order. ADR-SPT-8.
@ObservationIgnored private var pipelineTransportTask: Task<Void, Never>?

/// Set by PlaybackCoordinator at construction (ADR-SPT-4 forwarder pattern).
/// Closure form preserves Principle 6 (no pass-through layer) — calls AudioPlayer.setStreamSilenced.
@ObservationIgnored var silenceGateForwarder: (@MainActor (Bool) -> Void)?
```

**5.2 Wire `pipeline.onPrebufferReady`.**
In `setupPipelineCallbacks()` (`StreamPlayer.swift:172-229`), after the existing `pipeline.onFormatReady` wiring (line 208):
```swift
pipeline.onPrebufferReady = { [weak self] in
    guard let self else { return }
    self.prebufferReadyContinuation?.resume()
    self.prebufferReadyContinuation = nil
}
```

**5.2.5 Helper: chain a pipeline transport call onto the serial transport task.**
Add to `StreamPlayer` (after `cancelResumeWarmup()`):
```swift
/// Append an async pipeline transport operation to the serial transport task chain.
/// Guarantees ordering: rapid pause→resume→pause runs as exactly that sequence on the
/// pipeline + decode queue, never interleaved.
private func chainTransport(_ op: @escaping @MainActor @Sendable () async -> Void) {
    let prior = pipelineTransportTask
    pipelineTransportTask = Task { @MainActor [weak self] in
        await prior?.value
        guard !Task.isCancelled, self != nil else { return }
        await op()
    }
}
```

**5.3 Replace `pause()`.**
Replace `StreamPlayer.swift:116-125`:
```swift
func pause() {
    cancelResumeWarmup()                       // drain any in-flight warmup
    cancelReconnect()
    stopElapsedTimer()
    userPaused = true
    silenceGateForwarder?(true)                // step 1: instant render-block silence (atomic, no-op if bridge inactive)

    if case .connecting = pipeline.state {
        pipeline.stop()                        // pre-bridge: no producer to quiesce
    } else if case .buffering = pipeline.state {
        pipeline.stop()
    } else {
        // step 2: producer quiesce + flush ring inside decode queue.
        // Chained onto the serial transport task: any in-flight resumeByUser from a
        // prior `resume()` call completes BEFORE this pauseByUser runs. This guarantees
        // pipeline.state is .playing when pauseByUser checks its guard, so the barrier
        // actually fires (no silent no-op on rapid pause→resume→pause).
        chainTransport { [weak self] in
            await self?.pipeline.pauseByUser()
        }
    }

    isPlaying = false
    isBuffering = false
    // wasActivelyPlaying is intentionally NOT cleared — kept for resume-after-socket-death detection.
}
```

**5.4 Replace `resume()`. Add `isResumeWarming` flag.**
Add at `StreamPlayer.swift:64-69` block:
```swift
@ObservationIgnored private var isResumeWarming: Bool = false
```
This flag suppresses the "playing" transition in `pipeline.onStateChange` while the warmup task owns the user-visible state.

Replace `StreamPlayer.swift:127-138`:
```swift
func resume() {
    cancelResumeWarmup()                            // defensive — drain any prior warmup
    userPaused = false

    // CRITICAL: branch decision happens INSIDE the chained task body — after any
    // in-flight pauseByUser() completes — so pipeline.state read here is accurate.
    // Reading state outside the chain races with prior async transport calls.
    isResumeWarming = true                          // suppress onStateChange isPlaying flip
    isBuffering = true                              // user-visible: still warming
    startResumeWarmup()                             // arm the prebuffer/timeout race ASAP
    chainTransport { [weak self] in
        guard let self else { return }
        guard !Task.isCancelled else { return }     // stop() / handleTermination cancelled chain

        if case .paused = self.pipeline.state {
            // Healthy pause→resume: pipeline still alive, dataTask suspended. Resume.
            await self.pipeline.resumeByUser()
        } else if let station = self.currentStation {
            // Pipeline was torn down silently while paused (long pause + socket death).
            // pipeline.state at this point is .error(...) (set in handleStreamComplete
            // before our handleTermination ran — see StreamDecodePipeline.swift:344-345),
            // OR .idle if the user never had an active connection. Either way, neither
            // state supports resumeByUser, so we live-edge restart.
            //
            // The warmup task is already running; we don't abort it because pipeline.start
            // produces onPrebufferReady via the new DecodeContext, which drains the
            // warmup continuation as soon as ≥8192 frames buffer.
            let rb = LockFreeRingBuffer(capacity: 32768, channelCount: 2)
            self.ringBuffer = rb
            self.pipeline.start(url: station.streamURL, ringBuffer: rb)
            // pipeline.onFormatReady → PlaybackCoordinator activates fresh bridge AND clears gate.
        } else {
            // No paused pipeline AND no station — nothing to resume. Cancel the warmup.
            self.cancelResumeWarmup()
        }
    }
}
```

**5.4.1 Update `pipeline.onStateChange` to honour `isResumeWarming`.**
In `setupPipelineCallbacks()` (`StreamPlayer.swift:173-201`), the `case .playing` branch:
```swift
case .playing:
    if self.isResumeWarming {
        // Warmup task owns user-visible state. Pipeline transport is correct (URLSession
        // resumed) but render output is still gated. Do NOT flip isPlaying here.
        // The warmup task will set isPlaying = true after the silence gate drops, OR
        // it will fall through to the fresh-start branch on timeout.
        // wasActivelyPlaying stays true (sticky); startPlaybackStableTimer is a no-op
        // (already running) so we still call it for consistency.
        self.startPlaybackStableTimer()
    } else {
        self.isPlaying = true
        self.isBuffering = false
        self.isReconnecting = false
        self.wasActivelyPlaying = true
        self.startPlaybackStableTimer()
        self.startElapsedTimer()
    }
```

**5.4.2 Clear `isResumeWarming` in the warmup completion.**
In `startResumeWarmup()` (Phase 5.5 below) — after the gate is dropped on healthy resume:
```swift
self.silenceGateForwarder?(false)
self.isBuffering = false
self.isResumeWarming = false                    // releases onStateChange to its normal path
self.isPlaying = true
self.startElapsedTimer()                         // resume elapsed counter from where it left off
```
And on the live-edge fresh-start branch:
```swift
self.isResumeWarming = false
let fresh = LockFreeRingBuffer(...)
// ...
```

**5.5 Warmup helper — single owned task + identity-guarded property writes.**
The continuation lifecycle is brittle under pause-spam. Following ADR-SPT-7 (below): exactly one owned task, one owned continuation; both are drained at every entry-point that invalidates the warmup (`pause`, `stop`, `play`, `handleTermination`). The 1s timeout is a sibling sub-`Task` that drains the continuation if the parent is still awaiting it. A monotonic `resumeWarmupGeneration` counter prevents a stale task body from clobbering `resumeWarmupTask` after a newer warmup has been spawned (Oracle iter-4 finding).

Add to `StreamPlayer` (after `cancelReconnect()` at `StreamPlayer.swift:346`):
```swift
/// Monotonic identity for the active warmup cycle. Used to guard `resumeWarmupTask = nil`
/// writes from stale tasks (a cancelled task running its post-await tail must not clobber
/// a newly-assigned warmup task).
@ObservationIgnored private var resumeWarmupGeneration: UInt64 = 0

/// Cancel any in-flight warmup task and drain a stranded continuation.
/// Safe to call from any state. Idempotent. Order matters: drain continuation FIRST so the
/// child task observes a resumed continuation before it sees `Task.isCancelled` — this lets
/// the child task exit cleanly via the awaited `withCheckedContinuation` path rather than
/// requiring an `onCancel` handler.
///
/// Increments `resumeWarmupGeneration` so any stale task running its tail will not nil
/// `resumeWarmupTask` (the new generation owns that property).
private func cancelResumeWarmup() {
    if let pending = prebufferReadyContinuation {
        prebufferReadyContinuation = nil
        pending.resume()                            // drain first
    }
    resumeWarmupTask?.cancel()                      // then cancel the task
    resumeWarmupTask = nil
    isResumeWarming = false                         // clear flag synchronously with cancel
    resumeWarmupGeneration &+= 1                    // invalidate any in-flight task's nil-out write
}

/// Begin resume warmup. Single owned MainActor task with a sibling timeout sub-Task
/// that drains the prebuffer continuation if the 1s deadline elapses.
/// Caller must ensure no prior warmup is in flight (`cancelResumeWarmup()` at every
/// entry-point that invalidates a resume).
private func startResumeWarmup() {
    // Defensive: drain any lingering state from prior cycles.
    cancelResumeWarmup()
    isResumeWarming = true                          // re-arm after cancelResumeWarmup cleared it

    resumeWarmupGeneration &+= 1
    let myGeneration = resumeWarmupGeneration
    resumeWarmupTask = Task { @MainActor [weak self] in
        guard let self else { return }

        /// Identity-guarded property writer: only nil out resumeWarmupTask if we're still
        /// the active generation. Otherwise a newer warmup owns it and we must not clobber.
        @MainActor func clearTaskIfMine() {
            if self.resumeWarmupGeneration == myGeneration {
                self.resumeWarmupTask = nil
            }
        }

        // Manual two-task race using a single MainActor parent task plus a timeoutTask
        // sub-task that drains the continuation so the parent's withCheckedContinuation
        // cannot hang. Cancellation: cancelResumeWarmup() drains the continuation first,
        // then cancels the parent task; timeoutTask's `try? await Task.sleep` cancels
        // benignly on its next suspension.
        let timeoutTask: Task<Void, Never> = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self else { return }
            // Drain continuation if still ours — wakes child-1 cleanly.
            if let pending = self.prebufferReadyContinuation {
                self.prebufferReadyContinuation = nil
                pending.resume()
            }
        }

        // Child task: await prebuffer-ready (or timeout-driven drain).
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            // If gate already drained pre-arming, short-circuit.
            if let rb = self.ringBuffer, rb.availableFrames >= 8192 {
                cont.resume()
                return
            }
            // If a prior continuation was somehow not cleaned up, drain it now.
            // (Belt-and-suspenders: cancelResumeWarmup at startResumeWarmup top should have done this.)
            if let stale = self.prebufferReadyContinuation {
                self.prebufferReadyContinuation = nil
                stale.resume()
            }
            self.prebufferReadyContinuation = cont
        }

        // Cancel the timeout if it hasn't fired (we got prebuffer-ready first).
        // If it has fired, this is a no-op.
        timeoutTask.cancel()

        // Detect whether we landed here via timeout or prebuffer-ready by inspecting
        // ring buffer state. Either path has resumed the continuation exactly once.
        let timedOut: Bool = (self.ringBuffer?.availableFrames ?? 0) < 8192

        // After this point: continuation has been resumed exactly once
        // (by onPrebufferReady, by timeout, or by cancellation). prebufferReadyContinuation
        // is nil. Re-validate state.

        guard !Task.isCancelled, !self.userPaused else {
            clearTaskIfMine()                       // identity-guarded nil
            return
        }

        // Determine whether we have enough buffer.
        let rb = self.ringBuffer
        let havePrebuffer = (rb?.availableFrames ?? 0) >= 8192

        if timedOut && !havePrebuffer {
            // Treat as terminated: live-edge restart.
            self.isResumeWarming = false            // release onStateChange to normal path
            clearTaskIfMine()
            if let station = self.currentStation {
                let fresh = LockFreeRingBuffer(capacity: 32768, channelCount: 2)
                self.ringBuffer = fresh
                self.pipeline.start(url: station.streamURL, ringBuffer: fresh)
                // PlaybackCoordinator.onFormatReady → activateStreamBridge + setStreamSilenced(false).
            }
            return
        }

        // Healthy resume (either prebuffer reached threshold, or timed out but ring
        // happens to have ≥8192 frames anyway — accept it and unmute).
        self.silenceGateForwarder?(false)
        self.isBuffering = false
        self.isResumeWarming = false                // release onStateChange to normal path
        self.isPlaying = true
        self.startElapsedTimer()                    // resume elapsed counter
        clearTaskIfMine()
    }
}
```

**Resume-warmup completion guarantees:**
- `prebufferReadyContinuation` is nil whenever `resumeWarmupTask` is nil.
- `resumeWarmupTask` is nil whenever `isResumeWarming` is false (audited by Phase 8 `pauseSpam`).
- The identity-guarded `clearTaskIfMine()` helper at every return point of the task ensures `resumeWarmupTask` does not linger as a completed-but-still-referenced handle, AND a stale task tail cannot clobber a newly-assigned warmup task.

**Single-owner invariant audit:**
- `prebufferReadyContinuation` writers: only `startResumeWarmup` (set), `pipeline.onPrebufferReady` (consume + nil), timeout sub-task (consume + nil), `cancelResumeWarmup` (drain + nil), `handleTermination` (drain + nil).
- `resumeWarmupTask` writers: only `startResumeWarmup` (assign), `cancelResumeWarmup` (cancel + nil).
- All MainActor-isolated. Pause-spam scenario: each `pause()` calls `cancelResumeWarmup()` which cancels the task and drains the continuation; each `resume()` calls `startResumeWarmup()` which itself drains defensively before installing.

### ADR-SPT-7: Warmup is a single owned task with continuation-draining timeout sub-task
**Decision:** `resumeWarmupTask` is a single MainActor `Task`. Inside it: a `timeoutTask` sub-task is spawned that, after `Task.sleep(for: .seconds(1))`, drains `prebufferReadyContinuation` if still set. The parent task `await`s `withCheckedContinuation` — the continuation is resumed by exactly one of three drivers: (a) `pipeline.onPrebufferReady` callback, (b) the timeout sub-task, (c) `cancelResumeWarmup()`. After the await returns, the parent inspects `ringBuffer.availableFrames` to decide healthy resume vs. live-edge restart. Cancellation: `cancelResumeWarmup()` drains the continuation first, then cancels `resumeWarmupTask`, which transitively no-ops the timeout sub-task on its next suspension.
**Why not `withTaskGroup`?** Tried in iter-3 — child task awaiting `withCheckedContinuation` is not cancellation-aware, so when the timeout child wins, `group.cancelAll()` doesn't actually wake the prebuffer child. The current shape (timeout drains the continuation) explicitly closes that gap.
**Why not `withTaskCancellationHandler`?** `cancelResumeWarmup()` already drains the continuation synchronously on MainActor before cancelling. The handler-based approach was redundant and added an unstructured nested `Task`.
**Why not a `DispatchWorkItem` or `Timer`?** Both create lifecycle complexity equivalent to two Tasks. Structured `Task` keeps cancellation linear.

### ADR-SPT-8: Pipeline transport calls are serialized via a chained Task
**Decision:** `pause()` and `resume()` schedule their async pipeline transport (`pauseByUser`/`resumeByUser`) onto a single serial `pipelineTransportTask` chain. Each new call awaits the prior task's `.value` before its own body runs.
**Why:** `pause()` is sync at the StreamPlayer API; the `pauseByUser`/`resumeByUser` calls inside are async (decode-queue barrier). Without serialization, rapid pause→resume→pause within ~1ms can have `pause`'s `pauseByUser` run before `resume`'s `resumeByUser` completes its `setState(.playing)`. `pauseByUser` would then see `state == .paused`, no-op, and the user's intent is lost — pipeline ends up in `.playing` while the silence gate stays raised, producing a stuck-silenced stream.
**Cost:** one MainActor `await prior?.value` per transport call. For pause-spam (20 alternations), the chain serializes correctly with no orphan Tasks.
**Reset on `stop()` / `play(station:)`:** the chain is cancelled and replaced (`pipelineTransportTask?.cancel(); pipelineTransportTask = nil`).

**5.6 Cancel warmup + reset transport chain on stop / pause / play / handleTermination.**
Call `cancelResumeWarmup()` from:
- `pause()` (top — already in §5.3).
- `stop()` (`StreamPlayer.swift:140-154`) plus `pipelineTransportTask?.cancel(); pipelineTransportTask = nil`.
- `play(station:)` (`StreamPlayer.swift:89-102`) plus `pipelineTransportTask?.cancel(); pipelineTransportTask = nil`.
- top of `handleTermination(_:)` (see Phase 6) plus `pipelineTransportTask?.cancel(); pipelineTransportTask = nil`.

Reset rationale: `stop()` and `play(station:)` start a fresh stream session — any pending transport calls from the prior session are stale. `handleTermination` ends the current session entirely (ring buffer cleared), so chained transport calls referencing the dead pipeline state would no-op anyway; cancelling avoids the `await prior?.value` hang.

**Tests:** `tailLengthBound`, `pauseSpam` (Phase 8).

---

### Phase 6 — Latent bug fix: `userPaused` reconnect-suppression
**File:** `MacAmpApp/Audio/StreamPlayer.swift`

**6.1 Update `handleTermination(_:)` (`StreamPlayer.swift:272-286`).**
```swift
private func handleTermination(_ reason: StreamDecodePipeline.StreamTerminationReason) {
    // Cancel any in-flight resume warmup (we're terminating, not warming up).
    cancelResumeWarmup()                    // drains continuation, cancels task, sets task=nil
    isResumeWarming = false                 // CRITICAL: release onStateChange to its normal path,
                                            // otherwise a subsequent reconnect's .playing would be
                                            // suppressed and user-visible isPlaying would never flip.

    if userPaused {
        // User-paused state — never auto-reconnect. Stay paused. UI title bar stays
        // on the station name (not "Connecting…") because we don't flip isReconnecting.
        //
        // CRITICAL: still call onStreamTerminated to tear down the engine bridge.
        // The bridge is paired to the (now-dead) ring buffer; leaving it active means
        // resume's fresh-ring-buffer path lands on a stale streamSourceNode whose render
        // block captured the OLD ring. The render block does not re-bind on its own;
        // bridge teardown forces re-activation via onFormatReady on the next start().
        ringBuffer = nil
        isReconnecting = false
        onStreamTerminated?()           // tears down bridge cleanly; PlaybackCoordinator
                                        // calls audioPlayer.deactivateStreamBridge() here.
                                        // Silence gate is dropped with the bridge —
                                        // resume() will re-issue pipeline.start, and the
                                        // new bridge activation re-arms a fresh gate.
        // DO NOT fire onStreamStateChanged() — that would update Now Playing and flicker
        // the UI to "stopped" while the user expects "paused". State stays .paused from
        // pipeline's perspective (we never called pipeline.stop()).
        return
    }

    if wasActivelyPlaying && isReconnectable(reason) {
        attemptReconnect()
    } else {
        isReconnecting = false
        ringBuffer = nil
        let message = reason.userMessage
        if error == nil && !message.isEmpty {
            error = message
        }
        onStreamTerminated?()
        onStreamStateChanged?()
    }
}
```

**6.1.1 Belt-and-suspenders: clear `isResumeWarming` in `attemptReconnect()`.**
At the top of `attemptReconnect()` (`StreamPlayer.swift:305`), add `isResumeWarming = false`. Reasoning: even though `handleTermination` already clears it, an in-flight reconnect attempt that fires `pipeline.onStateChange(.playing)` after a fresh start should always reach the user-visible state path — defensive clearing eliminates any window where `isResumeWarming` could be stale from a prior cycle.

**Why bridge-teardown matters for the paused path (Oracle Critical finding #1):** `AudioEngineController.activateStreamBridge` constructs the `streamSourceNode` with a render block that captures the *current* `ringBuffer` reference (`AudioEngineController.swift:325-326`). On resume after socket-death-during-pause, `StreamPlayer.resume()` allocates a fresh `LockFreeRingBuffer` and calls `pipeline.start(...)` (Phase 5.4 `else if let station` branch). Without the teardown call here, the engine still holds the stale render block bound to the dead ring; when the new pipeline fires `onFormatReady`, `activateStreamBridge` short-circuits at the `guard !isBridgeActive else { return }` line (`AudioEngineController.swift:314`) and the new ring is never wired. The user hears silence forever. Calling `onStreamTerminated?()` in this branch routes through `PlaybackCoordinator.swift:166-171` to `audioPlayer.deactivateStreamBridge()`, which clears `isBridgeActive` and the captured ring — the next `onFormatReady` activates a fresh bridge with the new ring buffer.

**6.2 Resume after socket-death-during-pause.**
Already covered by Phase 5.4 `resume()` — when `pipeline.state` is no longer `.paused` (typically `.error(...)` because `handleStreamComplete` sets `.error` before invoking `onTermination`; see `StreamDecodePipeline.swift:344-345`), the `else if let station` branch fires `pipeline.start(...)` with a fresh ring buffer. Live-edge reconnect, no "Connecting…" flicker during the pause itself. Note that the userPaused branch in §6.1 does NOT call `pipeline.stop()` — the pipeline already self-transitioned to `.error` inside `handleStreamComplete`'s `setState(.error(message))` call. Calling `stop()` would advance the generation counter and tear down the URLSession a second time, which is harmless but redundant; we skip it for clarity.

**Tests:** `longPauseSuppressesReconnect` (Phase 8).

---

### Phase 7 — `AudioPlayer` forwarder + `PlaybackCoordinator` wiring
**Files:** `MacAmpApp/Audio/AudioPlayer.swift`, `MacAmpApp/Audio/PlaybackCoordinator.swift`

**7.1 `AudioPlayer.setStreamSilenced(_:)` (forwarder, facade pattern).**
After `deactivateStreamBridge()` (`AudioPlayer.swift:534-536`):
```swift
/// Forwarder to AudioEngineController.setStreamSilenced.
/// No-op when the stream bridge is inactive.
func setStreamSilenced(_ silenced: Bool) {
    engine.setStreamSilenced(silenced)
}

#if DEBUG
var isStreamSilenceGateActive: Bool { engine.isStreamSilenceGateActive }
#endif
```

**7.2 `PlaybackCoordinator` wiring.**
At the end of `init(audioPlayer:streamPlayer:)` (`PlaybackCoordinator.swift:185`), after `setupRemoteCommands()`:
```swift
self.streamPlayer.silenceGateForwarder = { [weak self] silenced in
    self?.audioPlayer.setStreamSilenced(silenced)
}
```
**Note:** the forwarder is captured at coordinator init, so it survives bridge teardown/re-activation cycles. `AudioPlayer.setStreamSilenced` no-ops if engine has no gate (bridge inactive), so calling it during `.connecting`/`.buffering` is safe (Risk row 8).

**7.3 Bridge-activation path clears the gate.**
In `streamPlayer.onFormatReady` callback (`PlaybackCoordinator.swift:155-163`), after `audioPlayer.activateStreamBridge(...)`:
```swift
// Clear silence gate after bridge activates (covers reconnect-after-long-pause path).
self.audioPlayer.setStreamSilenced(false)
```

**Tests:** integration coverage via Phase 8 `tailLengthBound` (full coordinator wiring exercised).

---

### Phase 8 — Tests (Swift Testing)
**File:** `Tests/MacAmpTests/StreamPauseTailTests.swift` (new). The test target is `MacAmpTests` and imports the production module as `MacAmp` (verified via `Package.swift:5,18` and existing tests `Tests/MacAmpTests/EQCodecTests.swift:4`).

```swift
import Testing
import AVFoundation
import Atomics
@testable import MacAmp

@MainActor
@Suite("Stream Pause Tail")
struct StreamPauseTailTests {

    @Test("Silence gate forces zero output and isSilence=true")
    func silenceGateProducesZeros() async {
        // Use the DEBUG factory helper from AudioEngineController.
        // Pre-fill ring with a 1.0-amplitude sine, render once with gate=0 → assert nonzero.
        // Set gate=1, render once → assert all zeros + isSilence == true.
        // Set gate=0 again → assert subsequent reads return ring data (not stuck-silenced).
    }

    @Test("Pause during buffering does not crash and clears packet queue")
    func pauseDuringBuffering() async {
        // Use the DEBUG harness on StreamDecodePipeline (see test seams below).
        // Inject 5 packets into DecodeContext.decoder.enqueue, call pauseByUser BEFORE formatReadyFired.
        // Assert: hasQueuedPackets == false, ringBuffer.availableFrames == 0, no crash.
    }

    @Test("Rapid pause/resume does not deadlock or leak warmup tasks")
    func pauseSpam() async {
        // 20 alternating pause/resume cycles via the public StreamPlayer API.
        // After the loop, assert: resumeWarmupTask is nil OR cancelled,
        // prebufferReadyContinuation is nil, no test timeout (must complete < 5 s).
    }

    @Test("Long pause suppresses reconnect even on socket death")
    func longPauseSuppressesReconnect() async {
        // 1. Bring StreamPlayer to .playing via test harness (sets wasActivelyPlaying=true).
        // 2. Call pause() — userPaused becomes true.
        // 3. Inject termination via DEBUG hook handleTerminationForTest(.networkError("conn lost",
        //    NSURLErrorNetworkConnectionLost)).
        // 4. Assert: isReconnecting == false, attemptReconnectInvocationCount == 0,
        //    onStreamTerminated invoked exactly once (bridge teardown).
        // 5. Call resume(). Assert: a fresh pipeline.start was issued.
    }

    @Test("Tail length bounded to ≤ 1 render quantum at 44.1 kHz")
    func tailLengthBound() async {
        // Use synthetic SPSC harness: fill ring with 1 kHz tone at 44.1 kHz, near-full.
        // Call StreamPlayer.pause via coordinator harness, then immediately invoke render block
        // 8 × 512-frame iterations. Record the index of the last non-zero output sample.
        // Assert: lastNonZeroFrameIndex < 512 (≤ 11.6 ms = 1 render quantum).
    }
}
```

**Test seams (DEBUG-scoped to honour Principle 5).** Add the following inside `#if DEBUG` blocks in production source:

1. **`AudioEngineController.makeStreamRenderBlock(...)`** — currently `private nonisolated static` (line 277). Change to:
```swift
#if DEBUG
internal nonisolated static func makeStreamRenderBlockForTesting(
    ringBuffer: LockFreeRingBuffer,
    silenceGate: ManagedAtomic<UInt8>
) -> AVAudioSourceNodeRenderBlock {
    makeStreamRenderBlock(ringBuffer: ringBuffer, silenceGate: silenceGate)
}
#endif
```
The original stays `private`. Tests call the `…ForTesting` shim. **No production visibility widening.**

2. **`StreamDecodePipeline` test injection + observation.** Add inside `#if DEBUG`:
```swift
#if DEBUG
/// Test-only injection of a termination event without going through URLSession.
internal func injectTerminationForTesting(_ reason: StreamTerminationReason) {
    onTermination?(reason)
}

/// Test-only: synchronously query whether the decode context's `isPausedByUser` flag is set.
/// Hops onto the decode queue with a sync barrier; safe because tests run on the main queue.
internal func isPausedByUserForTesting() -> Bool {
    guard let ctx = decodeContext else { return false }
    return ctx.isPausedByUserSnapshotForTesting()
}

/// Test-only: snapshot of decoder.hasQueuedPackets via the decode-queue barrier.
internal func decoderHasQueuedPacketsForTesting() -> Bool {
    guard let ctx = decodeContext else { return false }
    return ctx.decoderHasQueuedPacketsForTesting()
}

/// Test-only: enqueue a synthetic compressed-packet blob into the decoder, exercising the
/// real packetQueue path. Used by pauseDuringBuffering to populate state without network.
internal func enqueueRawPacketForTesting(data: Data, descriptions: [AudioStreamPacketDescription]) {
    decodeContext?.enqueueRawPacketForTesting(data: data, descriptions: descriptions)
}

/// Test-only: get the current decode context (concrete type so callers don't need AnyObject casts).
internal var decodeContextForTesting: DecodeContextTestProxy? {
    decodeContext.map { DecodeContextTestProxy(context: $0) }
}
#endif
```
Add corresponding decode-queue-confined sync getters on `DecodeContext` (inside `#if DEBUG`):
```swift
#if DEBUG
internal func isPausedByUserSnapshotForTesting() -> Bool {
    decodeQueue.sync { isPausedByUser }
}
internal func decoderHasQueuedPacketsForTesting() -> Bool {
    decodeQueue.sync { decoder?.hasQueuedPackets ?? false }
}
internal func enqueueRawPacketForTesting(data: Data, descriptions: [AudioStreamPacketDescription]) {
    decodeQueue.sync { decoder?.enqueue(data: data, descriptions: descriptions) }
}
#endif
```
And a thin `DecodeContextTestProxy` struct (also `#if DEBUG`, scoped to the file) that exposes the same three getters via the proxy. This avoids exposing `DecodeContext` itself (which is `private`) outside the file.

3. **`StreamPlayer` test observability.** Add inside `#if DEBUG`:
```swift
#if DEBUG
internal var isResumeWarmupActiveForTesting: Bool { resumeWarmupTask != nil && resumeWarmupTask?.isCancelled == false }
internal var hasPrebufferContinuationForTesting: Bool { prebufferReadyContinuation != nil }
internal var isResumeWarmingForTesting: Bool { isResumeWarming }
internal private(set) var attemptReconnectInvocationCountForTesting: Int = 0
internal private(set) var pipelineStartInvocationCountForTesting: Int = 0
internal var pipelineStateForTesting: StreamDecodePipeline.StreamState { pipeline.state }
internal func injectPipelineTerminationForTesting(_ reason: StreamDecodePipeline.StreamTerminationReason) {
    pipeline.injectTerminationForTesting(reason)   // routes through onTermination → handleTermination
}
internal func setWasActivelyPlayingForTesting(_ value: Bool) {
    wasActivelyPlaying = value                      // bypass full pipeline play() in tests
}
#endif
```
Increment `attemptReconnectInvocationCountForTesting` at the top of `attemptReconnect()` and `pipelineStartInvocationCountForTesting` at the top of the `else if let station = currentStation` branch in `resume()` and inside the warmup-task fresh-start branch. Both increments inside `#if DEBUG`.

4. **`AudioPlayer.isBridgeActive`** is already public-readable (`AudioPlayer.swift:59`) — no new seam needed for the bridge-teardown assertion in `longPauseSuppressesReconnect`.

5. **No `DecodeContext` tests bypass `StreamDecodePipeline`.** Tests interact only via the DEBUG seams on `StreamDecodePipeline` and `StreamPlayer`. `DecodeContext` itself remains `private`.

**Principle 5 compliance:** all four hooks are `#if DEBUG` and `internal` (not `public`). Release builds compile without them. Test target `MacAmpTests` is built in Debug configuration (verified by `Package.swift:33-40`); release `MacAmp` executable target excludes the test seams.

---

## 6. Files Inventory

| # | File | Existing lines | Change type | Anticipated insertion |
|---|------|---------------:|-------------|-----------------------|
| 1 | `MacAmpApp/Audio/LockFreeRingBuffer.swift` | 181 | Doc-only update | +6 doc lines |
| 2 | `MacAmpApp/Audio/AudioEngineController.swift` | 425 | Behavioral + new method | +1 import, +1 stored property, +1 init line, +1 deinit line, ~5 lines in render-block factory, ~10 lines for `setStreamSilenced` + DEBUG getter |
| 3 | `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` | 698 | New API + state | +2 stored props in DecodeContext, +1 callback on pipeline, `pauseByUser`/`resumeByUser` async (~30 lines incl. continuation wrapping), `setPausedByUser`/`resetPrebufferTracking` (~28 lines), gate checks (+2 lines × 2 sites), prebuffer-on-resume tracking (+~6 lines), init signature update (+1 param), DEBUG seams (~10 lines) |
| 4 | `MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift` | 285 | New method | +~8 lines (`clearQueue`) |
| 5 | `MacAmpApp/Audio/StreamPlayer.swift` | 415 | Behavioral + new state | +5 stored props (incl. `isResumeWarming`), replace `pause()` (+5 net lines), replace `resume()` (+8 net lines), `cancelResumeWarmup` (~10 lines), `startResumeWarmup` (~50 lines incl. cancellation handler + continuation), `handleTermination` rewrite (+18 net lines incl. bridge teardown), `onStateChange .playing` branch (+8 lines), DEBUG seams (~10 lines) |
| 6 | `MacAmpApp/Audio/AudioPlayer.swift` | 735 | New forwarder | +~10 lines (`setStreamSilenced` + DEBUG getter) |
| 7 | `MacAmpApp/Audio/PlaybackCoordinator.swift` | 562 | Wiring | +2 lines (forwarder closure assignment) +1 line (clear gate after bridge activation) |
| 8 | `Tests/MacAmpTests/StreamPauseTailTests.swift` | 0 (NEW) | New | ~200 lines (5 tests + harness helpers) |

**Total estimated insertion:** ~340 production LOC + ~200 test LOC. **No file deletions.** **No XcodeGen `project.yml` changes** (Tests/MacAmpTests is glob-included). **Module import:** `@testable import MacAmp` (NOT `MacAmpApp`).

### 6.5 Responsibility map (Principle 3 audit)

| State | Owner | Writers | Readers | Confinement |
|-------|-------|---------|---------|-------------|
| `streamSilenceGate` (`ManagedAtomic<UInt8>`) | `AudioEngineController` | `setStreamSilenced` (MainActor, releasing) | render block (RT thread, relaxed) | atomic |
| `userPaused: Bool` | `StreamPlayer` | `pause()`, `resume()`, `play(station:)`, `stop()` | `handleTermination`, `startResumeWarmup` | MainActor |
| `isPausedByUser: Bool` | `DecodeContext` | `setPausedByUser` (decode queue) | `handleIncomingData`, `handlePackets` | decode serial queue |
| `prebufferReadyContinuation: CheckedContinuation<Void, Never>?` | `StreamPlayer` | `startResumeWarmup` (set), `pipeline.onPrebufferReady` (resume + nil), timeout sub-task (resume + nil), `cancelResumeWarmup` (drain + nil), `handleTermination` (drain + nil) | `cancelResumeWarmup` reads | MainActor |
| `prebufferReadyFiredOnResume: Bool` | `DecodeContext` | `resetPrebufferTracking`, `handlePackets` | `handlePackets` | decode serial queue |
| `silenceGateForwarder` closure | `StreamPlayer` (assigned by `PlaybackCoordinator`) | `PlaybackCoordinator.init` only | `pause()`, `startResumeWarmup` | MainActor |
| `resumeWarmupTask: Task<Void, Never>?` | `StreamPlayer` | `startResumeWarmup` (set), `cancelResumeWarmup` (cancel + nil), the running task body via `clearTaskIfMine()` (identity-guarded nil) | None outside `cancelResumeWarmup` | MainActor |
| `resumeWarmupGeneration: UInt64` | `StreamPlayer` | `startResumeWarmup` (increment, capture local copy), `cancelResumeWarmup` (increment to invalidate stale tasks) | running task body via `clearTaskIfMine()` (compares captured local copy) | MainActor |
| `isResumeWarming: Bool` | `StreamPlayer` | `startResumeWarmup` (true), `cancelResumeWarmup` (false), warmup task body completion paths (false), `handleTermination` top (false), `attemptReconnect` top (false), `resume()` `else if station` branch (false) | `pipeline.onStateChange .playing` branch reads | MainActor |
| `pipelineTransportTask: Task<Void, Never>?` | `StreamPlayer` | `chainTransport` (set), `stop()` (cancel + nil), `play(station:)` (cancel + nil), `handleTermination` (cancel + nil), `resume()` `else if station` branch (cancel + nil) | `chainTransport` reads `prior` | MainActor |
| `decodeContext.audioWorkgroup` (existing) | `DecodeContext` | `setAudioWorkgroup` (decode queue async) | `handleIncomingData` join/leave | decode serial queue |

No state is shared between layers without a documented confinement.

---

## 7. Resolution of research.md Open Questions

| # | Question | Decision (this plan) |
|---|----------|---------------------|
| 1 | Wiring `setStreamSilenced(_:)` — forwarder vs injected closure | **Forwarder via `AudioPlayer.setStreamSilenced` + closure on `StreamPlayer` assigned at PlaybackCoordinator init.** ADR-SPT-4. No new pass-through layer. Survives bridge teardown/reactivate cycles. |
| 2 | `userPaused` flag location — StreamPlayer vs DecodeContext | **StreamPlayer** (already in research recommendation). Plus a separate decode-queue-confined `isPausedByUser` mirror in `DecodeContext`. ADR-SPT-2. |
| 3 | Live-edge vs paused-snapshot on resume after long pause | **Best-effort first; live-edge fallback after 1 s prebuffer timeout.** No 5 s branch. ADR-SPT-5. |
| 4 | Same gate for reconnect's bridge-teardown path | **No** — keep gate scoped to user pause. Reconnect already creates fresh ring buffer + bridge. Plan §2 explicitly drops the gate in `deactivateStreamBridge`. |
| 5 | Local-file pause path | **Out of scope.** `AVAudioPlayerNode.pause()` is sample-accurate. |

---

## 8. Verification Approach

### 8.1 Quantitative tail-length measurement
- **Method:** `tailLengthBound` test (Phase 8) — synthetic producer fills ring at 44.1 kHz with a 1 kHz sine, MainActor calls `StreamPlayer.pause()`, render block invoked iteratively, last non-zero output frame is recorded.
- **Acceptance:** ≤ 512 frames (~11.6 ms = 1 render quantum at 44.1 kHz). **Target much tighter than the original "0.7 s" failure.**

### 8.2 Manual end-to-end loopback recording (S3 verification doc)
- Play a SHOUTcast/Icecast MP3 stream via the app, capture system audio with BlackHole, pause, measure trailing audio in Audacity at 22.05 / 44.1 / 48 kHz.
- **Acceptance:** trailing audio < 25 ms (≤ 1 render quantum + ≤ 25 ms hardware latency).

### 8.3 Behavioral acceptance checklist (manual + tests)
- [ ] No reconnect events fire while user is paused — even after simulated socket death (`longPauseSuppressesReconnect`).
- [ ] Resume latency to first audible frame < 500 ms in normal network conditions.
- [ ] After 30 s pause: resume succeeds, no audible "Connecting..." flicker visible (UI stays on "Buffering…" briefly during prebuffer warmup).
- [ ] Pause during `.connecting` / `.buffering` → existing `pipeline.stop()` path fires, no crash, gate-set is a no-op (bridge inactive).
- [ ] Pause-spam (10 alternations in 1 s) → no deadlock, no leaked warmup task (Task IDs in `Console.app` show cancellations).
- [ ] Local-file pause is unchanged: sample-accurate stop, no measurable tail.
- [ ] EQ and balance changes during pause are silent (gate active) but apply correctly on resume.

### 8.4 Thread Sanitizer
- `xcodebuildmcp macos test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`
- **Acceptance:** zero new TSan warnings vs current `main` baseline.

### 8.5 XcodeBuildMCP build + test
After file creation: `xcodegen generate`, then build and run the full `MacAmpApp` test plan. Existing 57 tests must all pass.

---

## 9. Risk Assessment

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|:--:|:--:|------------|
| 1 | Late URLSession delegate callback writes ring buffer after pause | Mitigated | Stale audio on resume | `isPausedByUser` set inside same `decodeQueue.async` block as `flush`. ADR-SPT-2. Tested in `pauseDuringBuffering`. |
| 2 | Silence gate atomic creates TSan complaint | Low | CI noise | Same `ManagedAtomic` primitive as `LockFreeRingBuffer.writeHead/readHead`, which is TSan-clean today. Releasing-store on writer, relaxed-load on reader is canonical. |
| 3 | Late `pipeline.onPrebufferReady` after resume timeout | Medium | Continuation double-resume | `prebufferReadyContinuation` is set to nil on every consumption site (timeout, prebuffer-ready, cancel). `?.resume()` is idempotent only when nil. Audit point in code review. |
| 4 | Resume contract regression — pause+resume during reconnect race | Medium | Stalled stream | Phase 5.6 explicitly cancels warmup task in `play(station:)`, `stop()`, `handleTermination`. `pauseSpam` test exercises this. |
| 5 | Local-file pause regression (silence gate accidentally applied) | Low | Local file goes silent | Gate is owned by `AudioEngineController`, ONLY captured by stream render block. `playerNode.pause()` path is unaffected. Verified by existing local-file tests + manual smoke test. |
| 6 | Reconnect-while-paused suppression accidentally suppresses normal reconnect | Medium | Reconnect broken | New `userPaused` flag is set ONLY in `pause()` and cleared in `resume()`/`play()`/`stop()`. `handleTermination` checks `userPaused` first; otherwise falls through to existing `wasActivelyPlaying && isReconnectable` path. Tested in `longPauseSuppressesReconnect`. |
| 7 | Successor task rebase conflicts (HLS, OGG modify same files) | Medium | Sprint slowdown | Changes are additive: new methods, no signature changes on existing public methods (only `pause()`/`resume()` body, which HLS/OGG do not touch). Phase ordering keeps insertion locations stable. |
| 8 | XcodeGen project.yml drift after adding test file | Low | Build break | `xcodegen generate` after creating `StreamPauseTailTests.swift`. Validated by xcodebuildmcp build step. |
| 9 | TSan false positive on `LockFreeRingBuffer.flush` writing both heads | Low | CI noise | Documented benign in `LockFreeRingBuffer.swift:13-16`. Producer is fully quiesced (suspend + decode-queue gate) before flush. |
| 10 | 1 s warmup timeout too aggressive on slow networks | Low | Spurious live-edge reconnects | `8192` prebuffer threshold ≈ 185 ms @ 44.1 kHz; even slow streams (32 kbps MP3) refill in << 1 s. If user reports false-positive reconnects, threshold and timeout are both single constants — easy bump. |
| 11 | `AudioEngineController` gate-allocation race vs render block | None | n/a | `streamSilenceGate` is created BEFORE the render block factory call. `AVAudioSourceNode` cannot invoke the render block before `audioEngine.start()`, which happens after `streamSourceNode` is attached. Order: gate alloc → render block built → source attached → engine start. |

**Overall regression risk: LOW–MEDIUM.** Two new state-machine flags interact with existing reconnect logic — covered by Phase 8 edge-case tests.

---

## 10. Stop Criteria (Kill Switch)

Halt and roll back the task if **any** of the following is true after Phase 5 lands locally:

1. **TSan warnings** in stream-related render block, decode queue, or ring buffer that did not exist before this branch.
2. **Tail measurement > 25 ms** at 44.1 kHz in `tailLengthBound`. Indicates the gate is racing with the render block in an unexpected way.
3. **Local-file playback regression** of any kind (any failing existing test).
4. **`pauseSpam` test deadlocks** or exceeds 5 s wall-clock — implies leaked continuation or warmup-task cycle.
5. **Reconnect-during-active-playback breaks** (all `wasActivelyPlaying && !userPaused` paths must continue to reconnect as today).

If 1–3 occur: revert the silence-gate Phase 2 changes only (keep Phase 6 latent-bug fix as a standalone PR). If 4–5 occur: revert the entire branch.

---

## 11. Branch + PR Plan

**Branch:** `fix/stream-pause-tail`
**Base:** `main` at S3-1 wave start (post-S2 head).
**Worktree:** `worktree-stream-pause-tail` (separate physical checkout, parallel with `worktree-mainwindow-visualizer-isolation`).
**Wave:** S3-1 Worktree B.
**Merge order:** PR #A (`mainwindow-visualizer-isolation`) merges first; this PR rebases onto post-A `main`, then merges as PR #B.
**Commits expected:** 3–5 logical commits aligned with phases:
1. Phase 1 + 2 + 4 — silence gate + decoder clearQueue + LRB doc.
2. Phase 3 — pipeline pauseByUser/resumeByUser + onPrebufferReady plumbing.
3. Phase 5 + 6 + 7 — StreamPlayer orchestration + latent bug fix + Coordinator wiring.
4. Phase 8 — tests.
5. Oracle review fixes (single squashable commit).

### 11.1 Shared-anchor conflict map for successors

| Anchor (file:approx-line) | This PR change | HLS (S3-3) plan | OGG (S3-4) plan | Conflict severity | Rebase guidance |
|---|---|---|---|---|---|
| `StreamDecodePipeline.swift` `pause()` `:227-231` | Replaced with sync→async wrapper; new `pauseByUser()` / `resumeByUser()` async | HLS `pause()` calls `hlsFeeder?.pause()` (HLS plan §554) — but per HLS plan v1, pause-as-stop, no direct conflict | OGG does not modify `pause()` | **Medium** (HLS) | HLS to call new `pauseByUser` shape if HLS-feeder pause path needs barrier semantics; otherwise existing `pause()` legacy entry preserved. |
| `StreamDecodePipeline.swift` `DecodeContext` state block `:462-469` | Add `isPausedByUser`, `prebufferReadyFiredOnResume` | OGG adds `StreamBackend` enum, `setHint`, replay buffer (OGG plan §291-373) | OGG plan touches same struct heavily | **High** (OGG) | OGG already plans to refactor `DecodeContext` heavily and rebases against this. OGG plan §625 explicitly lists `formatReadyFired` as MainActor — OGG must integrate `prebufferReadyFiredOnResume` similarly. |
| `StreamDecodePipeline.swift` `handleIncomingData` `:537` | Add `!isPausedByUser` guard | HLS does not touch | OGG: backend dispatch may replace this method body | **High** (OGG) | OGG must preserve the `!isPausedByUser` guard inside whichever backend handles ICE/Vorbis bytes. |
| `StreamDecodePipeline.swift` callbacks block `:55-58` | Add `onPrebufferReady` callback | HLS adds `onChainFormatChange`-style callbacks (none — HLS plan does not add callbacks here) | OGG adds `onChainFormatChange` (OGG plan §374) | **Low** (additive) | All three callbacks coexist as separate `var` declarations. No conflict. |
| `StreamPlayer.swift` `pause()` `:116-125` | Rewritten | HLS does not modify | OGG does not modify | None | Clean rebase. |
| `StreamPlayer.swift` `resume()` `:127-138` | Rewritten | HLS does not modify | OGG does not modify | None | Clean rebase. |
| `StreamPlayer.swift` `handleTermination` `:272-286` | Rewritten with `userPaused` branch | HLS modifies `isReconnectable` switch (HLS plan §616-642) — separate method | OGG does not modify | **Low** | Both modify different methods; HLS rebases cleanly. |
| `StreamPlayer.swift` reconnect-state block `:64-69` | Add `userPaused`, `prebufferReadyContinuation`, `resumeWarmupTask`, `silenceGateForwarder`, `isResumeWarming` | None | None | None | Clean. |
| `AudioEngineController.swift` `makeStreamRenderBlock` `:277-303` | Render block adds silence-gate read | None (HLS, OGG don't touch render block) | None | None | Clean. |
| `AudioConverterDecoder.swift` `enqueue` `:130-133` (insert after) | New `clearQueue()` | None | OGG creates a separate `VorbisDecoder`; doesn't touch this file | None | Clean. |
| `AudioPlayer.swift` after `deactivateStreamBridge` `:534-536` | New `setStreamSilenced` forwarder | None | None | None | Clean. |
| `PlaybackCoordinator.swift` `init` end `:185` | Add forwarder closure assignment + `setStreamSilenced(false)` after bridge activation | None | None | None | Clean. |

**Successor merge order:**
1. This PR merges (S3-1B).
2. `video-audio-engine-routing` (S3-2) — separate file boundaries (`VideoPlaybackController`), no conflict with this PR's changes.
3. `hls-streaming-support` (S3-3) — rebases against post-merge HEAD; HLS plan §646 already prescribes a HEAD re-read at implementation time. Conflict expected on `pause()` legacy entry (Medium severity above) — resolution: HLS adopts `pauseByUser()` async path or keeps legacy sync `pause()` for HLS-only backend.
4. `ogg-vorbis-support` (S3-4) — major `DecodeContext` refactor; OGG plan-writer must reconcile `isPausedByUser` and `prebufferReadyFiredOnResume` with the new backend split.

This PR's plan-writer commits to **NOT** adding any further changes to `pause()` / `resume()` / `handleTermination` after this plan is approved, to give successor planners a stable rebase target.

---

## 12. Rollback Plan

If post-merge regression is detected:
1. **Single-commit revert** restores prior pause behavior (audible tail returns; latent bug returns).
2. Followed by a focused fix-forward PR addressing the specific failure mode.
3. Tail-fix can ship piecemeal: the silence-gate (Phase 2) alone resolves 90 % of the audible tail; the producer-quiesce + flush (Phase 3) is what closes the resume-with-stale-audio gap. If only Phase 3 needs revert, drop just that commit and leave the silence gate.

The latent bug fix (Phase 6) is independent of the audio path — if needed it can be cherry-picked into a hotfix branch without the silence-gate changes.

---

## 13. Oracle Validation Summary

**Reviewer:** Codex CLI (`mcp__codex-cli__codex`, model `gpt-5.3-codex`, reasoningEffort `xhigh`).
**Dates:** 2026-04-27. **Forwarded each iteration:** plan.md, todo.md, research.md, principles.md, all 7 audio source files, Package.swift.

| Iteration | Score | Verdict | Key Findings | Resolution |
|----------|------:|---------|--------------|-----------|
| 1 | 7.8/10 | CONDITIONAL | (Critical) paused-termination path leaves stale bridge; (High) async barrier not enforced in pauseByUser/resumeByUser; (High) warmup continuation lifecycle fragile; (Medium) early `.playing` transition; (Medium) test seams insufficient + wrong module name; (Medium) "additive" claim overstated. | Bridge teardown added to userPaused branch (§Phase 6.1). pauseByUser/resumeByUser made async with continuation-wrapped barriers (§Phase 3.5). cancelResumeWarmup + withTaskCancellationHandler design (§Phase 5.5). isResumeWarming flag (§Phase 5.4). DEBUG test seams + module name corrected to `MacAmp` (§Phase 8). Conflict map §11.1 added. |
| 2 | 8.6/10 | CONDITIONAL | (High) plan/todo mismatch on async pause call; (High) isResumeWarming not cleared in termination/reconnect; (Medium) timeout sub-task unstructured; (Medium) resumeWarmupTask lifecycle incomplete + test seams insufficient. | pause() now wraps `Task { await pauseByUser() }` (§5.3). isResumeWarming=false in handleTermination + attemptReconnect (§6.1, §6.1.1). Warmup redesigned with `withTaskGroup` (later replaced). Stronger test seams: `injectPipelineTerminationForTesting`, `setWasActivelyPlayingForTesting`, `pipelineStartInvocationCountForTesting`, `isPausedByUserForTesting`, `decoderHasQueuedPacketsForTesting`. |
| 3 | 8.9/10 | CONDITIONAL | (Medium) onCancel uses unstructured Task; (Medium) rapid resume→pause race not closed. | Removed withTaskCancellationHandler entirely; cancelResumeWarmup drains continuation FIRST then cancels. Added `pipelineTransportTask` serial chain + `chainTransport` helper (ADR-SPT-8). All transport calls serialized. |
| 4 | 8.4/10 | CONDITIONAL | (Critical) withTaskGroup hangs on timeout because child-1's `withCheckedContinuation` is not cancellation-aware; (High) resume reads pipeline.state outside chain; (High) stop doesn't supersede in-flight resume; (Medium) todo stale; (Medium) pipelineTransportTask absent from P3 audit. | Replaced withTaskGroup with single MainActor task + sibling timeoutTask that drains continuation. resume() branch decision moved INSIDE chainTransport closure. `Task.isCancelled` checks added to pauseByUser/resumeByUser between awaits. Todo §5.5 corrected. P3 audit map expanded. |
| 5 | **9.1/10** | **APPROVED** | Single nit: line 586 doc comment said "structured via TaskGroup" (stale). | Comment updated to describe single MainActor task + sibling timeout sub-Task. |

**Final approval (iteration 5):** 9.1/10 — APPROVED. Plan ships to implementation.

**Cumulative principle scores from Oracle:**
- P1 (Problem-First): 10/10
- P2 (Cohesion): 9/10
- P3 (State Ownership): 9/10 (after P3 audit expansion in iter-4)
- P4 (AHA): 9/10
- P5 (API Surface): 9/10 (DEBUG-scoped seams accepted)
- P6 (No Pass-through): 9/10 (forwarder pattern explicitly justified)
- P7 (ADR + Kill Switch): 10/10 (8 ADRs, explicit stop criteria, rollback plan)

---

## 14. Cross-References

- Research: `tasks/stream-pause-tail/research.md`
- Principles: `tasks/_context/principles.md`
- Cross-task state: `tasks/_context/state.md`
- Prior unified-pipeline lessons: `tasks/done/unified-audio-pipeline/lessons-learned.md` (Lessons 4, 5, 9)
- Network reconnect (related state machine): `tasks/done/network-auto-reconnect/plan.md`
- Architecture guide: `docs/MACAMP_ARCHITECTURE_GUIDE.md` §4 + §9 (unified pipeline + stream bridge lifecycle)
- Implementation patterns: `docs/IMPLEMENTATION_PATTERNS.md` (audio patterns + stream bridge lifecycle)
