# Oscilloscope/RMS Mode Toggle - Research

**Date:** 2025-10-30
**Objective:** Add UI toggle to switch between Spectrum Analyzer and RMS/Oscilloscope modes
**Research Sources:**
- Gemini (webamp implementation analysis)
- MacAmp codebase discovery
- VISCOLOR.TXT specification

---

## Executive Summary

**Finding:** MacAmp ALREADY HAS spectrum/RMS backend! ✅

**What Exists:**
- ✅ AudioPlayer.useSpectrumVisualizer: Bool (toggle property)
- ✅ RMS calculation in audio tap
- ✅ Spectrum calculation in audio tap
- ✅ VisualizerOptions.swift component with UI toggle

**What's Missing:**
- ❌ VisualizerOptions not surfaced in main window
- ❌ Oscilloscope waveform mode (webamp has this)
- ❌ Click-to-cycle on visualizer (webamp pattern)
- ❌ VISCOLOR colors 18-22 not applied to RMS mode

**Implementation:** Expose existing backend + add oscilloscope mode

---

## Webamp Implementation Analysis (Gemini)

### 3 Visualization Modes

**Webamp supports:**
1. **Spectrum Analyzer** (`VISUALIZERS.BAR`)
   - Frequency bars (bass to treble)
   - Uses VISCOLOR colors 2-17 (16-color gradient)

2. **Oscilloscope** (`VISUALIZERS.OSCILLOSCOPE`)
   - Waveform visualization (amplitude over time)
   - Uses VISCOLOR colors 18-22 (5 white shades)

3. **None** (`VISUALIZERS.NONE`)
   - Visualizer off

**Note:** NO "RMS mode" in webamp - just Spectrum and Oscilloscope

### Clickable Canvas Pattern

**File:** `webamp_clone/packages/webamp/js/components/Vis.tsx`

```typescript
export default function Vis({ analyser }: Props) {
  const toggleVisualizerStyle = useActionCreator(Actions.toggleVisualizerStyle);

  return (
    <canvas
      id="visualizer"
      onClick={toggleVisualizerStyle}  // ← Click to cycle modes
    />
  );
}
```

**How it works:**
1. User clicks canvas
2. Dispatches `toggleVisualizerStyle` action
3. Reducer increments mode index
4. Cycles through: BAR → OSCILLOSCOPE → NONE → BAR ...

### Mode Cycling Logic

**File:** `webamp_clone/packages/webamp/js/constants.ts`

```typescript
export const VISUALIZERS = {
  OSCILLOSCOPE: "OSCILLOSCOPE",
  BAR: "BAR",
  NONE: "NONE",
};

export const VISUALIZER_ORDER = [
  VISUALIZERS.BAR,
  VISUALIZERS.OSCILLOSCOPE,
  VISUALIZERS.NONE,
];
```

**File:** `webamp_clone/packages/webamp/js/reducers/display.ts`

```typescript
case "TOGGLE_VISUALIZER_STYLE":
  return {
    ...state,
    visualizerStyle: (state.visualizerStyle + 1) % VISUALIZER_ORDER.length,
  };
```

### Rendering Differences

**Spectrum Analyzer (BarPaintHandler):**
- Renders frequency bands as vertical bars
- Uses FFT data (frequency analysis)
- Colors 2-17: Red (high) → Yellow (mid) → Green (low)
- 16-color gradient pre-rendered to off-screen canvas
- Each bar samples one frequency range

**Oscilloscope (WavePaintHandler):**
- Renders waveform (amplitude over time)
- Uses time-domain audio data (raw samples)
- Colors 18-22: 5 shades of white (brightest to dimmest)
- Draws connected line across canvas
- Shows audio wave shape

**File:** `webamp_clone/packages/webamp/js/components/VisPainter.ts`

```typescript
// WavePaintHandler - Uses colors 18-22
colorIndex(y: number): number {
  if (y >= 14) return 4;  // Darkest (color 22)
  if (y >= 12) return 3;  // Darker  (color 21)
  if (y >= 10) return 2;  // Mid     (color 20)
  if (y >= 8)  return 1;  // Bright  (color 19)
  if (y >= 6)  return 0;  // Brightest (color 18)
  // ... mirror for bottom half
}
```

---

## MacAmp Backend Discovery

### Existing Components ✅

**1. AudioPlayer.swift - State Property**

**File:** `MacAmpApp/Audio/AudioPlayer.swift`
**Line:** 107

```swift
var useSpectrumVisualizer: Bool = true
```

**Purpose:** Toggle between spectrum (FFT) and RMS (amplitude) modes
**State:** @Observable property
**Access:** Can toggle from UI

**2. Audio Tap - Dual Calculation**

**File:** `MacAmpApp/Audio/AudioPlayer.swift`
**Lines:** 838-958

**RMS Calculation (Lines 882-903):**
```swift
scratch.withRms { rms in
    let bucketSize = max(1, frameCount / bars)
    var cursor = 0
    for b in 0..<bars {
        // Calculate RMS (Root Mean Square) for each bucket
        var sumSq: Float = 0
        for i in start..<end {
            let sample = mono[i]
            sumSq += sample * sample
        }
        var value = sqrt(sumSq / Float(end - start))
        value = min(1.0, value * 4.0)
        rms[b] = value
    }
}
```

**Spectrum Calculation (Lines 904-948):**
```swift
// FFT for frequency spectrum
vDSP_fft_zrip(fftSetup, &complex, 1, vDSP_Length(log2n), FFTDirection(FFT_FORWARD))

// Convert to magnitude
scratch.withSpectrum { spectrum in
    // Map frequency bins to bars
    // Apply weighting, smoothing, etc.
}
```

**3. Visualizer Level Update (Lines 838-843)**

```swift
@MainActor
private func updateVisualizerLevels(rms: [Float], spectrum: [Float]) {
    // Choose which data to use based on mode
    let used = self.useSpectrumVisualizer ? spectrum : rms

    // Update visualizer with selected data
    // ...
}
```

**Key Finding:** Backend calculates BOTH RMS and Spectrum, selects based on `useSpectrumVisualizer`!

**4. VisualizerOptions.swift - UI Component**

**File:** `MacAmpApp/Views/VisualizerOptions.swift`
**Lines:** 1-40

```swift
struct VisualizerOptions: View {
    @Environment(AudioPlayer.self) var audioPlayer

    var body: some View {
        @Bindable var player = audioPlayer

        VStack {
            Button("Options") { show.toggle() }
            if show {
                Toggle("Spec", isOn: $player.useSpectrumVisualizer)  // ← Toggle exists!
                    .toggleStyle(.switch)

                // Also has smoothing and peak falloff sliders
            }
        }
    }
}
```

**Key Finding:** UI toggle ALREADY EXISTS but not surfaced in main window!

**5. VisualizerView.swift - Rendering**

**File:** `MacAmpApp/Views/VisualizerView.swift`
**Lines:** 1-200+

**Current Implementation:**
- Renders 19 vertical bars
- Uses `audioPlayer.getFrequencyData(bands: 19)`
- Hardcoded green/yellow/red colors (doesn't use VISCOLOR yet)
- 30 FPS update rate
- Peak dots with decay

**What it supports:**
- ✅ Frequency data (spectrum mode)
- ✅ Can receive RMS data (backend provides it)
- ❌ No waveform/oscilloscope rendering
- ❌ Not using VISCOLOR colors 18-22

---

## VISCOLOR.TXT Color Specification

### Color Map (24 Colors Total)

From `tasks/done/viscolor-spectrum/research.md`:

```
Index | RGB         | Usage
------|-------------|----------------------------------
0     | 0,0,0       | Black (background)
1     | 24,33,41    | Grey for dots
2-17  | (gradient)  | Spectrum analyzer (16 colors)
  2   | 239,49,16   | Red (high frequency/amplitude)
  17  | 24,132,8    | Green (low frequency/amplitude)
18-22 | (whites)    | Oscilloscope (5 shades)
  18  | 255,255,255 | Brightest
  22  | (dimmer)    | Darkest
23    | 150,150,150 | Peak dots
```

### Current Usage in MacAmp

**Spectrum Mode (Colors 2-17):**
- ✅ Parser exists: `VisColorParser.swift`
- ✅ Colors loaded: `Skin.visualizerColors`
- ❌ Not applied yet: `VisualizerView.swift` uses hardcoded colors

**Oscilloscope/RMS (Colors 18-22):**
- ✅ Colors available in Skin.visualizerColors[18-22]
- ❌ Not used anywhere yet
- ❌ No oscilloscope waveform rendering

---

## MacAmp vs Webamp Comparison

### Webamp

| Feature | Status |
|---------|--------|
| Spectrum Analyzer | ✅ Implemented |
| Oscilloscope (waveform) | ✅ Implemented |
| None (off) | ✅ Implemented |
| Click to cycle modes | ✅ Implemented |
| VISCOLOR colors | ✅ Applied |
| 3 modes | ✅ All functional |

### MacAmp

| Feature | Status |
|---------|--------|
| Spectrum Analyzer | ✅ Backend done, rendering exists |
| RMS Mode | ✅ Backend done, NOT surfaced |
| Oscilloscope (waveform) | ❌ Not implemented |
| Click to cycle modes | ❌ Not implemented |
| VISCOLOR colors | ⚠️ Loaded but not applied |
| Toggle UI | ✅ EXISTS but hidden (VisualizerOptions.swift) |

---

## What Modes Should MacAmp Support?

### Option A: Spectrum vs RMS (Simplest)

**Already have backend:**
- Spectrum: Frequency bars (FFT analysis)
- RMS: Amplitude bars (volume levels)
- Just surface VisualizerOptions component

**Effort:** 30 minutes (expose existing UI)

### Option B: Add Oscilloscope (Like Webamp)

**Need to implement:**
- Waveform rendering (connect audio samples as line)
- Use VISCOLOR colors 18-22
- Different rendering code path

**Effort:** 3-4 hours (new rendering mode)

### Option C: Both + Click-to-Cycle

**Full webamp parity:**
- 3 modes: Spectrum, Oscilloscope, None
- Click visualizer to cycle
- Apply VISCOLOR colors correctly
- Match webamp behavior

**Effort:** 4-5 hours

---

## Recommended Implementation Strategy

### Phase 1: Expose Existing RMS Toggle (30 min)

**What:**
- Add VisualizerOptions component to main window
- User can toggle Spectrum vs RMS
- Uses existing backend (already works!)

**Where to add:**
- Near visualizer area
- Or in Options menu (future O button)
- Or make visualizer clickable

**Code:**
```swift
// In WinampMainWindow - near visualizer
VisualizerOptions()
    .at(CGPoint(x: 24, y: 60)) // Near visualizer
```

### Phase 2: Make Visualizer Clickable (1 hour)

**What:**
- Add .onTapGesture to VisualizerView
- Cycles modes: Spectrum → RMS → None → Spectrum
- Matches webamp pattern

**Implementation:**
```swift
// In VisualizerView
var body: some View {
    HStack { /* bars */ }
        .onTapGesture {
            cycleVisualizerMode()
        }
}

private func cycleVisualizerMode() {
    // Cycle through modes
    // Could use AppSettings.visualizerMode (already scaffolded!)
}
```

### Phase 3: Add Oscilloscope Mode (3-4 hours)

**What:**
- Implement waveform rendering
- Use time-domain audio samples
- Apply VISCOLOR colors 18-22
- Add to mode cycling

**Complexity:** Medium (new rendering logic)

### Phase 4: Apply VISCOLOR Colors (2 hours)

**What:**
- Use Skin.visualizerColors instead of hardcoded
- Spectrum: colors 2-17
- RMS/Oscilloscope: colors 18-22
- Peak dots: color 23

**Files:**
- VisualizerView.swift - Update SpectrumBar coloring

---

## Technical Details

### Current RMS vs Spectrum Logic

**File:** `AudioPlayer.swift` Line 840

```swift
let used = self.useSpectrumVisualizer ? spectrum : rms
```

**Simple boolean toggle:**
- `true` → Spectrum (frequency analysis)
- `false` → RMS (amplitude analysis)

**Both calculated every frame** - just choose which to display!

### Oscilloscope Rendering (To Implement)

**Different from bars:**
- Not vertical bars
- Connected waveform line
- Horizontal axis = time
- Vertical axis = amplitude
- Uses audio samples directly (not FFT)

**Gemini's findings:**
- Webamp uses WavePaintHandler
- Draws connected points
- Uses 5 white shades for depth
- Updates at 60 FPS

### State Management Options

**Option A: Use AudioPlayer.useSpectrumVisualizer (Current)**
- Bool: true = spectrum, false = RMS
- ❌ Can't support 3+ modes

**Option B: Use AppSettings.visualizerMode (Scaffolded)**
- Int: 0 = none, 1 = spectrum, 2 = RMS, 3 = oscilloscope
- ✅ Supports multiple modes
- ✅ Already exists in AppSettings
- ✅ Can cycle through

**Recommendation:** Migrate to visualizerMode enum for extensibility

---

## UI Integration Options

### Option 1: Add VisualizerOptions Button (Quickest)

**Pros:**
- ✅ Component already exists
- ✅ 30 minutes implementation
- ✅ Toggle between Spectrum/RMS works

**Cons:**
- ⚠️ Doesn't match webamp (no click-to-cycle)
- ⚠️ Extra UI element

**Implementation:**
```swift
// In WinampMainWindow
buildVisualizerArea()
    .overlay(
        VisualizerOptions()
            .frame(width: 60, height: 40)
            .at(CGPoint(x: 25, y: 58))
    )
```

### Option 2: Clickable Visualizer (Webamp Pattern)

**Pros:**
- ✅ Matches webamp behavior
- ✅ No extra UI elements
- ✅ Intuitive (click to cycle)

**Cons:**
- ⚠️ Need to add .onTapGesture
- ⚠️ State management for modes
- ⚠️ 1-2 hours implementation

**Implementation:**
```swift
// In VisualizerView
var body: some View {
    HStack { /* bars */ }
        .onTapGesture {
            settings.visualizerMode = (settings.visualizerMode + 1) % 3
        }
}
```

### Option 3: V Button in Clutter Bar

**Pros:**
- ✅ Uses scaffolded V button
- ✅ Keyboard shortcut: Ctrl+V
- ✅ Matches D/A button pattern

**Cons:**
- ⚠️ Less discoverable than clicking visualizer
- ⚠️ Button might not be obvious

**Implementation:**
```swift
// Wire V button to cycle visualizerMode
Button(action: {
    settings.visualizerMode = (settings.visualizerMode + 1) % 3
}) {
    let sprite = getSpriteForMode(settings.visualizerMode)
    SimpleSpriteImage(sprite, width: 8, height: 7)
}
```

---

## Recommended Implementation Path

### MVP: Expose Existing Backend (Option 1 + 2)

**Phase 1 (30 min): Add VisualizerOptions**
- Surface existing component
- Works immediately with current backend

**Phase 2 (1 hour): Make Visualizer Clickable**
- Add .onTapGesture
- Cycle: Spectrum → RMS → None
- Matches webamp pattern

**Phase 3 (Optional - 4 hours): Add Oscilloscope**
- Implement waveform rendering
- Use VISCOLOR colors 18-22
- Add to mode cycle

**Total: 1.5 hours (Spectrum/RMS only), 5.5 hours (with Oscilloscope)**

---

## VISCOLOR Color Application

### Spectrum Gradient (Colors 2-17)

**Current (Hardcoded):**
```swift
// VisualizerView.swift - Hardcoded colors
if normalizedHeight < greenThreshold {
    return LinearGradient(colors: [
        Color(red: 0, green: 0.6, blue: 0),  // HARDCODED!
        Color(red: 0, green: 1, blue: 0)
    ], ...)
}
```

**Should be:**
```swift
let skinColors = skinManager.currentSkin?.visualizerColors ?? defaultColors

// Map bar height to color index (2-17)
let colorIndex = 2 + Int((normalizedHeight) * 15)
let barColor = skinColors[colorIndex]
```

### RMS/Oscilloscope Shades (Colors 18-22)

**Should implement:**
```swift
// For RMS bars or oscilloscope waveform
let whiteShades = skinManager.currentSkin?.visualizerColors[18...22] ?? defaultWhites

// Use for amplitude-based coloring
let shadeIndex = Int(amplitude * 4) // Maps 0-1 to 0-4
let color = whiteShades[shadeIndex]
```

---

## Oscilloscope Implementation (If Adding)

### Rendering Strategy

**Different from bars:**
- Canvas: 76px wide × 16px tall (webamp dimensions)
- Data: Time-domain samples (not FFT)
- Visual: Connected waveform line
- Colors: 5 white shades based on amplitude

**Pseudo-code:**
```swift
struct OscilloscopeView: View {
    let samples: [Float]  // Audio samples
    let colors: [Color]   // VISCOLOR 18-22

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))

            for (index, sample) in samples.enumerated() {
                let x = CGFloat(index) / CGFloat(samples.count) * size.width
                let y = size.height / 2 - (CGFloat(sample) * size.height / 2)

                path.addLine(to: CGPoint(x: x, y: y))
            }

            // Color based on amplitude
            let amplitude = abs(samples.max() ?? 0)
            let colorIndex = min(4, Int(amplitude * 5))
            let color = colors[colorIndex]

            context.stroke(path, with: .color(color))
        }
    }
}
```

**Complexity:** Medium - need time-domain sample access from AudioPlayer

---

## State Management Strategy

### Current: Boolean (Spectrum vs RMS)

```swift
// AudioPlayer.swift
var useSpectrumVisualizer: Bool = true
```

**Limitation:** Only 2 modes

### Recommended: Enum (Extensible)

```swift
enum VisualizerMode: Int {
    case none = 0
    case spectrum = 1
    case rms = 2
    case oscilloscope = 3
}

// In AppSettings (already scaffolded!)
var visualizerMode: Int = 1  // Default to spectrum

// Usage
var currentMode: VisualizerMode {
    VisualizerMode(rawValue: visualizerMode) ?? .spectrum
}
```

**Benefits:**
- ✅ Supports 3+ modes
- ✅ Can cycle through
- ✅ Extensible (add waterfall, etc.)
- ✅ Persists to UserDefaults

---

## Integration with Clutter Bar

### V Button Could Toggle Visualizer Mode!

**Current Status:**
- V button: Scaffolded (disabled)
- AppSettings.visualizerMode: Int (scaffolded)
- Perfect match!

**Implementation:**
```swift
// Make V button functional
Button(action: {
    settings.visualizerMode = (settings.visualizerMode + 1) % 3
}) {
    let sprite = settings.visualizerMode == 0
        ? "MAIN_CLUTTER_BAR_BUTTON_V"
        : "MAIN_CLUTTER_BAR_BUTTON_V_SELECTED"
    SimpleSpriteImage(sprite, width: 8, height: 7)
}
.help("Cycle visualizer mode (Ctrl+V)")
```

**Or:**
- Mode 0: Button normal (off)
- Mode 1+: Button selected (on, different modes)

---

## Implementation Complexity Assessment

| Task | Effort | Complexity | Priority |
|------|--------|------------|----------|
| Expose VisualizerOptions | 30 min | 🟢 Simple | HIGH |
| Make visualizer clickable | 1 hour | 🟢 Simple | MEDIUM |
| Wire V button | 1 hour | 🟢 Simple | HIGH |
| Apply VISCOLOR colors | 2 hours | 🟡 Medium | MEDIUM |
| Add oscilloscope mode | 4 hours | 🟡 Medium | LOW |

**Quickest Win:** Expose VisualizerOptions (30 min, works immediately)
**Best UX:** Clickable visualizer + V button (2 hours)
**Full Feature:** Add oscilloscope waveform (6 hours total)

---

## Key Findings

### What's Already Working ✅
1. ✅ RMS calculation in audio tap
2. ✅ Spectrum calculation in audio tap
3. ✅ Toggle property (useSpectrumVisualizer)
4. ✅ VisualizerOptions UI component
5. ✅ VISCOLOR parser and color loading

### What's Missing ❌
1. ❌ VisualizerOptions not in main window
2. ❌ Clickable visualizer area
3. ❌ Oscilloscope waveform rendering
4. ❌ VISCOLOR colors not applied
5. ❌ V button not wired

### Easiest Implementation ✅
**Just add one line to WinampMainWindow:**
```swift
VisualizerOptions()
    .at(CGPoint(x: 25, y: 58))
```

**Result:** Instant Spectrum vs RMS toggle! ✅

---

## References

- Webamp: `webamp_clone/packages/webamp/js/components/Vis.tsx`
- MacAmp Backend: `MacAmpApp/Audio/AudioPlayer.swift` Lines 107, 838-958
- MacAmp UI: `MacAmpApp/Views/VisualizerOptions.swift`
- MacAmp Rendering: `MacAmpApp/Views/VisualizerView.swift`
- VISCOLOR Spec: `tasks/done/viscolor-spectrum/research.md`

---

**Status:** Research complete - Backend exists, just needs UI exposure!
**Recommendation:** Start with Phase 1 (expose VisualizerOptions) for quick win
# Oracle Review - Oscilloscope/RMS Mode Task

**Date:** 2025-10-30
**Reviewer:** Oracle (Codex)
**Scope:** Complete task review (research, plan, state, todo)

---

## Critical Issues Found (5)

### 1. ❌ CRITICAL: Enum Doesn't Wire to Backend

**Issue:** Phase 2 adds visualizerMode enum but never connects it to AudioPlayer.useSpectrumVisualizer

**Problem:**
```swift
// AppSettings
settings.visualizerMode = 2  // User selects RMS

// But AudioPlayer still uses:
let used = self.useSpectrumVisualizer ? spectrum : rms  // ← Still reads old Bool!
```

**Result:** Mode cycling won't actually change what's rendered!

**Fix Required:**
```swift
// Option A: Sync enum to Bool
var visualizerMode: Int = 1 {
    didSet {
        // Update AudioPlayer flag
        let player = AudioPlayer.instance()  // Or pass reference
        player.useSpectrumVisualizer = (visualizerMode == 1)
    }
}

// Option B: Replace Bool with enum in AudioPlayer
enum VisualizerMode: Int {
    case none, spectrum, rms, oscilloscope
}

// In AudioPlayer - replace Bool with enum
var visualizerMode: VisualizerMode = .spectrum

// Update selector logic:
let used: [Float]
switch visualizerMode {
case .none: used = Array(repeating: 0, count: bars)
case .spectrum: used = spectrum
case .rms: used = rms
case .oscilloscope: used = waveform  // Phase 3
}
```

**Severity:** CRITICAL - Feature won't work without this
**Impact:** All of Phase 2

---

### 2. ❌ HIGH: Data Exposure Not Addressed

**Issue:** Currently one dataset is thrown away, RMS not accessible from UI

**Current Code (Line 840):**
```swift
let used = self.useSpectrumVisualizer ? spectrum : rms
// One array is selected, the other is DISCARDED
```

**Problem:** VisualizerView can't access RMS data even if mode changes

**Fix Required:**
```swift
// Store both datasets on @MainActor
var currentSpectrumLevels: [Float] = []
var currentRMSLevels: [Float] = []

@MainActor
private func updateVisualizerLevels(rms: [Float], spectrum: [Float]) {
    // Store BOTH
    self.currentRMSLevels = rms
    self.currentSpectrumLevels = spectrum

    // VisualizerView can access either
}

// Expose methods:
@MainActor
func getRMSData(bands: Int) -> [Float] {
    return currentRMSLevels
}

@MainActor
func getSpectrumData(bands: Int) -> [Float] {
    return currentSpectrumLevels
}
```

**Severity:** HIGH - RMS mode won't have data
**Impact:** Phase 1 & 2
**Effort:** +30 minutes to implementation

---

### 3. ⚠️ MEDIUM: VisualizerOptions Layout Issues

**Issue:** Component is ~200px wide when expanded, won't fit in proposed 60×40 frame

**VisualizerOptions.swift current UI:**
```swift
VStack {
    Button("Options") { show.toggle() }  // ~60px
    if show {
        Toggle("Spec", ...)  // ~100px
        Slider(..., width: 80)  // 80px slider
        Slider(..., width: 80)  // 80px slider
    }
}
```

**Problem:**
```swift
VisualizerOptions()
    .frame(width: 60, height: 40)  // ← Will clip sliders!
```

**Fix Options:**

**A. Don't constrain frame:**
```swift
VisualizerOptions()
    .at(CGPoint(x: 24, y: 58))
// Let it be natural size, may overlap other elements
```

**B. Position more carefully:**
```swift
VisualizerOptions()
    .at(CGPoint(x: 180, y: 70))  // Away from other controls
```

**C. Redesign for compact size:**
- Remove sliders from initial version
- Just show toggle in smaller frame

**Severity:** MEDIUM - Will work but look wrong
**Impact:** Phase 1 UX
**Effort:** +30 min layout testing

---

### 4. ⚠️ MEDIUM: @Environment Observation Issue

**Issue:** Using `AppSettings.instance()` bypasses SwiftUI observation

**Current plan:**
```swift
// In VisualizerView
private func cycleVisualizerMode() {
    let settings = AppSettings.instance()  // ← Won't trigger re-render!
    settings.visualizerMode = (settings.visualizerMode + 1) % 3
}
```

**Problem:** SwiftUI won't re-render VisualizerView when mode changes

**Fix Required:**
```swift
// Add @Environment to VisualizerView
@Environment(AppSettings.self) var settings

// Then SwiftUI tracks changes automatically
private func cycleVisualizerMode() {
    settings.visualizerMode = (settings.visualizerMode + 1) % 3
    // ✅ SwiftUI observes and re-renders
}
```

**Severity:** MEDIUM - Click won't appear to work
**Impact:** Phase 2
**Effort:** Trivial (add @Environment)

---

### 5. ⚠️ MEDIUM: Oscilloscope Threading Complexity

**Issue:** Waveform sample copying from audio thread not accounted for

**Problem:**
- Audio tap runs on realtime audio thread
- Oscilloscope needs ~1000 time-domain samples
- Must copy to main actor every frame
- Down-sampling required
- Canvas rendering cost

**Current estimate:** 4 hours
**Oracle estimate:** 6-8 hours (includes threading, buffering, performance)

**Additional Work:**
```swift
// Need circular buffer for samples
private var waveformBuffer: CircularBuffer<Float>(capacity: 2048)

// Copy in audio tap (realtime thread)
scratch.withMonoReadOnly { mono in
    waveformBuffer.append(contentsOf: mono)
}

// Snapshot for UI (main thread)
let snapshot = waveformBuffer.latest(76)  // Downsample

// Pass to main actor
Task { @MainActor [snapshot] in
    player.updateWaveformSamples(snapshot)
}
```

**Severity:** MEDIUM - Oscilloscope harder than estimated
**Impact:** Phase 3 timeline
**Effort:** +2-4 hours

---

## Oracle Recommendations

### 1. State Management Strategy

**Don't duplicate state!**

**Option A (Recommended):** Single source of truth in AudioPlayer
```swift
// In AudioPlayer - replace Bool with enum
enum VisualizerMode: Int { case none, spectrum, rms }
var visualizerMode: VisualizerMode = .spectrum

// AppSettings just persists
var persistedVisualizerMode: Int {
    get { UserDefaults.standard.integer(forKey: "visualizerMode") }
    set { UserDefaults.standard.set(newValue, forKey: "visualizerMode") }
}

// Sync on app launch
audioPlayer.visualizerMode = VisualizerMode(rawValue: settings.persistedVisualizerMode) ?? .spectrum
```

**Option B:** Keep AppSettings.visualizerMode, sync to AudioPlayer
```swift
// In AppSettings
var visualizerMode: Int = 1 {
    didSet {
        AudioPlayer.instance().useSpectrumVisualizer = (visualizerMode == 1)
    }
}
```

### 2. Data Exposure Fix

**Must store both datasets:**
```swift
// In AudioPlayer
@MainActor
private var latestRMS: [Float] = []
@MainActor
private var latestSpectrum: [Float] = []

@MainActor
private func updateVisualizerLevels(rms: [Float], spectrum: [Float]) {
    self.latestRMS = rms
    self.latestSpectrum = spectrum
    // Don't discard either!
}

// Expose both:
@MainActor
func getRMSData(bands: Int) -> [Float] { latestRMS }

@MainActor
func getSpectrumData(bands: Int) -> [Float] { latestSpectrum }
```

### 3. VisualizerOptions Layout

**Test first, adjust layout:**
- Don't constrain frame initially
- Let it render at natural size
- Observe what overlaps
- Then decide: reposition, redesign, or accept

### 4. Use @Environment Everywhere

**Pattern:**
```swift
struct VisualizerView: View {
    @Environment(AppSettings.self) var settings  // ✅ Add this
    @Environment(AudioPlayer.self) var audioPlayer

    // Now changes to settings trigger re-renders
}
```

### 5. Defer Oscilloscope

**Oracle Recommendation:**
- Phase 1 & 2 are valuable standalone
- Oscilloscope is nice-to-have
- More complex than estimated
- Do after clutter bar buttons (I, O) complete

---

## Corrected Effort Estimates

**After Oracle Corrections:**

| Phase | Original | Oracle | Reason |
|-------|----------|--------|--------|
| Phase 1 (Expose) | 30 min | 1 hour | Layout testing, data exposure |
| Phase 2 (Click + V) | 2 hours | 3 hours | State wiring, data storage |
| Phase 3 (Oscilloscope) | 4 hours | 6-8 hours | Threading, buffering, performance |

**Total:** 1-12 hours (was 30min-6.5hrs)

---

## Oracle Priority Recommendation

**Do First:**
1. Finish clutter bar buttons (I, O) - established pattern
2. AirPlay integration - user-requested, ready
3. Then visualizer modes - lower priority

**Why:**
- Clutter bar: 2 of 5 done, finish the set
- AirPlay: User-requested, Oracle-reviewed, ready
- Visualizer: Backend exists but needs state refactoring

**Or:** Do Phase 1 only (quick win), defer Phase 2 & 3

---

## Oracle Verdict

**Feasibility:** ✅ YES (with corrections)
**Complexity:** HIGHER than estimated
**Value:** MEDIUM (backend exists, just needs polishing)
**Priority:** LOWER than AirPlay or remaining clutter buttons

**Recommendation:**
1. Implement AirPlay first (Oracle-reviewed, ready)
2. Finish clutter bar (I, O buttons)
3. Then tackle visualizer modes with corrected approach

**Or quick win:** Just expose VisualizerOptions (1 hour), accept imperfect layout

---

**Status:** Task needs updates based on Oracle feedback before implementation
