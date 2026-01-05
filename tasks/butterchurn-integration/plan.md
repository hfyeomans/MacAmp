# Butterchurn Integration - Revised Implementation Plan

**Task ID:** butterchurn-integration
**Created:** 2026-01-05
**Revised:** 2026-01-05 (Oracle Review)
**Approach:** WKUserScript Injection with 30 FPS Swift→JS + 60 FPS JS render loop
**Scope:** Local playback only (AVAudioEngine) with future stream capture design

---

## Key Decisions & Constraints

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Stream scope | Local playback only | AVPlayer provides no PCM; design for future SystemAudioCapture |
| Update rate | 30 FPS Swift→JS | Better stability; JS render loop at 60 FPS pulls from buffer |
| Preset manager layer | Bridge (ViewModels) | UI-coupled state, timer ownership, JS API dependency |
| Audio tap strategy | Merge into existing | AVAudioEngine allows only one tap per bus |

---

## Layer Placement (Three-Layer Pattern)

```
┌─────────────────────────────────────────────────────────────┐
│  PRESENTATION (Views)                                        │
│  ├── ButterchurnWebView.swift (struct NSViewRepresentable)  │
│  └── WinampMilkdropWindow.swift (embeds ButterchurnWebView) │
├─────────────────────────────────────────────────────────────┤
│  BRIDGE (ViewModels)                                         │
│  ├── ButterchurnBridge.swift (WKScriptMessageHandler)       │
│  └── ButterchurnPresetManager.swift (cycling, transitions)  │
├─────────────────────────────────────────────────────────────┤
│  MECHANISM (Models/Audio)                                    │
│  ├── AudioPlayer.swift (extended tap, Butterchurn FFT)      │
│  └── AppSettings.swift (Butterchurn preferences)            │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: WebView + JS Injection (Foundation)

**Goal:** Load Butterchurn reliably with correct injection order and JS render loop.

**Commit scope:** Phase 1 complete when static Butterchurn frame renders.

### 1.1 Create ButterchurnWebView (Presentation)

```swift
// MacAmpApp/Views/Windows/ButterchurnWebView.swift
struct ButterchurnWebView: NSViewRepresentable {
    @Environment(ButterchurnBridge.self) private var bridge

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()

        // Load JS from bundle
        let butterchurnJS = loadBundleJS("butterchurn.min")
        let presetsJS = loadBundleJS("butterchurnPresets.min")
        let bridgeJS = loadBundleJS("bridge")

        // Inject libraries at document start
        userContentController.addUserScript(WKUserScript(
            source: butterchurnJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        userContentController.addUserScript(WKUserScript(
            source: presetsJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        // Inject bridge at document end (after DOM ready)
        userContentController.addUserScript(WKUserScript(
            source: bridgeJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

        // Register message handler
        userContentController.add(bridge, name: "butterchurn")

        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        bridge.webView = webView

        // Load minimal HTML
        if let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Butterchurn") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }

        return webView
    }

    func dismantleNSView(_ nsView: WKWebView, coordinator: ()) {
        // CRITICAL: Remove handler to prevent retain cycle
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "butterchurn")
        bridge.cleanup()
    }

    private func loadBundleJS(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js", subdirectory: "Butterchurn"),
              let js = try? String(contentsOf: url) else {
            return "console.error('Failed to load \(name).js');"
        }
        return js
    }
}
```

### 1.2 Minimal HTML (index.html)

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        * { margin: 0; padding: 0; }
        body { background: #000; overflow: hidden; }
        canvas { display: block; width: 100%; height: 100%; }
        #fallback { display: none; color: #0f0; font-family: monospace;
                    text-align: center; padding-top: 40%; }
    </style>
</head>
<body>
    <canvas id="canvas"></canvas>
    <div id="fallback">Butterchurn unavailable</div>
</body>
</html>
```

### 1.3 Bridge JS Bootstrap (bridge.js)

```javascript
// Butterchurn/bridge.js
(function() {
    'use strict';

    // State
    let visualizer = null;
    let audioData = { spectrum: new Uint8Array(1024), waveform: new Float32Array(1024) };
    let isRunning = false;

    // Initialize after DOM ready (script injected at documentEnd)
    if (typeof butterchurn === 'undefined' || typeof butterchurnPresets === 'undefined') {
        document.getElementById('fallback').style.display = 'block';
        window.webkit.messageHandlers.butterchurn.postMessage({ type: 'loadFailed', error: 'Libraries not loaded' });
        return;
    }

    const canvas = document.getElementById('canvas');
    const presets = butterchurnPresets.getPresets();
    const presetKeys = Object.keys(presets);

    // Create visualizer
    visualizer = butterchurn.createVisualizer(null, canvas, {
        width: canvas.clientWidth,
        height: canvas.clientHeight,
        pixelRatio: window.devicePixelRatio || 1,
        textureRatio: 1
    });

    // Load initial preset
    if (presetKeys.length > 0) {
        visualizer.loadPreset(presets[presetKeys[0]], 0);
    }

    // 60 FPS render loop (pulls from latest audio data)
    function renderLoop() {
        if (!isRunning) return;
        visualizer.render();
        requestAnimationFrame(renderLoop);
    }

    // API for Swift bridge
    window.macampButterchurn = {
        setAudioData: function(spectrum, waveform) {
            audioData.spectrum.set(spectrum);
            audioData.waveform.set(waveform);
            // Butterchurn reads from mock analyser
        },

        loadPreset: function(index, transition) {
            const key = presetKeys[index];
            if (key) {
                visualizer.loadPreset(presets[key], transition || 2.7);
            }
        },

        showTrackTitle: function(title) {
            visualizer.launchSongTitleAnim(title);
        },

        setSize: function(width, height) {
            canvas.width = width;
            canvas.height = height;
            visualizer.setRendererSize(width, height);
        },

        start: function() {
            isRunning = true;
            requestAnimationFrame(renderLoop);
        },

        stop: function() {
            isRunning = false;
        }
    };

    // Notify Swift we're ready
    window.webkit.messageHandlers.butterchurn.postMessage({
        type: 'ready',
        presetCount: presetKeys.length,
        presetNames: presetKeys
    });

    // Start render loop
    window.macampButterchurn.start();
})();
```

### 1.4 Fallback UI

```swift
// In WinampMilkdropWindow.swift
struct WinampMilkdropWindow: View {
    @Environment(ButterchurnBridge.self) private var bridge

    var body: some View {
        MilkdropWindowChromeView {
            if bridge.isReady {
                ButterchurnWebView()
            } else {
                // Fallback placeholder
                Text("MILKDROP")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
        }
    }
}
```

**Success Criteria (Phase 1):**
- [ ] `butterchurn` global is defined before HTML init
- [ ] `butterchurnPresets.getPresets()` returns preset list
- [ ] JS render loop runs with static frame (no audio)
- [ ] Fallback UI shows if injection fails
- [ ] No WebView memory leaks on window close

---

## Phase 2: Audio Tap Merge (Mechanism)

**Goal:** Produce Butterchurn FFT + waveform from the existing tap.

**Commit scope:** Phase 2 complete when Butterchurn data available in AudioPlayer.

### 2.1 Extend AudioPlayer Tap

```swift
// MacAmpApp/Audio/AudioPlayer.swift additions

/// Butterchurn audio frame snapshot
struct ButterchurnFrame {
    let spectrum: [Float]   // 1024 bins (from 2048 FFT)
    let waveform: [Float]   // 1024 samples
    let timestamp: TimeInterval
}

// Add to AudioPlayer class
@ObservationIgnored private var butterchurnSpectrum: [Float] = Array(repeating: 0, count: 1024)
@ObservationIgnored private var butterchurnWaveform: [Float] = Array(repeating: 0, count: 1024)
@ObservationIgnored private var lastButterchurnUpdate: TimeInterval = 0

/// Thread-safe snapshot of current Butterchurn audio data
func snapshotButterchurnFrame() -> ButterchurnFrame? {
    // Only return data for local playback
    guard isLocalPlayback else { return nil }

    return ButterchurnFrame(
        spectrum: butterchurnSpectrum,
        waveform: butterchurnWaveform,
        timestamp: lastButterchurnUpdate
    )
}

// Inside existing installTap() method:
private func processButterchurnData(buffer: AVAudioPCMBuffer) {
    // Compute 2048-point FFT for Butterchurn (1024 bins)
    // Separate from existing 19-bar analysis
    // Store in butterchurnSpectrum and butterchurnWaveform
    // Update lastButterchurnUpdate = CACurrentMediaTime()
}
```

### 2.2 FFT Processing

```swift
// Extend existing visualizer tap to include Butterchurn processing
private func installVisualizerTap() {
    let format = engine.mainMixerNode.outputFormat(forBus: 0)

    engine.mainMixerNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, time in
        guard let self = self else { return }

        // Existing 19-bar spectrum analysis
        self.process19BarSpectrum(buffer: buffer)

        // NEW: Butterchurn 2048-FFT analysis
        self.processButterchurnData(buffer: buffer)
    }
}
```

**Success Criteria (Phase 2):**
- [ ] Single tap remains installed (no second tap)
- [ ] `snapshotButterchurnFrame()` returns valid data during local playback
- [ ] Returns `nil` for stream playback
- [ ] No UI observation churn from high-frequency updates

---

## Phase 3: Swift→JS Bridge (30 FPS)

**Goal:** Push audio data to JS at 30 FPS and let JS render at 60 FPS.

**Commit scope:** Phase 3 complete when visualization responds to music.

### 3.1 ButterchurnBridge

```swift
// MacAmpApp/ViewModels/ButterchurnBridge.swift
@MainActor
@Observable
final class ButterchurnBridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?

    var isReady: Bool = false
    var presetCount: Int = 0
    var presetNames: [String] = []

    @ObservationIgnored private var updateTimer: Timer?
    @ObservationIgnored private var audioPlayer: AudioPlayer?

    func configure(audioPlayer: AudioPlayer) {
        self.audioPlayer = audioPlayer
    }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else { return }

        switch type {
        case "ready":
            isReady = true
            presetCount = dict["presetCount"] as? Int ?? 0
            presetNames = dict["presetNames"] as? [String] ?? []
            startAudioUpdates()

        case "loadFailed":
            isReady = false
            stopAudioUpdates()

        default:
            break
        }
    }

    private func startAudioUpdates() {
        // 30 FPS = 1/30 second interval
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendAudioFrame()
            }
        }
    }

    private func stopAudioUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func sendAudioFrame() {
        guard let frame = audioPlayer?.snapshotButterchurnFrame(),
              let webView = webView else { return }

        // Convert to JSON arrays
        let spectrumJSON = frame.spectrum.map { UInt8(min(255, max(0, $0 * 255))) }
        let waveformJSON = frame.waveform

        let js = "window.macampButterchurn.setAudioData(\(spectrumJSON), \(waveformJSON));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func cleanup() {
        stopAudioUpdates()
        webView = nil
    }
}
```

**Success Criteria (Phase 3):**
- [ ] JS buffers update at 30 FPS
- [ ] JS render loop continues at 60 FPS
- [ ] Visualization responds to bass, treble
- [ ] No perceptible audio/visual lag
- [ ] Clean start/stop on playback state changes

---

## Phase 4: Preset Manager (Bridge Layer)

**Goal:** Manage presets, cycling, and transitions.

**Commit scope:** Phase 4 complete when presets cycle automatically.

### 4.1 ButterchurnPresetManager

```swift
// MacAmpApp/ViewModels/ButterchurnPresetManager.swift
@MainActor
@Observable
final class ButterchurnPresetManager {
    var presets: [String] = []
    var currentPresetIndex: Int = 0
    var isRandomize: Bool = true
    var isCycling: Bool = true
    var cycleInterval: TimeInterval = 15.0
    var transitionDuration: Double = 2.7

    @ObservationIgnored private var presetHistory: [Int] = []
    @ObservationIgnored private var cycleTimer: Timer?
    @ObservationIgnored private weak var bridge: ButterchurnBridge?

    func configure(bridge: ButterchurnBridge, appSettings: AppSettings) {
        self.bridge = bridge

        // Load from settings
        isRandomize = appSettings.butterchurnRandomize
        isCycling = appSettings.butterchurnCycling
        cycleInterval = appSettings.butterchurnCycleInterval
    }

    func loadPresets(_ names: [String]) {
        presets = names
        if presets.count > 0 {
            selectPreset(at: 0, transition: 0)
        }
    }

    func nextPreset() {
        guard presets.count > 1 else { return }

        presetHistory.append(currentPresetIndex)

        let next: Int
        if isRandomize {
            repeat {
                next = Int.random(in: 0..<presets.count)
            } while next == currentPresetIndex && presets.count > 1
        } else {
            next = (currentPresetIndex + 1) % presets.count
        }

        selectPreset(at: next)
    }

    func previousPreset() {
        guard let previous = presetHistory.popLast() else { return }
        selectPreset(at: previous)
    }

    func selectPreset(at index: Int, transition: Double? = nil) {
        guard index >= 0, index < presets.count else { return }
        currentPresetIndex = index

        let js = "window.macampButterchurn.loadPreset(\(index), \(transition ?? transitionDuration));"
        bridge?.webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func startCycling() {
        guard isCycling else { return }
        stopCycling()

        cycleTimer = Timer.scheduledTimer(withTimeInterval: cycleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.nextPreset()
            }
        }
    }

    func stopCycling() {
        cycleTimer?.invalidate()
        cycleTimer = nil
    }
}
```

### 4.2 AppSettings Additions

```swift
// MacAmpApp/Models/AppSettings.swift additions

// Load in init
butterchurnRandomize = UserDefaults.standard.bool(forKey: "butterchurnRandomize")
butterchurnCycling = UserDefaults.standard.object(forKey: "butterchurnCycling") as? Bool ?? true
butterchurnCycleInterval = UserDefaults.standard.double(forKey: "butterchurnCycleInterval")
if butterchurnCycleInterval == 0 { butterchurnCycleInterval = 15.0 }

// Properties with persistence
var butterchurnRandomize: Bool = true {
    didSet { UserDefaults.standard.set(butterchurnRandomize, forKey: "butterchurnRandomize") }
}

var butterchurnCycling: Bool = true {
    didSet { UserDefaults.standard.set(butterchurnCycling, forKey: "butterchurnCycling") }
}

var butterchurnCycleInterval: Double = 15.0 {
    didSet { UserDefaults.standard.set(butterchurnCycleInterval, forKey: "butterchurnCycleInterval") }
}
```

**Success Criteria (Phase 4):**
- [ ] Preset list loads from JS
- [ ] Presets cycle every 15 seconds
- [ ] Random mode produces variety
- [ ] Previous/next navigation works with history
- [ ] Settings persist across restarts

---

## Phase 5: UI Integration & Commands

**Goal:** Wire Butterchurn into the Milkdrop window and controls.

**Commit scope:** Phase 5 complete when shortcuts work and track titles display.

### 5.1 Track Title Updates

```swift
// In PlaybackCoordinator or appropriate location
func onTrackChange(newTrack: Track) {
    butterchurnBridge?.showTrackTitle(newTrack.title)
}

// ButterchurnBridge addition
func showTrackTitle(_ title: String) {
    let escaped = title.replacingOccurrences(of: "'", with: "\\'")
    let js = "window.macampButterchurn.showTrackTitle('\(escaped)');"
    webView?.evaluateJavaScript(js, completionHandler: nil)
}
```

### 5.2 Keyboard Shortcuts

| Key | Action | Implementation |
|-----|--------|----------------|
| Space | Next preset | `presetManager.nextPreset()` |
| Backspace | Previous preset | `presetManager.previousPreset()` |
| R | Toggle random | `presetManager.isRandomize.toggle()` |
| T | Show track title | `bridge.showTrackTitle(currentTrack.title)` |

### 5.3 Window Lifecycle

```swift
// Pause when window hidden
.onReceive(NotificationCenter.default.publisher(for: NSWindow.didMiniaturizeNotification)) { _ in
    butterchurnBridge?.pauseRendering()
}

// Resume when shown
.onReceive(NotificationCenter.default.publisher(for: NSWindow.didDeminiaturizeNotification)) { _ in
    butterchurnBridge?.resumeRendering()
}
```

**Success Criteria (Phase 5):**
- [ ] Track titles appear on track change
- [ ] All keyboard shortcuts work
- [ ] Rendering pauses when window minimized
- [ ] Rendering resumes when window restored

---

## Phase 6: Verification (Dual-Backend Constraints)

**Goal:** Validate local-only Butterchurn behavior without breaking stream playback.

**Commit scope:** Phase 6 complete when all tests pass.

### Manual Test Matrix

| Scenario | Expected |
|----------|----------|
| Local file → Play | Butterchurn visualizes |
| Stream → Play | Fallback UI (no visualization) |
| Local → Stream switch | Visualization stops cleanly |
| Stream → Local switch | Visualization resumes |
| Preset cycle 5+ min | No memory leaks |
| Window hide/show | Rendering pauses/resumes |
| App restart | Settings preserved |

### Build Verification

```bash
# Thread Sanitizer build
xcodebuild -scheme MacAmp -configuration Debug -enableThreadSanitizer YES

# Run and verify no data race warnings
```

**Success Criteria (Phase 6):**
- [ ] No attempt to read PCM from streams
- [ ] Single tap remains stable
- [ ] CPU < 15%, memory stable
- [ ] Thread Sanitizer clean
- [ ] All manual tests pass

---

## Files Summary

### New Files (4)

| File | Layer | Lines (Est) |
|------|-------|-------------|
| `Views/Windows/ButterchurnWebView.swift` | Presentation | ~80 |
| `ViewModels/ButterchurnBridge.swift` | Bridge | ~100 |
| `ViewModels/ButterchurnPresetManager.swift` | Bridge | ~120 |
| `Butterchurn/bridge.js` | N/A (JS) | ~100 |

### Modified Files (4)

| File | Layer | Changes |
|------|-------|---------|
| `Audio/AudioPlayer.swift` | Mechanism | Add Butterchurn FFT in tap |
| `Models/AppSettings.swift` | Mechanism | Add Butterchurn settings |
| `Views/WinampMilkdropWindow.swift` | Presentation | Embed ButterchurnWebView |
| `Butterchurn/index.html` | N/A | Simplify for injection |

---

## Future Stream Support Design

When implementing system audio capture:

```swift
/// Protocol for Butterchurn audio sources
protocol ButterchurnAudioSource {
    var isActive: Bool { get }
    func snapshotButterchurnFrame() -> ButterchurnFrame?
}

// AudioPlayer conforms (already)
extension AudioPlayer: ButterchurnAudioSource { }

// Future implementation
class SystemAudioCapture: ButterchurnAudioSource {
    // Use virtual audio device or AudioUnit
}
```

Bridge will depend only on protocol, allowing seamless switch to system capture.

---

## Rollback Plan

If injection or rendering fails:

1. **Fallback A:** Inline all JavaScript in HTML (~470KB embedded)
2. **Fallback B:** Serve via `WKURLSchemeHandler`
3. **Fallback C:** Keep placeholder window, defer to native Metal later

Each phase produces a testable milestone - can stop at any phase with partial functionality.
