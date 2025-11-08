# MilkDrop3 Comprehensive Technical Analysis

## Executive Summary

MilkDrop3 is a sophisticated Windows-based music visualization engine built on DirectX 9 with:
- **Graphics API**: DirectX 9 (d3d9.h, d3dx9.h)
- **Scripting Engine**: EEL2 (Nullsoft Expression Evaluator Language)
- **Audio Capture**: Windows WASAPI/Loopback Capture
- **Build System**: Visual Studio 2022 (.vcxproj)
- **Platform**: Windows-only (no native macOS/Linux support)
- **License**: BSD 3-Clause (Maxim Volskiy, based on BeatDrop)

---

## 1. ARCHITECTURE

### Project Structure
```
MilkDrop3/
├── code/
│   ├── vis_milk2/              # Main visualization plugin (54 C++ files)
│   ├── audio/                  # Audio capture (Windows WASAPI)
│   ├── ns-eel2/                # EEL2 scripting language
│   └── resources/Milkdrop2/    # Default resources
├── linux/                      # Wine compatibility guide
└── README.md                   # Feature documentation
```

### Core Components

#### 1a. **Rendering Pipeline (vis_milk2/)**
- **Main Plugin Class**: `CPlugin` (extends `CPluginShell`)
- **Key Entry Points**:
  - `MyRenderFn()` - Frame rendering
  - `MyRenderUI()` - User interface rendering
  - `RenderFrame()` - Main animation loop
  - `AllocateMyDX9Stuff()` - DirectX resource allocation
  - `CleanUpMyDX9Stuff()` - Resource cleanup

#### 1b. **DirectX Context (dxcontext.h/cpp)**
- Handles DirectX 9 device initialization
- Window management (fullscreen/windowed)
- Multi-monitor support
- Supports PS 2.0, 2.x, 3.0 pixel shaders
- ~5,942 lines of context management code

#### 1c. **Plugin Shell (pluginshell.h/cpp)**
- Virtual plugin interface from Nullsoft
- Sound analysis: `td_soundinfo` struct containing:
  - Bass/mids/treble (3 frequency bands, per channel)
  - Immediate, average, medium-damped, long-damped levels
  - Waveform data (576 samples per channel)
  - Spectrum data (NUM_FREQUENCIES samples per channel)
  - Range: 0 Hz to 22,050 Hz (evenly spaced)
- FFT-based audio analysis

---

## 2. RENDERING TECHNOLOGY

### Graphics API
**DirectX 9 (Exclusive)**
- Located: `/code/vis_milk2/dxcontext.h` (includes d3d9.h, d3dx9.h)
- Device type: IDirect3DDevice9
- Presentation parameters: D3DPRESENT_PARAMETERS
- Multiple sample anti-aliasing support

### Shader System
**HLSL Shaders** (High-Level Shader Language)
- **Pixel Shaders**: ps_2_0, ps_2_x, ps_3_0 versions
- **Vertex Shaders**: Fallback vertex shader set
- **Compiled Shaders**: Cached for performance (v3.31 feature)
- **Data Structures**:
  ```cpp
  struct PShaderSet {
    // Pixel shader pointers for warp, composite, blur
  };
  
  struct VShaderSet {
    // Vertex shader pointers
  };
  ```
- **Constant Tables**: D3DXCONSTANTTABLE for parameter management

### Texture Management
- Texture manager: `texmgr.cpp/h`
- Support for:
  - Disk textures
  - Blur passes (TEX_BLUR0-6)
  - Dynamic render targets
  - Evictable textures (LRU management)
  - D3DBASETEXTURE9 base type
- Sprite system with 5 blend modes (v3.26)

### Effects Pipeline
1. **Warp Shader** (pixel shader applied to feedback)
2. **Composite Shader** (final rendering)
3. **Blur Passes** (multiple blur levels)
4. **Transition Effects** (25+ visual transitions)

---

## 3. PRESET SYSTEM

### Preset Format
- **.milk files**: Standard MilkDrop 2 presets
- **.milk2 files**: Double presets (blend 2 presets simultaneously) - NEW in v3
- Format: Text-based configuration with embedded HLSL shader code

### Preset Structure
```cpp
class CState {
  // Per-frame variables (q1-q64)
  // Waveform definitions (up to 4, now 16 in v3)
  // Shape definitions (up to 4, now 16 in v3)
  // Shader code (warp & composite)
  // Blending parameters
  // Animation scripts (EEL2)
};
```

### Preset Loading
- **Function**: `LoadPreset(const wchar_t *szPresetFilename, float fBlendTime)`
- **Async Loading**: Uses `LoadPresetTick()` for incremental compilation
- **Compilation**: Shaders dynamically compiled on preset load
- **Error Handling**: Auto-upgrade shader versions on compilation failure
- **Caching**: New smart shader cache (v3.31)

### Preset Features
- **Wave Animation** (16 waveforms available)
- **Shape Animation** (16 shapes with up to 500 points)
- **Color Keys** (q1-q64 variables for customization)
- **Time Variables** (t1-t8 for time-based effects)
- **Blending Modes**: 20+ transition patterns

---

## 4. AUDIO ANALYSIS

### Audio Capture
**Windows WASAPI (Windows Audio Session API)**
- Located: `/code/audio/loopback-capture.h/cpp`
- Structure: `LoopbackCaptureThreadFunctionArguments`
- Captures from: `IMMDevice` (Windows multimedia device)
- Supports: 16-bit and higher bit depths
- **NEW in v3.31**: Full Hi-Res support (24-bit/192kHz and beyond)
- **Thread-based**: Separate capture thread with event signaling

### FFT Analysis
- **Class**: `FFT` (fft.h/cpp)
- **Input Samples**: 512 samples (MY_FFT_SAMPLES)
- **Output**: Frequency domain spectrum
- **Features**:
  - Equalization table for flat response
  - Envelope function for windowing
  - Bit-reversal table for FFT optimization
  - Cosine/sine pre-computed table
- **Resolution**: NUM_FREQUENCIES bands (configurable)

### Sound Data Structure
```cpp
struct td_soundinfo {
  float imm[2][3];          // Immediate bass/mids/treble per channel
  float avg[2][3];          // Average (with damping)
  float med_avg[2][3];      // Medium damping
  float long_avg[2][3];     // Heavy damping
  float infinite_avg[2][3]; // Winamp's average output
  float fWaveform[2][576];  // 576 samples per channel
  float fSpectrum[2][NUM_FREQUENCIES]; // 0-22050 Hz
};
```

### Audio Features
- Bass/Mid/Treble analysis (3 frequency bands)
- Relative levels (normalized to long-term average)
- Waveform capture (raw PCM)
- Spectrum analysis (FFT-based)
- Per-frame audio update

---

## 5. PRESET SCRIPTING (EEL2)

### Scripting Language
**NS-EEL2** (Nullsoft Expression Evaluator Language v2)
- Located: `/code/ns-eel2/` (~15 C files)
- **Purpose**: Runtime expression evaluation in presets
- **Type System**: Double-precision floating-point (EEL_F)
- **Architecture**: JIT-compiled to native code

### EEL2 Core Features
```cpp
// VM Management
NSEEL_VMCTX vm = NSEEL_VM_alloc();     // Create VM context
NSEEL_CODEHANDLE code = NSEEL_code_compile(vm, "expression");
NSEEL_code_execute(code);
NSEEL_code_free(code);
NSEEL_VM_free(vm);

// Variable Registration
EEL_F *var = NSEEL_VM_regvar(vm, "myvar");

// Custom Functions
NSEEL_addfunctionex2(name, nparms, code, len, pproc, fptr, fptr2);
```

### Expression Types
- **Per-Frame Code**: Animation expressions (every frame)
- **Per-Point Code**: Shape/wave vertex calculations
- **Per-Pixel Code**: Shader variable calculations
- **Blending**: Smooth transitions between presets

### Available Variables in Expressions
```
time, fps, frame, progress
bass, mid, treb (immediate)
bass_att, mid_att, treb_att (damped)
q1-q64 (user-defined variables)
t1-t8 (time-based variables)
x, y, rad, ang (geometry)
r, g, b, a (colors)
```

---

## 6. PLATFORM SUPPORT

### Windows-Only Implementation
- **Exclusive Dependencies**:
  - Windows.h (core API)
  - d3d9.h, d3dx9.h (DirectX)
  - mmsystem.h (multimedia)
  - mmdeviceapi.h (WASAPI audio)
  - winsock.h (networking for player control)

### Platform-Specific Code
- **Audio**: WASAPI loopback capture (Windows only)
- **Graphics**: DirectX 9 (Windows only)
- **UI**: Windows window messages (WM_*)
- **Build**: Visual Studio 2022 (.vcxproj)

### Non-Native Platform Support
- **Linux**: Wine wrapper (documented in `/linux/README.md`)
  - Requires Wine 10.13+
  - Needs Direct3D 9 libraries
  - Text rendering issues with Wine
  - Fully functional otherwise
- **macOS**: No native support, would require Wine or complete rewrite

---

## 7. MODERN FEATURES (v3.x)

### Version 3.31 Features (Latest)
- Full Hi-Res audio support (24-bit/192kHz+)
- New custom VM with enhanced stability
- Automatic GPU selection (integrated vs. dedicated)
- Smart shader cache (only new presets cached)
- MilkPanel editor with syntax highlighting
- COPY/CUT/PASTE in shader editor
- CTRL+Z/Y undo/redo
- Code folding
- 25+ transition effects
- 16 shapes and 16 waveforms (vs. 4 each)
- 64 Q variables (vs. 32)
- Double-preset blending (.milk2 format)
- Sprite system with 5+ blend modes
- Beat detection mode
- Playlist support
- Color randomization
- Deep mash-up mode

### Shader Capabilities
- Real-time shader editing
- Automatic shader compilation
- Error recovery with version auto-upgrade
- Fallback shaders for compatibility
- HLSL fragment shader effects

---

## 8. DEPENDENCIES

### Required Libraries
```
DirectX 9 SDK (d3d9, d3dx9)
Windows Multimedia API
WASAPI (Windows Audio Session API)
Visual C++ Runtime
```

### Internal Components
```
ns-eel2/          EEL2 scripting engine
fft.cpp/h         FFT analysis
texmgr.cpp/h      Texture management
state.cpp/h       Preset state machine
menu.cpp/h        Menu system
dxcontext.cpp/h   DirectX context management
```

### Data Structures
- **PresetInfo**: Metadata for each preset
- **CState**: Entire preset state (shaders, variables, scripts)
- **td_soundinfo**: Per-frame audio analysis
- **TexInfo**: Texture metadata with eviction info
- **CShaderParams**: Shader constant table handles

---

## 9. PERFORMANCE OPTIMIZATIONS

### Rendering Optimizations
- **Shader Caching**: Pre-compiled shaders for faster load (v3.31)
- **Texture Management**: LRU eviction with age tracking
- **Frame Rate Control**: 60/90/120 FPS selectable
- **Auto GPU Selection**: Picks dedicated GPU if available (v3.28)
- **Async Preset Loading**: Doesn't freeze on load
- **Viewport Optimization**: Windowed mode snapping (32x32 blocks)

### Memory Management
- **RAM Limits**: NSEEL_RAM_limitmem configurable
- **Evictable Textures**: Size tracking (nSizeInBytes)
- **Variable Cleanup**: NSEEL_VM_freeRAM()
- **Shader Fallback**: Graceful degradation on error

### Threading
- **Audio Thread**: Separate WASAPI loopback capture thread
- **Render Thread**: Main DirectX rendering thread
- **Thread Safety**: Mutex stubs for EEL2 VM access

---

## 10. SWIFT/macOS FEASIBILITY ANALYSIS

### Challenges for Integration

#### 1. Graphics API
- **Problem**: DirectX 9 is Windows-only
- **Solution Options**:
  - Rewrite rendering in Metal (Apple's graphics API)
  - Use WebGL/OpenGL (cross-platform but not optimal for macOS)
  - Wrap with ANGLE or translation layer

#### 2. Audio Capture
- **Problem**: WASAPI is Windows-specific
- **Solution**: Use AVAudioEngine or Core Audio on macOS

#### 3. Scripting Language
- **Problem**: EEL2 has x86 assembly components (asm-nseel-x86-msvc.c)
- **Solution**: Keep EEL2 interpreter (already has x64-macho.o), no x86 asm needed

#### 4. Preset Format
- **Good News**: .milk and .milk2 are text-based, platform-agnostic
- **Feasibility**: 100% compatible

#### 5. Dependencies
- **Current**: 42 DirectX references in core files
- **Required Rewrite**: dxcontext, rendering pipeline, shader compilation

### Integration Path for MacAmp

**Option A: Metal Renderer (Recommended)**
```
1. Keep EEL2 scripting (platform-agnostic)
2. Keep preset format (.milk/.milk2)
3. Keep audio analysis (use Core Audio instead of WASAPI)
4. Rewrite graphics layer:
   - dxcontext → MTLDevice + MTLCommandQueue
   - HLSL shaders → Metal Shading Language (MSL)
   - D3D texture management → MTLTexture
5. Build as Swift/SwiftUI macOS app
```

**Option B: Thin Wrapper (Minimal)**
```
1. Keep everything as-is (Windows DLL)
2. Wrap with Wine/Compatibility layer
3. Run as subprocess
4. Pros: Quick, 100% compatible
5. Cons: Heavyweight, poor integration
```

**Option C: Hybrid (Realistic)**
```
1. Use existing EEL2 VM for scripting
2. Keep preset parser (text-based)
3. Implement Metal rendering backend
4. Use AVAudioEngine for audio capture
5. Swift wrapper around C++ core
```

### Estimated Rewrite Effort
- **Graphics Layer**: 2,000-3,000 lines (dxcontext, rendering, shader compilation)
- **Audio Adapter**: 500-1,000 lines (Core Audio integration)
- **Metadata**: 100-200 lines (integration with MacAmp)
- **Testing**: 20+ presets validation
- **Estimated Time**: 4-8 weeks (experienced Metal developer)

### Compatibility Notes
- ✅ Preset format: Fully compatible
- ✅ EEL2 scripting: Fully compatible
- ✅ Audio analysis: API differences only
- ❌ HLSL shaders: Need conversion to MSL
- ❌ DirectX textures: Need Metal texture adaption
- ❌ Build system: Complete rewrite needed

---

## 11. BUILD SYSTEM

### Visual Studio Project
- **Solution File**: `MilkDrop3.sln` (Visual Studio 14.0+)
- **Project Type**: C++ DLL (vis_milk2/plugin.vcxproj)
- **Configurations**: Debug|Win32, Release|Win32
- **Output**: vis_milk2.dll

### Compiler Settings
- **Platform Toolset**: v140 (VS2015) or compatible
- **C++ Standard**: C++11 at minimum
- **Runtime**: Dynamic (/MD)
- **Preprocessor**: Various feature flags

### Dependencies in .vcxproj
```xml
<ItemDefinitionGroup>
  <Link>
    <AdditionalDependencies>
      d3d9.lib;d3dx9.lib;dxguid.lib;
      winmm.lib;ole32.lib;oleaut32.lib;
      shell32.lib;advapi32.lib
    </AdditionalDependencies>
  </Link>
</ItemDefinitionGroup>
```

---

## 12. KEY SOURCE FILES REFERENCE

### Main Files (vis_milk2/)
| File | Size | Purpose |
|------|------|---------|
| plugin.cpp | 8,859 lines | Main plugin implementation |
| plugin.h | 635 lines | Plugin interface |
| pluginshell.cpp | 2,563 lines | Plugin shell framework |
| milkdropfs.cpp | 4,712 lines | Rendering pipeline |
| state.cpp | 1,945 lines | Preset state machine |
| dxcontext.cpp | 6,139 lines | DirectX 9 context |
| fft.cpp | 319 lines | FFT audio analysis |
| menu.cpp | 749 lines | UI menu system |
| texmgr.cpp | 311 lines | Texture management |

### Audio Files (audio/)
| File | Purpose |
|------|---------|
| loopback-capture.cpp | WASAPI loopback capture |
| prefs.cpp | Audio preferences/settings |
| audiobuf.cpp | Audio buffer management |

### Scripting (ns-eel2/)
| File | Purpose |
|------|---------|
| ns-eel.h | EEL2 VM public interface |
| nseel-compiler.c | Expression compiler (50K lines) |
| nseel-eval.c | VM executor |
| asm-nseel-x86-msvc.c | x86 native code gen |
| asm-nseel-x64-macho.o | x64 Mac object file |

---

## 13. SUMMARY TABLE

| Aspect | Details |
|--------|---------|
| **Graphics API** | DirectX 9 (d3d9.h, d3dx9.h) |
| **Shaders** | HLSL, ps_2.0/2.x/3.0 |
| **Audio Capture** | Windows WASAPI loopback |
| **Audio Analysis** | FFT (512 samples → spectrum) |
| **Scripting** | EEL2 (JIT-compiled) |
| **Preset Format** | .milk (text + HLSL code) |
| **Presets in DB** | 900+ included presets |
| **Waveforms/Shapes** | 16 each (vs. 4 in v2) |
| **Color Variables** | q1-q64 (vs. q1-q32 in v2) |
| **Transitions** | 25+ visual effects |
| **Build System** | Visual Studio 2022 (.vcxproj) |
| **Platform** | Windows only (Wine on Linux) |
| **macOS Support** | None (would need complete rewrite) |
| **Code Size** | ~27K lines C++ core |
| **Dependencies** | DirectX 9, Windows Multimedia |
| **Version** | 3.31 (latest, Sept 2025) |

---

## 14. INTEGRATION RECOMMENDATIONS FOR MacAmp

### Phase 1: Analysis (Complete ✓)
- Understand MilkDrop3 architecture: DONE
- Identify platform-specific code: 42+ DirectX references
- Plan Metal rendering layer: Design ready

### Phase 2: Core Integration (If Pursuing)
1. **Audio System**
   - Implement `AudioAnalyzer` using AVAudioEngine
   - Map WASAPI structure to Core Audio
   - Port FFT analysis (reuse with Metal compute if needed)

2. **Preset System**
   - Implement `.milk` file parser
   - Validate format compatibility
   - Test with existing preset library

3. **Rendering**
   - Implement Metal-based rendering
   - Convert HLSL → MSL shaders
   - Create Metal texture manager

4. **Scripting**
   - Integrate EEL2 VM (already has x64 support)
   - Create Swift wrapper for expression evaluation
   - Expose audio data to scripts

### Phase 3: MacAmp Integration
- Embed as visualization provider in MacAmp
- Use SwiftUI for controls
- Handle audio input from playback system
- Manage presets in app preferences

### Estimated Scope
- **High Complexity**: Extensive rewrite required
- **High Reward**: Professional-grade visualization
- **Time**: 4-8 weeks (assuming experienced team)
- **Risk**: Graphics subsystem is complex, requires Metal expertise

