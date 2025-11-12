# Research: Milkdrop/Video Support for MacAmp V Button

**Task ID**: milk-drop-video-support
**Research Date**: 2025-11-08
**Researchers**: Claude Code + Gemini CLI + Explore Agents
**Prerequisite**: TASK 1 (magnetic-docking-foundation) MUST be complete first

---

## CRITICAL: Resizable Window Pattern (Shared Across Tasks)

**Discovery from TASK 1**: Video and Milkdrop windows are ALSO resizable (like Playlist)

**Shared Resize Pattern** (applies to Playlist, Video, Milkdrop):
- Bottom section: LEFT (125px) + CENTER (expandable) + RIGHT (150px)
- Quantized segments: 25px width × 29px height increments
- BOTTOM_TILE sprite for center tiling
- Transparent 20×20 drag handle at bottom-right corner
- Minimum: 275×116 pixels (segments [0,0])
- See: `tasks/playlist-resize-analysis/` for complete specification

**Implementation Strategy for TASK 2**:
- Video window will use same resize pattern
- Milkdrop window will use same resize pattern
- Can implement resize for ALL 3 windows together (Playlist + Video + Milkdrop)
- Solve once, apply to all 3!

**If NOT implemented in TASK 2**:
- Could become TASK 3: "Resizable Window System"
- Implement resize for Playlist/Video/Milkdrop together
- ~12-20 hours total (first window hardest, others follow pattern)

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

### Part 15: Sprite Source Audit (Video vs. Milkdrop Chrome)

**Date**: 2025-11-09  
**Goal**: Answer the “CRITICAL SPRITE SOURCE RESEARCH” questions for Task 2.

#### 15.1 VIDEO.bmp Summary

- **File & size**: `tmp/Winamp/VIDEO.BMP` – `file` reports `234 x 119` (Windows 3.x BMP, 8-bit palette).
- **Layout of sprites**: Taken directly from Winamp’s classic skin definition (`webamp_clone/packages/webamp-modern/assets/winamp_classic/xml/classic-elements.xml:112-141`). Active and inactive title bars are stacked vertically, followed by border pieces and the control pod.

| ID (per XML) | Rect (x, y, w, h) | Notes |
| --- | --- | --- |
| `video.topleft.(active|inactive)` | `(0,0,25,20)` / `(0,21,25,20)` | Left cap of titlebar; hold Winamp logo highlight |
| `video.top.center.(active|inactive)` | `(26,0,100,20)` / `(26,21,100,20)` | Center strip behind title text |
| `video.top.stretchybit.(active|inactive)` | `(127,0,25,20)` / `(127,21,25,20)` | Tile to span between center and right cap |
| `video.topright.(active|inactive)` | `(153,0,25,20)` / `(153,21,25,20)` | Right cap plus bevel highlight |
| `video.left` / `video.right` | `(127,42,11,29)` / `(139,42,8,29)` | Vertical borders for resizable body |
| `video.bottomleft` / `video.bottomright` | `(0,42,125,38)` / `(0,81,125,38)` | Fixed ends of the control bar |
| `video.bottom.stretchybit` | `(127,81,25,38)` | Tileable center under playhead |
| `video.close` / `video.closep` | `(167,3,9,9)` / `(148,42,9,9)` | Close button (normal/pressed) used by `<button action="Close">` |
| `video.fullscreen` / `video.fullscreenp` | `(9,51,15,18)` / `(158,42,15,18)` | Fullscreen toggle |
| `video.1x` / `video.1xp` | `(24,51,15,18)` / `(173,42,15,18)` | 1× zoom |
| `video.2x` / `video.2xp` | `(39,51,15,18)` / `(188,42,15,18)` | 2× zoom |
| `video.misc` / `video.miscp` | `(69,51,15,18)` / `(218,42,15,18)` | Misc/options drop-down |

`video.xml` confirms the resize scheme: `minimum_w="275"` / `minimum_h="116"`; bottom edges use the shared “left cap + stretch + right cap” pattern; the `<layer ... resize="bottomright">` entry creates the transparent drag handle so no dedicated sprite is present.

**Parsing requirement**: MacAmp must extract the 16 sprite pairs above and expose them as a little 9-slice kit (top row, center row, bottom row) plus individual command buttons. No sign of extra hover/disabled states, so the unpressed + pressed assets are sufficient.

#### 15.2 Milkdrop Chrome Provenance

- `MilkdropWindow` renders a `GenWindow` (`webamp_clone/packages/webamp/js/components/MilkdropWindow/index.tsx:60`) which provides titlebar, borders, and resize affordances.
- `GenWindow` composes the chrome entirely from the `GEN_*` sprite set defined in `skinSprites.ts:700-738` and styled via `css/gen-window.css`.
- There is **no** reference to `AVSMAIN.bmp` anywhere in the component tree; the visualization simply fills the GenWindow content area with a black `<Background>` until Butterchurn paints.
- Therefore, Milkdrop’s chrome always comes from `GEN.BMP` (and optionally `GEN_CLOSE_SELECTED`), matching other “general” plugin hosts in Winamp.

#### 15.3 GEN.bmp vs. GENEX.bmp

- `GEN.bmp` – Required; contains the six top pieces, vertical borders, bottom tiles, and the close button. It forms a strict 9-slice frame (see `WinampSkinRenderingProcessResearch.md:90-118` for historical documentation).
- `GENEX.bmp` – Optional; adds shared button backgrounds, scrollbars, and the color configuration pixels Nullsoft encoded in the top-right corner. Webamp leaves the `GENEX` entry commented out (`skinSprites.ts:760-820`) because it does not ship a Media Library, but nothing prevents MacAmp from parsing the same file later.
- **Implication**: For Task 2 we only need the `GEN` sprites we already parse; Milkdrop does not require new chrome assets even if `AVSMAIN.bmp` is missing from the skin.

#### 15.4 Sprite Parsing Checklist

1. **Video window**
   - Detect `VIDEO.bmp`, slice every sprite from the table above, build a 3×3 tiling system, and wire the command buttons (normal + pressed states).
   - Provide fallback chrome (bundled VIDEO.bmp) when the sheet is absent.
2. **Milkdrop window**
   - Reuse the `GEN.bmp` surfaces already in SkinManager; only ensure we expose the necessary sprites to the SwiftUI Milkdrop shell.
   - `GENEX.bmp` remains optional metadata—useful for scrollbars later but not needed for chrome.

**Key takeaway**: VIDEO.bmp is the *only* new required sprite sheet for Task 2; the Milkdrop window inherits all chrome from the existing `GEN.bmp` general-window system.

---

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

---

## Part 15: GEN Sprite Extraction Methodology (2025-11-11)

### Critical Learning: Sprite Coordinate Verification

**Context**: Implementing Milkdrop window titlebar with GEN.bmp letter sprites

### The Problem

Webamp documentation specified letter sprite coordinates:
- Selected letters: Y=88
- Normal letters: Y=96

However, visual testing showed letters were **cut off at the bottom** when using these coordinates.

### Investigation Process

**Tool Used**: ImageMagick (available on macOS via Homebrew)

**Systematic Extraction Testing**:
```bash
# Extract letter 'M' at different Y positions
magick /tmp/GEN.png -crop 8x7+86+85 /tmp/M_Y85.png
magick /tmp/GEN.png -crop 8x7+86+86 /tmp/M_Y86.png  # ✅ Complete letter
magick /tmp/GEN.png -crop 8x7+86+87 /tmp/M_Y87.png
magick /tmp/GEN.png -crop 8x7+86+88 /tmp/M_Y88.png  # ❌ Top cut off
magick /tmp/GEN.png -crop 8x7+86+96 /tmp/M_Y96.png  # ✅ Complete letter
magick /tmp/GEN.png -crop 8x7+86+97 /tmp/M_Y97.png
```

**Visual Inspection**: Open extracted PNGs and compare

### The Solution

**Correct Coordinates** (verified by extraction):
- Selected (bright) letters: **Y=86** (not 88)
- Normal (dim) letters: **Y=96** (matches Webamp!)

**Why Offset Exists**:
1. Different Winamp skin versions may have varying sprite layouts
2. Classic Winamp vs Winamp 5 vs Winamp 3 used different GEN.BMP versions
3. Webamp docs may reference a different skin variant

### Tools for Sprite Coordinate Verification

#### 1. ImageMagick (Recommended) ✅

**Extract sprite region**:
```bash
magick input.png -crop WIDTHxHEIGHT+X+Y output.png

# Example: Extract 8×7 pixel letter at (86,86)
magick /tmp/GEN.png -crop 8x7+86+86 /tmp/letter_test.png
open /tmp/letter_test.png
```

**Extract horizontal strip** (find Y position):
```bash
# Extract 10-pixel tall strip starting at Y=85
magick /tmp/GEN.png -crop 194x10+0+85 /tmp/strip_Y85.png
```

**Get image info**:
```bash
identify -verbose image.png  # Full metadata
identify image.png           # Quick dimensions
```

#### 2. macOS Preview.app ✅

**Coordinate Inspection**:
1. `open -a Preview /tmp/GEN.png`
2. Tools → Show Inspector (⌘I)
3. Tools → Rectangular Selection
4. Hover mouse over image
5. Bottom-left shows coordinates

**Important**: Preview coordinates are relative to monitor, not image (0,0) = top-left of *screen*
**Workaround**: Use selection tool, Inspector shows selection dimensions

#### 3. Python + Pillow (Programmatic)

```python
from PIL import Image
img = Image.open('/tmp/GEN.png')
print(f'Size: {img.size}')  # (194, 109)

# Extract region (left, top, right, bottom)
letter = img.crop((86, 86, 86+8, 86+7))
letter.save('/tmp/extracted.png')
```

### Titlebar Tiling Pattern (ZStack vs HStack)

**Problem**: HStack compresses tiles, doesn't fill width

**Solution**: Use **ZStack with explicit .position()** (like VIDEO window):

```swift
ZStack(alignment: .topLeading) {
    // Left corner
    SimpleSpriteImage("GEN_TOP_LEFT", width: 25, height: 20)
        .position(x: 12.5, y: 10)  // Center at X=12.5 (0-25 range)
    
    // Left fill tiles
    ForEach(0..<8, id: \.self) { i in
        SimpleSpriteImage("GEN_TOP_CENTER_FILL", width: 25, height: 20)
            .position(x: 50 + 12.5 + CGFloat(i) * 25, y: 10)
    }
    
    // Letters overlay (HStack positioned at center)
    HStack(spacing: 0) {
        SimpleSpriteImage("GEN_TEXT_M", width: 8, height: 7)
        // ... more letters
    }
    .position(x: 256, y: 10)  // Center of 512px window
    
    // Right fill tiles
    ForEach(0..<8, id: \.self) { i in
        SimpleSpriteImage("GEN_TOP_CENTER_FILL", width: 25, height: 20)
            .position(x: 280 + 12.5 + CGFloat(i) * 25, y: 10)
    }
}
```

**Why this works**:
- Each tile explicitly positioned (no SwiftUI layout compression)
- Tiles fill space from edges to center
- Letters overlay on top at center
- Matches VIDEO window pattern exactly

### Key Learnings

1. **Never trust documentation blindly** - Always verify sprite coordinates with actual bitmap extraction
2. **Use ImageMagick for systematic testing** - Extract at multiple Y values to find complete sprites
3. **ZStack + .position() for tiling** - HStack gets compressed by SwiftUI layout system
4. **Visual verification is critical** - Extract test sprites before updating code
5. **Different skin versions exist** - Webamp docs may reference different GEN.BMP variant

### Added to @BUILDING_RETRO_MACOS_APPS_SKILL.md

These sprite extraction patterns should be documented in the main skill guide for future retro app development.


### Critical Discovery: GEN Letters Are Two-Piece Sprites

**Date**: 2025-11-11
**Discovered By**: User visual inspection + ImageMagick systematic extraction

#### The Problem

Initial implementation used single 7px tall letter sprites, but letters appeared **cut off at the bottom** in the rendered window.

#### The Root Cause

**GEN.BMP letters are split into TWO separate sprite pieces:**

1. **Top portion**: 4 pixels tall (main body of letter)
2. **Bottom portion**: 3 pixels tall (serifs/feet of letters)
3. **Total height**: 7 pixels when combined

#### Coordinates (Verified by ImageMagick Extraction)

**Selected (bright) letters for active window:**
- Top piece: Y=86, Height=4
- Bottom piece: Y=90, Height=3
- Gap between pieces: 0px (stack directly)

**Normal (dim) letters for inactive window:**
- Top piece: Y=96, Height=4
- Bottom piece: Y=100, Height=3
- Gap between pieces: 0px (stack directly)

#### Extraction Test Commands

```bash
# Extract both pieces of letter M (selected)
magick /tmp/GEN.png -crop 8x4+86+86 /tmp/M_top.png     # Top 4px
magick /tmp/GEN.png -crop 8x3+86+90 /tmp/M_bottom.png  # Bottom 3px

# Combine to verify (should be complete 7px M)
magick /tmp/M_top.png /tmp/M_bottom.png -append /tmp/M_complete.png
open /tmp/M_complete.png
```

#### Implementation Pattern

**SkinSprites.swift** - Define both pieces:
```swift
// 32 sprites total: 8 letters × 2 pieces × 2 states
Sprite(name: "GEN_TEXT_SELECTED_M_TOP", x: 86, y: 86, width: 8, height: 4),
Sprite(name: "GEN_TEXT_SELECTED_M_BOTTOM", x: 86, y: 90, width: 8, height: 3),
Sprite(name: "GEN_TEXT_M_TOP", x: 86, y: 96, width: 8, height: 4),
Sprite(name: "GEN_TEXT_M_BOTTOM", x: 86, y: 100, width: 8, height: 3),
// ... repeat for I, L, K, D, R, O, P
```

**View Code** - Stack pieces vertically:
```swift
@ViewBuilder
private func makeLetter(_ letter: String, width: CGFloat, isActive: Bool) -> some View {
    let prefix = isActive ? "GEN_TEXT_SELECTED_" : "GEN_TEXT_"
    VStack(spacing: 0) {
        SimpleSpriteImage("\(prefix)\(letter)_TOP", width: width, height: 4)
        SimpleSpriteImage("\(prefix)\(letter)_BOTTOM", width: width, height: 3)
    }
}

// Usage in HStack
HStack(spacing: 0) {
    makeLetter("M", width: 8, isActive: true)
    makeLetter("I", width: 4, isActive: true)
    // ...
}
```

#### Why Webamp Might Not Show This

Webamp's CSS-based rendering likely uses:
- Background image positioning to show only top OR both pieces
- CSS `background-position` with negative offsets
- Single sprite request that includes both pieces in one image crop

Our bitmap-based extraction requires explicit handling of both pieces.

#### Lesson Learned

**ALWAYS visually verify sprite extraction at pixel level** when dealing with multi-color/multi-layer retro graphics. What appears as a single "letter" sprite may actually be composite pieces that must be assembled.

**Verification Workflow**:
1. Extract suspected sprite region
2. Visual inspection - does it look complete?
3. If cut off, search adjacent rows/columns for missing pieces
4. Test combinations until complete graphic is assembled
5. Document exact coordinates of all pieces


---

## Part 16: Webamp's GEN Letter Sprite Solution (2025-11-11)

### The Elegant Solution: Include the Separator

**Investigation**: Specialized Explore agent analyzed webamp_clone codebase completely

**Key Finding**: Webamp extracts **7-pixel tall sprites that INCLUDE the cyan separator**

### Webamp Extraction Code (skinParser.js, lines 107-128)

```javascript
const getLetters = (y, prefix) => {
  const getColorAt = (x) => context.getImageData(x, y, 1, 1).data.join(",");
  let x = 1;
  const backgroundColor = getColorAt(0);  // Cyan separator color
  const height = 7;  // FIXED - includes separator!
  
  return LETTERS.map((letter) => {
    let nextBackground = x;
    while (getColorAt(nextBackground) !== backgroundColor && nextBackground < canvas.width) {
      nextBackground++;
    }
    const width = nextBackground - x;
    const name = `${prefix}_${letter}`;
    const sprite = { x, y, height, width, name };
    x = nextBackground + 1;
    return sprite;
  });
};

// Extract both letter rows
const sprites = [
  ...getLetters(88, "GEN_TEXT_SELECTED"),  // Bright letters
  ...getLetters(96, "GEN_TEXT"),           // Dim letters
];
```

**What This Does**:
1. Samples at Y=88 (or Y=96) to detect letter boundaries
2. Uses color detection to find where each letter ends (hits cyan)
3. Extracts **7-pixel tall sprites** starting from that Y
4. The 7px naturally includes: top piece + cyan + bottom piece

### Why This Is Genius

**The cyan separator is NOT removed** - it's part of the sprite:

```
Extracted 7px sprite for "M":
Row 0-1: Top of letter (white/bright pixels)
Row 2:   Cyan separator (thin line)  ← INCLUDED
Row 3-6: Bottom of letter (white/bright pixels)
```

**Benefits**:
- ✅ Simple extraction (single sprite per letter)
- ✅ Authentic Winamp appearance (cyan is original design)
- ✅ Perfect alignment (no stacking/positioning math)
- ✅ Robust (works with any separator color or thickness)

### MacAmp Implementation

**SkinSprites.swift**:
```swift
// Single 7px sprite per letter (includes separator)
Sprite(name: "GEN_TEXT_SELECTED_M", x: 86, y: 86, width: 8, height: 7),
Sprite(name: "GEN_TEXT_M", x: 86, y: 96, width: 8, height: 7),
```

**View Code**:
```swift
HStack(spacing: 0) {
    SimpleSpriteImage("GEN_TEXT_SELECTED_M", width: 8, height: 7)  // Single sprite
    SimpleSpriteImage("GEN_TEXT_SELECTED_I", width: 4, height: 7)
    // ...
}
```

**No VStack needed, no piece combination, just render the 7px sprite as-is!**

### Coordinate Correction: Y=86 vs Y=88

**Webamp docs**: Y=88 and Y=96
**MacAmp reality**: Y=86 and Y=96

**Reason**: Different GEN.BMP variants or skin versions have 2px offset

**Verification method**:
```bash
# Test extraction at different Y values
magick GEN.png -crop 8x7+86+86 M_Y86.png  # Complete ✅
magick GEN.png -crop 8x7+86+88 M_Y88.png  # Top cut off ❌
```

**Lesson**: Always verify with actual bitmap extraction - don't trust docs blindly

### Final Pattern

**For any GEN.BMP letter rendering**:
1. Extract 7px tall sprites (includes separator)
2. Start at Y=86 (selected) or Y=96 (normal)
3. Variable width per letter (auto-detected or documented)
4. Render with SimpleSpriteImage - cyan separator shows naturally
5. Result: Authentic Winamp pixel-perfect letters


---

## Part 17: Day 7 Session - Complete Lessons Learned (2025-11-11)

### Executive Summary: GEN Sprite Integration Complexity

This session focused on integrating GEN.BMP sprites for the Milkdrop window titlebar and chrome. Multiple approaches were attempted, with significant learnings about sprite extraction, coordinate systems, and the complexity of GEN's two-piece letter system.

**Status**: Day 7 foundation work in progress - code will be reset, knowledge preserved

---

### Critical Discovery 1: GEN Letter Sprites Are Two Discontiguous Pieces

**The Problem**: Letters appeared cut off at the bottom when using documented coordinates.

**Root Cause**: Each GEN letter is **TWO separate sprites** separated by cyan boundary pixels:
- **Top piece**: 6 pixels tall
- **Cyan separator**: 1px (selected) or 6px+ (normal) 
- **Bottom piece**: 2px (selected) or 1px (normal)

**Verified Coordinates** (via ImageMagick systematic extraction):

**Selected (bright) letters**:
```
TOP: Y=88, H=6 (no cyan)
BOTTOM: Y=95, H=2 (no cyan)
Cyan gap at Y=94 (1px, excluded)
Total combined: 8px
```

**Normal (dim) letters**:
```
TOP: Y=96, H=6 (no cyan)
BOTTOM: Y=108, H=1 (no cyan, last pixel row of GEN.BMP)
Cyan gap at Y=102-107 (6px, excluded)
Total combined: 7px
```

**Implementation**:
```swift
// 32 sprites total: 8 letters × 2 pieces × 2 states
Sprite(name: "GEN_TEXT_SELECTED_M_TOP", x: 86, y: 88, width: 8, height: 6)
Sprite(name: "GEN_TEXT_SELECTED_M_BOTTOM", x: 86, y: 95, width: 8, height: 2)
Sprite(name: "GEN_TEXT_M_TOP", x: 86, y: 96, width: 8, height: 6)
Sprite(name: "GEN_TEXT_M_BOTTOM", x: 86, y: 108, width: 8, height: 1)

// VStack to combine pieces
VStack(spacing: 0) {
    SimpleSpriteImage("GEN_TEXT_SELECTED_M_TOP", width: 8, height: 6)
    SimpleSpriteImage("GEN_TEXT_SELECTED_M_BOTTOM", width: 8, height: 2)
}
```

**Key Insight**: Unlike webamp which includes cyan in the sprite (web can handle any pixels), MacAmp's ImageSlicing extracts exact rectangles - cyan boundaries must be explicitly excluded.

---

### Critical Discovery 2: Cyan Is A Boundary Marker (Not Display Content)

**User Clarification**: "The cyan should not be included - it's a boundary, a way to show the limits of the sprite. If there is cyan, it's not to be displayed - it shows the edge of sprites across all BMPs. You do this in every sprite in your entire project already."

**What This Means**:
- Cyan (#00C6FF, #00FFFF) pixels mark sprite boundaries
- These boundary pixels must NOT be extracted
- Extract only the clean sprite pixels between cyan boundaries
- This applies to ALL BMP sprite sheets (MAIN, GEN, VIDEO, PLEDIT, etc.)

**Testing Method**:
```bash
# Extract sprite and check for cyan
magick GEN.png -crop 8x6+86+88 test.png
magick test.png txt:- | grep "00C6FF"

# If cyan found: adjust Y coordinate or height
# Keep testing until no cyan in extracted sprite
```

---

### Critical Discovery 3: GEN Titlebar Has 6 Distinct Pieces

**Complete GEN.BMP Titlebar Specification** (from user):

```
Row 1 (Y=0-19): Active/selected titlebar
Row 2 (Y=21-40): Inactive titlebar

Each row has 6 pieces (separated by cyan):
1. TOP_LEFT (X=0): Left corner with close X button
2. TOP_LEFT_END (X=26): Fixed non-repeating graphic (gold with lines)
3. TOP_CENTER_FILL (X=52): Main title container (grey, repeatable for text area)
4. TOP_RIGHT_END (X=78): Non-repeating graphic (gold with lines)
5. TOP_LEFT_RIGHT_FILL (X=104): Horizontal scaling piece (gold, repeats when resizing)
6. TOP_RIGHT (X=130): Right corner (plain gold)
```

**Usage Pattern**:
- Pieces 1, 2, 4, 6 = **Used once each** (corners/transitions)
- Piece 3 (grey) = **Under "MILKDROP" text** (2-3 tiles constant)
- Piece 5 (gold) = **Scales with window width** (more tiles as window grows)

**WRONG Approach** (our mistake):
- Using only ONE piece (CENTER_FILL or LEFT_END) repeated across entire titlebar
- Results in monochrome titlebar (all grey or all gold)

**CORRECT Approach**:
- Use variety: corners → ends → scaling fills → grey center → scaling fills → ends → corners
- Gold on sides, grey under text
- Smooth visual transitions between piece types

---

### Critical Discovery 4: Window Dimension Standards

**MacAmp Window Heights** (confirmed):
```
Main:     275 × 116  (1× base height)
EQ:       275 × 116  (1×)
Playlist: 275 × 232  (2×) ← User confirmed
Video:    275 × 232  (2×) ← Matches Playlist
Milkdrop: 275 × 232  (2×) ← SHOULD match Playlist/Video
```

**Why This Matters**:
- GEN sprites designed for 275px width windows
- Using wider windows (384px, 512px) causes tile layout issues
- Vertical proportions matter for sprite alignment
- 232px height = 2× main window = standard for secondary windows

**Webamp Default**: 275×116 initially, but user-resizable
**Gemini Research**: Milkdrop has no fixed default, designed to be flexible

**MacAmp Decision**: Start at 275×232 (matches Video/Playlist), will add resize later

---

### Tool Discovery: ImageMagick for Sprite Coordinate Verification

**Essential Tool**: ImageMagick (`magick` command) for systematic sprite extraction testing

**Key Commands**:
```bash
# Extract sprite region
magick input.png -crop WIDTHxHEIGHT+X+Y output.png

# Example: Extract letter M top piece
magick /tmp/GEN.png -crop 8x6+86+88 /tmp/M_top.png

# Verify no cyan in extracted sprite
magick /tmp/M_top.png txt:- | grep "00C6FF"
# No output = clean extraction ✓

# Combine two pieces to verify complete letter
magick top.png bottom.png -append combined.png
open combined.png

# Extract horizontal strip to find Y position
magick /tmp/GEN.png -crop 194x10+0+85 /tmp/strip_Y85.png
```

**Workflow**:
1. Extract sprite at documented Y coordinate
2. Check pixel data for cyan (#00C6FF)
3. If cyan present: adjust Y or height
4. Test multiple Y values systematically
5. Verify extracted sprite is complete and clean
6. Document final coordinates

**Why This Is Critical**:
- Documentation may have errors or version differences
- Webamp docs (Y=88/96) vs actual GEN.BMP (Y=88/108) had offsets
- Visual inspection required - AI cannot reliably determine sprite coordinates
- Only way to ensure cyan boundaries are excluded

---

### Lesson 5: SwiftUI ZStack + .position() vs HStack for Tiling

**Problem**: HStack gets compressed by SwiftUI's layout system
**Solution**: Use ZStack with explicit .position() for each tile

**WRONG (HStack - gets compressed)**:
```swift
HStack(spacing: 0) {
    SimpleSpriteImage("TILE1", width: 25, height: 20)
    ForEach(0..<10) { _ in
        SimpleSpriteImage("TILE2", width: 25, height: 20)
    }
    SimpleSpriteImage("TILE3", width: 25, height: 20)
}
// Result: Tiles don't fill expected width, gaps appear
```

**CORRECT (ZStack with .position())**:
```swift
ZStack(alignment: .topLeading) {
    SimpleSpriteImage("TILE1", width: 25, height: 20)
        .position(x: 12.5, y: 10)  // Explicit position
    
    ForEach(0..<10) { i in
        SimpleSpriteImage("TILE2", width: 25, height: 20)
            .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
    }
    
    SimpleSpriteImage("TILE3", width: 25, height: 20)
        .position(x: 262.5, y: 10)
}
// Result: Tiles positioned exactly where specified, no gaps
```

**Pattern from VIDEO window** - proven to work for titlebar tiling

---

### Lesson 6: Coordinate System Confusion - NO Y-Flip Needed

**Initial Belief**: SkinSprites.swift might use Webamp top-down coords that need CGImage bottom-up conversion

**Oracle Investigation**: Confirmed that sprite extraction uses coordinates AS-IS from SkinSprites.swift
- No flipY() function exists or is needed
- CGImage.cropping operates in the same top-down coordinate space
- Y=0 is at top for both Webamp docs AND our extraction

**Implication**: Use documented Y coordinates directly, no conversion math needed

**Testing confirmed**: VIDEO window renders correctly with Y=0 at top, proving no flip occurs

---

### Lesson 7: Documentation vs Reality - Always Verify

**Webamp Documentation vs Actual GEN.BMP**:

| Source | Selected Letters Y | Normal Letters Y | Verified? |
|--------|-------------------|------------------|-----------|
| Webamp skinParser.js | 88 | 96 | Documented |
| ImageMagick extraction (top only) | 88 | 96 | ✓ Clean top pieces |
| ImageMagick extraction (7px full) | 86 | 96 | Earlier attempt |
| Final two-piece | TOP: 88, BOTTOM: 95 | TOP: 96, BOTTOM: 108 | ✓ No cyan |

**Why Offsets Exist**:
- Different GEN.BMP versions across Winamp releases
- Classic Winamp vs Winamp 5 vs Winamp 3 variations
- Skin variations (some skins have custom GEN.BMP)

**Lesson**: Never trust documentation alone - verify with actual bitmap extraction using ImageMagick

---

### Lesson 8: Observer Pattern for Window Visibility

**Pattern Used** (copied from VIDEO window, works perfectly):

```swift
// AppSettings - persistence
@Observable
@MainActor
final class AppSettings {
    var showMilkdropWindow: Bool = false {
        didSet {
            UserDefaults.standard.set(showMilkdropWindow, forKey: "showMilkdropWindow")
        }
    }
}

// WindowCoordinator - observer
private func setupMilkdropWindowObserver() {
    milkdropWindowTask?.cancel()
    
    milkdropWindowTask = Task { @MainActor [weak self] in
        guard let self else { return }
        
        withObservationTracking {
            _ = self.settings.showMilkdropWindow
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.settings.showMilkdropWindow {
                    self.showMilkdrop()
                } else {
                    self.hideMilkdrop()
                }
                self.setupMilkdropWindowObserver()  // Re-establish
            }
        }
    }
    
    // Honor initial state immediately
    if settings.showMilkdropWindow {
        showMilkdrop()
    }
}

// Keyboard shortcut
Button(settings.showMilkdropWindow ? "Hide Milkdrop" : "Show Milkdrop") {
    settings.showMilkdropWindow.toggle()
}
.keyboardShortcut("k", modifiers: [.control, .shift])
```

**Why This Works**:
- Single source of truth (AppSettings)
- Automatic persistence via didSet
- Reactive observer responds to all changes
- Works from button, menu, or keyboard
- Thread-safe with @MainActor

---

### Lesson 9: GEN.BMP Complete Structure (from User)

**Authoritative specification**:

```
GEN.BMP Layout (194×109 pixels):

ROW 1 (Y=0-19): Active titlebar - 6 pieces
ROW 2 (Y=21-40): Inactive titlebar - 6 pieces

Below titlebars:
- Y=42-55: Left bottom corner (125×14)
- Y=57-70: Right bottom corner (125×14)
- Y=42-70: Sidewalls (left 11×29, right 8×29)
- Y=42-51: Close button (9×9)
- Y=42-65: Bottom corner sidewalls (left 11×24, right 8×24 with resize grip)
- Y=72-85: Bottom fill tile (25×14, repeats horizontally when resizing)

- Y=86-92: Selected letters (top 6px) + separator
- Y=93-94: Cyan separator
- Y=95-96: Selected letters (bottom 2px)

- Y=96-101: Normal letters (top 6px)
- Y=102-107: Cyan separator (6px!)
- Y=108: Normal letters (bottom 1px, last row of image)
```

**Resizing Behavior**:
- **Titlebar**: LEFT_RIGHT_FILL (piece 5) tiles multiply as width grows
- **CENTER_FILL (piece 3)**: CONSTANT 2-3 tiles (50-75px) under "MILKDROP" text
- **Side borders**: MIDDLE_LEFT/RIGHT tile vertically as height grows
- **Bottom bar**: BOTTOM_FILL tiles multiply as width grows
- **Min size**: 275×116, **Max tested**: 464×464

---

### Lesson 10: Debugging Sprite Rendering Issues

**Symptoms Encountered**:
1. Letters cut off at bottom → Wrong Y coordinates
2. Cyan showing in letters → Not excluding boundary pixels
3. All-grey or all-gold titlebar → Using only one piece type repeatedly
4. Gaps between tiles → Incorrect position calculations
5. Side borders overlapping corners → Starting at Y=0 instead of Y=20

**Systematic Debugging Approach**:

```bash
# Step 1: Extract suspect sprite
magick GEN.png -crop WxH+X+Y test.png

# Step 2: Visual inspection
open test.png
# Does it look complete? Any cyan visible?

# Step 3: Pixel data analysis
magick test.png txt:- | grep "00C6FF"
# Cyan found = wrong coordinates

# Step 4: Test adjacent rows/columns
magick GEN.png -crop 8x6+86+86 M_Y86.png  # Too high
magick GEN.png -crop 8x6+86+88 M_Y88.png  # Just right ✓
magick GEN.png -crop 8x6+86+90 M_Y90.png  # Too low

# Step 5: Document verified coordinates
# Add to research.md and SkinSprites.swift
```

---

### Lesson 11: File Organization for Task Work

**WRONG Files Updated**:
- ❌ READY_FOR_NEXT_SESSION.md (only for end of session)
- ❌ Multiple premature updates to state.md

**CORRECT Files to Update**:
- ✓ todo.md - Check off completed tasks
- ✓ state.md - Update at end of day/major milestones
- ✓ research.md - Document discoveries and lessons learned
- ✓ READY_FOR_NEXT_SESSION.md - ONLY at actual session end

**Pattern**:
- Work incrementally
- Document in research.md as you learn
- Update todo.md frequently (task completion)
- Update state.md at day boundaries
- Update READY file when actually ending session

---

### Lesson 12: When to Reset and Start Fresh

**Indicators It's Time to Reset**:
1. Multiple approaches attempted without success
2. Code becoming increasingly complex/messy
3. Losing track of what works vs what doesn't
4. Good knowledge gained but implementation tangled

**Smart Reset Strategy**:
1. Document ALL lessons learned in research.md
2. Commit research.md (preserve knowledge)
3. Git reset --hard to last clean commit
4. Apply lessons correctly from the start

**This Session** - good candidate for reset:
- ✓ Learned GEN letter system (two-piece, verified coordinates)
- ✓ Learned 6-piece titlebar structure
- ✓ Learned window sizing (275×232)
- ✓ Learned cyan boundary exclusion principle
- ✗ Code has gaps, overlaps, incomplete rendering
- ✗ Multiple dimension changes (512→384→464→275)
- ✗ Titlebar tile calculations changed many times

**Better Approach**: Start fresh with all lessons, implement once correctly

---

### Lesson 13: ImageMagick Workflow for Sprite Sheets

**Essential workflow established**:

```bash
# 1. Convert BMP to PNG for easier viewing
sips -s format png input.BMP --out /tmp/output.png

# 2. View in Preview for interactive inspection
open -a Preview /tmp/output.png
# Tools → Show Inspector
# Use rectangular selection tool
# Inspector shows selection Width × Height

# 3. Systematic extraction testing
for y in 86 87 88 89 90; do
    magick /tmp/GEN.png -crop 8x6+86+$y /tmp/M_Y${y}.png
done

# 4. Find clean extraction (no cyan)
magick /tmp/M_Y88.png txt:- | grep "00C6FF" || echo "Y=88 is clean"

# 5. Test two-piece combination
magick /tmp/M_top.png /tmp/M_bottom.png -append /tmp/M_complete.png
open /tmp/M_complete.png

# 6. Document verified coordinates
# Add to SkinSprites.swift with comments
```

**Tools Available**:
- ✅ ImageMagick (installed)
- ✅ macOS Preview (coordinate inspection)
- ✅ Python + Pillow (programmatic extraction)

---

### Lesson 14: Sprite Naming Consistency

**Pattern for Two-Piece Sprites**:
```swift
// Clear suffix indicating which piece
GEN_TEXT_SELECTED_M_TOP      // ✓ Clear
GEN_TEXT_SELECTED_M_BOTTOM   // ✓ Clear

// Not:
GEN_TEXT_SELECTED_M          // ✗ Ambiguous if two pieces exist
GEN_TEXT_SELECTED_M_1        // ✗ Unclear what "1" means
```

**Total sprites for "MILKDROP"**:
- 8 letters (M, I, L, K, D, R, O, P)
- 2 pieces each (TOP, BOTTOM)
- 2 states (SELECTED, normal)
- **32 total letter sprites**

---

### Lesson 15: Content Area Coverage Issues

**Problem**: Black background or content area covering bottom portions of titlebar sprites

**GEN sprite structure**: Titlebar pieces have decorative elements that extend beyond the nominal 20px height

**Solution**: Ensure proper Z-ordering and positioning:
```swift
ZStack(alignment: .topLeading) {
    // 1. Background (bottom layer)
    Color.black.frame(width: 275, height: 232)
    
    // 2. Titlebar (middle layer) - positioned at top
    MilkdropTitlebar(...)
        .position(x: 137.5, y: 10)  // Y=10 for 20px titlebar
    
    // 3. Content (top layer) - starts BELOW titlebar
    content
        .frame(width: 256, height: 198)
        .position(x: 137.5, y: 119)  // Y=20 + (198/2) = 119
}
```

Content must start at Y=20 (below titlebar) to not cover titlebar decorations

---

### Key Learnings for @BUILDING_RETRO_MACOS_APPS_SKILL.md

1. **Cyan boundaries are universal** - all Winamp BMP sprite sheets use cyan to delimit sprites, must be excluded from extraction

2. **Two-piece sprites exist** - some sprites (like GEN letters) are discontiguous pieces that must be extracted separately and stacked

3. **ImageMagick is essential** - systematic sprite extraction testing required, documentation alone is insufficient

4. **Sprite variety matters** - using one piece repeatedly creates monotone visuals, must use proper sequence

5. **Window dimensions have patterns** - secondary windows often 2× main window height (232px vs 116px)

6. **Reset when tangled** - preserving knowledge + clean start > continuing with messy code

---

### Deferred Work (For Fresh Implementation)

**What Needs Completion**:
1. ✅ Milkdrop window foundation (275×232)
2. ✅ GEN sprite integration (all pieces identified)
3. ✅ Letter sprites (32 sprites, coordinates verified)
4. ⚠️ Titlebar tile layout (known structure, implementation incomplete)
5. ⚠️ Side border positioning (overlaps corners currently)
6. ⚠️ Bottom chrome integration
7. ⏳ Resize functionality (deferred, spec documented)

**With Clean Start, We Can**:
- Implement titlebar with correct 6-piece sequence from the beginning
- Use verified letter coordinates (no trial and error)
- Apply 275×232 dimensions from start
- Follow VIDEO window ZStack pattern exactly
- Avoid dimension thrashing (512→384→464→275)

---

**Session End**: Comprehensive knowledge captured, ready for clean re-implementation

**Files to Preserve**:
- tasks/milk-drop-video-support/research.md (this file) ← KEEP
- tasks/milk-drop-video-support/MILKDROP_RESIZE_SPEC.md ← KEEP
- tasks/milk-drop-video-support/TITLEBAR_EDITING_GUIDE.md ← KEEP

**Files to Reset**:
- All MacAmpApp/*.swift files
- All task tracking files (todo.md, state.md)
- READY_FOR_NEXT_SESSION.md

**Next Session Start**:
With this knowledge, Day 7 implementation should be straightforward:
1. Window: 275×232 (known)
2. Letters: 32 sprites with verified coordinates (known)
3. Titlebar: 6-piece sequence with proper tiles (known)
4. Pattern: Follow VIDEO window ZStack approach (proven)

Estimated: 2-3 hours for clean implementation vs 8+ hours of exploration this session.


---

## WORKING CODE: MILKDROP Letter Extraction and Rendering

**Status**: ✅ THIS CODE WORKS CORRECTLY - Preserve for re-implementation

### SkinSprites.swift - Letter Sprite Definitions (32 sprites)

```swift
// In "GEN" sprite array:

// Letter sprites for titlebar text (GEN.BMP 194×109)
// CRITICAL: Letters are TWO DISCONTIGUOUS pieces separated by cyan boundaries
// Verified by ImageMagick extraction testing (no PNG conversion needed)
// Selected: TOP Y=88 H=6, BOTTOM Y=95 H=2 (1px cyan gap at Y=94)
// Normal: TOP Y=96 H=6, BOTTOM Y=108 H=1 (6px cyan gap at Y=102-107)

// Selected (focused) letter TOPS - Y=88, H=6 (no cyan)
Sprite(name: "GEN_TEXT_SELECTED_M_TOP", x: 86, y: 88, width: 8, height: 6),
Sprite(name: "GEN_TEXT_SELECTED_I_TOP", x: 60, y: 88, width: 4, height: 6),
Sprite(name: "GEN_TEXT_SELECTED_L_TOP", x: 80, y: 88, width: 5, height: 6),
Sprite(name: "GEN_TEXT_SELECTED_K_TOP", x: 72, y: 88, width: 7, height: 6),
Sprite(name: "GEN_TEXT_SELECTED_D_TOP", x: 24, y: 88, width: 6, height: 6),
Sprite(name: "GEN_TEXT_SELECTED_R_TOP", x: 124, y: 88, width: 7, height: 6),
Sprite(name: "GEN_TEXT_SELECTED_O_TOP", x: 102, y: 88, width: 6, height: 6),
Sprite(name: "GEN_TEXT_SELECTED_P_TOP", x: 109, y: 88, width: 6, height: 6),

// Selected (focused) letter BOTTOMS - Y=95, H=2 (no cyan)
Sprite(name: "GEN_TEXT_SELECTED_M_BOTTOM", x: 86, y: 95, width: 8, height: 2),
Sprite(name: "GEN_TEXT_SELECTED_I_BOTTOM", x: 60, y: 95, width: 4, height: 2),
Sprite(name: "GEN_TEXT_SELECTED_L_BOTTOM", x: 80, y: 95, width: 5, height: 2),
Sprite(name: "GEN_TEXT_SELECTED_K_BOTTOM", x: 72, y: 95, width: 7, height: 2),
Sprite(name: "GEN_TEXT_SELECTED_D_BOTTOM", x: 24, y: 95, width: 6, height: 2),
Sprite(name: "GEN_TEXT_SELECTED_R_BOTTOM", x: 124, y: 95, width: 7, height: 2),
Sprite(name: "GEN_TEXT_SELECTED_O_BOTTOM", x: 102, y: 95, width: 6, height: 2),
Sprite(name: "GEN_TEXT_SELECTED_P_BOTTOM", x: 109, y: 95, width: 6, height: 2),

// Normal (unfocused) letter TOPS - Y=96, H=6 (no cyan)
Sprite(name: "GEN_TEXT_M_TOP", x: 86, y: 96, width: 8, height: 6),
Sprite(name: "GEN_TEXT_I_TOP", x: 60, y: 96, width: 4, height: 6),
Sprite(name: "GEN_TEXT_L_TOP", x: 80, y: 96, width: 5, height: 6),
Sprite(name: "GEN_TEXT_K_TOP", x: 72, y: 96, width: 7, height: 6),
Sprite(name: "GEN_TEXT_D_TOP", x: 24, y: 96, width: 6, height: 6),
Sprite(name: "GEN_TEXT_R_TOP", x: 124, y: 96, width: 7, height: 6),
Sprite(name: "GEN_TEXT_O_TOP", x: 102, y: 96, width: 6, height: 6),
Sprite(name: "GEN_TEXT_P_TOP", x: 109, y: 96, width: 6, height: 6),

// Normal (unfocused) letter BOTTOMS - Y=108, H=1 (no cyan, at image edge)
Sprite(name: "GEN_TEXT_M_BOTTOM", x: 86, y: 108, width: 8, height: 1),
Sprite(name: "GEN_TEXT_I_BOTTOM", x: 60, y: 108, width: 4, height: 1),
Sprite(name: "GEN_TEXT_L_BOTTOM", x: 80, y: 108, width: 5, height: 1),
Sprite(name: "GEN_TEXT_K_BOTTOM", x: 72, y: 108, width: 7, height: 1),
Sprite(name: "GEN_TEXT_D_BOTTOM", x: 24, y: 108, width: 6, height: 1),
Sprite(name: "GEN_TEXT_R_BOTTOM", x: 124, y: 108, width: 7, height: 1),
Sprite(name: "GEN_TEXT_O_BOTTOM", x: 102, y: 108, width: 6, height: 1),
Sprite(name: "GEN_TEXT_P_BOTTOM", x: 109, y: 108, width: 6, height: 1),
```

### WinampMilkdropWindow.swift - Letter Rendering Code

```swift
// Helper function to build a two-piece letter (excluding cyan boundaries)
// Selected: TOP (6px) + BOTTOM (2px) = 8px total
// Normal: TOP (6px) + BOTTOM (1px) = 7px total
@ViewBuilder
private func makeLetter(_ letter: String, width: CGFloat, isActive: Bool) -> some View {
    let prefix = isActive ? "GEN_TEXT_SELECTED_" : "GEN_TEXT_"
    VStack(spacing: 0) {
        SimpleSpriteImage("\(prefix)\(letter)_TOP", width: width, height: 6)
        SimpleSpriteImage("\(prefix)\(letter)_BOTTOM", width: width, height: isActive ? 2 : 1)
    }
}

// Usage in titlebar:
HStack(spacing: 0) {
    makeLetter("M", width: 8, isActive: isActive)
    makeLetter("I", width: 4, isActive: isActive)
    makeLetter("L", width: 5, isActive: isActive)
    makeLetter("K", width: 7, isActive: isActive)
    makeLetter("D", width: 6, isActive: isActive)
    makeLetter("R", width: 7, isActive: isActive)
    makeLetter("O", width: 6, isActive: isActive)
    makeLetter("P", width: 6, isActive: isActive)
}
.position(x: 137.5, y: 9)  // Centered in 275px titlebar, Y=9 (slightly up)
```

### Verification Commands (ImageMagick)

```bash
# Verify selected letter M extraction (should show complete letter, no cyan)
magick /tmp/GEN.png -crop 8x6+86+88 /tmp/M_sel_top.png
magick /tmp/GEN.png -crop 8x2+86+95 /tmp/M_sel_bottom.png
magick /tmp/M_sel_top.png /tmp/M_sel_bottom.png -append /tmp/M_selected_complete.png
magick /tmp/M_selected_complete.png txt:- | grep "00C6FF"  # Should return nothing

# Verify normal letter M extraction
magick /tmp/GEN.png -crop 8x6+86+96 /tmp/M_norm_top.png
magick /tmp/GEN.png -crop 8x1+86+108 /tmp/M_norm_bottom.png
magick /tmp/M_norm_top.png /tmp/M_norm_bottom.png -append /tmp/M_normal_complete.png
magick /tmp/M_normal_complete.png txt:- | grep "00C6FF"  # Should return nothing

# Visual check
open /tmp/M_selected_complete.png /tmp/M_normal_complete.png
```

**Result**: Complete letters with no cyan boundaries, ready for rendering

---

**IMPORTANT**: This letter extraction approach is VERIFIED WORKING. Use these exact coordinates and the two-piece VStack pattern when re-implementing from clean start.

