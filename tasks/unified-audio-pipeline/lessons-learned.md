# Lessons Learned: Unified Audio Pipeline (2026-03-14)

> **Purpose:** Document debugging techniques, root causes, and architectural lessons
> from implementing the custom stream decode pipeline. These should inform future
> audio work and be captured in BUILDING_RETRO_MACOS_APPS_SKILL.md.

---

## Lesson 1: Sine Wave Diagnostic for Engine Path Isolation

**Technique:** Replace the render block's ring buffer read with a 440Hz sine wave generator.
If the tone is clean, the engine path (format, SRC, graph connections) is correct.
If warped, the engine setup is wrong.

**When to use:** Any time audio output is corrupted — immediately isolates whether the
problem is in the engine/output path or upstream in the data production.

**Result:** Clean sine wave proved engine format, SRC (44100→48000Hz), graph connections,
and interleaved→non-interleaved conversion all work correctly. Saved hours of debugging
the wrong layer.

**Key insight:** Always test from the output backward, not from the input forward.

---

## Lesson 2: Duplicate State Initialization Causes ICY Metadata Corruption

**Bug:** `configureFramer()` was called twice per stream connection:
1. From `onResponse` callback (immediate, delegate queue → decode queue)
2. From `handleHTTPResponse` (delayed, MainActor → decode queue)

The second call reset the framer's `audioByteCount` to 0 after data had already been
processed, throwing off ICY metadata boundary alignment for the entire stream.

**Symptom:** High-pitched "warping" sound with partial lyrics audible. The corruption
was periodic (at every ICY metadata boundary = every 8192 audio bytes).

**How it was masked:** Diagnostic file writes (PCM/MP3 dump) added latency to the
decode queue, changing the timing so the second `configureFramer` arrived before
significant data was processed. Removing diagnostics brought the warping back.

**Prevention:**
- When fixing a race condition by adding an early call, REMOVE the original late call
- Search for ALL call sites of any function you're moving between isolation contexts
- `grep -r "configureFramer"` would have caught this immediately

---

## Lesson 3: PCM Statistical Analysis Can Miss Audible Corruption

**Observation:** PCM data that passes all statistical checks (no NaN, valid amplitude
range, smooth RMS, no zero blocks) can still sound completely wrong.

**Why:** ICY metadata bytes decoded as audio produce valid Float32 values in the
normal amplitude range. They just represent the wrong signal — garbled noise mixed
with real audio.

**Better approach:** Write decoder output to a WAV file and LISTEN to it.
Or write pre-decoder data to an MP3 file and play it separately.
Human ears detect corruption that statistics miss.

---

## Lesson 4: AVAudioEngine Graph Rewiring Requires Explicit Formats

**Bug:** After stream bridge (with explicit non-interleaved format), reconnecting
with `format: nil` caused EQ node format stickiness → error -10868.

**Root cause:** `format: nil` means "use the previously negotiated format." After
the stream bridge set an explicit format, the EQ node retained that format state.
When rewiring for local file playback, the nil-format connection tried to use the
stream's format, which was incompatible.

**Fix:** Always use explicit `AVAudioFormat` for graph connections:
```swift
let graphFormat = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: outputNode.inputFormat(forBus: 0).sampleRate,
    channels: fileChannels,
    interleaved: false
)!
```

**Also:** Use `disconnectNodeInput(eqNode, bus: 0)` to clear stale input connections.
`disconnectNodeOutput` alone doesn't clear the receiving node's input format cache.

**Also:** Don't use `audioEngine.reset()` for format cleanup — it's not a format scrub.
Just disconnect, reconnect with explicit format, and prepare.

---

## Lesson 5: Bridge Deactivation Must Be in ALL Playback Paths

**Bug:** Direct playback paths (drag-and-drop, playlist double-click) bypass
PlaybackCoordinator and call AudioPlayer.playTrack() directly. If the stream
bridge was active, the engine graph still had the streamSourceNode attached,
causing -10868 when trying to start with the playerNode path.

**Fix:** Add `deactivateStreamBridge()` at the start of `rewireForCurrentFile()` —
this is the single choke point for ALL local file playback paths.

---

## Lesson 6: AudioConverter Input Buffer Lifetime Contract

**Bug:** The input callback freed the previous buffer at the START of each
`decode()` call via `prepareInputBuffer()`. Apple's contract requires buffers
to remain valid until the NEXT callback invocation.

**Fix:** The input callback itself calls `advanceToNextPacket()` which frees the
PREVIOUS buffer (safe because the converter is calling us again = done with it)
and provides the NEXT packet's data.

**Key insight:** AudioConverter's `FillComplexBuffer` calls the input callback
repeatedly within one invocation. The callback must manage its own packet queue.

---

## Lesson 7: Packet Batching Causes Data Loss with Small Output Buffers

**Bug:** AudioFileStream delivers multiple packets in one callback (concatenated
data buffer with per-packet descriptions). Enqueuing the entire batch as one
entry meant the input callback provided ALL packets at once. When the 4096-frame
output buffer filled after ~3.5 MP3 frames, the remaining packets were lost.

**Fix:** Split batched packets into individual queue entries:
```swift
for desc in descriptions {
    let packetData = data[offset..<(offset + size)]
    decoder.enqueue(data: Data(packetData), descriptions: [singleDesc])
}
```

---

## Lesson 8: M3U/PLS Playlist URLs Must Be Resolved Before Streaming

**Bug:** AVPlayer handles M3U/PLS playlist URLs natively. Our custom pipeline
tried to stream the playlist file itself as audio → URLSession downloaded the
tiny text file → `didCompleteWithError` fired (no error) → "Stream ended."

**Fix:** Check URL extension before streaming. If `.m3u`, `.m3u8`, or `.pls`,
download and parse first, then stream the resolved audio URL.

---

## Lesson 9: Engine Start Must Be a Hard Gate

**Bug:** When `audioEngine.start()` failed (e.g., -10868), the code continued
to install the visualizer tap and call `playerNode.play()`. This produced
confusing error cascades: "Tap installed" followed by "Engine is not running."

**Fix:** `startEngineIfNeeded()` returns `Bool`. `play()` aborts early if false:
```swift
guard startEngineIfNeeded() else {
    AppLog.error(.audio, "Play aborted — engine failed to start")
    return
}
```

---

## Lesson 10: Diagnostic Code Can Mask Timing Bugs

**Observation:** Adding file I/O (PCM dump, MP3 dump) to the decode queue
accidentally fixed the stream warping by adding latency. This delayed the
second `configureFramer` call enough that it arrived before significant data
was processed.

**Key insight:** When a bug disappears with logging/diagnostics added and
reappears when removed, the bug is timing-related. Look for:
- Race conditions between threads/queues
- Duplicate state initialization
- Order-dependent operations crossing isolation boundaries

---

## Debugging Methodology (Recommended Order)

1. **Sine wave test** — isolates engine path vs data production
2. **Raw data dump** — capture pre-decoder data (MP3) and post-decoder data (PCM)
3. **Listen to dumps** — human ears catch what statistics miss
4. **Check for duplicate calls** — `grep -r "functionName"` across entire codebase
5. **Check isolation crossings** — any function called from multiple isolation contexts?
6. **Add/remove diagnostics** — if bug changes with logging, it's timing-related
7. **Oracle consultation** — share actual code, not descriptions

---

## Architecture Notes for Future Reference

### Stream Decode Chain
```
URLSession (delegate queue)
    → SessionDelegateProxy (onResponse configures framer on decode queue)
    → SessionDelegateProxy (onData dispatches to DecodeContext)

DecodeContext (serial decode queue, @unchecked Sendable)
    → ICYFramer.consume() → .audio/.metadata chunks
    → AudioFileStreamParser.parse() → onPackets callback
    → handlePackets: split batch → individual enqueue
    → AudioConverterDecoder.decode() → Float32 PCM
    → LockFreeRingBuffer.write()

AVAudioSourceNode (real-time audio thread)
    → render block reads from LockFreeRingBuffer
    → interleaved Float32 at stream sample rate (44100Hz)
    → engine handles SRC to device rate (48000Hz)
```

### Key Invariants
- ICYFramer.configure() called EXACTLY ONCE per stream (from delegate queue)
- AudioConverterDispose BEFORE AudioFileStreamClose
- deactivateStreamBridge in rewireForCurrentFile (catches all local play paths)
- Explicit format (not nil) for all graph connections after bridge was active
- Ring buffer: 32768 frames (~743ms), prebuffer: 16384 frames (~371ms)
