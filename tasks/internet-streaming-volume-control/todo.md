# TODO: Internet Streaming Volume Control

> **Purpose:** Broken-down task checklist derived from the plan. Each item is a discrete, verifiable unit of work.

---

## Status: ORACLE REVIEWED — CORRECTIONS APPLIED — PREREQUISITES DOCUMENTED

---

## Prerequisites (Must Complete Before Phase 1)

These issues were discovered during Oracle validation of the internet-radio-review task. They affect the streaming infrastructure that Phase 1 builds upon. Fixing them first prevents compounding bugs.

| ID | Issue | Severity | Blocks? | Task Reference |
|----|-------|----------|---------|----------------|
| N1 | Playlist navigation broken during stream playback — next/prev always jumps to first track because `audioPlayer.currentTrack` is nil during streams | HIGH | YES | `tasks/internet-radio-review/findings.md` |
| N2 | PlayPause indicator desync — coordinator flags diverge from StreamPlayer's actual state during buffering stalls or network errors | MEDIUM | Recommended | `tasks/internet-radio-review/findings.md` |
| N5 | Main window indicator bound to AudioPlayer, not PlaybackCoordinator — wrong play/pause display during streams | MEDIUM | Recommended | `tasks/internet-radio-review/findings.md` |
| N3 | externalPlaybackHandler naming clarity — fires on metadata refresh, misleading name | LOW | NO | `tasks/internet-radio-review/findings.md` |
| N4 | StreamPlayer metadata overwrite — initial title/artist cleared by play(station:) before ICY arrives | LOW | NO | `tasks/internet-radio-review/findings.md` |
| N6 | Track Info dialog uses `currentTitle` instead of `displayTitle` — missing live ICY metadata | LOW | NO | `tasks/internet-radio-review/findings.md` |

**Blocking rule:** N1 (HIGH) must be fixed before Phase 1 implementation begins. N2 and N5 (MEDIUM) should be fixed in the same pass. N3, N4, N6 (LOW) can be bundled or deferred.

---

## Phase 1: Stream Volume Control + Capability Flags

### StreamPlayer Volume/Balance
- [x] **1.1** Add `volume: Float` property to StreamPlayer with didSet syncing to `player.volume` — both AVPlayer.volume and AVAudioPlayerNode.volume use 0.0-1.0 linear amplitude, no conversion needed
- [x] **1.2** Add `balance: Float` property to StreamPlayer (stored, not applied — AVPlayer has no .pan property). Enables uniform propagation from PlaybackCoordinator without backend type checks
- [x] **1.9** Apply persisted volume in StreamPlayer.play() before playback starts (`player.volume = volume` before `player.play()`). **Startup sync:** PlaybackCoordinator must propagate initial volume from UserDefaults to StreamPlayer during init or lazily before first stream play — otherwise first stream uses default 0.75 instead of saved volume

### PlaybackCoordinator Routing
- [x] **1.3-pre** (Oracle ordering) Add backend readiness model before wiring setVolume/setBalance — ensure AVPlayer.volume setter is safe on unconfigured players (verified idempotent, no-op on unconfigured)
- [x] **1.3a** Add `setVolume(_ volume: Float)` method to PlaybackCoordinator — propagates unconditionally to audioPlayer + streamPlayer + videoPlaybackController. Design: update ALL backends always (simpler, no race conditions, zero cost on idle players)
- [x] **1.3b** Add `setBalance(_ balance: Float)` method to PlaybackCoordinator — propagates to audioPlayer + streamPlayer
- [x] **1.3c** (Oracle) Add "apply current settings on backend activation" — satisfied by unconditional setVolume/setBalance design + init sync in PlaybackCoordinator.init()
- [x] **1.4a** Add `isStreamBackendActive` private computed property to PlaybackCoordinator — uses `currentSource` enum (not `currentTrack?.isStream`) because `currentTrack` can be nil when playing a station directly via `play(station:)`. A paused stream should still report as stream-backend-active for capability flag purposes
- [x] **1.4b** Add `supportsEQ` computed property (returns `!isStreamBackendActive`)
- [x] **1.4c** Add `supportsBalance` computed property (returns `!isStreamBackendActive`)
- [x] **1.4d** Add `supportsVisualizer` computed property (returns `!isStreamBackendActive`) — unused by UI (Phase 2 prep), documented

### AudioPlayer Cleanup
- [x] **1.6** Remove `videoPlaybackController.volume = volume` from AudioPlayer.volume didSet — coordinator handles all cross-backend propagation now. Added prominent warning comment at property declaration.

### UI Wiring
- [x] **1.5** Update WinampMainWindow volume slider binding to route through PlaybackCoordinator.setVolume() — using Binding<Float>(get:set:) pattern with asymmetric read from audioPlayer / write through coordinator
- [x] **1.8a** Reroute balance slider binding in WinampMainWindow through PlaybackCoordinator.setBalance() — same asymmetric Binding pattern
- [x] **1.8b** Dim/grey out balance slider in WinampMainWindow when `supportsBalance == false` — opacity 0.5 + allowsHitTesting(false) + tooltip
- [x] **1.7** Dim/grey out EQ sliders in WinampEqualizerWindow when `supportsEQ == false` — entire EQ controls group dimmed via opacity 0.5 + allowsHitTesting(false). Titlebar buttons excluded from dimming.

### Phase 1 Verification (All passed — manual testing by user 2026-02-22)
- [x] **V1.1** Stream playback: volume slider controls stream volume
- [x] **V1.2** Volume adjustment during stream: immediate audible effect
- [x] **V1.3** Switch stream -> local file: volume stays consistent
- [x] **V1.4** Switch local file -> stream: volume stays consistent
- [x] **V1.5** EQ sliders visually dimmed during stream playback
- [x] **V1.6** Balance slider visually dimmed during stream playback
- [x] **V1.7** Local file playback: all controls work exactly as before (regression test)
- [x] **V1.8** Persist volume -> restart app -> play stream: volume restored
- [x] **V1.9** (Oracle) Video playback: volume still works after Step 1.6 refactor
- [x] **V1.10** (Oracle) Switch stream -> local file: balance re-applied correctly (tests 1.3c)
- [x] **V1.11** (Oracle) Rapid slider changes while stream backend is erroring: no crash

---

## Phase 2: Loopback Bridge — IMPLEMENTATION COMPLETE

### Prerequisites
- [x] **2.0a** `lock-free-ring-buffer` task completed and tested (Wave 1)
- [x] **2.0b** Phase 1 completed (capability flags infrastructure in place, PR #53)
- [x] **2.0c** (Oracle) Bridge lifecycle defined — teardown/setup/attach sequence with identity gating
- [x] **2.0d** (Oracle) ABR handling integrated into initial bridge implementation (generation IDs in tapPrepare + render block)

### Ring Buffer Integration
- [x] **2.1** LockFreeRingBuffer already in MacAmpApp/Audio/ from Wave 1

### MTAudioProcessingTap Implementation (Block 1 — commit 4194086)
- [x] **2.2a** Top-level @convention(c) callbacks: loopbackTapInit, loopbackTapFinalize, loopbackTapPrepare, loopbackTapUnprepare, loopbackTapProcess
- [x] **2.2b** tapProcess: copy PCM to ring buffer, zero bufferListInOut to prevent double-render
- [x] **2.2c** tapPrepare: capture audio format, flush ring buffer with generation ID increment
- [x] **2.2d** tapUnprepare: flush ring buffer with generation ID increment
- [x] **2.2e** `attachLoopbackTap(ringBuffer:onFormatReady:)` on StreamPlayer with PreEffects flag
- [x] **2.2f** `detachLoopbackTap()` for clean teardown (nil audioMix + release tap ref)
- [x] **2.2g** LoopbackTapContext: `@unchecked Sendable` + `nonisolated(unsafe)` for shared state
- [x] **2.2h** Real-time safety enforced in ALL callbacks: zero allocations, zero locks, zero ARC, zero logging

### AVAudioEngine Integration (Block 2 — commit d47da07)
- [x] **2.3** AVAudioSourceNode in AudioPlayer reads from ring buffer, fills silence on underrun
- [x] **2.4a** Engine graph switching via stop/reset/rewire pattern (lesson: hot-swap crashes with -10868)
- [x] **2.4b** Existing playerNode → eqNode → mainMixerNode preserved for local files
- [x] **2.4c** PlaybackCoordinator triggers graph switching via activateStreamBridge/deactivateStreamBridge

### Capability Flag Updates (Block 3 — commit 0ba7b1a)
- [x] **2.5** supportsEQ/Balance/Visualizer: `!isStreamBackendActive || audioPlayer.isBridgeActive`

### Visualization Fix (Block 4 — commit 0ba7b1a)
- [x] **2.6** VisualizerView updated: 4 sites changed from `audioPlayer.isPlaying` → `audioPlayer.isEngineRendering`

### ABR Format Change Handling (integrated into Block 1+2)
- [x] **2.7a** tapPrepare: reinitialize ring buffer on format change with generation ID increment
- [x] **2.7b** Pre-allocate scratch buffer for worst-case (stereo interleaved output)
- [x] **2.7c** Source node render: checks generation ID, fills silence on mismatch
- [x] **2.7d** Brief silence during ABR transition — acceptable for radio

### Telemetry (already in LockFreeRingBuffer from Wave 1)
- [x] **2.8a** Atomic underrun/overrun counters in LockFreeRingBuffer
- [x] **2.8b** `telemetry()` method for main-thread diagnostics

### Oracle Review (commit a5f96b3)
- [x] **P2-1** Gate onFormatReady with ring buffer identity check (race prevention)
- [x] **P2-2** Revalidate currentItem after async loadTracks (stale item prevention)
- [x] **P3-1** Limit interleaved fast path to channels == 2 (>2 channel correctness)
- [x] **P3-2** Explicit isSilence reset on successful read (determinism)

### Phase 2 Verification
- [ ] **V2.1** Stream playback: EQ sliders affect audio
- [ ] **V2.2** Stream playback: visualizer shows spectrum analysis
- [ ] **V2.3** Stream playback: balance slider pans audio
- [ ] **V2.4** Switch stream <-> local file: seamless transition (no audible gap, engine stays running)
- [ ] **V2.5** HLS stream with ABR: no crashes on bitrate switches
- [ ] **V2.6** Extended playback (30+ min): no audio drift or memory growth
- [ ] **V2.7** Local file playback: identical to pre-bridge behavior (regression test)
- [ ] **V2.8** Kill stream mid-playback: clean teardown, no orphan taps
- [ ] **V2.9** (Oracle) ABR with sample-rate/channel-count changes while visualizer active
- [ ] **V2.10** (Oracle) Stream drop/reconnect: bridge recovery + capability flags correct
- [ ] **V2.11** (Oracle) Ring buffer soak test: long playback + CPU pressure — no underrun
- [ ] **V2.12** (Oracle) No double-audio during any transition
- [ ] **V2.13** (Oracle) Thread-safety: tap/source teardown during stop/pause/track switch
- [ ] **V2.14** (Oracle) CPU/memory regression: bridge-enabled streaming vs baseline
