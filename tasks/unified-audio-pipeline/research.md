# Research: Unified Audio Pipeline (Custom Stream Decode)

> **Purpose:** Consolidated research for replacing AVPlayer with a custom decode pipeline for internet radio streams.

---

## Problem Statement

MacAmp uses a dual audio backend: AVAudioEngine for local files, AVPlayer for internet radio. AVPlayer is a black-box player with no access to decoded PCM. This means streams cannot use EQ, visualization, or balance.

**Goal:** Replace AVPlayer with a custom decoder that outputs raw PCM Float32, feeding the existing AVAudioEngine graph via LockFreeRingBuffer + AVAudioSourceNode.

## Failed Approaches (Documented Elsewhere)

1. **MTAudioProcessingTap** — DEAD: callbacks never fire for streaming AVPlayerItems (Apple QA1716)
2. **CoreAudio Process Tap** — REJECTED: feedback loop in same-process capture, unreliable device isolation
3. **ScreenCaptureKit** — REJECTED: high latency, user permission friction

See: `tasks/_context/lessons-dual-backend-dead-end.md` for full analysis.

## Recommended Architecture

### Winamp Model (Proven for 25+ Years)

```
ANY source → Input Plugin (decode to PCM) → EQ → DSP → Visualizer → Output
```

Winamp's `in_mp3.dll` decoded BOTH local files AND SHOUTcast streams to the same PCM format. The core never knew the source type. MacAmp should do the same.

### Target Architecture

```
HTTP stream → URLSession → ICYFramer → AudioFileStream → AudioConverter → Float32 PCM
    → LockFreeRingBuffer → AVAudioSourceNode → AVAudioEngine (EQ + Viz + Balance) → Speakers
```

### Oracle Assessment (gpt-5.3-codex, xhigh, 2026-02-22)

**Recommended approach:** AudioFileStream + AudioConverter pipeline

- AudioFileStream: streaming parser for MP3/AAC progressive HTTP streams
- AudioConverter: codec conversion to Float32 interleaved stereo PCM
- ICY metadata: parsed from HTTP byte stream before reaching audio parser
- Threading: URLSession delegate → decode serial queue → ring buffer write
- AVAssetReader: NOT recommended for live/infinite streams
- AVSampleBufferAudioRenderer: renders to hardware, no PCM intercept API
- HLS: defer to separate implementation phase

### Deep Research System Assessment (User's External Tool, 2026-02-22)

Recommended AVSampleBufferAudioRenderer + AVSampleBufferRenderSynchronizer as the custom engine, with AVAssetReader for HLS chunks. This approach uses Apple's HLS stack for transport but intercepts decoded CMSampleBuffers before rendering.

**Key difference from Oracle:** Deep research system recommends AVSampleBufferAudioRenderer for clock synchronization. Oracle recommends pure AudioToolbox (AudioFileStream + AudioConverter) for simplicity.

**Resolution:** Start with AudioFileStream + AudioConverter (simpler, works for progressive streams). Add AVSampleBufferAudioRenderer path for HLS if needed later.

## Component Design

### 1. ICYFramer

**Purpose:** Strip ICY metadata from HTTP byte stream before audio data reaches parser.

**How ICY Protocol Works:**
1. Client sends `Icy-MetaData: 1` in HTTP request headers
2. Server responds with `icy-metaint: N` (metadata interval in bytes)
3. After every N audio bytes, server inserts: 1 length byte (L), then L*16 metadata bytes
4. Metadata format: `StreamTitle='Artist - Title';StreamUrl='...';`

**Implementation:**
```swift
struct ICYFramer {
    private var metaInterval: Int = 0  // from icy-metaint header
    private var audioByteCount: Int = 0
    private var metaBytesRemaining: Int = 0
    private var metaBuffer = Data()

    enum Chunk {
        case audio(Data)
        case metadata(ICYMetadata)
    }

    struct ICYMetadata {
        let title: String?
        let artist: String?
    }

    mutating func configure(metaInterval: Int) { ... }
    mutating func consume(_ data: Data) -> [Chunk] { ... }
}
```

### 2. AudioFileStreamParser

**Purpose:** Parse compressed audio packets from progressive HTTP streams.

**Apple API:** `AudioFileStream` (AudioToolbox, macOS 10.5+)

**Key functions:**
- `AudioFileStreamOpen()` — create parser with property/packet callbacks
- `AudioFileStreamParseBytes()` — feed bytes, triggers callbacks
- `AudioFileStreamClose()` — cleanup

**Callbacks:**
- Property listener: `kAudioFileStreamProperty_DataFormat` (ASBD), `kAudioFileStreamProperty_MagicCookie` (for AAC), `kAudioFileStreamProperty_ReadyToProducePackets`
- Packets callback: receives compressed audio packets + packet descriptions

**Supported formats:** MP3, AAC, AIFF, WAV, CAF. **NOT** OGG (requires libvorbis).

**Format hint:** Can provide `kAudioFileMP3Type` or `kAudioFileAAC_ADTSType` to help parser. Or use `0` for auto-detection.

### 3. AudioConverterDecoder

**Purpose:** Decode compressed audio packets to Float32 interleaved stereo PCM.

**Apple API:** `AudioConverter` (AudioToolbox, macOS 10.1+)

**Key functions:**
- `AudioConverterNew()` — create converter with input/output ASBDs
- `AudioConverterFillComplexBuffer()` — decode packets via input callback
- `AudioConverterSetProperty()` — set magic cookie, quality settings
- `AudioConverterDispose()` — cleanup

**Input format:** From AudioFileStream's DataFormat property (compressed ASBD)
**Output format:** Float32, interleaved, stereo, 44100 Hz (normalized)

**Input data callback pattern:**
```swift
// AudioConverterFillComplexBuffer calls this when it needs more input
let inputCallback: AudioConverterComplexInputDataProc = { converter, ioNumberDataPackets, ioData, outDataPacketDescription, inUserData in
    // Dequeue next compressed packet from packet queue
    // Set ioData to point at packet data
    // Set outDataPacketDescription for variable-rate formats (AAC)
    return noErr  // or eofErr when no more data
}
```

### 4. StreamDecodePipeline

**Purpose:** Orchestrate the full decode chain as a Swift actor.

```swift
actor StreamDecodePipeline {
    private let ringBuffer: LockFreeRingBuffer
    private let decodeQueue = DispatchQueue(label: "macamp.stream.decode")

    private var framer = ICYFramer()
    private var parser: AudioFileStreamParser?
    private var decoder: AudioConverterDecoder?
    private var urlSession: URLSession?

    // Callbacks to StreamPlayer (@MainActor)
    var onStateChange: (@Sendable (StreamState) -> Void)?
    var onFormatReady: (@Sendable (Float64) -> Void)?
    var onMetadata: (@Sendable (ICYFramer.ICYMetadata) -> Void)?

    func start(url: URL) async { ... }
    func pause() { ... }
    func stop() { ... }
}
```

### 5. StreamPlayer (Modified)

**Removes:** AVPlayer, AVPlayerItem, AVPlayerItemMetadataOutput, MTAudioProcessingTap, all loopback tap code
**Adds:** StreamDecodePipeline ownership
**Preserves:** Same public API (play/pause/stop, isPlaying/isBuffering, streamTitle/streamArtist, volume/balance)

## Threading Model

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Main Thread    │     │  Decode Queue    │     │  Audio IO Thread │
│   (@MainActor)   │     │  (serial, bg)    │     │  (real-time)     │
├─────────────────┤     ├──────────────────┤     ├─────────────────┤
│ StreamPlayer     │     │ ICYFramer        │     │ AVAudioSourceNode│
│ PlaybackCoord.   │◄────│ AudioFileStream  │     │ render block     │
│ UI state updates │     │ AudioConverter   │     │ ringBuffer.read()│
│                  │     │ ringBuffer.write()│────►│                  │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

**Key constraint:** Decode queue is NOT real-time. It can allocate, log, and do I/O. Only the AVAudioSourceNode render block is real-time (already handled by existing `makeStreamRenderBlock()`).

## Format Handling

| Stream Type | AudioFileStream Hint | Typical Sample Rate | Channels |
|-------------|---------------------|---------------------|----------|
| MP3 (SHOUTcast) | kAudioFileMP3Type | 44100 Hz | Stereo |
| AAC (Icecast) | kAudioFileAAC_ADTSType | 44100/48000 Hz | Stereo |
| AAC-HE | kAudioFileAAC_ADTSType | 22050/44100 Hz | Stereo |
| OGG Vorbis | Not supported | N/A | N/A |

**Output normalization:** AudioConverter converts all input formats to Float32 interleaved stereo at 44100 Hz. Sample rate conversion and channel upmixing handled natively by AudioConverter.

## macOS Version Compatibility

| API | Min macOS | Notes |
|-----|-----------|-------|
| AudioFileStream | 10.5 | Stable, unchanged for 15+ years |
| AudioConverter | 10.1 | Stable, unchanged for 20+ years |
| URLSession | 10.9 | Modern networking |
| LockFreeRingBuffer | 15.0 | Uses Swift Atomics (our code) |
| AVAudioSourceNode | 10.15 | Consumer side |

**No macOS 26-specific APIs needed.** The entire pipeline works on macOS 15+.

## What We Reuse (No Changes Needed)

| Component | File | Lines | Status |
|-----------|------|-------|--------|
| LockFreeRingBuffer | Audio/LockFreeRingBuffer.swift | ~200 | As-is |
| makeStreamRenderBlock() | Audio/AudioPlayer.swift:610 | ~50 | As-is |
| activateStreamBridge() | Audio/AudioPlayer.swift:662 | ~60 | As-is |
| deactivateStreamBridge() | Audio/AudioPlayer.swift:726 | ~30 | As-is |
| streamSourceNode property | Audio/AudioPlayer.swift | ~5 | As-is |
| isBridgeActive / isEngineRendering | Audio/AudioPlayer.swift | ~5 | As-is |
| Capability flags | Audio/PlaybackCoordinator.swift:92-98 | ~10 | As-is |
| VisualizerView isEngineRendering | Views/VisualizerView.swift | 4 sites | As-is |

## What We Remove

| Component | File | Reason |
|-----------|------|--------|
| LoopbackTapContext | Audio/StreamPlayer.swift:12-34 | MTAudioProcessingTap abandoned |
| 5 tap callbacks | Audio/StreamPlayer.swift:41-160 | MTAudioProcessingTap abandoned |
| attachLoopbackTap() | Audio/StreamPlayer.swift:287-392 | Replaced by pipeline |
| detachLoopbackTap() | Audio/StreamPlayer.swift:394-398 | Replaced by pipeline |
| currentTapRef | Audio/StreamPlayer.swift:212 | No tap |
| attachBridgeTap() | Audio/PlaybackCoordinator.swift:142-159 | Pipeline handles directly |
| bridgeLog() | Audio/StreamPlayer.swift:7-17 | Temporary diagnostic |

## Open Questions (For Plan Review)

1. **Network jitter buffer:** LockFreeRingBuffer is 4096 frames (~85ms). Is this enough for network jitter? May need a separate pre-decode buffer.
2. **Reconnection strategy:** Auto-reconnect on network drops? Exponential backoff?
3. **OGG support:** Defer or add libvorbis dependency?
4. **HLS timeline:** Phase 1 targets progressive only. When to add HLS?
5. **AVPlayer for video:** VideoPlaybackController still uses AVPlayer for video files. No change needed there — video doesn't need EQ/visualization.

## Sources

- Oracle (gpt-5.3-codex, xhigh): Custom decode pipeline design, 2026-02-22
- Gemini: Winamp unified pipeline architecture, 2026-02-22
- Deep research system: AVSampleBufferAudioRenderer recommendation, 2026-02-22
- Apple SDK: AudioFileStream.h, AudioConverter.h headers
- Winamp SDK: In_Module interface documentation
- Webamp: elementSource.ts (createMediaElementSource pattern)
- Lessons learned: `tasks/_context/lessons-dual-backend-dead-end.md`
- Prior research: `tasks/internet-streaming-volume-control/research.md`
