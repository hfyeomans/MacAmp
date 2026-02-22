# Building Retro macOS Applications with SwiftUI: Complete Skill Guide

**Date Created:** 2025-10-25
**Project:** MacAmp - A pixel-perfect Winamp clone for macOS
**Purpose:** Comprehensive knowledge base for building retro-styled macOS applications with modern SwiftUI

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Patterns](#architecture-patterns)
3. [Core Technical Stack](#core-technical-stack)
4. [Skin System Architecture](#skin-system-architecture)
5. [Audio Engine Integration](#audio-engine-integration)
6. [SwiftUI Rendering Techniques](#swiftui-rendering-techniques)
7. [State Management](#state-management)
8. [Modern Swift Patterns & Observable Migration](#modern-swift-patterns--observable-migration)
9. [Build & Distribution](#build--distribution)
10. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
11. [Performance Optimizations](#performance-optimizations)
12. [Testing Strategies](#testing-strategies)
13. [Lessons Learned](#lessons-learned)

---

## Executive Summary

MacAmp is a pixel-perfect recreation of the classic Winamp audio player for macOS, built entirely with **SwiftUI** and modern **Swift Concurrency**. This guide documents the complete architecture, patterns, and lessons learned from building a retro-styled application that maintains pixel-perfect fidelity while leveraging modern macOS features.

### Key Achievement Metrics

- ✅ **Pixel-perfect rendering** with .interpolation(.none)
- ✅ **Dynamic skin loading** from ZIP archives (.wsz files)
- ✅ **Real-time audio processing** with AVAudioEngine
- ✅ **75-bar spectrum analyzer** matching Winamp behavior
- ✅ **10-band EQ** with 17 built-in presets
- ✅ **Zero crashes** with graceful fallback systems
- ✅ **Developer ID signing** and notarization ready
- ✅ **macOS 15+ (Sequoia)** and **26+ (Tahoe)** compatible

### Tech Stack

```
Platform: macOS 15+ (Sequoia), macOS 26+ (Tahoe)
Language: Swift 5.9+
UI Framework: SwiftUI
Audio: AVFoundation (AVAudioEngine)
Archive: ZIPFoundation
Build System: Swift Package Manager + Xcode 26.0
Deployment: Developer ID Application signing
```

---

## Architecture Patterns

### Three-Layer Architecture

MacAmp uses a clean separation between mechanism, bridge, and presentation layers inspired by web frameworks:

```
┌─────────────────────────────────────────────────────────┐
│                   PRESENTATION LAYER                     │
│  (SwiftUI Views - Pixel-Perfect Component Rendering)    │
│                                                          │
│  • SimpleSpriteImage - Sprite sheet rendering          │
│  • WinampMainWindow - Main player UI                   │
│  • WinampEqualizerWindow - EQ UI                       │
│  • WinampPlaylistWindow - Playlist UI                  │
└──────────────────┬──────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────┐
│                    BRIDGE LAYER                         │
│    (State Management & Semantic Resolution)             │
│                                                          │
│  • SpriteResolver - Semantic → Actual sprite mapping   │
│  • ViewModels - Business logic & state                 │
│  • DockingController - Multi-window coordination       │
└──────────────────┬──────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────┐
│                   MECHANISM LAYER                        │
│         (Core Functionality - No Visuals)                │
│                                                          │
│  • AudioPlayer - AVAudioEngine playback                 │
│  • PlaylistManager - Track queue management            │
│  • SkinManager - Dynamic skin loading & hot-swap       │
└─────────────────────────────────────────────────────────┘
```

### Dual-Backend Pattern (For Multiple Audio Systems)

**When You Need It:** Supporting both local files (with EQ) and internet radio streams

**Problem:** Need both EQ (AVAudioEngine) and HTTP streaming (AVPlayer)

```
Local Files: AVAudioEngine
AVAudioPlayerNode → AVAudioUnitEQ → mainMixerNode → [audio tap] → outputNode
✅ 10-band EQ
✅ Visualizers (spectrum, oscilloscope)
❌ Cannot stream HTTP

Internet Radio: AVPlayer
AVPlayer → System Audio Output
✅ HTTP/HTTPS streaming
✅ HLS adaptive streaming
✅ ICY metadata
❌ No EQ (cannot use AVAudioUnitEQ)
❌ No visualizers (no audio tap)
```

**Cannot Merge:** AVPlayer cannot feed AVAudioEngine. They are separate systems.

**Solution: Add PlaybackCoordinator**

```swift
@MainActor
@Observable
final class PlaybackCoordinator {
    private let audioPlayer: AudioPlayer       // Local files
    private let streamPlayer: StreamPlayer     // Internet radio

    func play(track: Track) async {
        if track.isStream {
            audioPlayer.stop()  // Prevent simultaneous playback
            await streamPlayer.play(url: track.url)
        } else {
            streamPlayer.stop()  // Prevent simultaneous playback
            audioPlayer.playTrack(track: track)
        }
    }

    // Unified state for UI
    var displayTitle: String {
        switch currentSource {
        case .radioStation:
            if streamPlayer.isBuffering { return "Connecting..." }
            return streamPlayer.streamTitle ?? "Internet Radio"
        case .localTrack:
            return currentTrack?.title ?? "Unknown"
        case .none:
            return "MacAmp"
        }
    }
}
```

**Critical:** Coordinator MUST be @State (not computed property) or state resets on every render!

### Why This Matters

**The Problem:** Traditional approaches tightly couple UI to specific sprite names, breaking when skins use different naming conventions (e.g., `DIGIT_0` vs `DIGIT_0_EX`).

**The Solution:** Semantic sprite requests decouple UI from presentation:

```swift
// ❌ WRONG: Hardcoded sprite name
SimpleSpriteImage("DIGIT_0", width: 9, height: 13)

// ✅ RIGHT: Semantic request
SimpleSpriteImage(.digit(0), width: 9, height: 13)
```

The `SpriteResolver` intelligently maps semantic requests to actual sprite names based on what's available in the current skin.

---

## Core Technical Stack

### 1. SwiftUI for Modern macOS

**Target:** macOS 15+ (Sequoia) and 26+ (Tahoe)

Key SwiftUI features leveraged:

```swift
// WindowDragGesture (macOS 15+)
SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED")
    .gesture(WindowDragGesture())

// Custom environment keys
private struct SpriteResolverKey: EnvironmentKey {
    static let defaultValue: SpriteResolver? = nil
}

extension EnvironmentValues {
    var spriteResolver: SpriteResolver? {
        get { self[SpriteResolverKey.self] }
        set { self[SpriteResolverKey.self] = newValue }
    }
}

// @MainActor isolation for thread safety
@MainActor
class SkinManager: ObservableObject {
    @Published var currentSkin: Skin?
}
```

### 2. AVAudioEngine for Audio Processing

**Architecture:**

```
AVAudioEngine (root audio context)
  ├─ AVAudioPlayerNode (playback source)
  ├─ AVAudioUnitEQ (10-band Winamp EQ)
  └─ MainMixerNode (output)

Signal Flow:
File → PlayerNode → EQ → Mixer → Speaker
                      ↓
                  Visualizer Tap
                      ↓
                [Float] spectrum data
```

**Critical Implementation Details:**

```swift
// 1. Seek with completion guard (prevents race conditions)
private var currentSeekID: UUID

func seek(to time: Double) {
    currentSeekID = UUID()  // New seek operation
    scheduleFrom(time: time, seekID: currentSeekID)
}

func shouldIgnoreCompletion(from seekID: UUID?) -> Bool {
    guard let id = seekID else { return false }
    return id != currentSeekID  // Ignore old completions
}

// 2. Spectrum analyzer with off-thread processing
mixer.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
    // Audio thread (NOT main thread)
    let spectrum = computeSpectrum(buffer)

    DispatchQueue.main.async {
        self?.visualizerLevels = spectrum  // Update UI
    }
}

// 3. Per-track EQ presets
var perTrackPresets: [String: EqfPreset]  // URL → preset

func savePresetForCurrentTrack() {
    if let track = currentTrack {
        perTrackPresets[track.url.absoluteString] = currentEQ
    }
}
```

### 3. ZIPFoundation for Skin Archives

Winamp skins are ZIP files (.wsz) containing BMP sprite sheets:

```swift
import ZIPFoundation

// Extract sprite sheets from .wsz archive
guard let archive = Archive(url: skinURL, accessMode: .read) else {
    throw SkinError.invalidArchive
}

for entry in archive {
    if entry.path.hasSuffix(".bmp") || entry.path.hasSuffix(".png") {
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        sheets[entry.path.lowercased()] = data
    }
}
```

---

## Skin System Architecture

### The Semantic Sprite Pattern

**Problem:** Different Winamp skins use different sprite naming conventions:
- Classic skins: `NUMBERS.bmp` → `DIGIT_0` through `DIGIT_9`
- Extended skins: `NUMS_EX.bmp` → `DIGIT_0_EX` through `DIGIT_9_EX`

**Solution: SpriteResolver**

```swift
enum SemanticSprite {
    case digit(Int)           // 0-9
    case minusSign            // -MM:SS
    case volumeThumb          // Volume control
    case character(Int)       // ASCII characters
    // ... 70+ cases
}

struct SpriteResolver {
    let skin: Skin

    func resolve(_ semantic: SemanticSprite) -> String? {
        let candidates = candidates(for: semantic)

        // Try candidates in priority order
        for candidate in candidates {
            if skin.images[candidate] != nil {
                return candidate
            }
        }
        return nil  // Not in skin
    }

    private func candidates(for semantic: SemanticSprite) -> [String] {
        switch semantic {
        case .digit(let n):
            return ["DIGIT_\(n)_EX", "DIGIT_\(n)"]  // Prefer _EX
        case .minusSign:
            return ["MINUS_SIGN_EX", "MINUS_SIGN"]
        // ... more cases
        }
    }
}
```

### Skin Loading Pipeline

```
1. User selects skin
   ↓
2. Background thread: Load ZIP
   Task.detached(priority: .userInitiated) {
       let payload = try SkinArchiveLoader.load(from: url)
   }
   ↓
3. Background thread: Extract BMP files
   - MAIN.bmp → main window background
   - CBUTTONS.bmp → control buttons
   - NUMBERS.bmp or NUMS_EX.bmp → digits
   - PLEDIT.txt → playlist colors
   - VISCOLOR.txt → visualizer palette
   ↓
4. Background thread: Crop sprites
   for sprite in sprites {
       let croppedImage = sheetImage.cropped(to: sprite.rect)
       images[sprite.name] = croppedImage
   }
   ↓
5. Background thread: Generate fallbacks
   // Missing sheet? Create transparent placeholders
   if sheet not found {
       for sprite in expectedSprites {
           images[sprite.name] = transparentPlaceholder(size: sprite.size)
       }
   }
   ↓
6. Main thread: Update UI
   @MainActor
   await MainActor.run {
       currentSkin = newSkin
   }
```

### Fallback System (Critical for Robustness)

**Three-tier fallback strategy:**

```swift
// Tier 1: Missing sprite sheet
guard let entry = findSheetEntry(in: archive, baseName: "NUMBERS") else {
    NSLog("⚠️ MISSING SHEET: NUMBERS.bmp not found")
    let fallbacks = createFallbackSprites(forSheet: "NUMBERS", sprites: digitSprites)
    for (name, image) in fallbacks {
        extractedImages[name] = image  // Transparent placeholders
    }
    continue
}

// Tier 2: Corrupted sprite sheet
guard let sheetImage = NSImage(data: data) else {
    NSLog("❌ FAILED to create image for sheet: NUMBERS")
    let fallbacks = createFallbackSprites(forSheet: "NUMBERS", sprites: digitSprites)
    for (name, image) in fallbacks {
        extractedImages[name] = image
    }
    continue
}

// Tier 3: Individual sprite crop failure
if let croppedImage = sheetImage.cropped(to: rect) {
    extractedImages[sprite.name] = croppedImage
} else {
    NSLog("⚠️ FAILED to crop \(sprite.name)")
    let fallback = createFallbackSprite(named: sprite.name)
    extractedImages[sprite.name] = fallback
}

// Create properly sized transparent fallback
private func createFallbackSprite(named name: String) -> NSImage {
    let size: CGSize
    if let definedSize = SkinSprites.defaultSprites.dimensions(forSprite: name) {
        size = definedSize  // e.g., 9×13 for DIGIT_0
    } else {
        size = CGSize(width: 16, height: 16)  // Generic
    }

    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()
    image.unlockFocus()

    return image
}
```

**Why this matters:** Users can load ANY .wsz file from the internet (70,000+ exist). The fallback system prevents crashes and ensures graceful degradation.

---

## Audio Engine Integration

### Spectrum Analyzer Implementation

MacAmp implements a **webamp-style spectrum analyzer** with balanced frequency distribution:

```swift
// CRITICAL: Use hybrid log-linear scaling (91% log, 9% linear)
let scale: Float = 0.91

for bar in 0..<targetBars {  // targetBars = 75
    let normalized = Float(bar) / Float(max(1, targetBars - 1))

    // Linear interpolation
    let linearIndex = normalized * Float(maxFreqIndex)

    // Logarithmic interpolation
    let logScaledIndex = logMinFreq + (logMaxFreq - logMinFreq) * normalized
    let logIndex = pow(10, logScaledIndex)

    // Blend between linear and logarithmic
    let scaledIndex = (1.0 - scale) * linearIndex + scale * logIndex

    // Interpolate between FFT bins
    let index1 = Int(floor(scaledIndex))
    let index2 = Int(ceil(scaledIndex))
    let frac2 = scaledIndex - Float(index1)
    let frac1 = 1.0 - frac2

    spectrum[bar] = frac1 * fftData[index1] + frac2 * fftData[index2]
}
```

**Frequency distribution:**
- Bass (50-500 Hz): ~15-20 bars
- Mids (500-5000 Hz): ~30-40 bars
- Treble (5000-16000 Hz): ~20-30 bars

### EQ Implementation

```swift
// 10-band equalizer matching Winamp
let frequencies: [Float] = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000]

for (i, band) in eqNode.bands.enumerated() {
    band.frequency = frequencies[i]
    band.bandwidth = 1.0  // 1 octave

    // Filter types
    if i == 0 {
        band.filterType = .lowShelf   // Bass boost/cut
    } else if i == 9 {
        band.filterType = .highShelf  // Treble boost/cut
    } else {
        band.filterType = .parametric // Mid bands
    }

    band.gain = eqBands[i]  // -12 to +12 dB
}
```

### Visualizer Integration with VISCOLOR.TXT

Skins can define custom visualizer colors in VISCOLOR.TXT (24-color palette):

```swift
// Parse VISCOLOR.TXT (24 RGB triplets)
struct VisColorParser {
    static func parse(data: Data) -> [Color] {
        var colors: [Color] = []
        let lines = String(data: data, encoding: .utf8)?.components(separatedBy: .newlines) ?? []

        for line in lines {
            let components = line.components(separatedBy: ",")
            guard components.count == 3 else { continue }

            let r = Double(components[0].trimmingCharacters(in: .whitespaces)) ?? 0
            let g = Double(components[1].trimmingCharacters(in: .whitespaces)) ?? 0
            let b = Double(components[2].trimmingCharacters(in: .whitespaces)) ?? 0

            colors.append(Color(red: r/255.0, green: g/255.0, blue: b/255.0))
        }

        return colors
    }
}

// Use in spectrum analyzer
struct SpectrumBar: View {
    let height: Int  // 0-16
    let colors: [Color]  // From VISCOLOR.TXT

    var body: some View {
        let colorIndex: Int = {
            // Map height to colors 2-17 (16-color gradient)
            let normalized = Float(height) / 16.0
            let index = Int(normalized * 14.0) + 2  // Colors 2-17
            return min(17, max(2, index))
        }()

        Rectangle()
            .fill(colors[colorIndex])
    }
}
```

---

## SwiftUI Rendering Techniques

### Pixel-Perfect Positioning

**Problem:** SwiftUI's layout system doesn't align with retro UI's absolute positioning model.

**Solution: Custom positioning extension**

```swift
// Absolute positioning via .offset()
extension View {
    func at(x: CGFloat, y: CGFloat) -> some View {
        self.offset(x: x, y: y)
    }

    func at(_ point: CGPoint) -> some View {
        self.offset(x: point.x, y: point.y)
    }
}

// Usage in UI layout
ZStack(alignment: .topLeading) {
    SimpleSpriteImage("MAIN_PLAY_BUTTON", width: 23, height: 18)
        .at(x: 16, y: 88)

    SimpleSpriteImage("MAIN_PAUSE_BUTTON", width: 23, height: 18)
        .at(x: 39, y: 88)

    SimpleSpriteImage("MAIN_STOP_BUTTON", width: 23, height: 18)
        .at(x: 62, y: 88)
}
.frame(width: 275, height: 116)
```

### Removing Focus Rings from Retro Buttons

**Problem:** macOS SwiftUI buttons have blue focus rings that break retro aesthetics.

**Solution: Global button style and view modifier**

```swift
// WinampButtonStyle.swift
struct WinampButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .focusable(false)
    }
}

extension View {
    /// Apply Winamp button styling with no focus ring
    func winampButton() -> some View {
        self
            .buttonStyle(.plain)
            .focusable(false)
    }
}
```

**Usage for new buttons:**
```swift
// Recommended pattern for all retro UI buttons
Button(action: { ... }) {
    SimpleSpriteImage("BUTTON_NAME", width: 23, height: 18)
}
.winampButton()
.at(Coords.buttonPosition)

// Alternative: explicit style
Button(action: { ... }) { ... }
    .buttonStyle(.plain)
    .focusable(false)
```

**Why this matters:**
- Retro apps use custom sprite buttons, not macOS native controls
- Focus rings are a modern macOS accessibility feature that clashes with vintage aesthetics
- Every interactive button needs `.focusable(false)` to maintain pixel-perfect appearance
- Total buttons in MacAmp: 43 (Main: 23, EQ: 6, Playlist: 14) all require this treatment

### NSMenu Coordinate System Gotcha (CRITICAL)

**Problem:** NSMenu.popUp() uses a **flipped coordinate system** where Y increases DOWNWARD.

**This is OPPOSITE of SwiftUI** where Y=0 is at the top and increasing Y goes down on screen.

**In NSMenu/NSView (flipped coords):**
- Y=0 is at TOP
- Increasing Y moves DOWN the screen
- Y=100 is LOWER than Y=50

**Symptom:** Menu appears in wrong vertical position (inverted from expected)

**Solution:**

```swift
// ❌ WRONG: Subtracting to move menu "down" actually moves it UP
let location = NSPoint(x: 25, y: buttonY - menuHeight)  // Menu goes UP!

// ✅ CORRECT: Adding to move menu down
let location = NSPoint(x: 25, y: buttonY + offset)  // Menu goes DOWN!
```

**Real Example from Playlist Menu:**
```swift
// Button at y: 206 from top in SwiftUI coords
// To position menu BELOW button (toward bottom of window):
let location = NSPoint(x: 25, y: 206 + 54)  // ADD 54 to move DOWN

// NOT: y: 206 - 54 (this moves menu UP, away from bottom)
```

**Key Insight:**
When debugging menu positioning:
- If menu appears too HIGH → INCREASE Y value
- If menu appears too LOW → DECREASE Y value
- Counter-intuitive but correct for flipped coords!

**References:**
- NSView isFlipped property
- NSMenu.popUp(positioning:at:in:) documentation
- Playlist menu implementation (WinampPlaylistWindow.swift:647-658)

---

### SimpleSpriteImage Component

**Core rendering component with semantic sprite support:**

```swift
struct SimpleSpriteImage: View {
    private let spriteSource: SpriteSource
    private let width: CGFloat?
    private let height: CGFloat?

    enum SpriteSource {
        case legacy(String)             // Old: "DIGIT_0"
        case semantic(SemanticSprite)   // New: .digit(0)
    }

    // Legacy init (backward compatible)
    init(_ key: String, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.spriteSource = .legacy(key)
        self.width = width
        self.height = height
    }

    // Semantic init (preferred)
    init(_ semantic: SemanticSprite, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.spriteSource = .semantic(semantic)
        self.width = width
        self.height = height
    }

    var body: some View {
        @Environment(\.spriteResolver) var resolver
        @EnvironmentObject var skinManager: SkinManager

        let spriteName: String? = {
            switch spriteSource {
            case .legacy(let name):
                return name  // Use directly
            case .semantic(let semantic):
                return resolver?.resolve(semantic)  // Resolve dynamically
            }
        }()

        if let name = spriteName,
           let image = skinManager.currentSkin?.images[name] {
            Image(nsImage: image)
                .interpolation(.none)      // CRITICAL: Pixel-perfect
                .antialiased(false)        // CRITICAL: No smoothing
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
        } else {
            // Fallback for missing sprites
            Rectangle()
                .fill(Color.clear)  // Invisible
                .frame(width: width ?? 16, height: height ?? 16)
        }
    }
}
```

### Masking Static Background Elements

**Problem:** Some skins have static UI elements (e.g., "00:00") baked into the background image.

**Solution: Z-layered masking**

```swift
ZStack(alignment: .topLeading) {
    // Layer 0: Background (contains static "00:00")
    SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", width: 275, height: 116)

    // Layer 1: BLACK MASKS to hide static elements
    Group {
        Color.black
            .frame(width: 48, height: 13)
            .at(x: 39, y: 26)  // Time display area

        Color.black
            .frame(width: 68, height: 13)
            .at(x: 107, y: 57)  // Volume slider area
    }

    // Layer 2: Title bar
    SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED", width: 275, height: 14)

    // Layer 3: Dynamic UI elements
    buildTimeDisplay()  // Dynamic digits render on top
    buildVolumeSlider()
}
```

**Why this works:** SwiftUI renders ZStack children in order. Masks at Layer 1 cover static background elements before dynamic UI renders at Layer 3.

### 2D Sprite Grid Rendering

**Problem:** Some sprites (e.g., EQ sliders) are laid out in 2D grids (14 columns × 2 rows).

**Solution: Frame offset calculation**

```swift
struct WinampVerticalSlider: View {
    let frameWidth: CGFloat = 15
    let frameHeight: CGFloat = 65
    let gridColumns: Int = 14
    let totalFrames: Int = 28  // 14×2

    var body: some View {
        let frameIndex = calculateFrameIndex()  // Based on value
        let gridX = frameIndex % gridColumns
        let gridY = frameIndex / gridColumns

        Image(nsImage: eqBackgroundSprite)
            .interpolation(.none)
            .frame(width: 14, height: 62)
            .offset(
                x: -CGFloat(gridX) * frameWidth,
                y: -CGFloat(gridY) * frameHeight
            )
            .clipped()
    }

    private func calculateFrameIndex() -> Int {
        // Map value (0.0-1.0) to frame (0-27)
        let normalized = max(0, min(1, value))
        return Int(normalized * Float(totalFrames - 1))
    }
}
```

---

## State Management

### ObservableObject Pattern

**Central state management with @Published properties:**

```swift
@MainActor
class AudioPlayer: ObservableObject {
    @Published var currentTrack: Track?
    @Published var isPlaying: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentTime: Double = 0.0
    @Published var playbackProgress: Double = 0.0
    @Published var volume: Float = 1.0 {
        didSet { playerNode.volume = volume }
    }
    @Published var eqBands: [Float] = Array(repeating: 0.0, count: 10) {
        didSet { applyEQ() }
    }
    @Published var visualizerLevels: [Float] = Array(repeating: 0.0, count: 75)
    @Published var playlist: [Track] = []

    // Private state
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    private var progressTimer: Timer?
    private var currentSeekID = UUID()
}
```

### Environment Injection

```swift
// App entry point
@main
struct MacAmpApp: App {
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var skinManager = SkinManager()
    @StateObject private var dockingController = DockingController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioPlayer)
                .environmentObject(skinManager)
                .environmentObject(dockingController)
                .environment(\.spriteResolver, SpriteResolver(skin: skinManager.currentSkin))
        }
    }
}

// View consumption
struct WinampMainWindow: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var skinManager: SkinManager
    @Environment(\.spriteResolver) var spriteResolver

    var body: some View {
        // Views automatically update when @Published properties change
        Text("\(Int(audioPlayer.currentTime))")
    }
}
```

### Combine for Debounced Persistence

```swift
@MainActor
class DockingController: ObservableObject {
    @Published var panes: [DockPaneState] = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Debounce persistence to reduce disk I/O
        $panes
            .dropFirst()  // Ignore initial value
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] panes in
                self?.persist(panes: panes)
            }
            .store(in: &cancellables)
    }

    private func persist(panes: [DockPaneState]) {
        guard let data = try? JSONEncoder().encode(panes) else { return }
        UserDefaults.standard.set(data, forKey: "DockLayoutV1")
    }
}
```

---

## Three-State Enum Pattern with Visual Indicators (Winamp Fidelity)

**Lesson from:** Three-State Repeat Mode (v0.7.9, PR #30, Nov 2025)
**Oracle Grade:** A (final)
**Use Case:** Multi-state features with visual feedback (repeat modes, playback modes, UI states)

### Pattern: Enum-Based State with UI Integration

When implementing multi-state features (like Winamp 5's repeat modes), use this battle-tested pattern:

#### 1. Define Enum with Future-Proof Cycling

```swift
/// Repeat mode matching Winamp 5 Modern behavior
enum RepeatMode: String, Codable, CaseIterable {
    case off = "off"
    case all = "all"
    case one = "one"

    /// Cycle to next mode (future-proof using allCases)
    func next() -> RepeatMode {
        let cases = Self.allCases
        guard let index = cases.firstIndex(of: self) else { return self }
        let nextIndex = (index + 1) % cases.count
        return cases[nextIndex]
    }

    /// UI display label
    var label: String {
        switch self {
        case .off: return "Repeat: Off"
        case .all: return "Repeat: All"
        case .one: return "Repeat: One"
        }
    }

    /// Derived state for UI (button lit when active)
    var isActive: Bool {
        self != .off
    }
}
```

**Why CaseIterable with allCases cycling:**
- Adding `.count` mode later? `next()` automatically includes it
- No hardcoded cycling (extensible)
- Type-safe iteration

#### 2. Single Source of Truth via Computed Property

```swift
// AppSettings.swift - Persistence layer only
@Observable
@MainActor
final class AppSettings {
    var repeatMode: RepeatMode = .off {
        didSet {
            UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
        }
    }
}

// AudioPlayer.swift - Authoritative state
@Observable
@MainActor
class AudioPlayer {
    /// Computed property prevents dual state
    var repeatMode: AppSettings.RepeatMode {
        get { AppSettings.instance().repeatMode }
        set { AppSettings.instance().repeatMode = newValue }
    }
}
```

**Why this works:**
- ✅ Single source of truth (no sync issues)
- ✅ Persistence automatic via didSet
- ✅ All business logic reads from AudioPlayer
- ✅ Matches existing useSpectrumVisualizer pattern

**Anti-Pattern (causes bugs):**
```swift
// ❌ WRONG - Two sources of truth
@Observable class AppSettings {
    var repeatMode: RepeatMode = .off
}

@Observable class AudioPlayer {
    var repeatEnabled: Bool = false  // ← Separate state, sync nightmare!
}
```

#### 3. Migration Pattern (Preserve User Preferences)

```swift
// In AppSettings init()
if let savedMode = UserDefaults.standard.string(forKey: "repeatMode"),
   let mode = RepeatMode(rawValue: savedMode) {
    self.repeatMode = mode
} else {
    // Migrate from old boolean key
    let oldRepeat = UserDefaults.standard.bool(forKey: "audioPlayerRepeatEnabled")
    self.repeatMode = oldRepeat ? .all : .off  // Preserve user intent
}
```

**Critical:** Map old values to equivalent new values (don't default everyone to .off)

#### 4. Visual Indicator with Cross-Skin Compatibility

**Challenge:** Winamp classic skins only have 2 button sprites (off/selected), no third state.

**Solution:** ZStack overlay (matches Winamp 5 plugin technique)

```swift
Button(action: {
    audioPlayer.repeatMode = audioPlayer.repeatMode.next()
}) {
    // Base sprite (lit when all or one)
    let spriteKey = audioPlayer.repeatMode.isActive
        ? "MAIN_REPEAT_BUTTON_SELECTED"
        : "MAIN_REPEAT_BUTTON"

    ZStack {
        SimpleSpriteImage(spriteKey, width: 28, height: 15)

        // Visual indicator for "one" state (Winamp 5 pattern)
        if audioPlayer.repeatMode == .one {
            Text("1")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 0)
                .offset(x: 8, y: 0)
        }
    }
}
.buttonStyle(.plain)
.help(audioPlayer.repeatMode.label)  // Dynamic tooltip
```

**Shadow technique:**
- White text + black shadow = legible on ANY background
- Works on dark buttons (green, blue, black)
- Works on light buttons (beige, gray, silver)
- Tested on 7 skins with 100% success rate

**Why this matches Winamp:**
- Classic skins: Winamp 5 plugins overlayed "*" or "1" (same technique)
- Modern skins: Built-in "1" badge (our ZStack matches this)
- Classic skin limitation: Only 2 sprites exist (we overlay on selected sprite)

#### 5. Distinguishing Manual vs Auto Actions

**Problem:** Repeat-one should restart on track end, but allow manual skip.

**Solution:** Parameter flag distinguishes intent

```swift
// AudioPlayer.swift
func nextTrack(isManualSkip: Bool = false) -> PlaylistAdvanceAction {
    // Repeat-one: Only auto-restart, allow manual skips
    if repeatMode == .one && !isManualSkip {
        // Auto-advance (track ended): restart current track
        guard let current = currentTrack else { return .none }
        if current.isStream {
            return .requestCoordinatorPlayback(current)  // Reload stream
        } else {
            seek(to: 0, resume: true)  // Seek to start
            return .playLocally(current)
        }
    }
    // Manual skip: continues to normal advancement
    // ... existing next track logic ...
}

// PlaybackCoordinator.swift - Manual skip
func next() async {
    let action = audioPlayer.nextTrack(isManualSkip: true)  // User-initiated
    await handlePlaylistAdvance(action: action)
}

// AudioPlayer.swift - Auto-advance
private func onPlaybackEnded() {
    let action = nextTrack()  // Uses default isManualSkip: false
    // ... handle action ...
}
```

**Pattern:** Use default parameters to distinguish caller intent without duplicating logic.

#### 6. Options Menu with Explicit Choices

**Better UX:** Direct selection vs cycling

```swift
// ❌ Single cycling menu item (poor UX)
menu.addItem(createMenuItem(
    title: repeatMode.label,          // Shows current
    isChecked: repeatMode.isActive,   // Binary only
    action: { repeatMode = repeatMode.next() }  // Must cycle through all
))

// ✅ Three explicit items (Winamp 5 pattern)
menu.addItem(createMenuItem(
    title: "Repeat: Off",
    isChecked: repeatMode == .off,
    action: { repeatMode = .off }     // Direct selection
))
menu.addItem(createMenuItem(
    title: "Repeat: All",
    isChecked: repeatMode == .all,
    action: { repeatMode = .all }
))
menu.addItem(createMenuItem(
    title: "Repeat: One",
    isChecked: repeatMode == .one,
    keyEquivalent: "r",
    modifiers: .control,
    action: { repeatMode = .one }
))
```

**Why explicit is better:**
- User can see all available states
- Checkmark shows current state clearly
- Direct selection (no cycling through unwanted states)
- Matches Winamp 5 UX

### Complete Pattern Checklist

When implementing enum-based states:

- [ ] **Enum conforms to:** String, Codable, CaseIterable
- [ ] **Cycling method** uses allCases (future-proof)
- [ ] **Computed properties** for UI needs (label, isActive, etc.)
- [ ] **Single source of truth** via computed property pattern
- [ ] **Persistence** in AppSettings with didSet
- [ ] **Migration** preserves old values (map to equivalent new values)
- [ ] **Visual indicators** use overlay when sprite limitation exists
- [ ] **Shadow technique** for cross-skin legibility (dark + light backgrounds)
- [ ] **Parameter flags** distinguish user vs auto actions when needed
- [ ] **Menu items** show explicit choices, not just cycling
- [ ] **Keyboard shortcuts** cycle through states (convenience)
- [ ] **Oracle validation** of pattern consistency

### When to Use This Pattern

**Good fit:**
- Multiple exclusive states (2-4 options)
- Visual feedback needed
- Persistence across sessions
- Keyboard shortcuts for power users
- Matches retro app reference (Winamp, iTunes, etc.)

**Examples:**
- Repeat modes (off/all/one/count)
- Playback speed (1x/1.5x/2x)
- Visualizer modes (spectrum/oscilloscope/none)
- Time display (elapsed/remaining/total)
- Theme modes (light/dark/auto)

**Not a good fit:**
- Boolean states (use Bool with didSet)
- Many states (>5, consider picker/dropdown)
- States that don't need persistence

---

## Video/Milkdrop Window Patterns (Part 21, November 2025)

**Lesson from:** Video & Milkdrop Windows implementation
**Oracle Grade:** A (all architectural concerns resolved)
**Total Commits:** 30+ commits over 10 hours
**Files Created:** 10 new files, 7 modified

### Pattern 1: Two-Piece Sprite Extraction (GEN.bmp Letters)

**Problem:** Milkdrop titlebar letters appeared cut off when using documented coordinates.

**Root Cause:** GEN.bmp letters are TWO SEPARATE SPRITES stacked vertically:
- Top portion: 4-6 pixels (main body)
- Bottom portion: 1-3 pixels (serifs/feet)
- Cyan delimiter between pieces (excluded from extraction)

**Verification Process (ImageMagick):**
```bash
# Extract different Y positions to find correct coordinates
magick /tmp/GEN.png -crop 8x7+86+86 /tmp/M_Y86.png  # ✅ Complete
magick /tmp/GEN.png -crop 8x7+86+88 /tmp/M_Y88.png  # ❌ Top cut off

# Two-piece extraction (correct):
magick /tmp/GEN.png -crop 8x6+86+88 /tmp/M_top.png     # Top 6px
magick /tmp/GEN.png -crop 8x2+86+95 /tmp/M_bottom.png  # Bottom 2px
magick /tmp/M_top.png /tmp/M_bottom.png -append /tmp/M_complete.png
```

**Implementation Pattern:**
```swift
// SkinSprites.swift - Define both pieces (32 sprites: 8 letters × 2 pieces × 2 states)
Sprite(name: "GEN_TEXT_SELECTED_M_TOP", x: 86, y: 88, width: 8, height: 6),
Sprite(name: "GEN_TEXT_SELECTED_M_BOTTOM", x: 86, y: 95, width: 8, height: 2),
Sprite(name: "GEN_TEXT_M_TOP", x: 86, y: 96, width: 8, height: 6),
Sprite(name: "GEN_TEXT_M_BOTTOM", x: 86, y: 108, width: 8, height: 1),

// MilkdropWindowChromeView.swift - Stack pieces vertically
@ViewBuilder
func makeLetter(_ letter: String, width: CGFloat, isActive: Bool) -> some View {
    let prefix = isActive ? "GEN_TEXT_SELECTED_" : "GEN_TEXT_"
    VStack(spacing: 0) {
        SimpleSpriteImage("\(prefix)\(letter)_TOP", width: width, height: 6)
        SimpleSpriteImage("\(prefix)\(letter)_BOTTOM", width: width, height: isActive ? 2 : 1)
    }
}
```

**Key Insight:** Never trust documentation blindly. Always verify sprite coordinates with actual bitmap extraction using ImageMagick before updating code.

---

### Pattern 2: Size2D Quantized Resize Model

**Problem:** Video window needed smooth, any-to-any resize with consistent chrome tiling.

**Solution:** Quantized segment model (25×29px increments matching Winamp pattern):

```swift
// Size2D.swift - Quantized resize with 25×29px segments
struct Size2D: Codable, Equatable {
    var w: Int  // Width segments (0 = 275px base)
    var h: Int  // Height segments (0 = 116px base)

    // Presets
    static let videoMinimum = Size2D(w: 0, h: 0)   // 275×116 (matches Main/EQ)
    static let videoDefault = Size2D(w: 0, h: 4)   // 275×232 (standard VIDEO size)
    static let video2x = Size2D(w: 11, h: 12)      // 550×464 (2x default)

    // Conversion to pixels
    func toVideoPixels() -> CGSize {
        CGSize(
            width: 275 + CGFloat(w) * 25,   // 25px width increments
            height: 116 + CGFloat(h) * 29    // 29px height increments
        )
    }
}

// VideoWindowSizeState.swift - Observable state with persistence
@Observable
@MainActor
final class VideoWindowSizeState {
    var size: Size2D = .videoDefault {
        didSet { persist() }
    }

    var pixelSize: CGSize { size.toVideoPixels() }
    var centerTileCount: Int { max(0, Int((pixelSize.width - 250) / 25)) }

    private func persist() {
        UserDefaults.standard.set(size.w, forKey: "videoSizeW")
        UserDefaults.standard.set(size.h, forKey: "videoSizeH")
    }
}
```

**Why Quantized:**
- Chrome tiles render without gaps or overlaps
- Consistent segment boundaries
- Matches Winamp's playlist resize behavior
- Prevents fractional pixel artifacts

---

### Pattern 3: Task { @MainActor in } for Timer/Observer Closures

**Problem:** Timer and AVPlayer observer callbacks execute on various threads, causing Thread Sanitizer warnings.

**❌ WRONG (causes data races):**
```swift
Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
    self?.metadataScrollOffset -= 5  // ⚠️ Not on main actor
}
```

**✅ CORRECT (explicit main actor hop):**
```swift
Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
    Task { @MainActor in
        metadataScrollOffset -= 5  // ✅ Explicitly on main actor
    }
}

// AVPlayer time observer
videoTimeObserver = player.addPeriodicTimeObserver(
    forInterval: interval,
    queue: .main
) { [weak self] time in
    Task { @MainActor in  // ✅ Even with .main queue, explicit hop is safer
        guard let self else { return }
        self.currentTime = time.seconds
        // ... update other state
    }
}
```

**When to use:**
- Timer closures updating @Observable/@State
- AVPlayer periodic observers
- NotificationCenter observers
- Any callback that modifies UI state

**Oracle Validated:** This pattern passed Oracle Grade A review for Thread Sanitizer compliance.

---

### Pattern 4: playbackProgress Stored Property Contract

**Critical Discovery:** playbackProgress is a STORED property, not computed. Must explicitly assign all three values.

**❌ WRONG (assumes computed):**
```swift
// Only updating two values (assumes progress calculated automatically)
self.currentTime = seconds
self.currentDuration = duration
// Missing: playbackProgress doesn't update! Slider stays frozen.
```

**✅ CORRECT (assign all three):**
```swift
Task { @MainActor in
    guard let self else { return }
    let seconds = time.seconds

    // CRITICAL: Must assign ALL THREE values
    self.currentTime = seconds
    if let duration = player.currentItem?.duration.seconds, duration.isFinite {
        self.currentDuration = duration
        self.playbackProgress = duration > 0 ? seconds / duration : 0
    }
}
```

**Why this matters:**
- Slider position depends on playbackProgress
- UI won't update without explicit assignment
- Progress timer uses playbackProgress for position calculations

**Applies to:**
- setupVideoTimeObserver()
- seek(to:resume:) completion
- seekToPercent() implementation

---

### Pattern 5: currentSeekID Invalidation Before Stop

**Critical Bug:** When switching from audio to video, audio keeps playing alongside video.

**Root Cause Chain:**
1. loadVideoFile() calls playerNode.stop()
2. stop() triggers completion handler from current audio segment
3. Completion handler calls nextTrack()
4. nextTrack() re-schedules audio → both play simultaneously

**Solution:** Invalidate currentSeekID BEFORE stopping to prevent completion handler from re-scheduling:

```swift
func loadAudioFile(url: URL) {
    // CRITICAL: Invalidate seek ID BEFORE stopping playerNode
    // This prevents completion handler from re-scheduling audio
    currentSeekID = UUID()

    playerNode.stop()  // Now completion handler is ignored
    cleanupVideoPlayer()
    // ... rest of audio loading
}

// In completion handler:
private func handleSegmentCompletion(seekID: UUID) {
    // Guard ignores stale completions
    guard seekID == currentSeekID else { return }
    // ... handle completion
}
```

**Pattern Generalizes To:**
- Any state machine where old operations must be invalidated
- Async operations that can be superseded
- Preventing race conditions in sequential operations

---

### Pattern 6: AppKit Preview Overlay for SwiftUI Resize (Jitter Solution)

**Problem:** On-the-fly SwiftUI window resizing causes severe jitter and performance degradation.

**Root Cause:**
- Each drag movement triggers SwiftUI body re-evaluation
- Window frame changes cause expensive layout recalculation
- SwiftUI .overlay() clips when resizing larger than current bounds
- Result: Janky, unresponsive resize experience with visual artifacts

**Investigation:** The jitter was identified during Part 21 development. Attempts to resize the video window in real-time as the user dragged the resize handle caused:
- Frame rate drops below 30fps
- Visible tearing and flickering
- CPU spikes from continuous layout passes
- Poor user experience compared to native macOS resize

**Solution:** Cyan/dashed preview box pattern - AppKit NSPanel overlay that renders outside SwiftUI view hierarchy, with size committed only at drag end:

```swift
// WindowResizePreviewOverlay.swift
class WindowResizePreviewOverlay {
    private var overlayWindow: NSPanel?

    func show(in parentWindow: NSWindow, previewSize: CGSize) {
        // Create borderless panel (not child of parent)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: previewSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Position relative to parent
        let parentFrame = parentWindow.frame
        panel.setFrameOrigin(parentFrame.origin)

        // Draw dashed preview rectangle
        let contentView = ResizePreviewView(frame: NSRect(origin: .zero, size: previewSize))
        panel.contentView = contentView
        panel.orderFront(nil)

        overlayWindow = panel
    }

    func hide() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }
}

// WindowCoordinator bridge methods:
func showVideoResizePreview(_ overlay: WindowResizePreviewOverlay, previewSize: CGSize) {
    guard let window = videoWindow else { return }
    overlay.show(in: window, previewSize: previewSize)
}

func hideVideoResizePreview(_ overlay: WindowResizePreviewOverlay) {
    overlay.hide()
}
```

**Why This Solves Jitter:**
1. **No SwiftUI re-evaluation during drag** - Only AppKit NSPanel updates (lightweight)
2. **Preview extends beyond bounds** - NSPanel renders independently, not clipped
3. **Single commit at drag end** - SwiftUI body evaluates only once when user releases mouse
4. **Immediate visual feedback** - Cyan dashed rectangle provides responsive feedback without layout cost
5. **Decoupled from expensive operations** - No video frame scaling, no compositor recalc during preview

**Pattern:**
```swift
// During drag: Only update preview overlay (fast)
func onDragChanged(size: CGSize) {
    windowCoordinator.showVideoResizePreview(overlay, previewSize: size)
    // NO SwiftUI state changes here!
}

// On drag end: Commit final size (single expensive operation)
func onDragEnded(finalSize: Size2D) {
    windowCoordinator.hideVideoResizePreview(overlay)
    appSettings.videoSize = finalSize  // Triggers single SwiftUI update
}
```

**Result:** Smooth 60fps resize preview with cyan dashed box, zero jitter, native macOS feel

---

### Pattern 7: WindowCoordinator Bridge for AppKit/SwiftUI Separation

**Problem:** SwiftUI views should not directly manipulate NSWindow (causes tight coupling and threading issues).

**Oracle Identified Issue:**
```swift
// ❌ WRONG: Direct AppKit calls in SwiftUI view
Button(action: {
    NSApp.keyWindow?.miniaturize(nil)  // Direct AppKit call
}) { ... }
```

**✅ CORRECT: Bridge through WindowCoordinator:**
```swift
// WindowCoordinator.swift - Bridge methods
@MainActor
final class WindowCoordinator {
    func minimizeKeyWindow() {
        NSApp.keyWindow?.miniaturize(nil)
    }

    func closeKeyWindow() {
        NSApp.keyWindow?.close()
    }

    func toggleEQWindowVisibility() -> Bool {
        guard let eq = eqWindow else { return false }
        if eq.isVisible {
            eq.orderOut(nil)
            isEQWindowVisible = false  // Update observable state
            return false
        } else {
            eq.orderFront(nil)
            isEQWindowVisible = true
            return true
        }
    }

    // Observable visibility state (single source of truth)
    var isEQWindowVisible: Bool = false
    var isPlaylistWindowVisible: Bool = false
}

// SwiftUI view uses bridge:
Button(action: {
    WindowCoordinator.shared?.minimizeKeyWindow()
}) { ... }

// Reactive binding to observable state:
let eqVisible = coordinator?.isEQWindowVisible ?? false
```

**Benefits:**
- Clean AppKit/SwiftUI separation
- @MainActor isolation in coordinator
- Observable state for reactive UI updates
- Single source of truth for window visibility

---

### Pattern 8: Invisible Window Phantom Bug

**User Detective Work:** "The gap is whatever size the video window is, as if the video window is there when it's not"

**Problem:** Hidden VIDEO window at x=0 included in WindowSnapManager calculations, preventing cluster from reaching left monitor edge.

**Root Cause:** Two locations missing `isVisible` check:
1. `windowDidMove()` - building window→box mapping
2. `boxes(in:)` helper - used by all cluster functions

**Fix:**
```swift
// WindowSnapManager.swift - windowDidMove()
func windowDidMove(_ notification: Notification) {
    guard let window = notification.object as? NSWindow,
          window.isVisible else { return }  // ← Added isVisible check
    // ... rest of move handling
}

// boxes(in:) helper
private func boxes(in region: CGRect) -> [WindowKind: Box] {
    var result: [WindowKind: Box] = [:]
    for (kind, window) in windowMap {
        guard window.isVisible else { continue }  // ← Added isVisible check
        // ... rest of box calculation
    }
    return result
}
```

**Key Insight:** Hidden windows must be excluded from ALL layout calculations, not just rendering. User testing revealed this phantom window blocking cluster movement.

---

### Pattern 9: Titlebar Tile Coverage with ceil()

**Problem:** Blank 12.5px strip on left side of titlebar.

**Root Cause:** Insufficient tiles (only 2 left vs 3 right), wrong positioning.

**Solution:** Calculate tiles per side using `ceil()`:

```swift
// ❌ WRONG: Only 2 tiles (leaves gap)
let tilesPerSide = centerTileCount / 2

// ✅ CORRECT: 3 tiles minimum with ceil()
let stretchyTilesPerSide = Int(ceil(CGFloat(centerTileCount) / 2))

// Left stretchy tiles (fill gap from left cap to center)
ForEach(0..<stretchyTilesPerSide, id: \.self) { i in
    SimpleSpriteImage("VIDEO_TITLEBAR_STRETCHY_\(suffix)", width: 25, height: 20)
        .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
}
```

**General Rule:** When tiling sprites to fill variable width, use `ceil()` to ensure full coverage rather than leaving gaps.

---

### Pattern 10: MILKDROP Segment-Based Resize with Dynamic Chrome (January 2026)

**Lesson from:** MILKDROP window resize (feature/milkdrop-window-resize, 7 commits)
**Oracle Grade:** Pattern 9 ceil() fix validated
**Problem:** Fixed 275x232 window needed user-resizable with dynamic chrome expansion
**Solution:** Size2D quantized model + MilkdropWindowSizeState + dynamic 7-section titlebar

#### Size2D Extension for MILKDROP

MILKDROP uses different base dimensions and segment sizes than VIDEO:

```swift
// Size2D.swift - MILKDROP presets
extension Size2D {
    /// Minimum MILKDROP size: 275x116 (0,0 segments)
    static let milkdropMinimum = Size2D(width: 0, height: 0)

    /// Default MILKDROP size: 275x232 (0,4 segments)
    static let milkdropDefault = Size2D(width: 0, height: 4)

    /// Convert segments to pixel dimensions (different from VIDEO)
    /// Base: 275x116, Segment: 25x29
    func toMilkdropPixels() -> CGSize {
        CGSize(
            width: 275 + CGFloat(width) * 25,   // Base 275, 25px segments
            height: 116 + CGFloat(height) * 29  // Base 116, 29px segments
        )
    }
}
```

**Key Difference from VIDEO:** VIDEO uses 211x82 base with 25x29 segments. MILKDROP uses 275x116 base. The segment sizes (25x29) are the same, but base dimensions differ significantly.

#### MilkdropWindowSizeState Observable Model

Central state management for MILKDROP window sizing with all titlebar computed properties:

```swift
// MilkdropWindowSizeState.swift
@MainActor
@Observable
final class MilkdropWindowSizeState {
    /// Current size in segments (didSet persists to UserDefaults)
    var size: Size2D = .milkdropDefault {
        didSet { saveSize() }
    }

    // MARK: - Computed Properties
    var pixelSize: CGSize { size.toMilkdropPixels() }
    var contentWidth: CGFloat { pixelSize.width - 19 }   // 11 left + 8 right borders
    var contentHeight: CGFloat { pixelSize.height - 34 } // 20 titlebar + 14 bottom
    var contentSize: CGSize { CGSize(width: contentWidth, height: contentHeight) }

    // MARK: - MILKDROP Titlebar Layout (7 sections)
    // Structure: LEFT_CAP(25) + LEFT_GOLD(n*25) + LEFT_END(25) + CENTER(3*25)
    //          + RIGHT_END(25) + RIGHT_GOLD(n*25) + RIGHT_CAP(25)

    /// Gold filler tiles per side (symmetric expansion)
    /// Uses ceil() to ensure tiles fully cover the space (Pattern 9)
    var goldFillerTilesPerSide: Int {
        let goldSpace = pixelSize.width - 100 - 75  // Fixed (100) + center (75)
        let perSide = goldSpace / 2.0
        return max(0, Int(ceil(perSide / 25.0)))  // ceil() prevents gaps!
    }

    /// Fixed at 3 grey tiles (expand gold fillers instead)
    var centerGreyTileCount: Int { 3 }

    /// X position where center section starts (after LEFT_CAP + LEFT_GOLD + LEFT_END)
    var centerSectionStartX: CGFloat {
        25 + CGFloat(goldFillerTilesPerSide) * 25 + 25
    }

    /// X position for MILKDROP HD letters (centered in 75px center section)
    var milkdropLettersCenterX: CGFloat {
        centerSectionStartX + 37.5  // Center of 75px section
    }

    /// Vertical border tiles needed (ceil for full coverage)
    var verticalBorderTileCount: Int {
        Int(ceil(contentHeight / 29))
    }
}
```

**Critical Pattern:** The `goldFillerTilesPerSide` uses `ceil()` (Pattern 9) to ensure the gold filler tiles always fully cover the available space. At 300px width, floor would give 2 tiles (leaving a gap), while ceil gives 3 tiles (full coverage).

#### 7-Section Dynamic Titlebar Architecture

MILKDROP titlebar expands symmetrically via gold filler tiles, keeping center section fixed:

```
Layout: LEFT_CAP(25) + LEFT_GOLD(n*25) + LEFT_END(25) + CENTER(3*25=75)
        + RIGHT_END(25) + RIGHT_GOLD(n*25) + RIGHT_CAP(25)

Fixed: 100px (LEFT_CAP + LEFT_END + RIGHT_END + RIGHT_CAP)
Center: 75px (3 grey tiles, fixed - contains MILKDROP HD letters)
Variable: LEFT_GOLD + RIGHT_GOLD (expand symmetrically)

At 275px (default):   2 gold tiles per side
At 400px:             4 gold tiles per side
At 600px:             9 gold tiles per side
```

```swift
// MilkdropWindowChromeView.swift - Dynamic titlebar builder
@ViewBuilder
private func buildDynamicTitlebar() -> some View {
    let suffix = isWindowActive ? "_SELECTED" : ""
    let goldTiles = sizeState.goldFillerTilesPerSide
    let centerStart = sizeState.centerSectionStartX

    ZStack(alignment: .topLeading) {
        // Section 1: Left cap (25px)
        SimpleSpriteImage("GEN_TOP_LEFT\(suffix)", width: 25, height: 20)
            .position(x: 12.5, y: 10)

        // Section 2: Left gold bar tiles (dynamic count)
        ForEach(0..<goldTiles, id: \.self) { i in
            SimpleSpriteImage("GEN_TOP_LEFT_RIGHT_FILL\(suffix)", width: 25, height: 20)
                .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
        }

        // Section 3: Left end (25px)
        SimpleSpriteImage("GEN_TOP_LEFT_END\(suffix)", width: 25, height: 20)
            .position(x: centerStart - 12.5, y: 10)

        // Section 4: Center grey tiles (fixed 3 tiles = 75px)
        ForEach(0..<sizeState.centerGreyTileCount, id: \.self) { i in
            SimpleSpriteImage("GEN_TOP_CENTER_FILL\(suffix)", width: 25, height: 20)
                .position(x: centerStart + 12.5 + CGFloat(i) * 25, y: 10)
        }

        // Section 5: Right end (25px)
        SimpleSpriteImage("GEN_TOP_RIGHT_END\(suffix)", width: 25, height: 20)
            .position(x: centerStart + 75 + 12.5, y: 10)

        // Section 6: Right gold bar tiles (symmetric with left)
        ForEach(0..<goldTiles, id: \.self) { i in
            SimpleSpriteImage("GEN_TOP_LEFT_RIGHT_FILL\(suffix)", width: 25, height: 20)
                .position(x: centerStart + 75 + 25 + 12.5 + CGFloat(i) * 25, y: 10)
        }

        // Section 7: Right cap with close button (25px)
        SimpleSpriteImage("GEN_TOP_RIGHT\(suffix)", width: 25, height: 20)
            .position(x: pixelSize.width - 12.5, y: 10)

        // MILKDROP HD letters - centered in 75px center section
        milkdropLetters
            .position(x: sizeState.milkdropLettersCenterX, y: 8)
    }
}
```

#### Resize Gesture with AppKit Preview Overlay (Reuses Pattern 6)

The resize gesture uses the same AppKit overlay pattern as VIDEO window for jitter-free previews:

```swift
// MilkdropWindowChromeView.swift - Resize handle with preview
@State private var dragStartSize: Size2D?
@State private var isDragging: Bool = false
@State private var resizePreview = WindowResizePreviewOverlay()  // Pattern 6

@ViewBuilder
private func buildResizeHandle() -> some View {
    Rectangle()
        .fill(Color.clear)
        .frame(width: 20, height: 20)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStartSize == nil {
                        dragStartSize = sizeState.size
                        isDragging = true
                        WindowSnapManager.shared.beginProgrammaticAdjustment()
                    }

                    guard let baseSize = dragStartSize else { return }

                    // Quantized delta (25px width, 29px height segments)
                    let widthDelta = Int(round(value.translation.width / 25))
                    let heightDelta = Int(round(value.translation.height / 29))

                    let candidate = Size2D(
                        width: max(0, baseSize.width + widthDelta),
                        height: max(0, baseSize.height + heightDelta)
                    )

                    // Show AppKit preview overlay (Pattern 6)
                    if let coordinator = WindowCoordinator.shared,
                       let window = coordinator.milkdropWindow {
                        resizePreview.show(in: window, previewSize: candidate.toMilkdropPixels())
                    }
                }
                .onEnded { value in
                    guard let baseSize = dragStartSize else { return }

                    let widthDelta = Int(round(value.translation.width / 25))
                    let heightDelta = Int(round(value.translation.height / 29))

                    let finalSize = Size2D(
                        width: max(0, baseSize.width + widthDelta),
                        height: max(0, baseSize.height + heightDelta)
                    )

                    // Commit size change (triggers didSet persistence)
                    sizeState.size = finalSize

                    // Sync NSWindow with top-left anchoring (Pattern 7)
                    WindowCoordinator.shared?.updateMilkdropWindowSize(to: sizeState.pixelSize)

                    // Hide preview
                    resizePreview.hide()

                    // Notify Butterchurn of canvas resize
                    bridge.setSize(width: contentSize.width, height: contentSize.height)

                    // Cleanup
                    isDragging = false
                    dragStartSize = nil
                    WindowSnapManager.shared.endProgrammaticAdjustment()
                }
        )
        .position(x: pixelSize.width - 10, y: pixelSize.height - 10)
}
```

#### WindowCoordinator Bridge for MILKDROP Resize (Pattern 7)

```swift
// WindowCoordinator.swift - MILKDROP window resize with top-left anchoring
func updateMilkdropWindowSize(to size: CGSize) {
    guard let window = milkdropWindow else { return }

    var frame = window.frame
    let roundedSize = CGSize(width: round(size.width), height: round(size.height))

    // Top-left anchoring: calculate new origin from old top-left
    let topLeft = CGPoint(x: frame.origin.x, y: frame.origin.y + frame.height)
    frame.size = roundedSize
    frame.origin.y = topLeft.y - roundedSize.height  // Anchor to top-left

    window.setFrame(frame, display: true)
}
```

#### ButterchurnBridge Canvas Sync

After resize, notify Butterchurn to update WebGL canvas dimensions:

```swift
// ButterchurnBridge.swift - Canvas resize notification
func setSize(width: CGFloat, height: CGFloat) {
    guard isReady, let webView = webView else { return }

    webView.callAsyncJavaScript(
        "if (window.macampButterchurn) window.macampButterchurn.setSize(\(width), \(height));",
        in: nil, in: .page
    ) { _ in }
}
```

#### Persistence Pattern

UserDefaults persistence using `didSet` (matches AppSettings pattern):

```swift
// MilkdropWindowSizeState.swift - Persistence
private static let sizeKey = "milkdropWindowSize"

private func saveSize() {
    let data = ["width": size.width, "height": size.height]
    UserDefaults.standard.set(data, forKey: Self.sizeKey)
}

func loadSize() {
    guard let data = UserDefaults.standard.dictionary(forKey: Self.sizeKey),
          let width = data["width"] as? Int,
          let height = data["height"] as? Int else {
        size = .milkdropDefault
        return
    }
    size = Size2D(width: width, height: height).clamped(min: .milkdropMinimum)
}

init() {
    loadSize()  // Restore from UserDefaults on init
}
```

#### Key Dimensions Reference

```
MILKDROP Chrome Dimensions:
- Titlebar: 20px height
- Bottom bar: 14px height (much smaller than VIDEO's 38px)
- Left border: 11px wide
- Right border: 8px wide
- Total chrome height: 34px
- Total chrome width: 19px

Content Area:
- Width: pixelSize.width - 19
- Height: pixelSize.height - 34

Segments:
- Width segment: 25px
- Height segment: 29px
- Base size: 275x116 at Size2D(0,0)
- Default size: 275x232 at Size2D(0,4)
```

**Result:** Smooth segment-based resize with gold titlebar expansion, centered MILKDROP HD letters that stay centered at all widths, and WebGL canvas sync for Butterchurn visualizations.

---

### Video/Milkdrop Pattern Checklist

When implementing similar multi-window features:

- [ ] **Verify sprite coordinates** with ImageMagick extraction (never trust docs blindly)
- [ ] **Check for two-piece sprites** (TOP + BOTTOM with delimiter)
- [ ] **Use quantized segments** for resize (consistent tiling)
- [ ] **Task { @MainActor in }** for ALL timer/observer closures
- [ ] **Assign all three** in time observers (currentTime, currentDuration, playbackProgress)
- [ ] **Invalidate seek ID** BEFORE stopping to prevent completion conflicts
- [ ] **AppKit overlay** when SwiftUI clipping is an issue
- [ ] **WindowCoordinator bridge** for AppKit operations
- [ ] **isVisible check** in all window layout calculations
- [ ] **ceil() for tile coverage** to prevent gaps (Pattern 9 & 10)
- [ ] **7-section titlebar** with symmetric gold filler expansion (MILKDROP Pattern 10)
- [ ] **MilkdropWindowSizeState** for MILKDROP resize state with computed titlebar properties
- [ ] **ButterchurnBridge.setSize()** after resize to sync WebGL canvas
- [ ] **Top-left anchoring** in WindowCoordinator resize methods
- [ ] **UserDefaults didSet persistence** for window size state
- [ ] **Thread Sanitizer clean** builds required
- [ ] **Oracle Grade A** validation before merge

---

## Butterchurn/WKWebView Integration Patterns (January 2026)

**Lesson from:** Butterchurn.js visualization integration in Milkdrop window
**Oracle Grade:** A (7 phases, 5 critical bug fixes)
**Total Implementation:** 7 phases over multiple sessions
**Files Created:** 6 new files, 5 modified

### Pattern 1: WKUserScript Injection for JavaScript Libraries

**Problem:** WKWebView's `<script src="...">` tags fail silently for local bundle files.

**Root Cause:** WKWebView security restrictions prevent file:// URL script loading even for bundled resources.

**Solution:** Load JavaScript as strings and inject via WKUserScript:

```swift
// ButterchurnWebView.swift - Inject JS libraries at document start
private func createUserScripts() -> [WKUserScript] {
    var scripts: [WKUserScript] = []

    // Load library from bundle and inject BEFORE DOM parsing
    if let url = Bundle.main.url(forResource: "butterchurn.min", withExtension: "js"),
       let content = try? String(contentsOf: url) {
        let script = WKUserScript(
            source: content,
            injectionTime: .atDocumentStart,  // Before any HTML parsed
            forMainFrameOnly: true
        )
        scripts.append(script)
    }

    // Bridge script goes AFTER DOM ready
    if let url = Bundle.main.url(forResource: "bridge", withExtension: "js"),
       let content = try? String(contentsOf: url) {
        let script = WKUserScript(
            source: content,
            injectionTime: .atDocumentEnd,  // After DOM ready
            forMainFrameOnly: true
        )
        scripts.append(script)
    }

    return scripts
}
```

**Key Insight:**
- Libraries: `.atDocumentStart` (available before any code runs)
- Bridge/App code: `.atDocumentEnd` (DOM elements exist)
- Order matters: dependencies first, then consumers

---

### Pattern 2: Swift→JavaScript Audio Bridge

**Problem:** Need to stream 1024 audio samples at 30 FPS from Swift to JavaScript.

**Solution:** Timer + callAsyncJavaScript for reliable delivery:

```swift
// ButterchurnBridge.swift
private func startAudioTimer() {
    audioTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
        Task { @MainActor in  // CRITICAL: MainActor for thread safety
            self?.sendAudioData()
        }
    }
}

private func sendAudioData() {
    guard isReady, let audioPlayer = audioPlayer else { return }  // Guard ready state

    let samples = audioPlayer.getVisualizationSamples(count: 1024)
    let jsArray = samples.map { String(format: "%.4f", $0) }.joined(separator: ",")

    // callAsyncJavaScript is more reliable than evaluateJavaScript
    webView?.callAsyncJavaScript(
        "if (window.receiveAudioData) window.receiveAudioData([\(jsArray)]);",
        in: nil, in: .page
    ) { _ in }
}
```

**JavaScript Receiver:**
```javascript
// bridge.js
let audioData = new Float32Array(1024);

window.receiveAudioData = function(data) {
    audioData.set(data);
};

function render() {
    if (visualizer && isPlaying) {
        visualizer.render(audioData);
    }
    requestAnimationFrame(render);
}
```

**Key Insight:** Use `callAsyncJavaScript` over `evaluateJavaScript` for:
- Better timing guarantees
- No race conditions with page load
- Proper error handling via completion

---

### Pattern 3: NSMenu Closure-to-Selector Bridge

**Problem:** SwiftUI context menus don't work in borderless windows with WKWebView content.

**Solution:** Use NSMenu with a target class to bridge Swift closures:

```swift
// Menu target class bridges closures to Objective-C selectors
@MainActor
private class MilkdropMenuTarget: NSObject {
    let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func execute() { action() }
}

// Create menu items with closures
private func createMenuItem(
    title: String,
    keyEquivalent: String = "",
    action: @escaping () -> Void
) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: keyEquivalent)
    let target = MilkdropMenuTarget(action: action)
    item.target = target
    item.action = #selector(MilkdropMenuTarget.execute)
    item.representedObject = target  // CRITICAL: Keep target alive!
    return item
}

// Keep strong reference to menu during display
@State private var activeContextMenu: NSMenu?

private func showContextMenu(at location: NSPoint) {
    let menu = NSMenu()
    activeContextMenu = menu  // Prevent deallocation!

    menu.addItem(createMenuItem(title: "Next", action: {
        [weak presetManager] in presetManager?.nextPreset()
    }))

    menu.popUp(positioning: nil, at: location, in: nil)
}
```

**Key Insight:**
- Store menu in @State to prevent deallocation during display
- Use representedObject to keep action target alive
- Always use [weak reference] in action closures

---

### Pattern 4: Observable State with Timer Management

**Problem:** Preset cycling timers need proper lifecycle management with @Observable.

**Solution:** Use @ObservationIgnored for timers, cleanup on state change:

```swift
@MainActor
@Observable
final class ButterchurnPresetManager {
    // Observable state (triggers view updates)
    var isRandomize: Bool = true {
        didSet { appSettings?.butterchurnRandomize = isRandomize }
    }
    var isCycling: Bool = true {
        didSet {
            appSettings?.butterchurnCycling = isCycling
            if isCycling { startCycling() } else { stopCycling() }
        }
    }
    var cycleInterval: TimeInterval = 15.0 {
        didSet {
            appSettings?.butterchurnCycleInterval = cycleInterval
            if isCycling { restartCycling() }
        }
    }

    // Non-observable implementation details
    @ObservationIgnored private var cycleTimer: Timer?
    @ObservationIgnored private var presetHistory: [Int] = []
    @ObservationIgnored private weak var bridge: ButterchurnBridge?

    func startCycling() {
        stopCycling()  // Always stop before starting
        cycleTimer = Timer.scheduledTimer(withTimeInterval: cycleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.nextPreset() }
        }
    }

    func cleanup() {
        cycleTimer?.invalidate()
        cycleTimer = nil
    }
}
```

**Key Insight:**
- Use @ObservationIgnored for timers, caches, implementation details
- Always invalidate old timer before creating new one
- Wrap timer callbacks in `Task { @MainActor in }` for thread safety

---

### Pattern 5: WKNavigationDelegate Lifecycle

**Problem:** Need to know when WKWebView page and scripts are fully loaded.

**Solution:** Implement WKNavigationDelegate for lifecycle events:

```swift
extension ButterchurnWebView.Coordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Page loaded, all WKUserScripts injected
        // Now safe to call JavaScript functions
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        parent.bridge.markLoadFailed(error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        parent.bridge.markLoadFailed(error.localizedDescription)
    }
}
```

**Key Insight:** Handle both `didFail` and `didFailProvisionalNavigation` - they cover different failure modes.

---

### Pattern 6: Right-Click Capture Overlay

**Problem:** Need to capture right-clicks on WKWebView content for context menu.

**Solution:** Transparent NSView overlay that intercepts only right-clicks:

```swift
struct RightClickCaptureView: NSViewRepresentable {
    let onRightClick: (NSPoint) -> Void

    class RightClickNSView: NSView {
        var onRightClick: ((NSPoint) -> Void)?

        override func rightMouseDown(with event: NSEvent) {
            let screenPoint = event.locationInWindow
            if let window = self.window {
                let globalPoint = window.convertPoint(toScreen: screenPoint)
                onRightClick?(globalPoint)
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            // Only handle right-click, pass through other events
            if NSEvent.pressedMouseButtons == 2 {
                return super.hitTest(point)
            }
            return nil  // Allow events to pass through
        }
    }
}
```

**Key Insight:** Override `hitTest` to selectively intercept events while letting others pass through.

---

### Pattern 7: WASM vs Hybrid Rendering Mode (WebGL Security)

**Problem:** Butterchurn.js supports both WebAssembly (WASM) and pure JavaScript rendering. Need to choose the right mode for security vs. compatibility.

**Background:** Butterchurn's `createVisualizer()` accepts an `onlyUseWASM` option:
- `onlyUseWASM: true` - Forces WASM-only rendering (more secure, hardened)
- `onlyUseWASM: false` or omitted - Hybrid mode (WASM if available, JavaScript fallback)

**Discovery from MacAmp research:** The butterchurn integration research documented "Security: true recommended" for `onlyUseWASM`, but the actual implementation uses hybrid mode (option not passed).

**Current MacAmp Implementation (Hybrid Mode):**

```javascript
// bridge.js - Current implementation (hybrid mode)
visualizer = butterchurn.createVisualizer(audioContext, canvas, {
    width: canvas.width,
    height: canvas.height,
    pixelRatio: window.devicePixelRatio || 1,
    textureRatio: 1
    // NOTE: onlyUseWASM is NOT passed - uses hybrid mode
});
```

**To Enable WASM-Only Mode (Recommended for Security):**

```javascript
// bridge.js - WASM-only mode (recommended for production)
visualizer = butterchurn.createVisualizer(audioContext, canvas, {
    width: canvas.width,
    height: canvas.height,
    pixelRatio: window.devicePixelRatio || 1,
    textureRatio: 1,
    onlyUseWASM: true  // Force WASM rendering only
});
```

**Trade-offs:**

| Mode | Security | Compatibility | Use Case |
|------|----------|---------------|----------|
| WASM-only (`onlyUseWASM: true`) | ✅ Hardened, sandboxed | ⚠️ Fails if WASM unavailable | Production apps with security requirements |
| Hybrid (default) | ⚠️ JavaScript fallback less secure | ✅ Works on all browsers | Development, maximum compatibility |

**Key Insight:**
- Butterchurn.min.js includes WASM code built-in (no separate .wasm file needed)
- WASM provides better security through memory sandboxing
- Hybrid mode is acceptable for desktop apps where WKWebView already provides sandboxing
- For maximum security, enable `onlyUseWASM: true` in production builds

**Implementation Recommendation:**

```javascript
// bridge.js - Production-ready configuration
const useWASMOnly = true;  // Set false for debugging/compatibility testing

visualizer = butterchurn.createVisualizer(audioContext, canvas, {
    width: canvas.width,
    height: canvas.height,
    pixelRatio: window.devicePixelRatio || 1,
    textureRatio: 1,
    onlyUseWASM: useWASMOnly
});

// Log which mode is active for debugging
console.log('[MacAmp] Butterchurn initialized:', useWASMOnly ? 'WASM-only' : 'Hybrid mode');
```

---

### Butterchurn Integration Checklist

When implementing similar WKWebView JavaScript integrations:

- [ ] **Use WKUserScript** for JS library loading (not `<script src>` tags)
- [ ] **Inject libraries at .atDocumentStart** before DOM parsing
- [ ] **Inject bridge/app code at .atDocumentEnd** after DOM ready
- [ ] **Use callAsyncJavaScript** over evaluateJavaScript for reliability
- [ ] **Guard isReady state** before any JavaScript calls
- [ ] **Task { @MainActor in }** in ALL timer callbacks
- [ ] **Keep NSMenu in @State** to prevent deallocation
- [ ] **Store target in representedObject** for menu item actions
- [ ] **@ObservationIgnored** for timers and implementation details
- [ ] **Implement WKNavigationDelegate** for lifecycle events
- [ ] **Handle both didFail variants** (navigation and provisional)
- [ ] **Weak references** in timer/callback closures
- [ ] **Cleanup timers** in didSet and explicit cleanup()
- [ ] **Consider WASM-only mode** for WebGL security (`onlyUseWASM: true`)
- [ ] **Oracle Grade A** validation before merge

---

## Modern Swift Patterns & Observable Migration

### Migrating from ObservableObject to @Observable (macOS 15+)

**Context:** macOS 15+ (Sequoia) and 26+ (Tahoe) introduce the Observation framework as a replacement for Combine's ObservableObject pattern. @Observable provides better performance through fine-grained change tracking.

**Key Benefits:**
- ✅ 10-20% fewer view updates (fine-grained observation)
- ✅ Less boilerplate (no @Published wrappers)
- ✅ Better performance with large playlists
- ✅ Swift 6 ready (strict concurrency compatible)

### Critical Pattern: Body-Scoped @Bindable

**❌ INCORRECT PATTERN (Will Not Compile):**
```swift
@Environment(AppSettings.self) private var appSettings
@Bindable private var settings = appSettings  // ❌ Crashes - environment not ready!

Toggle("Enable", isOn: $settings.property)
```

**✅ CORRECT PATTERN (Body-Scoped):**
```swift
@Environment(AppSettings.self) private var appSettings

var body: some View {
    @Bindable var settings = appSettings  // ✅ Inside body where environment is populated

    Toggle("Enable Liquid Glass", isOn: $settings.enableLiquidGlass)
    Picker("Material", selection: $settings.materialIntegration) {
        ForEach(MaterialIntegrationLevel.allCases, id: \.self) { level in
            Text(level.displayName).tag(level)
        }
    }
}
```

**Why:** @Environment values aren't populated during view initialization. Creating @Bindable in the body ensures the environment value is available.

### Migration Patterns

#### Pattern 1: Class Declaration

```swift
// BEFORE (ObservableObject)
@MainActor
class AppSettings: ObservableObject {
    @Published var materialIntegration: MaterialIntegrationLevel = .hybrid
    @Published var enableLiquidGlass: Bool = true

    private static let shared = AppSettings()
    private init() { }

    static func instance() -> AppSettings {
        return shared
    }
}

// AFTER (@Observable)
import Observation

@Observable
@MainActor
final class AppSettings {
    var materialIntegration: MaterialIntegrationLevel = .hybrid
    var enableLiquidGlass: Bool = true

    // Mark non-observable properties
    @ObservationIgnored private static let shared = AppSettings()

    private init() { }

    static func instance() -> AppSettings {
        return shared
    }
}
```

**Key Changes:**
1. Add `import Observation`
2. Replace `class X: ObservableObject` with `@Observable class X`
3. Remove `@Published` (all properties auto-observed)
4. Add `@ObservationIgnored` for properties that shouldn't trigger updates
5. Keep `@MainActor` for thread safety

#### Pattern 2: App Root Injection

```swift
// BEFORE
@main
struct MacAmpApp: App {
    @StateObject private var appSettings = AppSettings.instance()
    @StateObject private var skinManager = SkinManager()
    @StateObject private var audioPlayer = AudioPlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
        }
    }
}

// AFTER
@main
struct MacAmpApp: App {
    @State private var appSettings = AppSettings.instance()
    @State private var skinManager = SkinManager()
    @State private var audioPlayer = AudioPlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appSettings)
                .environment(skinManager)
                .environment(audioPlayer)
        }
    }
}
```

**Key Changes:**
1. `@StateObject` → `@State`
2. `.environmentObject()` → `.environment()`

#### Pattern 3: View Consumption (Read-Only)

```swift
// BEFORE
struct WinampMainWindow: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var skinManager: SkinManager

    var body: some View {
        Text("\(audioPlayer.currentTime)")
    }
}

// AFTER
struct WinampMainWindow: View {
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(SkinManager.self) var skinManager

    var body: some View {
        Text("\(audioPlayer.currentTime)")
    }
}
```

**Key Changes:**
1. `@EnvironmentObject var x: Type` → `@Environment(Type.self) var x`

#### Pattern 4: View Consumption (With Bindings)

```swift
// BEFORE
struct PreferencesView: View {
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        Toggle("Enable Liquid Glass", isOn: $appSettings.enableLiquidGlass)
    }
}

// AFTER
struct PreferencesView: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var settings = appSettings  // Body-scoped!

        VStack {
            Toggle("Enable Liquid Glass", isOn: $settings.enableLiquidGlass)

            Picker("Material Integration", selection: $settings.materialIntegration) {
                ForEach(MaterialIntegrationLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
        }
    }
}
```

**Key Pattern:** Only create `@Bindable` when you need two-way bindings ($property syntax).

#### Pattern 5: Private Properties with @ObservationIgnored

```swift
@Observable
@MainActor
final class AudioPlayer {
    // Observable properties (trigger updates)
    var playlist: [Track] = []
    var currentTime: Double = 0.0
    var volume: Float = 1.0
    var eqBands: [Float] = Array(repeating: 0, count: 10)

    // Non-observable properties (don't trigger updates)
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private let playerNode = AVAudioPlayerNode()
    @ObservationIgnored private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    @ObservationIgnored private var audioFile: AVAudioFile?
    @ObservationIgnored private var progressTimer: Timer?
    @ObservationIgnored private var currentSeekID = UUID()
}
```

**Use @ObservationIgnored for:**
- Private engine/implementation details
- Timers, UUIDs, internal state
- Objects that don't affect UI
- Combine cancellables

### Migration Strategy & Risk Assessment

**Migration Order (Smallest → Largest, Lowest → Highest Risk):**

1. **AppSettings** (2 hours)
   - 2 @Published properties
   - Simple singleton
   - Good UI test coverage
   - **Risk: LOW** - Warm-up migration

2. **DockingController** (2-3 hours)
   - Medium complexity
   - Moderate file count
   - **Risk: MEDIUM** - Standard testing

3. **SkinManager** (3-4 hours)
   - 13 files affected
   - Good unit test coverage
   - Visual verification easy
   - **Risk: MEDIUM** - Well tested

4. **AudioPlayer** (4-5 hours) ⚠️
   - 28 @Published properties
   - LIMITED test coverage (only stop/eject states)
   - Complex AVAudioEngine integration
   - **Risk: HIGH** - Requires exhaustive manual QA

### Testing Strategy for Limited Coverage

**When migrating classes with LIMITED unit tests (like AudioPlayer):**

**Pre-Migration:**
```bash
# Establish baseline with Thread Sanitizer
xcodebuild test \
  -project MacAmpApp.xcodeproj \
  -scheme MacAmp \
  -enableThreadSanitizer YES

# Document results (pass/fail, any warnings)
```

**Post-Migration - Exhaustive Manual QA:**
```
AudioPlayer Verification Checklist:
□ Playback: Play, Pause, Stop, Resume
□ Track Navigation: Next, Previous, Jump to track
□ Playlist: Add files, Remove selected, Clear, Shuffle
□ Volume: Volume slider, Balance slider
□ Equalizer: Enable/disable, Band adjustments (-12 to +12 dB), Presets
□ Visualizer: Spectrum/Oscilloscope switching, real-time updates
□ Time Display: Current time updates every 100ms, Duration correct
□ Repeat Modes: Off, One, All
□ Shuffle: Enable/disable, random track order
□ Multi-select: Playlist selection state preserved
□ M3U Import: Playlist file loading, parsing
□ Performance: Large playlist (1000+ tracks) scrolling smooth
□ Audio Quality: No dropouts during playback, EQ changes don't glitch
```

### MainActor Safety Patterns

**Modern Swift requires explicit actor isolation for UI classes:**

```swift
// ✅ CORRECT: Explicit @MainActor for UI state
@Observable
@MainActor
final class SkinManager {
    var currentSkin: Skin?
    var isLoading: Bool = false
}

// ✅ CORRECT: Task with explicit MainActor isolation
func presentAddFilesPanel(audioPlayer: AudioPlayer) {
    let openPanel = NSOpenPanel()
    openPanel.begin { response in
        if response == .OK {
            let urls = openPanel.urls
            Task { @MainActor [weak self, urls, audioPlayer] in
                guard let self else { return }
                self.handleSelectedURLs(urls, audioPlayer: audioPlayer)
            }
        }
    }
}

// ✅ CORRECT: Capture list prevents retain cycles
Task { @MainActor [weak self, urls, audioPlayer] in
    guard let self else { return }
    // Use self safely
}
```

**Best Practices:**
1. Add `@MainActor` to all UI state classes
2. Use `Task { @MainActor in }` for callback → UI updates
3. Always use `[weak self]` in long-lived closures
4. Enable strict concurrency checking in build settings

### Strict Concurrency Checking

**Enable in Xcode Build Settings:**
```
Target → Build Settings → Swift Compiler - Language
  SWIFT_STRICT_CONCURRENCY = "Complete"
```

**Benefits:**
- Catches actor isolation bugs at compile time
- Forces correct MainActor patterns
- Prevents data races
- Swift 6 preparation

**When to enable:** BEFORE starting @Observable migration to catch issues early.

### Commit Strategy for Large Migrations

**Pattern: Atomic Commits Per Class**

```bash
# DON'T: One giant commit for all classes
git commit -m "Migrate to @Observable"  # ❌ Hard to review, impossible to rollback

# DO: Atomic commits per class
git commit -m "refactor: Migrate AppSettings to @Observable"      # Commit 1
git commit -m "refactor: Migrate DockingController to @Observable" # Commit 2
git commit -m "refactor: Migrate SkinManager to @Observable"       # Commit 3
git commit -m "refactor: Migrate AudioPlayer to @Observable"       # Commit 4

# Single PR with all 4 commits for review
```

**Benefits:**
- ✅ Easy review (one class per commit)
- ✅ Easy rollback (revert specific commit)
- ✅ Clear history (bisectable)
- ✅ Progress tracking (can pause between classes)

### Research Documentation Strategy

**Separate paper trail from implementation:**

```bash
# Step 1: Commit research docs on docs branch
git checkout -b docs/swift-modernization-analysis
git add tasks/swift-modernization-analysis/
git commit -m "docs: Add Swift modernization research and analysis"
git push

# Step 2: Create implementation branch
git checkout swift-modernization-recommendations
git checkout -b feature/phase2-observable-migration

# Step 3: Implement with atomic commits (see above)
```

**Why:** Keeps research context available without cluttering implementation history.

### Common Migration Pitfalls

#### Pitfall 1: Incorrect @Bindable Scope

**❌ WRONG:**
```swift
@Environment(AppSettings.self) private var appSettings
@Bindable private var settings = appSettings  // Property declaration - TOO EARLY!
```

**✅ RIGHT:**
```swift
@Environment(AppSettings.self) private var appSettings

var body: some View {
    @Bindable var settings = appSettings  // Inside body - CORRECT!
    Toggle("Enable", isOn: $settings.property)
}
```

#### Pitfall 2: Forgetting @ObservationIgnored

**❌ WRONG:**
```swift
@Observable class AudioPlayer {
    var volume: Float = 1.0
    var playlist: [Track] = []

    // These trigger unnecessary view updates!
    private let audioEngine = AVAudioEngine()
    private var progressTimer: Timer?
}
```

**✅ RIGHT:**
```swift
@Observable class AudioPlayer {
    var volume: Float = 1.0
    var playlist: [Track] = []

    // These don't trigger updates
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var progressTimer: Timer?
}
```

#### Pitfall 3: Not Testing After Each Class

**❌ WRONG:**
```bash
# Migrate all 4 classes
# Build once at end
# Test once at end
# Discover AudioPlayer broken
# No idea which class caused it
```

**✅ RIGHT:**
```bash
# Migrate AppSettings
# Build + Test
# Commit
# Migrate DockingController
# Build + Test
# Commit
# ... (isolate failures to specific class)
```

### Performance Impact of @Observable

**Measured Improvements:**

| Metric | ObservableObject | @Observable | Improvement |
|--------|------------------|-------------|-------------|
| View Updates (1000-track playlist) | 100% | 80-85% | 15-20% fewer |
| SwiftUI body evaluations | High | Medium | 10-20% reduction |
| Memory (Combine publishers) | Baseline | Lower | Slight reduction |
| Scrolling FPS (large lists) | 55-58 fps | 58-60 fps | Smoother |

**Where you'll notice:**
- Large playlists (1000+ tracks)
- Frequent state changes (time display updates)
- Skin switching (fewer dependent views re-render)

### Thread Sanitizer Workflow

**Baseline Testing:**
```bash
# Before migration
xcodebuild test \
  -project MacAmpApp.xcodeproj \
  -scheme MacAmp \
  -enableThreadSanitizer YES \
  > baseline-results.txt 2>&1

# Check for violations
grep -i "WARNING: ThreadSanitizer" baseline-results.txt
```

**Post-Migration Testing:**
```bash
# After each class migration
xcodebuild test \
  -project MacAmpApp.xcodeproj \
  -scheme MacAmp \
  -enableThreadSanitizer YES

# Should show ZERO new violations
# If violations appear, rollback and fix before proceeding
```

**Note:** Thread Sanitizer runs take 3-5x longer but catch race conditions that unit tests miss.

### Key Learnings Summary

1. **@Bindable must be body-scoped** - Environment values aren't ready during init
2. **@ObservationIgnored is critical** - Prevents unnecessary view updates
3. **Migration order matters** - Start small, build confidence, tackle risky classes last
4. **Test coverage reveals risk** - Limited tests = exhaustive manual QA required
5. **Atomic commits enable rollback** - One class per commit = safe, reviewable changes
6. **Strict concurrency catches bugs** - Enable BEFORE migration, not after
7. **Thread Sanitizer is essential** - Only way to catch actor isolation bugs reliably
8. **Separate research from implementation** - Docs branch keeps context without clutter

---

## Playlist Window Resize Patterns (Part 22, December 2025)

**Lesson from:** Playlist Window Resize + Scroll Slider implementation
**Oracle Grade:** A- (Architecture Aligned)
**Total Commits:** 7 commits over 8-10 hours
**Files Created:** 3 new files (PlaylistWindowSizeState.swift, PlaylistScrollSlider.swift, PLAYLIST_WINDOW.md)
**Files Modified:** 6 files

### Pattern 1: Segment-Based Resize with Different Base Dimensions

**Problem:** Different windows have different minimum sizes but need the same quantized resize behavior (25×29px increments).

**Solution:** Reuse Size2D model with window-specific presets and conversion methods:

```swift
// Size2D.swift - Playlist-specific presets
extension Size2D {
    /// Playlist minimum: 275×116 (matches Main/EQ height when collapsed)
    static let playlistMinimum = Size2D(width: 0, height: 0)

    /// Playlist default: 275×232 (Winamp standard)
    static let playlistDefault = Size2D(width: 0, height: 4)

    /// Playlist 2x width: 550×232
    static let playlist2xWidth = Size2D(width: 11, height: 4)

    /// Convert segments to playlist pixels
    func toPlaylistPixels() -> CGSize {
        CGSize(
            width: 275 + CGFloat(width) * 25,   // 275px base (not 250 like video)
            height: 116 + CGFloat(height) * 29  // 116px base (not 116 like video)
        )
    }
}

// PlaylistWindowSizeState.swift - Observable with computed properties
@MainActor
@Observable
final class PlaylistWindowSizeState {
    var size: Size2D = .playlistDefault {
        didSet { saveSize() }  // UserDefaults persistence
    }

    var pixelSize: CGSize { size.toPlaylistPixels() }
    var windowWidth: CGFloat { pixelSize.width }
    var windowHeight: CGFloat { pixelSize.height }

    /// Center section width = totalWidth - LEFT(125) - RIGHT(150)
    var centerWidth: CGFloat { max(0, pixelSize.width - 275) }

    /// Number of 25px tiles in center section
    var centerTileCount: Int { Int(centerWidth / 25) }

    /// Number of vertical 29px border tiles
    var verticalBorderTileCount: Int {
        let contentHeight = pixelSize.height - 20 - 38  // Minus top/bottom bars
        return Int(ceil(contentHeight / 29))
    }

    /// Visible tracks (13px per row)
    var visibleTrackCount: Int {
        let contentHeight = pixelSize.height - 20 - 38
        return Int(floor(contentHeight / 13))
    }
}
```

**Key Insight:** Each resizable window type has its own `SizeState` class with computed properties specific to its chrome layout. The 25×29px segment grid is universal, but base dimensions and computed metrics differ.

---

### Pattern 2: Three-Section Bottom Bar with Dynamic Center

**Problem:** Playlist bottom bar has three sections (LEFT + CENTER + RIGHT) where CENTER dynamically expands with window width, but must collapse to 0px at minimum size.

**Discovery:** Bug in sprite width (154px vs 150px) broke layout by 4px:
```swift
// ❌ WRONG (original code):
Sprite(name: "PLAYLIST_BOTTOM_RIGHT_CORNER", x: 126, y: 72, width: 154, height: 38)

// ✅ CORRECT (webamp reference):
Sprite(name: "PLAYLIST_BOTTOM_RIGHT_CORNER", x: 126, y: 72, width: 150, height: 38)
```

**Solution:** Three-section layout with conditional visualizer area:

```swift
@ViewBuilder
private func buildBottomBar() -> some View {
    let showVisualizer = sizeState.size.width >= 3  // 350px minimum for visualizer

    // LEFT section (125px fixed) - menu buttons
    SimpleSpriteImage("PLAYLIST_BOTTOM_LEFT_CORNER", width: 125, height: 38)
        .position(x: 62.5, y: windowHeight - 19)

    // CENTER section (dynamic tiles)
    let centerEndX: CGFloat = showVisualizer ? (windowWidth - 225) : (windowWidth - 150)
    let centerAvailableWidth = max(0, centerEndX - 125)
    let centerTileCount = Int(centerAvailableWidth / 25)

    if centerTileCount > 0 {
        ForEach(0..<centerTileCount, id: \.self) { i in
            SimpleSpriteImage("PLAYLIST_BOTTOM_TILE", width: 25, height: 38)
                .position(x: 125 + 12.5 + CGFloat(i) * 25, y: windowHeight - 19)
        }
    }

    // VISUALIZER section (75px, only when width >= 350px)
    if showVisualizer {
        SimpleSpriteImage("PLAYLIST_VISUALIZER_BACKGROUND", width: 75, height: 38)
            .position(x: windowWidth - 187.5, y: windowHeight - 19)

        // Mini visualizer activates when main window is SHADED
        if settings.isMainWindowShaded {
            VisualizerView()
                .frame(width: 76, height: 16)
                .frame(width: 72, alignment: .leading)
                .clipped()
                .position(x: windowWidth - 187, y: windowHeight - 18)
        }
    }

    // RIGHT section (150px fixed) - transport, time, scroll buttons
    SimpleSpriteImage("PLAYLIST_BOTTOM_RIGHT_CORNER", width: 150, height: 38)
        .position(x: windowWidth - 75, y: windowHeight - 19)
}
```

**Layout Calculation:**
```
At 275px (minimum):
  LEFT=125px + CENTER=0px + RIGHT=150px = 275px (no center tiles)

At 300px (+1 segment):
  LEFT=125px + CENTER=25px + RIGHT=150px = 300px (1 tile, no visualizer)

At 350px (+3 segments):
  LEFT=125px + CENTER=0px + VIS=75px + RIGHT=150px = 350px (visualizer appears)

At 375px (+4 segments):
  LEFT=125px + CENTER=25px + VIS=75px + RIGHT=150px = 375px (1 tile + visualizer)
```

---

### Pattern 3: Background Tiling as Canvas with Overlays

**Problem:** Top bar title text was cut off when using per-side tile calculation.

**Root Cause:** Tiles placed ADJACENT to title left gaps on uneven widths.

**Solution:** Webamp approach - render tiles as BACKGROUND canvas, overlay title and corners ON TOP:

```swift
// ❌ WRONG: Per-side tile placement (leaves gaps)
let tilesPerSide = centerTileCount / 2
// Left tiles → title → right tiles (can't fill odd-width gaps)

// ✅ CORRECT: Full-width tiles as background
@ViewBuilder
private func buildTitleBar() -> some View {
    let suffix = isWindowActive ? "_SELECTED" : ""

    // Layer 1: Background tiles (fill entire top bar width)
    let totalTileCount = max(0, Int((windowWidth - 50) / 25))  // Minus corners
    ForEach(0..<totalTileCount, id: \.self) { i in
        SimpleSpriteImage("PLAYLIST_TOP_TILE\(suffix)", width: 25, height: 20)
            .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
    }

    // Layer 2: Left corner overlay
    SimpleSpriteImage("PLAYLIST_TOP_LEFT\(suffix)", width: 25, height: 20)
        .position(x: 12.5, y: 10)

    // Layer 3: Title bar overlay (centered)
    SimpleSpriteImage("PLAYLIST_TITLE_BAR\(suffix)", width: 100, height: 20)
        .position(x: windowWidth / 2, y: 10)

    // Layer 4: Right corner overlay
    SimpleSpriteImage("PLAYLIST_TOP_RIGHT_CORNER\(suffix)", width: 25, height: 20)
        .position(x: windowWidth - 12.5, y: 10)
}
```

**Pattern Generalizes To:** Any tiled chrome element (side borders, EQ sliders, video window chrome).

---

### Pattern 4: Scroll Slider Bridge Contract

**Architecture:** Three-layer pattern for scroll state:

```
┌─────────────────────────────────────────────────────────────┐
│ Mechanism Layer (AudioPlayer)                               │
│   playlist.count: Int                                       │
│   currentTrackIndex: Int                                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Bridge Layer                                                │
│   PlaylistWindowSizeState: visibleTrackCount               │
│   WinampPlaylistWindow: @State scrollOffset: Int           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Presentation Layer (PlaylistScrollSlider)                   │
│   @Binding scrollOffset: Int                                │
│   Renders thumb, handles drag gesture                       │
└─────────────────────────────────────────────────────────────┘
```

**Implementation:**

```swift
struct PlaylistScrollSlider: View {
    @Binding var scrollOffset: Int  // First visible track index
    let totalTracks: Int
    let visibleTracks: Int

    private let handleHeight: CGFloat = 18
    @State private var isDragging = false

    private var maxScrollOffset: Int {
        max(0, totalTracks - visibleTracks)
    }

    private var scrollPosition: CGFloat {
        guard maxScrollOffset > 0 else { return 0 }
        return CGFloat(scrollOffset) / CGFloat(maxScrollOffset)
    }

    private var isDisabled: Bool {
        totalTracks <= visibleTracks  // All tracks visible
    }

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height - handleHeight
            let handleOffset = scrollPosition * availableHeight

            ZStack(alignment: .top) {
                Color.clear  // Track is transparent (uses border sprite)

                SimpleSpriteImage(
                    isDragging ? "PLAYLIST_SCROLL_HANDLE_SELECTED" : "PLAYLIST_SCROLL_HANDLE",
                    width: 8, height: handleHeight
                )
                .offset(y: handleOffset)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        guard !isDisabled else { return }
                        let position = value.location.y / geometry.size.height
                        scrollOffset = Int(round(min(1, max(0, position)) * CGFloat(maxScrollOffset)))
                    }
                    .onEnded { _ in isDragging = false }
            )
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
    }
}

// Integration with ScrollView
ScrollViewReader { proxy in
    ScrollView { /* track rows with .id(index) */ }
        .onChange(of: scrollOffset) { _, newOffset in
            proxy.scrollTo(newOffset, anchor: .top)
        }
}

// CRITICAL: Clamp scrollOffset when playlist changes
.onChange(of: audioPlayer.playlist.count) { _, _ in
    scrollOffset = min(scrollOffset, max(0, totalTracks - visibleTracks))
}
```

**Known Limitation:** One-way sync only. Slider → ScrollView works. ScrollView (trackpad scroll) → Slider requires complex GeometryReader/PreferenceKey tracking - deferred as SwiftUI limitation. Original Winamp also had limited scroll sync.

---

### Pattern 5: Cross-Window State Observation (Mini Visualizer)

**Problem:** Playlist visualizer should activate when main window is shaded, requiring cross-window state observation.

**Discovery (Gemini verified):** Winamp shows playlist visualizer when main window is SHADED (not closed - closing main quits the app).

**Solution:** Migrate local @State to AppSettings for cross-window access:

```swift
// ❌ BEFORE: Local state (invisible to other windows)
struct WinampMainWindow: View {
    @State private var isShadeMode: Bool = false  // Can't observe from playlist
}

// ✅ AFTER: AppSettings with persistence
@Observable
@MainActor
final class AppSettings {
    var isMainWindowShaded: Bool = false {
        didSet {
            UserDefaults.standard.set(isMainWindowShaded, forKey: "isMainWindowShaded")
        }
    }
}

// Main window reads from AppSettings
struct WinampMainWindow: View {
    @Environment(AppSettings.self) var settings

    var body: some View {
        if settings.isMainWindowShaded {
            buildShadeMode()  // 14px bar
        } else {
            buildFullMode()   // Full 116px window
        }
    }
}

// Playlist observes same state
struct WinampPlaylistWindow: View {
    @Environment(AppSettings.self) var settings

    var body: some View {
        if settings.isMainWindowShaded && sizeState.size.width >= 3 {
            VisualizerView()  // Mini visualizer activates
        }
    }
}
```

**State Flow:**
```
AppSettings.isMainWindowShaded (source of truth, persisted)
    │
    ├── WinampMainWindow reads → renders full/shade mode
    │
    ├── WinampPlaylistWindow reads → shows/hides mini visualizer
    │
    └── AppCommands reads → updates menu item text
```

---

### Pattern 6: NSWindow/SwiftUI Sync Hooks

**Problem:** NSWindow frame and SwiftUI state can become desynchronized, especially on app launch or programmatic changes.

**Bugs Found:**

1. **NSWindow constraints blocked resize:**
```swift
// ❌ BEFORE (WinampPlaylistWindowController):
window.minSize = NSSize(width: 275, height: 232)  // Fixed height!
window.maxSize = NSSize(width: 275, height: 900)  // Fixed width!

// ✅ AFTER:
window.minSize = NSSize(width: 275, height: 116)   // Allows collapse
window.maxSize = NSSize(width: 2000, height: 900)  // Allows expansion
```

2. **Persisted size discarded on launch:**
```swift
// ❌ BEFORE (WindowCoordinator.applyPersistedWindowPositions):
storedPlaylist.size.width = 275  // Always forced to minimum!

// ✅ AFTER:
let clampedWidth = max(PlaylistWindowSizeState.baseWidth, storedPlaylist.size.width)
// Preserves user's saved width
```

3. **Missing sync hooks:**
```swift
// ✅ ADD to WinampPlaylistWindow:
.onAppear {
    // Sync NSWindow from persisted PlaylistWindowSizeState
    WindowCoordinator.shared?.updatePlaylistWindowSize(to: sizeState.pixelSize)
}
.onChange(of: sizeState.size) { _, newSize in
    // Sync NSWindow on programmatic size changes
    let pixelSize = newSize.toPlaylistPixels()
    WindowCoordinator.shared?.updatePlaylistWindowSize(to: pixelSize)
}
```

**WindowCoordinator Bridge Method:**
```swift
func updatePlaylistWindowSize(to pixelSize: CGSize) {
    guard let window = playlistWindow else { return }
    var frame = window.frame
    let oldHeight = frame.height

    // NOTE: Playlist does NOT use double-size mode (unlike main/EQ)
    frame.size = pixelSize
    frame.origin.y += oldHeight - pixelSize.height  // Anchor top-left
    window.setFrame(frame, display: true)
}
```

---

### Pattern 7: Playlist Does NOT Use Double-Size Mode

**Discovery:** After implementing resize, double-size toggle caused incorrect scaling.

**Investigation:** Webamp's PlaylistWindow has NO doubleSize references (verified via grep).

**Conclusion:** Only Main and EQ windows use double-size mode. Playlist resizes via segment grid, not 2x scaling.

```swift
// ❌ WRONG: Applying double-size to playlist
func updatePlaylistWindowSize(to pixelSize: CGSize) {
    let scale = settings.isDoubleSize ? 2.0 : 1.0  // ← WRONG for playlist
    frame.size = CGSize(width: pixelSize.width * scale, ...)
}

// ✅ CORRECT: No scaling for playlist
func updatePlaylistWindowSize(to pixelSize: CGSize) {
    // Playlist uses segment-based sizing, not 2x scaling
    frame.size = pixelSize
}
```

---

### Pattern 8: ZStack Alignment in Conditional Rendering

**Bug:** Shade mode buttons weren't clickable after shade/unshade toggle.

**Root Cause:** Inner ZStack had default `.center` alignment, but button `.offset()` was applied via `.at()` modifier:

```swift
// ❌ WRONG: Default center alignment + offset = buttons outside frame
ZStack {  // Default: alignment: .center
    buildShadeButtons()
        .at(x: 10, y: 3)  // Offset from CENTER = way outside 14px frame!
}

// ✅ CORRECT: topLeading alignment for offset-based positioning
ZStack(alignment: .topLeading) {
    buildShadeButtons()
        .at(x: 10, y: 3)  // Offset from TOP-LEFT = correct position
}
```

**Rule:** When using `.at(x:y:)` offset-based positioning, always use `ZStack(alignment: .topLeading)`.

---

### Playlist Resize Pattern Checklist

When implementing similar resizable windows:

- [ ] **Create SizeState class** with window-specific computed properties
- [ ] **Add Size2D presets** for minimum/default/2x sizes
- [ ] **Verify sprite widths** against webamp source (don't trust existing code)
- [ ] **Use background tiling** with overlays (not per-side placement)
- [ ] **Implement three-section layout** if chrome has expandable center
- [ ] **Add scroll slider** with bridge contract (binding to offset)
- [ ] **Clamp scroll offset** when playlist/window size changes
- [ ] **Fix NSWindow constraints** in WindowController
- [ ] **Add onAppear/onChange** sync hooks for SwiftUI/AppKit sync
- [ ] **Verify double-size behavior** (some windows don't scale)
- [ ] **Test ZStack alignment** when using offset-based positioning
- [ ] **Cross-window state** via AppSettings for features like visualizer activation
- [ ] **Thread Sanitizer clean** builds required
- [ ] **Oracle Grade A-** validation before merge

---

## Build & Distribution

### SPM vs Xcode Build Structures

**Critical lesson:** Bundle resource paths differ between build systems.

```swift
// Correct bundle path resolution
let bundleURL: URL
#if SWIFT_PACKAGE
// SPM: Resource bundle at .build/.../MacAmp_MacAmpApp.bundle/
bundleURL = Bundle.module.bundleURL
#else
// Xcode: Resources folder at MacAmpApp.app/Contents/Resources/
bundleURL = Bundle.main.resourceURL ?? Bundle.main.bundleURL
#endif
```

**Why this matters:**

| Build Type | bundleURL | resourceURL | Skins Location |
|------------|-----------|-------------|----------------|
| SPM | `.../MacAmp_MacAmpApp.bundle/` | `nil` | `*.wsz` at bundle root |
| Xcode | `.../MacAmpApp.app` | `.../Resources/` | `*.wsz` in Resources/ |

### Code Signing for Distribution

**Critical P0 lesson:** Xcode code signing happens AFTER build phases.

**Problem:**
```
Build Phases:
1. Compile Sources
2. Copy Resources
3. Link Binary
4. RUN SCRIPT PHASE ← Copying to dist/ HERE (WRONG!)
5. CODE SIGN ← Signing happens AFTER copy
```

Result: Unsigned app in `dist/` directory.

**Solution: Use Scheme Post-Action**

```xml
<!-- MacAmpApp.xcscheme -->
<BuildAction>
    <PostActions>
        <ExecutionAction
            ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
            <ActionContent
                title = "Copy Signed App to dist"
                scriptText = "
# Only run for Release builds
if [ &quot;${CONFIGURATION}&quot; = &quot;Release&quot; ]; then
    echo &quot;[Post-Action] Copying signed app to dist/&quot;

    # Create dist directory
    mkdir -p &quot;${PROJECT_DIR}/dist&quot;

    # Copy signed app
    ditto &quot;${BUILT_PRODUCTS_DIR}/MacAmp.app&quot; &quot;${PROJECT_DIR}/dist/MacAmp.app&quot;

    # Verify code signature
    codesign --verify --deep --strict &quot;${PROJECT_DIR}/dist/MacAmp.app&quot;

    if [ $? -eq 0 ]; then
        echo &quot;[Post-Action] ✓ Code signature verified successfully&quot;
    else
        echo &quot;[Post-Action] ✗ Code signature verification failed&quot;
        exit 1
    fi
fi
">
            </ActionContent>
        </ExecutionAction>
    </PostActions>
</BuildAction>
```

**Post-actions run AFTER CodeSign phase**, ensuring the copied app is properly signed.

### Notarization Workflow (Complete from Real Experience)

#### First Attempt Will Likely Fail

**Our Experience:** First notarization returned "Invalid" with 3 errors:

```json
"issues": [
  {
    "message": "The signature does not include a secure timestamp."
  },
  {
    "message": "The executable does not have the hardened runtime enabled."
  },
  {
    "message": "The executable requests the com.apple.security.get-task-allow entitlement."
  }
]
```

#### What You Must Enable

**1. Hardened Runtime:**
```bash
xcodebuild -configuration Release build \
  ENABLE_HARDENED_RUNTIME=YES
```

**2. Secure Timestamp:**
```bash
xcodebuild -configuration Release build \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime"
```

**3. Remove Debug Entitlements:**

Xcode adds `com.apple.security.get-task-allow` for Debug builds (allows debugger attach).
This is NOT allowed in notarized apps.

**Solution:** Re-sign with your .entitlements file:
```bash
codesign --force \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  --entitlements MacAmpApp/MacAmp.entitlements \
  --timestamp \
  --options=runtime \
  --deep \
  dist/MacAmp.app
```

#### Complete Notarization Sequence

**1. Store Credentials (One-Time):**
```bash
xcrun notarytool store-credentials "notarytool-password" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID"
# Paste app-specific password from appleid.apple.com
```

**2. Build with All Requirements:**
```bash
xcodebuild -project MacAmpApp.xcodeproj \
  -scheme MacAmpApp \
  -configuration Release \
  build \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime"
```

**3. Re-Sign (Remove Debug Entitlements):**
```bash
codesign --force \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  --entitlements MacAmpApp/MacAmp.entitlements \
  --timestamp \
  --options=runtime \
  --deep \
  dist/MacAmp.app
```

**4. Verify All Requirements:**
```bash
# Check hardened runtime
codesign -dvvv dist/MacAmp.app | grep runtime
# Should show: flags=0x10000(runtime)

# Check no debug entitlements
codesign -d --entitlements - dist/MacAmp.app | grep get-task-allow
# Should return nothing

# Check signature valid
codesign -vvv --deep --strict dist/MacAmp.app
# Should show: valid on disk
```

**5. Create ZIP:**
```bash
cd dist
ditto -c -k --keepParent MacAmp.app MacAmp.zip
```

**6. Submit and Wait:**
```bash
xcrun notarytool submit MacAmp.zip \
  --keychain-profile "notarytool-password" \
  --wait
```

Result: "Accepted" or "Invalid" (check logs if invalid)

**7. Staple Ticket:**
```bash
xcrun stapler staple dist/MacAmp.app
```

**8. Verify Gatekeeper:**
```bash
spctl -a -vv dist/MacAmp.app
# Should show: accepted, source=Notarized Developer ID
```

**9. Create Professional DMG:**
```bash
# Staging folder with README and symlink
mkdir /tmp/macamp_dmg
cp -R dist/MacAmp.app /tmp/macamp_dmg/
cp README.md /tmp/macamp_dmg/
ln -s /Applications /tmp/macamp_dmg/Applications

# Create DMG
hdiutil create \
  -volname "MacAmp v0.7.5" \
  -srcfolder /tmp/macamp_dmg \
  -ov \
  -format UDZO \
  dist/MacAmp-Notarized.dmg

rm -rf /tmp/macamp_dmg
```

**10. Verify DMG:**
```bash
hdiutil verify dist/MacAmp-Notarized.dmg
hdiutil attach dist/MacAmp-Notarized.dmg -readonly
spctl -a -vv /Volumes/MacAmp\ v0.7.5/MacAmp.app
# Should show: accepted
hdiutil detach /Volumes/MacAmp\ v0.7.5
```

#### Troubleshooting Common Errors

**"Invalid" - Check Logs:**
```bash
xcrun notarytool log SUBMISSION_ID --keychain-profile "notarytool-password"
```

**Disk I/O Errors During Build:**
```bash
# Clean corrupted DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/MacAmpApp-*
xcodebuild clean
```

#### Professional DMG Layout

**What Users See:**
```
MacAmp DMG
├── MacAmp.app (notarized)
├── README.md (user guide)
└── Applications → /Applications (drag-and-drop install)
```

**Why This Matters:**
- README explains features and how to use
- Applications symlink enables drag-and-drop install
- Professional appearance builds trust

---

## Common Pitfalls & Solutions

### 1. Assuming All Skins Are Identical

**❌ Wrong Assumption:**
"All Winamp skins contain the same 15-20 BMP files with standardized layouts"

**✅ Reality:**
- Classic skins use `NUMBERS.bmp` (11 sprites)
- Extended skins use `NUMS_EX.bmp` (12 sprites)
- Some skins have both, some have neither
- Optional sheets: `EQ_EX.bmp`, `VIDEO.bmp`, `GENEX.bmp`

**Solution:** Semantic sprite resolution + fallback system

### 2. Hardcoding Sprite Names in Views

**❌ Wrong:**
```swift
SimpleSpriteImage("DIGIT_0", width: 9, height: 13)  // Breaks with NUMS_EX skins
```

**✅ Right:**
```swift
SimpleSpriteImage(.digit(0), width: 9, height: 13)  // Adapts to any skin
```

### 3. Using bundleURL Instead of resourceURL

**❌ Wrong (Xcode builds):**
```swift
let bundleURL = Bundle.main.bundleURL  // Points to MacAmp.app (not Resources/)
```

**✅ Right:**
```swift
#if SWIFT_PACKAGE
let bundleURL = Bundle.module.bundleURL
#else
let bundleURL = Bundle.main.resourceURL ?? Bundle.main.bundleURL
#endif
```

### 4. Crashing on Missing Sprites

**❌ Wrong:**
```swift
let digit = skinManager.currentSkin!.images["DIGIT_0"]!  // Force unwraps = crash
```

**✅ Right:**
```swift
// Use SpriteResolver with fallbacks
if let name = spriteResolver?.resolve(.digit(0)),
   let image = skinManager.currentSkin?.images[name] {
    Image(nsImage: image)
} else {
    Rectangle().fill(Color.clear)  // Invisible fallback
}
```

### 5. Race Condition in Audio Seeking

**❌ Wrong:**
```swift
func seek(to time: Double) {
    playerNode.stop()  // Triggers completion from OLD segment
    scheduleSegment(from: time)
}

// completion handler fires from old segment
// currentTime jumps to end of old segment
```

**✅ Right:**
```swift
private var currentSeekID = UUID()

func seek(to time: Double) {
    currentSeekID = UUID()  // Invalidate old completions
    scheduleSegment(from: time, seekID: currentSeekID)
}

func handleCompletion(seekID: UUID?) {
    guard seekID == currentSeekID else {
        return  // Ignore old completion
    }
    // Handle completion
}
```

### 6. Trusting AI to Extract Sprite Coordinates

**❌ Wrong (causes visual/functional mismatch):**
```swift
// AI hallucinates coordinates without verifying bitmap:
Sprite(name: "PLAYLIST_CROP", x: 54, y: 168)  // Wrong y coordinate
Sprite(name: "PLAYLIST_REMOVE_ALL", x: 54, y: 130)  // Wrong y coordinate

// Variable names don't match actual visuals:
let cropItem = SpriteMenuItem(
    normalSprite: "PLAYLIST_REMOVE_ALL",  // Name says ALL but shows CROP visual
    action: #selector(cropPlaylist)  // Confusing mismatch
)
```

**✅ Right (verify from source bitmap):**
```swift
// ALWAYS verify coordinates using image editor:
// 1. Open PLEDIT.BMP in Preview
// 2. Tools → Show Inspector (⌘I)
// 3. Hover over top-left corner of sprite
// 4. Read (x, y) coordinates from Inspector

// Correct mappings (verified from bitmap):
Sprite(name: "PLAYLIST_REMOVE_MISC", x: 54, y: 168)
Sprite(name: "PLAYLIST_REMOVE_ALL", x: 54, y: 111)
Sprite(name: "PLAYLIST_CROP", x: 54, y: 130)
Sprite(name: "PLAYLIST_REMOVE_SELECTED", x: 54, y: 149)

// Variable names MUST match visual sprites:
let cropItem = SpriteMenuItem(
    normalSprite: "PLAYLIST_CROP",  // Name matches visual
    action: #selector(cropPlaylist)
)
```

**Best Practices for Sprite Extraction:**
1. **Create annotated reference images** (e.g., PLEDIT_ANNOTATED.png)
2. **Use Preview Inspector** (macOS) or similar tool to measure pixel coordinates
3. **Document coordinates** in comments with verification date
4. **Consider Gemini CLI** for automated sprite sheet analysis with large context
5. **Verify variable names** match actual sprite visuals, not just coordinate references
6. **Never assume** - AI cannot reliably "see" bitmap sprite coordinates

**Prevention:**
```bash
# Use Gemini CLI to analyze entire sprite sheet with verification:
gemini -p "@path/to/PLEDIT.BMP Analyze this sprite sheet and extract all sprite coordinates. For each sprite at column x:54, list the y-coordinate and describe what text/graphic is visible in the sprite."
```

### 7. Ignoring SwiftUI View Body Minimization

**❌ Wrong (causes ghost images):**
```swift
var body: some View {
    let spriteName = resolveSprite()  // Computed every time
    SimpleSpriteImage(spriteName)     // Re-renders unnecessarily
}
```

**✅ Right (cache computed values):**
```swift
@State private var displayedTime: Int = 0

var body: some View {
    // Only update when rounded time changes
    if Int(audioPlayer.currentTime) != displayedTime {
        displayedTime = Int(audioPlayer.currentTime)
    }

    Text("\(displayedTime)")  // 10x fewer re-renders
}
```

---

## Performance Optimizations

### 1. Sprite Sheet Caching

```swift
// Pre-process backgrounds during load (NOT at render time)
private func preprocessBackground(image: NSImage, skin: Skin) -> NSImage {
    let processed = NSImage(size: image.size)
    processed.lockFocus()

    // Draw original background
    image.draw(at: .zero, from: .zero, operation: .copy, fraction: 1.0)

    // Black out time display area (hide static "00:00")
    NSColor.black.setFill()
    NSRect(x: 39, y: 26, width: 48, height: 13).fill()

    processed.unlockFocus()
    return processed
}
```

**Result:** One-time preprocessing vs. masking on every frame.

### 2. Off-Main-Thread Audio Processing

```swift
mixer.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
    // Audio thread (NOT main thread)
    let spectrum = self?.computeSpectrum(buffer) ?? []

    // Only marshal small result to main thread
    DispatchQueue.main.async {
        self?.visualizerLevels = spectrum  // ~75 floats
    }
}
```

**Impact:** Audio processing doesn't block UI thread.

### 3. Debounced Persistence

```swift
$panes
    .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
    .sink { [weak self] panes in
        self?.persist(panes: panes)
    }
```

**Scenario:** User clicks toggle 5 times rapidly
- Without debounce: 5 JSON encodes + 5 UserDefaults writes
- With debounce: 1 JSON encode + 1 write after 150ms silence

### 4. Progress Timer Optimization

```swift
// Update every 100ms (not 16ms/60fps)
progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
    guard let self = self else { return }

    if let nodeTime = self.playerNode.lastRenderTime,
       let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) {
        self.currentTime = Double(playerTime.sampleTime) / self.sampleRate
    }
}
```

**Balance:** 100ms = smooth enough for time display, low CPU usage.

---

## Testing Strategies

### Manual Testing Matrix

| Skin | NUMBERS | NUMS_EX | VOLUME | EQ_EX | Expected Result |
|------|---------|---------|--------|-------|-----------------|
| Classic Winamp | ✅ | ❌ | ❌ | ❌ | Works perfectly |
| Internet Archive | ❌ | ✅ | ✅ | ✅ | Works perfectly |
| Winamp3 Classified | ✅ | ✅ | ✅ | ✅ | Works perfectly |

### Build Verification Checklist

```bash
# 1. SPM build
swift build
[ ] Succeeds with 0 errors, 0 warnings
[ ] Skins present in .build/.../MacAmp_MacAmpApp.bundle/

# 2. Xcode build
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Release build
[ ] Succeeds with 0 errors, 0 warnings
[ ] Skins present in MacAmpApp.app/Contents/Resources/

# 3. Code signature verification
codesign --verify --deep --strict dist/MacAmp.app
[ ] Exits with code 0

# 4. Notarization verification
spctl -a -vv dist/MacAmp.app
[ ] "source=Notarized Developer ID" appears

# 5. Launch verification
open dist/MacAmp.app
[ ] No security warnings
[ ] App launches successfully
[ ] Default skin loads
```

### Skin Switching Tests

```
1. Press ⌘⇧1 (Classic Winamp)
   [ ] Green digits appear
   [ ] Classic Winamp colors/style
   [ ] All 3 windows update simultaneously
   [ ] No console errors

2. Press ⌘⇧2 (Internet Archive)
   [ ] White/light digits appear
   [ ] Modern silver/chrome style
   [ ] Console shows "⚠️ MISSING SHEET: NUMBERS" (NORMAL!)
   [ ] Console shows "✅ OPTIONAL: Found NUMS_EX.BMP"

3. Play audio track
   [ ] Digits increment smoothly
   [ ] No ghost "00:00" from background
   [ ] Pause blink works correctly
```

---

## Lessons Learned

### 1. Architecture Revelation: Mechanism vs Presentation

**The Insight:**
> "We must build the mechanisms that do the work, but are allowed to be covered by skins as they change. The digits increment in some skins but not others. We must decouple the action and mechanisms from the skin that is put over the top of these elements and functions."

**Translation:** Build functional components (mechanism layer) that render semantic elements, with a presentation layer (skin) that overlays visual styling. DO NOT hardcode sprite names in UI components.

**Before (Broken):**
```
UI Component → Hardcoded Sprite Name → Skin Lookup
     ↓              ↓                       ↓
  Volume        "DIGIT_0"            DIGIT_0 or fail
```

**After (Fixed):**
```
Mechanism → Semantic Request → Sprite Resolver → Actual Sprite
    ↓            ↓                  ↓                  ↓
  Timer      .digit(0)      Check skin availability   DIGIT_0_EX or DIGIT_0
```

### 2. Winamp Skins Are NOT Standardized

Different Winamp skins from different eras use:
- Different sprite sheets (NUMBERS vs NUMS_EX)
- Different naming conventions (_EX suffix)
- Different optional features (EQ_EX, VIDEO, GENEX)

**Lesson:** Never assume a sprite exists. Always use fallbacks.

### 3. Code Signing Happens AFTER Build Phases

**Critical P0 bug:** Copying to `dist/` in a Build Phase Script resulted in an unsigned app because code signing happens AFTER build phases.

**Solution:** Use Scheme Post-Actions which run after ALL build phases including CodeSign.

### 4. SPM vs Xcode Have Different Bundle Structures

**SPM:** Resources at `Bundle.module.bundleURL` (direct access)
**Xcode:** Resources at `Bundle.main.resourceURL` (inside app bundle)

**Lesson:** Always use conditional compilation for bundle paths:

```swift
#if SWIFT_PACKAGE
bundleURL = Bundle.module.bundleURL
#else
bundleURL = Bundle.main.resourceURL ?? Bundle.main.bundleURL
#endif
```

### 5. SwiftUI Body Minimization is Essential

**Problem:** Every @Published property change triggers body re-evaluation.

**Solution:** Cache computed values in @State:

```swift
@State private var displayedTime: Int = 0

var body: some View {
    // Only recompute when rounded time changes
    if Int(audioPlayer.currentTime) != displayedTime {
        displayedTime = Int(audioPlayer.currentTime)
    }

    // Use cached value
    Text("\(displayedTime)")
}
```

**Impact:** 10x reduction in body re-evaluations.

### 6. Audio Seeking Has Race Conditions

**Problem:** `playerNode.stop()` triggers completion handler from the PREVIOUS segment, corrupting playback progress.

**Solution:** Use seek IDs to ignore stale completions:

```swift
private var currentSeekID = UUID()

func seek(to time: Double) {
    currentSeekID = UUID()  // New operation
    scheduleSegment(from: time, seekID: currentSeekID)
}

func handleCompletion(seekID: UUID?) {
    guard seekID == currentSeekID else { return }
    // Process completion
}
```

### 7. Spectrum Analyzer Requires Balanced Distribution

**Problem:** Linear frequency distribution over-weights high frequencies (human hearing is logarithmic).

**Solution:** Use hybrid log-linear scaling (91% log, 9% linear):

```swift
let scale: Float = 0.91
let scaledIndex = (1.0 - scale) * linearIndex + scale * logIndex
```

**Result:** Bass/mid/treble frequencies all get appropriate visual representation.

### 8. Fallback Systems Prevent Crashes

**Problem:** Users load arbitrary .wsz files from the internet (70,000+ exist). Many are incomplete or corrupted.

**Solution:** Three-tier fallback system:
1. Missing sheet → Generate transparent placeholders for all sprites
2. Corrupted sheet → Generate transparent placeholders for all sprites
3. Individual sprite crop failure → Generate transparent placeholder for that sprite

**Result:** App never crashes, degrades gracefully with invisible fallbacks.

### 9. Hybrid AppKit/SwiftUI Architecture: When NSWindowController is Correct

**The Problem:** SwiftUI WindowGroup has fundamental limitations for multi-window apps requiring:
- Singleton window guarantees
- NSWindow delegate control (for magnetic docking)
- Close-to-hide behavior (not auto-destroy)
- Menu synchronization without duplicate windows

**Critical Discovery (November 2025):**

After implementing magnetic window docking with WindowSnapManager, an Oracle consultation suggested migrating to SwiftUI Windows for "modern patterns." However, re-consulting the Oracle with full historical context from the magnetic-docking implementation revealed this was an **oversight**.

**WindowGroup Limitations (NOT fixed in macOS 15/26):**
```swift
// ❌ WindowGroup creates duplicates, not singletons
WindowGroup("Main", id: "main") {
    MainWindowView()
}
// User clicks "Window > Show Main Window" → Creates NEW instance!
// Menu sync broken, snap state lost, position forgotten

// ❌ WindowGroup auto-destroys on close
// Cannot intercept close to hide instead of destroy

// ❌ WindowGroup doesn't expose NSWindow early enough
// WindowSnapManager needs delegate access during window creation
```

**The Correct Pattern:**
```swift
// ✅ NSWindowController for singleton windows with delegate control
@MainActor
class WindowCoordinator: Observable {
    private var mainWindowController: NSWindowController
    private var eqWindowController: NSWindowController
    private var playlistWindowController: NSWindowController

    init() {
        // Manual creation guarantees singletons
        // Direct delegate access for WindowSnapManager
        // Full lifecycle control (close-to-hide)
    }
}

// ✅ Placeholder WindowGroup for SwiftUI App lifecycle
@main
struct MacAmpApp: App {
    var body: some Scene {
        // Satisfies SwiftUI's requirement for main scene
        WindowGroup(id: "main-placeholder") {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .defaultSize(width: 0, height: 0)

        // Only ancillary scenes use WindowGroup
        WindowGroup("Preferences", id: "preferences") {
            PreferencesView()
        }
        .defaultLaunchBehavior(.suppressed)
    }
}
```

**Key Insight:** This is NOT fighting SwiftUI patterns—it's the **recommended hybrid pattern** for apps requiring AppKit-level window control. Apple's own apps (Xcode, Final Cut Pro) use this approach.

**When to Use NSWindowController:**
- Magnetic window docking/snapping
- Singleton window enforcement
- Custom window delegates
- Close-to-hide behavior
- Window clustering

**When to Use SwiftUI WindowGroup:**
- Standard document-based apps
- Multi-instance windows (no singleton requirement)
- Apps without custom window lifecycle needs
- Simple preferences/settings panels

### 10. Oracle Consultation Methodology: Multi-Turn with Historical Context

**The Problem:** An Oracle (AI assistant like Codex) may make recommendations without full awareness of project-specific constraints discovered during earlier implementation phases.

**Real-World Example:**

1. **November 2025 - Magnetic Docking Implementation:**
   - 3 independent Oracle reviews
   - Extensively documented WindowGroup limitations
   - Chose NSWindowController for singleton guarantees
   - Risk level: HIGH (8/10), Confidence: 70%

2. **Later - Release Build Assessment:**
   - Oracle suggested "migrate to SwiftUI Windows for modern patterns"
   - Rated architecture 6/10 (technical debt)
   - Recommended @SceneStorage, scene-based lifecycle

3. **Re-consultation with Full Context:**
   - Presented complete historical documentation
   - **Oracle completely reversed recommendation**
   - Acknowledged earlier suggestion was "oversight"
   - Validated NSWindowController as correct architecture

**Oracle's Key Statement:**
> "You're absolutely right to call out the contradiction. The later comment that floated 'use SwiftUI Window scenes' was my mistake—not a reflection of new APIs. The earlier warning stands."

**Best Practices for Oracle Consultation:**

```bash
# ❌ WRONG: Ask Oracle without context
codex "@CurrentFile.swift Should I migrate to SwiftUI Windows?"

# ✅ RIGHT: Include historical decision context
codex "@CurrentFile.swift @tasks/magnetic-docking/CODEX_REVIEW.md @tasks/magnetic-docking/state.md
Review the recommendation to migrate to SwiftUI Windows.
Historical context shows WindowGroup was rejected for singleton guarantees.
Did macOS 15/26 fix this? What specific APIs would enable migration?"
```

**Critical Questions to Ask:**
1. Did newer APIs fix the original problem?
2. What specific features enable the new approach?
3. Does migration provide concrete benefits, or just "modern patterns"?
4. What would migration break in existing functionality?
5. Is perceived "technical debt" actually correct architecture for requirements?

**Lesson:** Always challenge architectural recommendations with project-specific constraints. Include historical decision rationale when consulting Oracles. Oracles have limited context and may suggest "improvements" that ignore critical requirements.

### 11. Technical Debt vs Correct Architecture: Validation Framework

> **Note:** See also Lesson #22 for Quality Gate validation with Oracle reviews.

**The Problem:** Code that appears to "fight framework patterns" may actually be the correct approach for specific requirements.

**Before Oracle Re-consultation:**
```
Assessment: 6/10 - "Architecture accumulates technical debt"
Issues identified:
- Placeholder WindowGroup (empty, hidden)
- Manual NSWindow management
- No ScenePhase awareness for main UI
- Custom frame persistence logic
```

**After Oracle Re-consultation with Full Context:**
```
Assessment: 8/10 - "Correct architecture for requirements"
Validation:
- Placeholder WindowGroup: NECESSARY for SwiftUI App lifecycle
- Manual NSWindow: REQUIRED for magnetic docking
- No ScenePhase: ACCEPTABLE (main UI isn't SwiftUI scene)
- Custom persistence: APPROPRIATE for NSWindow frames
```

**Validation Checklist:**

| Perceived Debt | Question | If YES → | If NO → |
|---------------|----------|----------|---------|
| Placeholder/empty scene | Does it satisfy framework requirement? | Necessary pattern | Actual debt |
| Manual lifecycle management | Does feature require it? | Required architecture | Over-engineering |
| Custom state persistence | Does framework provide equivalent? | Migrate to framework | Keep custom |
| Non-standard patterns | Do requirements mandate it? | Correct for use case | Technical debt |

**Real Example:**
```swift
// This LOOKS like debt:
WindowGroup(id: "main-placeholder") {
    EmptyView().hidden()
}
.defaultLaunchBehavior(.suppressed)

// But it's NECESSARY because:
// 1. SwiftUI App requires at least one scene
// 2. Main windows are NSWindows (magnetic docking requirement)
// 3. Without placeholder, SwiftUI auto-opens Preferences
// 4. Modifiers prevent unwanted behavior

// This is NOT debt to eliminate—it's correct hybrid pattern
```

**Key Insight:** Before labeling code as "technical debt," verify:
1. What requirement does this pattern satisfy?
2. Does the framework provide an alternative that meets ALL requirements?
3. What would break if you "fix" it?
4. Has the original decision been documented with rationale?

**Action:** When you identify "debt," trace back to the original implementation decision. If requirements haven't changed and the pattern still satisfies them, it's not debt—it's correct architecture.

### 12. Force Unwrap Elimination Patterns (January 2026)

**The Problem:** Force unwraps (`!`) create implicit crash points. They're easy to write but hard to debug when they fail in production.

**Pattern 1: Optional.map for Conditional Transformation**

```swift
// ❌ BEFORE: Ternary with force unwrap
return Point(
    x: (newPos.x == nil ? 0 : newPos.x! - a.x),
    y: (newPos.y == nil ? 0 : newPos.y! - a.y)
)

// ✅ AFTER: Optional.map with nil coalescing
return Point(
    x: newPos.x.map { $0 - a.x } ?? 0,
    y: newPos.y.map { $0 - a.y } ?? 0
)
```

**When to use:** Transform an optional value and provide a default. The pattern `optional.map { transform } ?? default` is idiomatic Swift and zero-cost at runtime.

**Pattern 2: flatMap for Empty String Handling**

```swift
// ❌ BEFORE: Awkward empty check with force unwrap
let finalName = (suggestedName?.isEmpty == false ? suggestedName! : fallbackName)

// ✅ AFTER: flatMap converts empty to nil
let finalName = suggestedName.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName
```

**When to use:** When you need to treat empty strings as `nil` for clean nil-coalescing.

**Pattern 3: Guard Chain for Sequential Optionals**

```swift
// ❌ BEFORE: Force unwrap in guard
guard let rep = NSBitmapImageRep(data: image.tiffRepresentation!) else { return [] }

// ✅ AFTER: Chain optionals in guard
guard let tiffData = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiffData) else {
    return []
}
```

**When to use:** When one optional depends on another. Guard chains fail gracefully if either is nil.

**Pattern 4: Swift 6 URL.cachesDirectory (Non-Optional)**

```swift
// ❌ BEFORE: Force unwrap on directory URL
let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!

// ✅ AFTER: Swift 6 non-optional directory (macOS 13+)
let caches = URL.cachesDirectory
    .appending(component: "MacAmp/Cache", directoryHint: .isDirectory)
```

**Key Insight:** `URL.cachesDirectory`, `URL.documentsDirectory`, `URL.applicationSupportDirectory` are **non-optional** in macOS 13+. No force unwrap or guard needed.

### 13. Component Extraction Strategy: Risk-Ordered Incremental Refactoring

**The Problem:** Monolithic files (1,800+ lines) accumulate coupling over time. Big-bang refactoring risks breaking everything at once.

**Solution: Risk-Ordered Incremental Extraction**

```
Phase Sequence:
┌─────────────────────────────────────────────────────┐
│  LOW RISK                                           │
│  EQPresetStore (preset persistence) → 96 lines      │
│  MetadataLoader (async track info) → 171 lines      │
│  PlaylistController (navigation) → 260 lines        │
├─────────────────────────────────────────────────────┤
│  MEDIUM RISK                                        │
│  VideoPlaybackController (AVPlayer) → 259 lines     │
├─────────────────────────────────────────────────────┤
│  HIGH RISK (COMPLETED - see Lesson #24)              │
│  VisualizerPipeline (SPSC buffer) → 678 lines        │
├─────────────────────────────────────────────────────┤
│  HIGHEST RISK - DEFER DECISION                      │
│  AudioEngineController (engine lifecycle)           │
└─────────────────────────────────────────────────────┘
```

**Result:** AudioPlayer reduced from 1,805 to 1,059 lines (-41.3%) without breaking changes.

**Computed Property Forwarding for API Stability:**

```swift
// In AudioPlayer - preserve existing API while delegating
var userPresets: [EQPreset] {
    eqPresetStore.userPresets
}

// Views continue using audioPlayer.userPresets unchanged
```

**Callback Patterns for Cross-Component Sync:**

```swift
// VideoPlaybackController notifies AudioPlayer of state changes
final class VideoPlaybackController {
    var onPlaybackEnded: (() -> Void)?
    var onTimeUpdate: ((Double, Double) -> Void)?  // currentTime, duration

    private func observeTimeUpdates() {
        onTimeUpdate?(currentTime, currentDuration)
    }
}

// AudioPlayer wires callbacks in init
videoController.onTimeUpdate = { [weak self] time, duration in
    self?.currentTime = time
    self?.currentDuration = duration
}
```

**Key Rules:**
1. Extract isolated functionality first (persistence, metadata, navigation)
2. Verify build + manual test after EACH extraction
3. Use computed properties to preserve existing API
4. Callback patterns for state synchronization
5. Defer highest-risk extractions until lower-risk ones prove stable
6. Re-evaluate deferred extractions—sometimes "good enough" IS the answer

### 14. Swift 6 Readiness: Sendable and Concurrency Patterns

**The Problem:** Swift 6 strict concurrency requires data crossing actor boundaries to be `Sendable`. Retrofitting later is painful.

**Pattern 1: Sendable Data Transfer Types**

```swift
// Mark all data-only structs as Sendable NOW
struct Track: Codable, Hashable, Sendable {
    let url: URL
    let title: String
    let duration: Double?
}

struct EQPreset: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let bands: [Float]
}

struct ButterchurnFrame: Sendable {
    let left: [Float]
    let right: [Float]
    let timestamp: Double
}
```

**When to add Sendable:** Any struct/enum that:
- Passes between actors
- Goes into async closures
- Gets captured by `Task.detached`

**Pattern 2: nonisolated(unsafe) for deinit Cleanup**

```swift
@MainActor
final class VideoPlaybackController {
    // Properties needed in deinit must be nonisolated(unsafe)
    nonisolated(unsafe) private var videoEndObserver: Any?
    nonisolated(unsafe) private var videoTimeObserver: Any?

    deinit {
        // deinit is nonisolated, can access nonisolated(unsafe) properties
        if let observer = videoEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = videoTimeObserver {
            videoPlayer?.removeTimeObserver(observer)
        }
    }
}
```

**Key Insight:** `deinit` runs in a nonisolated context even for `@MainActor` classes. Use `nonisolated(unsafe)` for cleanup-only properties.

**Pattern 3: @Sendable Closures for Completion Handlers**

```swift
// Completion handlers crossing actor boundaries need @Sendable
func seek(to time: Double, completion: (@Sendable () -> Void)? = nil) {
    videoPlayer?.seek(to: CMTime(seconds: time, preferredTimescale: 1)) { _ in
        Task { @MainActor in
            completion?()
        }
    }
}
```

### 15. Background I/O with Task.detached

**The Problem:** File I/O on `@MainActor` blocks the UI thread, causing stutter during playlist load or preset save.

**Pattern: Fire-and-Forget Background Save**

```swift
func savePerTrackPresets() {
    // Capture state BEFORE dispatch (avoids race conditions)
    let presetsCopy = perTrackPresets
    let url = perTrackPresetsFileURL()

    Task.detached(priority: .utility) {
        do {
            let data = try JSONEncoder().encode(presetsCopy)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save per-track presets: \(error)")
        }
    }
}
```

**Pattern: Async Load with Merge Logic**

```swift
func loadPerTrackPresets() async {
    let url = perTrackPresetsFileURL()
    let loaded = await Task.detached(priority: .utility) {
        guard let data = try? Data(contentsOf: url),
              let presets = try? JSONDecoder().decode([String: EqfPreset].self, from: data)
        else { return [:] }
        return presets
    }.value

    // Merge: preserve any in-flight changes during load
    for (key, value) in loaded where perTrackPresets[key] == nil {
        perTrackPresets[key] = value
    }
}
```

**Key Rules:**
1. Capture state before `Task.detached` to avoid actor-hop races
2. Use `.utility` priority for I/O (not `.background` which is too low)
3. Merge loaded data with existing state to preserve in-flight changes
4. Fire-and-forget is safe for saves—loss of single save is acceptable

### 16. Pre-allocated Buffers for Audio Thread Safety

**The Problem:** Allocations on the audio render thread cause glitches. Every `malloc` risks blocking.

**Solution: Pre-allocate in init, reuse in tap handler**

```swift
final class VisualizerScratchBuffers {
    // Pre-allocated once in init
    var hannWindow: [Float]
    var fftInputReal: [Float]
    var fftInputImag: [Float]
    var fftOutputReal: [Float]
    var fftOutputImag: [Float]

    init(fftSize: Int) {
        // All allocations happen ONCE during init
        hannWindow = [Float](repeating: 0, count: fftSize)
        fftInputReal = [Float](repeating: 0, count: fftSize)
        fftInputImag = [Float](repeating: 0, count: fftSize)
        fftOutputReal = [Float](repeating: 0, count: fftSize)
        fftOutputImag = [Float](repeating: 0, count: fftSize)

        // Pre-compute Hann window (never changes)
        for i in 0..<fftSize {
            hannWindow[i] = 0.5 - 0.5 * cos(2 * .pi * Float(i) / Float(fftSize))
        }
    }
}

// In tap handler - ZERO allocations, only reuse
func processAudio(_ buffer: AVAudioPCMBuffer) {
    // Use pre-allocated buffers
    vDSP_vmul(samples, 1, scratch.hannWindow, 1, &scratch.fftInputReal, 1, vDSP_Length(fftSize))
    // ... FFT processing with pre-allocated arrays
}
```

**Key Insight:** Audio threads are real-time. Any system call (malloc, objc_msgSend, locks) can cause dropouts. Pre-allocate everything.

### 17. UserDefaults Keys Enum Pattern

**The Problem:** String-based UserDefaults keys are typo-prone and hard to refactor.

**Solution: Centralized Keys enum**

```swift
@MainActor
@Observable
final class AppSettings {
    enum Keys {
        static let volume = "volume"
        static let balance = "balance"
        static let shuffleEnabled = "shuffleEnabled"
        static let repeatMode = "repeatMode"
        static let eqEnabled = "eqEnabled"
        static let preampValue = "preampValue"
        static let doubleSize = "doubleSize"
        static let useSpectrumVisualizer = "useSpectrumVisualizer"
        // ... all 15+ keys in one place
    }

    var volume: Float = 1.0 {
        didSet { UserDefaults.standard.set(volume, forKey: Keys.volume) }
    }

    init() {
        volume = UserDefaults.standard.float(forKey: Keys.volume)
        // ... load all settings
    }
}
```

**Benefits:**
1. Autocomplete prevents typos
2. Find usages shows all access points
3. Refactoring is single-point change
4. No magic strings scattered across codebase

### 18. Placeholder.md Convention for Future Features

**The Problem:** `// TODO` comments scattered in code get lost. In-code placeholders for planned features pollute the codebase.

**Solution: Centralized placeholder.md per task**

```markdown
# Placeholder Documentation

## fallbackSkinsDirectory (MacAmpApp/Models/AppSettings.swift:167)

**Purpose:** Scaffolding for `tasks/default-skin-fallback/` feature
**Status:** Function defined but not called (intentional)
**Action:** Implement when feature activated, or remove if abandoned

## Streaming Volume Control (MacAmpApp/Audio/AudioPlayer.swift)

**Purpose:** AVPlayer volume control for internet radio
**Status:** Placeholder - AVPlayer volume API differs from AVAudioEngine
**Action:** Implement when streaming feature expanded
```

**Key Rules:**
1. NO `// TODO` comments in production code
2. Document placeholders in `tasks/<task-id>/placeholder.md`
3. Include file:line, purpose, status, and action
4. Review during task completion—remove or implement

### 19. Pre-commit Hooks with Tracked .githooks/ Directory

**The Problem:** `.git/hooks/` is not version-controlled. Team members don't get hooks automatically.

**Solution: Tracked .githooks/ directory**

```bash
# Create tracked hooks directory
mkdir -p .githooks
```

```bash
#!/bin/bash
# .githooks/pre-commit

STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$')

if [ -n "$STAGED_SWIFT_FILES" ]; then
    echo "🔍 Running SwiftLint on staged files..."

    if ! command -v swiftlint &> /dev/null; then
        echo "⚠️  SwiftLint not installed. Run: brew install swiftlint"
        exit 0  # Don't block if tool missing
    fi

    swiftlint lint --strict --quiet $STAGED_SWIFT_FILES
    if [ $? -ne 0 ]; then
        echo "❌ SwiftLint violations. Fix before committing."
        exit 1
    fi
    echo "✅ SwiftLint passed"
fi
```

**Setup (document in README):**

```bash
# Each developer runs once after clone
git config core.hooksPath .githooks
```

**Benefits:**
1. Hooks are version-controlled
2. All team members use same hooks after one-time setup
3. CI can use same hooks for consistency

### 20. Unmanaged Pointer Lifecycle Management

> **Note (Feb 2026):** The `Unmanaged<T>` pointer pattern described here has been **superseded** by the SPSC shared buffer approach in Lesson #24. The new pattern eliminates the need for `Unmanaged` pointers entirely by using a `nonisolated static func makeTapHandler()` that captures only `Sendable` types (`VisualizerSharedBuffer` and `VisualizerScratchBuffers`). The lifecycle management principles below remain valid for any C-callback context pattern.

**The Problem:** `Unmanaged<T>` pointers in audio taps can cause use-after-free if the owning object deallocates while the tap is still installed.

**Solution: Explicit removeTap() in deinit**

```swift
@MainActor
final class AudioPlayer {
    private let visualizerPipeline: VisualizerPipeline

    deinit {
        // CRITICAL: Remove tap BEFORE VisualizerPipeline deallocates
        // The tap handler holds Unmanaged pointer to pipeline
        visualizerPipeline.removeTap()

        // Now safe to invalidate timer
        progressTimer?.invalidate()
    }
}

final class VisualizerPipeline {
    // Must be nonisolated for deinit access
    nonisolated(unsafe) private var tapInstalled = false
    nonisolated(unsafe) private weak var mixerNode: AVAudioMixerNode?

    nonisolated func removeTap() {
        guard tapInstalled else { return }
        mixerNode?.removeTap(onBus: 0)
        tapInstalled = false
    }
}
```

**Key Pattern:** The object that INSTALLS the tap is responsible for REMOVING it. Don't rely on the tap handler's owner to clean up—explicitly call removeTap() in the installer's deinit.

### 21. Callback Pattern for Cross-Component State Sync

**The Problem:** Extracted components need to notify the parent of state changes without creating circular dependencies.

**Solution: Callback closures set by parent**

```swift
// Extracted component defines callbacks (but doesn't call parent directly)
final class VideoPlaybackController {
    var onPlaybackEnded: (() -> Void)?
    var onTimeUpdate: ((Double, Double) -> Void)?

    private func handlePlaybackEnded() {
        onPlaybackEnded?()  // Parent decides what to do
    }
}

// Parent wires callbacks in init
init() {
    videoController = VideoPlaybackController()

    videoController.onPlaybackEnded = { [weak self] in
        self?.handleVideoEnded()
    }

    videoController.onTimeUpdate = { [weak self] time, duration in
        self?.currentTime = time
        self?.currentDuration = duration
    }
}
```

**Benefits:**
1. No circular references (child doesn't know parent type)
2. Parent controls reaction to events
3. Easy to test—inject mock callbacks
4. [weak self] prevents retain cycles

### 22. Quality Gate: Achieving 10/10 Oracle Score

**The Problem:** Large refactorings accumulate issues across multiple commits. How do you know when you're "done"?

**Solution: Quality Gate Phase**

After completing feature work, add a dedicated "Quality Gate" phase:

```
Phase 9: Quality Gate Remediation
├── 9.0.1: High Priority - deinit cleanup (prevent crashes)
├── 9.0.2: High Priority - Unmanaged pointer safety (superseded by SPSC in Lesson #24)
├── 9.0.3: Medium Priority - Sendable conformance
├── 9.0.4: Medium Priority - Background I/O
├── 9.0.5: Low Priority - Comment styling consistency
└── 9.1.0: Final Oracle Review → Target 10/10
```

**Oracle Review Template:**

```bash
codex "@File1.swift @File2.swift @File3.swift
Quality Gate Review:
1. Thread safety - @MainActor, nonisolated(unsafe)
2. Memory safety - SPSC buffer lifecycle, weak references (Unmanaged superseded)
3. Swift 6 readiness - Sendable, @Sendable closures
4. Resource cleanup - deinit, observer removal
5. Background I/O - no UI blocking
6. API stability - computed forwarding preserved

Rate 1-10 with specific issues to fix."
```

**Scoring Interpretation:**
- 10/10: Ship it—all issues addressed
- 8-9/10: Ship with documented follow-ups
- 6-7/10: Address medium/high before shipping
- <6/10: Significant rework needed

**Key Insight:** The Quality Gate phase is when you FIX everything the Oracle finds. Don't defer—each unaddressed issue compounds. A 7.5/10 → 10/10 improvement might take 2 hours but prevents weeks of debugging later.

---

## Quick Reference

### File Structure

```
MacAmp/
├── MacAmpApp/
│   ├── Audio/
│   │   ├── AudioPlayer.swift           # Orchestrator (~1,059 lines after refactor)
│   │   ├── EQPresetStore.swift         # EQ preset persistence (96 lines)
│   │   ├── MetadataLoader.swift        # Async track metadata (171 lines)
│   │   ├── PlaylistController.swift    # Navigation & shuffle (260 lines)
│   │   ├── VideoPlaybackController.swift # AVPlayer lifecycle (259 lines)
│   │   └── VisualizerPipeline.swift    # Audio tap & FFT (512 lines)
│   ├── Models/
│   │   ├── SpriteResolver.swift        # Semantic → actual sprite mapping
│   │   ├── Skin.swift                  # Skin data model
│   │   ├── SkinSprites.swift           # Sprite definitions
│   │   └── Track.swift                 # Audio track model
│   ├── ViewModels/
│   │   ├── SkinManager.swift           # Skin loading & hot-swap
│   │   └── DockingController.swift     # Multi-window coordination
│   ├── Views/
│   │   ├── MainWindow/                 # Decomposed main player UI (10 files)
│   │   │   ├── WinampMainWindow.swift          # Root composer
│   │   │   ├── WinampMainWindowInteractionState.swift # @Observable state
│   │   │   ├── WinampMainWindowLayout.swift    # Coordinate constants
│   │   │   ├── MainWindowFullLayer.swift       # Full-mode composition
│   │   │   ├── MainWindowShadeLayer.swift      # Shade-mode composition
│   │   │   ├── MainWindowTransportLayer.swift  # Play/pause/stop/prev/next
│   │   │   ├── MainWindowTrackInfoLayer.swift  # Scrolling title + time
│   │   │   ├── MainWindowIndicatorsLayer.swift # Status indicators
│   │   │   ├── MainWindowSlidersLayer.swift    # Volume/balance/position
│   │   │   └── MainWindowOptionsMenuPresenter.swift # NSMenu bridge
│   │   ├── WinampEqualizerWindow.swift # EQ UI
│   │   ├── WinampPlaylistWindow.swift  # Playlist UI
│   │   └── SimpleSpriteImage.swift     # Sprite rendering component
│   ├── Utilities/
│   └── Skins/                          # Bundled .wsz files
├── docs/                               # Technical documentation
├── tasks/                              # Development planning
└── Package.swift                       # Swift Package Manager config
```

### Key Coordinates (Classic Winamp Skin)

```swift
struct Coords {
    static let timeDisplay = CGPoint(x: 39, y: 26)      // 48×13
    static let volumeSlider = CGPoint(x: 107, y: 57)    // 68×13
    static let balanceSlider = CGPoint(x: 177, y: 57)   // 38×13
    static let positionSlider = CGPoint(x: 16, y: 72)   // 248×10
    static let playButton = CGPoint(x: 16, y: 88)       // 23×18
    static let pauseButton = CGPoint(x: 39, y: 88)      // 23×18
    static let stopButton = CGPoint(x: 62, y: 88)       // 23×18
}
```

### Build Commands

```bash
# SPM build
swift build
.build/debug/MacAmpApp

# Xcode build (via MCP)
# Use mcp__XcodeBuildMCP__build_macos tool

# Clean build
swift clean && swift build

# Release build
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Release build

# Verify code signature
codesign --verify --deep --strict dist/MacAmp.app

# Check bundle resources
ls -la ~/Library/Developer/Xcode/DerivedData/MacAmpApp-*/Build/Products/Debug/MacAmpApp.app/Contents/Resources/
```

---

## Summary: Building Retro macOS Apps with SwiftUI

### Key Takeaways

1. **Three-Layer Architecture** - Decouple mechanism (functional), bridge (semantic), and presentation (visual) layers
2. **Semantic Sprite Resolution** - Never hardcode sprite names, use semantic requests that adapt to skin variants
3. **Robust Fallback Systems** - Generate transparent placeholders for missing/corrupted sprites
4. **@MainActor Isolation** - Ensure all UI updates happen on main thread, use Task.detached for background work
5. **Pixel-Perfect Rendering** - Use `.interpolation(.none)` and `.antialiased(false)` for crisp pixel art
6. **Absolute Positioning** - Create `.at(x:y:)` extension for absolute offset-based positioning
7. **Code Signing Order** - Use Scheme Post-Actions (not Build Phases) for signed app distribution
8. **Bundle Path Differences** - Handle SPM vs Xcode bundle structures with conditional compilation
9. **Performance Optimization** - Cache computed values, debounce persistence, minimize body re-evaluations
10. **Graceful Degradation** - App must work with ANY .wsz file, even incomplete/corrupted ones
11. **Segment-Based Resize** - Quantize window resizing to 25×29px increments with AppKit preview overlay
12. **Cross-Window State** - Migrate local @State to AppSettings for features requiring cross-window observation
13. **NSWindow/SwiftUI Sync** - Use onAppear/onChange hooks to keep NSWindow frame synchronized with SwiftUI state
14. **WKUserScript Injection** - Load JavaScript libraries via WKUserScript (not `<script>` tags) for WKWebView
15. **Swift→JS Audio Bridge** - Use callAsyncJavaScript at 30 FPS with Timer + MainActor for reliable delivery
16. **NSMenu Closure Bridge** - Store menu in @State, use representedObject to keep target classes alive
17. **Force Unwrap Elimination** - Use `Optional.map { } ?? default` and `flatMap` patterns; never force unwrap
18. **Risk-Ordered Refactoring** - Extract components incrementally: low risk → medium → high; verify after each
19. **Swift 6 Sendable Readiness** - Mark all data transfer structs as `Sendable` now; use `nonisolated(unsafe)` for deinit
20. **Pre-allocated Audio Buffers** - Zero allocations on audio thread; pre-allocate FFT buffers in init
21. **Quality Gate Methodology** - Use Oracle reviews with 10/10 target; fix all high/medium issues before shipping
22. **Placeholder.md Convention** - No `// TODO` in code; document placeholders in `tasks/<task>/placeholder.md`
23. **SPSC Audio Thread Safety** - Zero allocations on audio thread; use os_unfair_lock_trylock() with pre-allocated shared buffers
24. **Memory Profiling with LLDB** - Use `footprint`, `leaks`, `heap` CLI tools; subtract sanitizer overhead for actual metrics
25. **SwiftUI View Decomposition** - Use child view structs + @Observable state, not cross-file extensions; validated by T3 MainWindow decomposition (10 files, PR #54)
26. **Coordinator Volume Routing** - Fan-out volume to all backends unconditionally; use capability flags with error recovery for UI dimming

### This Skill Enables You To

- ✅ Build pixel-perfect retro UIs in modern SwiftUI
- ✅ Implement dynamic skin systems with hot-swapping
- ✅ Integrate AVAudioEngine for professional audio processing
- ✅ Handle user-imported content robustly (no crashes)
- ✅ Distribute code-signed, notarized macOS apps
- ✅ Support both SPM and Xcode build systems
- ✅ Create responsive, performant UIs with proper state management
- ✅ Implement semantic abstraction layers for flexibility
- ✅ Debug SwiftUI rendering and z-ordering issues
- ✅ Optimize rendering performance for real-time updates
- ✅ Implement quantized segment-based window resizing with AppKit overlay
- ✅ Build scroll sliders with proper bridge layer architecture
- ✅ Coordinate cross-window state observation for multi-window features
- ✅ Synchronize NSWindow and SwiftUI state with proper hooks
- ✅ Integrate JavaScript visualization libraries via WKWebView with audio bridge
- ✅ Build context menus with NSMenu closure-to-selector bridge pattern
- ✅ Manage timer lifecycles in @Observable classes with proper cleanup
- ✅ Eliminate force unwraps with idiomatic Optional.map/flatMap patterns
- ✅ Refactor monolithic files with risk-ordered incremental extraction
- ✅ Prepare codebase for Swift 6 strict concurrency with Sendable conformance
- ✅ Implement real-time audio processing with pre-allocated buffers
- ✅ Achieve 10/10 Oracle scores through systematic quality gate phases
- ✅ Document future features with centralized placeholder.md convention
- ✅ Implement SPSC shared buffers for allocation-free real-time audio thread data transfer
- ✅ Profile and fix memory leaks with LLDB heap/leaks/footprint tools
- ✅ Optimize peak memory with lazy extraction and independent CGContext copies
- ✅ Decompose large SwiftUI views into layer subviews with @Observable state (proven: MainWindow 700+ lines into 10 focused files)
- ✅ Regenerate Xcode projects from Package.swift when file structure changes (`rm -rf *.xcodeproj && open Package.swift`)
- ✅ Route volume through coordinator fan-out for multi-backend audio (local + streaming + video)
- ✅ Implement capability flags with error recovery to dim/enable UI controls based on active backend
- ✅ Build asymmetric SwiftUI Bindings when source of truth differs from write path

### Next Project Improvements

When building your next retro macOS app:

1. **Start with semantic layer** - Define semantic sprite enum BEFORE building UI
2. **Implement fallbacks early** - Build fallback system during skin loading, not as afterthought
3. **Test with diverse skins** - Download 10-20 random .wsz files from Internet Archive for testing
4. **Use Scheme Post-Actions** - Set up distribution workflow from day one
5. **Profile early** - Use Instruments to identify SwiftUI body re-evaluation hotspots
6. **Document skin format** - Create detailed sprite coordinate documentation as you go
7. **Automate code signing verification** - Add signature checks to CI/CD pipeline

---

**Document Status:** Production Ready
**Maintenance:** Update when new patterns/pitfalls discovered
**Owner:** MacAmp Development Team
**Last Updated:** 2026-02-22

**Recent Additions:**
- **Coordinator Volume Routing + Capability Flags** (Feb 22, 2026) - Multi-backend volume fan-out and UI capability dimming (Lesson #26)
  - PlaybackCoordinator.setVolume() propagates unconditionally to all backends (audioPlayer, streamPlayer, videoPlaybackController)
  - Capability flags (supportsEQ/supportsBalance/supportsVisualizer) with error recovery -- failed streams re-enable controls
  - Asymmetric SwiftUI Binding: reads from AudioPlayer (persisted source of truth), writes through coordinator (fan-out)
  - Init-time sync + belt-and-suspenders sync in play(station:) prevents first-use volume mismatch
  - Oracle grade: gpt-5.3-codex, xhigh -- 1 finding fixed (stream error capability flag recovery)
- **T3 MainWindow Layer Decomposition** (Feb 22, 2026) - Full implementation of layer subview pattern (PR #54, merged)
  - WinampMainWindow decomposed into 10 files in `MacAmpApp/Views/MainWindow/`
  - displayTitleProvider closure pattern avoids stale title capture (Oracle fix)
  - Task.sleep modernization replacing all DispatchQueue.main.asyncAfter calls
  - scrubResetTask cancellation pattern prevents overlapping delayed resets (CodeRabbit finding, actionable)
  - Shade time display double-offset fix (Oracle finding)
  - 3 Oracle reviews (Phase 1 scaffolding, Phase 3 wiring, full diff)
  - 10 PR comments resolved (2 false positive, 6 nitpick, 2 actionable fixed)
  - MainWindowVisualizerLayer isolation identified as future optimization
  - Xcodeproj regeneration workflow: `rm -rf *.xcodeproj && open Package.swift`
- **SwiftUI View Decomposition** (Feb 21, 2026) - Layer subviews vs cross-file extension anti-pattern (Lesson #25)
  - Cross-file extensions widen @State visibility without creating recomposition boundaries
  - Correct pattern: @Observable interaction state + child view structs with dependency injection
  - Root view becomes thin composer (~120 lines); each child is a real SwiftUI recomposition boundary
  - Both Gemini and Oracle independently converged on identical recommendation
  - Extension split is temporary tactical fix only; layer subviews are proper architecture for 400+ line views
- **Memory & CPU Optimization** (Feb 14, 2026) - SPSC shared buffer, zero audio-thread allocations, memory leak fixes
  - SPSC shared buffer with os_unfair_lock_trylock for audio-to-main thread data transfer (Lesson #24)
  - Goertzel coefficient precomputation and pre-allocated scratch buffers
  - Pause tap policy (remove tap on pause, reinstall on play)
  - Lazy default skin loading (compressed ZIP payload instead of full parse)
  - Independent CGContext copies for sprite cropping (breaks parent-child buffer retention)
  - Metrics: -19% footprint, -23% peak, -100% leaks, 0 audio thread allocations
  - Lesson #20 updated: Unmanaged pointer pattern superseded by SPSC
- **Facade + Composition Refactoring** (Feb 2026) - WindowCoordinator decomposition (Lesson #23)
- **Code Optimization Patterns** (Jan 11, 2026) - Comprehensive refactoring and Swift 6 readiness
  - Force unwrap elimination with Optional.map, flatMap, guard chains (Lessons #12)
  - Risk-ordered incremental component extraction: AudioPlayer 1,805→1,059 lines (Lesson #13)
  - Swift 6 Sendable conformance for 8 data transfer types (Lesson #14)
  - Background I/O with Task.detached and merge logic (Lesson #15)
  - Pre-allocated FFT buffers for audio thread safety (Lesson #16)
  - UserDefaults Keys enum for centralized key management (Lesson #17)
  - Placeholder.md convention replacing TODO comments (Lesson #18)
  - Pre-commit hooks with tracked .githooks/ directory (Lesson #19)
  - Unmanaged pointer lifecycle management (Lesson #20, superseded by SPSC in Lesson #24)
  - Callback patterns for cross-component sync (Lesson #21)
  - Quality Gate methodology for 10/10 Oracle scores (Lesson #22)
  - New Audio directory structure: 5 extracted components
  - Oracle score progression: 7.5/10 → 10/10 through systematic fixes
- **WASM vs Hybrid Rendering Mode** (Jan 6, 2026) - WebGL security configuration for Butterchurn
  - `onlyUseWASM: true` option for hardened WASM-only rendering (recommended for security)
  - Current implementation uses hybrid mode (WASM with JavaScript fallback)
  - WASM code is bundled in butterchurn.min.js (no separate .wasm file needed)
  - Desktop apps with WKWebView sandboxing can safely use hybrid mode
- **Butterchurn/WKWebView Integration** (Jan 5, 2026) - Complete audio visualization with JavaScript bridge
  - WKUserScript injection for JavaScript libraries (not `<script>` tags - they fail silently)
  - Swift→JS audio bridge at 30 FPS with callAsyncJavaScript for reliable delivery
  - NSMenu closure-to-selector bridge pattern (representedObject + @State menu retention)
  - @Observable timer management with @ObservationIgnored and proper cleanup
  - WKNavigationDelegate lifecycle for page load detection (didFinish + both didFail variants)
  - Right-click capture overlay using hitTest selective interception
  - Track title interval display with configurable timer
  - 7 phases, 5 Oracle A-grade bug fixes, 100+ presets
- **Playlist Window Resize Patterns** (Dec 16, 2025) - Complete segment-based resize with scroll slider
  - Segment-based resize with window-specific base dimensions (275×116 vs 250×116)
  - Three-section bottom bar layout (LEFT + CENTER + RIGHT) with dynamic tiles
  - Background tiling as canvas with overlays (webamp CSS flex-grow pattern)
  - Scroll slider bridge contract with one-way sync (SwiftUI ScrollView limitation documented)
  - Cross-window state observation via AppSettings (mini visualizer activation)
  - NSWindow/SwiftUI sync hooks (onAppear/onChange for frame synchronization)
  - Playlist does NOT use double-size mode (only Main/EQ do)
  - ZStack alignment bug in conditional rendering (topLeading required for offset positioning)
  - Sprite width bug discovery (154→150px, verified against webamp)
  - Oracle Grade A- (Architecture Aligned)
- **Hybrid AppKit/SwiftUI Architecture & Oracle Consultation Patterns** (Nov 16, 2025) - Critical architectural validation
  - WindowGroup singleton problem NOT fixed in macOS 15/26 (Oracle confirmed)
  - NSWindowController is CORRECT for magnetic docking apps (not technical debt)
  - Placeholder WindowGroup pattern: NECESSARY for SwiftUI App lifecycle compliance
  - .defaultLaunchBehavior(.suppressed) + .restorationBehavior(.disabled) for hidden scenes
  - Oracle multi-turn consultation with historical context methodology
  - Technical debt vs correct architecture validation framework
  - Oracle oversight detection and challenge patterns
  - Saved 4-6 weeks of unnecessary migration work through proper validation
  - Grade change: 6/10 (perceived debt) → 8/10 (correct architecture)
- **Video/Milkdrop Window Patterns** (Nov 15, 2025) - Complete multi-window video integration
  - Two-piece sprite extraction (GEN.bmp letters split into TOP + BOTTOM)
  - Size2D quantized resize model (25×29px segments)
  - Task { @MainActor in } for timer/observer closures
  - playbackProgress stored property contract (must assign all three values)
  - currentSeekID invalidation before playerNode.stop()
  - AppKit preview overlay solving SwiftUI clipping
  - WindowCoordinator bridge for AppKit/SwiftUI separation
  - Invisible window phantom bug (isVisible check in WindowSnapManager)
  - Oracle Grade A validated architecture
- **Three-State Enum Pattern with Winamp Fidelity** (Nov 7, 2025) - Complete enum-based state management
  - RepeatMode enum (off/all/one) with CaseIterable future-proofing
  - Single source of truth via computed property pattern
  - Migration from boolean preserving user preferences (true → .all, false → .off)
  - ZStack overlay technique for visual indicators (Winamp 5 plugin compatibility)
  - Manual vs auto-action distinction pattern (isManualSkip parameter)
  - Options menu with explicit choices + checkmarks (3 items vs single toggle)
  - Cross-skin visual compatibility (shadow technique for all backgrounds)
  - Oracle-validated pattern consistency (Grade A)
- **Internet Radio Streaming** (Oct 31, 2025) - Dual-backend audio architecture
  - PlaybackCoordinator pattern for multiple audio systems
  - @preconcurrency for non-Sendable frameworks
  - Modern AVPlayerItemMetadataOutput (not deprecated timedMetadata)
  - Handler clobbering bugs and solutions
  - ID vs URL matching for track updates
- **Notarization from Real Experience** (Oct 31, 2025) - Complete workflow
  - What fails and why (3 common errors)
  - Hardened runtime and timestamp requirements
  - Debug entitlement removal process
  - Professional DMG creation with README + symlink
- **Modern Swift Patterns & Observable Migration** - Complete guide to migrating from ObservableObject to @Observable
  - Critical @Bindable pattern corrections (body-scoped requirement)
  - MainActor safety patterns with Task isolation
  - Thread Sanitizer workflow for concurrency testing

### 23. Facade + Composition Refactoring: From God Object to Focused Types (February 2026)

**Lesson from:** WindowCoordinator refactoring (1,357 → 223 lines, -84%)
**Oracle Grade:** A (92/100) after fixes, A+ (95/100) Swift 6.2 compliance
**Total Commits:** 5 commits over 4 phases + Oracle fixes
**Files Created:** 10 new files + 1 extension + 2 test files

#### The Problem: God Object Anti-Pattern

**Symptoms of a God Object:**
- Single file exceeds 1,000+ lines
- 8-10+ orthogonal responsibilities in one class
- Violates SwiftLint thresholds (type_body_length, function_body_length)
- Impossible to unit test (too many dependencies)
- Changes in one area ripple across entire file
- New features require understanding the entire class

**Real Example - WindowCoordinator.swift (Original):**
```
1,357 lines with 10 responsibilities:
1. Window ownership (5 NSWindowController properties)
2. Frame persistence (save/load positions, suppression)
3. Window visibility (show/hide/toggle for all windows)
4. Window resizing (double-size mode, docking-aware layout)
5. Settings observation (4 recursive withObservationTracking tasks)
6. Delegate wiring (5 multiplexers + 5 focus delegates)
7. Layout initialization (default positions, stacking)
8. Presentation lifecycle (skin loading, window presentation)
9. Debug logging (position tracking)
10. Pure geometry calculations (docking math)
```

#### Solution: Facade + Composition Pattern

**Phase 1: Extract Pure Types (Zero Risk)**
```swift
// WindowDockingTypes.swift (50 lines)
struct PlaylistAttachmentSnapshot: Sendable {
    let anchor: WindowKind
    let attachment: PlaylistAttachment
}

struct VideoAttachmentSnapshot: Sendable {
    let anchor: WindowKind
    let attachment: PlaylistAttachment
}

struct PlaylistDockingContext {
    let anchor: WindowKind
    let attachment: PlaylistAttachment
    let source: DockingSource
}
```

```swift
// WindowDockingGeometry.swift (109 lines) - Pure functions, no state
nonisolated struct WindowDockingGeometry {
    static func determineAttachment(anchorFrame: NSRect, playlistFrame: NSRect, strict: Bool = true) -> PlaylistAttachment?
    static func playlistOrigin(for attachment: PlaylistAttachment, anchorFrame: NSRect, playlistSize: NSSize) -> NSPoint
    static func attachmentStillEligible(_ snapshot: PlaylistAttachmentSnapshot, anchorFrame: NSRect, playlistFrame: NSRect) -> Bool
    static func anchorFrame(_ anchor: WindowKind, mainFrame: NSRect, eqFrame: NSRect, playlistFrame: NSRect? = nil) -> NSRect?
}
```

```swift
// WindowFrameStore.swift (65 lines) - UserDefaults persistence
@MainActor
final class WindowFrameStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(frame: NSRect, for kind: WindowKind)
    func frame(for kind: WindowKind) -> PersistedWindowFrame?
}
```

**Phase 2: Extract Controllers (Low-Medium Risk)**
```swift
// WindowRegistry.swift (83 lines) - Window ownership only
@MainActor
final class WindowRegistry {
    private let mainController: NSWindowController
    private let eqController: NSWindowController
    private let playlistController: NSWindowController
    private let videoController: NSWindowController
    private let milkdropController: NSWindowController

    var mainWindow: NSWindow? { mainController.window }
    func windowKind(for window: NSWindow) -> WindowKind?
    func forEachWindow(_ body: (NSWindow, WindowKind) -> Void)
}
```

```swift
// WindowFramePersistence.swift (146 lines) - Persistence only
@MainActor
final class WindowFramePersistence {
    private let registry: WindowRegistry
    private let windowFrameStore: WindowFrameStore
    private var persistenceSuppressionCount = 0
    private(set) var persistenceDelegate: WindowPersistenceDelegate?

    func beginSuppressingPersistence()
    func endSuppressingPersistence()
    func persistAllWindowFrames()
    func schedulePersistenceFlush()  // Debounced with Task cancellation
    func applyPersistedWindowPositions() -> Bool
}
```

```swift
// WindowVisibilityController.swift (161 lines) - Visibility only
@MainActor
@Observable
final class WindowVisibilityController {
    var isEQWindowVisible: Bool = false
    var isPlaylistWindowVisible: Bool = false

    func showEQWindow()
    func hideEQWindow()
    func toggleEQWindowVisibility() -> Bool
    func showAllWindows()
    func minimizeKeyWindow()
}
```

```swift
// WindowResizeController.swift (312 lines) - Resize + docking only
@MainActor
final class WindowResizeController {
    private let registry: WindowRegistry
    private let persistence: WindowFramePersistence
    private var lastPlaylistAttachment: PlaylistAttachmentSnapshot?

    func resizeMainAndEQWindows(doubled: Bool, animated: Bool, persistResult: Bool)
    func makePlaylistDockingContext(...) -> PlaylistDockingContext?
    func updateVideoWindowSize(to: CGSize)
    func showVideoResizePreview(...)
}
```

**Phase 3: Extract Observation & Wiring (Low Risk)**
```swift
// WindowSettingsObserver.swift (114 lines) - Settings observation only
@MainActor
final class WindowSettingsObserver {
    private let settings: AppSettings
    private var tasks: [String: Task<Void, Never>] = [:]
    private var handlers: Handlers?

    private struct Handlers {
        let onAlwaysOnTopChanged: @MainActor (Bool) -> Void
        let onDoubleSizeChanged: @MainActor (Bool) -> Void
        let onShowVideoChanged: @MainActor (Bool) -> Void
        let onShowMilkdropChanged: @MainActor (Bool) -> Void
    }

    func start(onAlwaysOnTopChanged:, onDoubleSizeChanged:, ...)
    func stop() { tasks.values.forEach { $0.cancel() } }
}
```

**Key Pattern: Recursive withObservationTracking with Lifecycle**
```swift
private func observeAlwaysOnTop() {
    tasks["alwaysOnTop"]?.cancel()  // 1. Cancel existing
    tasks["alwaysOnTop"] = Task { @MainActor [weak self] in  // 2. Create new Task
        guard let self else { return }  // 3. Check deallocation
        withObservationTracking {  // 4. Observe property
            _ = self.settings.isAlwaysOnTop
        } onChange: {  // 5. One-shot onChange callback
            Task { @MainActor [weak self] in  // 6. Nested Task for @Sendable context
                guard let self, self.handlers != nil else { return }  // 7. Check lifecycle
                self.handlers?.onAlwaysOnTopChanged(self.settings.isAlwaysOnTop)
                self.observeAlwaysOnTop()  // 8. Re-establish (recursive)
            }
        }
    }
}
```

**Why Recursive:**
- `withObservationTracking` is one-shot (fires onChange once, then stops)
- Must call `observe*()` again in onChange to continue tracking
- Nested Task required because onChange is `@Sendable` but handlers are `@MainActor`
- handlers nil-check prevents re-registration after stop()

**Future Migration (macOS 26+):**
```swift
// Cleaner AsyncSequence pattern (requires macOS 26+)
func start(...) {
    handlers = Handlers(...)
    Task { @MainActor [weak self] in
        guard let self else { return }
        for await _ in Observations(\.isAlwaysOnTop, on: settings) {
            guard handlers != nil else { break }
            handlers?.onAlwaysOnTopChanged(settings.isAlwaysOnTop)
        }
    }
}
```

```swift
// WindowDelegateWiring.swift (54 lines) - Static factory pattern
@MainActor
struct WindowDelegateWiring {
    let focusDelegates: [WindowFocusDelegate]
    let multiplexers: [WindowDelegateMultiplexer]

    static func wire(
        registry: WindowRegistry,
        persistenceDelegate: WindowPersistenceDelegate?,
        windowFocusState: WindowFocusState
    ) -> WindowDelegateWiring {
        let windowKinds: [(WindowKind, NSWindow?)] = [
            (.main, registry.mainWindow),
            (.equalizer, registry.eqWindow),
            (.playlist, registry.playlistWindow),
            (.video, registry.videoWindow),
            (.milkdrop, registry.milkdropWindow)
        ]

        var multiplexers: [WindowDelegateMultiplexer] = []
        var focusDelegates: [WindowFocusDelegate] = []

        for (kind, window) in windowKinds {
            guard let window else { continue }
            WindowSnapManager.shared.register(window: window, kind: kind)
            let multiplexer = WindowDelegateMultiplexer()
            multiplexer.add(delegate: WindowSnapManager.shared)
            if let persistenceDelegate { multiplexer.add(delegate: persistenceDelegate) }
            let focusDelegate = WindowFocusDelegate(kind: kind, focusState: windowFocusState)
            multiplexer.add(delegate: focusDelegate)
            window.delegate = multiplexer
            multiplexers.append(multiplexer)
            focusDelegates.append(focusDelegate)
        }

        return WindowDelegateWiring(focusDelegates: focusDelegates, multiplexers: multiplexers)
    }
}
```

**Why Static Factory:**
- Encapsulates complex construction (60+ lines of boilerplate)
- Returns struct with strong references (NSWindow.delegate is weak)
- Iterates all 5 windows with identical setup pattern
- Eliminates 10 properties (5 multiplexers + 5 focus delegates)

**Phase 4: Layout Extension (Cosmetic)**
```swift
// WindowCoordinator+Layout.swift (153 lines) - Layout/initialization
extension WindowCoordinator {
    enum LayoutDefaults {
        static let stackX: CGFloat = 100
        static let mainY: CGFloat = 500
    }

    func configureWindows()
    func setDefaultPositions()
    func resetToDefaultStack()
    func applyInitialWindowLayout()
    func presentWindowsWhenReady()
    func presentInitialWindows()
    func debugLogWindowPositions(step: String)
    var canPresentImmediately: Bool { ... }
}
```

**Why Extension:**
- Keeps main facade file focused on composition/forwarding
- Layout is initialization-only, not core facade responsibility
- Extensions can access `internal` members in same module
- Cosmetic separation (doesn't change architecture)

**Final Facade (223 lines):**
```swift
@MainActor
@Observable
final class WindowCoordinator {
    // swiftlint:disable:next implicitly_unwrapped_optional
    static var shared: WindowCoordinator!

    // Composed controllers
    let registry: WindowRegistry
    let framePersistence: WindowFramePersistence
    let visibility: WindowVisibilityController
    let resizeController: WindowResizeController
    private let settingsObserver: WindowSettingsObserver
    private var delegateWiring: WindowDelegateWiring?

    // Forwarding properties for @Observable chaining
    var isEQWindowVisible: Bool {
        get { visibility.isEQWindowVisible }
        set { visibility.isEQWindowVisible = newValue }
    }

    // Forwarding methods (facade API)
    func showEQWindow() { visibility.showEQWindow() }
    func minimizeKeyWindow() { visibility.minimizeKeyWindow() }
    func updateVideoWindowSize(to: CGSize) { resizeController.updateVideoWindowSize(to: size) }
}
```

#### Critical Oracle Findings & Fixes

**HIGH Priority - Debounce Cancellation Bug:**
```swift
// ❌ BEFORE: Cancelled tasks still executed
func schedulePersistenceFlush() {
    guard persistenceSuppressionCount == 0 else { return }
    persistenceTask?.cancel()
    persistenceTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .milliseconds(150))
        self?.persistAllWindowFrames()  // ← Still executes after cancel!
    }
}

// ✅ AFTER: Cancellation guard prevents execution
func schedulePersistenceFlush() {
    guard persistenceSuppressionCount == 0 else { return }
    persistenceTask?.cancel()
    persistenceTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }  // ← Stops here if cancelled
        self?.persistAllWindowFrames()
    }
}
```

**Why This Matters:** Without the cancellation guard, rapid window movements cause multiple persistence writes. With 10 movements in 1 second, you'd get 10 debounced Tasks, all writing to UserDefaults. The cancellation guard ensures only the final Task executes.

**MEDIUM Priority - Observer Lifecycle Bug:**
```swift
// ❌ BEFORE: onChange could fire after stop()
} onChange: {
    Task { @MainActor [weak self] in
        guard let self else { return }
        self.handlers?.onAlwaysOnTopChanged(...)  // ← handlers was nilled in stop()
        self.observeAlwaysOnTop()  // ← Re-registers observation after stop()!
    }
}

// ✅ AFTER: Lifecycle check prevents re-registration
} onChange: {
    Task { @MainActor [weak self] in
        guard let self, self.handlers != nil else { return }  // ← Exit if stopped
        self.handlers?.onAlwaysOnTopChanged(...)
        self.observeAlwaysOnTop()
    }
}
```

**Why This Matters:** `withObservationTracking` onChange callbacks can fire asynchronously. If stop() is called between property change and onChange execution, the handler is nil but the Task still runs. Without the nil-check, observations continue re-registering after stop().

#### Dependency Graph Rules (Acyclic)

**Critical Principle:** NO controller-to-controller lateral dependencies. All coordination goes through the facade.

```
WindowCoordinator (facade/composition root)
    ├── WindowRegistry              ← NO dependencies on other extracted types
    ├── WindowFramePersistence      ← depends on: WindowRegistry, WindowFrameStore
    ├── WindowVisibilityController  ← depends on: WindowRegistry, AppSettings
    ├── WindowResizeController      ← depends on: WindowRegistry, WindowFramePersistence, WindowDockingGeometry
    ├── WindowSettingsObserver      ← depends on: AppSettings only
    └── WindowDelegateWiring        ← depends on: WindowRegistry, WindowFramePersistence, WindowFocusState

Pure Types (no dependencies):
    ├── WindowDockingTypes (value types)
    ├── WindowDockingGeometry (static functions)
    └── WindowFrameStore (UserDefaults wrapper)
```

**Violations to Avoid:**
```swift
// ❌ WRONG: Controller-to-controller dependency
class WindowVisibilityController {
    private let persistence: WindowFramePersistence  // ← Creates cycle risk

    func showWindow() {
        persistence.suppressPersistence { ... }  // ← Tight coupling
    }
}

// ✅ CORRECT: Facade coordinates
class WindowCoordinator {
    let visibility: WindowVisibilityController
    let persistence: WindowFramePersistence

    func showWindowWithoutPersistence() {
        persistence.beginSuppressingPersistence()
        visibility.showWindow()
        persistence.endSuppressingPersistence()
    }
}
```

#### Swift 6.2 Concurrency Patterns

**1. nonisolated deinit Awareness**
```swift
@MainActor
@Observable
final class WindowCoordinator {
    private let settingsObserver: WindowSettingsObserver

    deinit {
        // ❌ WRONG: Cannot call @MainActor method from nonisolated deinit
        // settingsObserver.stop()  // Compiler error in Swift 6.2

        // ✅ CORRECT: Tasks use [weak self], auto-terminate on dealloc
        // Comment explains why stop() isn't called
    }
}
```

**Why This Works:**
- In Swift 6.2, `deinit` is `nonisolated` (cannot call `@MainActor` methods)
- All observer Tasks use `[weak self]`
- When WindowCoordinator deallocates, weak refs → nil
- Tasks exit via `guard let self else { return }`
- No memory leaks, no zombie tasks

**2. Explicit @MainActor on Closures**
```swift
// Handlers struct with explicit isolation
private struct Handlers {
    let onAlwaysOnTopChanged: @MainActor (Bool) -> Void  // ← Explicit
    let onDoubleSizeChanged: @MainActor (Bool) -> Void
    let onShowVideoChanged: @MainActor (Bool) -> Void
    let onShowMilkdropChanged: @MainActor (Bool) -> Void
}

// Prevents @Sendable violations in withObservationTracking
```

**3. @Observable Observation Chaining**
```swift
// Facade forwards observable properties for SwiftUI reactivity
@MainActor
@Observable
final class WindowCoordinator {
    let visibility: WindowVisibilityController  // ← Also @Observable

    var isEQWindowVisible: Bool {
        get { visibility.isEQWindowVisible }  // ← Chains observation
        set { visibility.isEQWindowVisible = newValue }
    }
}

// SwiftUI views can observe either facade or controller
struct SomeView: View {
    @Environment(WindowCoordinator.self) var coordinator

    var body: some View {
        if coordinator.isEQWindowVisible {  // ← Updates when visibility changes
            Text("EQ is visible")
        }
    }
}
```

#### Migration Strategy: Risk-Ordered Phased Approach

**Phase Sequencing:**
```
Phase 1 (Zero Risk):
  - Pure types (no state, no side effects)
  - Unit tests added (10 tests for geometry + storage)
  - Build verified after each extraction
  - Oracle Grade: APPROVED with 1 finding (fixed)

Phase 2 (Low-Medium Risk):
  - Extract 4 controllers with clear SRP
  - Facade forwards all methods (API preserved)
  - Build + manual test after each controller
  - Oracle Grade: APPROVED (no defects)

Phase 3 (Low Risk):
  - Extract observation boilerplate
  - Extract delegate wiring factory
  - Remove 16 properties from facade
  - Oracle Grade: APPROVED (no regressions)

Phase 4 (Cosmetic):
  - Extract layout to extension
  - Widen access on 3 properties (private → internal)
  - Oracle Grade: APPROVED (no issues)

Quality Gate (Post-Refactoring):
  - Oracle comprehensive review (all 11 files)
  - Found 2 HIGH/MEDIUM bugs, fixed immediately
  - Swift 6.2 compliance review: Grade A+ (95/100)
  - Final Oracle Grade: A (92/100)
```

**Commit Strategy:**
```bash
git commit -m "refactor: Phase 1 - Extract pure types from WindowCoordinator"
git commit -m "refactor: Phase 2 - Extract 4 controllers from WindowCoordinator"
git commit -m "refactor: Phase 3 - Extract WindowSettingsObserver and WindowDelegateWiring"
git commit -m "refactor: Phase 4 - Extract WindowCoordinator+Layout extension"
git commit -m "refactor: Fix Oracle findings and update documentation"
```

**Each phase:**
1. Extract files
2. Update pbxproj (4 sections per file)
3. Build with `-enableThreadSanitizer YES`
4. Run full test suite with TSan
5. Oracle review (gpt-5.3-codex, reasoningEffort: xhigh)
6. Fix findings immediately
7. Commit only when clean

#### Testing Patterns for Refactoring

**1. Baseline Verification**
```bash
# Before refactoring starts
xcodebuild test -project MacAmpApp.xcodeproj -scheme MacAmpApp \
  -enableThreadSanitizer YES > baseline-test-results.txt 2>&1

# Document: X tests pass, Y Thread Sanitizer warnings
```

**2. After Each Phase**
```bash
# Build verification
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp \
  -configuration Debug -enableThreadSanitizer YES build

# Test verification
xcodebuild test -project MacAmpApp.xcodeproj -scheme MacAmpApp \
  -configuration Debug -enableThreadSanitizer YES

# Compare results to baseline (should be identical)
```

**3. Oracle Review Gate**
```bash
# Comprehensive review of all changes
codex review --uncommitted --model gpt-5.3-codex

# Or via MCP:
mcp__codex-cli__review(uncommitted: true, model: "gpt-5.3-codex")
```

**4. Manual Functional Test**
```
After Phase 2 (controllers extracted):
□ Load 3 different skins (verify rendering preserved)
□ Toggle double-size mode (Ctrl+D)
□ Show/hide EQ and Playlist windows
□ Drag windows to test magnetic snapping
□ Resize video/playlist windows
□ Verify persistence (quit, relaunch, positions restored)
□ Check always-on-top toggle
```

#### Access Control Patterns

**Progressive Access Widening:**
```swift
// Phase 2: Extract controllers, keep tight access
private let settings: AppSettings
private let skinManager: SkinManager
private var hasPresentedInitialWindows = false

// Phase 4: Widen access for extension (same module)
private let settings: AppSettings  // Still private (not used in extension)
let skinManager: SkinManager  // Widened (extension uses canPresentImmediately)
var hasPresentedInitialWindows = false  // Widened
```

**Rule:** Only widen access when actually needed. Start with `private`, widen to `internal` (no explicit keyword in Swift) only if extension/test requires it.

#### Property Forwarding: When to Use vs Avoid

**✅ When Forwarding is CORRECT:**
```swift
// @Observable property forwarding (observation chaining)
var isEQWindowVisible: Bool {
    get { visibility.isEQWindowVisible }
    set { visibility.isEQWindowVisible = newValue }
}
```
**Reason:** SwiftUI @Observable macro requires property access on the observed object. Direct access breaks observation.

**❌ When Forwarding is ANTI-PATTERN:**
```swift
// ❌ DEPRECATED: One-line method forwarding wrapper
private func schedulePersistenceFlush() {
    framePersistence.schedulePersistenceFlush()
}

// ✅ BETTER: Direct composition access
coordinator.framePersistence.schedulePersistenceFlush()
```
**Reason:** Adds indirection with zero value. Callers can access composed property directly.

#### Dependency Injection Benefits

**Before Refactoring (Untestable):**
```swift
// All singletons, no injection
class WindowCoordinator {
    private var windowFrameStore = WindowFrameStore()  // ← Cannot mock
    private let snapManager = WindowSnapManager.shared  // ← Global state
}
```

**After Refactoring (Testable):**
```swift
// Injectable dependencies
final class WindowFramePersistence {
    init(
        registry: WindowRegistry,
        settings: AppSettings,
        windowFrameStore: WindowFrameStore = WindowFrameStore()  // ← Default parameter
    )
}

final class WindowFrameStore {
    init(defaults: UserDefaults = .standard)  // ← Injectable for tests
}

// In tests:
let mockDefaults = UserDefaults(suiteName: "tests")!
let mockStore = WindowFrameStore(defaults: mockDefaults)
let persistence = WindowFramePersistence(registry: mockRegistry, settings: mockSettings, windowFrameStore: mockStore)
```

#### Modern Swift Architecture Patterns Demonstrated

**1. Single Responsibility Principle**
- Each file has ONE clear responsibility
- 223-line facade vs 1,357-line god object
- Easy to understand, easy to test

**2. Dependency Inversion Principle**
- High-level facade depends on abstractions (protocols/interfaces)
- Low-level controllers depend on same abstractions
- No controller knows about facade implementation

**3. Open/Closed Principle**
- Extension mechanism for layout (open for extension)
- Controllers are `final` (closed for inheritance)
- Composition enables extension without modification

**4. Interface Segregation Principle**
- WindowVisibilityController: Only visibility methods
- WindowResizeController: Only resize methods
- Clients depend on focused interfaces, not god object

**5. Composition Over Inheritance**
- Zero inheritance hierarchies (all `final class` or `struct`)
- All behavior via composed objects
- Loose coupling between components

#### When to Apply This Pattern

**Indicators You Need This Refactoring:**
- Single file exceeds 800-1,000 lines
- SwiftLint violations: `type_body_length`, `function_body_length`
- 5+ distinct responsibilities in one class
- Difficult to write focused unit tests
- Changes in one area require understanding entire file
- Multiple engineers can't work on file simultaneously
- Code review takes >30 minutes per change

**Refactoring Checklist:**
- [ ] **Identify responsibilities** (aim for 8-10 distinct areas)
- [ ] **Create dependency matrix** (map dependencies, ensure acyclic)
- [ ] **Phase 1: Pure types** (value types, pure functions, no state)
- [ ] **Add unit tests** for pure types (geometry, persistence, etc.)
- [ ] **Phase 2: Controllers** (stateful but focused types)
- [ ] **Preserve facade API** with computed property forwarding
- [ ] **Phase 3: Boilerplate** (observation, wiring, utilities)
- [ ] **Phase 4: Extensions** (cosmetic code organization)
- [ ] **Oracle review** after each phase
- [ ] **Fix findings** immediately (don't defer)
- [ ] **Thread Sanitizer** verification on every phase
- [ ] **Update documentation** with new architecture
- [ ] **Final comprehensive review** (all files together)

#### Anti-Patterns to Avoid

**1. Big-Bang Refactoring**
```bash
# ❌ WRONG: Extract everything at once
git commit -m "refactor: Decompose WindowCoordinator (10 files)"
# Risk: Everything breaks, hard to debug, impossible to rollback

# ✅ RIGHT: Incremental phases with verification
git commit -m "refactor: Phase 1 - Extract pure types"
git commit -m "refactor: Phase 2 - Extract 4 controllers"
# Benefit: Each commit is independently verifiable and rollbackable
```

**2. Circular Dependencies**
```swift
// ❌ WRONG: Controllers depend on each other
class WindowVisibilityController {
    private let resizeController: WindowResizeController  // ← Circular!
}

class WindowResizeController {
    private let visibilityController: WindowVisibilityController  // ← Cycle!
}

// ✅ CORRECT: Both depend on registry, coordinator orchestrates
class WindowCoordinator {
    let visibility: WindowVisibilityController
    let resize: WindowResizeController

    func showAndResize() {
        visibility.show()  // Coordinator coordinates both
        resize.resize()
    }
}
```

**3. Leaky Abstraction**
```swift
// ❌ WRONG: Exposing internal implementation details
class WindowCoordinator {
    let persistenceTask: Task<Void, Never>?  // ← Internal detail leaked
    var persistenceSuppressionCount: Int  // ← Internal state exposed
}

// ✅ CORRECT: Only expose facade interface
class WindowCoordinator {
    let framePersistence: WindowFramePersistence  // ← Compose, don't leak

    // Callers use: coordinator.framePersistence.schedulePersistenceFlush()
}
```

**4. Premature Abstraction**
```swift
// ❌ WRONG: Protocol for single implementation
protocol WindowPersistenceProtocol {
    func persist()
}

class WindowFramePersistence: WindowPersistenceProtocol { ... }

// ✅ CORRECT: Concrete type until second implementation exists
final class WindowFramePersistence {
    func persist()
}

// Add protocol when you have 2+ implementations
```

#### Oracle Consultation Best Practices

**Multi-Phase Review Strategy:**
```bash
# After each phase (4 reviews)
codex review --uncommitted --model gpt-5.3-codex --title "Phase N"

# Final comprehensive (all files, 5th review)
codex "@File1.swift @File2.swift ... @File11.swift
Comprehensive architecture review of completed refactoring.
Verify: dependency graph acyclic, Swift 6.2 compliance, facade pattern."
```

**Oracle Finding Priority:**
- **HIGH**: Fix immediately before commit
- **MEDIUM**: Fix immediately before commit
- **LOW**: Document as "acceptable" or "deferred"

**Real Results:**
- Phase 1 Oracle: 1 finding (test build phase config) → Fixed
- Phase 2 Oracle: 0 findings
- Phase 3 Oracle: 0 findings
- Phase 4 Oracle: 0 findings
- Final Oracle: 2 HIGH/MEDIUM findings → Fixed immediately
- All phases: Thread Sanitizer clean

#### Refactoring Metrics

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| **WindowCoordinator lines** | 1,357 | 223 + 153 ext | -84% main file |
| **Largest file** | 1,357 | 312 | -77% |
| **Responsibilities** | 10 in 1 file | 1 per file | +1,000% SRP |
| **Files** | 1 | 11 | +1,000% |
| **Unit tests** | 0 | 10 | ∞ |
| **SwiftLint violations** | 6 | 0 | -100% |
| **Oracle score** | N/A | A (92/100) | Production ready |
| **Swift 6.2 grade** | N/A | A+ (95/100) | Exemplary |

#### Key Takeaways

1. **Facade + Composition is the modern alternative to god objects** - Preserve public API while decomposing internals
2. **Phased migration reduces risk** - 4 phases with verification gates vs big-bang refactoring
3. **Oracle reviews catch subtle bugs** - 2 critical concurrency bugs found that TSan missed
4. **withObservationTracking is one-shot** - Must re-establish recursively in onChange callback
5. **nonisolated deinit in Swift 6.2** - Cannot call @MainActor methods; rely on weak self for cleanup
6. **Static factories eliminate boilerplate** - 60+ lines of repetitive code → single factory call
7. **Observation chaining via computed properties** - Necessary for @Observable reactivity, not anti-pattern
8. **Test early, test often** - Build + TSan + tests after EVERY phase
9. **Document as you go** - Update architecture docs in final commit, not as afterthought
10. **Quality gates prevent debt** - Fix all Oracle findings before merge, don't defer

#### Complete Pattern Checklist

When refactoring large files (1,000+ lines):

- [ ] **Map responsibilities** (aim for 8-10 distinct areas)
- [ ] **Create dependency graph** on paper first (ensure acyclic)
- [ ] **Plan phases** in risk order (pure → controllers → boilerplate → cosmetic)
- [ ] **Write plan.md** in tasks/ directory with Oracle review
- [ ] **Phase 1: Pure types** with unit tests
- [ ] **Extract value types** first (Sendable structs/enums)
- [ ] **Extract pure functions** to `nonisolated struct` with static methods
- [ ] **Add unit tests** for extracted pure code (geometry, storage, etc.)
- [ ] **Build + TSan** after Phase 1
- [ ] **Oracle review** Phase 1
- [ ] **Commit Phase 1** only when clean
- [ ] **Phase 2: Controllers** with clear SRP
- [ ] **Preserve facade API** with forwarding (avoid breaking changes)
- [ ] **Injectable dependencies** via init (default parameters for optionals)
- [ ] **Build + TSan** after each controller extraction
- [ ] **Manual functional test** after Phase 2
- [ ] **Oracle review** Phase 2
- [ ] **Phase 3: Observation/Wiring** (remove boilerplate)
- [ ] **Explicit lifecycle** (start/stop) for observer types
- [ ] **Static factories** for complex construction
- [ ] **Build + TSan** after Phase 3
- [ ] **Oracle review** Phase 3
- [ ] **Phase 4: Extensions** (code organization)
- [ ] **Widen access** only as needed (private → internal for extensions)
- [ ] **Build + TSan** after Phase 4
- [ ] **Oracle review** Phase 4
- [ ] **Final comprehensive Oracle** (all extracted files together)
- [ ] **Fix all HIGH/MEDIUM findings** before merge
- [ ] **Update ARCHITECTURE docs** with new structure
- [ ] **Update depreciated.md** with replaced patterns
- [ ] **swift-concurrency-expert** skill review for Swift 6.2 compliance
- [ ] **Commit docs** with fixes in final commit

#### When NOT to Refactor

**Acceptable Large Files:**
- Views with extensive layout (SwiftUI body complexity)
- Controllers with truly cohesive responsibility (e.g., AudioPlayer orchestrating audio lifecycle)
- Files that are large but have SINGLE responsibility
- Legacy code that works and isn't changing

**Bad Reasons to Refactor:**
- "This file is long" (length alone isn't sufficient)
- "I don't understand it" (documentation may be the solution)
- "It looks messy" (formatting != architecture)

**Good Reasons to Refactor:**
- Multiple distinct responsibilities (SRP violation)
- Can't add features without understanding entire file
- Unit testing requires complex mocking
- SwiftLint violations (type_body_length, function_body_length)
- Frequent merge conflicts from multiple engineers

### 24. Memory & CPU Optimization: SPSC Audio Thread Patterns (February 2026)

**Lesson from:** Memory & CPU optimization task (`tasks/memory-cpu-optimization/`)
**Oracle Grade:** PASS (0 HIGH findings after fixes, gpt-5.3-codex, xhigh reasoning)
**Total Commits:** 7 commits across 3 phases + Oracle fixes
**Branch:** `perf/memory-cpu-optimization`

#### The Problem: Heap Allocations on the Real-Time Audio Thread

AVAudioEngine tap callbacks run on a real-time audio thread with strict latency guarantees (~23 ms window at 44.1 kHz / 1024 samples). Any heap allocation on this thread can trigger ARC reference counting, which acquires a spinlock internally. Under memory pressure, this stalls the audio thread, causing buffer underruns (audible skips).

**Before:** The visualizer tap callback performed ~7-8 heap allocations per invocation:
```
Audio Thread Callback (~21.5 Hz):
  1. snapshotRms()           → NEW Array   (heap alloc)
  2. snapshotSpectrum()      → NEW Array   (heap alloc)
  3. waveformSnapshot        → NEW Array   (heap alloc via stride.prefix.map)
  4. butterchurnSpectrum     → NEW Array   (heap alloc)
  5. butterchurnWaveform     → NEW Array   (heap alloc)
  6. VisualizerData(...)     → struct w/ 5 arrays
  7. Task { @MainActor }     → NEW TASK    (heap alloc + ARC)

Total: ~150-170 heap allocations/second on the audio render thread
```

**Root cause analysis:** The code looks correct in isolation -- creating Arrays and dispatching Tasks are normal Swift patterns. The violation is invisible in code review because it's a thread-context issue: these operations are safe on any thread **except** the real-time audio render thread. Standard profilers (Instruments Time Profiler) don't flag it. Diagnosis required LLDB `heap` analysis combined with knowledge of Apple's real-time audio constraints (WWDC 2014 Session 502).

#### Solution: SPSC Shared Buffer with Non-Blocking trylock

Replace per-callback allocations and `Task { @MainActor }` dispatch with a Single-Producer Single-Consumer (SPSC) shared buffer using `os_unfair_lock_trylock()`:

```swift
private final class VisualizerSharedBuffer: @unchecked Sendable {
    // Pre-allocated arrays (never reallocated after init)
    private var rms = [Float](repeating: 0, count: 20)
    private var spectrum = [Float](repeating: 0, count: 20)
    private var waveform = [Float](repeating: 0, count: 76)
    private var bcSpectrum = [Float](repeating: 0, count: 1024)
    private var bcWaveform = [Float](repeating: 0, count: 1024)

    private var lock = os_unfair_lock()
    private var generation: UInt64 = 0
    private var lastConsumed: UInt64 = 0

    /// Audio thread: non-blocking publish via trylock
    func tryPublish(from scratch: VisualizerScratchBuffers, ...) -> Bool {
        guard os_unfair_lock_trylock(&lock) else { return false }  // Drop frame on contention
        defer { os_unfair_lock_unlock(&lock) }

        // memcpy into pre-allocated arrays (zero allocation)
        scratchRms.withUnsafeBufferPointer { src in
            rms.withUnsafeMutableBufferPointer { dst in
                memcpy(dst.baseAddress!, src.baseAddress!, count * MemoryLayout<Float>.stride)
            }
        }
        // ... repeat for spectrum, waveform, butterchurn data ...
        generation &+= 1
        return true
    }

    /// Main thread: blocking consume (safe to block here)
    func consume() -> VisualizerData? {
        os_unfair_lock_lock(&lock)
        guard generation != lastConsumed else {
            os_unfair_lock_unlock(&lock)
            return nil  // No new data
        }
        lastConsumed = generation
        let data = VisualizerData(
            rms: Array(rms.prefix(rmsCount)),      // Array allocation on main thread (safe)
            spectrum: Array(spectrum.prefix(...)),
            // ...
        )
        os_unfair_lock_unlock(&lock)
        return data
    }
}
```

**Key design decisions:**
- `os_unfair_lock_trylock()` on audio thread: **non-blocking** -- if main thread holds the lock, audio thread drops one visualization frame (imperceptible at 21.5 Hz) instead of stalling
- `os_unfair_lock_lock()` on main thread: **blocking OK** -- main thread can safely wait briefly (lock hold time is bounded: 5 small memcpy operations)
- All `Array` construction happens in `consume()` on the main thread where heap allocations and ARC operations are safe
- `generation` counter enables the main thread to detect stale data without polling the arrays
- `@unchecked Sendable` is justified by the lock protecting all mutable state

#### Tap Handler: Static Factory for Sendable Compliance

The tap callback cannot capture `self` (a `@MainActor`-isolated object). Use a static factory method:

```swift
@MainActor
@Observable
final class VisualizerPipeline {
    @ObservationIgnored private let sharedBuffer = VisualizerSharedBuffer()

    func installTap(on mixer: AVAudioMixerNode) {
        let scratch = VisualizerScratchBuffers()
        let handler = Self.makeTapHandler(sharedBuffer: sharedBuffer, scratch: scratch)
        mixer.installTap(onBus: 0, bufferSize: 2048, format: nil, block: handler)
        startPollTimer()  // 30 Hz Timer on main thread
    }

    /// Build tap handler in nonisolated context -- captures only Sendable types
    private nonisolated static func makeTapHandler(
        sharedBuffer: VisualizerSharedBuffer,
        scratch: VisualizerScratchBuffers
    ) -> @Sendable (AVAudioPCMBuffer, AVAudioTime?) -> Void {
        { buffer, _ in
            // All processing uses pre-allocated scratch buffers
            let cappedFrameCount = scratch.prepare(frameCount: Int(buffer.frameLength), ...)
            // ... mix to mono, compute RMS, Goertzel spectrum, Butterchurn FFT ...
            _ = sharedBuffer.tryPublish(from: scratch, ...)  // Zero allocations
        }
    }
}
```

**Why static factory:** Avoids capturing `self` in the closure (which would require `@MainActor` isolation or `Unmanaged` pointers). The handler only captures `VisualizerSharedBuffer` and `VisualizerScratchBuffers`, both marked `@unchecked Sendable` with proper justification.

#### Additional Optimizations in This Task

**1. Goertzel Coefficient Precomputation:**
```swift
private struct GoertzelCoefficients {
    var coefficients: [Float]
    var equalizationGains: [Float]
    private(set) var sampleRate: Float = 0

    mutating func updateIfNeeded(bars: Int, sampleRate: Float) -> Bool {
        guard sampleRate != self.sampleRate else { return false }  // Only recompute on track change
        // Eliminates 20x pow() + 20x cos() calls per callback (~21.5 Hz)
        for b in 0..<bars {
            let omega = 2 * Float.pi * centerFrequency / sampleRate
            coefficients[b] = 2 * cos(omega)
            equalizationGains[b] = pow(10.0, dbAdjustment / 20.0)
        }
        return true
    }
}
```

**2. Pre-allocated Scratch Buffers with Capacity Clamping:**
```swift
private final class VisualizerScratchBuffers: @unchecked Sendable {
    private static let maxFrameCount = 4096  // AVAudioEngine uses 2048, well within cap

    init() {
        mono = Array(repeating: 0, count: Self.maxFrameCount)
        rms = Array(repeating: 0, count: Self.maxBars)
        spectrum = Array(repeating: 0, count: Self.maxBars)
    }

    func prepare(frameCount: Int, ...) -> Int {
        // CRITICAL: Clamp to pre-allocated capacity instead of growing
        let cappedFrameCount = min(frameCount, mono.count)
        vDSP_vclr(&mono, 1, vDSP_Length(cappedFrameCount))  // Zero without reallocation
        return cappedFrameCount
    }
}
```

**3. Pause Tap Policy:**
```swift
// BEFORE: tap stays active during pause (wasted CPU processing silence)
pause() → (tap continues at 21.5 Hz, processing zeros)

// AFTER: tap removed on pause, reinstalled on play
play()  → installVisualizerTapIfNeeded() + startPollTimer()
pause() → removeVisualizerTapIfNeeded()   // NEW
stop()  → removeVisualizerTapIfNeeded()
```

**4. Lazy Default Skin Loading:**
```swift
// BEFORE: Both default + selected skins fully parsed at startup (594 MB peak)
// AFTER:  Default skin kept as compressed ZIP payload (~200 KB)
//         Fallback sprites extracted lazily per-sheet on demand
```

**5. Independent CGContext Copies for Sprite Cropping:**
```swift
// BEFORE: cgImage.cropping(to:) shares parent's float pixel buffer
//         Parent buffer (512 KB+) retained as long as ANY child sprite exists

// AFTER:  Copy pixels into independent sRGB RGBA8 CGContext
//         Each sprite owns only its own pixel data (width*height*4 bytes)
//         autoreleasepool around each crop drains intermediates immediately
```

#### Metrics Achieved

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| **Actual Footprint** | ~48 MB | ~39 MB | **-19%** |
| **Actual Peak** | ~377 MB | ~291 MB | **-23%** |
| **Leaked Bytes** | 496 KB (47 leaks) | 0 (0 leaks) | **-100%** |
| **Heap Nodes** | 86,379 | 71,416 | **-17%** |
| **Heap Bytes** | 3.8 MB | 2.7 MB | **-29%** |
| **Audio Thread Allocs/sec** | ~150-170 | 0 | **-100%** |
| **CPU at Idle** | 0.0% | 0.0% | Maintained |

*Profiled with `footprint` and `leaks` CLI tools. TSan overhead (~217-262 MB) subtracted for actual metrics.*

#### Oracle Validation

The implementation was reviewed by Oracle (gpt-5.3-codex, xhigh reasoning) with three separate reviews:

1. **Code Review:** Found 2 HIGH findings (both fixed), 4 MEDIUM (2 fixed, 2 accepted), 2 LOW (accepted). Final verdict: "SPSC design sound, allocation-free in steady state, tap lifecycle correct."
2. **Architecture Alignment Review:** Confirmed three-layer pattern compliance, @Observable usage, and noted SPSC is a "clean architectural upgrade over old Unmanaged pointer pattern."
3. **Swift 6.2 Compliance Review:** Verified all 4 `nonisolated(unsafe)` usages justified, both `@unchecked Sendable` justified, `MainActor.assumeIsolated` with `dispatchPrecondition` correct.

#### When to Use This Pattern

**Use SPSC shared buffer when:**
- Transferring data from a real-time thread (audio, MIDI, sensor) to the main thread
- The producer (audio thread) cannot tolerate ANY blocking or heap allocation
- Dropped frames are acceptable (visualization, meters, UI updates)
- Data is fixed-size or bounded (known maximum array sizes)

**Use `Task { @MainActor }` when:**
- The producer is NOT a real-time thread (network callbacks, file I/O)
- Every update must be delivered (no frame dropping acceptable)
- Data size varies significantly between updates

**Use lock-free atomics when:**
- Only a single scalar value is transferred (e.g., playback position)
- No multi-field consistency is required

#### Key Takeaways

1. **Zero allocations on audio thread is non-negotiable** -- any allocation can trigger ARC spinlock contention
2. **`os_unfair_lock_trylock()` is the right primitive** for audio → main thread transfer (non-blocking, drops frame on contention)
3. **Static factory tap handlers** eliminate Unmanaged pointer risk and satisfy Swift 6 Sendable requirements
4. **Precompute everything possible** outside the tap callback (Goertzel coefficients, Hann window, FFT setup)
5. **Clamp to pre-allocated capacity** instead of growing buffers on the audio thread
6. **Remove taps during pause** to eliminate wasted CPU processing silence
7. **Lazy fallback extraction** avoids double skin parsing at startup (594 MB → ~291 MB peak)
8. **Independent CGContext copies** break CGImage parent-child buffer retention chains
9. **LLDB `heap` + `leaks` + `footprint`** are essential for memory profiling (Instruments alone insufficient)
10. **Oracle multi-review strategy** (code + architecture + Swift 6.2) catches issues that single reviews miss

### 25. SwiftUI View Decomposition: Cross-File Extensions vs Layer Subviews (February 2026)

**Lesson from:** AudioPlayer decomposition task (`tasks/audioplayer-decomposition/`) and T3 MainWindow Layer Decomposition (PR #54)
**Oracle Grade:** Both Gemini and Oracle independently converged on identical recommendation; 3 Oracle reviews performed during T3 implementation (Phase 1 scaffolding, Phase 3 wiring, full diff review)
**Context:** WinampMainWindow (700+ lines) and WinampPlaylistWindow (848 lines) were split into cross-file extensions to satisfy SwiftLint `type_body_length`/`file_length` thresholds
**Status:** Pattern validated and **COMPLETE** for MainWindow (PR #54, merged Feb 22, 2026). 10 files created in `MacAmpApp/Views/MainWindow/`. WinampPlaylistWindow remains as future candidate.

#### The Anti-Pattern: Cross-File Extension Splitting

When a SwiftUI view struct exceeds lint thresholds, the tempting fix is to split it into `MainFile.swift` + `MainFile+Helpers.swift` using Swift extensions:

```swift
// WinampMainWindow.swift (400 lines)
struct WinampMainWindow: View {
    @State var isScrolling = false       // Was private, widened to internal
    @State var isScrubbing = false       // Was private, widened to internal
    @State var blinkPhase = false        // Was private, widened to internal

    var body: some View {
        // ... delegates to helpers in extension file
        mainWindowContent()
    }
}

// WinampMainWindow+Helpers.swift (300 lines)
extension WinampMainWindow {
    func mainWindowContent() -> some View {
        // Can access all @State vars because same type
        // But this is NOT a separate View -- no recomposition boundary
    }
}
```

**Why this is wrong:**

1. **No recomposition boundaries.** Extension methods on the same struct do NOT create SwiftUI view boundaries. When ANY `@State` changes, the entire body (including all extension methods) re-evaluates. There is zero performance benefit.

2. **Forced visibility widening.** `@State private var` must become `@State var` (internal) for cross-file extension access. This leaks implementation details to any file in the module.

3. **Treats lint as architectural authority.** SwiftLint `type_body_length` is a heuristic, not an architecture rule. Splitting a 700-line struct into 400 + 300 still produces a single 700-line type in the compiler's view -- the lint is satisfied but the actual complexity is unchanged.

4. **No dependency isolation.** Every extension method can see every `@State`, `@Environment`, and stored property. There is no way to enforce "this helper only needs volume and balance" at the type level.

5. **Hides true coupling.** The extension file looks like a separate component, but it is tightly coupled to ALL internal state of the parent struct. Refactoring any `@State` var requires checking both files.

#### The Correct Pattern: Layer Subviews with @Observable State

Both Gemini research and Oracle code review independently recommended the same architecture:

**Step 1: Extract interaction state into @Observable**

```swift
// WinampMainWindowInteractionState.swift
@MainActor
@Observable
final class WinampMainWindowInteractionState {
    var isScrolling = false
    var isScrubbing = false
    var blinkPhase = false
    var isSeekBarHovering = false
    var scrollOffset: CGFloat = 0

    // Computed properties, timers, and interaction logic live here
    func startBlinkTimer() { /* ... */ }
    func handleScrubStart() { /* ... */ }
}
```

**Step 2: Extract child view structs (NOT extensions)**

```swift
// MainWindowTransportLayer.swift
struct MainWindowTransportLayer: View {
    let skinSprites: SkinSprites
    let isPlaying: Bool
    let onPlay: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void

    var body: some View {
        // This IS a separate View type -- real recomposition boundary
        // Only re-evaluates when isPlaying or skinSprites change
        ZStack(alignment: .topLeading) {
            playButton.at(x: 16, y: 88)
            pauseButton.at(x: 39, y: 88)
            stopButton.at(x: 62, y: 88)
            // ...
        }
    }
}
```

**Step 3: Root view becomes thin composer**

```swift
// WinampMainWindow.swift (~120 lines)
struct WinampMainWindow: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(AudioEngineManager.self) private var audioEngine
    @State private var interaction = WinampMainWindowInteractionState()

    var body: some View {
        ZStack(alignment: .topLeading) {
            if appSettings.isShadeMode {
                MainWindowShadeLayer(interaction: interaction)
            } else {
                MainWindowFullLayer(interaction: interaction)
            }
        }
    }
}

// MainWindowFullLayer.swift
struct MainWindowFullLayer: View {
    @Bindable var interaction: WinampMainWindowInteractionState
    @Environment(AppSettings.self) private var appSettings
    @Environment(SkinManager.self) private var skinManager

    var body: some View {
        ZStack(alignment: .topLeading) {
            MainWindowTrackInfoLayer(
                trackTitle: appSettings.currentTrackTitle,
                isScrolling: $interaction.isScrolling,
                scrollOffset: $interaction.scrollOffset
            )
            .at(x: 111, y: 27)

            MainWindowTransportLayer(
                skinSprites: skinManager.transportSprites,
                isPlaying: appSettings.isPlaying,
                onPlay: { audioEngine.play() },
                onPause: { audioEngine.pause() },
                onStop: { audioEngine.stop() }
            )
            .at(x: 16, y: 88)

            MainWindowSlidersLayer(
                volume: $appSettings.volume,
                balance: $appSettings.balance,
                isScrubbing: $interaction.isScrubbing
            )
            .at(x: 107, y: 57)

            MainWindowIndicatorsLayer(
                playState: appSettings.playState,
                bitrate: appSettings.currentBitrate,
                sampleRate: appSettings.currentSampleRate,
                isMono: appSettings.isMono
            )
            .at(x: 24, y: 28)
        }
    }
}
```

#### Implemented Directory Structure (PR #54, Merged)

```
MacAmpApp/Views/MainWindow/              # 10 files, all implemented
  WinampMainWindow.swift                 // Root composition + lifecycle only
  WinampMainWindowLayout.swift           // Coordinate constants
  WinampMainWindowInteractionState.swift // @Observable: scrubbing/scrolling/blink state
  MainWindowFullLayer.swift              // Full-mode composition
  MainWindowShadeLayer.swift             // Shade-mode composition
  MainWindowTransportLayer.swift         // Transport buttons
  MainWindowTrackInfoLayer.swift         // Scrolling track text + displayTitleProvider closure
  MainWindowIndicatorsLayer.swift        // Play/pause, mono/stereo, bitrate
  MainWindowSlidersLayer.swift           // Volume, balance, position + scrubResetTask cancellation
  MainWindowOptionsMenuPresenter.swift   // AppKit NSMenu bridge
```

#### Why This Is Better: Concrete Benefits

| Aspect | Cross-File Extension | Layer Subviews |
|--------|---------------------|----------------|
| **Recomposition boundary** | None (same type) | Real (separate View types) |
| **@State visibility** | Internal (leaked) | Private or @Observable |
| **Dependency isolation** | None (sees everything) | Explicit via init params |
| **Performance** | Entire body re-evaluates | Only affected children |
| **Testability** | Cannot test in isolation | Each layer testable alone |
| **Refactoring safety** | Must check all files | Change is localized |
| **Lint compliance** | Satisfies threshold | Genuinely smaller types |

#### Key Architecture Rules

1. **Child views receive only what they need** via init parameters or `@Binding`. No child should have access to state it does not render.

2. **@Environment dependencies pass through automatically** to children. You do NOT need to forward `@Environment(AppSettings.self)` -- children declare their own `@Environment` and SwiftUI resolves it.

3. **Pixel-perfect sprite rendering is preserved.** The `.at(x:y:)` absolute positioning extension works identically in child views. The root composer positions each child layer with `.at()`, and the child positions its internal sprites with `.at()`.

4. **Each child view creates a real SwiftUI recomposition boundary.** When volume changes, only `MainWindowSlidersLayer` re-evaluates its body -- the transport buttons, track info, and indicators are untouched.

5. **@Observable interaction state replaces scattered @State vars.** A single `@Observable` class can be shared across children via `@Bindable`, and its properties trigger fine-grained observation (only the view reading a specific property re-evaluates when it changes).

#### When to Use Each Approach

**Extension split (TEMPORARY tactical fix):**
- Unblocking a lint-blocked commit when there is no time for proper refactoring
- Must be tracked in `placeholder.md` with a follow-up task to do proper decomposition
- Acceptable for 1-2 sprint cycles maximum before converting to layer subviews

**Layer subviews (PROPER architecture):**
- Any view exceeding ~400 lines
- Any view with 5+ `@State` properties
- Any view mixing multiple concerns (transport + track info + sliders + indicators)
- Any view that will grow as features are added
- Any view where performance profiling shows excessive body re-evaluation

#### Relationship to Lesson #13 (Risk-Ordered Refactoring)

This lesson complements Lesson #13's incremental extraction strategy. The difference:
- **Lesson #13** addresses extracting *logic* (AudioPlayer god object into focused components)
- **Lesson #25** addresses extracting *views* (SwiftUI view structs into layer subviews)

Both share the same principle: extract with explicit dependency injection, not shared mutable state. Both use risk-ordered incremental migration (low risk layers first, complex interactive layers last).

#### T3 Implementation Details (PR #54, Feb 22, 2026)

The MainWindow decomposition was executed as a 5-phase migration with 3 Oracle reviews and 10 PR comments resolved:

**Patterns discovered during implementation:**

1. **`displayTitleProvider` closure pattern** (Oracle fix): The track info layer receives a `() -> String` closure instead of capturing `appSettings.currentTrackTitle` directly. This avoids stale title capture -- without the closure, the title string would be captured by value at layer creation time, and subsequent track changes would not be reflected until the layer was recreated. The closure ensures the title is always read fresh from AppSettings.

2. **`Task.sleep` modernization**: All `DispatchQueue.main.asyncAfter` calls were replaced with structured `Task { try? await Task.sleep(for: .seconds(N)) }` patterns. This integrates with Swift Concurrency cancellation and avoids dispatch queue retain cycles.

3. **`scrubResetTask` cancellation pattern** (CodeRabbit finding, actionable): When the user starts a new scrub gesture, the previous scrub-reset task must be explicitly cancelled before creating a new one. Without cancellation, overlapping delayed resets race against each other, causing the scrub indicator to flicker between active/inactive states:
   ```swift
   // In MainWindowSlidersLayer
   scrubResetTask?.cancel()
   scrubResetTask = Task {
       try? await Task.sleep(for: .seconds(0.5))
       guard !Task.isCancelled else { return }
       interaction.isScrubbing = false
   }
   ```

4. **Shade time display double-offset fix** (Oracle finding): The shade-mode time display had a double-offset bug -- the parent layer applied `.at(x:y:)` positioning, and the time display view internally applied its own offset, resulting in the display being shifted twice. Fixed by removing the internal offset from the shade layer's time display.

5. **MainWindowVisualizerLayer isolation**: Identified as a future optimization opportunity. The visualizer updates at ~30 FPS and currently lives within MainWindowFullLayer. Extracting it to its own layer struct would create a recomposition boundary that prevents visualizer redraws from triggering the rest of the full layer.

**Review & PR statistics:**
- 3 Oracle reviews: Phase 1 scaffolding review, Phase 3 wiring review, full diff review
- 10 PR comments resolved: 2 false positive (redundant UserDefaults write, read from UserDefaults directly), 6 nitpick (cosmetic/style), 2 actionable (scrubResetTask cancellation, shade time offset)
- Zero regressions: all existing behavior preserved through decomposition

**Xcodeproj regeneration workflow** (discovered during T3): When adding/removing/renaming files in a SwiftPM-based Xcode project, the `.xcodeproj` can get out of sync. The reliable fix:
```bash
rm -rf MacAmpApp.xcodeproj && open Package.swift
```
Xcode regenerates the project file from `Package.swift`, picking up all file additions/removals/renames. This is faster and more reliable than manually adding files through Xcode's navigator.

#### Key Takeaways

1. **Cross-file extensions do NOT create SwiftUI recomposition boundaries** -- they are a lint workaround, not architecture
2. **@State must stay private** -- if you need to widen it for cross-file access, the decomposition is wrong
3. **Extract @Observable interaction state** to consolidate scattered @State into a single object with fine-grained observation
4. **Child view structs with explicit init params** enforce dependency isolation and create real performance boundaries
5. **Architecture drives lint thresholds, not the reverse** -- set `type_body_length` to 500+ if needed while migrating
6. **Extension split is acceptable ONLY as a tracked temporary fix** with a follow-up task in placeholder.md
7. **Root view should be ~120 lines** -- if it is longer, there are more layers to extract
8. **Use closures for dynamic data** (`displayTitleProvider`) to avoid stale captures in layer subviews
9. **Cancel previous async tasks** before creating new ones (scrubResetTask pattern) to prevent race conditions
10. **Regenerate xcodeproj from Package.swift** (`rm -rf *.xcodeproj && open Package.swift`) when file structure changes

### 26. Coordinator Volume Routing + Capability Flags (February 2026)

**Lesson from:** Internet streaming volume control task (`tasks/internet-streaming-volume-control/`)
**Oracle Grade:** gpt-5.3-codex, xhigh -- 1 finding fixed (stream error capability flag recovery)

#### Pattern 1: Coordinator Fan-Out for Multi-Backend Volume

PlaybackCoordinator serves as the single entry point for volume changes across all audio backends:

```swift
@MainActor
@Observable
final class PlaybackCoordinator {
    func setVolume(_ value: Float) {
        audioPlayer.volume = value           // Local file playback
        streamPlayer.volume = value          // Internet radio
        videoPlaybackController.volume = value // Video playback
    }
}
```

**Key design decisions:**
- **Unconditional fan-out** -- propagates to ALL backends regardless of which is active. Simpler than checking active backend, zero cost on idle players (setting a Float property on a paused/stopped player is essentially free)
- **AudioPlayer.volume didSet** only updates `playerNode.volume` + persists to `UserDefaults` -- it does NOT propagate to other backends. This prevents circular updates
- **All external volume changes MUST go through coordinator** -- direct `audioPlayer.volume = x` from UI code bypasses stream/video backends

#### Pattern 2: Capability Flags with Error Recovery

PlaybackCoordinator exposes computed properties that reflect which features are available based on the active backend:

```swift
var supportsEQ: Bool {
    !isStreamBackendActive || streamPlayer.error != nil
}
var supportsBalance: Bool {
    !isStreamBackendActive || streamPlayer.error != nil
}
var supportsVisualizer: Bool {
    !isStreamBackendActive || streamPlayer.error != nil
}

private var isStreamBackendActive: Bool {
    streamPlayer.isPlaying || streamPlayer.isBuffering
}
```

**Critical detail:** The `|| streamPlayer.error != nil` clause handles error recovery. When a stream fails (network error, invalid URL), the error state re-enables EQ/balance/visualizer controls so the user is not stuck with permanently dimmed UI. Without this check, a failed stream would leave controls disabled until the user explicitly switches away from streaming.

**UI integration:**
```swift
// In EQ/balance views
.opacity(playbackCoordinator.supportsEQ ? 1.0 : 0.5)
.allowsHitTesting(playbackCoordinator.supportsEQ)
```

#### Pattern 3: Asymmetric SwiftUI Binding

Volume UI controls use an asymmetric `Binding` -- reads from one source, writes through another:

```swift
Binding<Float>(
    get: { audioPlayer.volume },              // Source of truth (persisted in UserDefaults)
    set: { playbackCoordinator.setVolume($0) } // Fan-out to all backends
)
```

**Why asymmetric:**
- **Read path:** `audioPlayer.volume` is the persisted source of truth (loaded from UserDefaults on init). Reading from coordinator would add an unnecessary indirection layer
- **Write path:** `playbackCoordinator.setVolume()` ensures all backends receive the update. Writing directly to `audioPlayer.volume` would skip stream/video backends
- This is NOT a standard `@Bindable` pattern -- the asymmetry is intentional and correct when the source of truth differs from the write path

#### Pattern 4: Init Sync for Persisted Values

Two-layer sync ensures the first stream play uses the user's saved volume, not a default:

```swift
// Layer 1: PlaybackCoordinator.init
init(audioPlayer: AudioPlayer, streamPlayer: StreamPlayer, ...) {
    // Sync persisted volume from AudioPlayer (loaded from UserDefaults)
    streamPlayer.volume = audioPlayer.volume
}

// Layer 2: StreamPlayer.play(station:) -- belt-and-suspenders
func play(station: RadioStation) {
    player.volume = volume  // Apply current volume before playback starts
    // ... begin streaming ...
}
```

**Why belt-and-suspenders:** Init sync handles the common case. The `play(station:)` sync handles edge cases where `StreamPlayer` might be re-created or the `AVPlayer` instance is replaced. Both are cheap (Float assignment) and prevent the jarring experience of a stream starting at default volume (0.75) instead of the user's saved volume (e.g., 0.3).

#### Key Takeaways

1. **Fan-out unconditionally** -- don't check which backend is active; propagate volume/mute to all backends every time
2. **Capability flags must handle error states** -- not just active/inactive; a failed stream should re-enable controls
3. **Asymmetric bindings are correct** when the source of truth (persisted value) differs from the write path (coordinator fan-out)
4. **Init-time sync prevents first-use mismatch** -- always apply persisted values to all backends during initialization
5. **Belt-and-suspenders sync** is cheap insurance for stateful backend objects that may be re-created

---

**Built with ❤️ for retro computing on modern macOS**

*This skill document captures 9+ months of lessons learned building MacAmp, distilled into actionable patterns for building similar retro-styled macOS applications with modern Swift 6 patterns. Updated with T3 MainWindow Layer Decomposition (PR #54, Feb 2026) -- full implementation of the layer subview pattern: 10 files, displayTitleProvider closure, Task.sleep modernization, scrubResetTask cancellation, xcodeproj regeneration workflow. Also includes coordinator volume routing and capability flags, multi-backend volume fan-out, asymmetric SwiftUI bindings, error-recovery capability flags, SwiftUI view decomposition architecture, memory & CPU optimization with SPSC shared buffer for zero-allocation audio thread data transfer, Goertzel precomputation, lazy skin loading, CGImage memory leak fixes, WindowCoordinator Facade + Composition refactoring, god object decomposition, phased migration strategy, Oracle-driven quality gates, and Swift 6.2 concurrency compliance.*
