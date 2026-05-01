# Todo: Video Audio Engine Routing

> **Plan:** `tasks/video-audio-engine-routing/plan.md`
> **Branch:** `feat/video-audio-engine-routing` (after S3-1 merged)
> **Spike branch:** `spike/vaer-av-drift-measurement` (throwaway)

Numbering convention: `<Phase>.<Item>`. Mark `[x]` on completion. Use `[~]` for in-progress, `[!]` for blocked.

---

## Phase 0 — A/V Sync Spike (throwaway branch) ✅ COMPLETE

> **Outcome:** **Path NONE** — frequency-locked clocks confirmed empirically. Plan §9 Phase 4 collapses to no-op. See `research.md` "Phase 0 — Spike Results" for full data.
> **Spike branch:** `spike/vaer-av-drift-measurement` (4 commits, never pushed) — deleted per plan §5.5.
> **Findings commit on main:** `1d4eca1`.

### 0.1 Spike preparation

- [x] 0.1.1 Confirmed S3-1 merged to main.
- [x] 0.1.2 Created `spike/vaer-av-drift-measurement` from main.
- [x] 0.1.3 Sourced 5 test video files (deviation: stored in repo `clapperboard-videos/`, gitignored, not `~/Movies/macamp-vaer-spike/`).
- [x] 0.1.4 User recorded clapperboard files (~3 sec each) — public-domain sources weren't readily available.
- [N/A] 0.1.5 Repo `.gitignore` already covered `*.mp4`/`*.mov`; user added `*.m4v` separately for project-wide use.

### 0.2 Spike implementation

- [x] 0.2.1 Built `MinimalTap` in standalone SPM target under `tasks/video-audio-engine-routing/spike/` (deleted with branch).
- [x] 0.2.2 Built `EngineBridge` (AVAudioEngine + AVAudioSourceNode) wiring.
- [x] 0.2.3 Built measurement harness using `AVPlayer.currentTime()` correlated against tap-delivered cumulative frames (simpler equivalent to plan §5.3's `AVPlayerItemVideoOutput.copyPixelBuffer` approach — same drift signal, fewer moving parts).
- [x] 0.2.4 Built CSV output: per-file summary CSV + per-tick trace CSV with status, rate, framesWritten, framesRendered.

### 0.3 Spike measurement

- [x] 0.3.1 Ran playback against all 5 files. Initial 30-sec runs were dominated by loop-boundary noise (3-sec clips × 9 loops); switched to 2-sec single-pass per file for clean steady-state.
- [x] 0.3.2 Captured initial offsets, peak drift, and per-tick trace. Slope analysis over post-warmup window (≥0.5 s, status=playing).
- [N/A] 0.3.3 Subjective listening check skipped — harness doesn't display video frames; perception test deferred to plan §5.3 during implementation manual verification.
- [N/A] 0.3.4 Path A (`AVPlayer.sourceClock`) escalation NOT NEEDED — slope across all 5 files clusters around zero (mean -0.75 ms/sec, 95% CI [-6.4, +4.9]).
- [N/A] 0.3.5 Path B (pre-roll) escalation NOT NEEDED.
- [N/A] 0.3.6 KILL SWITCH not triggered.

### 0.4 Spike findings

- [x] 0.4.1 "Phase 0 — Spike Results" section appended to `tasks/video-audio-engine-routing/research.md` (commit `1d4eca1` on main).
- [x] 0.4.2 Path NONE documented with full quantitative data, slope statistics, and Gemini/Oracle synthesis.
- [N/A] 0.4.3 Path A API research skipped (Path NONE selected).
- [N/A] 0.4.4 Path B sub-plan skipped (Path NONE selected).
- [x] 0.4.5 Plan §9 outcome: Phase 4 = no-op. Captured in plan.md context plus todo §4.NONE below.
- [x] 0.4.6 Spike branch deleted: `git branch -D spike/vaer-av-drift-measurement`.

### 0.5 Implementation-phase implications discovered during spike

- [x] 0.5.1 Plan §7.5 AudioConverter promoted from "edge case handler" to **load-bearing**. Without it, 44.1 kHz source audio plays as discontinuous bursts every ~76 ms (engine consumes at 48k, tap supplies at 44.1k, ring underflows). Phase 2 todo 2.3.x items are now mandatory, not optional.
- [x] 0.5.2 Drift formula `drift = AVPlayer.currentTime - cumulativeFrames/sampleRate` measures decoded-vs-presentation offset (~200 ms constant), not perceptible A/V drift. Future debugging that uses this metric must factor out the pipeline-depth phase offset before computing slope.

---

## Phase 1 — Engine Configuration Change Observer ✅ COMPLETE

> **Outcome:** 10 commits on `feat/video-audio-engine-routing` (`d5081e9` … `e7f8eed`). Local-file + stream + AirPlay verified manually; 72/72 tests pass with TSan. Three Oracle-driven follow-up commits address all HIGH-priority review items. Plan §6.3 updated to reflect actual implementation contract.

### 1.1 Implementation

- [x] 1.1.1 Created branch `feat/video-audio-engine-routing` from main (post-S3-1).
- [x] 1.1.2 Created `MacAmpApp/Audio/AudioEngineConfigurationObserver.swift` (commits `d5081e9` + `c454c49` for Oracle-driven re-entrancy guard).
    - [x] @MainActor class
    - [x] init takes `AVAudioEngine`
    - [x] `start()` / `stop()` idempotent
    - [x] Debounce window 150 ms (cancel-and-replace pattern, semantically equivalent to plan-spec'd generation counter for single-task case)
    - [x] `onWillReconfigure` / `onDidReconfigure` callbacks
    - **Modernizations applied:** AsyncSequence (`NotificationCenter.notifications(named:object:)`), `Task.sleep(for: Duration)`, `Notification.Name` (not `NSNotification.Name`), `isolated deinit`, `@preconcurrency import AVFoundation`.
- [x] 1.1.3 Added observer to `AudioEngineController.swift` (commit `63dda27`).
    - [x] `private let configObserver` (no `@ObservationIgnored` needed — class is not `@Observable`; plan note was mistaken)
    - [x] Initialized in `init()` after `setupEngine()`
    - [x] Wired `handleEngineWillReconfigure` / `handleEngineDidReconfigure`
- [x] 1.1.4 Added `PreReconfigureSnapshot` struct + `onEngineWillReconfigure` / `onEngineDidReconfigure` callbacks per plan §6.3 (commit `63dda27`).
- [x] 1.1.5 Wired `onEngineWillReconfigure` callback in `AudioPlayer` init (commits `d95cccf` + `3267091` for AirPlay-resume regression fix):
    - [x] Stores received snapshot in `pendingReconfigureSnapshot` (with currentTime/wasPlaying overridden by AudioPlayer's authoritative state — see `3267091` rationale)
    - [x] Bumps `currentSeekID = UUID()` BEFORE engine restart (filters stale completions)
    - [x] Sets `seekGuardActive = true`, `isHandlingCompletion = true`
- [x] 1.1.6 Wired `onEngineDidReconfigure` callback in `AudioPlayer` (commit `d95cccf`):
    - [x] Re-applies volume + balance via `engine.setVolume` / `engine.setBalance`
    - [x] Local-audio path: ALWAYS reschedules from `snapshot.currentTime` (since `play()` does NOT itself reschedule per AudioPlayer.swift:476)
        - [x] If `wasPlaying`: `engine.startEngineIfNeeded()` + `installVisualizerTapIfNeeded()` + `playAudio()` + `startProgressTimer()` + `transition(to: .playing)`
        - [x] Else: `transition(to: .paused)` (segment is primed; next user `play()` resumes from saved point)
    - [x] Stream bridge: fires `onEngineReconfigured` callback (workgroup refresh — see 1.1.7)
    - [x] Video bridge: TODO comment placeholder for Phase 3 (no-op currently since `wasVideoBridge` is hardcoded false)
    - [x] Clears `seekGuardActive` after 100 ms (modern `Task.sleep(for: .milliseconds(100))`)
    - [x] Clears `isHandlingCompletion` after 200 ms (modern Duration API)
- [x] 1.1.7 Wired `onEngineReconfigured` in `PlaybackCoordinator` to refresh stream workgroup via `streamPlayer.setAudioWorkgroup(audioPlayer.audioWorkgroup)` (commit `ce7e889`). Bridge-active gate keeps it a no-op when no stream is playing.

### 1.2 Tests

- [x] 1.2.1 Created `Tests/MacAmpTests/EngineConfigObserverTests.swift` (commits `694666c` + `1052331`):
    - [x] `observerFiresOnSyntheticNotification` — single notification fires one will/did pair
    - [x] `observerDebouncesBurst` — 3 notifications within 60 ms collapse to one will/did pair
    - [x] `observerStopDuringBurstCancelsDid` — Oracle-flagged contract test (commit `1052331`)
    - [x] `observerSurvivesStartStopCycles` — multiple start/stop cycles + posts-while-stopped no-op (commit `1052331`)
    - **Note:** test file lives at `Tests/MacAmpTests/` (flat layout matches existing convention) rather than the plan-spec'd `Tests/MacAmpTests/Audio/` subdir which doesn't exist in this codebase.

### 1.3 Manual verification ✅

- [x] 1.3.1 Built with `xcodegen generate && xcodebuildmcp macos build/test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`. TSan-on, 72/72 pass.
- [x] 1.3.2 Local file: play → switch output via Control Center (built-in ↔ external) → audio resumes from saved time, EQ still active. Verified.
- [x] 1.3.3 Stream: play → switch output → audio resumes < 1 s, ICY metadata flowing, visualizer animating. Verified.
- [x] 1.3.4 AirPlay coverage (added during verification): play → switch to/from AirPlay → resumes from saved time. Initial regression on this path was caught and fixed by `3267091`. Verified post-fix.
- [x] 1.3.5 Paused-then-routed-then-resume: works for both local and stream paths.
- [x] 1.3.6 Seek mid-track + switch output: seek state stays clean (no spurious "track ended" or position reset).
- [x] 1.3.7 Local↔stream↔local transitions across output switches: no audio leakage, no engine errors.
- [x] 1.3.8 `/usr/bin/log show` over the 15-minute test window: zero `<Error>`/`<Fault>`-level MacAmp entries; zero `-10868`; zero `AudioEngine.start error`. CoreAudio HAL `!obj`/`!dev`/`'nope'` chatter on AirPlay→built-in transitions noted as OS-level device-teardown noise (not actionable; documented in state.md "CoreAudio HAL log observation").

### 1.4 Phase 1 follow-up commits (Oracle-driven, post-implementation review)

- [x] `fabe5e2` `cancelPendingReconfigure()` called from `play()`/`pause()`/`stop()`/`seek()`/`playTrack()` — addresses Oracle items #2, #4, #7 (stale `onDid` overriding new user intent).
- [x] `1052331` Lifecycle-interruption + start/stop cycle tests — addresses Oracle item #5 (untested contract from `c454c49`).
- [x] `e7f8eed` Plan §6.3 updated to document split state ownership + cancellation contract — addresses Oracle item #8 (plan/implementation drift).

---

## Phase 2 — MTAudioProcessingTap Implementation ✅ COMPLETE

> **Outcome:** 4 commits on `feat/video-audio-engine-routing`. Oracle pass-3 score 9.3/10 (clears the ≥9/10 bar). Tests 76 → 84 (+8 format-classification tests). All 84 pass with TSan. Plan §7 contract delivered; Phase 3 will wire the tap into AudioEngineController.

### 2.1 VideoAudioTap class

- [x] 2.1.1 Created `MacAmpApp/Audio/VideoAudioTap.swift` (~340 LOC) per plan §7.
- [x] 2.1.2 `VideoAudioTapContext` defined as `final class @unchecked Sendable`, queue-confined to the tap render thread.
    - [x] Holds `LockFreeRingBuffer` reference
    - [x] Holds optional `AudioConverterRef` + scratch buffer + processingFormat ASBD
    - [x] Atomic `lastCallbackHostTime` (`ManagedAtomic<UInt64>`)
    - [x] Atomic `fallbackRequested` (`ManagedAtomic<Bool>`) — Phase 5 watchdog reads this in addition to the host-time stall
    - [x] `sourceChannelLayout: Data?` captured in attach() from the asset's format description (Oracle pass-2 follow-up)
- [x] 2.1.3 `init(ringBuffer:expectedSampleRate:)`.
- [x] 2.1.4 `attach(to: AVPlayerItem) async throws -> AVMutableAudioMix` — modernized to async to use the non-deprecated `loadTracks(withMediaType:)` (deviation from plan §7.3's sync signature).
    - [x] Builds `MTAudioProcessingTapCallbacks`
    - [x] `MTAudioProcessingTapCreate` with `kMTAudioProcessingTapCreationFlag_PostEffects`
    - [x] `Unmanaged<VideoAudioTapContext>.passRetained` for clientInfo (released exactly once in tapFinalize)
    - [x] Builds `AVMutableAudioMixInputParameters` for first audio track
    - [x] Returns assembled `AVMutableAudioMix`
    - [x] Captures source channel layout from `CMAudioFormatDescriptionGetChannelLayout` for surround downmix accuracy
    - [x] Resets stale layout state on reattach (defensive — Oracle pass-3 follow-up)
- [x] 2.1.5 `detach()` — nils our hold on the tap CFType (auto-managed in Swift; no `Unmanaged` needed for the tap itself). Caller responsibility: set `playerItem.audioMix = nil` BEFORE detach so AVPlayer's hold is gone too.
- [x] 2.1.6 `lastCallbackHostTime` + `fallbackRequested` accessors.
- [x] 2.1.7 No explicit deinit needed — Swift ARC handles tap CFType release; tapFinalize drops the Unmanaged context.

### 2.2 C-convention callbacks

- [x] 2.2.1 `tapPrepare`: captures format, classifies via `shouldBypassConverter`, lazily builds AudioConverter on mismatch, configures channel mapping for non-stereo sources.
- [x] 2.2.2 `tapProcess`: calls `MTAudioProcessingTapGetSourceAudio`, optionally converts, writes to ring buffer, updates `lastCallbackHostTime`. **Does NOT zero the bufferList** (AVPlayer plays it; mute via `player.volume = 0` in Phase 3).
- [x] 2.2.3 `tapUnprepare`: disposes converter, deallocates scratch.
- [x] 2.2.4 `tapFinalize`: releases `Unmanaged<VideoAudioTapContext>`.

### 2.3 Format-edge handling

- [x] 2.3.1 Mono source → stereo via explicit `kAudioConverterChannelMap = [0, 0]` (duplicates single channel to L+R; default routing would leave R silent).
- [x] 2.3.2 3-8 channel surround → stereo via input/output AudioChannelLayout properties + `kAudioConverterPropertyPerformDownmix = 1` (Oracle pass-2 follow-up; without PerformDownmix the converter installs layouts but never applies the downmix matrix).
- [x] 2.3.3 Non-Float32 source → Float32 conversion via AudioConverter.
- [x] 2.3.4 Sample-rate mismatch → resample via AudioConverter (load-bearing per Phase 0 — without it 44.1 kHz audio plays as bursts at engine's 48 kHz consumer rate).
- [x] 2.3.5 If `AudioConverterNew` fails OR channel-mapping fails → `ctx.fallbackRequested.store(true)`, ring writes skipped. Phase 5 picks up.

### 2.4 Tests

- [x] 2.4.1 Created `Tests/MacAmpTests/VideoAudioTapTests.swift` (flat layout, no `Audio/` subdir per Phase 1 convention).
    - [x] `attachReturnsAudioMixForAudioAsset` — happy path with synthetic silence WAV
    - [x] `attachThrowsForVideoOnlyAsset` — empty AVMutableComposition exercises `.noAudioTrack` guard
    - [x] `detachIsIdempotent`
    - [x] `initialStateBeforeFirstCallback` — `lastCallbackHostTime == 0`, `fallbackRequested == false`
    - [x] 6 bypass-classification tests (canonical Float32 stereo, Float64, mono, sample-rate mismatch, non-interleaved, integer PCM)
    - [x] 2 surround-layout-map tests (3-8 channel coverage + non-surround rejection)
    - **Note:** ring-buffer-throughput and formatMismatchTriggersAudioConverter behavior fires only inside Core Audio render-thread callbacks; deferred to Phase 7 manual verification (plan §14, todo §7.4.2/7.4.3).

### 2.5 Commits

- [x] `14d47af` feat(audio): add VideoAudioTap with MTAudioProcessingTap callbacks
- [x] `48244f4` test(audio): add VideoAudioTap unit tests
- [x] `09cb521` fix(audio): tighten format detection + channel mapping (Oracle pass-1, 8.2/10)
- [x] `b9a8478` fix(audio): surround downmix + AAC layouts + tests (Oracle pass-2, 8.4/10 → 9.3/10)
- [x] `749b91d` fix(audio): clear stale channel layout on tap reattach (Oracle pass-3 defensive)

---

## Phase 3 — Engine Source Node + Wiring ✅ COMPLETE

### 3.1 AudioEngineController extensions

- [x] 3.1.1 Added `videoSourceNode`, `videoRingBuffer`, `isVideoBridgeActive` fields per plan §8.1.
- [x] 3.1.2 Added `makeVideoRenderBlock` (parallel to `makeStreamRenderBlock`, kept inline per Principle 4 / AHA Rule of Three at N=2).
- [x] 3.1.3 Implemented `activateVideoBridge(ringBuffer:sampleRate:)`.
- [x] 3.1.4 Implemented `deactivateVideoBridge()` (idempotent).

### 3.2 Mutual exclusion

- [x] 3.2.1 `rewireForFile(_:)` deactivates both stream and video bridges.
- [x] 3.2.2 `activateStreamBridge(...)` deactivates the video bridge first.
- [x] 3.2.3 `activateVideoBridge(...)` deactivates the stream bridge first AND stops `playerNode` if running.

### 3.3 Volume / balance forwarding

- [x] 3.3.1 `setVolume(_:)` forwards to `videoSourceNode?.volume`.
- [x] 3.3.2 `setBalance(_:)` forwards to `videoSourceNode?.pan`.

### 3.4 AudioPlayer integration

- [x] 3.4.1 Added `videoAudioTap: VideoAudioTap?`, `videoRingBuffer: LockFreeRingBuffer?`, and `videoLoadTask: Task<Void, Never>?` (Oracle pass-1 follow-up — cancellable async setup).
- [x] 3.4.2 Added `isVideoBridgeActive` getter delegating to `engine.isVideoBridgeActive`.
- [x] 3.4.3 Refactored `playTrack` video branch into `startVideoTrack(track)` (async via Task — `await tap.attach(to:)` is async per Phase 2 architectural shift; activates bridge on attach success, drops refs on failure for direct AVPlayer fallback).
- [x] 3.4.4 `stop()` and audio↔video switch in `playTrack` call new `tearDownVideoBridge()` helper (cancels `videoLoadTask`, deactivates bridge, detaches tap, clears refs).
- [x] 3.4.5 `isEngineRendering` includes `engine.isVideoBridgeActive`.

### 3.5 VideoPlaybackController extensions

- [x] 3.5.1 `loadVideo(url:autoPlay:)` → `loadVideo(url:autoPlay:audioTap:) async -> Bool` (returns whether tap successfully attached).
- [x] 3.5.2 Tap attached BEFORE play() per plan §8.4 (post-await `self.player === newPlayer` guard catches mid-await player swaps — Oracle pass-1 hardening).
- [x] 3.5.3 Tracks `attachedTap` field for cleanup.
- [x] 3.5.4 `detachAudioTap()` method: sets `playerItem.audioMix = nil` BEFORE `tap.detach()`, clears `attachedTap`. Idempotent.
- [x] 3.5.5 `cleanup()` calls `detachAudioTap()` (single unified teardown path); `isolated deinit` mirrors the ordering.

### 3.6 Tests

- [x] 3.6.1 Created `Tests/MacAmpTests/AudioEngineControllerVideoBridgeTests.swift` (flat layout per Phase 1/2 convention, not the `Audio/` subdir originally specced).
    - [x] `activateVideoBridgeAddsSourceNode`
    - [x] `activateVideoBridgeDeactivatesStreamBridge`
    - [x] `activateStreamBridgeDeactivatesVideoBridge` (symmetric, added during implementation)
    - [x] `deactivateVideoBridgeIsIdempotent`
    - [x] `videoRenderBlockReadsRingBuffer` (test seam — `makeVideoRenderBlockForTesting`)
    - [x] `videoRenderBlockSilenceOnEmptyRing` (test seam — underflow zero-fill + `isSilence`)
    - **Note:** `setVolumeForwardsToVideoSourceNode` originally specced; covered indirectly by other tests (videoSourceNode is private, direct verification would require visibility widening). Manual verification at Phase 7 §7.2.7.

### 3.7 Build + commits

- [x] 3.7.1 `xcodegen generate` after adding test file.
- [x] 3.7.2 Build + tests with TSan green at every checkpoint (84 → 90 tests).
- [x] 3.7.3 Per-step commits (nine total — six implementation + three regression-fix from real-video manual test):
    - `dcce548` feat(audio): add video bridge to AudioEngineController
    - `33d9e49` feat(audio): wire AudioPlayer video branch through engine bridge
    - `4aac795` test(audio): video bridge state machine + render block tests
    - `3fd4d26` fix(audio): guard video tap attach against player swaps mid-await
    - `7e953bd` fix(audio): tap-identity stale check + cancellable load task (impl Oracle pass-1, 8.4/10 → 9.2/10)
    - `1fa5aad` fix(audio): cancel video load + drop bridge in AudioPlayer deinit (impl Oracle pass-2, 9.2/10 → 9.4/10 — initial gate clear)
    - `f41418a` fix(audio): video display + double-audio regressions from Phase 3 wiring (real-video manual surfaced @ObservationIgnored re-render miss + slider-un-mute double-audio)
    - `f18c518` fix(audio): tighten video-bridge teardown + play() ordering (regression-fix Oracle pass-1, 7/10 → 8/10 — tear-down restore over-broad; play()-before-attach race)
    - `d112e1b` fix(audio): clear videoLoadTask after Task body claims active load (regression-fix Oracle pass-2, 8/10 → **9.5/10 final** — completed task was permanently blocking pause/resume)

---

## Phase 4 — Sync Strategy ✅ NO-OP per Phase 0

> **Path NONE** selected by Phase 0 spike. Phase 4 is a no-op. See `research.md` "Phase 0 — Spike Results" for the empirical data.

### Path NONE (drift < 30 ms — selected)

- [x] 4.NONE Documented in `research.md` that no sync code was needed; phase is a no-op. No `sourceClock` / pre-roll wiring goes into production. Manual perception test (plan §5.3) is the residual check during Phase 7 manual verification.

### Path A (`AVPlayer.sourceClock`) — SKIPPED

- [N/A] 4.A.1 — Path NONE confirmed; sourceClock not needed.
- [N/A] 4.A.2
- [N/A] 4.A.3
- [N/A] 4.A.4

### Path B (Pre-roll buffering) — SKIPPED

- [N/A] 4.B.1 — Path NONE confirmed; pre-roll not needed.
- [N/A] 4.B.2
- [N/A] 4.B.3
- [N/A] 4.B.4

---

## Phase 5 — Tap Failure Fallback ✅ COMPLETE (1 commit, Oracle 9.2/10 pass 2, 94/94 TSan)

### 5.1 Watchdog ✅

- [x] 5.1.1 Add `videoTapWatchdogTask: Task<Void, Never>?` to AudioPlayer.
- [x] 5.1.2 Add `videoTapFallbackActive: Bool = false` flag (`private(set) var`, observable for Phase 6 capability surface).
- [x] 5.1.3 Implement watchdog logic: every 250 ms check `(now - tap.lastCallbackHostTime) > 1000 ms` AND `videoPlaybackController.isPlaying` AND `engine.isVideoBridgeActive`. **Co-design from Oracle pass 1:** uses `max(last, resumeBaselineHost)` so a stale pre-pause callback can't false-positive on resume.
- [x] 5.1.4 Start watchdog when video bridge activates (only when `engine.isVideoBridgeActive == true` after activation); stop when video stops, fallback engages, or bridge deactivates.

### 5.2 Fallback sequence ✅ (`@MainActor` per plan §10.2)

- [x] 5.2.1 Idempotency guard: `guard !videoTapFallbackActive else { return }`.
- [x] 5.2.2 Cancel watchdog FIRST: `stopVideoTapWatchdog()`.
- [x] 5.2.3 Set `videoTapFallbackActive = true`.
- [x] 5.2.4 Log error: `AppLog.error(.audio, "Video audio tap stalled — restoring AVPlayer.volume fallback")`.
- [x] 5.2.5 `engine.deactivateVideoBridge()` (guarded with `if engine.isVideoBridgeActive`).
- [x] 5.2.6 `videoPlaybackController.detachAudioTap()` — already present from Phase 3, sets audioMix=nil before tap.detach.
- [x] 5.2.7 Clear `videoAudioTap = nil` and `videoRingBuffer = nil`.
- [x] 5.2.8 Restore AVPlayer volume: `videoPlaybackController.volume = volume` (didSet propagates to `player.volume`).
- [x] 5.2.9 Reset `seekGuardActive = false` (no `currentSeekID` bump per plan).
- [x] 5.2.10 In `playTrack`, reset `videoTapFallbackActive = false` after `updatePlaylistPosition` and before per-track setup.

### 5.3 Volume-during-fallback ✅

- [x] 5.3.1 Existing gate `if engine?.isVideoBridgeActive != true { videoPlaybackController.volume = volume }` is preserved per plan §10.3 — bridge deactivates in fallback so forwarding resumes naturally. Phase 6 §11.6 tightens the gate to `videoTapFallbackActive`-aware semantics.

### 5.4 Tests ✅ (4 added)

- [x] 5.4.1 `Tests/MacAmpTests/VideoTapFallbackTests.swift`:
    - [x] `engageRestoresAVPlayerVolume` — engage flips flag and restores controller volume.
    - [x] `engageIsIdempotent` — second engage no-ops; external mute survives.
    - [x] `watchdogEngagesOnFallbackRequested` — real bridge + real tap, sets `fallbackRequested`, sleeps 600 ms, asserts `videoTapFallbackActive == true` and `isVideoBridgeActive == false`.
    - [x] `playTrackResetsFallbackFlag` — flag cleared on next track.

### 5.5 Co-fixes (pulled in to make Phase 5 correct, Oracle pass-1 MUST-FIXes)

- [x] 5.5.1 `VideoAudioTap.tapProcess` flags `fallbackRequested` on `MTAudioProcessingTapGetSourceAudio` non-noErr.
- [x] 5.5.2 `VideoAudioTap.tapProcess` flags `fallbackRequested` on `AudioConverterFillComplexBuffer` non-noErr/non-noMoreInputData.
- [x] 5.5.3 `lastCallbackHostTime` now updated only after a successful ring write (both converter path and bypass path), so converter-fault loops can't mask the stall by appearing healthy.
- [x] 5.5.4 `startVideoTrack` Task body guards `engine.isVideoBridgeActive` after `engine.activateVideoBridge`; if engine refused to start, detaches tap and restores AVPlayer volume.

### 5.6 Commit ✅

- [x] 5.6.1 `adf3fa4` feat(audio): add video tap-failure watchdog + AVPlayer fallback

---

## Phase 6 — Capability Flag Surface ✅ COMPLETE (1 commit, Oracle 9/10 pass 2, 102/102 TSan)

### 6.1 PlaybackCoordinator ✅

- [x] 6.1.1 Update `supportsAudioProcessing` per plan §11.2 (three-branch: stream / video / local).

### 6.2 AudioPlayer ✅

- [x] 6.2.1 Update `snapshotButterchurnFrame()` per plan §11.3 (bridge-aware guard).
- [x] 6.2.2 `isEngineRendering` already extended to include video bridge in Phase 3.
- [x] 6.2.3 Update `volume.didSet` per plan §11.6. **Deviation:** uses `currentMediaType == .video, engine?.isVideoBridgeActive != true` rather than the plan's narrower `videoTapFallbackActive`. Oracle-approved — broader gate covers attach-failure and engine-activation-failure paths added in Phase 3 that aren't watchdog-flagged.
- [x] 6.2.4 Remove `engine.removeVisualizerTapIfNeeded()` from `playTrack` audio→video transition per plan §11.4.

### 6.3 Observation fix (Oracle pass-1 MUST-FIX)

- [x] 6.3.1 Add `onVideoBridgeStateChanged` callback to `AudioEngineController`, fire on activate/deactivate.
- [x] 6.3.2 Switch `AudioPlayer.isVideoBridgeActive` from computed-passthrough to `private(set) var` mirror updated via the callback. SwiftUI Observation now tracks bridge flips correctly.
- [x] 6.3.3 Update `isEngineRendering` to read the mirror property.

### 6.4 Tests ✅ (5 added)

- [x] 6.4.1 `Tests/MacAmpTests/AudioPlayerVideoCapabilityTests.swift`:
    - [x] `supportsAudioProcessingForLocalAudioReturnsTrue`
    - [x] `supportsAudioProcessingWithActiveVideoBridge`
    - [x] `supportsAudioProcessingWithVideoTapFallback`
    - [x] `supportsAudioProcessingForVideoWithoutBridgeReturnsFalse`
    - [x] `snapshotButterchurnFrameNilForVideoWithoutBridge`
    - [x] `snapshotButterchurnFrameWorksForVideoBridge`
    - [x] `volumeDoesNotForwardWhileBridgeActive`
    - [x] `volumeForwardsToAVPlayerWhenBridgeInactive`

### 6.5 UI copy

- [x] 6.5.1 `MainWindowSlidersLayer` balance tooltip: "unavailable during streaming" → "unavailable on this audio path".

### 6.6 Commit ✅

- [x] 6.6.1 `d840a2b` feat(audio): enable EQ + visualizer + balance for video sessions

---

## Phase 7 — Tests + Verification

### 7.1 Test suite full run

- [ ] 7.1.1 `xcodebuildmcp macos test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — all green.
- [ ] 7.1.2 Verify no TSan warnings in test logs.
- [ ] 7.1.3 Commit any final test consolidation: `test(audio): video routing test coverage`.

### 7.2 Manual verification (PRE-MERGE)

- [ ] 7.2.1 5-min real video playback with TSan: no warnings, no audio dropouts.
- [ ] 7.2.2 Switch output device via Control Center mid-video: video keeps playing, audio resumes < 1 s.
- [ ] 7.2.3 EQ band slider during video: audible difference.
- [ ] 7.2.4 EQ presets applied to video: audible.
- [ ] 7.2.5 Visualizer (spectrum) animates during video playback.
- [ ] 7.2.6 Visualizer (oscilloscope) animates during video playback.
- [ ] 7.2.7 Balance slider during video: audible L/R shift.
- [ ] 7.2.8 Drift target verification: < 30 ms sustained over 5 minutes (using same Phase 0 harness).

### 7.3 Manual regression (PRE-MERGE)

- [ ] 7.3.1 Local mp3 playback: EQ + visualizer + balance still work.
- [ ] 7.3.2 Internet radio (44.1 kHz): EQ + visualizer + ICY metadata still work.
- [ ] 7.3.3 Internet radio (48 kHz): EQ + visualizer + ICY metadata still work.
- [ ] 7.3.4 Switch local → stream → local: no engine reset failures (-10868), no double audio.
- [ ] 7.3.5 Stream pause-tail (S3-1 feature): tail playout still works.
- [ ] 7.3.6 Visualizer pause during volume drag (S3-1 feature): still resolved.

### 7.4 Edge cases (PRE-MERGE)

- [ ] 7.4.1 Video file with no audio track → fallback path; no crash.
- [ ] 7.4.2 Video file with mono audio → tap downmixes to stereo.
- [ ] 7.4.3 Video file with 5.1 audio → tap downmixes to stereo.
- [ ] 7.4.4 Video → next track is local audio: clean teardown.
- [ ] 7.4.5 Video → next track is stream: video bridge → stream bridge transition clean.
- [ ] 7.4.6 Video paused, output device changed, video resumed: engine config observer reconnects.
- [ ] 7.4.7 Video reaches end-of-file: `onPlaybackEnded` fires, bridge deactivates.

### 7.5 Engine config observer manual

- [ ] 7.5.1 Local file playing → switch output → resumes < 1 s, EQ active.
- [ ] 7.5.2 Stream playing → switch output → resumes < 1 s, ICY metadata flowing.
- [ ] 7.5.3 Video playing → switch output → resumes < 1 s.

### 7.6 Verification agent

- [ ] 7.6.1 Spawn separate sub-agent per CLAUDE.md §6 to verify feature works end-to-end.
- [ ] 7.6.2 Sub-agent writes findings to `tasks/video-audio-engine-routing/verification.md`.

---

## Pre-PR Checklist

- [ ] P.1 `xcodegen generate` ran successfully (no project.yml warnings).
- [ ] P.2 `project.yml` includes new files (`VideoAudioTap.swift`, `AudioEngineConfigurationObserver.swift`).
- [ ] P.3 Build clean with TSan: zero warnings.
- [ ] P.4 All tests pass with TSan.
- [ ] P.5 No `// TODO` in production code (use `placeholder.md` if needed).
- [ ] P.6 No `// Deprecated` in production code (use `depreciated.md` if needed).
- [ ] P.7 Drift measurement re-run on production code: < 30 ms.
- [ ] P.8 Codex Oracle review on full diff. Score ≥ 9/10. Address actionable items.
- [ ] P.9 Update `tasks/_context/state.md` deferred-items inventory if anything new emerged.
- [ ] P.10 Update `verification.md` with sub-agent findings.

---

## PR Submission

- [ ] PR.1 Push branch: `git push -u origin feat/video-audio-engine-routing`.
- [ ] PR.2 `gh pr create` with title `feat(audio): route video audio through AVAudioEngine for EQ + visualizer + balance`.
- [ ] PR.3 PR body: link plan §1 (problem statement), Phase 0 spike findings, file-by-file summary, manual test checklist, TSan output snippet, drift measurement summary.
- [ ] PR.4 Reviewer: project owner (per skill-first workflow + sprint policy).

---

## Post-Merge

- [ ] PM.1 Move `tasks/video-audio-engine-routing/` to `tasks/done/video-audio-engine-routing/`.
- [ ] PM.2 Update `tasks/_context/state.md`: mark task COMPLETE, add Sprint S3 progress, note any deferred follow-ups.
- [ ] PM.3 Update `tasks/_context/tasks_index.md`.
- [ ] PM.4 Update relevant docs (likely `docs/MACAMP_ARCHITECTURE_GUIDE.md` to reflect three-bridge audio graph).
- [ ] PM.5 Add lessons-learned items to memory or `tasks/_context/` if anything notable emerged.
- [ ] PM.6 Verify spike branch `spike/vaer-av-drift-measurement` is deleted locally.

---

## Open Items / Deferrals (NOT blockers)

- [ ] D.1 Whether to surface a UI banner on tap fallback (user-visible "EQ unavailable for this video"). Currently log-only.
- [ ] D.2 Watchdog cadence tuning (250 ms baseline; revisit if false-positives observed in the wild).
- [ ] D.3 Auto-recovery from tap fallback on next playback (current design: sticky for current track only).
- [ ] D.4 Video file with embedded chapter markers: future work for chapter-aware sync; not in scope.
- [ ] D.5 Remote video sources (HTTP/HLS): explicitly OUT of scope per plan §2.
