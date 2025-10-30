# MacAmp

A pixel-perfect, native macOS audio player that brings the classic desktop audio player experience to modern Apple Silicon Macs with full skin compatibility.

![MacAmp Screenshot](docs/screenshots/macamp-main.png)

## Overview

MacAmp is a SwiftUI-based audio player for macOS that recreates the iconic desktop audio player interface with modern enhancements. Built specifically for **macOS Sequoia (15.0+)** and **macOS Tahoe (26.0+)**, it leverages the latest SwiftUI features while maintaining pixel-perfect fidelity to classic skins.

### Key Features

- 🎨 **Full Skin Support** - Load and switch between classic `.wsz` skins with VISCOLOR.TXT gradients
- 🎵 **Native Audio Engine** - Built on AVFoundation for optimal macOS performance
- 🎚️ **10-Band Equalizer** - Professional audio control with 17 built-in presets
- 📊 **Improved Spectrum Analyzer** - Webamp-style balanced frequency distribution with skin-specific colors
- ⌨️ **Keyboard Navigation** - Navigate playlist menus with arrow keys (↑↓) and Escape
- ♿ **VoiceOver Ready** - Accessible menu navigation for screen reader users
- 📋 **M3U Playlist Support** - Load M3U/M3U8 playlist files with local audio tracks
- 📂 **Playlist Menus** - Sprite-based popup menus for ADD, REM, MISC, and LIST OPTS with hover states
- ✨ **Multi-Select** - Shift+Click to select multiple tracks, Command+A to select all, with CROP and remove operations
- 📝 **Native Text Rendering** - Playlist tracks use real text with PLEDIT.txt colors and Unicode support (not bitmap fonts)
- 🎛️ **Advanced Controls** - Volume, balance, position seeking, shuffle, and repeat
- 🪟 **Multi-Window Interface** - Main player, equalizer, and playlist windows with shade modes
- 🔍 **Double-Size Mode** - Toggle 200% scaling for better visibility on high-res displays (Classic Winamp "D" button)
- 🎯 **Native macOS Integration** - Borderless windows with custom title bars
- ⚡ **Modern SwiftUI** - Utilizes WindowDragGesture and latest macOS APIs
- 🔄 **Dynamic Skin Switching** - Hot-swap skins without restart
- 📦 **Distribution Ready** - Developer ID signed builds for /Applications installation
- 🚀 **Swift 6 Architecture** - Modern, performant, future-proof codebase

## Requirements

- **macOS Sequoia 15.0+** or **macOS Tahoe 26.0+**
- **Apple Silicon** (M1/M2/M3/M4) or Intel Mac
- **Xcode 26.0+** (for building from source)

## Installation

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/MacAmp.git
cd MacAmp

# Build with Swift Package Manager
swift build

# Run the app
.build/debug/MacAmpApp
```

### Running in Xcode

```bash
# Open in Xcode
open Package.swift

# Press Cmd+R to build and run
```

## Usage

### Basic Playback

1. **Load Audio Files** - Click the eject button or drag audio files to the window
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
2. **Add Files** - Click the + button to add audio files or M3U playlists
3. **Load M3U Playlists** - Select .m3u or .m3u8 files to load multiple tracks
4. **Remove** - Select tracks and click the - button
5. **Shuffle** - Click the shuffle button to randomize playback order
6. **Repeat** - Click the repeat button to loop playlist

### Skins

1. **Switch Skins** - Use keyboard shortcuts:
   - `Cmd+Shift+1` - Classic Winamp
   - `Cmd+Shift+2` - Internet Archive
   - `Cmd+Shift+3` - Tron Vaporwave
   - `Cmd+Shift+4` - Winamp3 Classified
2. **Import Skins** - Place `.wsz` files in `~/Library/Application Support/MacAmp/Skins/`
3. **Supported Formats** - Standard ZIP-based skin files

### Double-Size Mode

1. **Toggle Size** - Click the "D" button in the clutter bar (left side, 4th button from top)
2. **Normal Mode** - Windows at 100% size (275×116 for main/EQ)
3. **Doubled Mode** - Windows at 200% size (550×232 for main/EQ)
4. **Behavior** - All 3 windows (main, EQ, playlist) scale together
5. **Persistence** - Last size remembered across app restarts
6. **Animation** - Smooth 0.2-second transition

**Clutter Bar Buttons** (vertical strip, left side):
- **O** - Options (coming soon)
- **A** - Always On Top (coming soon)
- **I** - Info (coming soon)
- **D** - Double Size (functional)
- **V** - Visualizer (coming soon)

## Architecture

MacAmp uses a three-layer architecture inspired by modern frontend frameworks:

### Mechanism Layer
- **AudioPlayer** - AVAudioEngine-based playback with EQ
- **PlaylistManager** - Track queue and playback order
- **SkinManager** - Dynamic skin loading and hot-swapping

### Bridge Layer
- **SpriteResolver** - Semantic sprite resolution for cross-skin compatibility
- **ViewModels** - State management and business logic
- **DockingController** - Multi-window coordination

### Presentation Layer
- **SwiftUI Views** - Pixel-perfect component rendering
- **SimpleSpriteImage** - Sprite sheet rendering with semantic support
- **Custom Sliders** - Frame-based sprite animation

For detailed architecture documentation, see [`docs/ARCHITECTURE_REVELATION.md`](docs/ARCHITECTURE_REVELATION.md).

## Project Structure

```
MacAmp/
├── MacAmpApp/
│   ├── Audio/              # Audio engine and playback
│   │   └── AudioPlayer.swift
│   ├── Models/             # Data models
│   │   ├── SpriteResolver.swift
│   │   ├── Skin.swift
│   │   └── Track.swift
│   ├── ViewModels/         # State management
│   │   ├── SkinManager.swift
│   │   └── DockingController.swift
│   ├── Views/              # SwiftUI interface
│   │   ├── WinampMainWindow.swift
│   │   ├── WinampEqualizerWindow.swift
│   │   └── WinampPlaylistWindow.swift
│   ├── Utilities/          # Helper functions
│   └── Skins/              # Bundled skins
├── docs/                   # Technical documentation
├── tasks/                  # Development planning
└── Package.swift           # Swift Package Manager config
```

## Keyboard Shortcuts

### Global Controls

| Shortcut | Action |
|----------|--------|
| `Space` | Play/Pause |
| `Cmd+O` | Open file |
| `Cmd+Shift+E` | Toggle equalizer window |
| `Cmd+Shift+P` | Toggle playlist window |
| `Cmd+Shift+1` | Switch to Classic Winamp skin |
| `Cmd+Shift+2` | Switch to Internet Archive skin |
| `Cmd+Shift+3` | Switch to Tron Vaporwave skin |
| `Cmd+Shift+4` | Switch to Winamp3 Classified skin |
| `←` / `→` | Previous/Next track |
| `↑` / `↓` | Volume up/down |

### Menu Navigation (New!)

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate menu items (when menu is open) |
| `Escape` | Close menu |
| `Click` | Activate highlighted item |

**Accessible Menus:** ADD, REM, MISC, and LIST buttons now support full keyboard navigation with VoiceOver announcements.

## Supported Formats

### Audio Files
- MP3 (all bitrates)
- FLAC (lossless)
- AAC/M4A
- WAV/AIFF
- Apple Lossless (ALAC)

### Playlists
- M3U (standard playlists)
- M3U8 (extended format with metadata)
- Local file paths (absolute and relative)
- Remote stream URLs (internet radio - P5 planned)

### Skins
- WSZ (ZIP-based Winamp skins)
- VISCOLOR.TXT gradients
- Classic skin sprite sheets

## Technical Highlights

### Modern macOS Features

- **WindowDragGesture** - Native SwiftUI window dragging (macOS 15+)
- **Borderless Windows** - Custom title bars with system chrome removed
- **SwiftUI Materials** - Glass effects and backdrop blur (optional)
- **AVAudioEngine** - Real-time audio processing and EQ
- **Structured Concurrency** - Modern Swift async/await patterns

### Skin Compatibility

MacAmp implements comprehensive skin support:

- **Sprite Resolution** - Handles `DIGIT_0` vs `DIGIT_0_EX` variants automatically
- **Dynamic Loading** - Loads sprite sheets from ZIP archives on-the-fly
- **Fallback System** - Generates placeholder sprites for missing elements
- **2D Grid Rendering** - Supports complex sprite layouts (e.g., EQMAIN.BMP 14×2 grid)
- **Mirrored Gradients** - Balance slider with proper center snapping

See [`docs/SpriteResolver-Architecture.md`](docs/SpriteResolver-Architecture.md) for implementation details.

### Performance Optimizations

- **Sprite Sheet Caching** - Pre-processed backgrounds for instant rendering
- **SwiftUI Body Minimization** - Prevents ghost images from re-evaluation
- **Progress Timer Optimization** - 100ms update interval balances CPU vs. smoothness
- **Conditional Logging** - `#if DEBUG` wraps all debug output

## Recent Updates

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

### Completed Phases

**Swift Modernization (Oct 2025):**
- ✅ **Phase 1:** Pixel-perfect sprite rendering (PR #23)
- ✅ **Phase 2:** @Observable migration + Swift 6 (PR #24)
- ✅ **Phase 3:** NSMenuDelegate keyboard navigation (PR #25)

**Earlier Phases:**
- ✅ SpriteResolver architecture
- ✅ Time display with semantic sprites
- ✅ All slider implementations (volume, balance, position, EQ)
- ✅ EQ with 17 presets
- ✅ Shuffle and repeat modes
- ✅ Borderless windows with WindowDragGesture
- ✅ Playlist menu system with multi-select
- ✅ Native text rendering

### Known Limitations

**Not Yet Implemented:**
- Settings persistence (volume/repeat reset on restart)
- Oscilloscope/RMS visualizer mode (backend exists, UI hidden)
- Repeat One/All modes (only On/Off toggle)
- Playlist scrolling (for large playlists)
- Enter key menu activation (arrow keys + click work)

See [`tasks/swift-modernization-recommendations/unimplemented-features.md`](tasks/swift-modernization-recommendations/unimplemented-features.md) for details.

### Contributing

We welcome contributions! Areas that need work:

1. **Additional Skin Support** - Test with more classic skins
2. **Playlist Persistence** - Save/restore playlists
3. **Media Key Support** - Respond to keyboard media keys
4. **Dock Integration** - Show controls in macOS dock
5. **File Format Support** - Add OGG Vorbis, Opus support

## Documentation

- **Architecture:** [`docs/ARCHITECTURE_REVELATION.md`](docs/ARCHITECTURE_REVELATION.md)
- **Sprite System:** [`docs/SpriteResolver-Architecture.md`](docs/SpriteResolver-Architecture.md)
- **Skin Format:** [`docs/winamp-skins-lessons.md`](docs/winamp-skins-lessons.md)
- **Phase 4 Plan:** [`tasks/phase4-polish-and-bugfixes/plan.md`](tasks/phase4-polish-and-bugfixes/plan.md)

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

[Add your license here]

## Support

For issues, questions, or feature requests:
- Open an issue on GitHub
- Check [`docs/`](docs/) for technical documentation
- Review [`tasks/`](tasks/) for development planning

---

**Built with ❤️ for macOS**

*MacAmp - Bringing classic audio player vibes to modern Apple Silicon.*
