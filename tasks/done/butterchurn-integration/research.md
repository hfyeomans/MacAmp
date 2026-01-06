# Butterchurn Integration - Research

**Task ID:** butterchurn-integration
**Created:** 2026-01-05
**Objective:** Integrate Butterchurn visualization engine into MacAmp's Milkdrop window

---

## Executive Summary

Butterchurn is a JavaScript/WebGL port of Milkdrop 2 visualizer. MacAmp has the Milkdrop window chrome fully implemented, but the actual visualization engine is blocked by WKWebView's inability to load external JavaScript files from local bundles.

---

## Current Implementation Status

### What's Complete (Production Ready)

| Component | Status | Files |
|-----------|--------|-------|
| Milkdrop window chrome | ✅ Complete | MilkdropWindowChromeView.swift |
| GEN.bmp sprite rendering | ✅ Complete | SkinSprites.swift |
| "MILKDROP HD" titlebar letters | ✅ Complete | Two-piece sprite pattern |
| Window controller | ✅ Complete | WinampMilkdropWindowController.swift |
| Magnetic docking | ✅ Complete | WindowSnapManager integration |
| Focus state tracking | ✅ Complete | Active/inactive titlebar |
| Position persistence | ✅ Complete | UserDefaults via WindowFrameStore |
| Keyboard shortcut | ✅ Complete | Ctrl+K toggle |

### What's Blocked/Deferred

| Component | Status | Blocker |
|-----------|--------|---------|
| Butterchurn visualization | ❌ Blocked | WKWebView file:// restriction |
| Preset management | ❌ Not started | Depends on Butterchurn |
| Audio data bridge | ❌ Not started | Depends on Butterchurn |

---

## WKWebView Blocker Analysis

### The Problem

WKWebView cannot load external JavaScript files from the local app bundle:

```html
<!-- These ALL fail silently -->
<script src="butterchurn.min.js"></script>
<script src="butterchurnPresets.min.js"></script>
<script src="bridge.js"></script>

<!-- This works -->
<script>console.log("inline JS works")</script>
```

### Evidence (from BUTTERCHURN_BLOCKERS.md, Nov 14)

- Dark green background renders (HTML loads) ✅
- Inline JavaScript executes ("JavaScript: Running ✓") ✅
- External scripts fail (`butterchurn` global is undefined) ❌
- This is NOT a CSP issue - it's a macOS security restriction
- JIT entitlements enabled but don't help

### Attempted Solutions (All Failed)

1. JIT entitlements (`com.apple.security.cs.allow-jit: true`)
2. Unsigned executable memory entitlements
3. Content-Security-Policy meta tag relaxation
4. Multiple file search paths
5. Both individual files (yellow groups) and folder reference (blue folder) in Xcode

---

## Butterchurn Assets in Bundle

Files already exist at `/Users/hank/dev/src/MacAmp/Butterchurn/`:

| File | Size | Purpose |
|------|------|---------|
| butterchurn.min.js | 238 KB | Main Butterchurn library |
| butterchurnPresets.min.js | 230 KB | Preset data (hundreds of presets) |
| bridge.js | 4 KB | Swift ↔ JavaScript communication |
| index.html | 3 KB | Full HTML with debug overlay |
| test.html | 440 B | Minimal test (red background) |

---

## Webamp Butterchurn Integration (Reference Implementation)

### Audio Data Flow

```
Source → Preamp (Gain) → EQ Filters (10 bands) → Balance Node
                                                      ↓
                                    ├─→ Analyser Node (2048 FFT) → Butterchurn
                                    ↓
                                 Gain Node → Destination (Speakers)
```

### AnalyserNode Configuration

```javascript
// Required settings for Butterchurn
const analyser = audioContext.createAnalyser()
analyser.fftSize = 2048              // 1024 frequency bins
analyser.smoothingTimeConstant = 0.0  // No smoothing (responsive)
```

### Butterchurn JavaScript API

```typescript
// Create visualizer instance
const visualizer = butterchurn.createVisualizer(
  audioContext: AudioContext,
  canvas: HTMLCanvasElement,
  options: {
    width: number,
    height: number,
    meshWidth?: number,    // Default: 32
    meshHeight?: number,   // Default: 24
    pixelRatio?: number,   // Device pixel ratio
    onlyUseWASM?: boolean  // Security: true recommended
  }
)

// Connect audio source
visualizer.connectAudio(analyserNode: AnalyserNode)

// Load preset with transition
visualizer.loadPreset(presetObject, transitionTimeSeconds)

// Render frame (call in animation loop)
visualizer.render()

// Resize canvas
visualizer.setRendererSize(width, height)

// Show song title overlay
visualizer.launchSongTitleAnim(title)
```

### Preset System

**Preset Types:**
- Bundled presets (butterchurn-presets package)
- Remote JSON presets (fetch from URL)
- Lazy-loaded presets (Promise-based)
- Converted .milk files (via AWS converter endpoint)

**Transition Durations:**
- DEFAULT: 2.7 seconds
- USER_PRESET: 5.7 seconds
- IMMEDIATE: 0 seconds

**Auto-cycling:**
- Cycles every 15 seconds during playback
- Random order by default
- Toggle via hotkeys (R, Scroll Lock)

### Hotkeys (Webamp Reference)

| Key | Action |
|-----|--------|
| Space | Next preset |
| Backspace | Previous preset |
| H | Next preset (immediate) |
| R | Toggle random |
| L | Show/hide preset list |
| T | Show track title |
| Double-click | Toggle fullscreen |

---

## Proposed Solutions

### Option A: Bundle Injection (RECOMMENDED - Fastest)

Load JavaScript files as Swift strings and inject via `evaluateJavaScript()`:

```swift
// Load JS files as strings from bundle
guard let butterchurnURL = Bundle.main.url(forResource: "butterchurn.min", withExtension: "js"),
      let butterchurnJS = try? String(contentsOf: butterchurnURL) else {
    return
}

// Inject before HTML loads or via userContentController
webView.evaluateJavaScript(butterchurnJS) { result, error in
    // Then inject presets and bridge
}
```

**Pros:**
- Uses existing assets
- Minimal code changes
- Works around WKWebView restriction

**Cons:**
- Large string injection (470KB total)
- Must inject in correct order (butterchurn → presets → bridge)
- Timing-sensitive

**Estimated Effort:** 2-4 hours

### Option B: WKUserScript Injection (Variation of A)

Use WKUserContentController to inject at document start:

```swift
let config = WKWebViewConfiguration()
let userContentController = WKUserContentController()

// Inject at document start
let butterchurnScript = WKUserScript(
    source: butterchurnJS,
    injectionTime: .atDocumentStart,
    forMainFrameOnly: true
)
userContentController.addUserScript(butterchurnScript)

config.userContentController = userContentController
let webView = WKWebView(frame: .zero, configuration: config)
```

**Pros:**
- Cleaner than evaluateJavaScript timing
- Scripts ready before HTML parses
- One-time setup

**Estimated Effort:** 3-5 hours

### Option C: Native Metal Renderer (Long-term)

Port Butterchurn's WebGL rendering to Metal:

**Pros:**
- Best performance
- No JavaScript/WebView overhead
- Full native integration

**Cons:**
- Substantial effort (weeks)
- Need to port GLSL shaders to Metal
- Preset format conversion needed

**Estimated Effort:** 2-4 weeks

### Option D: projectM C++ Library

Use projectM (native Milkdrop implementation):

**Pros:**
- C++ library, Objective-C++ bridge possible
- Reads original .milk presets
- Good performance

**Cons:**
- Different codebase to learn
- Objective-C++ complexity
- May have rendering differences from Butterchurn

**Estimated Effort:** 1-2 weeks

---

## Audio Bridge Architecture

### MacAmp's Existing Audio Pipeline

```
AVAudioEngine
  ├─ AVAudioPlayerNode (playback source)
  ├─ AVAudioUnitEQ (10-band Winamp EQ)
  └─ MainMixerNode (output)
        └─ Audio Tap (spectrum analyzer)
             └─ currentSpectrum [Float] (19 bars)
             └─ currentWaveform [Float] (1024 samples)
```

### Bridge Requirements for Butterchurn

1. **Frequency Data:** 1024 bins (from 2048 FFT)
2. **Waveform Data:** 1024 samples
3. **Update Rate:** 60 FPS (requestAnimationFrame equivalent)
4. **Format:** Byte array (0-255) or Float32 (-1.0 to 1.0)

### Swift → JavaScript Communication

The existing `bridge.js` provides:

```javascript
// Called from Swift with audio data
window.updateAudioData = function(frequencyData, waveformData) {
    if (window.butterchurnVisualizer) {
        // Butterchurn reads from analyser automatically
        // but we may need to provide data manually
    }
}

// Called from Swift for track info
window.showTrackTitle = function(title) {
    visualizer.launchSongTitleAnim(title)
}

// Called from Swift for preset changes
window.loadPreset = function(presetIndex) {
    visualizer.loadPreset(presets[presetIndex], 2.7)
}
```

### JavaScript → Swift Communication

```javascript
// Send messages back to Swift
window.webkit.messageHandlers.butterchurn.postMessage({
    type: 'ready',
    presetCount: presets.length
})

window.webkit.messageHandlers.butterchurn.postMessage({
    type: 'presetChanged',
    index: currentPresetIndex,
    name: currentPresetName
})
```

---

## Window Dimensions

The Milkdrop window uses GEN.bmp chrome (same as Video window):

| Dimension | Value | Notes |
|-----------|-------|-------|
| Window width | 275px | Fixed (not resizable initially) |
| Window height | 232px | Fixed (standard VIDEO size) |
| Titlebar | 20px | GEN.bmp sprites |
| Left border | 11px | GEN_MIDDLE_LEFT |
| Right border | 8px | GEN_MIDDLE_RIGHT |
| Bottom bar | 14px | GEN_BOTTOM_* |
| **Content area** | **256×198px** | Available for visualization |

---

## Files to Create/Modify

### New Files

| File | Purpose |
|------|---------|
| ButterchurnWebView.swift | WKWebView wrapper with injection |
| ButterchurnBridge.swift | Swift side of JS bridge |
| ButterchurnPresetManager.swift | Preset loading and cycling |

### Modify Existing

| File | Changes |
|------|---------|
| WinampMilkdropWindow.swift | Replace placeholder with ButterchurnWebView |
| AudioPlayer.swift | Add higher-resolution FFT tap for Butterchurn |
| AppSettings.swift | Add Butterchurn preferences (randomize, cycle) |

---

## References

### Documentation

- `docs/MILKDROP_WINDOW.md` - Full window specification
- `docs/MACAMP_ARCHITECTURE_GUIDE.md` - Audio pipeline, Section 8.4
- `tasks/milk-drop-video-support/BUTTERCHURN_BLOCKERS.md` - WKWebView blocker details

### External

- Butterchurn: https://github.com/jberg/butterchurn
- Webamp: https://github.com/captbaritone/webamp
- projectM: https://github.com/projectM-visualizer/projectm

---

## Recommendation

**Start with Option B (WKUserScript Injection):**

1. Fastest path to working visualization
2. Uses existing assets
3. Proven pattern in iOS/macOS apps
4. Can iterate to native Metal later if needed

---

## Oracle Review Findings (2026-01-05)

### Critical Architecture Constraints

#### AVAudioEngine Tap Limitation
**AVAudioEngine allows only ONE tap per bus.** Adding a separate Butterchurn tap would replace or break the existing 19-bar analyzer.

**Solution:** Merge Butterchurn processing into the existing visualizer tap. Compute both 19-bar and 2048-FFT data in the same buffer pass.

#### Stream Playback Has No PCM Data
`StreamPlayer` (AVPlayer) provides no raw PCM access. Butterchurn visualization is **impossible** for internet radio streams without system-level audio capture.

**Solution:** Scope Butterchurn to local playback only initially. Design for future `SystemAudioCapture` via a protocol abstraction.

### Script Injection Timing

**Race condition risk:** `WKUserScript` at `.atDocumentStart` with bridge code that touches DOM elements can race the HTML parser.

**Solution:**
- Inject `butterchurn.min.js` at `.atDocumentStart`
- Inject `butterchurnPresets.min.js` at `.atDocumentStart`
- Inject `bridge.js` at `.atDocumentEnd` (or gate on `DOMContentLoaded`)

### Preset API Correction

**Incorrect assumption:** Plan assumed a global `presets` array.

**Correct API:** Use `butterchurnPresets.getPresets()` to retrieve preset list.

### Performance Architecture

**Problem:** 60 FPS `evaluateJavaScript()` with two 1024-element arrays creates significant overhead.

**Solution:** Hybrid 30/60 FPS approach:
- Swift → JS: Push audio data at **30 FPS**
- JS render loop: `requestAnimationFrame` at **60 FPS**
- JS pulls from last-known buffer, reducing Swift→JS call frequency by 50%

### Memory Management Requirements

1. **WKScriptMessageHandler cleanup:** `WKUserContentController` retains handlers. Must call `removeScriptMessageHandler` in `dismantleNSView`.
2. **Timer cleanup:** Stop all cycling/update timers when view tears down.
3. **Graceful fallback:** If JS injection fails, show placeholder UI instead of crash.

### Layer Placement (Three-Layer Pattern)

| Component | Layer | Location | Rationale |
|-----------|-------|----------|-----------|
| ButterchurnWebView | Presentation | Views/Windows/ | SwiftUI NSViewRepresentable |
| ButterchurnBridge | Bridge | ViewModels/ | Owns JS communication, UI-coupled |
| ButterchurnPresetManager | Bridge | ViewModels/ | Manages UI state (cycling, transitions) |
| Audio tap extension | Mechanism | Audio/ | Core audio processing |
| AppSettings additions | Mechanism | Models/ | Persistence only |

**Why preset manager is Bridge layer:** It's tightly coupled to the WebView/JS API, manages UI-driven state (cycling, randomization, transitions), and owns timers. Mechanism layer should remain focused on audio/persistence and be independent of visualization implementation.

### Pattern Corrections

| Incorrect | Correct |
|-----------|---------|
| `@Published var` | `var` (with `@Observable` class) |
| `class ButterchurnWebView: NSViewRepresentable` | `struct ButterchurnWebView: NSViewRepresentable` |
| Timer as property | `@ObservationIgnored` timer |
| AppSettings `didSet` only | Load from UserDefaults in `init` + `didSet` |

### Future Stream Support Design

Define `ButterchurnAudioSource` protocol in Mechanism layer:
```swift
protocol ButterchurnAudioSource {
    var isActive: Bool { get }
    func snapshotButterchurnFrame() -> ButterchurnFrame?
}
```

- `AudioPlayer` conforms immediately
- Future `SystemAudioCapture` (virtual device / AudioUnit) can conform later
- Bridge depends only on protocol, not concrete source

---

## Implementation Phases (Revised)

**Phase 1:** WebView + JS injection (static frame, no audio)
**Phase 2:** Audio tap merge (single tap, both FFT sizes)
**Phase 3:** Swift→JS bridge (30 FPS updates)
**Phase 4:** Preset manager (cycling, randomization, persistence)
**Phase 5:** UI integration (shortcuts, track titles, lifecycle)
**Phase 6:** Verification (local-only validation, stream fallback)

---

## Implementation Findings (2026-01-05)

### Critical Discovery: Butterchurn Requires Audio Graph Connection

**Original Assumption:** Phase 1 could render "static frames" without any audio data.

**Reality:** Butterchurn's `render()` method internally calls `this.analyser.getByteTimeDomainData()` and `this.analyser.getByteFrequencyData()` on every frame. Without an audio source connected to its internal AnalyserNode, the buffers are empty/zeros and the canvas renders blank.

**Root Cause Chain:**
1. `butterchurn.createVisualizer(audioContext, canvas, options)` creates an internal `AnalyserNode`
2. `render()` reads audio data from this internal analyser every frame
3. If nothing is connected to the analyser, it reads zeros → blank visualization
4. Even for "static" time-based preset animations, the audio graph must be wired

**Solution:** Use `visualizer.connectAudio(audioSourceNode)` to connect an audio source to butterchurn's internal analyser. For Phase 1 (no real audio), connect a silent oscillator:

```javascript
var audioContext = new AudioContext();
var oscillator = audioContext.createOscillator();
oscillator.frequency.value = 0;  // Silent
var gainNode = audioContext.createGain();
gainNode.gain.value = 0;  // Muted
oscillator.connect(gainNode);
oscillator.start();

visualizer = butterchurn.createVisualizer(audioContext, canvas, options);
visualizer.connectAudio(gainNode);  // CRITICAL: Connect to butterchurn's analyser
```

**Lesson Learned:** Butterchurn is not a "render preset to canvas" library - it's an audio-reactive visualization engine that requires a connected audio graph even for basic rendering. The plan's Phase 1 "no audio" scope was correct in intent (no real music data), but incorrect in implementation (still needs audio graph wiring).

### ES Module vs UMD Bundle Differences

**Problem:** butterchurn.min.js uses ES module syntax (`export{qt as default}`) which doesn't work with WKUserScript injection.

**Solution:** Regex replacement to convert ES module export to window global:
```swift
// Convert: export{qt as default}
// To: window.butterchurn = qt;
```

**Problem:** butterchurnPresets.min.js UMD bundle exports differently than ES module:
- ES Module: `butterchurnPresets.getPresets()` returns preset map
- UMD Bundle: `window.minimal.default` contains preset map directly (no `getPresets()` method)

**Solution:** Handle both patterns in bridge.js:
```javascript
if (typeof butterchurnPresets.getPresets === 'function') {
    presets = butterchurnPresets.getPresets();  // ES module
} else if (butterchurnPresets.default) {
    presets = butterchurnPresets.default;  // UMD bundle
}
```

### WebGL Context Verification

Always verify WebGL availability before creating visualizer:
```javascript
var gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
if (!gl) {
    showFallback('WebGL not available');
    return;
}
```

### Canvas Sizing for WKWebView

CSS `width: 100%; height: 100%` is not sufficient. Must also set:
```css
html, body { width: 100%; height: 100%; }
canvas { position: absolute; top: 0; left: 0; }
```

And verify pixel dimensions in JS:
```javascript
canvas.width = canvas.clientWidth || 256;
canvas.height = canvas.clientHeight || 198;
```

---

## Oracle A-Grade Fixes (2026-01-05)

After initial implementation, Oracle (Codex gpt-5.2-codex with high reasoning) reviewed the code and identified improvements to upgrade from Grade B+ to Grade A.

### Fix 1: Centralized Failure Handling (Critical)

**Problem:** Load failures didn't stop the audio update timer, causing zombie updates to a dead WebView.

**Solution:** Added `markLoadFailed(_ message: String)` helper method that:
- Sets `isReady = false`
- Clears state (presetCount, presetNames)
- **Stops audio update task**
- Logs error

```swift
func markLoadFailed(_ message: String) {
    isReady = false
    errorMessage = message
    presetCount = 0
    presetNames = []
    stopAudioUpdates()  // CRITICAL: Stop timer on failure
    AppLog.error(.general, "[ButterchurnBridge] Load failed: \(message)")
}
```

**Lesson:** Always pair "start" operations with corresponding "stop" in error paths.

### Fix 2: Guard Both `isReady` and `webView` (Critical)

**Problem:** `sendAudioFrame()` only checked `webView != nil`, not `isReady`. Could send JS calls to failed/dead WebView.

**Solution:** Combined guard:
```swift
// Before
guard let webView = webView else { return }

// After
guard isReady, let webView = webView else { return }
```

**Lesson:** Guard all preconditions, not just the obvious one.

### Fix 3: WKNavigationDelegate for WebView Errors (Critical)

**Problem:** WebView load failures (network, process termination) went undetected. Bridge thought WebView was healthy.

**Solution:** Made Coordinator conform to WKNavigationDelegate:
```swift
class Coordinator: NSObject, WKNavigationDelegate {
    weak var bridge: ButterchurnBridge?

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        bridge?.markLoadFailed("WebView navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        bridge?.markLoadFailed("WebView provisional navigation failed: \(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        bridge?.markLoadFailed("WebView content process terminated")
    }
}
```

**Lesson:** Always monitor external process health (WebView, audio engine, etc.).

### Fix 4: callAsyncJavaScript with Typed Arguments (Important)

**Problem:** Per-frame string interpolation overhead:
```swift
// Bad: String interpolation every frame (30 FPS = 30 string builds/sec)
let js = "window.macampButterchurn?.setAudioData(\(spectrumInts), \(frame.waveform));"
webView.evaluateJavaScript(js, completionHandler: nil)
```

**Solution:** Use typed arguments via `callAsyncJavaScript`:
```swift
// Good: Typed arguments, no string building
webView.callAsyncJavaScript(
    "window.macampButterchurn?.setAudioData(spectrum, waveform);",
    arguments: ["spectrum": spectrumInts, "waveform": frame.waveform],
    in: nil,
    contentWorld: .page,
    completionHandler: nil
)
```

**Lesson:** Avoid string interpolation in hot paths. Use typed APIs when available.

### Fix 5: Async Task Loop Instead of Timer+Task (Nice-to-have)

**Problem:** Timer + Task hop pattern creates timing jitter and harder cancellation:
```swift
// Timer fires → creates Task → Task awaits MainActor → executes
updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
    Task { @MainActor in
        self?.sendAudioFrame()
    }
}
```

**Solution:** Pure async Task loop with clean cancellation:
```swift
audioUpdateTask = Task { [weak self] in
    while !Task.isCancelled {
        await self?.sendAudioFrame()
        try? await Task.sleep(nanoseconds: 33_333_333)  // ~30 FPS
    }
}
```

**Benefits:**
- Cleaner cancellation (`task.cancel()` vs `timer.invalidate()`)
- No Timer→Task hop (less jitter)
- Respects structured concurrency

### Fix 6: Swift 6 Strict Concurrency (MainActor.assumeIsolated)

**Problem:** `WKScriptMessageHandler.userContentController(_:didReceive:)` is `nonisolated`, but the class is `@MainActor`. Accessing `message.body` triggered Swift 6 error:
```
Main actor-isolated property 'body' can not be referenced from a nonisolated context
```

**Solution:** Use `MainActor.assumeIsolated` since WebKit guarantees main thread:
```swift
nonisolated func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
) {
    // WebKit guarantees this delegate is called on main thread
    MainActor.assumeIsolated {
        // Safe to access message.body and self.handleMessage here
        guard let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else { ... }
        self.handleMessage(...)
    }
}
```

**Lesson:** Use `MainActor.assumeIsolated` for delegate methods that are guaranteed to be called on main thread but protocol requires `nonisolated`.

### Linker Warning (Non-Issue)

**Warning:** `Duplicate -rpath '@executable_path' ignored`

**Cause:** `LD_RUNPATH_SEARCH_PATHS` contains same entry at project and target level.

**Impact:** None. Linker ignores duplicates.

**Fix:** Deduplicate in Xcode Build Settings (optional cleanup).

---

## Architecture Lessons Learned

1. **Failure States Must Cascade:** When component A fails, stop all dependent components (B, C, D)
2. **Guard All Preconditions:** Check both state (`isReady`) and resources (`webView != nil`)
3. **Monitor External Processes:** WebView, audio engine, network can fail independently
4. **Hot Path Optimization:** Avoid allocations/string-building in per-frame code
5. **Swift 6 Actor Boundaries:** Use `MainActor.assumeIsolated` when caller guarantees main thread
6. **Structured Concurrency:** Prefer async Task loops over Timer+Task patterns
