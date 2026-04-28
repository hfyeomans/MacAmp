# Todo: Stream Pause Tail

> **Source:** `tasks/stream-pause-tail/plan.md`. Each item is atomic and verifiable. Acceptance criteria called out where non-obvious. Phases run in sequence; tests in Phase 8 may be developed alongside earlier phases for fast feedback.
> **Branch:** `fix/stream-pause-tail`. **Wave:** S3-1 Worktree B.

---

## Pre-flight

- [ ] **0.1** Verify `main` HEAD includes PR #A (`mainwindow-visualizer-isolation`) merge, OR start parallel branch from same base if PR #A not yet merged. Document base SHA in PR description.
- [ ] **0.2** Create worktree: `git worktree add worktree-stream-pause-tail fix/stream-pause-tail`.
- [ ] **0.3** Confirm `import Atomics` is available to `MacAmpApp/Audio/AudioEngineController.swift` (Atomics is already in `Package.swift` via `LockFreeRingBuffer.swift:1`).
- [ ] **0.4** Read `tasks/stream-pause-tail/plan.md` end-to-end. ADRs SPT-1 through SPT-6 are non-negotiable.

---

## Phase 1 — `LockFreeRingBuffer` doc-only update

- [ ] **1.1** Append producer-quiesce contract paragraph to the doc on `flush(newGeneration:)` at `MacAmpApp/Audio/LockFreeRingBuffer.swift:136-149`. Wording in plan.md §Phase 1.
- [ ] **1.2** Build (`xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`) — must remain green.

**Acceptance:** doc-only diff. No behavioral change.

---

## Phase 2 — Silence gate atomic primitive (`AudioEngineController`)

- [ ] **2.1** Add `import Atomics` to `MacAmpApp/Audio/AudioEngineController.swift` (top of file).
- [ ] **2.2** Add `private var streamSilenceGate: ManagedAtomic<UInt8>?` near `streamSourceNode` (`AudioEngineController.swift:32-34`).
- [ ] **2.3** Update `makeStreamRenderBlock(...)` signature to accept `silenceGate: ManagedAtomic<UInt8>` and add the relaxed-load early-return memset path. Body in plan.md §Phase 2.2.
- [ ] **2.4** In `activateStreamBridge(...)` (`AudioEngineController.swift:313-366`), allocate `let gate = ManagedAtomic<UInt8>(0)` BEFORE `makeStreamRenderBlock` is called. Store `streamSilenceGate = gate`. Pass `gate` to factory.
- [ ] **2.5** In `deactivateStreamBridge()` (`AudioEngineController.swift:370-405`), set `streamSilenceGate = nil` alongside other cleanup.
- [ ] **2.6** Add `func setStreamSilenced(_ silenced: Bool)` after `setBalance(_:)` (`AudioEngineController.swift:267-270`). Body uses `streamSilenceGate?.store(...)`.
- [ ] **2.7** Add `#if DEBUG` getter `var isStreamSilenceGateActive: Bool` for tests.
- [ ] **2.8** Build green.
- [ ] **2.9** Run existing audio test suite — no regressions in render-block or bridge-lifecycle tests.

**Acceptance:** silence gate is allocated/dropped exactly with bridge lifecycle. Setter no-ops when bridge is inactive. Render block produces zeros + `isSilence=true` when gate is set. (Verified by Phase 8.1.)

---

## Phase 3 — Producer-quiesce hooks (`StreamDecodePipeline`)

- [ ] **3.1** In `DecodeContext` (`StreamDecodePipeline.swift:457`), add stored properties: `private var isPausedByUser: Bool = false` and `private var prebufferReadyFiredOnResume: Bool = true`.
- [ ] **3.2** Add `private static let resumePrebufferThreshold: Int = 8192` to `DecodeContext`.
- [ ] **3.3** Extend `DecodeContext.init(...)` (`StreamDecodePipeline.swift:481-495`) with `onPrebufferReady: @escaping @Sendable (UInt64) -> Void` parameter. Store as `private let onPrebufferReady`.
- [ ] **3.4** Update both `handleIncomingData(...)` (`StreamDecodePipeline.swift:537`) and the inner loop in `handlePackets(...)` (`StreamDecodePipeline.swift:642`) to also gate on `!isPausedByUser`.
- [ ] **3.5** In `handlePackets(...)` after `prebufferedFrames += framesWritten` (`StreamDecodePipeline.swift:647`), add the `prebufferReadyFiredOnResume` check + `onPrebufferReady(generation)` fire.
- [ ] **3.6** Add `setPausedByUser(_:completion:)` to `DecodeContext` (decode-queue async). On `paused == true`: **strict ordering inside the same async block**: (1) `isPausedByUser = true`, then (2) `decoder?.clearQueue()`, then (3) `ringBuffer.flush(newGeneration: false)`. Body in plan.md §Phase 3.3.
- [ ] **3.7** Add `resetPrebufferTracking(completion:)` to `DecodeContext` (decode-queue async): zero `prebufferedFrames`, set `prebufferReadyFiredOnResume = false`.
- [ ] **3.8** Add `var onPrebufferReady: (@MainActor @Sendable () -> Void)?` to `StreamDecodePipeline` alongside other callbacks at line 56.
- [ ] **3.9** Wire `onPrebufferReady` from `DecodeContext` init in `startDirectStream(...)` (`StreamDecodePipeline.swift:144-175`) — Task+@MainActor hop with generation check, fires `self.onPrebufferReady?()`.
- [ ] **3.10** Replace `pause()` / `resume()` (`StreamDecodePipeline.swift:227-237`). New shape:
   - `func pause()` (legacy sync entry) — fires `Task { @MainActor in await self?.pauseByUser() }`.
   - `func resume()` (legacy sync entry) — fires `Task { @MainActor in await self?.resumeByUser() }`.
   - `func pauseByUser() async` — `dataTask?.suspend()`, then `await withCheckedContinuation` wrapping `setPausedByUser(true) { cont.resume() }` (decode-queue barrier), then `setState(.paused)`.
   - `func resumeByUser() async` — barrier on `resetPrebufferTracking`, then barrier on `setPausedByUser(false)`, then `dataTask?.resume()`, then `setState(.playing)`.
- [ ] **3.11** Build green.

**Acceptance:** Calling `await pipeline.pauseByUser()` from MainActor returns ONLY after the decode-queue barrier completes — by that point `isPausedByUser=true`, `decoder.hasQueuedPackets==false`, `ringBuffer.availableFrames==0`. Late URLSession callbacks reaching `handleIncomingData` after the barrier no-op. (Verified by Phase 8.2.)

---

## Phase 4 — `AudioConverterDecoder.clearQueue()`

- [ ] **4.1** Add `func clearQueue()` after `enqueue(...)` at `MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift:130-133`. Body: `assertConfinement(); packetQueue.removeAll(); freeCurrentInput()`.
- [ ] **4.2** Build green.

**Acceptance:** `decoder.clearQueue()` followed by `decoder.hasQueuedPackets == false`. Idempotent — second call no-ops.

---

## Phase 5 — `StreamPlayer` orchestration & resume warmup

- [ ] **5.1** Add private state (`StreamPlayer.swift:64-69`):
   - `userPaused: Bool`
   - `prebufferReadyContinuation: CheckedContinuation<Void, Never>?`
   - `resumeWarmupTask: Task<Void, Never>?`
   - `resumeWarmupGeneration: UInt64` (Oracle iter-4 finding — identity-guards `resumeWarmupTask = nil` writes from stale tasks)
   - `isResumeWarming: Bool` (Oracle iter-2 finding — gates user-visible isPlaying flip during warmup)
   - `pipelineTransportTask: Task<Void, Never>?` (Oracle iter-3 finding — serializes async pipeline transport calls per ADR-SPT-8)
   - `silenceGateForwarder: (@MainActor (Bool) -> Void)?`
- [ ] **5.2** In `setupPipelineCallbacks()` (`StreamPlayer.swift:172-229`) wire `pipeline.onPrebufferReady` to drain `prebufferReadyContinuation`.
- [ ] **5.2.1** Update `case .playing` branch in `pipeline.onStateChange` (`StreamPlayer.swift:184-190`): when `isResumeWarming == true`, only call `startPlaybackStableTimer()`; do NOT flip `isPlaying`, `isBuffering`, `wasActivelyPlaying`, or restart elapsed timer. The warmup task owns those transitions. When `isResumeWarming == false`, the existing body runs unchanged.
- [ ] **5.2.5** Add `chainTransport(_:)` helper per plan.md §Phase 5.2.5 — appends an async pipeline transport op onto the serial `pipelineTransportTask` chain. The new task awaits `prior?.value` before running its body.
- [ ] **5.3** Replace `pause()` body (`StreamPlayer.swift:116-125`):
   1. `cancelResumeWarmup()` (drain prior warmup).
   2. `cancelReconnect()`.
   3. `stopElapsedTimer()`.
   4. `userPaused = true`.
   5. `silenceGateForwarder?(true)` (atomic, instant).
   6. Connecting/buffering: `pipeline.stop()` (no async needed).
   7. Otherwise: `chainTransport { [weak self] in await self?.pipeline.pauseByUser() }` (serialized through transport chain — covers rapid resume→pause race per ADR-SPT-8).
   8. `isPlaying = false; isBuffering = false`.
   9. `wasActivelyPlaying` is intentionally NOT cleared.
- [ ] **5.4** Replace `resume()` body (`StreamPlayer.swift:127-138`):
   1. `cancelResumeWarmup()`.
   2. `userPaused = false`.
   3. If `case .paused = pipeline.state`: set `isResumeWarming = true`, `isBuffering = true`, call `startResumeWarmup()`, then `chainTransport { [weak self] in await self?.pipeline.resumeByUser() }`.
   4. Else if `currentStation` is non-nil: cancel `pipelineTransportTask`, clear `isResumeWarming = false`, allocate fresh ring buffer, call `pipeline.start(...)` (live-edge restart path; bridge teardown already happened in handleTermination per Phase 6).
- [ ] **5.5** Add `cancelResumeWarmup()` and `startResumeWarmup()` per plan.md §Phase 5.5. `cancelResumeWarmup()` drains the continuation FIRST then cancels the task and clears `isResumeWarming`. `startResumeWarmup()` schedules a single MainActor task that arms a timeout sub-task (which itself drains the continuation if it fires) and awaits `withCheckedContinuation`. No `withTaskCancellationHandler` is used — cancel-time drainage is handled by the explicit drain in `cancelResumeWarmup()`. The `timedOut` outcome is determined post-await by inspecting `ringBuffer.availableFrames`.
- [ ] **5.6** Add `cancelResumeWarmup()` AND `pipelineTransportTask?.cancel(); pipelineTransportTask = nil` to: `stop()` (`StreamPlayer.swift:140-154`), `play(station:)` (`StreamPlayer.swift:89-102`), `handleTermination(_:)` (top — see Phase 6). `pause()` only needs `cancelResumeWarmup()` (transport chain remains valid for the chained pauseByUser call). Resume's `else if let station` fresh-start branch also cancels `pipelineTransportTask`.
- [ ] **5.7** Build green.

**Acceptance:**
- `pause()` returns immediately to MainActor; render block silenced within ≤ 1 quantum (Phase 8.5).
- `resume()` keeps `isPlaying=false, isBuffering=true` until silence gate drops (avoids early "playing" UI flicker before audio is heard).
- Pause→resume→pause cycles do not leak warmup tasks (Phase 8.3 — `isResumeWarmupActiveForTesting` returns false at end of test loop).
- `isResumeWarming` is always `false` when no warmup is in flight (audited via DEBUG getter in tests).

---

## Phase 6 — Latent bug fix: `userPaused` reconnect-suppression

- [ ] **6.1** Update `handleTermination(_:)` (`StreamPlayer.swift:272-286`) per plan.md §Phase 6.1:
   1. `cancelResumeWarmup()` at top (drains continuation + cancels task + sets task=nil).
   2. **`isResumeWarming = false`** (CRITICAL — Oracle High finding: otherwise a subsequent reconnect's `.playing` would be suppressed forever).
   3. If `userPaused`: clear `ringBuffer`, set `isReconnecting = false`, **call `onStreamTerminated?()` to tear down the engine bridge** (CRITICAL — Oracle Critical finding: leaving bridge active strands resume on stale ring), return WITHOUT firing `onStreamStateChanged?()` (UI stays "paused", not flipped to stopped).
   4. Otherwise existing logic (`wasActivelyPlaying && isReconnectable` → `attemptReconnect()`, else terminal teardown).
- [ ] **6.1.1** Add `isResumeWarming = false` at the top of `attemptReconnect()` (`StreamPlayer.swift:305`) — belt-and-suspenders defensive clear.
- [ ] **6.2** Confirm `resume()` (Phase 5.4) handles the case where `pipeline.state` is no longer `.paused` (was terminated silently during pause) by falling through to `pipeline.start(...)` with fresh ring buffer. The fresh `pipeline.onFormatReady` then re-activates the bridge via PlaybackCoordinator (`AudioPlayer.activateStreamBridge`) and clears the silence gate via `AudioPlayer.setStreamSilenced(false)` (Phase 7.4).
- [ ] **6.3** Manual test: pause stream, simulate network drop (turn off Wi-Fi briefly), confirm title bar does NOT flip to "Connecting…". Re-enable network, press resume, confirm fresh stream connects (live-edge).
- [ ] **6.4** Add `attemptReconnectInvocationCountForTesting` increment at top of `attemptReconnect()` inside `#if DEBUG` (DEBUG observability seam for Phase 8.5).

**Acceptance:**
- `handleTermination` with `userPaused == true` never calls `attemptReconnect()` (Phase 8.5: `attemptReconnectInvocationCountForTesting == 0`).
- `isReconnecting` stays `false` throughout pause.
- Bridge is torn down in the `userPaused` branch — verified by `audioPlayer.isBridgeActive == false` after injection (Phase 8.5 acceptance).
- Subsequent `resume()` calls `pipeline.start(...)` (not `dataTask.resume()`) — verified by Phase 8.5 reading `pipeline.state == .connecting` post-resume.

---

## Phase 7 — `AudioPlayer` forwarder + `PlaybackCoordinator` wiring

- [ ] **7.1** Add `func setStreamSilenced(_ silenced: Bool)` to `AudioPlayer` after `deactivateStreamBridge()` (`AudioPlayer.swift:534-536`). Body: `engine.setStreamSilenced(silenced)`.
- [ ] **7.2** Add `#if DEBUG var isStreamSilenceGateActive: Bool` getter on `AudioPlayer` for tests.
- [ ] **7.3** In `PlaybackCoordinator.init(...)` after `setupRemoteCommands()` (`PlaybackCoordinator.swift:185`), assign `streamPlayer.silenceGateForwarder = { [weak self] silenced in self?.audioPlayer.setStreamSilenced(silenced) }`.
- [ ] **7.4** In `streamPlayer.onFormatReady` callback (`PlaybackCoordinator.swift:155-163`), after `audioPlayer.activateStreamBridge(...)`, add `self.audioPlayer.setStreamSilenced(false)` to clear any stale gate state (covers reconnect-after-long-pause path).
- [ ] **7.5** Build green. Manual smoke: play stream, pause, hear silence < 25 ms; resume; hear audio < 500 ms.

**Acceptance:** Coordinator wiring is the only call site for `silenceGateForwarder`. AudioPlayer forwarder is the only call site for `engine.setStreamSilenced` outside tests.

---

## Phase 8 — Tests (Swift Testing)

- [ ] **8.0** Add DEBUG test seams to production source per plan.md §Phase 8 "Test seams" (all behind `#if DEBUG`, all `internal`):
   - `AudioEngineController.makeStreamRenderBlockForTesting(ringBuffer:silenceGate:)`.
   - `StreamDecodePipeline.injectTerminationForTesting(_:)`, `isPausedByUserForTesting()`, `decoderHasQueuedPacketsForTesting()`, `enqueueRawPacketForTesting(data:descriptions:)`, `decodeContextForTesting`.
   - `DecodeContext.isPausedByUserSnapshotForTesting()`, `decoderHasQueuedPacketsForTesting()`, `enqueueRawPacketForTesting(...)`.
   - `DecodeContextTestProxy` struct (file-private, DEBUG-only).
   - `StreamPlayer.isResumeWarmupActiveForTesting`, `hasPrebufferContinuationForTesting`, `isResumeWarmingForTesting`, `attemptReconnectInvocationCountForTesting`, `pipelineStartInvocationCountForTesting`, `pipelineStateForTesting`, `injectPipelineTerminationForTesting(_:)`, `setWasActivelyPlayingForTesting(_:)`.
   - Increment `attemptReconnectInvocationCountForTesting` and `pipelineStartInvocationCountForTesting` inside `#if DEBUG` blocks at all relevant call sites.
   - Confirm release build still compiles cleanly: `swift build -c release` AND `xcodebuild -configuration Release` both green.
- [ ] **8.1** Create `Tests/MacAmpTests/StreamPauseTailTests.swift`. Use `@testable import MacAmp` (NOT `MacAmpApp` — module name is `MacAmp` per `Package.swift:5,18`). The file is auto-included via path-globbing in `Package.swift:39`; no `xcodegen generate` rerun is required for the SwiftPM target. (XcodeGen-driven Xcode target also globs `Tests/MacAmpTests/**/*.swift` — confirm during 8.8.)
- [ ] **8.2** Write `silenceGateProducesZeros`: pre-fill synthetic ring with non-zero data, build render block via `makeStreamRenderBlockForTesting`, render once with gate=0 → assert nonzero. Set gate=1, render → assert all zeros + `isSilence == true`. Set gate=0 → assert ring data flows again.
- [ ] **8.3** Write `pauseDuringBuffering`: instantiate `StreamPlayer` with a stub URL that resolves to a local file:// MP3 fixture (or use `decodeContextForTesting` to enqueue packets directly). Call `pause()` before `formatReadyFired`; assert (a) no crash, (b) `pipeline.state` transitions correctly, (c) `decoder.hasQueuedPackets == false` after pause (read via `decodeContextForTesting`).
- [ ] **8.4** Write `pauseSpam`: 20 alternating `pause()/resume()` within 200 ms via `await Task.yield()` between each. After loop: assert `isResumeWarmupActiveForTesting == false`, `hasPrebufferContinuationForTesting == false`, no test timeout (test completes < 5 s), `wasActivelyPlaying` value is consistent (still true if was true at start).
- [ ] **8.5** Write `longPauseSuppressesReconnect`: use `streamPlayer.setWasActivelyPlayingForTesting(true)` to short-circuit the active-play setup. Call `pause()` (sets `userPaused=true`). Use `streamPlayer.injectPipelineTerminationForTesting(.networkError("conn lost", NSURLErrorNetworkConnectionLost))`. Assert: `streamPlayer.isReconnecting == false`, `streamPlayer.attemptReconnectInvocationCountForTesting == 0`, `audioPlayer.isBridgeActive == false` (bridge torn down — Critical fix). Subsequently call `resume()`; assert `streamPlayer.pipelineStartInvocationCountForTesting >= 1` (fresh `pipeline.start` was issued, not `dataTask.resume()`).
- [ ] **8.6** Write `tailLengthBound`: synthetic SPSC harness — spin up a producer thread feeding a 1 kHz tone at 44.1 kHz into a ring buffer; let ring fill near full (capacity 32 768). Build render block via `makeStreamRenderBlockForTesting`. Trigger `pause()` equivalent (raise the gate atomic directly in the test). Pump render block 8 × 512-frame iterations; record `lastNonZeroFrameIndex` across iterations. Assert: `lastNonZeroFrameIndex < 512` (≤ 11.6 ms = 1 render quantum).
- [ ] **8.7** Run full test suite with TSan: `xcodebuildmcp macos test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`. Zero new TSan warnings.
- [ ] **8.8** All 5 new tests pass; all existing 57 tests still pass. If using XcodeGen-managed `.xcodeproj` for IDE flow: confirm new test file appears in the IDE after `xcodegen generate` (path-globbing handles it; if not, add to `project.yml` test target sources).

**Acceptance:** 5 new tests added; suite size ≥ 62; TSan clean. Module import line is `@testable import MacAmp`. All DEBUG test seams compile in release config (verify via `-c release` build).

---

## Verification (manual + automated)

- [ ] **V.1** Manual: launch app, play SHOUTcast/Icecast MP3 stream (e.g. SomaFM). Pause → audible silence within 30 ms (subjective). Resume → audio returns within 500 ms (no surprise "Connecting…").
- [ ] **V.2** Manual: long pause (60 s) on stream. Confirm UI title bar stays on station name throughout. Resume succeeds (fresh socket if server timed out).
- [ ] **V.3** Manual: pause → unplug Ethernet/Wi-Fi → wait 30 s → reconnect network → resume. Should reconnect to live edge cleanly.
- [ ] **V.4** Manual: pause-spam (mash pause/resume rapidly for 5 s). UI remains responsive, no deadlock, no stuck buffering state.
- [ ] **V.5** Manual: local-file pause regression check — load 3 local MP3/FLAC, pause and resume. Sample-accurate, no audible artifacts.
- [ ] **V.6** Manual: BlackHole loopback recording. Capture 5 s of stream → pause → 1 s → analyze in Audacity. Trailing audio after pause < 25 ms at 44.1 kHz, < 30 ms at 22.05 kHz.
- [ ] **V.7** Build verification: `xcodegen generate && xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` clean build.
- [ ] **V.8** Test verification: `xcodebuildmcp macos test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` all green, no TSan warnings.

---

## Oracle code review gate

- [ ] **O.1** Run Oracle (`mcp__codex-cli__codex`, model `gpt-5.5`, `reasoningEffort: xhigh`) on the implementation diff. Forward: `plan.md`, `research.md`, `principles.md`, all modified files.
- [ ] **O.2** Iterate until Oracle score ≥ 9/10. Append findings + resolutions to plan.md §13 table.
- [ ] **O.3** Update `tasks/stream-pause-tail/state.md` with current status + Oracle score.

---

## PR

- [ ] **PR.1** Commit chain matches plan.md §11 (3–5 logical commits aligned with phases).
- [ ] **PR.2** Push branch, open PR with body summarizing: failure modes fixed (audible tail + reconnect-during-pause), ADR references, Oracle score, manual test plan checked off.
- [ ] **PR.3** Wait for `mainwindow-visualizer-isolation` (PR #A) to merge.
- [ ] **PR.4** Rebase onto post-A `main`. Re-run TSan tests. Re-run Oracle if any non-trivial conflict resolution required.
- [ ] **PR.5** Merge after review.

---

## Post-merge

- [ ] **PM.1** Update `tasks/_context/state.md` Sprint S3 row for `stream-pause-tail` to ✅ MERGED with PR #.
- [ ] **PM.2** Move `tasks/stream-pause-tail/` → `tasks/done/stream-pause-tail/` (per project hygiene convention from PR #b8e0438).
- [ ] **PM.3** Confirm `hls-streaming-support` (S3-3) plan-writer rebases its line-number references against post-merge `StreamDecodePipeline.swift` and `StreamPlayer.swift`.
- [ ] **PM.4** Verify `BUILDING_RETRO_MACOS_APPS_SKILL.md` lessons list — if a generally-applicable lesson emerged (e.g., "atomic silence gate pattern for RT producer-consumer pause"), add it.
