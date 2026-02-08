# TODO: Internet Streaming Volume Control

> **Purpose:** Broken-down task checklist derived from the plan. Each item is a discrete, verifiable unit of work.

---

## Status: ORACLE REVIEWED — CORRECTIONS APPLIED

## Phase 1: Stream Volume Control + Capability Flags

### StreamPlayer Volume/Balance
- [ ] **1.1** Add `volume: Float` property to StreamPlayer with didSet syncing to `player.volume`
- [ ] **1.2** Add `balance: Float` property to StreamPlayer (stored, not applied — no AVPlayer .pan)
- [ ] **1.9** Apply persisted volume in StreamPlayer.play() before playback starts

### PlaybackCoordinator Routing
- [ ] **1.3a** Add `setVolume(_ volume: Float)` method to PlaybackCoordinator — propagates to audioPlayer + streamPlayer + videoPlaybackController (Oracle: must include video)
- [ ] **1.3b** Add `setBalance(_ balance: Float)` method to PlaybackCoordinator — propagates to audioPlayer + streamPlayer
- [ ] **1.3c** (Oracle) Add "apply current settings on backend activation" — when backend switches, coordinator re-applies volume/balance to newly active backend
- [ ] **1.4a** Add `isStreamPlaying` computed property to PlaybackCoordinator
- [ ] **1.4b** Add `supportsEQ` computed property (returns `!isStreamPlaying`)
- [ ] **1.4c** Add `supportsBalance` computed property (returns `!isStreamPlaying`)
- [ ] **1.4d** Add `supportsVisualizer` computed property (returns `!isStreamPlaying`)

### AudioPlayer Cleanup
- [ ] **1.6** Remove `videoPlaybackController.volume = volume` from AudioPlayer.volume didSet — coordinator handles propagation now (Oracle: only after 1.3a is proven to cover video)

### UI Wiring
- [ ] **1.5** Update WinampMainWindow volume slider binding to route through PlaybackCoordinator
- [ ] **1.7** Dim/grey out EQ sliders in WinampEqualizerWindow when `supportsEQ == false`
- [ ] **1.8** Dim/grey out balance slider in WinampMainWindow when `supportsBalance == false`

### Phase 1 Verification
- [ ] **V1.1** Stream playback: volume slider controls stream volume
- [ ] **V1.2** Volume adjustment during stream: immediate audible effect
- [ ] **V1.3** Switch stream → local file: volume stays consistent
- [ ] **V1.4** Switch local file → stream: volume stays consistent
- [ ] **V1.5** EQ sliders visually dimmed during stream playback
- [ ] **V1.6** Balance slider visually dimmed during stream playback
- [ ] **V1.7** Local file playback: all controls work exactly as before (regression test)
- [ ] **V1.8** Persist volume → restart app → play stream: volume restored
- [ ] **V1.9** (Oracle) Video playback: volume still works after Step 1.6 refactor
- [ ] **V1.10** (Oracle) Switch stream → local file: balance re-applied correctly
- [ ] **V1.11** (Oracle) Rapid slider changes while stream backend is erroring: no crash

---

## Phase 2: Loopback Bridge (Blocked by `lock-free-ring-buffer` task)

### Prerequisites
- [ ] **2.0a** `lock-free-ring-buffer` task completed and tested
- [ ] **2.0b** Phase 1 completed (capability flags infrastructure in place)
- [ ] **2.0c** (Oracle) Define bridge lifecycle state machine (starting, active, failed, teardown)

### Ring Buffer Integration
- [ ] **2.1** Import LockFreeRingBuffer.swift from ring buffer task into MacAmpApp/Audio/

### MTAudioProcessingTap Implementation
- [ ] **2.2a** Create tap callback functions (tapInit, tapFinalize, tapPrepare, tapUnprepare, tapProcess)
- [ ] **2.2b** In tapProcess: copy PCM to ring buffer, then zero bufferListInOut (prevent double-render)
- [ ] **2.2c** In tapPrepare: capture audio format, configure ring buffer for format, increment generation ID
- [ ] **2.2d** In tapUnprepare: flush ring buffer
- [ ] **2.2e** Add attachTap(to:) method on StreamPlayer using kMTAudioProcessingTapCreationFlag_PreEffects
- [ ] **2.2f** Add detachTap() method for clean teardown
- [ ] **2.2g** Handle Swift 6 Sendability: @unchecked Sendable wrapper + nonisolated(unsafe) for shared state
- [ ] **2.2h** (Oracle) Enforce real-time safety: zero allocations, zero locks, zero ARC, zero logging in all callbacks

### AVAudioEngine Integration
- [ ] **2.3** Create AVAudioSourceNode in AudioPlayer that reads from ring buffer
- [ ] **2.4a** Add engine graph source switching WITHOUT engine restart (use disconnectNodeOutput/connect while running)
- [ ] **2.4b** Preserve existing graph: playerNode → eqNode → mainMixerNode for local files
- [ ] **2.4c** Wire PlaybackCoordinator to trigger graph switching on backend change

### Capability Flag Updates
- [ ] **2.5** Update supportsEQ/supportsBalance/supportsVisualizer — tie to actual bridge state (not just isStreamPlaying)

### Visualization Fix
- [ ] **2.6** Update VisualizerView playback state check (line ~74) to include stream playback via coordinator

### ABR Format Change Handling (part of initial bridge implementation, not late add-on)
- [ ] **2.7a** In tapPrepare: reinitialize ring buffer on format change with generation ID increment
- [ ] **2.7b** Pre-allocate for worst-case format (48kHz stereo float32)
- [ ] **2.7c** In source node render: check generation epoch, fill silence on mismatch
- [ ] **2.7d** Handle brief silence during ABR transition gracefully

### Telemetry (Oracle recommendation)
- [ ] **2.8a** Add atomic underrun/overrun counters to ring buffer
- [ ] **2.8b** Expose counters on main thread for diagnostics/logging

### Phase 2 Verification
- [ ] **V2.1** Stream playback: EQ sliders affect audio
- [ ] **V2.2** Stream playback: visualizer shows spectrum analysis
- [ ] **V2.3** Stream playback: balance slider pans audio
- [ ] **V2.4** Switch stream ↔ local file: seamless transition (no audible gap)
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
