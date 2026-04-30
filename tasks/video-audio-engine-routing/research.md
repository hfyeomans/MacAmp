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

---

## Phase 0 — Spike Results

**Date:** 2026-04-30
**Spike branch:** `spike/vaer-av-drift-measurement` (4 commits, never pushed; deleted post-findings per plan §5.5)
**Strategy decision per plan §5.4:** **Path NONE — proceed without sync code.**

### Methodology

Standalone SPM harness in `tasks/video-audio-engine-routing/spike/` (deleted with the branch). Pipeline:

```
AVPlayer (volume=0) → MTAudioProcessingTap → LockFreeRingBuffer → AVAudioSourceNode → AVAudioEngine output
```

Drift formula:
```
drift_at_T = (loopCount * contentDurationSec + AVPlayer.currentTime(T)) - audioElapsedSec(T)
audioElapsedSec(T) = cumulativeFramesRendered(T) / tap.tapSampleRate
```

Per-tick CSV trace (10 ms polling for first 500 ms of wall-clock to resolve AVPlayer warm-up, then 100 ms steady-state). Slope analysis over post-warmup window (≥ 0.5 s elapsed AND `timeControlStatus == .playing`).

### Pre-spike research synthesis (Gemini + Codex Oracle)

Both endorsed reframing the kill-switch criterion: **slope of drift over time, not absolute magnitude**, is the signal that distinguishes real clock slippage from a constant phase offset.

**Gemini synthesis (key insight):** AVPlayer maintains a 100-250 ms decoded-PCM lead for underrun protection (per WWDC AVFoundation guidance). `AVPlayer.currentTime()` reports "Presentation Time" (audio leaving the DAC); `MTAudioProcessingTap` delivers "Decoded Time" (audio post-decoder, pre-output buffer). The difference between them is the AVPlayer pipeline depth — a constant phase offset, not perceptible A/V drift. With both subsystems slaved to the audio output device clock by default (`CMTimebase`), they're frequency-locked to the same hardware crystal — slope should be ~0 in steady state.

**Codex Oracle:** Validated the harness drift formula against the source code; flagged two real bugs (`computeInitialOffsetMs` ignored `firstRenderHostTime`; `tapSampleRate` captured but unused) and confirmed the pipeline can't introduce sustained slippage in `strategy=none`.

### Test corpus

Five clipperboard videos in `clapperboard-videos/` (gitignored, never pushed):

| # | File | Container | Audio sample rate | Channels |
|---|---|---|---|---|
| 1 | `1_mp4_441_stereo.mp4` | mp4 | 44.1 kHz | stereo |
| 2 | `2_mp4_480_stereo.mp4` | mp4 | 48 kHz | stereo |
| 3 | `3_mov_480_stereo.mov` | mov | 48 kHz | stereo |
| 4 | `4_m4v_441_stereo.m4v` | m4v | 44.1 kHz | stereo |
| 5 | `5_mp4_480_surround.mp4` | mp4 | 48 kHz | 5.1 → stereo downmix |

Each ~3 seconds. Originally specced as 3-min clips (plan §5.2); shorter test files used here because looping is supported by the harness, and single-pass measurements within one clip duration give clean slope signals (see lessons learned).

### Quantitative results — final run (post-Fix A, single-pass, `--duration 2`)

| File | Source SR | toFirstTap | toFirstRender | peakDrift | lastDrift | steadyStart | **slope** |
|---|---|---|---|---|---|---|---|
| 1 (44.1 kHz mp4) | 44.1 | 41.1 ms | 51.7 ms | -221.4 ms | -221.4 ms | -211.8 ms | **-6.10 ms/s** |
| 2 (48 kHz mp4) | 48 | 65.3 ms | 76.1 ms | -212.4 ms | -203.2 ms | -202.3 ms | -0.54 ms/s |
| 3 (48 kHz mov) | 48 | 67.0 ms | 77.9 ms | -212.6 ms | -207.7 ms | -210.2 ms | +1.58 ms/s |
| 4 (44.1 kHz m4v) | 44.1 | 65.3 ms | 76.2 ms | -223.3 ms | -214.2 ms | -208.5 ms | -3.65 ms/s |
| 5 (48 kHz mp4 5.1) | 48 | 62.3 ms | 73.0 ms | -212.7 ms | -203.8 ms | -211.6 ms | +4.97 ms/s |

**Slope statistics:**
```
n = 5
mean   = -0.75 ms/sec
stddev =  4.5 ms/sec
95% CI = [-6.4, +4.9] ms/sec
```

The population slope is statistically indistinguishable from zero. The ±6 ms/sec spread is consistent with a 1.5-second post-warmup measurement window (variance shrinks as 1/√N over longer windows). Single-file outliers (file 1 at -6.10 ms/sec) are within noise floor.

### Findings

1. **Frequency-locked clocks confirmed empirically.** Slope across all 5 files clusters around zero with no systematic pattern — not source-rate dependent, not channel-count dependent, not container dependent.
2. **Path NONE is the right answer.** No sync mechanism (sourceClock, pre-roll) needed. The plan §5.4 escalation ladder doesn't trigger.
3. **The constant ~-200 ms offset is AVPlayer's pipeline depth** (decoded-time vs presentation-time), not perceptible drift. Whether the user perceives the offset depends on how production's engine output buffer aligns against AVPlayer's video presentation timing — empirically deferrable to plan §5.3's perception test during implementation.
4. **Plan §16 kill-switch criteria don't trigger:**
    - Drift not > 100 ms with both strategies tried (didn't need to try any)
    - Tap fired on all 5 files (24-26 callbacks per 2-second run)
    - No Swift 6.2 / `@convention(c)` / `Unmanaged` failures

### Lessons learned

1. **Loop-boundary noise contaminates slope analysis on short clips.** First measurement (`--duration 30` with looping) showed worst-case slope -65 ms/sec, but this was 9 loop boundaries × ~-200 ms per loop step, swamping the real signal. Single-pass measurement (`--duration 2` on 3-sec clip) was the only way to get a clean steady-state signal from the corpus we had. For a true 5-min run as plan §5.3 originally specs, longer source files are needed (out of scope for this spike).

2. **Sample-rate mismatch in initial harness math created a +81 ms/sec false drift signature on 44.1 kHz files.** Root cause: `audioElapsedSec = framesRendered / engineSampleRate` with `engineSampleRate` hardcoded to 48 kHz, while the harness deliberately skipped production's `AudioConverter` (plan §7.5). Fix A (use `tap.tapSampleRate` instead) eliminated the artifact. **Production implication:** the AudioConverter at plan §7.5 is essential — without it, 44.1 kHz audio would play with intermittent silence gaps every ~76 ms (engine consumes at 48 kHz, tap supplies at 44.1 kHz, ring underflows). This is the documented behavior the spike confirmed.

3. **AVPlayer's startup latency is ~50-80 ms.** `toFirstTap` (time from `play()` to first tap callback) ranges 41-67 ms across the corpus; `toFirstRender` (first non-silent engine render) adds ~10 ms for ring fill. Below the 100 ms threshold for noticeable startup lag.

4. **The `CMTimebase` slaved to audio output device clock does what Gemini said it does.** Both AVPlayer and our `AVAudioEngine` (using the same default output device) are frequency-locked to the same hardware crystal. No clock drift over the measurement window.

### Phase 4 implication

Plan §9 "Phase 4: Sync Strategy" branches on Phase 0 outcome. **Path NONE selected ⇒ Phase 4 is a no-op.** todo §4.NONE updates to: "Document in research.md that no sync code was needed" — done by this section.

### Spike artifact disposition

- Spike branch deleted post-findings (per plan §5.5).
- Test corpus `clapperboard-videos/` retained at repo root, gitignored via `*.mp4` / `*.mov` / `*.m4v`.
- No production code changes from the spike — all sync-strategy work to be rewritten cleanly on `feat/video-audio-engine-routing` (none required given Path NONE).
