# TASK 2 SYNTHESIS - Video & Milkdrop Windows

**Date**: 2025-11-09
**Purpose**: Synthesize all research to create accurate TASK 2 plan

---

## RESEARCH SOURCES REVIEWED

### 1. Gemini Historical Research (Original Winamp)
**Key Findings**:
- **V key**: Stop playback (NOT a button!)
- **Alt+V**: Toggle video window (keyboard shortcut)
- **Milkdrop**: Menu-based trigger (Visualizations menu or Ctrl+Shift+K)
- **Simultaneous**: Spectrum analyzer + Milkdrop could run together (resource-intensive)
- **Video window**: Added in Winamp 2.9 (March 2003)
- **Milkdrop**: Added November 2001 (BEFORE video support)

### 2. Oracle Source Code Analysis (Webamp)
**Key Findings**:
- Webamp has only 4 windows: Main, Playlist, EQ, Milkdrop
- No Video window in Webamp (not implemented)
- VIDEO.BMP exists in skins but unused by Webamp
- GEN.BMP used for Milkdrop chrome (generic window)

### 3. User's Milkdrop Analysis (milkdrop-analysis-hank.md)
**Key Findings**:
- Milkdrop = plugin engine + .milk preset files
- Preset files = scripts with equations (per-frame, per-pixel)
- Butterchurn = JS port using WebGL shaders
- Audio tap feeds FFT data to visualization

### 4. User Observations
**Key Findings**:
- Milkdrop MUST be separate window (confirmed in webamp)
- Options menu (O button) should control Milkdrop
- Spectrum and Milkdrop don't run simultaneously in webamp
- Single audio tap should be shared

### 5. Oracle Audio Tap Guidance
**Key Findings**:
- Extend EXISTING AudioPlayer tap (don't create new one)
- Add getMilkdropWaveform() and getMilkdropSpectrum()
- Higher resolution FFT for Milkdrop (512 bins)
- All from SAME tap

### 6. Existing plan.md (10-day plan)
**Status**: Very detailed, but needs updates:
- ❌ Mounts windows in WinampMainWindow (should use NSWindowController)
- ❌ V button toggle (should be Alt+V or just menu)
- ❌ Creates separate AudioAnalyzer (should extend existing tap)
- ✅ Two-window architecture correct
- ✅ VIDEO.BMP parsing approach correct
- ✅ Butterchurn integration approach correct

---

## ARCHITECTURE CORRECTIONS

### What TASK 1 Taught Us

**DON'T**:
```swift
// WRONG (from original plan):
if appSettings.showVideoWindow {
    VideoWindowView()  // ← Mounted INSIDE WinampMainWindow
}
```

**DO**:
```swift
// CORRECT (NSWindowController pattern from TASK 1):
WindowCoordinator.swift:
- private let videoController: NSWindowController
- private let milkdropController: NSWindowController

WinampVideoWindowController.swift:
- convenience init(...)
- let window = BorderlessWindow(...)
- window.contentView = NSHostingView(rootView: WinampVideoWindow())

Register with WindowSnapManager:
- WindowSnapManager.shared.register(window: videoWindow, kind: .video)
```

---

## CORRECTED TRIGGER MECHANISMS

### Video Window
**Original Winamp**: Alt+V toggles video window
**Webamp**: N/A (not implemented)
**MacAmp Should**:
- **Primary**: Menu item "Window > Video"
- **Shortcut**: Alt+V (or Cmd+V on macOS)
- **Auto-open**: When video file played from playlist
- **V clutter button**: Can wire to video toggle OR leave as visualizer toggle (TBD)

### Milkdrop Window
**Original Winamp**: Visualizations menu, Ctrl+Shift+K
**Webamp**: Has Milkdrop window (separate from main)
**MacAmp Should**:
- **Primary**: Options menu (O button) - "Start/Stop Milkdrop"
- **Shortcut**: Ctrl+Shift+K (Winamp standard)
- **Menu**: Also in Window menu for discoverability

---

## AUDIO TAP ARCHITECTURE (CORRECTED)

### Current MacAmp (from TASK 1)
```swift
AudioPlayer.swift:
- Has MTAudioProcessingTap on mainMixerNode
- Generates: spectrum (20 bands), waveform, RMS
- Used by VisualizerView in main window
```

### Oracle's Guidance
**EXTEND existing tap, don't create new one**:
```swift
// Add to AudioPlayer.swift:
private var milkdropFFTData: [Float] = []  // 512 bins
private var milkdropWaveform: [Float] = []  // 576 samples

func getMilkdropSpectrum() -> [Float] {
    return milkdropFFTData
}

func getMilkdropWaveform() -> [Float] {
    return milkdropWaveform
}

// In existing tap callback:
// - Run higher-res FFT (512 bins for Milkdrop)
// - Keep existing 20-band spectrum for main window
// - Generate 576-sample waveform for Milkdrop
// - All from SAME audio buffer (single tap!)
```

**Benefits**:
- No duplicate audio processing
- Single tap = better performance
- Shared data source = consistent analysis

---

## SPRITE SOURCES (CONFIRMED)

### Video Window
**Source**: VIDEO.BMP
- Titlebar (active/inactive)
- Borders (top/left/right/bottom)
- Corners (TL/TR/BL/BR)
- Buttons: close, minimize, shade
- Playback controls: play, pause, stop, prev, next
- Seek bar: track, thumb

**Parsing**: Need to implement (doesn't exist yet)
**Fallback**: Default gray chrome if VIDEO.BMP missing

### Milkdrop Window
**Source**: GEN.BMP (generic window sprites)
- Already parsed! ✅
- Used by GenWindow system
- Titlebar, borders, corners, close button

**Parsing**: Already done (reuse existing)
**Fallback**: Not needed (GEN.BMP always available)

---

## WINDOW PATTERN (From TASK 1)

### For Each Window
1. Create NSWindowController subclass (WinampVideoWindowController, WinampMilkdropWindowController)
2. Create SwiftUI view (WinampVideoWindow, WinampMilkdropWindow)
3. Add to WindowCoordinator
4. Register with WindowSnapManager
5. Add to delegate multiplexer
6. Wire state to AppSettings

**Example**:
```swift
// WindowCoordinator.swift
private let videoController: NSWindowController
private let milkdropController: NSWindowController

init(...) {
    // ... existing main/eq/playlist setup ...

    // Video window
    videoController = WinampVideoWindowController(...)
    if let video = videoController.window {
        WindowSnapManager.shared.register(window: video, kind: .video)
    }

    // Milkdrop window
    milkdropController = WinampMilkdropWindowController(...)
    if let milkdrop = milkdropController.window {
        WindowSnapManager.shared.register(window: milkdrop, kind: .milkdrop)
    }
}

func showVideo() { videoController.window?.makeKeyAndOrderFront(nil) }
func hideVideo() { videoController.window?.orderOut(nil) }
func showMilkdrop() { milkdropController.window?.makeKeyAndOrderFront(nil) }
func hideMilkdrop() { milkdropController.window?.orderOut(nil) }
```

---

## QUESTIONS TO RESOLVE

### 1. V Clutter Button Behavior
**Options**:
- A) Opens Video window (like existing plan suggests)
- B) Toggles visualization mode in main window (original function?)
- C) Does nothing / disabled (use menu/keyboard only)

**Need to decide**: What should MacAmp's V button do?

### 2. Milkdrop Trigger Priority
**User says**: Options menu (O button)
**Original Winamp**: Visualizations menu + Ctrl+Shift+K
**Existing plan**: Ctrl+Shift+M

**Should we**:
- Add to Options menu as primary trigger?
- Keep Ctrl+Shift+K (Winamp standard)?
- Also in Window menu?

### 3. Resize Implementation Timing
**Both windows are resizable** (like Playlist)
**Options**:
- Implement in TASK 2 (all 3 windows: Playlist/Video/Milkdrop)
- Defer to TASK 3 (dedicated resize task)

**Decision needed**: Now or later?

---

## PLAN UPDATES NEEDED

### Update Existing plan.md
1. Change window mounting strategy (NSWindowController not inline views)
2. Update audio tap approach (extend existing not create new)
3. Clarify V button behavior
4. Update Milkdrop trigger (Options menu integration)
5. Add WindowSnapManager registration steps
6. Add delegate multiplexer integration

### Keep From Existing plan.md
- 10-day timeline structure ✅
- Video window priority (Days 1-6) ✅
- Milkdrop window second (Days 7-10) ✅
- VIDEO.BMP sprite parsing approach ✅
- Butterchurn HTML bundle approach ✅
- Detailed task checklist ✅

---

## NEXT STEPS

1. Resolve open questions (V button, Milkdrop trigger, resize timing)
2. Update plan.md with NSWindowController pattern
3. Update audio tap approach
4. Get Oracle validation of updated plan
5. Begin Day 1 implementation

---

**Status**: Synthesis complete, awaiting user decisions on open questions
