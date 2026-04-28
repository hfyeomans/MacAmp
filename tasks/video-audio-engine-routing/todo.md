# Todo: Video Audio Engine Routing

> **Plan:** `tasks/video-audio-engine-routing/plan.md`
> **Branch:** `feat/video-audio-engine-routing` (after S3-1 merged)
> **Spike branch:** `spike/vaer-av-drift-measurement` (throwaway)

Numbering convention: `<Phase>.<Item>`. Mark `[x]` on completion. Use `[~]` for in-progress, `[!]` for blocked.

---

## Phase 0 — A/V Sync Spike (throwaway branch)

### 0.1 Spike preparation

- [ ] 0.1.1 Confirm S3-1 (`mainwindow-visualizer-isolation` + `stream-pause-tail`) is merged to main.
- [ ] 0.1.2 Create branch: `git checkout -b spike/vaer-av-drift-measurement` from latest main.
- [ ] 0.1.3 Source 5 test video files per plan §5.2 (mp4 44.1 kHz, mp4 48 kHz, mov 48 kHz, m4v 44.1 kHz, mp4 5.1 surround). Place in `~/Movies/macamp-vaer-spike/`.
- [ ] 0.1.4 If clean public-domain files unavailable, record three-second clapperboard files locally with QuickTime.
- [ ] 0.1.5 Add `~/Movies/macamp-vaer-spike/` to local-only `.gitignore` (DO NOT commit `.gitignore` change to main).

### 0.2 Spike implementation

- [ ] 0.2.1 Build minimal `VideoAudioTap` skeleton on the spike branch (no production polish — measurement only).
- [ ] 0.2.2 Build minimal `videoSourceNode` wiring in `AudioEngineController` (no mutual-exclusion plumbing yet — direct in-place test).
- [ ] 0.2.3 Build measurement harness: `AVPlayerItemVideoOutput.copyPixelBuffer(forItemTime:)` + ring buffer read host-time correlation.
- [ ] 0.2.4 Build CSV output for per-file drift readings at 5 s, 30 s, 60 s.

### 0.3 Spike measurement (5-minute runs per file, per plan §5.3)

- [ ] 0.3.1 Run 5-minute playback for each test file (loop shorter files to fill window). No sync mechanism enabled.
- [ ] 0.3.2 Capture initial offset, sustained drift at 5 s, 30 s, 60 s, 120 s, 240 s, 300 s, AND peak drift over the window.
- [ ] 0.3.3 Subjective listening check on each file (headphones, "imperceptible" / "noticeable" / "clearly desynced").
- [ ] 0.3.4 If sustained OR peak drift > 30 ms on ANY file: enable `AVPlayer.masterClock` (Path A); re-run all 5 files.
- [ ] 0.3.5 If still > 30 ms on any file: enable pre-roll buffering (Path B); re-run all 5 files.
- [ ] 0.3.6 If still > 100 ms with both strategies: trigger KILL SWITCH per plan §16. No partial-success / "ship 2 of 3" path at the spike stage.

### 0.4 Spike findings

- [ ] 0.4.1 Append "Phase 0 — Spike Results" section to `tasks/video-audio-engine-routing/research.md`.
- [ ] 0.4.2 Document chosen Path (NONE / A / B / KILL) with the data backing the decision.
- [ ] 0.4.3 If Path A: document exact `AVPlayer.masterClock` API call that worked on macOS 15.0.
- [ ] 0.4.4 If Path B: write a 1-page sub-plan for pre-roll into research.md.
- [ ] 0.4.5 Re-read plan.md §9 with Phase 0 result; update Phase 4 section explicitly with chosen path.
- [ ] 0.4.6 Delete spike branch: `git branch -D spike/vaer-av-drift-measurement`.

**HARD GATE:** if Phase 0.3.6 hits the kill switch, mark task PERMANENTLY DEFERRED in `tasks/_context/state.md` and `tasks/_context/tasks_index.md`. Do not proceed.

---

## Phase 1 — Engine Configuration Change Observer

### 1.1 Implementation

- [ ] 1.1.1 Create branch `feat/video-audio-engine-routing` from main (S3-1 merged).
- [ ] 1.1.2 Create `MacAmpApp/Audio/AudioEngineConfigurationObserver.swift` per plan §6.1.
    - [ ] @MainActor class
    - [ ] init takes `AVAudioEngine`
    - [ ] `start()` / `stop()` idempotent
    - [ ] Debounce window 150 ms with generation counter
    - [ ] `onWillReconfigure` / `onDidReconfigure` callbacks
- [ ] 1.1.3 Add observer to `AudioEngineController.swift` per plan §6.2.
    - [ ] `@ObservationIgnored private let configObserver`
    - [ ] Initialize in `setupEngine()`
    - [ ] Wire `handleEngineWillReconfigure` / `handleEngineDidReconfigure`
- [ ] 1.1.4 Add `PreReconfigureSnapshot` struct + `onEngineWillReconfigure` / `onEngineDidReconfigure` callbacks per plan §6.3.
- [ ] 1.1.5 Wire `onEngineWillReconfigure` callback in `AudioPlayer` init per plan §6.4 step list:
    - [ ] Save `savedSeekID = currentSeekID`, `savedTime = currentTime`
    - [ ] Bump `currentSeekID = UUID()` BEFORE engine restart (filters stale completions)
    - [ ] Set `seekGuardActive = true`, `isHandlingCompletion = true`
- [ ] 1.1.6 Wire `onEngineDidReconfigure` callback in `AudioPlayer` per plan §6.4 step list:
    - [ ] Re-apply volume + balance via `engine.setVolume` / `engine.setBalance`
    - [ ] If local audio path AND `engine.audioFile != nil`: ALWAYS reschedule from `savedTime` with new `currentSeekID` (even if paused — `play()` does NOT reschedule per AudioPlayer.swift:417)
        - [ ] Sub-branch: if `wasPlaying`, call `engine.playAudio()` + `engine.startProgressTimer()`
        - [ ] Sub-branch: if was paused, do NOT call `playAudio()`; restore `playbackState = .paused`
    - [ ] If stream bridge: fire `onEngineReconfigured` callback (workgroup refresh)
    - [ ] If video bridge: no resume needed (AVPlayer manages clock; paused video stays paused)
    - [ ] Clear `seekGuardActive` after 100 ms (matches existing pattern at AudioPlayer.swift:603)
    - [ ] Clear `isHandlingCompletion` after 200 ms (matches existing pattern at AudioPlayer.swift:673)
- [ ] 1.1.7 Wire `onEngineReconfigured` in `PlaybackCoordinator` to refresh stream workgroup via `streamPlayer.setAudioWorkgroup(audioPlayer.audioWorkgroup)`.

### 1.2 Tests

- [ ] 1.2.1 Create `Tests/MacAmpTests/Audio/EngineConfigObserverTests.swift`.
    - [ ] `observerFiresOnSyntheticNotification`
    - [ ] `observerDebouncesBurst` (3 notifications < 50 ms → 1 fire)

### 1.3 Manual verification

- [ ] 1.3.1 Build with `xcodegen generate && xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'`.
- [ ] 1.3.2 Local file playing → switch output via Control Center → audio resumes < 1 s, EQ still active.
- [ ] 1.3.3 Stream playing → switch output → audio resumes < 1 s, ICY metadata still flowing.

### 1.4 Commit

- [ ] 1.4.1 `feat(audio): add AudioEngineConfigurationObserver`

---

## Phase 2 — MTAudioProcessingTap Implementation

### 2.1 VideoAudioTap class

- [ ] 2.1.1 Create `MacAmpApp/Audio/VideoAudioTap.swift` per plan §7.
- [ ] 2.1.2 Define `VideoAudioTapContext` (final class, `@unchecked Sendable`, queue-confined).
    - [ ] Holds `LockFreeRingBuffer` reference
    - [ ] Holds `AudioStreamBasicDescription` + optional `AudioConverterRef`
    - [ ] Atomic `lastCallbackHostTime` (`ManagedAtomic<UInt64>`)
- [ ] 2.1.3 Implement `init(ringBuffer:expectedSampleRate:)`.
- [ ] 2.1.4 Implement `attach(to: AVPlayerItem) throws -> AVMutableAudioMix`.
    - [ ] Build `MTAudioProcessingTapCallbacks`
    - [ ] `MTAudioProcessingTapCreate` with `kMTAudioProcessingTapCreationFlag_PostEffects`
    - [ ] `Unmanaged<Context>.passRetained` for clientInfo
    - [ ] Build `AVMutableAudioMixInputParameters` for first audio track
    - [ ] Return assembled `AVMutableAudioMix`
- [ ] 2.1.5 Implement `detach()` — invalidate tap, release `Unmanaged<Context>`.
- [ ] 2.1.6 Implement `lastCallbackHostTime` accessor.
- [ ] 2.1.7 Implement deinit — call detach if not already.

### 2.2 C-convention callbacks

- [ ] 2.2.1 `tapPrepare`: capture format, lazily build AudioConverter on mismatch.
- [ ] 2.2.2 `tapProcess`: call `MTAudioProcessingTapGetSourceAudio`, optionally convert, write to ring buffer, update `lastCallbackHostTime`. **Must NOT zero the bufferList.**
- [ ] 2.2.3 `tapUnprepare`: tear down converter.
- [ ] 2.2.4 `tapFinalize`: release `Unmanaged<Context>`.

### 2.3 Format-edge handling

- [ ] 2.3.1 Mono source → stereo via AudioConverter.
- [ ] 2.3.2 5.1 source → stereo downmix via AudioConverter.
- [ ] 2.3.3 Non-Float32 source → Float32 conversion via AudioConverter.
- [ ] 2.3.4 Sample-rate mismatch → resample via AudioConverter.
- [ ] 2.3.5 If `AudioConverterNew` fails → mark context for fallback (Phase 5 picks up).

### 2.4 Tests

- [ ] 2.4.1 Create `Tests/MacAmpTests/Audio/VideoAudioTapTests.swift`.
    - [ ] `attachReturnsValidAudioMix` (stub AVPlayerItem with audio track)
    - [ ] `detachReleasesContext` (weak var leak check)
    - [ ] `ringBufferReceivesFramesFromTap` (use `@_spi(Testing) testInjectFrames`)
    - [ ] `formatMismatchTriggersAudioConverter`

### 2.5 Commit

- [ ] 2.5.1 `feat(audio): add VideoAudioTap with MTAudioProcessingTap callbacks`

---

## Phase 3 — Engine Source Node + Wiring

### 3.1 AudioEngineController extensions

- [ ] 3.1.1 Add `videoSourceNode`, `videoRingBuffer`, `isVideoBridgeActive` fields per plan §8.1.
- [ ] 3.1.2 Add `makeVideoRenderBlock` (parallel to `makeStreamRenderBlock`).
- [ ] 3.1.3 Implement `activateVideoBridge(ringBuffer:sampleRate:)`.
    - [ ] Deactivate stream bridge first (if active)
    - [ ] Stop playerNode if running
    - [ ] Stop engine, attach video source node
    - [ ] Connect: videoSourceNode → eqNode → mixer → output
    - [ ] Restart engine; install visualizer tap
    - [ ] Set `isVideoBridgeActive = true`
- [ ] 3.1.4 Implement `deactivateVideoBridge()`.
    - [ ] Idempotent guard
    - [ ] Detach source node, restore default playerNode wiring
    - [ ] Clear `videoRingBuffer`, `videoSourceNode`
    - [ ] Set `isVideoBridgeActive = false`

### 3.2 Mutual exclusion

- [ ] 3.2.1 In `rewireForFile(_:)`: call `deactivateVideoBridge()` (in addition to existing stream bridge deactivation).
- [ ] 3.2.2 In `activateStreamBridge(...)`: call `deactivateVideoBridge()` first.
- [ ] 3.2.3 In `activateVideoBridge(...)`: call `deactivateStreamBridge()` first.

### 3.3 Volume / balance forwarding

- [ ] 3.3.1 Extend `setVolume(_:)` to forward to `videoSourceNode?.volume`.
- [ ] 3.3.2 Extend `setBalance(_:)` to forward to `videoSourceNode?.pan`.

### 3.4 AudioPlayer integration

- [ ] 3.4.1 Add `videoAudioTap: VideoAudioTap?` and `videoRingBuffer: LockFreeRingBuffer?` fields to AudioPlayer.
- [ ] 3.4.2 Add `isVideoBridgeActive` getter that delegates to `engine.isVideoBridgeActive`.
- [ ] 3.4.3 Modify `playTrack` video branch (lines 354–360):
    - [ ] Remove visualizer-tap-removal at lines 347–349
    - [ ] Build ring buffer (capacity 4096, channels 2)
    - [ ] Create VideoAudioTap
    - [ ] Call `videoPlaybackController.loadVideo(url:autoPlay:audioTap:)`
    - [ ] On success: `engine.activateVideoBridge(...)`, set `player.volume = 0`
- [ ] 3.4.4 Modify `stop()` to deactivate video bridge and detach tap.
- [ ] 3.4.5 Update `isEngineRendering`:
    `engine.isEngineRunning && (isPlaying || isBridgeActive || engine.isVideoBridgeActive)`

### 3.5 VideoPlaybackController extensions

- [ ] 3.5.1 Extend `loadVideo(url:autoPlay:)` to `loadVideo(url:autoPlay:audioTap:)`.
- [ ] 3.5.2 After AVPlayerItem is `.readyToPlay`, attach tap and assign `audioMix`.
- [ ] 3.5.3 Track `attachedTap` field for cleanup.
- [ ] 3.5.4 Add new `detachAudioTap()` method that:
    - [ ] Sets `playerItem.audioMix = nil` (ESSENTIAL — prevents AVPlayer calling into a dead tap)
    - [ ] Calls `attachedTap?.detach()` (invalidates the tap, releases `Unmanaged<Context>`)
    - [ ] Clears `attachedTap = nil`
- [ ] 3.5.5 Extend `cleanup()` to call `detachAudioTap()` (single unified teardown path used by both normal stop and Phase 5 fallback).

### 3.6 Tests

- [ ] 3.6.1 Create `Tests/MacAmpTests/Audio/AudioEngineControllerVideoBridgeTests.swift`.
    - [ ] `activateVideoBridgeAddsSourceNode`
    - [ ] `activateVideoBridgeDeactivatesStreamBridge`
    - [ ] `deactivateVideoBridgeIsIdempotent`
    - [ ] `setVolumeForwardsToVideoSourceNode`

### 3.7 Build + commit

- [ ] 3.7.1 `xcodegen generate`
- [ ] 3.7.2 Build with TSan, run tests.
- [ ] 3.7.3 Commit: `feat(audio): wire video source node into engine graph`

---

## Phase 4 — Sync Strategy (TBD per Phase 0)

> **Read Phase 0 results before starting this phase.** This section is conditional.

### Path NONE (drift < 30 ms)

- [ ] 4.NONE Document in research.md that no sync code was needed; phase is a no-op.

### Path A (`AVPlayer.masterClock`)

- [ ] 4.A.1 Expose engine output clock from `AudioEngineController` (per spike-confirmed API).
- [ ] 4.A.2 Set `player.masterClock = engineClock` in `VideoPlaybackController.loadVideo` after creating the AVPlayer.
- [ ] 4.A.3 Re-run drift measurement with the production code (target < 30 ms).
- [ ] 4.A.4 Commit: `feat(audio): video A/V sync via masterClock`

### Path B (Pre-roll buffering)

- [ ] 4.B.1 Read pre-roll sub-plan written to research.md during spike.
- [ ] 4.B.2 In `playTrack` video branch: activate bridge, set `player.rate = 0`, `play()`, wait for first `tapProcess` callback + 50 ms accumulation, set `player.rate = 1.0`.
- [ ] 4.B.3 Re-run drift measurement (target < 30 ms).
- [ ] 4.B.4 Commit: `feat(audio): video A/V sync via pre-roll buffering`

---

## Phase 5 — Tap Failure Fallback

### 5.1 Watchdog

- [ ] 5.1.1 Add `videoTapWatchdogTask: Task<Void, Never>?` to AudioPlayer.
- [ ] 5.1.2 Add `videoTapFallbackActive: Bool = false` flag.
- [ ] 5.1.3 Implement watchdog logic: every 250 ms check `(now - tap.lastCallbackHostTime) > 1000 ms` AND `videoPlaybackController.isPlaying` AND `engine.isVideoBridgeActive`.
- [ ] 5.1.4 Start watchdog when video bridge activates; stop when video stops or fallback engages.

### 5.2 Fallback sequence (must run on @MainActor in this exact order, per plan §10.2)

- [ ] 5.2.1 Idempotency guard: `guard !videoTapFallbackActive else { return }` at top of fallback method.
- [ ] 5.2.2 Cancel watchdog FIRST: `videoTapWatchdogTask?.cancel(); videoTapWatchdogTask = nil`.
- [ ] 5.2.3 Set `videoTapFallbackActive = true` (capability surface re-evaluates).
- [ ] 5.2.4 Log error: `AppLog.error(.audio, "Video audio tap stalled — restoring AVPlayer.volume fallback")`.
- [ ] 5.2.5 `engine.deactivateVideoBridge()` (engine returns to default playerNode wiring).
- [ ] 5.2.6 `videoPlaybackController.detachAudioTap()` — new method that:
    - [ ] Sets `playerItem.audioMix = nil` (ESSENTIAL — failed tap must not stay attached)
    - [ ] Calls `videoAudioTap.detach()` (invalidates tap, releases `Unmanaged<Context>`)
- [ ] 5.2.7 Clear `videoAudioTap = nil` and `videoRingBuffer = nil` on AudioPlayer side.
- [ ] 5.2.8 Restore AVPlayer volume: `videoPlaybackController.player?.volume = audioPlayer.volume`.
- [ ] 5.2.9 Reset transient guards: `seekGuardActive = false` (do NOT bump `currentSeekID` — no scheduled segment to invalidate).
- [ ] 5.2.10 In `playTrack`, reset `videoTapFallbackActive = false` BEFORE per-track setup runs (fresh slate per track).

### 5.3 Volume-during-fallback

- [ ] 5.3.1 In `volume.didSet`: forward to `videoPlaybackController.volume` only when `videoTapFallbackActive`.

### 5.4 Tests

- [ ] 5.4.1 Create `Tests/MacAmpTests/Audio/VideoTapFallbackTests.swift`.
    - [ ] `watchdogDetectsStaleCallback`
    - [ ] `fallbackRestoresAVPlayerVolume`

### 5.5 Commit

- [ ] 5.5.1 `feat(audio): add tap-failure watchdog and fallback`

---

## Phase 6 — Capability Flag Surface

### 6.1 PlaybackCoordinator

- [ ] 6.1.1 Update `supportsAudioProcessing` per plan §11.2 (three-branch implementation).

### 6.2 AudioPlayer

- [ ] 6.2.1 Update `snapshotButterchurnFrame()` per plan §11.3 (replace media-type guard with bridge-aware guard).
- [ ] 6.2.2 Already done in Phase 3.4.5: extend `isEngineRendering` to include video bridge.
- [ ] 6.2.3 Update `volume.didSet` per plan §11.6 (gate AVPlayer forwarding on fallback flag).

### 6.3 PlaybackCoordinator volume forwarding

- [ ] 6.3.1 In `setVolume(_:)`: skip explicit `videoPlaybackController.volume = vol` (now handled by `engine.setVolume` via `videoSourceNode`).

### 6.4 Tests

- [ ] 6.4.1 Create `Tests/MacAmpTests/Audio/AudioPlayerVideoCapabilityTests.swift`.
    - [ ] `supportsAudioProcessingWithActiveVideoBridge`
    - [ ] `supportsAudioProcessingWithVideoTapFallback`
    - [ ] `snapshotButterchurnFrameWorksForVideo`

### 6.5 Commit

- [ ] 6.5.1 `feat(audio): enable EQ + visualizer + balance for video sessions`

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
