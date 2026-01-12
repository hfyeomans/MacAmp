# MacAmp

![Platform](https://img.shields.io/badge/platform-macOS%2015.0+-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)
![Version](https://img.shields.io/badge/version-1.0.5-brightgreen)
![Notarized](https://img.shields.io/badge/Notarized-Apple%20Approved-brightgreen?logo=apple)
![Maintained](https://img.shields.io/badge/maintained-yes-green)

A pixel-perfect, native macOS audio player that brings the classic desktop audio player experience to modern Apple Silicon Macs with full skin compatibility.

![MacAmp Screenshot](docs/screenshots/macamp-main.png)

## Overview

MacAmp is a SwiftUI-based audio player for macOS that recreates the iconic desktop audio player interface with modern enhancements. Built specifically for **macOS Sequoia (15.0+)** and **macOS Tahoe (26.0+)**, it leverages the latest SwiftUI features while maintaining pixel-perfect fidelity to classic skins.

### Key Features

- 🎨 **Full Skin Support** - Load and switch between classic `.wsz` skins with full sprite and color support
- 🎵 **Native Audio Engine** - Built on AVFoundation for optimal macOS performance
- 🎚️ **10-Band Equalizer** - Professional audio control with 17 built-in presets
- 📊 **Spectrum Analyzer & Oscilloscope** - Click visualizer to cycle through 3 modes: Spectrum (frequency bars), Oscilloscope (waveform), or None
- ⌨️ **Keyboard Navigation** - Navigate playlist menus with arrow keys (↑↓) and Escape
- ♿ **VoiceOver Ready** - Accessible menu navigation for screen reader users
- 📋 **M3U/M3U8 Playlists** - Load playlists with local files and internet radio streams
- 📻 **Internet Radio** - Stream HTTP/HTTPS radio with live metadata
- 📂 **Playlist Menus** - Sprite-based popup menus for ADD, REM, MISC, and LIST OPTS with hover states
- ✨ **Multi-Select** - Shift+Click to select multiple tracks, Command+A to select all, with CROP and remove operations
- 📝 **Native Text Rendering** - Playlist tracks use real text with PLEDIT.txt colors and Unicode support (not bitmap fonts)
- 🎛️ **Advanced Controls** - Volume, balance, position seeking, shuffle, and three-state repeat (Off/All/One)
- 🔄 **Three-State Repeat** - Winamp 5 Modern fidelity with Off/All/One modes and "1" badge indicator (Ctrl+R to cycle)
- 🪟 **Multi-Window Interface** - Main player, equalizer, playlist, and video windows with shade modes
- 📐 **Resizable Playlist** - Drag to resize in 25×29px segments with dynamic tiling and scroll slider
- 📊 **Playlist Visualizer** - Mini spectrum analyzer in playlist when main window is shaded
- 📺 **Video Playback** - Native video support (MP4, MOV, M4V) with V button or Ctrl+V
- 🎬 **Video Window** - Skinnable video window with VIDEO.bmp chrome or classic fallback
- 🔲 **Full Video Resize** - Drag any size with 25×29px quantized segments (1x/2x preset buttons)
- 🎚️ **Unified Video Controls** - Volume slider, seek bar, and time display work for both audio and video
- 📝 **Video Metadata Ticker** - Auto-scrolling display showing filename, codec, and resolution
- 🎨 **Butterchurn Visualizations** - 245 Milkdrop 2 presets with 60 FPS audio-reactive WebGL rendering
- 🌀 **Preset Controls** - Cycle (Space/Backspace), randomize (R), auto-cycle intervals, context menu selection
- 🖼️ **Milkdrop Window Resize** - Drag corner with 25×29px segment grid and dynamic titlebar expansion
- 🖼️ **5-Window Architecture** - Main, Equalizer, Playlist, VIDEO, and Milkdrop windows with unified focus tracking
- 🧲 **Magnetic Docking** - Windows snap together and stay docked when resizing (Ctrl+D compatible)
- 🔍 **Double-Size Mode** - Toggle 200% scaling with D button or Ctrl+D for better visibility on high-res displays
- 📌 **Always On Top** - Keep window floating above others with A button or Ctrl+A (Classic Winamp feature)
- ⚙️ **Options Menu** - Quick access to player settings via O button or Ctrl+O with time display toggle (Ctrl+T)
- ℹ️ **Track Information** - View detailed track/stream metadata with I button or Ctrl+I
- 🎯 **Native macOS Integration** - Borderless windows with custom title bars
- ⚡ **Modern SwiftUI** - Utilizes WindowDragGesture and latest macOS APIs
- 🔄 **Dynamic Skin Switching** - Hot-swap skins without restart
- 📦 **Distribution Ready** - Developer ID signed builds for /Applications installation
- 🚀 **Swift 6 Architecture** - Modern, performant, future-proof codebase

## Requirements

- **macOS Sequoia 15.0+** or **macOS Tahoe 26.0+**
- **Apple Silicon** (M1/M2/M3/M4) or Intel Mac
- **Xcode 26.0+** (for building from source)

## Download

### Latest Release: v1.0.5 (January 2026)

[![Download MacAmp](https://img.shields.io/badge/Download-MacAmp%20v1.0.5-blue?style=for-the-badge)](https://github.com/hfyeomans/MacAmp/releases/tag/v1.0.5)

**[Download MacAmp-1.0.5.dmg](https://github.com/hfyeomans/MacAmp/releases/tag/v1.0.5)** (2.7 MB)

| Property | Value |
|----------|-------|
| Version | 1.0.5 |
| Build | 5 |
| Signed | Developer ID Application |
| Notarized | Yes (Apple approved) |
| Architecture | Universal (arm64 + x86_64) |

**Installation:**
1. Download the DMG file
2. Open the DMG
3. Drag MacAmp to Applications folder
4. Launch from Applications (no Gatekeeper warnings)

**What's New in v1.0.5:**
- **Force Unwrap Elimination** - Removed all force unwraps from AudioPlayer for safer, crash-resistant playback
- **AudioPlayer Refactoring** - Three-layer architecture with `AudioEngineController`, `AudioPlaybackController`, and `AudioBusController`
- **SwiftLint Integration** - Consistent code style and quality enforcement across the codebase
- **Documentation Updates** - Comprehensive architecture guide and 11 new optimization patterns
- **Code Quality Improvements** - Enhanced error handling, cleaner state management, and improved concurrency safety

See [Release Notes](https://github.com/hfyeomans/MacAmp/releases/tag/v1.0.5) for full changelog.

## Installation

### Building from Source

```bash
# Clone the repository
git clone https://github.com/hfyeomans/MacAmp.git
cd MacAmp

# Open in Xcode
open MacAmpApp.xcodeproj

# Build and run (Cmd+R) or build from command line:
xcodebuild -scheme MacAmp -configuration Debug -destination "platform=macOS"
```

## Usage

### Basic Playback

1. **Load Audio/Video Files** - Click the eject button (supports MP3, FLAC, WAV, MP4, MOV, M4V) or drag files to the window
2. **Play/Pause/Stop** - Use transport controls
3. **Seek** - Drag the position slider to jump to any point in the track
4. **Volume** - Adjust with the vertical volume slider
5. **Balance** - Pan left/right with the balance slider

### Equalizer

1. **Open Equalizer** - Press `Cmd+Shift+E` or click the EQ button
2. **Adjust Bands** - Drag any of the 10 frequency sliders or preamp
3. **Load Presets** - Click "Presets" → "Load" → Choose from 17 built-in presets
4. **Save Settings** - Click "Presets" → "Save" to create custom presets
5. **Toggle EQ** - Click "ON" button to enable/disable equalization

Available presets: Classical, Club, Dance, Full Bass, Full Bass & Treble, Full Treble, Laptop Speakers/Headphones, Large Hall, Live, Party, Pop, Reggae, Rock, Ska, Soft, Soft Rock, Techno

### Playlist

1. **Open Playlist** - Press `Cmd+Shift+P` or click the PL button
2. **Add Files** - Click ADD button for local files or M3U/M3U8 playlists
3. **Add Radio Stream** - Click ADD → ADD URL, paste URL (e.g., `http://ice1.somafm.com/groovesalad-256-mp3`)
4. **Play** - Double-click any item (file or stream)
5. **Navigate** - Next/Previous work across local files and streams
6. **Shuffle/Repeat** - Work with mixed playlists

**Note:** Streams show "Connecting..." during buffering, then live metadata. No EQ/visualizer for streams (AVPlayer limitation).

### Playlist Window Resize

1. **Resize Window** - Drag the bottom-right corner to resize
2. **Quantized Sizing** - Snaps to 25×29px segments (Winamp standard)
3. **Size Range** - Minimum 275×116px, maximum 2000×900px
4. **Dynamic Layout:**
   - **Top Bar** - Title tiles expand/contract with width
   - **Side Borders** - Vertical tiles adjust to height
   - **Bottom Bar** - Three sections: LEFT (menus) + CENTER (tiles) + RIGHT (controls)
5. **Scroll Slider** - Gold thumb appears on right border, drag to scroll playlist
6. **Persistence** - Window size remembered across app restarts

**Size Examples:**
| Segments | Pixels | Visible Tracks |
|----------|--------|----------------|
| [0,0] | 275×116 | 4 tracks |
| [0,4] | 275×232 | 13 tracks (default) |
| [4,8] | 375×348 | 21 tracks |

### Playlist Mini Visualizer

The playlist window includes a mini spectrum analyzer that activates when the main window is **shaded**:

1. **Activation** - Shade the main window (click titlebar shade button or press `Cmd+Option+1`)
2. **Requirements:**
   - Playlist window must be **wide enough** (≥350px, or 3+ width segments)
   - Main window must be in **shade mode** (minimized to 14px bar)
3. **Behavior:**
   - Same 19-bar spectrum analyzer as main window
   - Located in bottom-right visualizer background area
   - Deactivates automatically when main window unshades
4. **Usage** - Allows visualizer viewing while main window is minimized

### Skins

1. **Switch Skins** - Use keyboard shortcuts:
   - `Cmd+Shift+1` - Classic Winamp
   - `Cmd+Shift+2` - Internet Archive
   - `Cmd+Shift+3` - Tron Vaporwave
   - `Cmd+Shift+4` - Winamp3 Classified
2. **Import Skins** - Place `.wsz` files in `~/Library/Application Support/MacAmp/Skins/`
3. **Supported Formats** - Standard ZIP-based skin files

### Options Menu (O Button)

1. **Open Menu** - Click the "O" button in the clutter bar OR press **Ctrl+O**
2. **Menu Contents:**
   - **Time Display** - Toggle between elapsed and remaining time (also **Ctrl+T**)
   - **Double Size** - Toggle 200% scaling (also **Ctrl+D** or D button)
   - **Repeat** - Enable/disable repeat mode (also **Ctrl+R**)
   - **Shuffle** - Enable/disable shuffle mode (also **Ctrl+S**)
3. **Visual Feedback** - Active settings show checkmarks (✓)
4. **Keyboard Shortcut** - **Ctrl+O** (open menu), **Ctrl+T** (toggle time)

### Double-Size Mode

1. **Toggle Size** - Click the "D" button in the clutter bar, use the "O" button menu, OR press **Ctrl+D**
2. **Normal Mode** - Windows at 100% size (275×116 for main/EQ)
3. **Doubled Mode** - Windows at 200% size (550×232 for main/EQ)
4. **Behavior** - All 3 windows (main, EQ, playlist) scale together
5. **Persistence** - Last size remembered across app restarts
6. **Animation** - Smooth 0.2-second transition
7. **Keyboard Shortcut** - **Ctrl+D** (also in Windows menu and O button menu)

### Always On Top

1. **Toggle Float** - Click the "A" button in the clutter bar, use the "O" button menu, OR press **Ctrl+A**
2. **Normal Mode** - Window at normal level (can be covered by other apps)
3. **Float Mode** - Window stays above all other windows
4. **Persistence** - Last setting remembered across app restarts
5. **Keyboard Shortcut** - **Ctrl+A** (also in Windows menu and O button menu)

### Track Information (I Button)

1. **Open Dialog** - Click the "I" button in the clutter bar OR press **Ctrl+I**
2. **Displays:**
   - Track title and artist (for local files)
   - Duration in MM:SS format
   - Technical details: bitrate, sample rate, channels
   - Stream name (for radio streams)
   - Graceful fallbacks for limited metadata
3. **Visual Feedback** - I button highlighted while dialog is open
4. **Dismissal** - Click "Close" button, press Esc, or click outside
5. **Keyboard Shortcut** - **Ctrl+I**

### Repeat Modes (Winamp 5 Modern Fidelity)

MacAmp supports three repeat modes matching Winamp 5 Modern skins (Modern, Bento, cPro):

1. **Repeat: Off** - Stops at playlist end (button unlit)
2. **Repeat: All** - Loops entire playlist (button lit)
3. **Repeat: One** - Repeats current track (button lit + white "1" badge)

**Usage:**
- **Click repeat button** to cycle: Off → All → One → Off
- **Keyboard shortcut:** Press **Ctrl+R** to cycle through modes
- **Options menu:** Press **Ctrl+O**, select specific mode directly
- **Visual indicator:** White "1" badge appears on button when in Repeat One mode

**Behavior:**
- **Off mode:** Next button stops at last track, Previous stops at first
- **All mode:** Next wraps to first track, Previous wraps to last
- **One mode:** Next/Previous skip to adjacent track, track ending naturally restarts same track
- **Persistence:** Mode remembered across app restarts

**Winamp Compatibility:**
- Badge uses same overlay technique as Winamp 5 plugins for classic skins
- Shadow ensures legibility across all skin colors (dark and light buttons)
- Scales automatically with double-size mode (Ctrl+D)

### Visualizer Modes

1. **Click to Cycle** - Click the spectrum analyzer window to cycle through visualization modes
2. **3 Modes Available:**
   - **Spectrum Analyzer** - Frequency bars showing bass to treble (default)
   - **Oscilloscope** - Waveform display showing actual audio wave shape
   - **None** - Visualizer off (blank)
3. **Persistence** - Last mode remembered across app restarts
4. **How to Use:**
   - Play music
   - Click the black analyzer window (shows bars or waveform)
   - Cycles: Spectrum → Oscilloscope → None → Spectrum...

**Visualization Modes:**
- **Spectrum:** 19 vertical bars dancing to different frequencies - bass on left, treble on right
- **Oscilloscope:** Connected waveform line showing the actual audio wave (very active and dynamic!)
- **None:** Blank display (visualizer off)

**Clutter Bar Buttons** (vertical strip, left side):
- **O** - Options menu with time display, double-size, repeat, shuffle toggles (functional) ✅
- **A** - Always On Top window floating (functional) ✅
- **I** - Track Information metadata dialog (functional) ✅
- **D** - Double Size 100%/200% scaling (functional) ✅
- **V** - Video Window toggle (functional) ✅

### Video Window

1. **Open Video Window** - Click the "V" button in the clutter bar OR press **Ctrl+V**
2. **Load Video** - Drop MP4, MOV, or M4V files into playlist and double-click
3. **Resize** - Drag bottom-right corner (25×29px quantized segments) or use 1x/2x buttons
4. **Controls** - Volume slider, seek bar, and time display work just like audio
5. **Metadata** - Bottom bar shows scrolling filename, codec, and resolution
6. **Skinnable** - VIDEO.bmp chrome (from skin) or classic fallback
7. **Docking** - Video window snaps to other MacAmp windows magnetically
8. **Persistence** - Window position and size remembered across restarts

### Milkdrop Visualizations

1. **Open Window** - Press **Ctrl+K** to toggle Milkdrop window
2. **Visualizations** - 245 authentic Milkdrop 2 presets with WebGL rendering at 60 FPS
3. **Preset Navigation:**
   - **Space** - Next preset (or random if randomize enabled)
   - **Backspace** - Previous preset (history-based)
   - **R** - Toggle randomize mode
   - **C** - Toggle auto-cycle (configurable intervals: 5s/10s/15s/30s/60s)
   - **T** - Toggle track title display (configurable intervals or manual)
4. **Context Menu** - Right-click for:
   - Current preset display
   - Direct preset selection (up to 100 shown in menu)
   - Cycle and randomize toggles
   - Track title interval configuration
5. **Window Features:**
   - GEN.bmp skinnable chrome with MILKDROP HD letterforms
   - Active/Inactive titlebar states (focus tracking)
   - Drag-to-resize with 25×29px segments (minimum 275×116, default 275×232)
   - Dynamic titlebar expansion using gold filler tiles
   - Magnetic docking to other MacAmp windows and screen edges
   - Size and position persisted across app restarts
6. **Audio Sync** - Real-time FFT audio from AVAudioEngine (30 FPS data → 60 FPS WebGL rendering)

## Architecture

MacAmp uses a strict three-layer separation, inspired by web frameworks but adapted for SwiftUI's declarative paradigm.

### Mechanism Layer ("What the app does")
- **PlaybackCoordinator** - Orchestrates dual audio backends (local + streaming)
- **AudioPlayer** - AVAudioEngine lifecycle for local files with 10-band EQ
- **StreamPlayer** - AVPlayer-based HTTP/HTTPS radio streaming
- **VisualizerPipeline** - Audio tap, FFT processing, Butterchurn data
- **PlaylistController** - Playlist state and navigation logic
- **VideoPlaybackController** - Video AVPlayer lifecycle management
- **EQPresetStore** - Preset persistence (UserDefaults + JSON)
- **SkinManager** - Skin loading and hot-swapping

### Bridge Layer ("How components connect")
- **SpriteResolver** - Semantic sprite resolution for cross-skin compatibility
- **WindowCoordinator** - 5-window lifecycle and AppKit/SwiftUI bridge
- **DockingController** - Multi-window magnetic snapping
- **WindowFocusState** - Unified focus tracking across all windows

### Presentation Layer ("What the user sees")
- **SwiftUI Views** - Pixel-perfect sprite rendering (`.interpolation(.none)`)
- **SimpleSpriteImage** - Interactive sprite components with semantic IDs
- **Window Chrome Views** - Skinnable VIDEO.bmp and GEN.bmp chrome

For detailed architecture documentation, see [`docs/MACAMP_ARCHITECTURE_GUIDE.md`](docs/MACAMP_ARCHITECTURE_GUIDE.md).

## Project Structure

MacAmp follows a three-layer architecture inspired by modern frontend frameworks:

```
MacAmpApp/
├── Audio/                              # 🔧 MECHANISM LAYER - Audio Engine & Playback
│   ├── AudioPlayer.swift                   # AVAudioEngine lifecycle (1,043 lines, refactored)
│   ├── EQPresetStore.swift                 # EQ preset persistence (UserDefaults + JSON)
│   ├── MetadataLoader.swift                # Async track/video metadata extraction
│   ├── PlaybackCoordinator.swift           # Orchestrates dual backend (local + streaming)
│   ├── PlaylistController.swift            # Playlist state and navigation logic
│   ├── StreamPlayer.swift                  # AVPlayer-based HTTP/HTTPS radio streaming
│   ├── VideoPlaybackController.swift       # AVPlayer lifecycle and observer management
│   └── VisualizerPipeline.swift            # Audio tap, FFT processing, Butterchurn data
│
├── Models/                             # 🔧 MECHANISM LAYER - Data Models & Parsers
│   ├── AppSettings.swift                   # @Observable app settings and preferences
│   ├── EQF.swift                           # EQ preset file format codec
│   ├── EQPreset.swift                      # Equalizer preset data model
│   ├── ImageSlicing.swift                  # Sprite sheet extraction utilities
│   ├── M3UEntry.swift                      # M3U playlist entry structure
│   ├── M3UParser.swift                     # M3U/M3U8 playlist parser (local + remote)
│   ├── PLEditParser.swift                  # PLEDIT.txt color parser
│   ├── PlaylistWindowSizeState.swift       # Playlist resize state with computed properties
│   ├── RadioStation.swift                  # Radio station model
│   ├── RadioStationLibrary.swift           # Favorite stations persistence
│   ├── Size2D.swift                        # Quantized 25×29px resize segments
│   ├── VideoWindowSizeState.swift          # Video window resize state management
│   ├── WindowFocusState.swift              # Window focus tracking for active/inactive
│   ├── Skin.swift                          # Skin package data model
│   ├── SkinSprites.swift                   # Sprite name definitions and mappings (VIDEO + GEN letters)
│   ├── SnapUtils.swift                     # Window snapping utilities
│   ├── SpritePositions.swift               # Sprite coordinate definitions
│   ├── SpriteResolver.swift                # Semantic sprite resolution (cross-skin compat)
│   ├── VisColorParser.swift                # VISCOLOR.TXT gradient parser
│   └── WindowSpec.swift                    # Window dimension specifications
│
├── ViewModels/                         # 🌉 BRIDGE LAYER - State Management & Controllers
│   ├── DockingController.swift             # Multi-window coordination and positioning
│   ├── SkinManager.swift                   # Dynamic skin loading, hot-swapping, sprite caching
│   └── WindowCoordinator.swift             # 5-window lifecycle, AppKit bridge, focus tracking
│
├── Windows/                            # 🖼️ NSWindowController Layer (AppKit)
│   ├── WinampMainWindowController.swift    # Main window controller with @MainActor
│   ├── WinampEqualizerWindowController.swift   # EQ window controller
│   ├── WinampPlaylistWindowController.swift    # Playlist window controller
│   ├── WinampVideoWindowController.swift   # Video window controller
│   └── WinampMilkdropWindowController.swift    # Milkdrop window controller
│
├── Views/                              # 🎨 PRESENTATION LAYER - SwiftUI Windows & Views
│   ├── Components/                         # Reusable UI Components
│   │   ├── PlaylistBitmapText.swift            # Bitmap font rendering for playlist
│   │   ├── PlaylistMenuDelegate.swift          # NSMenuDelegate for keyboard navigation
│   │   ├── PlaylistScrollSlider.swift          # Gold thumb scroll slider with proportional sizing
│   │   ├── PlaylistTimeText.swift              # Time display component
│   │   ├── SimpleSpriteImage.swift             # Pixel-perfect sprite rendering (.interpolation(.none))
│   │   ├── SpriteMenuItem.swift                # Sprite-based popup menu items
│   │   └── WinampVolumeSlider.swift            # Frame-based volume/balance sliders
│   ├── Windows/                            # Window Chrome Components
│   │   ├── VideoWindowChromeView.swift         # VIDEO.bmp chrome with dynamic sizing
│   │   ├── MilkdropWindowChromeView.swift      # GEN.bmp chrome with two-piece letters
│   │   ├── AVPlayerViewRepresentable.swift     # NSViewRepresentable for AVPlayerView
│   │   └── WindowResizePreviewOverlay.swift    # AppKit overlay for resize preview
│   ├── EqGraphView.swift                   # Equalizer frequency response graph
│   ├── PreferencesView.swift               # Settings and preferences window
│   ├── PresetsButton.swift                 # EQ preset selector button
│   ├── SkinnedBanner.swift                 # Scrolling banner text component
│   ├── SkinnedText.swift                   # Skinned text rendering
│   ├── UnifiedDockView.swift               # Multi-window container with double-size scaling
│   ├── VisualizerOptions.swift             # Visualizer mode switching UI
│   ├── VisualizerView.swift                # Spectrum analyzer & oscilloscope rendering
│   ├── WinampEqualizerWindow.swift         # 10-band equalizer window
│   ├── WinampMainWindow.swift              # Main player window with transport controls
│   ├── WinampPlaylistWindow.swift          # Playlist window with sprite-based menus
│   ├── WinampVideoWindow.swift             # Video window with AVPlayer
│   └── WinampMilkdropWindow.swift          # Milkdrop visualization window
│
├── Utilities/                          # 🔧 Helper Functions & Extensions
│   ├── WindowAccessor.swift                # NSWindow access from SwiftUI
│   ├── WindowFocusDelegate.swift           # NSWindowDelegate for focus tracking
│   └── WindowSnapManager.swift             # Magnetic window snapping
│
├── AppCommands.swift                   # Global keyboard shortcuts and menu commands
├── MacAmpApp.swift                     # App entry point & dependency injection
├── SkinsCommands.swift                 # Skin switching command handlers
└── Skins/                              # Bundled .wsz skin packages

Tests/
└── MacAmpTests/
    ├── AppSettingsTests.swift              # Settings persistence tests
    ├── AudioPlayerStateTests.swift         # Audio engine state tests
    ├── DockingControllerTests.swift        # Window coordination tests
    ├── EQCodecTests.swift                  # EQF file format tests
    ├── PlaylistNavigationTests.swift       # Playlist operation tests
    ├── SkinManagerTests.swift              # Skin loading tests
    └── SpriteResolverTests.swift           # Sprite resolution tests

docs/                                   # Technical Documentation
tasks/                                  # Development Planning & Context
Package.swift                           # Swift Package Manager Configuration
```

### Architecture Evolution

**January 2026 - AudioPlayer Decomposition (v1.0.5)**
- Reduced AudioPlayer from 1,805 → 1,043 lines (-42%)
- Extracted 5 focused components: EQPresetStore, MetadataLoader, PlaylistController, VideoPlaybackController, VisualizerPipeline
- Full Swift 6 strict concurrency compliance (Sendable, @MainActor)

**2025 - Foundation**
- **5-Window System**: Main, Equalizer, Playlist, Video, Milkdrop with unified focus tracking
- **Dual Audio Backend**: PlaybackCoordinator orchestrating AVAudioEngine (local) + AVPlayer (streams)
- **Swift 6 Migration**: @Observable macro pattern replacing ObservableObject
- **Segment-Based Resize**: 25×29px quantized sizing for all resizable windows

See [`docs/MACAMP_ARCHITECTURE_GUIDE.md`](docs/MACAMP_ARCHITECTURE_GUIDE.md) for complete architecture documentation.

## Keyboard Shortcuts

### Global Controls

| Shortcut | Action |
|----------|--------|
| `Space` | Play/Pause |
| `Cmd+O` | Open file |
| `Ctrl+O` | Open options menu (time, double-size, repeat, shuffle) |
| `Ctrl+T` | Toggle time display (elapsed ⇄ remaining) |
| `Ctrl+R` | Cycle repeat mode (Off → All → One) |
| `Ctrl+I` | Show track information dialog |
| `Ctrl+D` | Toggle double-size mode (100% ↔ 200%) |
| `Ctrl+A` | Toggle always on top (float window) |
| `Ctrl+V` | Toggle video window |
| `Ctrl+K` | Toggle Milkdrop window |
| `Cmd+Shift+E` | Toggle equalizer window |
| `Cmd+Shift+P` | Toggle playlist window |
| `Cmd+Shift+1` | Switch to Classic Winamp skin |
| `Cmd+Shift+2` | Switch to Internet Archive skin |
| `Cmd+Shift+3` | Switch to Tron Vaporwave skin |
| `Cmd+Shift+4` | Switch to Winamp3 Classified skin |
| `←` / `→` | Previous/Next track |
| `↑` / `↓` | Volume up/down |

### Menu Navigation & Accelerators

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate menu items (when menu is open) |
| `Escape` | Close menu |
| `Click` | Activate highlighted item |
| `Ctrl+D` | Double-size (when Options menu is open) |
| `Ctrl+R` | Repeat (when Options menu is open) |
| `Ctrl+S` | Shuffle (when Options menu is open) |

**Accessible Menus:** ADD, REM, MISC, and LIST buttons now support full keyboard navigation with VoiceOver announcements.

## Supported Formats

### Audio Files
- MP3 (all bitrates)
- FLAC (lossless)
- AAC/M4A
- WAV/AIFF
- Apple Lossless (ALAC)
- OGG Vorbis (via AVFoundation)

### Video Files
- MP4 (H.264, HEVC)
- MOV (QuickTime)
- M4V (iTunes video)
- AVI (common codecs)

### Playlists & Streams
- M3U/M3U8 (local files + radio URLs)
- HTTP/HTTPS streams (SHOUTcast, Icecast, HLS)

### Skins
- WSZ (ZIP-based Winamp skins)
- Classic skin sprite sheets with fallback generation

## Technical Highlights

### Modern macOS Features

- **Five-Window Architecture** - Independent WindowGroup(id:) scenes with unified focus state
- **WindowDragGesture** - Native SwiftUI borderless window dragging (macOS 15+)
- **@Observable Macro** - Swift 6 strict concurrency with @MainActor isolation
- **Dual Audio Backend** - AVAudioEngine (local + EQ) / AVPlayer (streams) orchestration
- **10-Band Parametric EQ** - Real-time equalization via AVAudioUnitEQ
- **Hot Skin Swapping** - Runtime skin changes without app restart

### Skin Compatibility

MacAmp implements comprehensive skin support:

- **Sprite Resolution** - Handles `DIGIT_0` vs `DIGIT_0_EX` variants automatically
- **Dynamic Loading** - Loads sprite sheets from ZIP archives on-the-fly
- **Fallback System** - Generates placeholder sprites for missing elements
- **2D Grid Rendering** - Supports complex sprite layouts (e.g., EQMAIN.BMP 14×2 grid)
- **Mirrored Gradients** - Balance slider with proper center snapping

See [`docs/SPRITE_SYSTEM_COMPLETE.md`](docs/SPRITE_SYSTEM_COMPLETE.md) for implementation details.

### Performance Optimizations

- **Pre-allocated FFT Buffers** - Zero allocations on realtime audio thread (VisualizerScratchBuffers)
- **Goertzel Algorithm** - Efficient single-bin DFT for 20-bar spectrum analysis
- **vDSP Acceleration** - Hardware-accelerated audio processing via Accelerate framework
- **Sprite Sheet Caching** - Pre-processed backgrounds for instant rendering
- **Background I/O** - Fire-and-forget Task.detached for preset persistence
- **Progress Timer** - 100ms update interval balances CPU vs. smoothness

## Recent Updates

### v1.0.5 (January 2026) - Code Quality & Architecture Improvements 🛠️

**A major code quality release focusing on stability and maintainability.**

**Major Changes:**
- ✅ **Force Unwrap Elimination** - Comprehensive audit and removal of all force unwraps
  - AudioPlayer completely refactored for safe optional handling
  - Prevents potential crashes from unexpected nil values
  - Cleaner error handling throughout playback pipeline
- ✅ **AudioPlayer Three-Layer Architecture** - Professional restructuring
  - `AudioEngineController` - AVAudioEngine lifecycle management
  - `AudioPlaybackController` - Playback state and operations
  - `AudioBusController` - EQ and audio bus configuration
  - Clear separation of concerns for better maintainability
- ✅ **SwiftLint Integration** - Consistent code style enforcement
  - Automated linting for all Swift files
  - Enforces best practices and coding standards
- ✅ **Documentation Updates** - 11 new optimization patterns documented
  - Comprehensive architecture guide for AudioPlayer refactoring
  - Lessons learned from force unwrap elimination
  - Best practices for Swift 6 concurrency

**Technical:**
- Enhanced error handling with proper optional chaining
- Improved state management with clear ownership
- Thread Sanitizer clean with @MainActor annotations
- Developer ID signed and Apple notarized

---

### v1.0.1 (January 2026) - Resizable Milkdrop + Butterchurn Packs 🎆

**The first stable release of MacAmp!**

**Major Features:**
- ✅ **Resizable Milkdrop Window** - Full drag-to-resize support
  - Drag bottom-right corner with 25×29px quantized segments
  - Dynamic titlebar expansion using gold filler tiles (symmetrical left/right)
  - 7-section titlebar: LEFT_CAP + LEFT_GOLD(n) + LEFT_END + CENTER(3) + RIGHT_END + RIGHT_GOLD(n) + RIGHT_CAP
  - MILKDROP HD letterforms stay centered at all widths
  - Size persistence via UserDefaults
- ✅ **Butterchurn Visualization Packs** - 245 authentic Milkdrop 2 presets
  - WebGL rendering at 60 FPS with real-time FFT audio from AVAudioEngine
  - Preset navigation: Space/Backspace (next/previous), R (randomize), C (auto-cycle)
  - Context menu with direct preset selection from full library
  - Configurable auto-cycle intervals (5s/10s/15s/30s/60s)
  - Track title overlay with T key toggle

**Technical:**
- MilkdropWindowSizeState @Observable with computed layout properties
- ButterchurnBridge.setSize() syncs WebGL canvas on resize
- Oracle Grade A validation (Thread Sanitizer clean)
- Developer ID signed and Apple notarized

### v0.10.0 (January 2026) - Butterchurn Visualizations + Milkdrop Resize 🌀

**Major Features:**
- ✅ **Butterchurn Visualization Engine** - Authentic Milkdrop 2 experience via WebGL
  - 245 presets from Milkdrop 2 library (expanded from original 29)
  - 60 FPS audio-reactive rendering with real-time FFT from AVAudioEngine
  - WKUserScript injection for butterchurn.min.js and butterchurnPresets.min.js
  - 30 FPS Swift→JS audio bridge via callAsyncJavaScript
- ✅ **Preset Management System** - Full Winamp-compatible preset controls
  - Space/Backspace for next/previous (history-based navigation)
  - R key toggles randomize mode
  - C key toggles auto-cycle with intervals (5s/10s/15s/30s/60s)
  - T key shows track title overlay with configurable intervals
  - Context menu with direct preset selection (up to 100 shown)
  - Preset state persisted across restarts (randomize, cycle, intervals)
- ✅ **Milkdrop Window Resize** - Segment-based resizing with dynamic chrome
  - Drag bottom-right corner with 25×29px quantized segments
  - Minimum 275×116px (Size2D[0,0]), default 275×232px (Size2D[0,4])
  - Dynamic titlebar expansion using gold filler tiles (symmetrical left/right)
  - 7-section titlebar layout: LEFT_CAP + LEFT_GOLD(n) + LEFT_END + CENTER(3) + RIGHT_END + RIGHT_GOLD(n) + RIGHT_CAP
  - MilkdropWindowSizeState @Observable with computed layout properties
  - Size persistence via UserDefaults
  - Butterchurn canvas sync on resize via ButterchurnBridge.setSize()
- ✅ **GEN.bmp Sprite System** - Complete chrome implementation
  - MILKDROP HD titlebar letterforms (two-piece sprites for selected/inactive)
  - Active/Inactive titlebar states with WindowFocusState integration
  - Two-piece bottom bar sprites (TOP + BOTTOM for pixel-perfect alignment)

**Technical Achievements:**
- WKWebView integration with WebGL for visualization
- ButterchurnPresetManager with cycling, randomization, and history
- NSMenu closure-to-selector bridge pattern (MilkdropMenuTarget)
- AppKit resize preview overlay during drag (WindowResizePreviewOverlay)
- Oracle Grade A validation (5 critical bug fixes for thread safety and lifecycle)
- Thread Sanitizer clean (Timer cleanup, @MainActor annotations)

**Implementation:**
- PR #36: Milkdrop window foundation with GEN.bmp chrome
- PR #37: Butterchurn.js visualization integration
- PR #38: Preset library expansion (29→245 presets)
- PR #39: Window resize with dynamic titlebar system
- 7 phases completed (WKUserScript injection → preset management → window resize)

### v0.9.1 (December 2025) - Playlist Window Resize + Mini Visualizer 📐

**Major Features:**
- ✅ **Playlist Window Resize** - Full resize support matching Winamp behavior
  - Drag bottom-right corner to resize in 25×29px quantized segments
  - Minimum 275×116px, maximum 2000×900px
  - Three-section bottom bar: LEFT (125px menus) + CENTER (dynamic tiles) + RIGHT (150px controls)
  - Dynamic top bar and side border tiling
  - Size persisted to UserDefaults across restarts
- ✅ **Playlist Scroll Slider** - Functional gold thumb scroll control
  - Proportional thumb size based on visible/total tracks
  - Drag to scroll through playlist
  - Located in right border area
- ✅ **Playlist Mini Visualizer** - Spectrum analyzer in playlist window
  - Activates when main window is **shaded** (minimized to 14px bar)
  - Requires playlist width ≥350px (3+ width segments)
  - Same 19-bar spectrum analyzer as main window
  - Renders 76px, clips to 72px (Winamp historical accuracy)

**Main Window Shade Mode:**
- ✅ Shade state migrated to AppSettings (observable, persisted)
- ✅ Cross-window observation enables playlist visualizer activation
- ✅ Menu command "Shade/Unshade Main" fixed

**Bug Fixes:**
- Fixed shade mode buttons not clickable (ZStack alignment)
- Fixed NSWindow constraints (allow dynamic playlist width)
- Fixed persisted size restoration on launch
- Fixed PLAYLIST_BOTTOM_RIGHT_CORNER sprite width (154→150px)

**Architecture:**
- PlaylistWindowSizeState.swift - Observable state with computed layout properties
- PlaylistScrollSlider.swift - Reusable scroll slider component
- Three-layer pattern maintained (Mechanism→Bridge→Presentation)
- Oracle Grade: A- (Architecture Aligned)

**Documentation:**
- Added docs/PLAYLIST_WINDOW.md (860 lines)
- Added Part 22 to BUILDING_RETRO_MACOS_APPS_SKILL.md

### v0.8.9 (November 2025) - Video & Milkdrop Windows 🎬

**Major Features:**
- ✅ **Video Window** - Native video playback with VIDEO.bmp skinned chrome
  - Full resize with 25×29px quantized segments
  - 1x/2x size preset buttons
  - VIDEO.bmp sprite rendering (24 sprites) or classic fallback
  - Metadata ticker with auto-scrolling (filename, codec, resolution)
- ✅ **Milkdrop Window Foundation** - GEN.bmp two-piece letter sprites
  - "MILKDROP" titlebar with 32 letter sprites
  - Active/Inactive focus states
  - Foundation ready for future visualization
- ✅ **Unified Video Controls** (Part 21)
  - Volume slider synced to video playback
  - Seek bar works for video files (drag to any position)
  - Time display shows video elapsed/remaining
  - Clean switch between audio↔video playback

**5-Window Architecture:**
- Main, Equalizer, Playlist, VIDEO, and Milkdrop windows
- Magnetic docking for all windows
- Window focus tracking with active/inactive sprites
- Position persistence via WindowFrameStore
- V button (Ctrl+V) and K button (Ctrl+K) shortcuts

**Technical Achievements:**
- Size2D quantized resize model (25×29px segments)
- WindowCoordinator bridge methods for AppKit/SwiftUI separation
- Observable visibility state (isEQWindowVisible, isPlaylistWindowVisible)
- Task { @MainActor in } pattern for timer/observer closures
- playbackProgress stored pattern (must assign all three values)
- currentSeekID invalidation before playerNode.stop()
- AppKit preview overlay for resize visualization
- Oracle Grade A validation (all architectural concerns resolved)

**Bug Fixes:**
- Fixed invisible window phantom affecting cluster docking
- Fixed titlebar gap with proper tile calculation (ceil())
- Fixed EQ/PL button state sync with WindowCoordinator
- Fixed timer closures using proper MainActor hopping

**Status:** Video window 100% complete, Milkdrop foundation complete (visualization deferred)

### v0.7.8 (November 2025) - Clutter Bar O & I Buttons 🎉

**New Features:**
- ✅ **O Button (Options Menu)** - Context menu with player settings
  - Time display toggle (elapsed ⇄ remaining)
  - Quick access to double-size, repeat, and shuffle modes
  - Keyboard shortcuts: Ctrl+O (menu), Ctrl+T (time toggle)
- ✅ **I Button (Track Information)** - Metadata dialog
  - Shows track title, artist, duration
  - Technical details: bitrate, sample rate, channels
  - Stream-aware with graceful fallbacks
  - Keyboard shortcut: Ctrl+I
- ✅ **Time Display Enhancement** - Click time display to toggle, persists across restarts

**Bug Fixes:**
- Fixed NSMenu lifecycle issue preventing repeated menu usage
- Fixed minus sign vertical centering in time display
- Fixed keyboard shortcuts working with any window focused
- Fixed SwiftUI state mutation warning

**Clutter Bar Status:** 5 of 5 buttons functional (O, A, I, D, V)

### v0.2.0 (October 2025) - Swift 6 Modernization 🎉

**Major Architecture Upgrade:**
- ✅ **Swift 6.0** - Upgraded to latest Swift with strict concurrency
- ✅ **Modern State Management** - Migrated to @Observable framework for better performance
- ✅ **Keyboard Accessibility** - Full keyboard navigation in playlist menus
- ✅ **Zero Warnings** - Clean build with strict concurrency checking
- ✅ **Improved Performance** - 10-20% fewer UI updates with fine-grained observation
- ✅ **VoiceOver Support** - Screen reader accessibility for menus

**User-Visible Improvements:**
- Smoother UI updates and animations
- Arrow key navigation in all playlist menus (ADD, REM, MISC, LIST)
- Better stability and responsiveness
- Pixel-perfect sprite rendering throughout
- Improved audio playback reliability

**Technical Excellence:**
- Zero concurrency errors with Swift 6 strict mode
- Production-ready codebase
- Modern SwiftUI patterns throughout

---

## Development

### Known Limitations

- **EQ for Streams** - Equalizer only works for local files (AVPlayer limitation for HTTP streams)
- **Skin Sprite Coverage** - Some rare skin variants may have missing sprites (fallbacks generated)
- **Enter Key in Menus** - Menu activation requires click (arrow key navigation + click works)
- **Multi-Room Sync** - AirPlay 2 multi-room audio not yet supported

### Contributing

We welcome contributions! High-impact areas from our [tasks backlog](tasks/):

1. **AirPlay Support** - Stream audio to AirPlay speakers and devices ([tasks/airplay](tasks/airplay/))
2. **Playlist Drag & Drop** - Drop files directly into the playlist window ([tasks/playlist-drag-and-drop](tasks/playlist-drag-and-drop/))
3. **Media Key Support** - Respond to macOS keyboard media keys (Play/Pause/Next/Previous)
4. **OGG/Opus Codecs** - Add Vorbis and Opus audio format support via FFmpeg or native decoders
5. **Dock Integration** - Show transport controls in macOS dock menu

## Documentation

**📚 Complete Documentation Index:** [`docs/README.md`](docs/README.md) (19,105 lines across 20 documents)

### Architecture & Design

| Document | Description | Lines |
|----------|-------------|-------|
| [`MACAMP_ARCHITECTURE_GUIDE.md`](docs/MACAMP_ARCHITECTURE_GUIDE.md) | ⭐ **Primary Reference** - Complete system architecture, three-layer design, dual audio backend | 4,555 |
| [`IMPLEMENTATION_PATTERNS.md`](docs/IMPLEMENTATION_PATTERNS.md) | Code patterns, @Observable usage, testing, anti-patterns | 2,327 |
| [`SPRITE_SYSTEM_COMPLETE.md`](docs/SPRITE_SYSTEM_COMPLETE.md) | Semantic sprite resolution, skin file structure | 814 |

### Window Documentation

| Document | Description | Lines |
|----------|-------------|-------|
| [`MULTI_WINDOW_ARCHITECTURE.md`](docs/MULTI_WINDOW_ARCHITECTURE.md) | 5-window system design, focus management, magnetic snapping | 1,060 |
| [`PLAYLIST_WINDOW.md`](docs/PLAYLIST_WINDOW.md) | Playlist resize, scroll slider, mini visualizer | 860 |
| [`VIDEO_WINDOW.md`](docs/VIDEO_WINDOW.md) | Video playback, VIDEO.bmp chrome, seek/volume sync | 1,151 |
| [`MILKDROP_WINDOW.md`](docs/MILKDROP_WINDOW.md) | Butterchurn visualization, GEN.bmp sprites, preset management | 1,623 |

### Build & Distribution

| Document | Description |
|----------|-------------|
| [`RELEASE_BUILD_GUIDE.md`](docs/RELEASE_BUILD_GUIDE.md) | Building, signing, notarizing, DMG creation |
| [`WINAMP_SKIN_VARIATIONS.md`](docs/WINAMP_SKIN_VARIATIONS.md) | Skin format specifications, file structure |

## Credits

### Inspiration

MacAmp draws inspiration from the classic desktop audio player that defined a generation of music listening, adapted for modern macOS with native SwiftUI.

### Dependencies

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) - ZIP archive handling
- AVFoundation - Native macOS audio engine
- SwiftUI - Modern declarative UI framework

### References

- **Webamp** - Browser-based implementation for architectural patterns
- **Skin Format Specification** - Classic skin `.wsz` format documentation
- **Apple SwiftUI Documentation** - macOS 15+ features

## License

MIT License - see [LICENSE](LICENSE) for details.

Free to use, modify, and distribute with attribution.

## Support

For issues, questions, or feature requests:
- Open an issue on GitHub
- Check [`docs/`](docs/) for technical documentation
- Review [`tasks/`](tasks/) for development planning

---

**Built with ❤️ for macOS**

*MacAmp - Bringing classic audio player vibes to modern Apple Silicon.*
