# Butterchurn Integration - Task List

**Task ID:** butterchurn-integration
**Created:** 2026-01-05
**Revised:** 2026-01-05 (Oracle Review)

---

## Phase 1: WebView + JS Injection (Foundation)

**Goal:** Load Butterchurn reliably with correct injection order and JS render loop.
**Commit after:** Static Butterchurn frame renders in window.

### 1.1 Create ButterchurnWebView.swift
- [ ] Create `MacAmpApp/Views/Windows/ButterchurnWebView.swift`
- [ ] Implement as `struct` conforming to `NSViewRepresentable`
- [ ] Configure `WKWebViewConfiguration` with `WKUserContentController`
- [ ] Implement `loadBundleJS()` helper to load .js as String

### 1.2 Script Injection Order
- [ ] Inject `butterchurn.min.js` at `.atDocumentStart`
- [ ] Inject `butterchurnPresets.min.js` at `.atDocumentStart`
- [ ] Inject `bridge.js` at `.atDocumentEnd` (after DOM ready)
- [ ] Register message handler with name "butterchurn"

### 1.3 Update HTML
- [ ] Modify `Butterchurn/index.html` to remove `<script src>` tags
- [ ] Add canvas element and fallback div
- [ ] Add minimal CSS (black background, no margin)

### 1.4 Rewrite bridge.js
- [ ] Check for `butterchurn` and `butterchurnPresets` globals
- [ ] Use `butterchurnPresets.getPresets()` to populate presets
- [ ] Create visualizer with canvas dimensions
- [ ] Implement 60 FPS `requestAnimationFrame` render loop
- [ ] Add `window.macampButterchurn` API object
- [ ] Dispatch `ready` message to Swift with preset count/names
- [ ] Dispatch `loadFailed` message if libraries not loaded

### 1.5 Lifecycle & Cleanup
- [ ] Implement `dismantleNSView` in ButterchurnWebView
- [ ] Call `removeScriptMessageHandler` to prevent retain cycle
- [ ] Call `bridge.cleanup()` to stop timers
- [ ] Add fallback UI in WinampMilkdropWindow when `!bridge.isReady`

### 1.6 Phase 1 Verification
- [ ] Test: `butterchurn` global is defined before HTML init
- [ ] Test: `butterchurnPresets.getPresets()` returns preset list
- [ ] Test: JS render loop runs with static frame (no audio)
- [ ] Test: Fallback UI shows if injection fails
- [ ] Test: No WebView memory leaks on window close

---

## Phase 2: Audio Tap Merge (Mechanism)

**Goal:** Produce Butterchurn FFT + waveform from the existing tap.
**Commit after:** `snapshotButterchurnFrame()` returns valid data during playback.

### 2.1 Define ButterchurnFrame
- [ ] Add `ButterchurnFrame` struct to AudioPlayer.swift
- [ ] Include `spectrum: [Float]` (1024 bins)
- [ ] Include `waveform: [Float]` (1024 samples)
- [ ] Include `timestamp: TimeInterval`

### 2.2 Add Butterchurn Buffers
- [ ] Add `@ObservationIgnored butterchurnSpectrum: [Float]` (1024)
- [ ] Add `@ObservationIgnored butterchurnWaveform: [Float]` (1024)
- [ ] Add `@ObservationIgnored lastButterchurnUpdate: TimeInterval`

### 2.3 Merge into Existing Tap
- [ ] Modify existing `installVisualizerTap()` (do NOT add second tap)
- [ ] Increase buffer size to 2048 if needed
- [ ] Add `processButterchurnData(buffer:)` call in tap closure
- [ ] Compute 2048-point FFT for 1024 frequency bins
- [ ] Downsample mono waveform to 1024 points

### 2.4 Expose Snapshot API
- [ ] Implement `snapshotButterchurnFrame() -> ButterchurnFrame?`
- [ ] Return `nil` if not local playback (`isLocalPlayback` check)
- [ ] Thread-safe copy of current buffers

### 2.5 Phase 2 Verification
- [ ] Test: Single tap remains installed (verify no second tap)
- [ ] Test: `snapshotButterchurnFrame()` returns data during local playback
- [ ] Test: Returns `nil` for stream playback
- [ ] Test: No UI observation churn from high-frequency updates

---

## Phase 3: Swift→JS Bridge (30 FPS)

**Goal:** Push audio data to JS at 30 FPS and let JS render at 60 FPS.
**Commit after:** Visualization responds to music.

### 3.1 Create ButterchurnBridge.swift
- [ ] Create `MacAmpApp/ViewModels/ButterchurnBridge.swift`
- [ ] Annotate with `@MainActor @Observable`
- [ ] Conform to `NSObject, WKScriptMessageHandler`
- [ ] Add `weak var webView: WKWebView?`
- [ ] Add observable state: `isReady`, `presetCount`, `presetNames`

### 3.2 Message Handler Implementation
- [ ] Implement `userContentController(_:didReceive:)`
- [ ] Parse `type` from message body dictionary
- [ ] Handle `ready` message: set isReady, extract preset info, start timer
- [ ] Handle `loadFailed` message: set isReady=false, stop timer

### 3.3 Audio Update Timer (30 FPS)
- [ ] Add `@ObservationIgnored updateTimer: Timer?`
- [ ] Add `@ObservationIgnored audioPlayer: AudioPlayer?`
- [ ] Implement `startAudioUpdates()` with 1/30 second interval
- [ ] Implement `stopAudioUpdates()` to invalidate timer
- [ ] Use `Task { @MainActor }` wrapper for timer callback

### 3.4 Send Audio Frame
- [ ] Implement `sendAudioFrame()` method
- [ ] Pull from `audioPlayer?.snapshotButterchurnFrame()`
- [ ] Convert spectrum to `[UInt8]` (0-255 range)
- [ ] Call `evaluateJavaScript` with audio data arrays
- [ ] Guard for nil webView or nil frame

### 3.5 Cleanup
- [ ] Implement `cleanup()` method
- [ ] Stop timer and nil out webView reference
- [ ] Implement `configure(audioPlayer:)` for dependency injection

### 3.6 Phase 3 Verification
- [ ] Test: JS buffers update at 30 FPS
- [ ] Test: JS render loop continues at 60 FPS
- [ ] Test: Visualization responds to bass, treble
- [ ] Test: No perceptible audio/visual lag
- [ ] Test: Clean start/stop on playback state changes

---

## Phase 4: Preset Manager (Bridge Layer)

**Goal:** Manage presets, cycling, and transitions.
**Commit after:** Presets cycle automatically every 15 seconds.

### 4.1 Create ButterchurnPresetManager.swift
- [ ] Create `MacAmpApp/ViewModels/ButterchurnPresetManager.swift`
- [ ] Annotate with `@MainActor @Observable`
- [ ] Add observable state: `presets`, `currentPresetIndex`, `isRandomize`, `isCycling`
- [ ] Add `cycleInterval: TimeInterval` and `transitionDuration: Double`

### 4.2 History & Navigation
- [ ] Add `@ObservationIgnored presetHistory: [Int]`
- [ ] Implement `nextPreset()` with random/sequential logic
- [ ] Implement `previousPreset()` using history stack
- [ ] Implement `selectPreset(at:transition:)` with JS call

### 4.3 Cycling Timer
- [ ] Add `@ObservationIgnored cycleTimer: Timer?`
- [ ] Implement `startCycling()` with configurable interval
- [ ] Implement `stopCycling()` to invalidate timer
- [ ] Guard cycling based on `isCycling` flag

### 4.4 Configuration & Wiring
- [ ] Add `weak var bridge: ButterchurnBridge?`
- [ ] Implement `configure(bridge:appSettings:)` to load initial values
- [ ] Implement `loadPresets(_ names:)` to populate from JS callback

### 4.5 AppSettings Persistence
- [ ] Add `butterchurnRandomize: Bool` to AppSettings.swift
- [ ] Add `butterchurnCycling: Bool` to AppSettings.swift
- [ ] Add `butterchurnCycleInterval: Double` to AppSettings.swift
- [ ] Load defaults in `init` (not just `didSet`)
- [ ] Handle missing/zero values with sensible defaults

### 4.6 Phase 4 Verification
- [ ] Test: Preset list loads from JS on ready
- [ ] Test: Presets cycle every 15 seconds (default)
- [ ] Test: Random mode produces variety (no immediate repeats)
- [ ] Test: Previous/next navigation works with history
- [ ] Test: Settings persist across app restarts

---

## Phase 5: UI Integration & Commands

**Goal:** Wire Butterchurn into the Milkdrop window and controls.
**Commit after:** Shortcuts work and track titles display.

### 5.1 Window Integration
- [ ] Replace placeholder in `WinampMilkdropWindow.swift`
- [ ] Embed `ButterchurnWebView` when `bridge.isReady`
- [ ] Show fallback placeholder when not ready or stream playing

### 5.2 Track Title Display
- [ ] Add `showTrackTitle(_ title:)` to ButterchurnBridge
- [ ] Escape single quotes in title string
- [ ] Call `window.macampButterchurn.showTrackTitle()` via JS
- [ ] Wire to track change event in PlaybackCoordinator

### 5.3 Keyboard Shortcuts
- [ ] Space → `presetManager.nextPreset()`
- [ ] Backspace → `presetManager.previousPreset()`
- [ ] R → `presetManager.isRandomize.toggle()`
- [ ] T → `bridge.showTrackTitle(currentTrack.title)`

### 5.4 Window Lifecycle
- [ ] Pause rendering on `NSWindow.didMiniaturizeNotification`
- [ ] Resume rendering on `NSWindow.didDeminiaturizeNotification`
- [ ] Add `pauseRendering()` and `resumeRendering()` to bridge
- [ ] Call `window.macampButterchurn.stop()` and `.start()` respectively

### 5.5 Phase 5 Verification
- [ ] Test: Track titles appear on track change (5 different tracks)
- [ ] Test: All keyboard shortcuts work in Milkdrop window
- [ ] Test: Rendering pauses when window minimized
- [ ] Test: Rendering resumes when window restored

---

## Phase 6: Verification (Dual-Backend Constraints)

**Goal:** Validate local-only Butterchurn behavior without breaking stream playback.
**Commit after:** All tests pass, PR ready.

### 6.1 Build Verification
- [ ] Build with Thread Sanitizer enabled
- [ ] Fix any data race warnings
- [ ] Verify no build warnings in new files

### 6.2 Oracle Code Review
- [ ] Run Oracle review on ButterchurnWebView.swift
- [ ] Run Oracle review on ButterchurnBridge.swift
- [ ] Run Oracle review on ButterchurnPresetManager.swift
- [ ] Run Oracle review on AudioPlayer.swift changes
- [ ] Address any issues identified

### 6.3 Manual Test: Local Playback
- [ ] Local file → visualization appears
- [ ] Bass hits cause visible reactions
- [ ] Treble/highs cause visible reactions
- [ ] Multiple files play without crashes

### 6.4 Manual Test: Stream Handling
- [ ] Stream → shows fallback UI (no visualization)
- [ ] Local → Stream switch: visualization stops cleanly
- [ ] Stream → Local switch: visualization resumes
- [ ] No crashes during backend transitions

### 6.5 Manual Test: Preset System
- [ ] Presets cycle for 5+ minutes
- [ ] Different presets visually distinct
- [ ] Previous button returns to last preset
- [ ] Next in random mode doesn't repeat immediately

### 6.6 Manual Test: Window States
- [ ] Window minimize: rendering pauses (CPU drops)
- [ ] Window restore: rendering resumes
- [ ] Window close: no memory leaks
- [ ] Window reopen: Butterchurn reinitializes

### 6.7 Manual Test: Persistence
- [ ] Quit and restart app
- [ ] Butterchurn settings preserved
- [ ] Window position preserved
- [ ] No first-launch errors

### 6.8 Performance Verification
- [ ] CPU usage < 15% during visualization
- [ ] Memory stable over 10+ minutes
- [ ] No visible frame drops
- [ ] Responsive to audio in real-time

### 6.9 Final Steps
- [ ] Create PR with comprehensive description
- [ ] Include all 6 phase commits
- [ ] Request review

---

## Reference Files

| Purpose | File |
|---------|------|
| Research | `tasks/butterchurn-integration/research.md` |
| Plan | `tasks/butterchurn-integration/plan.md` |
| State | `tasks/butterchurn-integration/state.md` |
| Milkdrop window | `MacAmpApp/Views/WinampMilkdropWindow.swift` |
| Window chrome | `MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift` |
| Audio player | `MacAmpApp/Audio/AudioPlayer.swift` |
| Settings | `MacAmpApp/Models/AppSettings.swift` |
| Butterchurn assets | `Butterchurn/*.js`, `Butterchurn/*.html` |
| Architecture guide | `docs/MACAMP_ARCHITECTURE_GUIDE.md` |
| Patterns | `docs/IMPLEMENTATION_PATTERNS.md` |

---

## Notes

- **Total estimated tasks:** 85 checkboxes across 6 phases
- **Each phase is independently committable**
- **Stream support deferred:** Local playback only; design allows future `ButterchurnAudioSource` protocol
- **Performance target:** 30 FPS Swift→JS, 60 FPS JS render loop
