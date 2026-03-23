# Research: Video Audio Engine Routing

> **Purpose:** Research MTAudioProcessingTap and AVAudioEngine integration for routing video playback audio through the engine graph.

**Status:** Initial research complete (2026-03-22). Deep research with Gemini pending.

---

## Context

Video currently uses AVPlayer directly — audio bypasses the AVAudioEngine graph. MTAudioProcessingTap works with local file AVPlayerItems (unlike streaming items where it failed for T5 Phase 2). This would unify ALL audio through the engine, enabling EQ/visualization for video playback.

---

## Current Architecture (3 Audio Paths)

```
Local audio → AVAudioPlayerNode → EQ → mixer → output    ✅ EQ, visualizer, balance
Streams     → decode → ringbuffer → AVAudioSourceNode → EQ → mixer → output    ✅ EQ, visualizer, balance
Video       → AVPlayer → direct to speakers    ❌ NO EQ, NO visualizer, NO balance
```

### Video Playback Today

- **`VideoPlaybackController`** (`Audio/VideoPlaybackController.swift`) owns an `AVPlayer` instance
- Audio goes directly from AVPlayer to system hardware — never touches AVAudioEngine
- Video files detected by extension (mp4, mov, m4v, avi) in `AudioPlayer.swift:360`
- Volume synced to AVPlayer separately (`videoPlaybackController.volume = volume`)
- **No EQ, no visualization, no balance** for video playback
- `snapshotButterchurnFrame()` returns nil for video (line 621)
- Visualizer tap removed when switching from audio to video (line 338)

## Target Architecture

```
Local audio → AVAudioPlayerNode → EQ → mixer → output
Streams     → decode → ringbuffer → AVAudioSourceNode → EQ → mixer → output
Video       → AVPlayer(video only) + MTAudioProcessingTap → ringbuffer → AVAudioSourceNode → EQ → mixer → output
```

Keep AVPlayer for **video rendering** (handles codecs, frame timing). Intercept decoded audio via MTAudioProcessingTap before it reaches speakers. That PCM goes into the existing ring buffer → AVAudioSourceNode → EQ → mixer path. AVPlayer's own audio muted (`volume = 0`).

## MTAudioProcessingTap Feasibility

### Confirmed Working for Local Files

MTAudioProcessingTap **works for local file AVPlayerItems** (Apple QA1716 confirms tap callbacks fire for local media). This was validated during the unified-audio-pipeline research. Since MacAmp video files are always local (mp4, mov, m4v, avi), this approach is viable.

### What the Tap Does

1. Create `MTAudioProcessingTap` with C-convention callbacks (`tapPrepare`, `tapProcess`, `tapUnprepare`, `tapFinalize`)
2. Attach to AVPlayerItem's audio track via `AVMutableAudioMix` + `AVMutableAudioMixInputParameters`
3. In `tapProcess`: call `MTAudioProcessingTapGetSourceAudio()` to get decoded PCM frames
4. Write PCM into existing `LockFreeRingBuffer`
5. Existing `AVAudioSourceNode` consumer reads from ring buffer → EQ → mixer → output
6. Mute AVPlayer's own audio (`player.volume = 0`) to prevent double-audio

## A/V Sync Risk (Key Technical Challenge)

### The Problem

AVPlayer normally renders video frames and audio samples on a unified internal clock — perfectly synchronized. When audio is intercepted and routed through our pipeline, latency is introduced:

```
Video frame → AVPlayer renders immediately → screen
Audio sample → tap intercepts → ring buffer write → ring buffer read → AVAudioEngine → speakers
```

The ring buffer itself is fast (SPSC, ~2-4ms). The latency comes from the **asynchronous boundary** — the tap writes at AVPlayer's pace, the AVAudioSourceNode reads at Core Audio's pace. These two clocks aren't synchronized.

**Perceptible threshold:** Humans notice A/V desync at ~40-80ms. If pipeline stays under ~30ms, likely fine. Needs measurement.

### Sync Solutions to Investigate

1. **`AVPlayer.masterClock`** — Set AVPlayer's master clock to match Core Audio's clock (`audioEngine.outputNode.audioUnit.deviceClock`). Synchronizes both timelines at the source.

2. **CMSampleBuffer presentation timestamps** — Tap provides exact timestamps for each audio chunk. Can detect drift and compensate.

3. **Pre-roll strategy** — Start audio pipeline first, let it buffer a few frames, then start video with calculated offset. Standard approach in professional A/V pipelines.

4. **`AVSynchronizedLayer`** — Apple's mechanism for syncing a video layer to an audio timeline.

5. **Ring buffer fill-level monitoring** — Buffer fill level is a proxy for A/V drift. If it grows, audio is lagging; if it drains, audio is leading. Could drive micro-adjustments.

## Ring Buffer Implications

The existing `LockFreeRingBuffer` works **as-is** — format-agnostic interleaved Float32 PCM. No structural changes needed. The stream bridge already proved this path.

For video, ring buffer fill level becomes meaningful (unlike streams where it's just flow control). Could add a fill-level monitoring callback for drift detection, but the buffer itself stays the same.

## Implementation Scope

### Changes Needed

1. **MTAudioProcessingTap setup** (~100-150 lines of C-convention callbacks)
2. **Wire tap output → existing ring buffer → existing bridge**
3. **Mute AVPlayer audio, keep video rendering**
4. **Engine config change handler** (also needed by AirPlay task — shared dependency)
5. **Sync mechanism** (masterClock or pre-roll — needs investigation)

### Risk Assessment: MEDIUM-HIGH

**Favorable:**
- MTAudioProcessingTap proven for local file AVPlayerItems
- Ring buffer + AVAudioSourceNode infrastructure battle-tested from stream bridge
- AudioEngineController graph wiring pattern well-established

**Risks:**
- **A/V sync drift** — Unknown latency, needs measurement and compensation
- **Sample rate mismatches** — Video audio tracks may be 48kHz (vs 44.1kHz for music)
- **Swift 6.2 isolation** — Tap callbacks must be `@convention(c)`, not closures
- **AVPlayer volume = 0 fallback** — If tap fails silently, user hears no audio
- **Zero existing MTAudioProcessingTap code** in codebase

### Recommendation

Defer to Sprint S3. Do a Gemini deep-research spike on A/V sync strategies first. The AirPlay task (S2) will add the engine config change handler that video routing also needs, so S3 benefits from that foundation.

---

## Gemini Deep Research (Pending)

See state.md for the Gemini prompt. Research should cover:
- MTAudioProcessingTap + AVAudioEngine A/V sync strategies
- `AVPlayer.masterClock` usage patterns
- `AVSynchronizedLayer` applicability
- Ring buffer latency measurement techniques
- Sample rate conversion handling
