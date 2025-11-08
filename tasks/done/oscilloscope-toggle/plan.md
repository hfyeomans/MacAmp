# Oscilloscope/RMS Mode Toggle - Implementation Plan

**Date:** 2025-10-30
**Objective:** Expose visualizer mode switching (Spectrum vs RMS, optionally add Oscilloscope)
**Approach:** Phased implementation (Expose existing → Click-to-cycle → Full oscilloscope)

---

## Success Criteria

### MVP (Phase 1 - 30 min)
- ✅ VisualizerOptions button visible
- ✅ Can toggle Spectrum vs RMS modes
- ✅ Backend switches correctly
- ✅ Visual difference observable

### Enhanced (Phase 2 - 2 hours)
- ✅ Visualizer area clickable (webamp pattern)
- ✅ Click cycles through modes
- ✅ V button functional (clutter bar)
- ✅ Keyboard shortcut: Ctrl+V

### Full Feature (Phase 3 - 4 hours)
- ✅ Oscilloscope waveform mode added
- ✅ VISCOLOR colors 18-22 applied
- ✅ 3 modes: Spectrum, Oscilloscope, None
- ✅ Matches webamp behavior

---

## Phase 1: Expose Existing Backend (30 minutes)

### 1.1 Surface VisualizerOptions Component

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

**Add to buildFullWindow() method:**

```swift
// Near spectrum analyzer visualization
buildSpectrumAnalyzer()

// Add visualizer options overlay
VisualizerOptions()
    .frame(width: 60, height: 40)
    .at(CGPoint(x: 24, y: 58)) // Above visualizer area
```

**That's it!** Component already exists and works.

### 1.2 Test Existing Toggle

**Manual Test:**
1. Build and run
2. Click "Options" button above visualizer
3. Toggle "Spec" switch
4. Observe visualizer changes:
   - ON: Spectrum (frequency bars)
   - OFF: RMS (amplitude bars)

**Expected Result:** Immediate mode switching ✅

---

## Phase 2: Click-to-Cycle + V Button (2 hours)

### 2.1 Migrate to visualizerMode Enum

**File:** `MacAmpApp/Models/AppSettings.swift`

**Current scaffolded state (Line ~160):**
```swift
var visualizerMode: Int = 0
```

**Define enum:**
```swift
enum VisualizerMode: Int, CaseIterable {
    case none = 0
    case spectrum = 1
    case rms = 2
    // case oscilloscope = 3  // Future
}
```

**Add helper property:**
```swift
var currentVisualizerMode: VisualizerMode {
    get { VisualizerMode(rawValue: visualizerMode) ?? .spectrum }
    set { visualizerMode = newValue.rawValue }
}
```

**Persist:**
```swift
var visualizerMode: Int = 1 {  // Default to spectrum
    didSet {
        UserDefaults.standard.set(visualizerMode, forKey: "visualizerMode")
    }
}

// Load in init()
self.visualizerMode = UserDefaults.standard.integer(forKey: "visualizerMode")
if self.visualizerMode == 0 && UserDefaults.standard.object(forKey: "visualizerMode") == nil {
    self.visualizerMode = 1  // Default to spectrum on first run
}
```

### 2.2 Make Visualizer Clickable

**File:** `MacAmpApp/Views/VisualizerView.swift`

**Add click handler:**

```swift
var body: some View {
    @Environment(AppSettings.self) var settings

    HStack(spacing: barSpacing) {
        // ... bars
    }
    .onTapGesture {
        cycleVisualizerMode()
    }
}

private func cycleVisualizerMode() {
    let settings = AppSettings.instance()

    // Cycle through modes
    settings.visualizerMode = (settings.visualizerMode + 1) % 3
    // 0 → 1 (none → spectrum)
    // 1 → 2 (spectrum → rms)
    // 2 → 0 (rms → none)
}
```

**Update rendering:**

```swift
// In updateBars() - choose data source
let settings = AppSettings.instance()
let mode = settings.currentVisualizerMode

let frequencyData: [Float]
switch mode {
case .none:
    frequencyData = Array(repeating: 0, count: barCount)
case .spectrum:
    frequencyData = audioPlayer.getFrequencyData(bands: barCount)
case .rms:
    // Get RMS data (need to expose from AudioPlayer)
    frequencyData = audioPlayer.getRMSData(bands: barCount)
}
```

### 2.3 Wire V Button (Clutter Bar)

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

**Update V button:**

```swift
// V - Visualizer Mode (FUNCTIONAL)
let vSpriteName = settings.visualizerMode == 0
    ? "MAIN_CLUTTER_BAR_BUTTON_V"
    : "MAIN_CLUTTER_BAR_BUTTON_V_SELECTED"

Button(action: {
    settings.visualizerMode = (settings.visualizerMode + 1) % 3
}) {
    SimpleSpriteImage(vSpriteName, width: 8, height: 7)
}
.buttonStyle(.plain)
.help("Cycle visualizer mode (Ctrl+V)")
.at(Coords.clutterButtonV)
```

### 2.4 Add Keyboard Shortcut

**File:** `MacAmpApp/AppCommands.swift`

```swift
Button(visualizerModeLabel(settings.visualizerMode)) {
    settings.visualizerMode = (settings.visualizerMode + 1) % 3
}
.keyboardShortcut("v", modifiers: [.control])

// Helper
private func visualizerModeLabel(_ mode: Int) -> String {
    switch mode {
    case 0: return "Enable Visualizer"
    case 1: return "Switch to RMS Mode"
    case 2: return "Disable Visualizer"
    default: return "Cycle Visualizer"
    }
}
```

---

## Phase 3: Add Oscilloscope Waveform (4 hours) - Optional

### 3.1 Expose Time-Domain Samples from AudioPlayer

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

**Add method to get waveform data:**

```swift
func getWaveformSamples(count: Int) -> [Float] {
    // Return time-domain audio samples
    // From audio tap mono buffer
    // Downsample to requested count
}
```

**Implementation needed:**
- Access mono buffer from audio tap
- Downsample to ~76 points (visualizer width)
- Return normalized samples (-1 to 1)

### 3.2 Create Oscilloscope Rendering

**File:** `MacAmpApp/Views/VisualizerView.swift`

**Add oscilloscope view:**

```swift
struct OscilloscopeView: View {
    let samples: [Float]
    let colors: [Color]  // VISCOLOR 18-22

    var body: some View {
        Canvas { context, size in
            let centerY = size.height / 2
            var path = Path()

            for (index, sample) in samples.enumerated() {
                let x = CGFloat(index) / CGFloat(samples.count) * size.width
                let y = centerY - (CGFloat(sample) * centerY)

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            // Color based on amplitude
            let amplitude = abs(samples.max() ?? 0)
            let colorIndex = min(4, Int(amplitude * 4))
            let strokeColor = colors[colorIndex]

            context.stroke(path, with: .color(strokeColor), lineWidth: 1)
        }
        .frame(width: 76, height: 16)
    }
}
```

### 3.3 Update VisualizerView to Support All Modes

```swift
var body: some View {
    let mode = AppSettings.instance().currentVisualizerMode

    Group {
        switch mode {
        case .none:
            Rectangle().fill(Color.black)
        case .spectrum:
            // Current bar visualization
            HStack(spacing: barSpacing) { /* bars */ }
        case .rms:
            // RMS bars (reuse bar UI with RMS data)
            HStack(spacing: barSpacing) { /* bars with RMS data */ }
        case .oscilloscope:
            // Waveform visualization
            OscilloscopeView(
                samples: audioPlayer.getWaveformSamples(count: 76),
                colors: oscilloscopeColors
            )
        }
    }
    .frame(width: 76, height: 16)
    .onTapGesture {
        cycleMode()
    }
}
```

---

## Rollout Strategy

### Day 1: Quick Win (30 min)
- Add VisualizerOptions to main window
- Test Spectrum vs RMS toggle
- Verify works with existing backend
- Document success

### Day 2: Enhanced UX (2 hours)
- Make visualizer clickable
- Wire V button
- Add keyboard shortcut
- Migrate to visualizerMode enum
- Test mode cycling

### Day 3: Full Feature (4 hours) - Optional
- Implement oscilloscope waveform
- Apply VISCOLOR colors 18-22
- Add to mode cycle
- Test all 3 modes

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| VisualizerOptions breaks layout | Low | Low | Test positioning, adjust if needed |
| Mode switching breaks playback | Very Low | Medium | Backend already separates concerns |
| RMS mode not working | Very Low | Low | Backend tested, just needs data exposure |
| Oscilloscope complex | Medium | Low | Defer to Phase 3, MVP works without it |
| VISCOLOR colors wrong | Low | Low | Reference webamp, validate indices |

---

## Testing Strategy

### Phase 1 Testing
- [ ] VisualizerOptions appears
- [ ] Can click "Options" button
- [ ] Toggle "Spec" switch
- [ ] Visualizer changes appearance
- [ ] Spectrum mode shows frequency bars
- [ ] RMS mode shows amplitude bars (different pattern)

### Phase 2 Testing
- [ ] Click visualizer area cycles modes
- [ ] V button cycles modes
- [ ] Ctrl+V keyboard shortcut works
- [ ] Button sprite changes with mode
- [ ] Mode persists across restarts
- [ ] Works with all skins

### Phase 3 Testing (If Implemented)
- [ ] Oscilloscope shows waveform
- [ ] Waveform updates in real-time
- [ ] Colors from VISCOLOR applied
- [ ] Smooth animation
- [ ] Cycle includes oscilloscope

---

## Dependencies

### Existing Components ✅
- AudioPlayer.useSpectrumVisualizer
- AudioPlayer RMS calculation
- AudioPlayer Spectrum calculation
- VisualizerOptions.swift component
- VisualizerView.swift rendering

### Need to Add
- Expose getRMSData() from AudioPlayer (if not already public)
- Oscilloscope rendering (Phase 3)
- Mode cycling logic
- VISCOLOR color application

### Framework Requirements
- ✅ SwiftUI (already using)
- ✅ Accelerate (already using for FFT)
- ✅ Canvas API (for oscilloscope)

---

## Implementation Files

### Files to Modify (Phase 1)
1. `WinampMainWindow.swift` - Add VisualizerOptions (+1 line)

### Files to Modify (Phase 2)
2. `AppSettings.swift` - Add VisualizerMode enum, persistence
3. `VisualizerView.swift` - Add .onTapGesture, mode switching
4. `WinampMainWindow.swift` - Wire V button
5. `AppCommands.swift` - Add Ctrl+V shortcut
6. `AudioPlayer.swift` - Expose getRMSData() if needed

### Files to Create (Phase 3)
7. `OscilloscopeView.swift` - Waveform rendering
8. Or add to VisualizerView.swift as switch case

---

## References

- Research: `tasks/oscilloscope-toggle/research.md`
- Webamp: `webamp_clone/packages/webamp/js/components/Vis.tsx`
- Backend: `MacAmpApp/Audio/AudioPlayer.swift`
- Existing UI: `MacAmpApp/Views/VisualizerOptions.swift`
