# Plan: Internet Streaming Volume Control

> **Purpose:** Implementation plan derived from research findings. Contains step-by-step approach, architecture decisions, and scope definition for enabling volume/EQ on internet radio streams.

---

## Status: ORACLE REVIEWED — CORRECTIONS APPLIED — PREREQUISITE VALIDATION COMPLETE

---

## Architecture Diagrams

### 1. Current Architecture (Before — The Problem)

Two disconnected audio backends with no unified volume routing:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MacAmp Audio System (Current)                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌───────────────────── LOCAL FILE BACKEND ─────────────────────┐           │
│  │                                                               │           │
│  │  AVAudioFile                                                  │           │
│  │      │                                                        │           │
│  │      ▼                                                        │           │
│  │  AVAudioPlayerNode ──► AVAudioUnitEQ ──► AVAudioMixerNode ──►│──► Output │
│  │   .volume ✅            (10-band)          │                  │           │
│  │   .pan ✅                                  │ [installTap]     │           │
│  │                                            ▼                  │           │
│  │                                   VisualizerPipeline          │           │
│  │                                   (Goertzel + FFT)            │           │
│  └───────────────────────────────────────────────────────────────┘           │
│                                                                             │
│  ┌───────────────────── STREAM BACKEND ─────────────────────────┐           │
│  │                                                               │           │
│  │  HTTP URL ──► AVPlayer ──────────────────────────────────────►│──► Output │
│  │               .volume ❌ (EXISTS but NOT WIRED TO UI)         │           │
│  │               .pan ❌ (DOES NOT EXIST)                        │           │
│  │               EQ ❌ (NO NODE GRAPH)                           │           │
│  │               Viz ❌ (NO TAP POINT)                           │           │
│  └───────────────────────────────────────────────────────────────┘           │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────┐         │
│  │                     PlaybackCoordinator                         │         │
│  │  • Routes play(track:) to correct backend                      │         │
│  │  • Does NOT propagate volume/balance/EQ ◄── ROOT CAUSE         │         │
│  └─────────────────────────────────────────────────────────────────┘         │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────┐         │
│  │                    UI Layer (WinampMainWindow)                   │         │
│  │                                                                 │         │
│  │  Volume Slider ──► audioPlayer.volume (AVAudioEngine ONLY)      │         │
│  │  Balance Slider ──► audioPlayer.balance (AVAudioEngine ONLY)    │         │
│  │  EQ Sliders ──► audioPlayer.eqNode (AVAudioEngine ONLY)        │         │
│  │                                                                 │         │
│  │  ❌ StreamPlayer is NEVER updated by any UI control             │         │
│  └─────────────────────────────────────────────────────────────────┘         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Signal break:** The UI binds directly to `AudioPlayer` properties. `StreamPlayer` has no
volume property and receives no updates from any UI control.

---

### 2. Phase 1 Architecture — Volume Routing via PlaybackCoordinator

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MacAmp Audio System (Phase 1)                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌────────────────────── UI Layer ──────────────────────┐                   │
│  │                                                       │                   │
│  │  Volume Slider ─────┐                                 │                   │
│  │  Balance Slider ────┤                                 │                   │
│  │  EQ Sliders ────────┤     (all route through          │                   │
│  │                      ▼      coordinator now)           │                   │
│  └──────────────────────┬────────────────────────────────┘                   │
│                         │                                                    │
│                         ▼                                                    │
│  ┌──────────────── PlaybackCoordinator ─────────────────────────────┐       │
│  │                                                                   │       │
│  │  setVolume(vol) ─────┬──► audioPlayer.volume = vol               │       │
│  │                      ├──► streamPlayer.volume = vol     ◄── NEW  │       │
│  │                      └──► videoPlayer.volume = vol               │       │
│  │                                                                   │       │
│  │  setBalance(bal) ────┬──► audioPlayer.balance = bal              │       │
│  │                      └──► streamPlayer.balance = bal    ◄── NEW  │       │
│  │                           (stored, not applied)                   │       │
│  │                                                                   │       │
│  │  Capability Flags:                                                │       │
│  │  ┌─────────────────────────────────────────────────────┐         │       │
│  │  │ supportsEQ:         !isStreamPlaying                │         │       │
│  │  │ supportsBalance:    !isStreamPlaying                │         │       │
│  │  │ supportsVisualizer: !isStreamPlaying                │         │       │
│  │  └─────────────────────────────────────────────────────┘         │       │
│  └──────────────────────────────────────────────────────────────────┘       │
│                                                                             │
│       ┌──────────────────┐          ┌───────────────────────┐               │
│       │   AudioPlayer    │          │    StreamPlayer        │               │
│       │  (Local Files)   │          │   (Internet Radio)     │               │
│       ├──────────────────┤          ├───────────────────────┤               │
│       │ .volume ✅       │          │ .volume ✅  ◄── NEW   │               │
│       │ .balance ✅      │          │ .balance (stored only) │               │
│       │ .eqNode ✅       │          │ EQ ❌ (unavailable)    │               │
│       │ .visualizer ✅   │          │ Viz ❌ (unavailable)   │               │
│       └──────────────────┘          └───────────────────────┘               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 3. Phase 1 Volume Signal Flow

Step-by-step propagation when user moves the volume slider:

```
  User drags volume slider
          │
          ▼
  ┌─────────────────────────┐
  │ WinampVolumeSlider       │
  │ $coordinator.volume      │  SwiftUI binding triggers didSet
  └────────────┬─────────────┘
               │
               ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │ PlaybackCoordinator.volume didSet                                │
  │                                                                  │
  │   ┌─────────────────────────────────────────────────────────┐    │
  │   │ audioPlayer.volume = vol                                │    │
  │   │   └──► playerNode.volume = vol  (AVAudioEngine)         │    │
  │   │   └──► UserDefaults.set(vol)    (persistence)           │    │
  │   │                                                         │    │
  │   │ streamPlayer.volume = vol                    ◄── NEW    │    │
  │   │   └──► player.volume = vol      (AVPlayer)              │    │
  │   │                                                         │    │
  │   │ videoPlaybackController.volume = vol                    │    │
  │   │   └──► player.volume = vol      (Video AVPlayer)        │    │
  │   └─────────────────────────────────────────────────────────┘    │
  │                                                                  │
  │  All backends updated unconditionally (idempotent, no branching) │
  └──────────────────────────────────────────────────────────────────┘
```

---

### 4. Phase 1 Capability Flags Decision Tree

How UI controls determine enabled/disabled state:

```
                    ┌──────────────────────┐
                    │ Is current track a   │
                    │ stream? (.isStream)  │
                    └────────┬─────────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
                    ▼                 ▼
               YES (Stream)     NO (Local File)
                    │                 │
              ┌─────┴──────┐    ┌────┴──────────────┐
              │ supportsEQ │    │ supportsEQ:    ✅  │
              │   = false  │    │ supportsBalance:✅  │
              │            │    │ supportsViz:   ✅  │
              │ supportsBal│    │                    │
              │   = false  │    │ All controls       │
              │            │    │ fully enabled      │
              │ supportsViz│    └────────────────────┘
              │   = false  │
              └─────┬──────┘
                    │
                    ▼
         ┌──────────────────────────────────┐
         │ UI Response:                      │
         │  • EQ sliders: dimmed / greyed    │
         │  • Balance slider: dimmed         │
         │  • Visualizer: inactive           │
         │  • Volume slider: STILL ACTIVE ✅ │
         │  • Presets: still selectable       │
         │    (applied when local resumes)    │
         └──────────────────────────────────┘
```

---

### 5. Phase 2 Loopback Bridge Architecture (Full Pipeline)

The complete stream audio path through AVAudioEngine:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      MacAmp Audio System (Phase 2 — Loopback Bridge)            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─── STREAM INGESTION ──────────────────────────────────────────────────────┐  │
│  │                                                                           │  │
│  │  HTTP/HLS URL                                                             │  │
│  │      │                                                                    │  │
│  │      ▼                                                                    │  │
│  │  AVPlayer ──► AVPlayerItem                                                │  │
│  │      │            │                                                       │  │
│  │      │      ┌─────┴────────────────────────────────┐                      │  │
│  │      │      │ MTAudioProcessingTap (PreEffects)    │                      │  │
│  │      │      │                                      │                      │  │
│  │      │      │ tapProcess callback:                 │                      │  │
│  │      │      │   1. GetSourceAudio(PCM samples)     │                      │  │
│  │      │      │   2. ringBuffer.write(samples) ──────┼──┐                   │  │
│  │      │      │   3. Zero output buffer ◄─ prevents  │  │                   │  │
│  │      │      │      double-render (silence AVPlayer) │  │                   │  │
│  │      │      └──────────────────────────────────────┘  │                   │  │
│  │      │                                                │                   │  │
│  │      ▼                                                │                   │  │
│  │  [AVPlayer direct output SILENCED]                    │                   │  │
│  │                                                       │                   │  │
│  └───────────────────────────────────────────────────────┼───────────────────┘  │
│                                                          │                      │
│                              ┌────────────────────────────┘                      │
│                              │                                                   │
│                              ▼                                                   │
│  ┌─── LOCK-FREE RING BUFFER ────────────────────────────────────────────────┐   │
│  │                                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐      │   │
│  │  │ Capacity: 4096 frames (~85ms @ 48kHz)                          │      │   │
│  │  │ Format: Stereo Float32                                         │      │   │
│  │  │ Writer: MTAudioProcessingTap thread (real-time)                │      │   │
│  │  │ Reader: AVAudioEngine render thread (real-time)                │      │   │
│  │  │ Sync: Swift Atomics (no locks, no allocations)                 │      │   │
│  │  │ Underrun: Fill silence    Overrun: Drop oldest                 │      │   │
│  │  │ ABR: Atomic generation ID to detect format changes             │      │   │
│  │  └─────────────────────────────────────────────────────────────────┘      │   │
│  │                                                                           │   │
│  └───────────────────────────────────────────────────────┬───────────────────┘   │
│                                                          │                       │
│                                                          ▼                       │
│  ┌─── AVAudioEngine PROCESSING ─────────────────────────────────────────────┐   │
│  │                                                                           │   │
│  │  AVAudioSourceNode                                                        │   │
│  │   (render block reads                                                     │   │
│  │    from ring buffer)                                                      │   │
│  │      │                                                                    │   │
│  │      ▼                                                                    │   │
│  │  AVAudioUnitEQ ◄── Existing 10-band EQ (reused! no custom biquads)       │   │
│  │   (60Hz–16kHz)                                                            │   │
│  │      │                                                                    │   │
│  │      ▼                                                                    │   │
│  │  AVAudioMixerNode                                                         │   │
│  │      │          │                                                         │   │
│  │      │    [installTap] ◄── Existing visualizer tap (reused!)              │   │
│  │      │          │                                                         │   │
│  │      │          ▼                                                         │   │
│  │      │   VisualizerPipeline                                               │   │
│  │      │   (Goertzel + FFT)                                                 │   │
│  │      │                                                                    │   │
│  │      ▼                                                                    │   │
│  │  OutputNode ──────────────────────────────────────────────────►  Speakers  │   │
│  │                                                                           │   │
│  └───────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

### 6. Phase 2 Thread Model

Real-time thread interactions and safety boundaries:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           Thread Interaction Model                            │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ MAIN THREAD (@MainActor)                                                │ │
│  │                                                                         │ │
│  │  • UI slider changes → PlaybackCoordinator.setVolume()                  │ │
│  │  • Capability flag reads (supportsEQ, supportsBalance)                  │ │
│  │  • Bridge lifecycle management (start/stop/teardown)                    │ │
│  │  • Read underrun/overrun telemetry counters                             │ │
│  │  • EQ preset selection                                                  │ │
│  │                                                                         │ │
│  │  ⚠️  SAFE: Allocations, ARC, logging, locks all OK here                │ │
│  └────────────────────────┬────────────────────────────────────────────────┘ │
│                           │                                                  │
│              ┌────────────┴────────────┐                                     │
│              ▼                         ▼                                      │
│  ┌────────────────────┐   ┌────────────────────────────┐                     │
│  │ TAP THREAD          │   │ RENDER THREAD               │                    │
│  │ (CoreMedia RT)      │   │ (CoreAudio RT)              │                    │
│  │                     │   │                              │                    │
│  │ tapProcess():       │   │ sourceNode render block:     │                    │
│  │  GetSourceAudio()   │   │  ringBuffer.read()           │                    │
│  │  ringBuffer.write() │──►│  Fill silence on underrun    │                    │
│  │  Zero output buffer │   │  return noErr                │                    │
│  │                     │   │                              │                    │
│  │ tapPrepare():       │   │ Pulls at hardware rate       │                    │
│  │  Capture format     │   │ (typically 512 frames        │                    │
│  │  Reset ring buffer  │   │  @ 48kHz = ~10.7ms)          │                    │
│  │  Update generation  │   │                              │                    │
│  │                     │   │                              │                    │
│  │ ⛔ FORBIDDEN:       │   │ ⛔ FORBIDDEN:                │                    │
│  │  • malloc/free      │   │  • malloc/free               │                    │
│  │  • Swift ARC ops    │   │  • Swift ARC ops             │                    │
│  │  • Locks/mutexes    │   │  • Locks/mutexes             │                    │
│  │  • ObjC messaging   │   │  • ObjC messaging            │                    │
│  │  • print/NSLog      │   │  • print/NSLog               │                    │
│  │  • Task/async       │   │  • Task/async                │                    │
│  └────────────────────┘   └────────────────────────────┘                     │
│              │                         │                                      │
│              │    ┌────────────────────┘                                      │
│              ▼    ▼                                                           │
│  ┌────────────────────────────────────────┐                                  │
│  │ SHARED STATE (Lock-Free Only)          │                                  │
│  │                                        │                                  │
│  │  Ring Buffer:                          │                                  │
│  │   writeHead: AtomicUInt64 (tap owns)   │                                  │
│  │   readHead:  AtomicUInt64 (render owns)│                                  │
│  │   storage:   UnsafeMutableBufferPointer │                                  │
│  │   generationID: AtomicUInt32 (ABR)     │                                  │
│  │                                        │                                  │
│  │  Telemetry:                            │                                  │
│  │   underrunCount: AtomicUInt64          │                                  │
│  │   overrunCount:  AtomicUInt64          │                                  │
│  │                                        │                                  │
│  │  Swift 6: nonisolated(unsafe)          │                                  │
│  │  Tap types: @unchecked Sendable        │                                  │
│  └────────────────────────────────────────┘                                  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

### 7. Backend Switching State Machine

Transitions between local file and stream playback:

```
                              ┌──────────────┐
                              │    IDLE       │
                              │ (no playback) │
                              └──────┬───────┘
                                     │
                        ┌────────────┴────────────┐
                        │                         │
                   play(local)               play(stream)
                        │                         │
                        ▼                         ▼
              ┌──────────────────┐    ┌────────────────────────┐
              │  LOCAL PLAYING   │    │   STREAM PLAYING       │
              │                  │    │                        │
              │ Engine graph:    │    │ Phase 1:               │
              │  playerNode      │    │  AVPlayer direct       │
              │  → eqNode        │    │  volume via .volume    │
              │  → mixerNode     │    │  EQ/Bal/Viz disabled   │
              │  → outputNode    │    │                        │
              │                  │    │ Phase 2:               │
              │ All controls ✅  │    │  Bridge active         │
              │ volume ✅        │    │  streamSourceNode      │
              │ balance ✅       │    │  → eqNode              │
              │ EQ ✅            │    │  → mixerNode           │
              │ visualizer ✅    │    │  → outputNode          │
              │                  │    │  All controls ✅       │
              └────────┬─────────┘    └──────────┬─────────────┘
                       │                         │
                       │    ┌──────────────┐     │
                       │    │  SWITCHING   │     │
                       └───►│              │◄────┘
                            │ 1. Stop src  │
                            │ 2. Disconnect│
                            │    old node  │
                            │ 3. Connect   │
                            │    new node  │
                            │ 4. Apply vol │
                            │    bal, EQ   │
                            │ 5. Update    │
                            │    cap flags │
                            │              │
                            │ ⚠️  Engine   │
                            │ stays running│
                            │ (no restart) │
                            └──────────────┘

  Phase 2 Engine Graph Switching Detail:

  LOCAL → STREAM:                        STREAM → LOCAL:
  ┌─────────────────────────┐            ┌─────────────────────────┐
  │ 1. disconnect(playerNode)│            │ 1. disconnect(srcNode)  │
  │ 2. connect(srcNode→eq)   │            │ 2. connect(playerNode→eq)│
  │ 3. Start tap + bridge    │            │ 3. Stop tap + bridge    │
  │ 4. Re-apply volume/bal   │            │ 4. Re-apply volume/bal  │
  │ 5. Update cap flags      │            │ 5. Update cap flags     │
  │                           │            │                         │
  │ Engine never stops ✅     │            │ Engine never stops ✅   │
  └─────────────────────────┘            └─────────────────────────┘
```

---

### 8. ABR (Adaptive Bitrate) Format Change Handling

How HLS bitrate switches are handled in the Loopback Bridge:

```
  Normal Streaming                    ABR Bitrate Switch Event
  ─────────────────                   ──────────────────────────

  tapProcess()                        CoreMedia detects bandwidth change
      │                                       │
      ▼                                       ▼
  GetSourceAudio ──► write            ┌──────────────────┐
  GetSourceAudio ──► write            │ tapUnprepare()   │
  GetSourceAudio ──► write            │  • Flush buffer  │
  ...                                 │  • Signal reader │
                                      └────────┬─────────┘
                                               │
                                               ▼
                                      ┌──────────────────┐
                                      │ tapPrepare()     │
                                      │  • New format:   │
                                      │    48kHz→44.1kHz │
                                      │    or vice versa │
                                      │  • Reinit buffer │
                                      │  • Increment     │
                                      │    generationID  │
                                      └────────┬─────────┘
                                               │
                                               ▼
                                      tapProcess() resumes
                                          │
                                          ▼
                                      GetSourceAudio ──► write (new format)
                                      ...

  Reader side during transition:

  sourceNode render block              sourceNode render block
      │                                       │
      ▼                                       ▼
  ringBuffer.read()                    ringBuffer.read()
  → framesRead = N ✅                 → framesRead = 0 (buffer flushed)
  → output samples                    → fill silence ◄── brief gap OK
                                               │
                                               ▼
                                      Check generationID changed?
                                      → Yes: accept new format
                                      → Resume reading new data
```

---

### 9. Component Dependency Map

Files and their relationships across both phases:

```
  ┌─────────────────────────────────────────────────────────────────────────────┐
  │                         Component Dependency Map                            │
  ├─────────────────────────────────────────────────────────────────────────────┤
  │                                                                             │
  │                        ┌──────────────────────┐                             │
  │                        │  WinampMainWindow     │                             │
  │                        │  (volume/balance UI)  │                             │
  │                        └──────────┬───────────┘                             │
  │                                   │ binds to                                │
  │  ┌────────────────────┐           │           ┌───────────────────────┐     │
  │  │ WinampEqualizer    │           │           │ VisualizerView        │     │
  │  │ Window (EQ UI)     │           │           │ (spectrum display)    │     │
  │  └────────┬───────────┘           │           └───────────┬───────────┘     │
  │           │ reads                 │                       │ reads            │
  │           │ supportsEQ            ▼                       │ supportsViz     │
  │           │              ┌──────────────────┐             │                 │
  │           └─────────────►│ Playback         │◄────────────┘                 │
  │                          │ Coordinator      │                               │
  │                          │                  │                               │
  │                          │ • setVolume()    │                               │
  │                          │ • setBalance()   │                               │
  │                          │ • supportsEQ     │                               │
  │                          │ • supportsBalance│                               │
  │                          │ • supportsViz    │                               │
  │                          └───────┬──────────┘                               │
  │                                  │ propagates to                            │
  │                    ┌─────────────┼─────────────┐                            │
  │                    │             │             │                             │
  │                    ▼             ▼             ▼                             │
  │           ┌──────────────┐ ┌──────────┐ ┌──────────────────┐               │
  │           │ AudioPlayer  │ │ Stream   │ │ VideoPlayback    │               │
  │           │              │ │ Player   │ │ Controller       │               │
  │           │ .volume      │ │ .volume  │ │ .volume          │               │
  │           │ .balance     │ │ .balance │ │                  │               │
  │           │ .eqNode      │ │ .player  │ │                  │               │
  │           │ .playerNode  │ │          │ │                  │               │
  │           │ .sourceNode* │ │ .tap*    │ │                  │               │
  │           └──────┬───────┘ └────┬─────┘ └──────────────────┘               │
  │                  │              │                                            │
  │                  │   Phase 2    │  Phase 2                                  │
  │                  │   only       │  only                                     │
  │                  │              │                                            │
  │                  │    ┌─────────┘                                            │
  │                  │    │                                                      │
  │                  ▼    ▼                                                      │
  │           ┌─────────────────────┐                                           │
  │           │ LockFreeRingBuffer  │  Phase 2 only                             │
  │           │ (Swift Atomics)     │  (from ring buffer task)                  │
  │           └─────────────────────┘                                           │
  │                                                                             │
  │  Legend:  ── Phase 1    ── Phase 2 only (marked with *)                     │
  │                                                                             │
  └─────────────────────────────────────────────────────────────────────────────┘
```

---

### 10. Comparison: Winamp vs Webamp vs MacAmp Pipelines

```
  WINAMP (Windows) — Unified PCM Pipeline
  ─────────────────────────────────────────
  Any Source ──► Decode to PCM ──► vis_*.dll ──► dsp_*.dll (EQ) ──► out_*.dll
                                                      │
                                  All sources are PCM by this point.
                                  EQ sees no difference between file/stream.


  WEBAMP (JavaScript) — Web Audio API Unified Graph
  ──────────────────────────────────────────────────
  <audio> element ──► MediaElementSource ──► BiquadFilter (EQ) ──► Analyser (Viz) ──► Destination
                             │
               Web Audio connects ANY source to processing nodes.
               No file/stream distinction.


  MACAMP (macOS) — Dual Backend (Current)
  ────────────────────────────────────────
  Local:  AVAudioFile ──► AVAudioEngine (EQ ✅, Viz ✅, Vol ✅, Bal ✅)
  Stream: HTTP URL ──► AVPlayer (closed box — Vol ❌, EQ ❌, Viz ❌, Bal ❌)

                  ⬇️  Phase 1 fixes volume  ⬇️

  Local:  AVAudioFile ──► AVAudioEngine (EQ ✅, Viz ✅, Vol ✅, Bal ✅)
  Stream: HTTP URL ──► AVPlayer (Vol ✅, EQ ❌, Viz ❌, Bal ❌)

                  ⬇️  Phase 2 Loopback Bridge  ⬇️

  Local:  AVAudioFile ──► AVAudioEngine (EQ ✅, Viz ✅, Vol ✅, Bal ✅)
  Stream: HTTP URL ──► AVPlayer ──► Tap ──► Ring Buffer ──► AVAudioEngine
                                                             (EQ ✅, Viz ✅, Vol ✅, Bal ✅)

                  Both backends converge on AVAudioEngine for processing.
                  Matches Winamp/Webamp unified pipeline philosophy.
```

---

### 11. Completed System — Final Architecture (Post Phase 1 + Phase 2)

The unified MacAmp audio system after all work is complete:

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                      │
│                        MacAmp Audio System — COMPLETED STATE                         │
│                        ─────────────────────────────────────                         │
│                                                                                      │
│          All audio sources converge on AVAudioEngine for processing.                 │
│          Every UI control works identically regardless of source.                    │
│                                                                                      │
├──────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│                              ┌──────────────────────┐                                │
│                              │      UI LAYER         │                                │
│                              │  (WinampMainWindow)   │                                │
│                              │                       │                                │
│                              │  Volume ■■■■■□□ 71%   │                                │
│                              │  Balance ◄──●───► 0   │                                │
│                              │  [▶] [■] [◄◄] [►►]   │                                │
│                              │                       │                                │
│                              │  All controls active  │                                │
│                              │  for ALL sources ✅   │                                │
│                              └──────────┬────────────┘                                │
│                                         │                                             │
│                                         ▼                                             │
│                              ┌──────────────────────────────────────────┐             │
│                              │         PlaybackCoordinator              │             │
│                              │                                          │             │
│                              │  setVolume(vol) ───► all backends        │             │
│                              │  setBalance(bal) ──► all backends        │             │
│                              │                                          │             │
│                              │  supportsEQ:      true  (always)        │             │
│                              │  supportsBalance:  true  (always)        │             │
│                              │  supportsViz:      true  (always)        │             │
│                              │                                          │             │
│                              │  play(track) ──► route to correct path   │             │
│                              └─────────────────┬────────────────────────┘             │
│                                                │                                      │
│                               ┌────────────────┴────────────────┐                     │
│                               │                                 │                     │
│                          Local File?                       Stream URL?                │
│                               │                                 │                     │
│                               ▼                                 ▼                     │
│                                                                                      │
│  SOURCE A: LOCAL FILES                    SOURCE B: INTERNET RADIO                   │
│  ══════════════════════                   ═══════════════════════                     │
│                                                                                      │
│  ┌───────────────────┐                    ┌───────────────────────────────────┐       │
│  │                   │                    │                                   │       │
│  │   AVAudioFile     │                    │   HTTP/HLS URL                    │       │
│  │   (MP3/FLAC/      │                    │       │                           │       │
│  │    WAV/M4A/OGG)   │                    │       ▼                           │       │
│  │       │           │                    │   AVPlayer                        │       │
│  │       ▼           │                    │       │                           │       │
│  │  AVAudioPlayer    │                    │       ▼                           │       │
│  │  Node             │                    │   AVPlayerItem                    │       │
│  │                   │                    │       │                           │       │
│  └───────┬───────────┘                    │   MTAudioProcessingTap            │       │
│          │                                │       │                           │       │
│          │                                │       ▼                           │       │
│          │                                │   tapProcess():                   │       │
│          │                                │     GetSourceAudio(PCM)           │       │
│          │                                │     ringBuffer.write(samples)     │       │
│          │                                │     zero output (silence direct)  │       │
│          │                                │                                   │       │
│          │                                └──────────────┬────────────────────┘       │
│          │                                               │                            │
│          │                                               ▼                            │
│          │                                ┌──────────────────────────┐                │
│          │                                │  Lock-Free Ring Buffer   │                │
│          │                                │  4096 frames (~85ms)     │                │
│          │                                │  Swift Atomics           │                │
│          │                                └─────────────┬────────────┘                │
│          │                                              │                             │
│          │                                              ▼                             │
│          │                                ┌──────────────────────────┐                │
│          │                                │  AVAudioSourceNode       │                │
│          │                                │  (render block reads     │                │
│          │                                │   from ring buffer)      │                │
│          │                                └─────────────┬────────────┘                │
│          │                                              │                             │
│          │      ┌───────────────────────────────────────┘                             │
│          │      │                                                                     │
│          │      │   Engine graph hot-swaps source node:                               │
│          │      │   Local  → playerNode connected                                     │
│          │      │   Stream → sourceNode connected                                     │
│          │      │   (engine never restarts)                                           │
│          │      │                                                                     │
│          ▼      ▼                                                                     │
│  ════════════════════════════════════════════════════════════════════════              │
│  ║                    SHARED AVAudioEngine PIPELINE                    ║              │
│  ║                    (identical processing for both sources)          ║              │
│  ║                                                                    ║              │
│  ║   ┌─────────────────────────────────────────────────────────────┐  ║              │
│  ║   │                                                             │  ║              │
│  ║   │   [playerNode OR sourceNode]                                │  ║              │
│  ║   │              │                                              │  ║              │
│  ║   │              ▼                                              │  ║              │
│  ║   │     AVAudioUnitEQ (10-band)                                 │  ║              │
│  ║   │     60Hz · 170Hz · 310Hz · 600Hz · 1kHz                    │  ║              │
│  ║   │     3kHz · 6kHz · 12kHz · 14kHz · 16kHz                    │  ║              │
│  ║   │              │                                              │  ║              │
│  ║   │              ▼                                              │  ║              │
│  ║   │     AVAudioMixerNode                                       │  ║              │
│  ║   │         │            │                                      │  ║              │
│  ║   │         │      [installTap]                                 │  ║              │
│  ║   │         │            │                                      │  ║              │
│  ║   │         │            ▼                                      │  ║              │
│  ║   │         │    VisualizerPipeline                             │  ║              │
│  ║   │         │    ┌─────────────────────────┐                    │  ║              │
│  ║   │         │    │ Goertzel (20-bar)       │                    │  ║              │
│  ║   │         │    │ vDSP FFT (waveform)     │──► Visualizer UI  │  ║              │
│  ║   │         │    │ Spectrum analysis        │                    │  ║              │
│  ║   │         │    └─────────────────────────┘                    │  ║              │
│  ║   │         │                                                   │  ║              │
│  ║   │         ▼                                                   │  ║              │
│  ║   │     OutputNode ─────────────────────────────► 🔊 Speakers  │  ║              │
│  ║   │                                                             │  ║              │
│  ║   └─────────────────────────────────────────────────────────────┘  ║              │
│  ║                                                                    ║              │
│  ════════════════════════════════════════════════════════════════════════              │
│                                                                                      │
│  ┌────────────────────────────────────────────────────────────────────┐               │
│  │                         EQ WINDOW                                  │               │
│  │                                                                    │               │
│  │  60   170  310  600  1k   3k   6k  12k  14k  16k                 │               │
│  │  ┃     ┃    ┃    ┃    ┃    ┃    ┃    ┃    ┃    ┃                  │               │
│  │  ┃  ┌──╂──┐ ┃    ┃    ┃    ┃    ┃    ┃    ┃    ┃  Preamp         │               │
│  │  ┃  │  ╂  │ ┃    ┃ ┌──╂──┐ ┃    ┃    ┃    ┃    ┃  ┃              │               │
│  │  ╂──┤  ╂  ├─╂────╂─┤  ╂  ├─╂────╂────╂────╂────╂──╂── 0dB       │               │
│  │  ┃  │  ╂  │ ┃    ┃ │  ╂  │ ┃    ┃ ┌──╂──┐ ┃    ┃  ┃              │               │
│  │  ┃  └──╂──┘ ┃    ┃ └──╂──┘ ┃    ┃ │  ╂  │ ┃    ┃  ┃              │               │
│  │  ┃     ┃    ┃    ┃    ┃    ┃    ┃ └──╂──┘ ┃    ┃  ┃              │               │
│  │                                                                    │               │
│  │  ✅ ACTIVE for BOTH local files AND internet streams              │               │
│  └────────────────────────────────────────────────────────────────────┘               │
│                                                                                      │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 12. Completed System — End-to-End User Flow

What happens from the user's perspective when playing an internet radio stream:

```
  USER ACTION                          SYSTEM RESPONSE
  ═══════════                          ═══════════════

  1. User clicks "Open URL"
     enters: http://stream.radio.com
         │
         ▼
  ┌─────────────────────┐
  │ PlaybackCoordinator  │
  │ play(track:)         │
  │                      │    Track.isStream == true
  │ Detects stream URL ──┼──► Route to StreamPlayer
  └──────────┬───────────┘
             │
             ▼
  ┌──────────────────────────────────────────────────────┐
  │ StreamPlayer.play(url:)                               │
  │                                                       │
  │  1. Create AVPlayerItem(url:)                         │
  │  2. Attach MTAudioProcessingTap to item               │
  │  3. Set player.replaceCurrentItem(with: item)         │
  │  4. Apply volume: player.volume = currentVolume       │
  │  5. player.play()                                     │
  │                                                       │
  │  ICY metadata extraction begins (title/artist)        │
  └──────────────────────┬────────────────────────────────┘
                         │
                         ▼
  ┌──────────────────────────────────────────────────────┐
  │ PlaybackCoordinator activates bridge                  │
  │                                                       │
  │  1. Disconnect playerNode from eqNode                 │
  │  2. Connect streamSourceNode → eqNode                 │
  │  3. Engine stays running (no restart)                 │
  │  4. Apply current volume + balance                    │
  │  5. Update capability flags (all true)                │
  └──────────────────────┬────────────────────────────────┘
                         │
                         ▼
  ┌──────────────────────────────────────────────────────┐
  │ Audio flows through unified pipeline                  │
  │                                                       │
  │  HTTP data ──► AVPlayer decodes ──► Tap extracts PCM  │
  │  ──► Ring Buffer ──► SourceNode ──► EQ ──► Mixer      │
  │  ──► Output                                           │
  │       │                                               │
  │       └──► installTap ──► VisualizerPipeline          │
  └──────────────────────────────────────────────────────┘
             │
             ▼

  ╔══════════════════════════════════════════════════════╗
  ║              USER SEES & HEARS                       ║
  ╠══════════════════════════════════════════════════════╣
  ║                                                      ║
  ║  🔊 Audio plays through speakers                     ║
  ║                                                      ║
  ║  📊 Visualizer animates (20-bar spectrum)            ║
  ║     ▁▃▅▇█▇▅▃▁▂▄▆█▆▄▂▁▃                             ║
  ║                                                      ║
  ║  🎚️ Volume slider: adjusts stream volume             ║
  ║  ◄►  Balance slider: pans left/right                 ║
  ║  🎛️ EQ sliders: shape frequency response             ║
  ║                                                      ║
  ║  📻 Title bar: "KEXP - Radiohead - Everything..."    ║
  ║     (ICY metadata from stream)                       ║
  ║                                                      ║
  ║  Identical experience to local file playback ✅      ║
  ╚══════════════════════════════════════════════════════╝


  2. User adjusts volume slider during stream
         │
         ▼
  ┌──────────────────────────┐
  │ PlaybackCoordinator       │
  │ setVolume(0.45)           │
  │                           │
  │  audioPlayer.volume = 0.45│──► playerNode.volume (idle, no-op)
  │  streamPlayer.volume= 0.45│──► player.volume = 0.45
  │  videoPlayer.volume = 0.45│──► (idle, no-op)
  │                           │
  │  UserDefaults.set(0.45)   │──► persisted for next launch
  └───────────────────────────┘
         │
         ▼
  Volume change is INSTANT ✅ (AVPlayer.volume is synchronous)


  3. User adjusts EQ slider (e.g., boost 1kHz +6dB)
         │
         ▼
  ┌──────────────────────────┐
  │ AudioPlayer.eqNode        │
  │  band[4].gain = 6.0       │──► AVAudioUnitEQ processes in engine
  └───────────────────────────┘       │
         │                            ▼
         │                   Stream audio flowing through engine
         │                   is affected by EQ in real-time ✅
         ▼
  User hears bass boost on the radio stream


  4. User switches from stream to local file
         │
         ▼
  ┌──────────────────────────────────────────────────────┐
  │ PlaybackCoordinator                                   │
  │                                                       │
  │  1. streamPlayer.stop()                               │
  │  2. Detach MTAudioProcessingTap                       │
  │  3. Flush ring buffer                                 │
  │  4. Disconnect streamSourceNode from eqNode           │
  │  5. Connect playerNode → eqNode                       │
  │  6. audioPlayer.play(file)                            │
  │  7. Re-apply current volume + balance                 │
  │  8. Engine stayed running — no gap ✅                 │
  │                                                       │
  │  EQ preset preserved across switch ✅                 │
  │  Volume preserved across switch ✅                    │
  │  Balance preserved across switch ✅                   │
  │  Visualizer continues seamlessly ✅                   │
  └──────────────────────────────────────────────────────┘


  5. User quits and relaunches MacAmp, plays stream
         │
         ▼
  ┌──────────────────────────────────────────────────────┐
  │ App Launch                                            │
  │                                                       │
  │  1. Read volume from UserDefaults → 0.45              │
  │  2. Read balance from UserDefaults → 0.0              │
  │  3. Read EQ preset from UserDefaults → "Rock"         │
  │  4. Apply to all backends                             │
  │  5. User plays stream → volume is 0.45 immediately    │
  │  6. EQ "Rock" preset shapes the stream audio          │
  │                                                       │
  │  Complete persistence across sessions ✅              │
  └──────────────────────────────────────────────────────┘
```

---

### 13. Completed System — Feature Parity Matrix

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │                    FEATURE PARITY MATRIX (Completed)                │
  ├───────────────────┬──────────────┬─────────────────┬───────────────┤
  │ Feature           │ Local Files  │ Internet Streams │ Video Files   │
  ├───────────────────┼──────────────┼─────────────────┼───────────────┤
  │ Volume Control    │     ✅       │       ✅         │     ✅        │
  │ Balance/Pan       │     ✅       │       ✅         │     ❌        │
  │ 10-Band EQ        │     ✅       │       ✅         │     ❌        │
  │ Visualizer        │     ✅       │       ✅         │     ❌        │
  │ Metadata          │     ✅       │       ✅ (ICY)   │     ✅        │
  │ Seek              │     ✅       │       ❌ (live)  │     ✅        │
  │ Persistence       │     ✅       │       ✅         │     ✅        │
  ├───────────────────┼──────────────┼─────────────────┼───────────────┤
  │ Audio Engine      │ AVAudioEngine│ AVPlayer →       │ AVPlayer      │
  │                   │ (direct)     │ Bridge →         │ (direct)      │
  │                   │              │ AVAudioEngine    │               │
  └───────────────────┴──────────────┴─────────────────┴───────────────┘

  Before:  Streams had 1/7 features working (metadata only)
  After:   Streams have 6/7 features working (all except seek — inherent to live radio)
```

---

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
    audioPlayer.videoPlaybackController.volume = volume
    // All backends always in sync — coordinator doesn't need to track which is active
}

func setBalance(_ balance: Float) {
    audioPlayer.balance = balance
    streamPlayer.balance = balance
}
```

**Design decision:** Update ALL backends unconditionally rather than checking which is active. This is simpler, avoids race conditions during backend switching, and has zero cost (setting volume on an idle player is a no-op). This includes video volume propagation, which moves from AudioPlayer.volume didSet to the coordinator (see Step 1.6).

### Step 1.4: Add capability flags to PlaybackCoordinator

**File:** `MacAmpApp/Audio/PlaybackCoordinator.swift`

Add computed properties that UI components can observe to gate feature availability:

```swift
var supportsEQ: Bool {
    !isStreamBackendActive
}

var supportsBalance: Bool {
    !isStreamBackendActive
}

var supportsVisualizer: Bool {
    !isStreamBackendActive
}

/// Whether the stream backend is active (playing OR paused on a stream).
/// Uses currentSource rather than currentTrack?.isStream because currentTrack
/// can be nil when playing a station directly (not from playlist).
private var isStreamBackendActive: Bool {
    if case .radioStation = currentSource { return true }
    return false
}
```

**Note:** Uses `currentSource` (which is always set correctly by play methods) rather than `currentTrack?.isStream` because `currentTrack` can be nil when playing a radio station directly via `play(station:)` (see PlaybackCoordinator.swift line 133). Also, a paused stream should still report as stream-backend-active for capability flag purposes.

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

### Step 1.8: Disable balance slider during stream playback + reroute binding

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

Read `playbackCoordinator.supportsBalance` and visually indicate when balance is unavailable:
- Dim/grey out balance slider
- Slider position preserved but doesn't affect stream audio
- **Also reroute balance binding** through PlaybackCoordinator (same as volume in Step 1.5) — currently balance binds directly to `audioPlayer.balance`, bypassing the coordinator

### Step 1.9: Apply persisted volume on stream start

**File:** `MacAmpApp/Audio/StreamPlayer.swift`

When StreamPlayer starts playback, apply the current volume:

```swift
func play(url: URL) {
    player.volume = volume  // Apply current volume before playback
    // ... existing playback code
}
```

**Startup sync:** Persisted volume is loaded in AudioPlayer.init() from UserDefaults. PlaybackCoordinator must propagate this initial volume to StreamPlayer during init (or lazily before first stream play) to ensure StreamPlayer.volume matches the persisted value before the first stream playback. Otherwise, the first stream play will use the default 0.75 instead of the user's saved volume.

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

**Prerequisite status:** ~~VisualizerPipeline zero-allocation refactor~~ **COMPLETE.** The SPSC shared buffer pattern (VisualizerSharedBuffer) provides a proven structural template for the ring buffer: generation counter, tryPublish/consume pattern, pre-allocated storage. However, the Phase 2 ring buffer between MTAudioProcessingTap and AVAudioEngine render threads (both real-time) requires true lock-free SPSC atomics (head/tail indices), not os_unfair_lock — the lock pattern is appropriate for RT-to-main but not RT-to-RT.

**clearData():** VisualizerPipeline.clearData() (line 453) must be called during stream-to-local transitions to prevent stale visualizer data. Already used by AudioPlayer.removeVisualizerTapIfNeeded().

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
