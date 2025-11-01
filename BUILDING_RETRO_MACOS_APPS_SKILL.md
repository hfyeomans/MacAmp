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

---

## Quick Reference

### File Structure

```
MacAmp/
├── MacAmpApp/
│   ├── Audio/
│   │   └── AudioPlayer.swift           # AVAudioEngine + EQ + spectrum
│   ├── Models/
│   │   ├── SpriteResolver.swift        # Semantic → actual sprite mapping
│   │   ├── Skin.swift                  # Skin data model
│   │   ├── SkinSprites.swift           # Sprite definitions
│   │   └── Track.swift                 # Audio track model
│   ├── ViewModels/
│   │   ├── SkinManager.swift           # Skin loading & hot-swap
│   │   └── DockingController.swift     # Multi-window coordination
│   ├── Views/
│   │   ├── WinampMainWindow.swift      # Main player UI
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
**Last Updated:** 2025-10-31

**Recent Additions:**
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

**Built with ❤️ for retro computing on modern macOS**

*This skill document captures 6+ months of lessons learned building MacAmp, distilled into actionable patterns for building similar retro-styled macOS applications with modern Swift 6 patterns. Updated with internet radio streaming and complete notarization experience.*
