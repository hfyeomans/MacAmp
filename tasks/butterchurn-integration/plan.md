# Butterchurn Integration - Implementation Plan

**Task ID:** butterchurn-integration
**Created:** 2026-01-05
**Approach:** WKUserScript Injection (Option B)

---

## Overview

Integrate Butterchurn visualization engine into the existing Milkdrop window using WKUserScript injection to work around WKWebView's file:// URL restriction.

---

## Phase 1: WebView Setup (Foundation)

**Goal:** Get Butterchurn loading and rendering a static visualization

### 1.1 Create ButterchurnWebView.swift

```swift
// WKWebView wrapper with script injection
@MainActor
class ButterchurnWebView: NSViewRepresentable {
    // WKWebViewConfiguration with userScripts
    // Load butterchurn.min.js, butterchurnPresets.min.js, bridge.js as WKUserScript
    // Inject at .atDocumentStart
}
```

**Files:**
- Create: `MacAmpApp/Views/Windows/ButterchurnWebView.swift`

### 1.2 Prepare Minimal HTML

Modify `index.html` to NOT use `<script src>` - rely on injected scripts:

```html
<!DOCTYPE html>
<html>
<head>
    <style>
        body { margin: 0; background: #000; overflow: hidden; }
        canvas { display: block; }
    </style>
</head>
<body>
    <canvas id="canvas"></canvas>
    <script>
        // Initialize after injected scripts are ready
        window.addEventListener('butterchurnReady', function() {
            initVisualization();
        });
    </script>
</body>
</html>
```

**Files:**
- Modify: `Butterchurn/index.html`

### 1.3 Test Injection

1. Load WKWebView with modified HTML
2. Verify `butterchurn` global exists
3. Verify presets load
4. Render static frame (no audio)

**Success Criteria:**
- [ ] Butterchurn library loads without errors
- [ ] Presets array populated
- [ ] Static visualization renders in canvas

---

## Phase 2: Audio Bridge (Core Functionality)

**Goal:** Feed real audio data to Butterchurn

### 2.1 Upgrade Audio Tap

Modify AudioPlayer to provide higher-resolution FFT data:

```swift
// AudioPlayer.swift additions
@Published var butterchurnSpectrum: [Float] = Array(repeating: 0, count: 1024)
@Published var butterchurnWaveform: [Float] = Array(repeating: 0, count: 1024)

private func setupButterchurnTap() {
    // 2048 FFT size for 1024 frequency bins
    // Separate tap from existing 19-bar analyzer
    // Update at 60 FPS
}
```

**Files:**
- Modify: `MacAmpApp/Audio/AudioPlayer.swift`

### 2.2 Create ButterchurnBridge.swift

Swift side of JavaScript communication:

```swift
@MainActor
class ButterchurnBridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?

    func sendAudioData(spectrum: [Float], waveform: [Float]) {
        let js = "window.updateAudioData(\(spectrum), \(waveform))"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        // Handle messages from JavaScript
    }
}
```

**Files:**
- Create: `MacAmpApp/Views/Windows/ButterchurnBridge.swift`

### 2.3 Update bridge.js

Add audio data receiver:

```javascript
window.updateAudioData = function(spectrum, waveform) {
    if (window.audioAnalyser) {
        // Copy data into analyser's buffers
        // Butterchurn reads from analyser.getByteFrequencyData()
    }
};
```

**Files:**
- Modify: `Butterchurn/bridge.js`

### 2.4 Connect Pipeline

```
AudioPlayer.butterchurnSpectrum
    ↓ (Timer 60 FPS)
ButterchurnBridge.sendAudioData()
    ↓ (evaluateJavaScript)
window.updateAudioData()
    ↓ (buffer copy)
AnalyserNode → Butterchurn.render()
```

**Success Criteria:**
- [ ] Visualization responds to music
- [ ] Bass hits cause visual reactions
- [ ] No audio/visual lag perceptible

---

## Phase 3: Preset Management

**Goal:** Implement preset cycling and selection

### 3.1 Create ButterchurnPresetManager.swift

```swift
@MainActor
@Observable
class ButterchurnPresetManager {
    var presets: [String] = []           // Preset names
    var currentPresetIndex: Int = 0
    var isRandomize: Bool = true
    var isCycling: Bool = true
    var cycleInterval: TimeInterval = 15.0

    private var presetHistory: [Int] = []
    private var cycleTimer: Timer?

    func nextPreset() { }
    func previousPreset() { }
    func selectPreset(at index: Int) { }
    func startCycling() { }
    func stopCycling() { }
}
```

**Files:**
- Create: `MacAmpApp/Models/ButterchurnPresetManager.swift`

### 3.2 Add Preset Commands to bridge.js

```javascript
window.loadPresetAtIndex = function(index, transition) {
    const preset = presets[index];
    visualizer.loadPreset(preset, transition);
};

window.getPresetNames = function() {
    return presets.map(p => p.name);
};
```

### 3.3 Wire Preset Cycling

- Timer fires every 15 seconds
- Select random (or sequential) preset
- Call bridge to load preset
- Track history for "previous" function

**Success Criteria:**
- [ ] Presets cycle automatically
- [ ] Random mode works
- [ ] Previous/next navigation works
- [ ] Preset names displayed (optional overlay)

---

## Phase 4: Integration & Polish

**Goal:** Full integration with MacAmp UI

### 4.1 Replace Placeholder in WinampMilkdropWindow

```swift
struct WinampMilkdropWindow: View {
    var body: some View {
        MilkdropWindowChromeView {
            ButterchurnWebView()  // Replace Text placeholder
        }
    }
}
```

**Files:**
- Modify: `MacAmpApp/Views/WinampMilkdropWindow.swift`

### 4.2 Add Track Title Display

When track changes:
```swift
butterchurnBridge.showTrackTitle(track.title)
```

JavaScript:
```javascript
window.showTrackTitle = function(title) {
    visualizer.launchSongTitleAnim(title);
};
```

### 4.3 Add Keyboard Shortcuts

| Key | Action | Implementation |
|-----|--------|----------------|
| Space | Next preset | presetManager.nextPreset() |
| Backspace | Previous preset | presetManager.previousPreset() |
| R | Toggle random | presetManager.isRandomize.toggle() |
| T | Show track title | bridge.showTrackTitle() |

### 4.4 Add AppSettings Persistence

```swift
// AppSettings.swift additions
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

**Files:**
- Modify: `MacAmpApp/Models/AppSettings.swift`

### 4.5 Handle Window Lifecycle

- Pause rendering when window hidden
- Resume when window shown
- Clean up WebView on window close

**Success Criteria:**
- [ ] Track titles show on track change
- [ ] Keyboard shortcuts work
- [ ] Settings persist across restarts
- [ ] No memory leaks on window close

---

## Phase 5: Testing & Validation

### 5.1 Thread Sanitizer Build

```bash
xcodebuild -scheme MacAmp -configuration Debug -enableThreadSanitizer YES
```

### 5.2 Manual Testing Checklist

- [ ] Butterchurn loads on first launch
- [ ] Visualization responds to all audio sources (local files, radio)
- [ ] Presets cycle correctly
- [ ] Random mode produces variety
- [ ] Previous/next work with history
- [ ] Track title shows on change
- [ ] Window focus states work
- [ ] Position persists across restarts
- [ ] No memory growth over time
- [ ] Performance acceptable (60 FPS target)

### 5.3 Oracle Code Review

```bash
codex "@ButterchurnWebView.swift @ButterchurnBridge.swift @ButterchurnPresetManager.swift
Review Butterchurn integration for:
- Thread safety
- Memory management
- WKWebView best practices
- Audio timing considerations"
```

---

## File Summary

### New Files (4)

| File | Lines (Est) | Phase |
|------|-------------|-------|
| ButterchurnWebView.swift | ~120 | Phase 1 |
| ButterchurnBridge.swift | ~80 | Phase 2 |
| ButterchurnPresetManager.swift | ~100 | Phase 3 |
| Butterchurn/index.html (modified) | ~50 | Phase 1 |

### Modified Files (5)

| File | Changes | Phase |
|------|---------|-------|
| Butterchurn/index.html | Remove script src, use injected | Phase 1 |
| Butterchurn/bridge.js | Add audio receiver | Phase 2 |
| AudioPlayer.swift | Add butterchurn FFT tap | Phase 2 |
| WinampMilkdropWindow.swift | Use ButterchurnWebView | Phase 4 |
| AppSettings.swift | Add Butterchurn prefs | Phase 4 |

---

## Rollback Plan

If injection approach fails:

1. **Fallback A:** Inline all JavaScript in HTML (embed ~470KB as strings)
2. **Fallback B:** Serve files via local WKURLSchemeHandler
3. **Fallback C:** Native Metal visualizer (long-term)

Each phase is independently testable - can stop at any phase with partial functionality.

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Frame rate | 60 FPS |
| Audio latency | < 50ms |
| Memory usage | < 100 MB |
| CPU usage | < 15% |
| Preset transition | Smooth 2.7s blend |
