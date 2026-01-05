# Butterchurn Integration - State

**Task ID:** butterchurn-integration
**Created:** 2026-01-05
**Revised:** 2026-01-05 (Oracle Review)
**Last Updated:** 2026-01-05

---

## Current State

**Phase:** ✅ PHASE 3 COMPLETE - Swift→JS Bridge Working

**Oracle Review:** ✅ Complete (2026-01-05) - 2 Oracle debugging sessions with gpt-5.2-codex

### Implementation Progress (2026-01-05)

**Completed:**
1. ✅ Created ButterchurnBridge.swift (WKScriptMessageHandler)
2. ✅ Created ButterchurnWebView.swift (NSViewRepresentable)
3. ✅ Rewrote bridge.js for new architecture
4. ✅ Simplified index.html (no script tags)
5. ✅ Added Butterchurn folder to Xcode project resources
6. ✅ Fixed chicken-and-egg bug (WebView must exist to send 'ready')
7. ✅ Fixed ES module export issue (butterchurn.min.js uses `export{qt as default}`)
8. ✅ Fixed butterchurnPresets alias (exports as 'minimal' → aliased to 'butterchurnPresets')

**Bugs Fixed:**
1. ✅ butterchurn.min.js uses ES module export which doesn't work with WKUserScript
   - Added `wrapESModuleAsGlobal()` to convert `export{qt as default}` → `window.butterchurn = qt`

2. ✅ butterchurnPresets.min.js exports as `window.minimal` → added alias to `window.butterchurnPresets`

3. ✅ **ROOT CAUSE FIXED (Oracle confirmed):** `butterchurnPresets.getPresets()` doesn't exist in UMD bundle
   - UMD exports `{default: {presetName: preset}}` structure, not ES module with getPresets()
   - Fixed bridge.js to handle both ES module and UMD patterns:
     - Try `butterchurnPresets.getPresets()` first (ES module)
     - Fall back to `butterchurnPresets.default` (UMD bundle)
     - Fall back to direct object if already unwrapped
4. ✅ Butterchurn visualizer was not receiving audio input from bridge
   - Added `visualizer.connectAudio(audioSourceNode)` after createVisualizer
   - Removed custom analyser connection in bridge.js to rely on butterchurn internal analyser

**Testing:** Awaiting build and test to verify visualization loads

### Debug Logging Status: ✅ CLEANED (2026-01-05)

All debug logging has been removed. Only meaningful logs remain:
- `AppLog.info` for ready state confirmation
- `AppLog.error` for load failures
- `AppLog.warn` for invalid/unknown messages

**CSS fixes retained** in index.html (required for proper rendering):
- `html, body { width: 100%; height: 100%; }`
- `box-sizing: border-box` to all elements
- `position: absolute; top: 0; left: 0;` to canvas

---

## Key Decisions (Oracle Review)

| Decision | Choice | Impact |
|----------|--------|--------|
| Stream scope | Local playback only | No Butterchurn for streams until SystemAudioCapture |
| Update rate | 30 FPS Swift→JS | Better stability; JS render loop at 60 FPS |
| Preset manager layer | Bridge (ViewModels) | UI-coupled state, timer ownership |
| Audio tap strategy | Merge into existing | AVAudioEngine allows only one tap per bus |
| @Observable pattern | Plain `var`, `@ObservationIgnored` timers | Correct Swift 6 pattern |
| NSViewRepresentable | `struct` not `class` | SwiftUI best practice |

---

## Component Status

| Component | Status | Notes |
|-----------|--------|-------|
| Research | ✅ Complete | Oracle findings added |
| Plan | ✅ Revised | 6-phase plan with code examples |
| Todo | ✅ Revised | 85 checkboxes, phase-aligned |
| Milkdrop window chrome | ✅ Complete | GEN.bmp sprites, focus states |
| Butterchurn assets | ✅ Bundled | .js files in Butterchurn/ folder |
| WKWebView integration | ✅ Phase 1 | WKUserScript injection approach |
| Audio data bridge | ✅ Phase 2 | FFT merged into existing tap |
| Swift→JS bridge | ✅ Phase 3 | 30 FPS waveform push, pause/resume |
| Preset management | ⏳ Phase 4 | Cycling, randomize, history |
| UI integration | ⏳ Phase 5 | Shortcuts, track titles |
| Verification | ⏳ Phase 6 | Local-only validation |

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

## Critical Constraints (Oracle Identified)

### Audio Tap Limitation
- AVAudioEngine allows only **one tap per bus**
- Must merge Butterchurn FFT into existing 19-bar tap
- Do NOT add a second tap

### Stream Playback
- `StreamPlayer` (AVPlayer) provides **no PCM data**
- Butterchurn is local playback only for now
- Future: `ButterchurnAudioSource` protocol for SystemAudioCapture

### Script Injection Order
1. `butterchurn.min.js` at `.atDocumentStart`
2. `butterchurnPresets.min.js` at `.atDocumentStart`
3. `bridge.js` at `.atDocumentEnd` (after DOM ready)

### Memory Management
- Must call `removeScriptMessageHandler` in `dismantleNSView`
- Timers must be stopped on cleanup
- Use `@ObservationIgnored` for non-observable state

---

## Files Inventory

### Existing (Ready to Use)

| File | Location | Size |
|------|----------|------|
| butterchurn.min.js | Butterchurn/ | 238 KB |
| butterchurnPresets.min.js | Butterchurn/ | 230 KB |
| bridge.js | Butterchurn/ | 4 KB (to be rewritten) |
| index.html | Butterchurn/ | 3 KB (to be simplified) |

### Window Infrastructure (Complete)

| File | Lines | Status |
|------|-------|--------|
| WinampMilkdropWindow.swift | 31 | ✅ Placeholder view |
| WinampMilkdropWindowController.swift | 52 | ✅ NSWindowController |
| MilkdropWindowChromeView.swift | 162 | ✅ GEN.bmp chrome |

### Created (Phase 1)

| File | Layer | Lines | Status |
|------|-------|-------|--------|
| ButterchurnWebView.swift | Presentation | ~280 | ✅ Complete |
| ButterchurnBridge.swift | Bridge | ~100 | ✅ Complete |

### To Be Created (Phase 4+)

| File | Layer | Est. Lines |
|------|-------|------------|
| ButterchurnPresetManager.swift | Bridge | ~120 |

### To Be Modified

| File | Layer | Changes |
|------|-------|---------|
| AudioPlayer.swift | Mechanism | Add Butterchurn FFT in tap |
| AppSettings.swift | Mechanism | Add Butterchurn settings |
| WinampMilkdropWindow.swift | Presentation | Embed ButterchurnWebView |
| bridge.js | N/A | Rewrite for new architecture |
| index.html | N/A | Simplify for injection |

---

## Technical Specifications

| Spec | Value |
|------|-------|
| FFT Size | 2048 (1024 bins for Butterchurn) |
| Swift→JS Rate | 30 FPS |
| JS Render Rate | 60 FPS (requestAnimationFrame) |
| Window Size | 256×198px content area |
| Preset Transition | 2.7 seconds default |
| Auto-cycle Interval | 15 seconds |
| Total JS Injection | ~472 KB as strings |

---

## Branch Status

- **Current branch:** `feature/butterchurn-integration`
- **Base commit:** `0ff0089` (main)
- **Target:** main (after all 6 phases complete)

---

## Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| Milkdrop window chrome | ✅ Available | PR #36 merged |
| AudioPlayer visualizer tap | ✅ Available | Needs FFT merge |
| WKWebView | ✅ Available | macOS 15+ standard |
| WebKit framework | ✅ Available | Already linked |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Injection timing race | Medium | High | bridge.js at documentEnd |
| 30 FPS too slow | Low | Medium | Test and tune |
| Memory leaks | Medium | Medium | Cleanup in dismantleNSView |
| Tap merge breaks 19-bar | Low | High | Test existing analyzer |

---

## Session Log

| Date | Action | Result |
|------|--------|--------|
| 2026-01-05 | Research completed | 4 agents analyzed all sources |
| 2026-01-05 | Task files created | research.md, state.md, plan.md, todo.md |
| 2026-01-05 | Oracle review | 12 findings, all addressed in revised plan |
| 2026-01-05 | Plan revised | 6-phase architecture with Oracle corrections |
| 2026-01-05 | Phase 1 implementation | Created ButterchurnBridge.swift, ButterchurnWebView.swift |
| 2026-01-05 | Debug: ES module fix | wrapESModuleAsGlobal() for butterchurn.min.js |
| 2026-01-05 | Debug: UMD presets fix | getPresets() fallback to .default for UMD bundle |
| 2026-01-05 | Debug: Render error | analyser.getByteTimeDomainData undefined → need AudioContext |
| 2026-01-05 | Debug: AudioContext added | Silent oscillator + gainNode for audio graph |
| 2026-01-05 | Debug: Blank screen | Missing connectAudio() call - Oracle identified |
| 2026-01-05 | Debug: connectAudio fix | Added visualizer.connectAudio(audioSourceNode) |
| 2026-01-05 | Debug: Still blank | Web Audio pull-based architecture issue identified |
| 2026-01-05 | Debug: Audio flow fix | oscillator(440Hz) → signalGain(1) → muteGain(0) → destination |
| 2026-01-05 | Debug: Still blank | Render loop running (1440+ frames) but canvas black |
| 2026-01-05 | Debug: WebGL context fix | Removed premature getContext() that blocked butterchurn |
| 2026-01-05 | **PHASE 1 COMPLETE** | Visualization rendering successfully! |
| 2026-01-05 | Documentation | Updated research.md and state.md with Implementation Findings |
| 2026-01-05 | Phase 2 implementation | ButterchurnFrame, vDSP FFT, merged tap, snapshotButterchurnFrame() |
| 2026-01-05 | **PHASE 2 COMPLETE** | Audio data bridge ready (commit 8e33d71) |
| 2026-01-05 | Phase 2 verification | Debug logging confirmed FFT values in expected ranges |
| 2026-01-05 | Phase 3 implementation | 30 FPS timer, ScriptProcessorNode, audioPlayer wiring |
| 2026-01-05 | Phase 3 initial test | Visualization responds to music - verification in progress |
| 2026-01-05 | Phase 3 pause/resume | Added isVisualizationActive flag, freezes when stopped |
| 2026-01-05 | **PHASE 3 COMPLETE** | Visualization responds to music and freezes when stopped |

---

## Lessons Learned

### Critical Discovery: Butterchurn Requires Audio Graph Connection

**Original Plan Assumption:** Phase 1 would render "static frames" without audio data, deferring audio connection to Phase 2-3.

**Reality:** Butterchurn's `createVisualizer()` and `render()` methods require a valid Web Audio API graph:

1. **AudioContext is mandatory** - Cannot pass `null` to createVisualizer()
2. **Internal AnalyserNode** - Butterchurn creates its OWN analyser internally
3. **connectAudio() required** - Must call `visualizer.connectAudio(audioSourceNode)` to connect to butterchurn's internal analyser
4. **Autoplay policy** - AudioContext may start suspended; call `resume()` after user interaction or programmatically

### Critical Discovery #2: Web Audio is Pull-Based

**The Bug:** Even with AudioContext and connectAudio(), screen was still blank.

**Root Cause:** Web Audio uses a **pull-based architecture**. Audio only flows through the graph if there's a path to `audioContext.destination`. A dead-end analyser receives no data.

**Broken Architecture:**
```
oscillator(0Hz) → gainNode(gain=0) → analyser (DEAD END)
                                      ↑
                            No audio flows here!
```

**Three problems with original approach:**
1. **Dead-end graph** - No path to destination = no audio flow
2. **Zero gain** - `gain=0` multiplies signal to silence before analyser sees it
3. **Zero frequency** - Oscillator at 0Hz produces DC, not visualizable content

**Working Architecture:**
```
                                      ┌─→ butterchurn.analyser (visualization)
oscillator(440Hz) → signalGain(1) ───┤
                                      └─→ muteGain(0) → destination (enables flow)
```

**Solution for Phase 1:**
```javascript
var audioContext = new AudioContext();

// Oscillator with audible frequency (content for analyser)
var oscillator = audioContext.createOscillator();
oscillator.frequency.value = 440;  // A4 note

// Signal gain - MUST be non-zero so analyser sees the signal
var signalGain = audioContext.createGain();
signalGain.gain.value = 1;  // Full signal
oscillator.connect(signalGain);

// Mute gain - enables flow but silences output
var muteGain = audioContext.createGain();
muteGain.gain.value = 0;  // Muted
signalGain.connect(muteGain);
muteGain.connect(audioContext.destination);  // CRITICAL: enables audio flow

audioSourceNode = signalGain;
oscillator.start();

// Now butterchurn's analyser receives real audio data
visualizer = butterchurn.createVisualizer(audioContext, canvas, options);
visualizer.connectAudio(audioSourceNode);
```

**Implications for Phase 2-3:**
- When real audio data is available, replace the silent oscillator with actual audio source
- Can disconnect silent source and connect real PCM stream from Swift
- The audio graph architecture is already in place

### ES Module vs UMD Bundle Differences

**butterchurn.min.js:** Uses ES module export (`export{qt as default}`)
- Fixed with `wrapESModuleAsGlobal()` in ButterchurnWebView.swift
- Converts to `window.butterchurn = qt`

**butterchurnPresets.min.js:** Uses UMD export (`window.minimal`)
- Aliased to `window.butterchurnPresets = window.minimal`
- Presets accessed via `.default` property, NOT `.getPresets()`

### Canvas Sizing in WKWebView

WKWebView canvas requires explicit CSS sizing:
```css
html, body { width: 100%; height: 100%; }
canvas {
    width: 100%;
    height: 100%;
    position: absolute;
    top: 0;
    left: 0;
}
```

Without this, canvas has 0×0 dimensions and WebGL context creation fails.

### Critical Discovery #3: WebGL Context Creation is Exclusive

**The Bug:** Render loop running (1440+ frames), but canvas shows solid black.

**Root Cause:** Calling `canvas.getContext('webgl')` creates a WebGL context with default attributes. Once created, you **cannot create another context** on the same canvas. Butterchurn needs to create its own context with specific attributes (like `preserveDrawingBuffer`).

**Broken Code:**
```javascript
// DEBUG check that blocks butterchurn:
var gl = canvas.getContext('webgl');  // Creates context with default attributes
// ... later ...
butterchurn.createVisualizer(audioContext, canvas, ...);  // Gets blocked or gets wrong context
```

**Fixed Code:**
```javascript
// Do NOT call getContext() before butterchurn!
// Let butterchurn handle WebGL context creation.
butterchurn.createVisualizer(audioContext, canvas, ...);  // Creates its own context

// AFTER visualizer creation, you can inspect the context:
var gl = canvas.getContext('webgl');  // Now returns butterchurn's context
```

**Key Lesson:** Never call `canvas.getContext()` on a canvas that will be used by a third-party WebGL library. Let the library create its own context first.

---

## Next Action

**✅ PHASE 1 COMPLETE** - Visualization working!

All bug fixes applied and verified:
1. ✅ ES module wrapper for butterchurn.min.js
2. ✅ UMD preset handling (getPresets fallback)
3. ✅ AudioContext with silent oscillator
4. ✅ visualizer.connectAudio() call
5. ✅ Canvas CSS sizing
6. ✅ Web Audio pull-based architecture fix
7. ✅ WebGL context exclusivity fix

---

**✅ PHASE 2 COMPLETE** - Audio Data Bridge Ready

Commits:
- `eef4b04`: Phase 1 complete - Butterchurn rendering working
- `7795217`: Debug cleanup
- `8e33d71`: Phase 2 complete - Audio data bridge implementation

**Phase 2 Implementation:**
1. ✅ `ButterchurnFrame` struct defined (spectrum, waveform, timestamp)
2. ✅ `@ObservationIgnored` butterchurnSpectrum/Waveform buffers
3. ✅ vDSP_DFT 2048-point FFT with Hann window
4. ✅ Merged into existing single tap (no second tap!)
5. ✅ Buffer size increased to 2048 for proper FFT
6. ✅ `snapshotButterchurnFrame()` API (returns nil for streams/video)

**Phase 2 Verification (2026-01-05):**
- Tested with local audio playback, debug logging at 1 Hz
- Spectrum: max 0.04-0.46, nonzero bins 110-615/1024 ✅
- Waveform: range -0.32 to +0.30, RMS 0.02-0.13 ✅
- All values in expected ranges, varies with music dynamics
- Logs stop when playback stops (tap inactive) ✅
- Debug logging removed after verification

---

**✅ PHASE 3 COMPLETE - Swift→JS Bridge Working**

**Phase 3 Implementation (2026-01-05):**
1. ✅ Updated ButterchurnBridge.configure() to take AudioPlayer type
2. ✅ Implemented startAudioUpdates() with 30 FPS Timer
3. ✅ Implemented sendAudioFrame() to call snapshotButterchurnFrame() and evaluateJavaScript
4. ✅ Timer starts automatically when JS sends 'ready' message
5. ✅ Updated bridge.js to use ScriptProcessorNode instead of 440Hz oscillator
6. ✅ ScriptProcessorNode outputs latestWaveform buffer (populated by Swift)
7. ✅ Wired audioPlayer to bridge in WinampMilkdropWindow.onAppear
8. ✅ Added visualization pause/resume based on playback state
9. ✅ User verified: visualization responds to music and freezes when stopped

**Phase 3 Verification (2026-01-05):**
- Spectrum max 0.04-0.53, nonzero 53-629/1024 ✅
- Waveform RMS 0.02-0.13, tracking music dynamics ✅
- Visualization animates during playback ✅
- Visualization freezes when paused/stopped ✅
- Debug logging removed after verification ✅

---

**Next Phase:** Phase 4 - Preset Management (cycling, randomize, history)
