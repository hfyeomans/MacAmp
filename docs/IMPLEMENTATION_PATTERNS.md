# MacAmp Implementation Patterns

**Version:** 1.0.0
**Date:** 2025-11-01
**Purpose:** Practical code patterns and best practices for MacAmp development

---

## Table of Contents

1. [Pattern Overview](#pattern-overview)
2. [State Management Patterns](#state-management-patterns)
3. [UI Component Patterns](#ui-component-patterns)
4. [Audio Processing Patterns](#audio-processing-patterns)
5. [Async/Await Patterns](#asyncawait-patterns)
6. [Error Handling Patterns](#error-handling-patterns)
7. [Testing Patterns](#testing-patterns)
8. [Migration Guides](#migration-guides)
9. [Anti-Patterns to Avoid](#anti-patterns-to-avoid)
10. [Quick Reference](#quick-reference)

---

## Pattern Overview

This document captures the proven patterns used throughout MacAmp's codebase. Each pattern includes:
- **When to use it**: The problem it solves
- **Implementation**: Complete code example
- **Real usage**: Where it's used in MacAmp
- **Pitfalls**: Common mistakes to avoid

---

## State Management Patterns

### Pattern: @Observable with @MainActor

**When to use**: For UI-bound state that needs thread safety

**Implementation**:
```swift
@MainActor
@Observable
final class PlayerState {
    // Observable properties (automatic change detection)
    private(set) var isPlaying: Bool = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    // Non-observable (use @ObservationIgnored)
    @ObservationIgnored
    private var updateTimer: Timer?

    // All methods run on main thread automatically
    func play() {
        isPlaying = true
        startTimer()
    }

    func pause() {
        isPlaying = false
        stopTimer()
    }

    private func startTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.currentTime += 0.1
        }
    }
}
```

**Real usage**: `AudioPlayer.swift`, `StreamPlayer.swift`, `PlaybackCoordinator.swift`

**Pitfalls**:
- Don't forget `@MainActor` for UI state
- Use `private(set)` for read-only properties
- Remember `@ObservationIgnored` for non-UI properties

### Pattern: Dependency Injection via Environment

**When to use**: Sharing state across multiple views

**Implementation**:
```swift
// 1. Create the observable model
@Observable
final class AppState {
    var theme: Theme = .default
    var volume: Float = 0.5
}

// 2. Inject at app root
@main
struct MyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)  // Inject here
        }
    }
}

// 3. Consume in any child view
struct PlayerView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        Slider(value: Binding(
            get: { appState.volume },
            set: { appState.volume = $0 }
        ))
    }
}
```

**Real usage**: `MacAmpApp.swift` injects all major services

**Pitfalls**:
- Must use `@State` at injection point, not computed property
- Don't inject too many separate objects (group related state)

### Pattern: Computed Properties with Dependency Tracking

**When to use**: Derived state that updates automatically

**Implementation**:
```swift
@Observable
final class PlaylistManager {
    var tracks: [Track] = []
    var currentIndex: Int = 0

    // Computed properties automatically track dependencies
    var currentTrack: Track? {
        guard currentIndex >= 0 && currentIndex < tracks.count else {
            return nil
        }
        return tracks[currentIndex]
    }

    var hasNext: Bool {
        currentIndex < tracks.count - 1
    }

    var hasPrevious: Bool {
        currentIndex > 0
    }

    // These will trigger view updates when dependencies change
    var displayTitle: String {
        currentTrack?.title ?? "No Track"
    }
}
```

**Real usage**: `PlaybackCoordinator.swift` for `displayTitle`, `canUseEQ`

### Pattern: Enum State with Persistence (RepeatMode Pattern)

**When to use**: Multi-state UI controls that need to persist across app launches

**Implementation**:
```swift
// File: MacAmpApp/Models/AppSettings.swift:232-266
// Purpose: Three-state repeat mode matching Winamp 5 Modern skins
// Context: Replaces boolean repeatEnabled with richer state model

enum RepeatMode: String, Codable, CaseIterable {
    case off = "off"
    case all = "all"  // Loop playlist
    case one = "one"  // Repeat current track

    /// Cycle to next mode (UI button behavior)
    func next() -> RepeatMode {
        let cases = Self.allCases
        guard let index = cases.firstIndex(of: self) else { return self }
        let nextIndex = (index + 1) % cases.count
        return cases[nextIndex]
    }

    /// UI display label for tooltips and menus
    var label: String {
        switch self {
        case .off: return "Repeat: Off"
        case .all: return "Repeat: All"
        case .one: return "Repeat: One"
        }
    }

    /// Button state - lit when active
    var isActive: Bool {
        self != .off
    }
}

// In AppSettings class (persistence layer)
@Observable
@MainActor
final class AppSettings {
    var repeatMode: RepeatMode = .off {
        didSet {
            UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
        }
    }

    init() {
        // Migration from old boolean key
        if let savedMode = UserDefaults.standard.string(forKey: "repeatMode"),
           let mode = RepeatMode(rawValue: savedMode) {
            self.repeatMode = mode
        } else {
            // Migrate: preserve user preference
            let oldRepeat = UserDefaults.standard.bool(forKey: "audioPlayerRepeatEnabled")
            self.repeatMode = oldRepeat ? .all : .off
        }
    }
}

// In AudioPlayer (computed property for single source of truth)
var repeatMode: AppSettings.RepeatMode {
    get { AppSettings.instance().repeatMode }
    set { AppSettings.instance().repeatMode = newValue }
}
```

**Real usage**: `AppSettings.swift` RepeatMode, TimeDisplayMode, VisualizerMode

**Pitfalls**:
- Don't duplicate state (use computed property in AudioPlayer)
- Remember migration logic for existing users
- Use CaseIterable for future-proof cycling

---

## UI Component Patterns

### Pattern: Sprite-Based Button Component

**When to use**: Creating interactive skinned buttons

**Implementation**:
```swift
// File: MacAmpApp/Views/Components/SimpleSpriteImage.swift (actual button pattern)
// Purpose: Interactive sprite rendering with button behaviors
// Context: Core component used throughout all UI views

struct SimpleSpriteImage: View {
    let source: SpriteSource
    let width: CGFloat?
    let height: CGFloat?
    let action: SpriteAction?

    @Environment(SkinManager.self) var skinManager
    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        if let imageName = resolveSpriteName(),
           let image = skinManager.currentSkin?.images[imageName] {

            switch action {
            case .button(let onClick, let whilePressed, let onRelease):
                Image(nsImage: image)
                    .interpolation(.none)  // Pixel-perfect rendering
                    .antialiased(false)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .onHover { hovering in
                        isHovered = hovering
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isPressed {
                                    isPressed = true
                                    whilePressed?()
                                }
                            }
                            .onEnded { _ in
                                if isPressed {
                                    isPressed = false
                                    onRelease?()
                                    onClick?()
                                }
                            }
                    )

            case .toggle(let isOn, let onChange):
                Image(nsImage: image)
                    .interpolation(.none)
                    .antialiased(false)
                    .onTapGesture {
                        onChange(!isOn)
                    }

            default:
                Image(nsImage: image)
                    .interpolation(.none)
                    .antialiased(false)
            }
        }
    }

    private func resolveSpriteName() -> String? {
        switch source {
        case .legacy(let name):
            return name
        case .semantic(let semantic):
            guard let skin = skinManager.currentSkin else { return nil }
            return SpriteResolver(skin: skin).resolve(semantic)
        }
    }
}
```

**Real usage**: All buttons in `WinampMainWindow.swift`, `WinampEqualizerWindow.swift`

### Pattern: Absolute Positioning Extension

**When to use**: Placing elements at exact pixel coordinates

**Implementation**:
```swift
// File: MacAmpApp/Views/Components/SimpleSpriteImage.swift:85-89
// Purpose: Absolute positioning using top-left origin like Winamp
// Context: Critical for pixel-perfect layout matching original Winamp

extension View {
    /// Position view at exact coordinates (top-left origin like Winamp)
    func at(x: CGFloat, y: CGFloat) -> some View {
        self.offset(x: x, y: y)
    }
}

// Usage examples from actual code:
// File: MacAmpApp/Views/WinampMainWindow.swift
SimpleSpriteImage(
    source: .legacy("MAIN_PLAY_BUTTON"),
    action: .button(onClick: { playbackCoordinator.play() })
)
.at(x: 39, y: 88)  // Exact Winamp coordinates

// Time display positioning
TimeDisplay()
    .at(x: 39, y: 26)

// Visualizer positioning
VisualizerView()
    .at(x: 24, y: 43)
```

**Real usage**: Every component placement in window views

### Pattern: Multi-State Slider

**When to use**: Creating draggable sliders with visual feedback

**Implementation**:
```swift
struct SkinSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let thumbSprite: ResolvedSprite
    let trackSprite: ResolvedSprite
    let trackRect: CGRect

    @State private var isDragging = false
    @State private var dragStartValue: Double = 0

    private var thumbOffset: CGFloat {
        let percent = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return trackRect.width * CGFloat(percent)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Track
            Image(nsImage: trackSprite.image)
                .interpolation(.none)

            // Thumb
            Image(nsImage: thumbSprite.image)
                .interpolation(.none)
                .offset(x: thumbOffset)
                .gesture(
                    DragGesture()
                        .onChanged { drag in
                            if !isDragging {
                                isDragging = true
                                dragStartValue = value
                            }

                            let percent = drag.location.x / trackRect.width
                            let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * Double(percent)
                            value = newValue.clamped(to: range)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
        }
        .frame(width: trackRect.width, height: trackRect.height)
    }
}
```

**Real usage**: Volume/balance sliders, EQ sliders

---

## Audio Processing Patterns

### Pattern: Safe Audio Buffer Processing

**When to use**: Processing audio buffers from taps

**Implementation**:
```swift
struct AudioProcessor {
    static func processSafely(
        buffer: AVAudioPCMBuffer,
        process: (UnsafeBufferPointer<Float>) -> Void
    ) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        // Process each channel safely
        for channel in 0..<channelCount {
            let data = UnsafeBufferPointer(
                start: channelData[channel],
                count: frameLength
            )
            process(data)
        }
    }

    static func mixToMono(buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }

        let frameLength = Int(buffer.frameLength)
        var mono = [Float](repeating: 0, count: frameLength)

        if buffer.format.channelCount == 2 {
            // Mix stereo to mono
            vDSP_vadd(
                channelData[0], 1,  // Left
                channelData[1], 1,  // Right
                &mono, 1,
                vDSP_Length(frameLength)
            )
            var scale: Float = 0.5
            vDSP_vsmul(&mono, 1, &scale, &mono, 1, vDSP_Length(frameLength))
        } else {
            // Copy mono
            mono = Array(UnsafeBufferPointer(
                start: channelData[0],
                count: frameLength
            ))
        }

        return mono
    }
}
```

**Real usage**: `AudioPlayer.swift` visualization processing

### Pattern: Thread-Safe Audio State

**When to use**: Sharing audio state between threads

**Implementation**:
```swift
actor AudioState {
    private var spectrum: [Float] = Array(repeating: 0, count: 75)
    private var waveform: [Float] = Array(repeating: 0, count: 576)

    func updateSpectrum(_ newSpectrum: [Float]) {
        spectrum = newSpectrum
    }

    func updateWaveform(_ newWaveform: [Float]) {
        waveform = newWaveform
    }

    func getSpectrum() -> [Float] {
        spectrum
    }

    func getWaveform() -> [Float] {
        waveform
    }
}

// Usage from audio tap (background thread)
Task.detached {
    let spectrum = processFFT(buffer)
    await audioState.updateSpectrum(spectrum)
}

// Usage from UI (main thread)
Task { @MainActor in
    let spectrum = await audioState.getSpectrum()
    spectrumView.update(spectrum)
}
```

**Real usage**: Visualization data flow in `AudioPlayer.swift`

---

## Async/Await Patterns

### Pattern: Async Stream Events

**When to use**: Publishing events from async contexts

**Implementation**:
```swift
@Observable
final class EventEmitter {
    let events: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation

    enum Event {
        case trackChanged(Track)
        case errorOccurred(Error)
        case stateChanged(State)
    }

    init() {
        (events, continuation) = AsyncStream<Event>.makeStream()
    }

    func emit(_ event: Event) {
        continuation.yield(event)
    }

    deinit {
        continuation.finish()
    }
}

// Consumer
Task {
    for await event in emitter.events {
        switch event {
        case .trackChanged(let track):
            updateUI(for: track)
        case .errorOccurred(let error):
            showError(error)
        case .stateChanged(let state):
            handleStateChange(state)
        }
    }
}
```

**Real usage**: Future pattern for event systems

### Pattern: Cancellable Tasks

**When to use**: Tasks that should be cancelled when view disappears

**Implementation**:
```swift
struct DataLoadingView: View {
    @State private var loadTask: Task<Void, Never>?
    @State private var data: [Item] = []

    var body: some View {
        List(data) { item in
            ItemRow(item: item)
        }
        .task {
            loadTask = Task {
                do {
                    for await batch in loadDataStream() {
                        // Check for cancellation
                        try Task.checkCancellation()
                        data.append(contentsOf: batch)
                    }
                } catch {
                    // Handle cancellation or other errors
                    if !Task.isCancelled {
                        print("Load error: \(error)")
                    }
                }
            }
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }
}
```

**Real usage**: Stream metadata loading in `StreamPlayer.swift`

---

## Error Handling Patterns

### Pattern: Result Builder for Complex Operations

**When to use**: Operations with multiple failure points

**Implementation**:
```swift
enum LoadError: Error {
    case invalidURL
    case downloadFailed(Error)
    case extractionFailed
    case parsingFailed(String)
}

struct SkinLoader {
    static func load(from url: URL) async -> Result<Skin, LoadError> {
        // Validate URL
        guard url.pathExtension == "wsz" else {
            return .failure(.invalidURL)
        }

        // Download if needed
        let localURL: URL
        if url.isFileURL {
            localURL = url
        } else {
            do {
                localURL = try await download(url)
            } catch {
                return .failure(.downloadFailed(error))
            }
        }

        // Extract archive
        guard let extracted = try? extractArchive(localURL) else {
            return .failure(.extractionFailed)
        }

        // Parse skin files
        guard let skin = try? parseSkin(from: extracted) else {
            return .failure(.parsingFailed("Invalid skin format"))
        }

        return .success(skin)
    }
}

// Usage
Task {
    let result = await SkinLoader.load(from: skinURL)

    switch result {
    case .success(let skin):
        applySkin(skin)
    case .failure(let error):
        switch error {
        case .invalidURL:
            showAlert("Invalid skin file")
        case .downloadFailed(let underlying):
            showAlert("Download failed: \(underlying)")
        case .extractionFailed:
            showAlert("Could not extract skin archive")
        case .parsingFailed(let reason):
            showAlert("Skin format error: \(reason)")
        }
    }
}
```

**Real usage**: Skin loading in `SkinManager.swift`

### Pattern: Graceful Degradation

**When to use**: Non-critical features that shouldn't crash the app

**Implementation**:
```swift
struct VisualizationView: View {
    @State private var spectrum: [Float] = Array(repeating: 0, count: 75)
    @State private var visualizationAvailable = true

    var body: some View {
        Group {
            if visualizationAvailable {
                SpectrumBars(data: spectrum)
                    .onAppear {
                        startVisualization()
                    }
            } else {
                // Fallback UI
                Text("Visualization unavailable")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func startVisualization() {
        do {
            try AudioEngine.shared.installTap { buffer in
                // Process audio
                updateSpectrum(from: buffer)
            }
        } catch {
            // Gracefully degrade
            print("Could not start visualization: \(error)")
            visualizationAvailable = false
        }
    }
}
```

**Real usage**: Spectrum analyzer fallback

---

## Testing Patterns

### Pattern: Mock Injection for Testing

**When to use**: Unit testing components with dependencies

**Implementation**:
```swift
// Protocol for mockable dependency
protocol AudioPlayable {
    var isPlaying: Bool { get }
    func play()
    func pause()
    func stop()
}

// Real implementation
@Observable
final class AudioPlayer: AudioPlayable {
    private(set) var isPlaying = false

    func play() {
        // Real implementation
        isPlaying = true
    }
}

// Mock for testing
class MockAudioPlayer: AudioPlayable {
    var isPlaying = false
    var playCalled = false

    func play() {
        playCalled = true
        isPlaying = true
    }
}

// Component that uses the protocol
struct PlayerControls: View {
    let player: AudioPlayable

    var body: some View {
        Button(player.isPlaying ? "Pause" : "Play") {
            if player.isPlaying {
                player.pause()
            } else {
                player.play()
            }
        }
    }
}

// Test
func testPlayButton() {
    let mock = MockAudioPlayer()
    let controls = PlayerControls(player: mock)

    // Trigger play
    controls.playButton.tap()

    XCTAssertTrue(mock.playCalled)
    XCTAssertTrue(mock.isPlaying)
}
```

**Real usage**: Testing patterns for `PlaybackCoordinator`

### Pattern: Async Test Helpers

**When to use**: Testing async operations

**Implementation**:
```swift
extension XCTestCase {
    func asyncTest<T>(
        timeout: TimeInterval = 5,
        test: @escaping () async throws -> T
    ) async throws -> T {
        try await withTimeout(seconds: timeout) {
            try await test()
        }
    }

    func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TestTimeout()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// Usage in test
func testStreamLoading() async throws {
    let player = StreamPlayer()

    try await asyncTest {
        await player.play(url: testStreamURL)
        XCTAssertTrue(player.isPlaying)
    }
}
```

---

## Migration Guides

### Migrating from ObservableObject to @Observable

**Step 1**: Remove ObservableObject conformance
```swift
// Before
class MyModel: ObservableObject {
    @Published var value = 0
}

// After
@Observable
final class MyModel {
    var value = 0
}
```

**Step 2**: Update view bindings
```swift
// Before
struct MyView: View {
    @StateObject private var model = MyModel()
    // or
    @ObservedObject var model: MyModel
    // or
    @EnvironmentObject var model: MyModel
}

// After
struct MyView: View {
    @State private var model = MyModel()
    // or
    @Environment(MyModel.self) var model
}
```

**Step 3**: Remove Combine imports
```swift
// Before
import Combine

class MyModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
}

// After
// No Combine needed
@Observable
final class MyModel {
    // No cancellables needed
}
```

### Migrating from Boolean to Enum State (RepeatMode Example)

**When to migrate**: When a boolean flag becomes insufficient and you need 3+ states

**Before**: Boolean flag with limited expressiveness
```swift
// Old implementation
class AudioPlayer {
    @Published var repeatEnabled: Bool = false  // Only on/off

    func handleTrackEnd() {
        if repeatEnabled {
            // Repeat... but what exactly? Current track? Playlist?
            restartPlaylist()  // Ambiguous behavior
        }
    }
}
```

**After**: Rich enum with clear semantics
```swift
// New implementation with RepeatMode enum
enum RepeatMode: String, Codable, CaseIterable {
    case off = "off"   // Stop at end
    case all = "all"   // Loop playlist
    case one = "one"   // Repeat current track
}

class AudioPlayer {
    var repeatMode: RepeatMode = .off

    func handleTrackEnd() {
        switch repeatMode {
        case .off:
            stop()  // Clear behavior
        case .all:
            playFirstTrack()  // Clear behavior
        case .one:
            restartCurrentTrack()  // Clear behavior
        }
    }
}
```

**Migration with User Preference Preservation**:
```swift
// In AppSettings init()
init() {
    // Try to load new enum value
    if let savedMode = UserDefaults.standard.string(forKey: "repeatMode"),
       let mode = RepeatMode(rawValue: savedMode) {
        self.repeatMode = mode
    } else {
        // Fall back to old boolean, preserve user's choice
        let oldRepeat = UserDefaults.standard.bool(forKey: "audioPlayerRepeatEnabled")
        self.repeatMode = oldRepeat ? .all : .off

        // Save in new format
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")

        // Optional: Clean up old key
        UserDefaults.standard.removeObject(forKey: "audioPlayerRepeatEnabled")
    }
}
```

**Real usage**: RepeatMode migration in MacAmp v0.7.9

### Migrating from Timer to Task.sleep

**Before**: Timer-based updates
```swift
class PollingService {
    private var timer: Timer?

    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.poll()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
```

**After**: Task-based updates
```swift
@Observable
final class PollingService {
    private var pollTask: Task<Void, Never>?

    func startPolling() {
        pollTask = Task {
            while !Task.isCancelled {
                poll()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
```

---

## Anti-Patterns to Avoid

### Anti-Pattern: Computed @State

**Wrong**:
```swift
struct BadView: View {
    // ❌ Recomputed on every view update!
    var viewModel: ViewModel {
        ViewModel(data: loadData())
    }
}
```

**Correct**:
```swift
struct GoodView: View {
    // ✅ Created once, persists across updates
    @State private var viewModel = ViewModel(data: loadData())
}
```

### Anti-Pattern: Force Unwrapping

**Wrong**:
```swift
// ❌ Will crash if nil
let track = playlist.tracks[index]!
let image = NSImage(named: spriteName)!
```

**Correct**:
```swift
// ✅ Safe handling
guard let track = playlist.tracks[safe: index] else { return }
let image = NSImage(named: spriteName) ?? fallbackImage
```

### Anti-Pattern: Synchronous I/O on Main Thread

**Wrong**:
```swift
struct BadView: View {
    var body: some View {
        // ❌ Blocks UI
        let data = try! Data(contentsOf: largeFileURL)
        Image(nsImage: NSImage(data: data)!)
    }
}
```

**Correct**:
```swift
struct GoodView: View {
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
            } else {
                ProgressView()
            }
        }
        .task {
            image = await loadImage(from: largeFileURL)
        }
    }
}
```

### Anti-Pattern: Massive View Bodies

**Wrong**:
```swift
struct BadView: View {
    var body: some View {
        // ❌ 500+ lines of nested views
        VStack {
            // ... hundreds of lines
        }
    }
}
```

**Correct**:
```swift
struct GoodView: View {
    var body: some View {
        VStack {
            HeaderSection()
            ContentSection()
            FooterSection()
        }
    }
}

// Extracted into focused components
struct HeaderSection: View { ... }
struct ContentSection: View { ... }
struct FooterSection: View { ... }
```

---

## Quick Reference

### Common Extensions

```swift
// Safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// Clamping values
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// Async main actor running
extension Task where Failure == Never, Success == Void {
    @MainActor
    static func onMain(_ operation: @MainActor @escaping () async -> Void) {
        Task { @MainActor in
            await operation()
        }
    }
}
```

### Debug Helpers

```swift
// Performance timing
func measure<T>(_ label: String, operation: () throws -> T) rethrows -> T {
    let start = CFAbsoluteTimeGetCurrent()
    defer {
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        print("⏱ \(label): \(elapsed * 1000)ms")
    }
    return try operation()
}

// State debugging
extension View {
    func debugPrint(_ value: Any) -> some View {
        #if DEBUG
        print("🔍 \(value)")
        #endif
        return self
    }
}
```

### SwiftUI Modifiers

```swift
// Conditional modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// Usage
Text("Hello")
    .if(isLarge) { $0.font(.largeTitle) }
```

---

## Conclusion

These patterns represent the collective wisdom gained from building MacAmp. They emphasize:
- **Safety**: Prevent crashes through optional handling and error recovery
- **Performance**: Efficient audio processing and UI updates
- **Maintainability**: Clear separation of concerns and testability
- **Modernization**: Embrace Swift 6 features while maintaining stability

When implementing new features, prefer these established patterns. When you discover new patterns, document them here for the team.

---

*Document Version: 1.0.0 | Last Updated: 2025-11-01 | Lines: 847*