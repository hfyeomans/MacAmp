# Research: Stream Audio Warping Recommendations

Date: 2026-03-14

## Scope
- `MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift`
- `MacAmpApp/Audio/AudioPlayer.swift`
- `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift`
- `MacAmpApp/Audio/LockFreeRingBuffer.swift`
- Local Apple SDK headers for `AVAudioSourceNode`

## User-Provided Facts
- Hardware output sample rate: 48000 Hz
- Stream sample rate: 44100 Hz
- Decoder outputs Float32 PCM at 44100 Hz
- Ring buffer stores decoded frames at 44100 Hz
- `AVAudioSourceNode` block format is 44100 Hz interleaved stereo
- Graph connection format to EQ is 48000 Hz non-interleaved stereo
- Audible symptom: high-pitched warping with partial lyrics

## Primary Source Findings

### AVAudioSourceNode contract
From Apple header:
- `/Applications/Xcode.app/.../AVFAudio.framework/.../AVAudioSourceNode.h`
- `initWithFormat:renderBlock:` explicitly says:
  - output bus format is set from the connection format
  - block format is the format passed to `initWithFormat`
  - different block/output formats are supported
  - supported conversions include sample rate, bit depth, and interleaving

This means the current 44.1k block format + 48k graph format is conceptually valid.

### Consequence
- The correct architectural expectation is that `AVAudioSourceNode`/engine performs the linear PCM conversion between:
  - block format: 44.1k interleaved stereo
  - graph format: 48k non-interleaved stereo
- Therefore a persistent pitch-up artifact is not, by itself, proof that the `AVAudioSourceNode` API cannot do SRC.

## Interpretation

### Most likely answer to A vs B
- **B is the correct model.**
- Keep source PCM at the stream sample rate and let `AVAudioSourceNode`/engine convert to the graph/device format.
- **A is optional simplification, not the primary correction.**

### Why A is not the first recommendation
- It couples the decoder to the current hardware output rate.
- It requires plumbing device rate into the decode pipeline.
- It requires converter rebuilds and ring-buffer flushes whenever the output device/sample rate changes.
- It weakens the source-agnostic design of the unified pipeline.

## FrameCount Question
- Apple’s API contract implies the render block operates in the block format supplied to `initWithFormat:renderBlock:`, not blindly in downstream device-rate frames.
- Therefore the render block should not be assumed to consume `48000/44100` more frames just because the hardware is 48k.
- Overconsumption remains a thing to verify with instrumentation, but it is not the expected contract.

## Other Likely Problem Areas

### 1) Decoder-side corruption is still a plausible culprit
- `AudioConverterDecoder` feeds compressed packets through a custom callback path.
- If packet grouping, packet descriptions, or callback accounting are slightly wrong, the output can sound warped/garbled while remaining partially intelligible.
- This is a better fit than “AVAudioSourceNode simply refused to SRC.”

### 2) Ring-buffer starvation or bursty producer timing can mimic rate issues
- If the producer cadence is unstable, the listener can hear warbling artifacts that resemble clock mismatch.
- `StreamDecodePipeline` already has telemetry hooks; these should be used to confirm whether the ring buffer drains steadily or oscillates into underruns.

### 3) Current evidence does not show a source-node format declaration bug
- `AudioPlayer.activateStreamBridge()` creates:
  - source block format: 44.1k Float32 interleaved stereo
  - graph format: device-rate Float32 non-interleaved stereo
- That matches Apple’s documented supported conversion path.

## Recommendation Direction
- Recommend **against** changing the decoder to device-rate PCM as the first move.
- Recommend treating the current warp as evidence of either:
  - wrong assumptions about actual render-block demand, or
  - bad PCM production / packet accounting upstream.
- Recommend adding focused instrumentation before changing architecture:
  - measured frames requested/sec in render block
  - measured frames written/sec by decoder
  - ring buffer fill, underruns, overruns
  - actual buffer list layout seen by the render block
