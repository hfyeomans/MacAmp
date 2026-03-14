# Research — AudioConverter Warping Diagnosis

Date: 2026-03-14
Scope: `AudioConverterDecoder`, `StreamDecodePipeline`, `AudioFileStreamParser`, `ICYFramer`, `LockFreeRingBuffer`

## Confirmed Findings From Source

1. `AudioConverterDecoder.init(inputFormat:outputSampleRate:magicCookie:)` ignores `outputSampleRate` and always sets `outputFormat.mSampleRate` to `inputFormat.mSampleRate`.
- File: `MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift` lines ~82-91
- Implication: experiments toggling decoder output rate may not actually change converter output rate.

2. `retainedBuffers` is declared but unused.
- File: `MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift` line ~58
- Current callback behavior keeps the current input buffer alive until next callback, which matches Apple’s documented contract.

3. Packet splitting sets `mStartOffset = 0` for per-packet `Data` slices.
- File: `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` lines ~546-556
- This is correct for individually sliced packet payloads.

4. ICY framing algorithm itself appears state-correct for metaint framing.
- File: `MacAmpApp/Audio/Streaming/ICYFramer.swift`
- Risk area is not the state machine math; risk is whether framer gets configured early enough and whether `icy-metaint` parsing is robust.

5. `extractICYMetaInt` only accepts header values castable to `String`.
- File: `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` lines ~274-283
- If Foundation provides non-String values, metaint may be treated as 0 and metadata would leak into parser.

6. Data/response ordering race is plausible.
- `didReceive response` hops to `@MainActor` before calling `configureFramer(metaInterval:)`.
- `didReceive data` enqueues directly to decode queue.
- Early data can be parsed before framer configuration, depending on scheduling.

## API Contract Check (AudioConverter.h)

From Apple header (`AudioToolbox.framework/Headers/AudioConverter.h`, lines ~749-805):
- Converter requests minimum packets via `ioNumberDataPackets`.
- Callback may return fewer packets; converter will call again.
- Callback must provide whole packets and packet descriptions for variable packet formats.
- Callback-owned input memory must remain valid until callback is called again.

Implications:
- Returning one packet at a time is legal.
- Freeing previous input buffer at start of next callback is legal.
- Unused `retainedBuffers` is likely not primary corruption source by itself.

## Most Plausible Root-Cause Candidates

1. ICY metadata leakage into parser (header parse robustness and/or response→data ordering race).
2. Input packet accounting mismatch under real stream conditions (descriptions missing/incorrect on some callbacks; packet count fallback path).
3. Less likely: AudioConverter callback memory-lifetime bug (current behavior matches documented contract).
