## Scope

Update the streaming architecture docs so they no longer imply the ring buffer or decoder is fixed at 44.1 kHz, and add explicit frame-capacity-to-duration examples.

## Findings

- `LockFreeRingBuffer` is frame-based and channel-based, not sample-rate-based.
- The streaming pipeline detects sample rate from `AudioFileStreamParser` and propagates it through `AudioConverterDecoder` and `AudioEngineController`.
- `44100` appears in docs both as stale wording and as an example for converting `32768` frames into seconds.
- Fixed-size frame buffers represent different real-time durations at different sample rates:
  - `32768 / 44100 ≈ 0.743 s`
  - `32768 / 48000 ≈ 0.683 s`
  - `32768 / 96000 ≈ 0.341 s`

## Target docs

- `docs/MACAMP_ARCHITECTURE_GUIDE.md`
- `docs/IMPLEMENTATION_PATTERNS.md`
