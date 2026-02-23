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

## Deep Research System Findings (2026-02-22)

Full document: `tasks/_context/deep-research-avplayer-bridge.md`

### Definitive Rejections (All Alternative Approaches Exhausted)

| Approach | Reason for Rejection | Source |
|----------|---------------------|--------|
| CoreAudio Process Tap (same-process) | Feedback loop unsolvable without XPC helper or virtual audio driver | Deep research §2, §3 |
| CoreAudio Process Tap (XPC helper) | Massive architectural overhead, sandbox compliance challenges | Deep research §3 |
| CoreAudio Process Tap (device segregation) | Requires user to install 3rd-party virtual audio driver | Deep research §3 |
| MTAudioProcessingTap (streams) | Callbacks never fire for HLS/streaming content | Deep research §6, our testing |
| AVSampleBufferAudioRenderer | Outputs directly to hardware HAL, cannot intercept PCM | Deep research Appendix |
| AudioUnit render callback hijacking | AVPlayer renders out-of-process (coreaudiod). PAC prevents pointer modification on Apple Silicon | Deep research §5 |
| ScreenCaptureKit | High latency, user permission friction | Prior research |

### Validated Architecture (Custom Decode Pipeline)

The deep research Appendix ("Coding Agent Blueprint") independently arrives at the exact same architecture:

```
Step 1: URLSession data tasks (HTTP transport)
Step 2: AudioFileStreamOpen + AudioFileStreamParseBytes → AudioConverter → Float32 PCM
Step 3: LockFreeRingBuffer (existing SPSC, 4096 frames) as bridge
Step 4: AVAudioSourceNode render block (existing, real-time consumer)
Step 5: AVAudioEngine graph (EQ + Viz + Balance)
```

### New Findings to Incorporate

#### 1. Audio Workgroup Integration (os_workgroup)

The decode thread should join the AVAudioEngine's audio workgroup to prevent priority inversion on Apple Silicon:

```swift
// Retrieve workgroup from engine output node
let workgroup = audioEngine.outputNode.auAudioUnit.osWorkgroup

// In decode thread (producer):
os_workgroup_join_self(workgroup)
```

**Why:** On M-series chips, the hardware performance controller schedules workgroup-linked threads at the same priority as the audio IO thread. Without this, the decode thread risks CPU core parking under load, starving the ring buffer.

**Priority:** MEDIUM — improves stability under CPU pressure, not required for basic functionality.

#### 2. macOS 26 Passthrough Risk (AVAudioContentSource_Passthrough)

macOS 26 introduces `AVAudioContentSource_Passthrough = 42` which allows apps to request raw bitstream passthrough (Dolby Digital, DTS:X) bypassing the system mixer. If our pipeline ever receives non-PCM frames, the ring buffer would fill with encoded data that AVAudioEngine can't process (white noise or crash).

**Mitigation:** Explicitly lock output format when configuring AudioConverter:
```swift
// Always output Float32 interleaved stereo PCM
// Never allow passthrough of encoded formats
outputASBD.mFormatID = kAudioFormatLinearPCM
outputASBD.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
```

**Priority:** LOW — only affects macOS 26 with HDMI/optical output devices. Internet radio streams are always PCM-decodable.

#### 3. Open-Source Reference Implementations

- **AudioCap** (github.com/insidegui/AudioCap) — Process tap implementation, confirms aggregate device requirement. No same-process feedback loop solution.
- **AudioTee** (stronglytyped.uk) — Command-line process tap, avoids feedback by having no audio output. Confirms entitlement requirements.
- **Chris' Coding Blog** (chritto.wordpress.com) — MTAudioProcessingTap Swift implementation, confirms HLS limitation.

#### 4. AVPlayer Render Pipeline Limits

Apple limits concurrent AVPlayer render pipelines to exactly 4 per application. A 5th AVPlayer causes `AVStatusFailed` crash. Not directly relevant (we're removing AVPlayer for streams) but documents why AVPlayer is constrained.

#### 5. Partial Ring Buffer Writes

Deep research emphasizes: "The SPSC enqueue mechanism must be mathematically robust enough to handle partial ring buffer writes, modulo arithmetic for buffer wrapping, and varying frame deliveries." Our LockFreeRingBuffer already handles this via its `write(from:frameCount:)` API with atomic head/tail pointers.

### Updated Open Questions

1. ~~Network jitter buffer~~ — Deep research doesn't flag this as critical. AudioFileStream + AudioConverter handle buffering internally. LockFreeRingBuffer's 4096 frames (~85ms) should suffice.
2. **os_workgroup integration** — Add to plan as optimization step. Not blocking for initial implementation.
3. **macOS 26 passthrough guard** — Add format validation in AudioConverter output configuration.
4. **HLS via AudioFileStream** — Deep research says "individual .ts/.aac segments from parsed HLS .m3u8 playlists" can be fed to AudioFileStream. This means HLS IS possible without AVAssetReader — just need an M3U8 playlist parser and segment downloader. Defer to Phase 2.

## Sources

- Oracle (gpt-5.3-codex, xhigh): Custom decode pipeline design, 2026-02-22
- Gemini: Winamp unified pipeline architecture, 2026-02-22
- Deep research system: Full analysis (46 citations), 2026-02-22 — `tasks/_context/deep-research-avplayer-bridge.md`
- Apple SDK: AudioFileStream.h, AudioConverter.h headers
- Open source: AudioCap, AudioTee, Chris' Coding Blog (MTAudioProcessingTap)
- Winamp SDK: In_Module interface documentation
- Webamp: elementSource.ts (createMediaElementSource pattern)
- Lessons learned: `tasks/_context/lessons-dual-backend-dead-end.md`
- Prior research: `tasks/internet-streaming-volume-control/research.md`
