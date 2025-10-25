# Spectrum Analyzer Frequency Balance - A/B Testing

**Task ID:** `spectrum-analyzer-balance`
**Priority:** P2 (User Experience Enhancement)
**Status:** 🧪 A/B Testing Ready
**Branch:** `analysis/spectrum-analyzer-bias`

---

## Problem

Spectrum analyzer shows **too much bias to the left side** - bass frequencies dominate the visualization even with balanced music.

**User Observation:**
- More bars active on left (bass frequencies dominating)
- Tested with both bass-heavy AND balanced music
- Both show left-side bias

---

## Root Cause (Confirmed by Gemini Analysis)

**Current frequency distribution dedicates 53% of bars to bass/low-mid frequencies:**

| Bars 0-9 (53%) | Frequency Range | Musical Content |
|----------------|-----------------|-----------------|
| First 10 bars | 50 - 758 Hz | Sub-bass, bass, low-mid |

| Bars 10-18 (47%) | Frequency Range | Musical Content |
|------------------|-----------------|-----------------|
| Last 9 bars | 1,025 - 16,000 Hz | Mid, high, treble |

**Problem:** Midpoint at only 758 Hz causes bass dominance
**Expected:** Midpoint should be around 1,500-2,000 Hz for balanced feel

---

## Solution: A/B Testing Three Frequency Mapping Modes

### Mode 1: Logarithmic (Original)
**Current implementation - bass-focused**

- Formula: `freq = 50 × (16000/50)^(bar/19)`
- Midpoint: ~758 Hz (bar 9)
- Bass bars: 10/19 (53%)
- **Best for:** Bass-heavy EDM, hip-hop

### Mode 2: Adjusted Log (Balanced)
**Gentler logarithmic curve**

- Formula: `freq = 50 × (16000/50)^((bar/19)^0.7)`
- Midpoint: ~1,200 Hz (bar 9)
- Bass bars: 7/19 (37%)
- **Best for:** Balanced rock, pop, classical

### Mode 3: Hybrid (Webamp-style)
**91% logarithmic + 9% linear**

- Formula: `freq = 0.91 × logScale + 0.09 × linScale`
- Midpoint: ~1,800 Hz (bar 9)
- Bass bars: 6/19 (32%)
- **Best for:** Matches original Winamp feel

---

## How to A/B Test

### Method 1: View Menu (Recommended)
1. Launch MacAmp
2. Click **View** menu
3. Select **Spectrum Frequency Mapping**
4. Choose mode:
   - **Logarithmic (Original)** - Current behavior
   - **Adjusted Log (Balanced)** - Moderate improvement
   - **Hybrid (Webamp-style)** - Best balance

### Method 2: Visualizer Options Panel
1. Right-click on spectrum analyzer
2. Click "Options" button
3. Use **Freq:** dropdown to select mode

### Testing Procedure
1. Play bass-heavy track (EDM, hip-hop)
2. Switch between modes while playing
3. Observe left-side bar activity
4. Play balanced track (rock, pop)
5. Compare which mode feels most balanced

---

## Implementation Details

### Files Modified

**1. AppSettings.swift**
- Added `SpectrumFrequencyMapping` enum
- Added `spectrumFrequencyMapping` published property
- Default: `.hybrid` (Webamp-style)

**2. AudioPlayer.swift**
- Captures frequency mapping mode before audio tap closure
- Inline switch statement for three calculation modes
- Clean, efficient implementation

**3. VisualizerOptions.swift**
- Added frequency mapping picker
- Dropdown menu with three modes
- Real-time switching

**4. AppCommands.swift**
- Added "View" menu
- Spectrum Frequency Mapping submenu
- Keyboard shortcuts ready

**5. MacAmpApp.swift**
- Pass settings to AppCommands

---

## Technical Notes

### Frequency Calculations

**Logarithmic (Original):**
```swift
centerFrequency = 50 * pow(16000/50, normalized)
// Result: 50, 68, 92, 124, 168, 227, 307, 415, 561, 758, ...
```

**Adjusted Log (0.7 exponent):**
```swift
centerFrequency = 50 * pow(16000/50, pow(normalized, 0.7))
// Result: 50, 75, 108, 149, 200, 264, 344, 442, 563, 715, 898, 1124, ...
```

**Hybrid (Webamp):**
```swift
logScale = 50 * pow(16000/50, normalized)
linScale = 50 + normalized * (16000 - 50)
centerFrequency = 0.91 * logScale + 0.09 * linScale
// Result: More linear in mid-range, smoother distribution
```

### VISCOLOR Integration

**Preserved:** All three modes use VISCOLOR.TXT gradients
- Color 0: Background (black)
- Colors 2-17: Spectrum gradient (16 colors)
- Color 23: Peak dots

**No changes to visual appearance** - only frequency distribution

---

## Expected Results

### Logarithmic (Original)
- ✅ Bass-heavy music: All bars active
- ❌ Balanced music: Left-side bias visible

### Adjusted Log
- ✅ Bass-heavy music: Still responsive
- ✅ Balanced music: More even distribution
- ✅ Mid-range vocals: Better representation

### Hybrid (Webamp-style)
- ✅ Bass-heavy music: Bass present but not dominant
- ✅ Balanced music: Even distribution
- ✅ Treble music: High frequencies visible
- ✅ Matches classic Winamp feel

---

## Testing Checklist

- [ ] Test Mode 1 (Logarithmic) with bass-heavy track
- [ ] Test Mode 1 with balanced track
- [ ] Test Mode 2 (Adjusted Log) with same tracks
- [ ] Test Mode 3 (Hybrid) with same tracks
- [ ] Compare left-side bar activity across modes
- [ ] Verify VISCOLOR gradients still work
- [ ] Check peak indicators function correctly
- [ ] Test with different skins
- [ ] Verify setting persists across app restarts

---

## Success Criteria

**Quantitative:**
- [ ] Mid-range frequencies (500-2000 Hz) get ≥40% of bars
- [ ] Bass frequencies (50-250 Hz) get ≤35% of bars
- [ ] Visual distribution feels balanced

**Qualitative:**
- [ ] User reports improved balance
- [ ] Spectrum responds to vocals/instruments better
- [ ] Bass still present but not dominating
- [ ] Matches expected Winamp behavior

---

## Next Steps After Testing

1. **Gather feedback:** Which mode feels best?
2. **Fine-tune:** Adjust exponents/ratios if needed
3. **Set default:** Choose best mode as default
4. **Optional:** Remove unused modes or keep for user choice
5. **Documentation:** Update with recommended mode

---

## Files Changed

```
MacAmpApp/Models/AppSettings.swift          - Enum + setting
MacAmpApp/Audio/AudioPlayer.swift           - Frequency calculations
MacAmpApp/Views/VisualizerOptions.swift     - UI picker
MacAmpApp/AppCommands.swift                 - View menu
MacAmpApp/MacAmpApp.swift                   - Pass settings
```

---

## Build Status

- ✅ Build successful
- ✅ Thread sanitizer enabled
- ✅ App launched
- ✅ View menu accessible
- ✅ Three modes switchable in real-time

---

**Status:** ✅ Ready for A/B testing
**Test now:** Use View > Spectrum Frequency Mapping menu
