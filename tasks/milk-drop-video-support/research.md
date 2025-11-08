# Research: Milkdrop/Video Support for MacAmp V Button

**Task ID**: milk-drop-video-support
**Research Date**: 2025-11-08
**Researchers**: Claude Code + Gemini CLI + Explore Agents

---

## Executive Summary

### Critical Finding: "V Button" is VISUALIZATION, NOT Video Playback

After comprehensive research of webamp_clone and MilkDrop3, we've determined:

1. **Webamp does NOT support video file playback** (MP4, AVI, MOV, etc.)
2. **The "V" button triggers AUDIO VISUALIZATION** (Milkdrop/Butterchurn)
3. **Milkdrop is an audio visualizer**, not a video player
4. **For MacAmp, we need to decide**: Visualization only, or add video playback?

---

## Part 1: Webamp Implementation Analysis

### 1.1 V Button - Current State

**Location**: `webamp_clone/packages/webamp/js/components/MainWindow/ClutterBar.tsx`

**CRITICAL BUG FOUND**: The V button (`#button-v`) has **NO click handler attached**:

```tsx
<div id="button-v" />
```

**Workaround**: The visualizer canvas itself handles clicks (line 205):
- Component: `Vis.tsx`
- Action: `toggleVisualizerStyle()`
- Cycles: `OSCILLOSCOPE` → `BAR` → `NONE` → repeat

### 1.2 Visualization System Architecture

**Three Built-in Modes**:
1. **Oscilloscope**: Waveform display using `getByteTimeDomainData()`
2. **Bar**: Frequency bars using `getByteFrequencyData()`
3. **None**: No visualization

**Advanced Mode**:
- **Milkdrop** via Butterchurn library (JavaScript port of Winamp's Milkdrop)
- Separate window: `MilkdropWindow` component
- Redux action: `ENABLE_MILKDROP`

### 1.3 Butterchurn Integration (Webamp's Solution)

**NPM Packages**:
- `butterchurn@3.0.0-beta.4` - Core visualization engine
- `butterchurn-presets@3.0.0-beta.4` - 200+ preset library

**Technical Details**:
- **Rendering**: WebGL-based (browser technology)
- **Presets**: Supports `.json` and `.milk` preset files
- **Transitions**: 2.7s default, 5.7s for user presets
- **Security**: `onlyUseWASM: true` flag (hardened)
- **Audio Source**: Web Audio API `AnalyserNode`

**Architecture**:
```
HTMLAudioElement 
  → Web Audio API (AnalyserNode)
    → Butterchurn (WebGL rendering)
      → Canvas element (visualization output)
```

### 1.4 NO Video Playback Support

**Evidence**:
- All media uses `HTMLAudioElement` exclusively
- No video format detection code found
- No `<video>` element usage
- Web Audio API only works with audio streams, not video

**Confirmed**: Open-source Webamp is **audio-only**. The commercial "WebAMP® Media Player" may have video, but we cannot access that code.

---

## Part 2: MilkDrop3 Analysis

### 2.1 Platform & Technology

**Platform**: Windows-only
**Graphics API**: DirectX 9 (42+ references in core code)
**Audio API**: WASAPI loopback
**Build System**: Visual Studio 2022
**License**: BSD 3-Clause (Maxim Volskiy)
**Code Size**: ~27,000 lines C++ across 54 files

### 2.2 Rendering Technology

**DirectX 9 Pipeline**:
- Shaders: HLSL pixel shaders (ps_2.0, 2.x, 3.0)
- Textures: Advanced LRU cache system
- Effects: 25+ transition effects
- Warp/Composite: Multi-pass rendering

**Key Files**:
- `plugin.cpp` (8,859 lines) - Main implementation
- `milkdropfs.cpp` (4,712 lines) - Rendering pipeline
- `dxcontext.cpp` (6,139 lines) - DirectX 9 management

### 2.3 Preset System

**Formats**:
- `.milk` - Text-based presets with embedded HLSL
- `.milk2` - NEW in v3: Double presets (blend 2 simultaneously)

**Scripting**: EEL2 (Nullsoft Expression Evaluator Language)
- **Source**: `ns-eel2/` directory (15 files)
- **Platform**: Includes `x64-macho.o` (macOS assembly support!)
- **Variables**: q1-q64 user-defined
- **Waveforms**: 16 types, expandable to 500 points
- **Shapes**: 16 types, expandable to 500 points

**900+ Preset Library**: Text format is fully portable

### 2.4 Audio Analysis

**Capture**: Windows WASAPI loopback
- Supports 24-bit/192kHz+ in v3.31

**Processing**:
- FFT: 512-sample with equalization and windowing
- Bands: Bass/Mid/Treble (3 frequency bands per channel)
- Output: Waveform (576 samples) + Spectrum (NUM_FREQUENCIES bands)

### 2.5 macOS Compatibility Assessment

| Component | macOS Compatible? | Notes |
|-----------|-------------------|-------|
| **Preset Format** | ✅ YES | Text-based, portable |
| **EEL2 Scripting** | ✅ YES | Includes x64-macho.o |
| **DirectX 9** | ❌ NO | Requires Metal rewrite |
| **WASAPI Audio** | ❌ NO | Needs Core Audio |
| **HLSL Shaders** | ❌ NO | Convert to MSL (Metal Shading Language) |

**Estimated Porting Effort**: 4-8 weeks for experienced Metal developer

---

## Part 3: Comparison - Butterchurn vs MilkDrop3

| Aspect | Butterchurn (JS/WebGL) | MilkDrop3 (C++/DirectX) |
|--------|------------------------|-------------------------|
| **Platform** | Cross-platform (browser) | Windows only |
| **Graphics** | WebGL | DirectX 9 |
| **Language** | JavaScript | C++ |
| **Integration** | Easy (npm package) | Hard (requires porting) |
| **Performance** | Good (GPU accelerated) | Excellent (native) |
| **Presets** | 200+ (Butterchurn) | 900+ (MilkDrop) |
| **Preset Format** | .milk/.json | .milk/.milk2 |
| **Audio Source** | Web Audio API | WASAPI |
| **macOS Native** | No (runs in WebView) | No (requires full port) |
| **Swift Integration** | Via WKWebView | Requires Metal rewrite |

---

## Part 4: Video Playback Research

### 4.1 Video Formats We Should Support

If we decide to add **true video playback**, these are the standard formats:

**Video Containers**:
- `.mp4` (H.264/H.265)
- `.mov` (QuickTime)
- `.avi` (legacy, but Winamp supported it)
- `.mkv` (Matroska)
- `.webm` (VP8/VP9)
- `.flv` (Flash Video - legacy)

**macOS Native Support** (via AVFoundation):
- ✅ MP4 (H.264, H.265/HEVC)
- ✅ MOV (QuickTime)
- ✅ M4V (iTunes video)
- ⚠️ AVI (limited codec support)
- ❌ MKV (requires third-party decoder)
- ❌ FLV (deprecated)

**Recommendation**: Support MP4/MOV natively, consider FFmpeg for wider format support.

### 4.2 Video Playback Architecture (if we add it)

**Option 1: AVPlayerView (Native SwiftUI)**
```swift
import AVKit

struct VideoPlayerView: View {
    @State private var player: AVPlayer
    
    var body: some View {
        VideoPlayer(player: player)
            .frame(width: 640, height: 480)
    }
}
```

**Pros**:
- Native macOS performance
- Hardware decoding
- Full codec support (via AVFoundation)
- Integrated with existing audio pipeline

**Cons**:
- macOS 11+ only
- Limited customization of controls

**Option 2: AVPlayerLayer (AppKit)**
```swift
import AVFoundation
import AppKit

class VideoView: NSView {
    private var playerLayer: AVPlayerLayer
    
    override func makeBackingLayer() -> CALayer {
        return playerLayer
    }
}
```

**Pros**:
- More control over rendering
- Can integrate with Metal for effects
- Works with older macOS

**Cons**:
- More complex integration
- Manual lifecycle management

---

## Part 5: Window Architecture Analysis

### 5.1 Current MacAmp Window Structure

**Single Window Container**: All three windows (Main, EQ, Playlist) exist within a single `NSWindow` enclosure.

**Reference Implementations** (for V button pattern):
- `tasks/done/double-size-button/` - D button (window scaling)
- `tasks/done/oi-button-bugfix-review/` - O button (options menu)
- `tasks/done/oi-button-bugfix-review/` - I button (track info)

### 5.2 Options for V Button Window

**Option A: Within Current Single-Window Container**
- Add Milkdrop/Video view as 4th window pane
- Stays within existing architecture
- Similar to Webamp's approach
- **Limitation**: Cannot be moved independently

**Option B: Independent NSWindow (Requires Magnetic Docking)**
- Create separate `NSWindow` for visualization/video
- Can be moved/resized independently
- Matches original Winamp behavior
- **Dependency**: Requires `magnetic-docking-windows` task completion

**Recommendation**: Start with Option A (easier), migrate to Option B later.

---

## Part 6: Integration Strategies

### 6.1 Strategy 1: Pure Visualization (Butterchurn-style)

**Approach**: Port Butterchurn concepts to Swift/Metal

**Components**:
1. Audio analysis via AVAudioEngine
2. Metal shaders for visualization
3. Preset system (.milk parser)
4. SwiftUI window container

**Pros**:
- Focused scope (visualization only)
- Matches Winamp's original V button purpose
- Can reuse Milkdrop preset library
- Performance optimized (native Metal)

**Cons**:
- No video playback (users might expect it)
- 4-6 weeks development time
- Requires Metal shader development

**Estimated Effort**: 4-6 weeks

### 6.2 Strategy 2: Video Playback + Simple Visualization

**Approach**: AVPlayer for video, simple visualizer for audio

**Components**:
1. AVPlayerView for video files
2. Simple waveform/spectrum visualizer for audio
3. Smart mode switching (video vs audio)
4. SwiftUI window container

**Pros**:
- Supports both video and visualization
- Leverages native AVFoundation
- Simpler than full Milkdrop port
- 2-3 weeks development time

**Cons**:
- Visualizer less impressive than Milkdrop
- No preset system

**Estimated Effort**: 2-3 weeks

### 6.3 Strategy 3: Hybrid (Recommended)

**Approach**: Video playback + Butterchurn via WKWebView

**Components**:
1. AVPlayerView for video files (.mp4, .mov)
2. WKWebView embedding Butterchurn for audio visualization
3. Smart mode switching based on file type
4. SwiftUI window container

**Pros**:
- Full video support (native)
- Full Milkdrop visualization (Butterchurn)
- Fastest time to market (1-2 weeks)
- Reuses proven Butterchurn library

**Cons**:
- WKWebView overhead for visualization
- Not "pure native" Swift
- Requires bundling Butterchurn JS

**Estimated Effort**: 1-2 weeks

---

## Part 7: Oracle Consultation Required

Before proceeding to plan.md, we need Oracle guidance on:

### 7.1 Architecture Questions

**Q1**: Should we implement within current single-window constraint (Option A) or wait for magnetic docking (Option B)?

**Q2**: Which integration strategy aligns best with MacAmp's architecture?
- Strategy 1: Pure Visualization (Metal-based)
- Strategy 2: Video + Simple Viz
- Strategy 3: Video + Butterchurn (Hybrid)

**Q3**: How should we handle the file type detection and mode switching?

### 7.2 Technical Questions

**Q4**: Can we integrate WKWebView for Butterchurn without breaking the retro aesthetic?

**Q5**: What's the best way to bridge AVAudioEngine analysis data to:
- Option A: Metal shaders?
- Option B: WKWebView/Butterchurn?

**Q6**: Should we support video formats beyond MP4/MOV (e.g., integrate FFmpeg)?

### 7.3 Scope Questions

**Q7**: Is "V button = visualization only" acceptable, or do users expect video playback?

**Q8**: Should we implement a preset library browser (like Winamp), or keep it simple?

**Q9**: What keyboard shortcuts should we implement?
- Ctrl+V: Toggle visualization window?
- Ctrl+Shift+V: Cycle visualization modes?

---

## Part 8: File Format Detection Strategy

### 8.1 Audio Files (Current Support)

**Already Supported** (from existing MacAmp code):
- `.mp3`
- `.m4a`
- `.flac`
- `.wav`
- `.aac`
- `.ogg`

**Behavior**: Show visualization (Milkdrop/spectrum/waveform)

### 8.2 Video Files (To Add)

**Proposed New Support**:
- `.mp4`
- `.mov`
- `.m4v`
- `.avi` (limited)

**Behavior**: Show video playback in visualization window

### 8.3 Detection Logic

```swift
enum MediaType {
    case audio
    case video
}

func detectMediaType(url: URL) -> MediaType {
    let videoExtensions = ["mp4", "mov", "m4v", "avi"]
    let ext = url.pathExtension.lowercased()
    
    return videoExtensions.contains(ext) ? .video : .audio
}
```

### 8.4 Playlist Integration

**Current**: Playlist shows audio files only

**Proposed**:
1. Add video file extensions to `supportedExtensions` array
2. Show video files in playlist with special icon (🎬)
3. When double-clicked, open video in V window
4. Display video title/duration in playlist

**File Locations** (from reference tasks):
- Add files: "ADD FILE" button in playlist ADD menu
- Eject button: Should support video files
- Drag & drop: Should accept video files

---

## Part 9: Reference Implementation Analysis

### 9.1 Clutter Bar Button Patterns

**A Button** (About/Autoscroll):
- Pattern: Toggle button with state
- Window: No separate window

**I Button** (Track Info):
- Pattern: Modal dialog
- Window: Temporary info window
- Data: Shows track metadata

**O Button** (Options Menu):
- Pattern: Context menu
- Window: No separate window
- Persistence: Settings saved to UserDefaults

**D Button** (Double Size):
- Pattern: Toggle button
- Window: Scales entire window
- State: Persisted in AppSettings

### 9.2 V Button Should Follow

**Most Similar To**: I button (separate window) + D button (persistent state)

**Proposed Pattern**:
- Click: Toggle visualization/video window
- State: Remember window position, size, mode
- Persistence: Save to UserDefaults
- Keyboard: Ctrl+V shortcut

---

## Part 10: Key Decisions Needed

### Decision Matrix

| Decision Point | Option A | Option B | Recommendation |
|----------------|----------|----------|----------------|
| **Scope** | Visualization only | Video + Visualization | **B** (users expect video) |
| **Window** | Single container | Independent window | **A** (wait for magnetic docking) |
| **Visualization** | Native Metal | Butterchurn/WebView | **B** (faster, proven) |
| **Video Player** | N/A | AVPlayerView | **AVPlayerView** (native) |
| **Presets** | Full library | None/Basic | **Basic** (start simple) |
| **Timeline** | 4-6 weeks | 1-2 weeks | **1-2 weeks** (Hybrid strategy) |

---

## Part 11: Next Steps

1. ✅ **Research Complete** - This document
2. 🔄 **Oracle Consultation** - Get architectural guidance
3. ⏳ **Plan Creation** - Detailed implementation plan
4. ⏳ **Prototype** - Build proof of concept
5. ⏳ **Implementation** - Full feature development
6. ⏳ **Testing** - Verify video/visualization works
7. ⏳ **Documentation** - User guide and API docs

---

## Research Sources

1. **Webamp Clone** - Full codebase exploration via Explore agent
2. **MilkDrop3** - Complete analysis saved to `/Users/hank/dev/src/MacAmp/MILKDROP3_ANALYSIS.md`
3. **Butterchurn** - NPM package analysis and web research
4. **Gemini CLI** - Web research on Webamp implementation
5. **Reference Tasks** - A/I/O/D button implementations

---

## Appendix: File References

### Webamp Key Files
- `webamp_clone/packages/webamp/js/components/MainWindow/ClutterBar.tsx` - V button location
- `webamp_clone/packages/webamp/js/components/Vis.tsx` - Visualizer component
- `webamp_clone/packages/webamp/js/components/MilkdropWindow/` - Milkdrop integration
- `webamp_clone/packages/webamp/js/reducers/milkdrop.ts` - Milkdrop Redux state

### MilkDrop3 Key Files
- `MilkDrop3/plugin.cpp` (8,859 lines) - Main implementation
- `MilkDrop3/milkdropfs.cpp` (4,712 lines) - Rendering pipeline
- `MilkDrop3/dxcontext.cpp` (6,139 lines) - DirectX 9 management
- `MilkDrop3/ns-eel2/` - EEL2 scripting engine (macOS compatible!)

### MacAmp Reference Files
- `tasks/done/double-size-button/` - D button implementation
- `tasks/done/oi-button-bugfix-review/` - O/I button implementations
- `MacAmpApp/Models/AppSettings.swift` - Settings persistence pattern
- `MacAmpApp/Views/WinampMainWindow.swift` - Main window container

---

**Research Completed**: 2025-11-08
**Next Phase**: Oracle Consultation → Plan Creation

---

## Part 12: Oracle Consultation Results (gpt-5-codex, High Reasoning)

### Architecture Decision: Option A (Single-Window Container)

**Recommendation**: Keep V button visualization inside existing `WinampMainWindow` for v1.

**Rationale**:
- Existing chrome is already an all-in-one SwiftUI scene with fixed pixel coordinates
- Reuses existing rendering assumptions and drag gesture handling
- Avoids blocking on magnetic-docking-windows task
- Can be hoisted to independent window later when docking lands

**Implementation Pattern**:
- Add `showVisualizerPanel` flag to `AppSettings` (mirrors `showTrackInfoDialog`)
- Persist geometry same way as `isDoubleSizeMode`
- Route through `AppCommands` with `⌃V` shortcut
- Isolate in `VisualizationContainerView` for future window extraction

### Strategy Decision: Strategy 3 (Hybrid)

**Recommendation**: Pursue hybrid approach (AVPlayerView + Butterchurn/WKWebView).

**Rationale**:
- Delivers both "video playback" and "Milkdrop visualization" in 6-day cycle
- Strategy 1 (Metal) overshoots schedule (4-6 weeks)
- Strategy 2 (Simple viz) under-delivers on nostalgia
- Keeps door open for future Metal renderer
- Immediately satisfies user expectations

**Components**:
1. **AVPlayerView** (via NSViewRepresentable) for video files
2. **WKWebView** hosting Butterchurn for audio visualization
3. **File-type detection** to switch modes before playback
4. **Skin-aware theming** to maintain retro aesthetic

### Technical Implementation Details

#### Video Surface
```swift
// Embed AVPlayerView in NSViewRepresentable
// Size to Winamp's legacy visualization rectangle
// Detect media type by extension/mime
// Switch player vs Butterchurn before playback
```

#### Visualization Surface
```swift
// Wrap Butterchurn in lightweight WKWebView
// Load local HTML bundle (no external resources)
// Remove scrollbars, disable background drawing
// Sync colors with current skin via SkinManager
```

#### Audio Bridge (AVAudioEngine → Butterchurn)
```swift
// Install tap on AVAudioEngine.mainMixerNode
// Compute FFT/RMS with Accelerate framework
// Downsample to 64-128 bins
// Serialize to typed array every ~16ms
// Push via evaluateJavaScript or WKScriptMessageHandler
// Use lock-free ring buffer for thread safety
// @MainActor task posts batches asynchronously
```

#### State Management
```swift
// Store in AppSettings.visualizerMode
// Reuse existing didSet persistence pattern
// Expose toggles through AppCommands
// ⌃V shortcut flips boolean (matches ⌃D, ⌃O, ⌃I)
```

#### Preset Handling
- Ship 5-8 curated Butterchurn presets
- Auto-cycle every 30 seconds
- Persist last-used preset index
- Defer full browser UI to later cycle

#### Skin Integration
- Feed active skin colors (SkinManager) to both:
  - AVPlayer overlay chrome
  - Butterchurn HTML (gradients, borders, fonts)
- Optional "chromeless" toggle in settings

### Risk Mitigations

**WKWebView "Un-Native" Feel**:
- ✅ Hide scrollbars
- ✅ Disable interaction
- ✅ Layer skin-colored matte behind canvas
- ✅ Cache HTML locally (offline support)
- ✅ No external resources (maintains retro vibe)

**Audio Bridge Throughput**:
- ⚠️ Cap FFT payloads (256 floats max)
- ⚠️ Send JSON only when tap produces new data
- ⚠️ Throttle with display-link timer if needed

**Synchronization**:
- ⚠️ Video playback: AVPlayer replaces audio pipeline (avoid dual sources)
- ⚠️ Audio-only: Keep player muted, clock to engine tap

**Magnetic Docking Dependency**:
- ✅ Document that visualization lives inside main window (v1)
- ✅ Isolated `VisualizationContainerView` ready for WindowGroup extraction

### 6-Day Implementation Plan

**Day 1: State + Plumbing**
- Extend `AppSettings` with V-button toggle
- Add keyboard shortcut to `AppCommands`
- Stub placeholder view in `WinampMainWindow`

**Day 2: Video Path**
- Build `AVPlayerViewRepresentable`
- Hook up file-type detection
- Ensure playlist/eject flows set correct mode

**Days 3-4: Butterchurn Host**
- Package WKWebView HTML bundle
- Integrate preset cycling
- Wire FFT bridge (AVAudioEngine → JavaScript)

**Day 5: Skin Polish + Persistence**
- Apply theming (SkinManager integration)
- Store window size/position
- Add simple preset selection UI (menu/keyboard toggle)

**Day 6: Verification + Documentation**
- Exercise both video and visualization modes
- Add regression tests for media-type detection
- Document feature in `docs/`

### Swift 6 Patterns

**State Management**:
```swift
@Observable @MainActor
final class AppSettings {
    var showVisualizerPanel: Bool = false { didSet { persist() } }
    var visualizerMode: VisualizerMode = .butterchurn
    var lastUsedPresetIndex: Int = 0
}
```

**Concurrency**:
- All mutable UI state in `@Observable @MainActor` models
- Inject via `@Environment` (matches existing clutter buttons)
- Audio taps run off render thread
- Publish FFT updates through `MainActor` isolated async sequences

**View Architecture**:
```swift
// Dedicated view types for embeds
struct AVPlayerViewRepresentable: NSViewRepresentable { }
struct ButterchurnWebView: NSViewRepresentable { }
struct VisualizationContainerView: View { }
```

**Persistence**:
- Use existing `didSet + UserDefaults` pattern
- Matches `isDoubleSizeMode`, `timeDisplayMode` consistency

### File Format Support

**Recommendation**: Start AVFoundation-only (MP4, MOV, M4V).

**Rationale**:
- Native codec support via AVFoundation
- No FFmpeg complexity for v1.0
- Covers 90% of user video files
- Can add FFmpeg in later cycle if needed

**Implementation**:
```swift
enum MediaType {
    case audio
    case video
}

func detectMediaType(url: URL) -> MediaType {
    let videoExtensions = ["mp4", "mov", "m4v", "avi"]
    return videoExtensions.contains(url.pathExtension.lowercased()) 
        ? .video : .audio
}
```

### Scope Definition

**Recommendation**: Smart Video + Visualization (Option B)

**Behavior**:
- Click V: Opens video/visualization window
- Auto-detects file type:
  - Video files (MP4, MOV) → AVPlayerView
  - Audio files (MP3, FLAC) → Butterchurn visualization
- Matches 2025 user expectations for Winamp clone

### Oracle's Final Assessment

**Time to Market**: 6 days (matches dev cycle)
**Code Quality**: High (follows existing patterns)
**Maintainability**: Excellent (isolated, testable components)
**Retro Aesthetic**: Preserved (skin-aware theming)
**Swift 6 Compliance**: Full (@Observable, @MainActor, strict concurrency)

**Next Steps**: Confirm hybrid scope with stakeholders, then capture in `plan.md`.

---

**Research + Oracle Consultation Complete**: 2025-11-08
**Total Research Time**: ~5 hours
**Next Phase**: Plan.md Creation → User Approval → Implementation

---

## Part 13: Preset Format Clarification (.milk vs .milk2)

### Question from User
"Did you include .milk2 files in research and plan?"

### Answer

**YES - Covered in Research** (Part 2.3):
- `.milk` - Original Milkdrop preset format (text-based, HLSL shaders)
- `.milk2` - MilkDrop3 v3.31+ exclusive (double presets, blend 2 simultaneously)

**For V1 Implementation**:
- **Using**: Butterchurn (JavaScript/WebGL port)
- **Supports**: `.milk` format only
- **Does NOT support**: `.milk2` (MilkDrop3-specific feature)
- **Preset Library**: butterchurn-presets NPM package (~200 `.milk` presets)

### Butterchurn Preset Support

**What Works in Butterchurn**:
- ✅ `.milk` text-based presets
- ✅ `.json` preset format (Butterchurn native)
- ✅ Embedded HLSL shaders (converted to GLSL for WebGL)
- ✅ EEL2 scripting (JavaScript port)
- ✅ Waveforms, shapes, transitions

**What Doesn't Work** (MilkDrop3 v3.31+ features):
- ❌ `.milk2` double presets
- ❌ Advanced v3.31 shader effects
- ❌ 500-point waveforms (Butterchurn limited to 16)

### Recommendation for V1

**Approach**: Use curated `.milk` presets from butterchurn-presets
- Select 5-8 high-quality, visually diverse presets
- All proven to work in Butterchurn
- Cover different visual styles (spiral, mandelbrot, plasma, etc.)

**Example Preset Selection**:
1. Geiss - Spiral Artifact (classic spiral)
2. Martin - Mandelbox Explorer (3D fractal)
3. Flexi - Predator-Prey (organic motion)
4. Rovastar - Altars of Madness (abstract)
5. Unchained - Lucid Concentration (plasma)

### Future Enhancement (V2/V3)

If we implement **Metal-native renderer**, we could:
- Parse `.milk2` files (text format, documented)
- Implement double-preset blending
- Port MilkDrop3 v3.31 shader enhancements
- Support 500-point waveforms

**Estimated Effort**: 2-3 weeks additional (after Metal renderer)

### Oracle Consultation Needed?

**Question for Oracle**: 
Should we:
1. Stick with Butterchurn's `.milk` presets for v1? (Recommended)
2. Or investigate Butterchurn `.milk2` support (may not exist)?
3. Or plan for Metal renderer sooner to support `.milk2`?

**User Decision**: Awaiting guidance on preset format priorities.

---

**Updated**: 2025-11-08 (Preset format clarification added)

---

## Part 14: CRITICAL DISCOVERY - Separate Video & Milkdrop Windows

**Date**: 2025-11-08  
**Discovery Method**: User found VIDEO.bmp, Explore agent analysis, Oracle validation  
**Impact**: MAJOR - Changes entire architectural approach

### Discovery Timeline

1. **User Observation**: VIDEO.bmp exists in Internet-Archive.wsz skin (233x119 pixels)
2. **Hypothesis**: Video window might be separate from Milkdrop window
3. **Investigation**: Deep dive into webamp_clone architecture
4. **Confirmation**: Original Winamp uses TWO separate skinnable windows

### Evidence: VIDEO.bmp Analysis

**File**: `tmp/Internet-Archive/VIDEO.bmp`  
**Dimensions**: 233 x 119 x 24-bit  
**Size**: 83,356 bytes  
**Purpose**: Window chrome sprites for dedicated video playback window

**Sprite Layout** (typical VIDEO.bmp):
- Titlebar (active/inactive states)
- Window borders (top, left, right, bottom)
- Corner pieces (4 corners)
- Buttons (close, minimize, shade)
- Playback controls (play, pause, stop, seek bar)

### Webamp Architecture Analysis

#### Current Implementation (webamp_clone)

**Only 4 Windows Defined**:
```typescript
// File: packages/webamp/js/constants.ts
export const WINDOWS = {
  MAIN: "main",
  PLAYLIST: "playlist",
  EQUALIZER: "equalizer",
  MILKDROP: "milkdrop"  // ✅ Fully implemented
  // ❌ NO video window
};
```

**Component Structure**:
```
packages/webamp/js/components/
├── EqualizerWindow/
├── GenWindow/
├── MainWindow/
├── MilkdropWindow/      ✅ Complete React component
├── PlaylistWindow/
└── WindowManager.tsx
❌ NO VideoWindow/
```

**Redux State** (`packages/webamp/js/reducers/windows.ts`):
```typescript
[WINDOWS.MILKDROP]: {
  title: "Milkdrop",
  size: [0, 0],
  open: false,
  shade: false,
  canResize: true,
  canShade: false,
  canDouble: false,
  position: { x: 0, y: 0 },
}
// ❌ NO video window state
```

#### Video Window in Winamp Classic Skin

**File**: `packages/webamp-modern/assets/winamp_classic/xml/video.xml`

```xml
<container id="video" name="Video Window" 
           default_x="0" default_y="232" default_visible="0">
  <layout id="normal" background="wasabi.frame.basetexture" 
          minimum_h="116" minimum_w="275">
    
    <!-- Window chrome from VIDEO.bmp -->
    <layer id="video.topleft" image="video.topleft.active" ... />
    <layer id="video.top" image="video.top.active" ... />
    <!-- ... more chrome layers ... -->
    
    <!-- Video content area -->
    <windowholder id="studio.list" component="" fitparent="1"
      x="11" y="20" w="-19" h="-58" relatw="1" relath="1"
      noshowcmdbar="1" autoopen="1" autoclose="1"
      param="guid:{F0816D7B-FFFC-4343-80F2-E8199AA15CC3}"
    />
  </layout>
</container>
```

**Window GUID**: `{F0816D7B-FFFC-4343-80F2-E8199AA15CC3}`

**Recognized in UIRoot.ts**:
```typescript
// File: packages/webamp-modern/src/UIRoot.ts
const knownContainerGuids = {
  "{F0816D7B-FFFC-4343-80F2-E8199AA15CC3}": "video",
  // ... other GUIDs
};
```

**But NOT Implemented**:
```typescript
// File: packages/webamp-modern/src/skin/SkinEngine_WindowsMediaPlayer.ts
case "video":
  //* UNHANDLED
  return this.group(node, parent);
```

### Original Winamp Classic Architecture

**TWO Independent, Simultaneous Windows**:

```
┌──────────────────────────┐    ┌──────────────────────────┐
│  Video Window            │    │  Milkdrop Window         │
│  GUID: {F0816D7B...}     │    │  (Visualization Plugin)  │
│                          │    │                          │
│  ┌────────────────────┐  │    │  ┌────────────────────┐  │
│  │ VIDEO.BMP Chrome   │  │    │  │ Milkdrop Chrome    │  │
│  ├────────────────────┤  │    │  ├────────────────────┤  │
│  │                    │  │    │  │                    │  │
│  │  Video Playback    │  │    │  │  Audio Viz         │  │
│  │  (MP4, AVI, etc)   │  │    │  │  (Butterchurn)     │  │
│  │                    │  │    │  │                    │  │
│  └────────────────────┘  │    │  └────────────────────┘  │
│  [■] [▶] [■] [◼] |====| │    │  [Presets] [Fullscreen]  │
└──────────────────────────┘    └──────────────────────────┘
     Independent Window              Independent Window
     Can open/close                  Can open/close
     Can coexist with other          Can coexist with other
```

**Key Characteristics**:
1. **Separate lifecycles**: Each window opens/closes independently
2. **Simultaneous operation**: Both can be open at the same time
3. **Independent skinning**: VIDEO.bmp vs Milkdrop chrome
4. **Different purposes**:
   - Video: Playback of video files (MP4, AVI, MOV)
   - Milkdrop: Audio visualization for music files

### Why Webamp Chose Milkdrop-Only

**Technical Reasons**:
1. Browser limitations for video codec support
2. Focus on audio player functionality
3. Milkdrop (via Butterchurn) more achievable in JavaScript/WebGL
4. Video playback already handled by browser's `<video>` element

**Webamp's Approach**:
- Implemented: Milkdrop window (full React component)
- Skipped: Video window (XML stub only)
- Rationale: Audio player focus, not media player

### Implications for MacAmp

#### Previous Assumption (INCORRECT)
- **Thought**: One combined window for both video and visualization
- **Based on**: Webamp only having Milkdrop window
- **Plan**: Mode-switching based on file type

#### New Reality (CORRECT)
- **Truth**: Two separate windows in original Winamp
- **Evidence**: VIDEO.bmp exists in skins, video.xml defines window
- **Requirement**: Faithful recreation needs both windows

#### Architecture Decision (User Approved)

**OPTION A: Two Independent Windows** ✅ CHOSEN

**Phase 1: Video Window** (Priority 1)
- VideoWindowView.swift
- AVPlayerView integration
- VIDEO.bmp sprite parsing
- Playback controls
- Skin-aware chrome
- Tie to "V" button

**Phase 2: Milkdrop Window** (Priority 2)
- MilkdropWindowView.swift
- Butterchurn via WKWebView
- FFT audio analysis
- Preset system
- Independent from video window

**Benefits**:
- ✅ Accurate to original Winamp
- ✅ Both windows can be open simultaneously
- ✅ VIDEO.bmp skin support
- ✅ Separate concerns (video vs visualization)
- ✅ Matches user expectations
- ✅ Future-proof architecture

**Timeline**: 8-10 days (acceptable per user)

### Video Window Requirements (Detailed)

#### 1. Window Chrome (VIDEO.bmp Parsing)

**SkinManager Extension Needed**:
```swift
extension SkinManager {
    func loadVideoWindowSprites(from skin: Skin) -> VideoWindowSprites {
        // Parse VIDEO.bmp
        // Extract sprite regions:
        // - Titlebar (active/inactive)
        // - Borders (top, left, right, bottom)
        // - Corners (TL, TR, BL, BR)
        // - Buttons (close, minimize, shade)
        // - Playback controls (play, pause, stop)
        // - Seek bar components
    }
}
```

**Sprite Regions** (typical VIDEO.bmp layout):
- Titlebar: y=0, height=14
- Window frame: Various regions
- Playback buttons: Bottom bar
- Seek bar: Slider track and thumb

#### 2. Video Playback Controls

**Controls from VIDEO.bmp**:
- Play button
- Pause button
- Stop button
- Previous track
- Next track
- Seek bar (with thumb)
- Volume control (optional)

**Behavior**:
- Click play → Start video
- Click pause → Pause video
- Drag seek bar → Seek to position
- Double-click titlebar → Shade mode (collapse to titlebar)

#### 3. AppSettings Integration

```swift
@Observable @MainActor
final class AppSettings {
    // Video window state
    var showVideoWindow: Bool = false {
        didSet { UserDefaults.standard.set(showVideoWindow, forKey: "showVideoWindow") }
    }
    
    var videoWindowFrame: CGRect? {
        didSet {
            if let frame = videoWindowFrame {
                UserDefaults.standard.set(NSStringFromRect(frame), forKey: "videoWindowFrame")
            }
        }
    }
    
    var videoWindowShaded: Bool = false {
        didSet { UserDefaults.standard.set(videoWindowShaded, forKey: "videoWindowShaded") }
    }
    
    // Milkdrop window state (separate)
    var showMilkdropWindow: Bool = false {
        didSet { UserDefaults.standard.set(showMilkdropWindow, forKey: "showMilkdropWindow") }
    }
    
    var milkdropWindowFrame: CGRect? { /* ... */ }
    // ... milkdrop settings
}
```

#### 4. V Button Behavior

**User Request**: "V" button opens **Video window**

```swift
// In AppCommands.swift
Button("Toggle Video Window") {
    appSettings.showVideoWindow.toggle()
}
.keyboardShortcut("v", modifiers: [.control])

// For Milkdrop (separate shortcut)
Button("Toggle Milkdrop Window") {
    appSettings.showMilkdropWindow.toggle()
}
.keyboardShortcut("m", modifiers: [.control, .shift])
// Or via Options menu
```

### Comparison: Webamp vs MacAmp Architecture

| Aspect | Webamp | MacAmp (New Plan) |
|--------|--------|-------------------|
| **Video Window** | ❌ XML stub only | ✅ Full implementation |
| **Milkdrop Window** | ✅ Fully implemented | ✅ Full implementation |
| **VIDEO.bmp Support** | ❌ Not parsed | ✅ Sprite parsing |
| **Simultaneous Windows** | N/A (no video) | ✅ Both can be open |
| **V Button** | Milkdrop toggle | Video window toggle |
| **Video Playback** | ❌ Not supported | ✅ AVPlayerView |
| **Skin Accuracy** | Partial | ✅ Full (both windows) |

### Research Conclusion

**Finding**: Original Winamp uses **TWO SEPARATE WINDOWS** for video and milkdrop.

**Decision**: MacAmp will implement **BOTH windows independently**.

**Priority**:
1. Video Window (with VIDEO.bmp skinning)
2. Milkdrop Window (with Butterchurn visualization)

**Timeline**: 8-10 days for complete two-window implementation.

**Accuracy**: Full Winamp Classic fidelity achieved.

---

**Research Complete**: 2025-11-08 (Updated with video window discovery)  
**Total Research Time**: ~10 hours (including video window investigation)  
**Next Phase**: Revised planning for two-window architecture
# CRITICAL ARCHITECTURAL FINDING: Separate Video Window

**Date**: 2025-11-08  
**Discovery**: User found VIDEO.bmp in Internet-Archive.wsz skin  
**Implication**: Original Winamp has SEPARATE windows for Video and Milkdrop

---

## Evidence

### 1. VIDEO.bmp in Skin
**File**: `tmp/Internet-Archive/VIDEO.bmp`
**Dimensions**: 233 x 119 x 24-bit
**Purpose**: Sprites for video window chrome (titlebar, borders, buttons)

### 2. Webamp Architecture Discovery

**Current Implementation** (Webamp):
- **Milkdrop Window**: ✅ FULLY implemented (React component, Redux state)
- **Video Window**: ⚠️ STUB/LEGACY (XML defined, NOT in React/Redux)

**File Evidence**:
```
packages/webamp/js/constants.ts:
  - Only 4 windows: MAIN, PLAYLIST, EQUALIZER, MILKDROP
  - NO video window constant

packages/webamp/js/components/:
  - EqualizerWindow/
  - MilkdropWindow/
  - MainWindow/
  - PlaylistWindow/
  - ❌ NO VideoWindow/

packages/webamp-modern/assets/winamp_classic/xml/video.xml:
  - ✅ Video window defined (GUID: {F0816D7B-FFFC-4343-80F2-E8199AA15CC3})
  - Container for studio.list component
  - Uses VIDEO.bmp sprites
  - ❌ NOT rendered in React layer
```

### 3. Original Winamp Classic

**Architecture** (from skin XML):
- **Video Window**: Separate skinned window
  - Chrome from VIDEO.bmp
  - Independent open/close
  - Can coexist with Milkdrop window

- **Milkdrop Window**: Separate plugin window
  - Independent visualization engine
  - Can be opened alongside video

**Both windows can be open SIMULTANEOUSLY**

---

## Implications for MacAmp

### Current Plan (Now Questionable)
Our 6-day plan assumed:
- **ONE window** for BOTH video and milkdrop
- Auto-switch based on file type
- Single VisualizationContainerView

### Should We Have TWO Separate Windows?

**Option A: TWO Separate Windows** (Winamp-accurate)
```
┌──────────────────┐    ┌──────────────────┐
│  Video Window    │    │ Milkdrop Window  │
│  (VIDEO.bmp)     │    │ (separate)       │
│                  │    │                  │
│  [AVPlayerView]  │    │ [Butterchurn]    │
└──────────────────┘    └──────────────────┘
```

**Pros**:
- Matches original Winamp behavior
- Both windows can be open simultaneously
- Separate skin support (VIDEO.bmp for video chrome)
- User can watch video AND see visualization of audio track

**Cons**:
- 2x skin parsing work
- 2x window management complexity
- Likely 8-10 days instead of 6

**Option B: ONE Combined Window** (Current plan)
```
┌──────────────────┐
│ Visualization    │
│ Window           │
│  (mode-switch)   │
│                  │
│  Video OR Viz    │
└──────────────────┘
```

**Pros**:
- Simpler implementation (6 days)
- Less complexity
- Still functional

**Cons**:
- NOT accurate to Winamp
- Can't have both video and milkdrop open
- No VIDEO.bmp skin support

---

## Questions for Oracle

1. **Should MacAmp have TWO separate windows** (Video + Milkdrop)?
2. **Or ONE combined window** (mode-switching)?
3. **Is VIDEO.bmp skinning essential** for retro accuracy?
4. **Timeline impact**: Can we do 2 windows in 6 days? Or extend to 8-10?
5. **User expectation**: Do users expect separate video/milkdrop windows?

---

## Next Steps

1. ✅ Document findings (this file)
2. ⏳ Consult Oracle with new evidence
3. ⏳ Decide: 1 window vs 2 windows
4. ⏳ Update plan.md if architecture changes
5. ⏳ Update todo.md with new tasks if needed

---

**CRITICAL**: Do not begin Day 1 implementation until this is resolved!
# Gemini File Access Errors - Explanation

## The Errors

```
Error executing tool read_file: File path '/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/components/Vis.tsx' is ignored by configured ignore patterns.
```

## Root Cause

**webamp_clone/** is a Git repository with a `.gitignore` file that excludes:
- `node_modules/`
- Build artifacts
- TypeScript/JavaScript source files in certain directories

Gemini's file reading tool respects `.gitignore` patterns and cannot read ignored files.

## Why It Doesn't Matter

Despite these errors, we successfully gathered all needed information through:

1. **Explore Agent** - Used specialized codebase exploration that bypasses ignore patterns
2. **Gemini's Search Tools** - Text search found code patterns even though files couldn't be read
3. **Codebase Investigator** - Analyzed project structure and dependencies

## What We Learned About Webamp's Milkdrop

**Version**: Webamp uses **Butterchurn** (JavaScript port of Milkdrop)
- Not Milkdrop v2 or v3 directly
- Butterchurn is a WebGL-based reimplementation
- NPM packages: `butterchurn@3.0.0-beta.4` + `butterchurn-presets@3.0.0-beta.4`

**Milkdrop v2 vs v3 Decision**: 
- **We're NOT using either directly** - both are Windows/DirectX only
- **We're using Butterchurn concept** - Web-based, cross-platform
- **Future option**: Port Milkdrop v3 to Metal (4-8 weeks effort, deferred)

## Conclusion

The errors were cosmetic - Gemini couldn't read specific source files but gathered enough context through alternative methods. All research objectives were met.
