# Lessons Learned: How a Dual Audio Backend Backed Us Into a Corner

> **Purpose:** Documents how MacAmp's architectural decision to use AVPlayer as a black-box internet radio backend created an invisible wall that only appeared when we needed EQ, visualization, and balance for streams. Captures the full journey from "it works" to "we need to rebuild."

---

## The Story

### Act 1: "We Just Want Streaming" (October 2025)

MacAmp started as a local file player built on AVAudioEngine. Everything worked: 10-band EQ, spectrum analyzer, oscilloscope, Milkdrop visualizer, balance/pan control. The audio pipeline was clean:

```
AVAudioFile → AVAudioPlayerNode → AVAudioUnitEQ → mainMixerNode → [visualizer tap] → outputNode → speakers
```

Then we wanted internet radio. AVPlayer was the obvious choice — Apple's battle-tested streaming player that handles HTTP, HLS, ICY metadata, adaptive bitrate, error recovery, and format negotiation. One line of code: `AVPlayer(url: streamURL).play()`. It just worked.

We didn't care about EQ or visualization for streams. Radio is radio — you just listen. The EQ is for your local music collection. The visualizer is for local playback. So we built a **dual backend:**

```
Local files → AVAudioEngine (EQ + Viz + Balance)
Streams     → AVPlayer (volume only)
```

PlaybackCoordinator orchestrated which backend was active. It worked perfectly. Ship it.

### Act 2: "Wait, Why Can't I EQ My Radio?" (February 2026)

Users (and we) started wanting the same experience for streams. If the EQ makes local files sound better, why not streams? If the spectrum analyzer is fun for local files, why not for radio? If Milkdrop visualizations work for local audio, why are they blank for streams?

The answer seemed simple: just tap AVPlayer's audio output and route it through AVAudioEngine. Like plugging a cable from one device to another.

### Act 3: The MTAudioProcessingTap Dead End

First attempt: MTAudioProcessingTap — Apple's official API for intercepting audio in AVPlayer's pipeline.

We fully implemented it:
- LoopbackTapContext with @unchecked Sendable
- Top-level @convention(c) callbacks (lesson from Swift 6.2 isolation crashes)
- LockFreeRingBuffer (SPSC, Swift Atomics, 4096 frames)
- AVAudioSourceNode consumer with nonisolated static render block
- Engine graph switching (stop/reset/rewire pattern)
- Capability flags, visualizer gating, Oracle-reviewed

**4 commits. Builds clean. Oracle gave 0 P1 findings.**

Then we tested it. `tapPrepare` never fired. `tapProcess` never fired. The tap was completely ignored.

After extensive debugging (file-based logging, 20 retry attempts for track discovery, deferred play sequences), we discovered: **MTAudioProcessingTap does not work with streaming AVPlayerItems.** Apple QA1716 confirms AVAudioMix was designed for file-based content only. CoreMedia simply doesn't invoke tap callbacks for live/streaming sources.

We had built a perfect bridge to nowhere.

### Act 4: The CoreAudio Process Tap Detour

Next attempt: CoreAudio Process Tap (AudioHardwareCreateProcessTap). Capture the process's audio output at the system level.

Both Oracle and Gemini rated it 8/10 feasibility. We researched it deeply — CATapDescription, aggregate devices, device UID scoping.

Then we hit the **feedback loop problem:** tapping your own process captures ALL audio output — AVPlayer + AVAudioEngine + VideoPlaybackController. If you re-render the captured audio through AVAudioEngine, you capture it again. Infinite loop.

Device UID isolation was proposed, but Oracle flagged it as "not reliable for same-process isolation." The API doesn't distinguish between different audio output paths within one process.

### Act 5: The Winamp Revelation

While preparing research for a deep research system, we analyzed how the **original Winamp** handled streaming:

**Winamp had NO dual backend.** It had a single unified pipeline.

`in_mp3.dll` (the MP3 input plugin) handled BOTH local files AND SHOUTcast streams. It decoded network bytes into raw PCM — the exact same format as local files — and pushed them into the same pipeline. The Winamp core never knew or cared where the audio came from. EQ, DSP plugins, and Milkdrop all received the same PCM regardless of source.

```
Winamp: ANY source → in_mp3.dll (decode to PCM) → EQ → DSP → Vis → Output
MacAmp: Stream → AVPlayer (black box) → ??? → can't get PCM out
```

We had built the wrong architecture. AVPlayer isn't a decoder — it's an entire self-contained media player. Using it for streams was like using a TV to play music and then trying to intercept the audio signal coming out of the TV's internal speakers.

### Act 6: The Unified Pipeline (Where We Are Now)

Three independent sources converged on the same conclusion:
1. **Winamp analysis** (Gemini): Single PCM pipeline, decode everything yourself
2. **Deep research system** (user's tool): "AVPlayer must be completely replaced"
3. **Oracle** (gpt-5.3-codex): "Use custom progressive decoder pipeline, replace StreamPlayer's AVPlayer internals"

The correct architecture:
```
HTTP stream → URLSession → ICYFramer → AudioFileStream → AudioConverter → Float32 PCM
    → LockFreeRingBuffer → AVAudioSourceNode → AVAudioEngine (EQ + Viz + Balance) → Speakers
```

This is the Winamp model adapted for modern Apple frameworks.

---

## What We Got Wrong

### 1. Treating AVPlayer as a Decoder
AVPlayer is an opaque, complete media player — not a decode component. It owns its entire pipeline from network to speakers. You can't intercept its internal audio without system-level hacks.

### 2. Not Anticipating Feature Parity
When we added streaming, we explicitly said "no EQ for streams" and added capability flags to dim the UI. This felt like a reasonable trade-off. But it created a permanently inferior experience that users would eventually want fixed.

### 3. The Sunk Cost of MTAudioProcessingTap
We invested significant effort in the tap approach (4 commits, Oracle review, comprehensive implementation) before discovering it fundamentally doesn't work with streams. The API exists, creates successfully, attaches successfully — but never fires. There's no error. It just silently doesn't work.

### 4. Not Studying Winamp's Architecture First
Had we analyzed how Winamp handled streaming before choosing AVPlayer, we would have known that a unified decode pipeline was the proven approach. Winamp solved this problem 20+ years ago.

## What We Got Right

### 1. The Consumer Pipeline Is Correct
Everything downstream of the ring buffer is right: LockFreeRingBuffer, AVAudioSourceNode, engine graph switching, capability flags, VisualizerView updates. These components are source-agnostic — they don't care if PCM comes from a tap, a process capture, or a custom decoder. They just work.

### 2. The PlaybackCoordinator Pattern
The orchestrator pattern is sound. It just needs to coordinate between AudioPlayer (local files) and a new StreamDecodePipeline (custom decoder) instead of AVPlayer.

### 3. Phase 1 (Volume Control) Was Correct
Volume routing through the coordinator, capability flags, UI dimming — all correct and will remain. Volume will shift from `AVPlayer.volume` to `AVAudioSourceNode.volume` once streams flow through the engine.

### 4. Incremental Discovery
Each failed approach taught us something:
- MTAudioProcessingTap failure → AVAudioMix doesn't work with streams
- CoreAudio Process Tap research → feedback loop is unsolvable for same-process
- Winamp analysis → unified pipeline is the proven architecture

---

## Technical Lessons

### 1. Apple's Audio Stack Has Invisible Walls
- AVPlayer and AVAudioEngine are fundamentally separate systems with no bridge API
- MTAudioProcessingTap looks like a bridge but only works for files
- This limitation is not documented prominently — you discover it empirically
- Apple QA1716 hints at it but doesn't explicitly say "won't work with streams"

### 2. "It Creates Successfully" Doesn't Mean "It Works"
- MTAudioProcessingTapCreate returns noErr for streaming items
- The audioMix is accepted by AVPlayerItem
- AVPlayerItem.tracks populates with audio tracks
- Everything looks correct — but the callbacks never fire
- Silent failure is the worst kind of failure

### 3. Black-Box Components Limit Future Capabilities
- AVPlayer is convenient today but constraining tomorrow
- When you delegate too much to an opaque framework, you lose the ability to extend
- The decision to use AVPlayer was correct for "just play streams" but wrong for "play streams with EQ"

### 4. Test the Integration Point First
- We should have tested whether MTAudioProcessingTap fires for streams BEFORE building the full bridge
- A 20-line test script could have saved 4 commits of work
- Always test the riskiest assumption first

### 5. Study Prior Art Before Architecture Decisions
- Winamp solved this exact problem 25 years ago
- The answer (unified PCM pipeline) was well-known in native audio programming
- We approached it as a novel problem because we were thinking in Apple frameworks, not audio architecture

---

## What Survives

| Component | Status | Notes |
|-----------|--------|-------|
| LockFreeRingBuffer | KEEP | Core bridge between any producer and AVAudioEngine consumer |
| AVAudioSourceNode + render block | KEEP | Consumer side is source-agnostic |
| activateStreamBridge / deactivateStreamBridge | KEEP | Engine graph switching works |
| PlaybackCoordinator | KEEP + SIMPLIFY | Remove tap lifecycle, simplify bridge setup |
| Capability flags | KEEP | Same logic, bridge still controls availability |
| VisualizerView isEngineRendering | KEEP | Already updated |
| Phase 1 volume control | KEEP | Routing shifts from AVPlayer.volume to sourceNode.volume |

## What Gets Replaced

| Component | Replacement |
|-----------|-------------|
| AVPlayer for streams | URLSession + AudioFileStream + AudioConverter |
| AVPlayerItemMetadataOutput | Custom ICY metadata parser |
| MTAudioProcessingTap + LoopbackTapContext | Eliminated — no tap needed |
| StreamPlayer.attachLoopbackTap() | Eliminated |

---

## The Article Thesis

> We backed ourselves into a corner we didn't know existed because we solved the easy problem (streaming playback) with a high-level tool (AVPlayer) that made the hard problem (audio processing) impossible. The fix wasn't a clever hack to extract audio from the black box — it was replacing the black box with a transparent pipeline, the same approach that Winamp used 25 years ago.

**Key insight for other developers:** If you might EVER need to process, analyze, or route audio from a media source, don't use AVPlayer. Decode the audio yourself and feed it into AVAudioEngine. The convenience of AVPlayer's built-in playback comes at the cost of permanent opacity.
