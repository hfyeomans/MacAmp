# MacAmp

A pixel-perfect, native macOS audio player that brings the classic desktop audio player experience to modern Apple Silicon Macs with full skin compatibility.

![MacAmp Screenshot](docs/screenshots/macamp-main.png)

## Overview

MacAmp is a SwiftUI-based audio player for macOS that recreates the iconic desktop audio player interface with modern enhancements. Built specifically for **macOS Sequoia (15.0+)** and **macOS Tahoe (26.0+)**, it leverages the latest SwiftUI features while maintaining pixel-perfect fidelity to classic skins.

### Key Features

- 🎨 **Full Skin Support** - Load and switch between classic `.wsz` skins
- 🎵 **Native Audio Engine** - Built on AVFoundation for optimal macOS performance
- 🎚️ **10-Band Equalizer** - Professional audio control with 17 built-in presets
- 📊 **Real-time Spectrum Analyzer** - Visual audio feedback
- 🎛️ **Advanced Controls** - Volume, balance, position seeking, shuffle, and repeat
- 🪟 **Multi-Window Interface** - Main player, equalizer, and playlist windows
- 🎯 **Native macOS Integration** - Borderless windows with custom title bars
- ⚡ **Modern SwiftUI** - Utilizes WindowDragGesture and latest macOS APIs
- 🔄 **Dynamic Skin Switching** - Hot-swap skins without restart

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
2. **Add Files** - Click the + button to add audio files
3. **Remove** - Select tracks and click the - button
4. **Shuffle** - Click the shuffle button to randomize playback order
5. **Repeat** - Click the repeat button to loop playlist

### Skins

1. **Switch Skins** - Use keyboard shortcuts:
   - `Cmd+Shift+1` - Classic Winamp
   - `Cmd+Shift+2` - Internet Archive
   - `Cmd+Shift+3` - Tron Vaporwave
   - `Cmd+Shift+4` - Winamp3 Classified
2. **Import Skins** - Place `.wsz` files in `~/Library/Application Support/MacAmp/Skins/`
3. **Supported Formats** - Standard ZIP-based skin files

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

## Supported Audio Formats

- MP3 (all bitrates)
- FLAC (lossless)
- AAC/M4A
- WAV/AIFF
- Apple Lossless (ALAC)

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

## Development

### Active Development

Current phase: **Phase 4 - Polish & Bug Fixes**

See [`tasks/phase4-polish-and-bugfixes/plan.md`](tasks/phase4-polish-and-bugfixes/plan.md) for current sprint details.

### Completed Features

- ✅ **Phase 1:** SpriteResolver architecture
- ✅ **Phase 2:** Time display with semantic sprites
- ✅ **Phase 3:** All slider implementations (volume, balance, position, EQ)
- ✅ **Phase 3:** EQ with 17 presets
- ✅ **Phase 3:** Shuffle and repeat modes
- ✅ **Phase 4:** Borderless windows with WindowDragGesture

### Known Issues

- **Position seeking** - Race condition with async track loading (fix in progress)
- **EQ preset menu** - Occasional menu glitches when clicking "Load"

See [`tasks/phase4-polish-and-bugfixes/research.md`](tasks/phase4-polish-and-bugfixes/research.md) for technical details.

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
