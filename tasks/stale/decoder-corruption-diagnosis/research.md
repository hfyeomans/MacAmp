# Research: Decoder Corruption Diagnosis

Date: 2026-03-14

## Scope
- `MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift`
- `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift`
- `MacAmpApp/Audio/Streaming/AudioFileStreamParser.swift`
- `MacAmpApp/Audio/Streaming/ICYFramer.swift`
- `MacAmpApp/Audio/LockFreeRingBuffer.swift`
- Apple SDK header: `AudioConverter.h`

## User-Confirmed Runtime Facts
- Render-block sine test is clean, so downstream engine/output path is likely good.
- Real stream audio is warped/corrupted with partial lyrics.
- Audio stops after 3-5 minutes and the ring buffer drains.
- Warp persists across output sample-rate changes.

## Highest-Value Conclusion
- The fastest path is not broad refactoring.
- The fastest path is deterministic isolation of decoder output before it reaches the ring buffer.
- Of the user’s listed options, **A is best**.
- Better than A alone: **Option D = offline capture/replay harness**:
  - capture a short raw HTTP byte sequence plus headers
  - replay it deterministically through `ICYFramer -> AudioFileStreamParser -> AudioConverterDecoder`
  - dump packet metadata and decoded PCM
  - compare PCM against a trusted decoder

## Apple Callback Contract Findings
From `AudioConverter.h`:
- `ioNumberDataPackets` is the minimum requested on entry, actual packets provided on exit.
- The callback may return fewer packets than requested.
- The callback must provide a whole number of packets.
- For compressed input, packet descriptions are required for every packet provided.
- The callback must keep the provided buffer valid until it is called again.

## Assessment of Specific Suspicions

### 1) Packet splitting with `mStartOffset = 0`
- Likely correct.
- After slicing each packet’s bytes into a new `Data`, the packet starts at offset 0 within that new buffer.
- This is not the leading suspect.

### 2) Partial packet consumption causing data loss
- Lower probability in the current single-packet callback design.
- The converter asks for packets, not arbitrary byte fragments.
- The bigger historical risk was batching multiple packets into one callback supply and then losing the remainder.
- The current packet-splitting approach was specifically added to avoid that class of bug.

### 3) `retainedBuffers` causing stale reads
- Not a live cause in the current revision.
- `retainedBuffers` exists as dead state in `AudioConverterDecoder`, but the decode path does not append to or read from it.
- It reflects churn, not current behavior.

### 4) `noMoreInputData` vs `noErr`
- Unlikely to explain corrupted/warped samples.
- Treating custom `ndta` as “return any frames already produced, else stop for now” is reasonable.
- This area can affect buffering cadence, but not usually PCM corruption.

### 5) `ICYFramer` miscounting bytes and leaking metadata into audio
- Plausible in theory and worth falsifying quickly.
- If one metadata byte leaks into the compressed stream at each interval, MP3 sync can be destabilized and produce persistent corruption independent of output sample rate.
- The framer logic looks structurally reasonable, so I rank it below the converter/input-callback path, but it should be tested in the offline harness.

## Additional Observations
- `AudioConverterDecoder.init(... outputSampleRate:)` currently accepts an output sample-rate parameter but ignores it and uses the input format’s sample rate instead.
- `StreamDecodePipeline.handleFormatAvailable()` passes a hard-coded `48000` output rate into the decoder constructor, but the decoder does not use it.
- This is probably not the corruption source, but it does make the codebase harder to reason about while debugging.

## Recommendation
- Choose **A now**.
- Prefer **D as the actual working method**:
  1. capture a deterministic byte sample from the live stream
  2. run it offline through the framer/parser/converter
  3. dump decoded PCM to file
  4. compare that PCM to a trusted decoder output

## Why Not B or C First
- **B** is useful after you have a minimal failing fixture, but it is slower and more diffuse.
- **C** changes too many variables at once and can erase the bug rather than explain it.
