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
- [ ] **1.1** Add `volume: Float` property to StreamPlayer with didSet syncing to `player.volume` — both AVPlayer.volume and AVAudioPlayerNode.volume use 0.0-1.0 linear amplitude, no conversion needed
- [ ] **1.2** Add `balance: Float` property to StreamPlayer (stored, not applied — AVPlayer has no .pan property). Enables uniform propagation from PlaybackCoordinator without backend type checks
- [ ] **1.9** Apply persisted volume in StreamPlayer.play() before playback starts (`player.volume = volume` before `player.play()`). **Startup sync:** PlaybackCoordinator must propagate initial volume from UserDefaults to StreamPlayer during init or lazily before first stream play — otherwise first stream uses default 0.75 instead of saved volume

### PlaybackCoordinator Routing
- [ ] **1.3-pre** (Oracle ordering) Add backend readiness model before wiring setVolume/setBalance — ensure AVPlayer.volume setter is safe on unconfigured players (verified idempotent, no-op on unconfigured)
- [ ] **1.3a** Add `setVolume(_ volume: Float)` method to PlaybackCoordinator — propagates unconditionally to audioPlayer + streamPlayer + videoPlaybackController. Design: update ALL backends always (simpler, no race conditions, zero cost on idle players)
- [ ] **1.3b** Add `setBalance(_ balance: Float)` method to PlaybackCoordinator — propagates to audioPlayer + streamPlayer
- [ ] **1.3c** (Oracle) Add "apply current settings on backend activation" — when backend switches, coordinator re-applies volume/balance/EQ to newly active backend. Must happen before Step 1.6 to ensure no control gaps during transitions
- [ ] **1.4a** Add `isStreamBackendActive` private computed property to PlaybackCoordinator — uses `currentSource` enum (not `currentTrack?.isStream`) because `currentTrack` can be nil when playing a station directly via `play(station:)`. A paused stream should still report as stream-backend-active for capability flag purposes
- [ ] **1.4b** Add `supportsEQ` computed property (returns `!isStreamBackendActive`)
- [ ] **1.4c** Add `supportsBalance` computed property (returns `!isStreamBackendActive`)
- [ ] **1.4d** Add `supportsVisualizer` computed property (returns `!isStreamBackendActive`)

### AudioPlayer Cleanup
- [ ] **1.6** Remove `videoPlaybackController.volume = volume` from AudioPlayer.volume didSet — coordinator handles all cross-backend propagation now. **Only safe after 1.3a is proven to cover video volume propagation on ALL paths (UI, restore, programmatic)**

### UI Wiring
- [ ] **1.5** Update WinampMainWindow volume slider binding to route through PlaybackCoordinator.setVolume() — prefer existing `@Bindable` pattern, add volume property to PlaybackCoordinator with didSet calling setVolume
- [ ] **1.8a** Reroute balance slider binding in WinampMainWindow through PlaybackCoordinator.setBalance() — currently binds directly to `audioPlayer.balance`, bypassing the coordinator
- [ ] **1.8b** Dim/grey out balance slider in WinampMainWindow when `supportsBalance == false` — slider position preserved but doesn't affect stream audio
- [ ] **1.7** Dim/grey out EQ sliders in WinampEqualizerWindow when `supportsEQ == false` — sliders still show current preset but don't affect stream audio. Preset selection still works (applied when switching back to local file)

### Phase 1 Verification
- [ ] **V1.1** Stream playback: volume slider controls stream volume
- [ ] **V1.2** Volume adjustment during stream: immediate audible effect
- [ ] **V1.3** Switch stream -> local file: volume stays consistent
- [ ] **V1.4** Switch local file -> stream: volume stays consistent
- [ ] **V1.5** EQ sliders visually dimmed during stream playback
- [ ] **V1.6** Balance slider visually dimmed during stream playback
- [ ] **V1.7** Local file playback: all controls work exactly as before (regression test)
- [ ] **V1.8** Persist volume -> restart app -> play stream: volume restored
- [ ] **V1.9** (Oracle) Video playback: volume still works after Step 1.6 refactor
- [ ] **V1.10** (Oracle) Switch stream -> local file: balance re-applied correctly (tests 1.3c)
- [ ] **V1.11** (Oracle) Rapid slider changes while stream backend is erroring: no crash

---

## Phase 2: Loopback Bridge (Blocked by `lock-free-ring-buffer` task)

### Prerequisites
- [ ] **2.0a** `lock-free-ring-buffer` task completed and tested
- [ ] **2.0b** Phase 1 completed (capability flags infrastructure in place)
- [ ] **2.0c** (Oracle) Define bridge lifecycle state machine (starting, active, failed, teardown) — must be defined BEFORE graph switching implementation
- [ ] **2.0d** (Oracle) ABR handling designed as part of initial bridge implementation, not a late add-on

### Ring Buffer Integration
- [ ] **2.1** Import LockFreeRingBuffer.swift from ring buffer task into MacAmpApp/Audio/

### MTAudioProcessingTap Implementation
- [ ] **2.2a** Create tap callback functions (tapInit, tapFinalize, tapPrepare, tapUnprepare, tapProcess)
- [ ] **2.2b** In tapProcess: copy PCM to ring buffer via `ringBuffer.write(samples)`, then zero `bufferListInOut` to prevent double-render (silence AVPlayer direct output). Per Apple QA1783, PreEffects tap runs before mix effects — zeroing is deterministic
- [ ] **2.2c** In tapPrepare: capture audio format, configure ring buffer for format, increment atomic generation ID (for ABR detection)
- [ ] **2.2d** In tapUnprepare: flush ring buffer, signal reader
- [ ] **2.2e** Add `attachTap(to:)` method on StreamPlayer using `kMTAudioProcessingTapCreationFlag_PreEffects`
- [ ] **2.2f** Add `detachTap()` method for clean teardown
- [ ] **2.2g** Handle Swift 6 Sendability: `@unchecked Sendable` wrapper + `nonisolated(unsafe)` for shared state between tap and source node
- [ ] **2.2h** (Oracle) Enforce real-time safety in ALL callbacks: zero allocations (no malloc/free), zero locks (no mutexes), zero ARC ops (no retain/release), zero logging (no print/NSLog), zero ObjC messaging, zero Task/async

### AVAudioEngine Integration
- [ ] **2.3** Create `AVAudioSourceNode` in AudioPlayer that reads from ring buffer — fill silence on underrun to prevent glitches
- [ ] **2.4a** Add engine graph source switching WITHOUT engine restart — use `disconnectNodeOutput`/`connect` while engine is running (Oracle correction #5: avoids audible gap)
- [ ] **2.4b** Preserve existing graph: playerNode -> eqNode -> mainMixerNode for local files
- [ ] **2.4c** Wire PlaybackCoordinator to trigger graph switching on backend change. LOCAL->STREAM: disconnect playerNode, connect streamSourceNode -> eqNode, start tap + bridge. STREAM->LOCAL: disconnect streamSourceNode, connect playerNode -> eqNode, stop tap + bridge, call `VisualizerPipeline.clearData()` to prevent stale visualizer data

### Capability Flag Updates
- [ ] **2.5** Update `supportsEQ`/`supportsBalance`/`supportsVisualizer` to return `true` always when bridge is available. (Oracle correction #7: tie flags to actual bridge state transitions — starting/active/failed/teardown — not just `isStreamBackendActive`)

### Visualization Fix
- [ ] **2.6** Update VisualizerView playback state check (line ~74) to include stream playback state from PlaybackCoordinator — with bridge active, stream audio flows through engine so existing visualization tap receives data

### ABR Format Change Handling (part of initial bridge implementation per Oracle ordering)
- [ ] **2.7a** In tapPrepare: reinitialize ring buffer on format change with generation ID increment
- [ ] **2.7b** Pre-allocate for worst-case format (48kHz stereo float32)
- [ ] **2.7c** In source node render: check atomic generation ID, fill silence on epoch mismatch (handles race during tap detach/reattach — Oracle correction #4)
- [ ] **2.7d** Handle brief silence during ABR transition gracefully — acceptable for radio

### Telemetry (Oracle recommendation)
- [ ] **2.8a** Add atomic underrun/overrun counters to ring buffer (AtomicUInt64, incremented in render callbacks)
- [ ] **2.8b** Expose counters on main thread for diagnostics/logging (read periodically, not in real-time path)

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
