# Plan: Internet Streaming Volume Control

> **Purpose:** Implementation plan derived from research findings. Contains step-by-step approach, architecture decisions, and scope definition for enabling volume/EQ on internet radio streams.

---

## Status: ORACLE REVIEWED — CORRECTIONS APPLIED

## Overview

Enable volume control, EQ, visualization, and balance for internet radio streams in MacAmp. Currently these only work for local file playback via AVAudioEngine. Streams played via AVPlayer have no working audio controls.

**Two-phase approach:**
- **Phase 1:** Wire volume to streams + disable unsupported UI controls (low risk, immediate value)
- **Phase 2:** Loopback Bridge architecture to route stream audio through AVAudioEngine for full EQ, visualization, and balance (high complexity, separate prerequisite task for ring buffer)

---

## Phase 1: Stream Volume Control + Capability Flags

**Goal:** Make volume slider work for internet radio streams. Disable EQ and balance UI during stream playback with clear visual indication.

**Scope:** ~5 files modified, 0 new files, ~100 lines changed

**No impact on local file playback** — all changes are additive, gated by stream detection.

### Step 1.1: Add volume property to StreamPlayer

**File:** `MacAmpApp/Audio/StreamPlayer.swift`

Add a `volume` property that syncs to the internal AVPlayer:

```swift
var volume: Float = 0.75 {
    didSet {
        player.volume = volume
    }
}
```

Both AVPlayer.volume and AVAudioPlayerNode.volume use 0.0-1.0 linear amplitude — no conversion needed.

### Step 1.2: Add balance property (stored, not applied) to StreamPlayer

**File:** `MacAmpApp/Audio/StreamPlayer.swift`

Add a balance property that is accepted but has no effect (AVPlayer has no .pan):

```swift
var balance: Float = 0.0  // Stored but not applied — AVPlayer has no .pan property
```

This ensures PlaybackCoordinator can propagate balance uniformly without checking backend type on every call.

### Step 1.3: Route volume/balance through PlaybackCoordinator

**File:** `MacAmpApp/Audio/PlaybackCoordinator.swift`

Add volume/balance propagation methods that route to the active backend:

```swift
func setVolume(_ volume: Float) {
    audioPlayer.volume = volume
    streamPlayer.volume = volume
    // Both backends always in sync — coordinator doesn't need to track which is active
}

func setBalance(_ balance: Float) {
    audioPlayer.balance = balance
    streamPlayer.balance = balance
}
```

**Design decision:** Update BOTH backends unconditionally rather than checking which is active. This is simpler, avoids race conditions during backend switching, and has zero cost (setting volume on an idle player is a no-op).

### Step 1.4: Add capability flags to PlaybackCoordinator

**File:** `MacAmpApp/Audio/PlaybackCoordinator.swift`

Add computed properties that UI components can observe to gate feature availability:

```swift
var supportsEQ: Bool {
    !isStreamPlaying
}

var supportsBalance: Bool {
    !isStreamPlaying
}

var supportsVisualizer: Bool {
    !isStreamPlaying
}

private var isStreamPlaying: Bool {
    currentTrack?.isStream == true && streamPlayer.isPlaying
}
```

### Step 1.5: Wire UI volume slider through PlaybackCoordinator

**File:** `MacAmpApp/Views/WinampMainWindow.swift` (line ~535)

Update volume slider binding to route through coordinator instead of directly to audioPlayer. The volume slider should trigger `PlaybackCoordinator.setVolume()` which propagates to both backends. Prefer the existing `@Bindable` pattern — add a volume property to PlaybackCoordinator that calls `setVolume` in its didSet.

### Step 1.6: Update AudioPlayer.volume didSet

**File:** `MacAmpApp/Audio/AudioPlayer.swift` (lines 79-85)

Remove the direct `videoPlaybackController.volume = volume` from AudioPlayer.volume didSet. Volume propagation to all backends should flow through PlaybackCoordinator, not through AudioPlayer knowing about other players.

**Current:**
```swift
var volume: Float = 0.75 {
    didSet {
        playerNode.volume = volume
        videoPlaybackController.volume = volume
        UserDefaults.standard.set(volume, forKey: Keys.volume)
    }
}
```

**New:**
```swift
var volume: Float = 0.75 {
    didSet {
        playerNode.volume = volume
        UserDefaults.standard.set(volume, forKey: Keys.volume)
    }
}
```

PlaybackCoordinator.setVolume() handles propagation to videoPlaybackController and streamPlayer.

### Step 1.7: Disable EQ UI during stream playback

**File:** `MacAmpApp/Views/WinampEqualizerWindow.swift`

Read `playbackCoordinator.supportsEQ` and visually indicate when EQ is unavailable:
- Dim/grey out EQ slider controls
- EQ sliders still show current preset but don't affect stream audio
- Preset selection still works (will apply when switching back to local file)

### Step 1.8: Disable balance slider during stream playback

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

Read `playbackCoordinator.supportsBalance` and visually indicate when balance is unavailable:
- Dim/grey out balance slider
- Slider position preserved but doesn't affect stream audio

### Step 1.9: Apply persisted volume on stream start

**File:** `MacAmpApp/Audio/StreamPlayer.swift`

When StreamPlayer starts playback, apply the current volume:

```swift
func play(url: URL) {
    player.volume = volume  // Apply current volume before playback
    // ... existing playback code
}
```

### Phase 1 Verification

1. Start an internet radio stream — volume slider should control stream volume
2. Adjust volume during stream playback — immediate effect
3. Switch from stream to local file — volume stays consistent
4. Switch from local file to stream — volume stays consistent
5. EQ sliders visually dimmed during stream playback
6. Balance slider visually dimmed during stream playback
7. Local file playback — all controls work exactly as before (no regression)
8. Persist volume, restart app, play stream — volume should be restored

---

## Phase 2: Loopback Bridge (EQ + Visualization + Balance for Streams)

**Goal:** Route stream audio through AVAudioEngine to enable full EQ, visualization, and balance.

**Architecture:**
```
AVPlayer → MTAudioProcessingTap (PreEffects) → Lock-Free Ring Buffer → AVAudioSourceNode → AVAudioEngine
                    |                                                                            |
              (zero output buffer                                                    AVAudioUnitEQ (existing)
               to prevent double-render)                                                         |
                                                                                   MainMixerNode [installTap] → Output
```

**Prerequisite:** `lock-free-ring-buffer` task must be completed first.

**No impact on local file playback** — the Loopback Bridge only activates when playing streams. Local files continue using the existing AVAudioPlayerNode path.

### Step 2.1: Integrate lock-free ring buffer (from separate task)

**File:** New file `MacAmpApp/Audio/LockFreeRingBuffer.swift` (from ring buffer task)

Import the tested ring buffer implementation. Must support:
- Lock-free concurrent single-writer / single-reader
- Write from MTAudioProcessingTap thread
- Read from AVAudioEngine render thread
- 4096 frame capacity (~85ms at 48kHz)
- Underrun handling (fill silence)
- Overrun handling (drop oldest)
- Format-aware (stereo float32)

### Step 2.2: Implement MTAudioProcessingTap on StreamPlayer

**File:** `MacAmpApp/Audio/StreamPlayer.swift`

Add tap attachment to AVPlayerItem when stream playback starts:

- Use `kMTAudioProcessingTapCreationFlag_PreEffects` to get audio before effects
- In `tapProcess`: copy PCM to ring buffer, then zero `bufferListInOut` to silence direct output
- In `tapPrepare`: capture audio format, reinitialize ring buffer if format changes (ABR)
- In `tapUnprepare`: flush ring buffer
- Mark tap context as `nonisolated(unsafe)` for Swift 6 strict mode
- Use `@unchecked Sendable` wrapper for tap types

### Step 2.3: Create AVAudioSourceNode for stream injection

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

Add a source node that reads from the ring buffer and feeds into the engine graph:

```swift
private lazy var streamSourceNode = AVAudioSourceNode { [ringBuffer] _, _, frameCount, audioBufferList in
    let framesRead = ringBuffer.read(into: audioBufferList, count: frameCount)
    if framesRead < frameCount {
        // Fill remaining with silence to prevent glitches
    }
    return noErr
}
```

### Step 2.4: Wire stream source node into engine graph

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

When stream playback is active, connect:
```
streamSourceNode → eqNode → mainMixerNode → outputNode
```

When local file playback is active, connect (existing):
```
playerNode → eqNode → mainMixerNode → outputNode
```

The engine graph must be reconfigured when switching between stream and local backends. This should happen in PlaybackCoordinator's backend switching logic.

### Step 2.5: Update capability flags

**File:** `MacAmpApp/Audio/PlaybackCoordinator.swift`

With Loopback Bridge active, all capabilities become available during stream playback:

```swift
var supportsEQ: Bool { true }         // Always true with bridge
var supportsBalance: Bool { true }     // Always true with bridge
var supportsVisualizer: Bool { true }  // Always true with bridge
```

### Step 2.6: Update VisualizerView playback state check

**File:** `MacAmpApp/Views/VisualizerView.swift` (line ~74)

Current code gates visualization on `audioPlayer.isPlaying`. With the Loopback Bridge, stream audio flows through the engine, so the existing visualization tap will receive data. Update the playback state check to include stream playback state from PlaybackCoordinator.

### Step 2.7: Handle ABR format changes

**File:** `MacAmpApp/Audio/StreamPlayer.swift`

HLS adaptive bitrate switches trigger `tapUnprepare` → `tapPrepare` cycles. Handle by:
1. In `tapPrepare`: capture new format, reinitialize ring buffer for new format
2. Pre-allocate for worst-case (48kHz stereo float32)
3. Brief silence during transition is acceptable for radio

### Phase 2 Verification

1. Play internet radio stream — EQ sliders should affect audio
2. Visualizer should show spectrum analysis during stream playback
3. Balance slider should pan audio left/right during streams
4. Switch between stream and local file — seamless transition
5. Play HLS stream with varying bitrate — no crashes on ABR switches
6. Extended playback (30+ minutes) — no audio drift or memory growth
7. Local file playback — identical behavior to pre-bridge (no regression)
8. Kill stream mid-playback — clean teardown, no orphan taps

---

## Files Modified Summary

### Phase 1
| File | Changes |
|------|---------|
| `StreamPlayer.swift` | Add volume/balance properties |
| `PlaybackCoordinator.swift` | Add setVolume/setBalance, capability flags, isStreamPlaying |
| `AudioPlayer.swift` | Remove cross-backend volume propagation from didSet |
| `WinampMainWindow.swift` | Route volume/balance through coordinator, dim balance during streams |
| `WinampEqualizerWindow.swift` | Dim EQ UI during streams |

### Phase 2
| File | Changes |
|------|---------|
| `LockFreeRingBuffer.swift` | NEW — from ring buffer task |
| `StreamPlayer.swift` | Add MTAudioProcessingTap setup/teardown |
| `AudioPlayer.swift` | Add streamSourceNode, engine graph switching |
| `PlaybackCoordinator.swift` | Update capability flags, manage bridge lifecycle |
| `VisualizerView.swift` | Update playback state gating |

---

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Phase 1 breaks local file volume | Test thoroughly — Phase 1 changes are simple property additions + routing |
| PlaybackCoordinator volume binding breaks UI reactivity | Use @Observable properties with didSet — matches existing pattern |
| Phase 2 ring buffer underruns cause glitches | 4096 frame buffer (~85ms) provides margin; fill silence on underrun |
| Phase 2 ABR format changes crash tap | Pre-allocate for worst-case format; reinitialize in tapPrepare |
| Phase 2 double-render (hear audio twice) | Zero bufferListInOut in tap callback — verified deterministic per Apple QA1783 |
| Swift 6 Sendability errors with tap types | Use @unchecked Sendable wrapper + nonisolated(unsafe) for shared state |

---

## Oracle Review Corrections (gpt-5.3-codex, high reasoning)

### Issues Found (ordered by severity)

1. **HIGH — Step 1.6 video volume risk:** Removing `videoPlaybackController.volume` from AudioPlayer.didSet can break video volume unless PlaybackCoordinator is guaranteed to propagate on ALL volume change paths (UI, restore, programmatic). **Mitigation:** Ensure PlaybackCoordinator.setVolume() also updates videoPlaybackController. Add to Step 1.3a.

2. **HIGH — Backend readiness guards:** Unconditional `setVolume`/`setBalance` on both backends can misbehave if StreamPlayer.player is unconfigured or in error state. **Mitigation:** Use idempotent setters. AVPlayer.volume setter is safe on unconfigured players (no-op), but verify with integration test.

3. **HIGH — Real-time safety not explicit:** Phase 2 tap/source callbacks must be zero-allocation, zero-lock, zero-ARC, zero-logging, zero-main-thread. **Mitigation:** Add explicit real-time safety requirements to Phase 2 steps.

4. **HIGH — ABR race condition:** Ring buffer reader/writer race during tap detach/reattach. **Mitigation:** Atomic generation ID pattern — reader checks epoch, skips stale data. Already in ring buffer task research.

5. **HIGH — Engine graph switching gap:** Stopping/restarting AVAudioEngine during stream↔local transitions can cause audible gap. **Mitigation:** Keep engine running, switch source routing only (disconnect playerNode, connect streamSourceNode or vice versa) without engine restart. Use engine's `disconnectNodeOutput`/`connect` while engine is running.

6. **MEDIUM — Balance re-application:** When switching from stream (balance stored but not applied) to local file, stored balance must be actively re-applied. **Mitigation:** PlaybackCoordinator applies all current settings on backend activation, not just during user interaction.

7. **MEDIUM — Capability flag lifecycle:** Flags must update synchronously with bridge state transitions (start success, failure, teardown). **Mitigation:** Tie flags to actual bridge state, not just `isStreamPlaying`.

8. **MEDIUM — Ring buffer telemetry:** Fixed 4096 frame buffer may underrun under CPU spikes. **Mitigation:** Add underrun/overrun counters (atomic increments, read on main thread for diagnostics).

### Additional Verification Scenarios (from Oracle)

- Rapid slider changes while stream backend is erroring
- ABR transitions with sample-rate/channel-count changes while visualizer active
- Stream drop/reconnect with bridge recovery and capability-flag correctness
- Ring buffer underrun/overrun soak test (long playback + CPU pressure)
- Transition tests: no double-audio and acceptable gap duration
- Thread-safety tests for tap/source teardown during stop/pause/track switch
- CPU/memory regression checks for bridge-enabled streaming

### Ordering Adjustments (from Oracle)

1. Add backend readiness model before Step 1.3
2. Add "coordinator applies current settings on backend activation" before Step 1.6
3. Phase 2: define bridge lifecycle state machine before graph switching
4. Phase 2: ABR handling should be part of initial bridge implementation, not a late add-on

---

## Dependencies

- **Phase 1:** No external dependencies. Can be implemented immediately.
- **Phase 2:** Depends on `lock-free-ring-buffer` task completion. Also depends on Phase 1 (capability flags infrastructure).
- **swift-atomics package:** Required for Phase 2 ring buffer. New SPM dependency (first-party Apple package).
