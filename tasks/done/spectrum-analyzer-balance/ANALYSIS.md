# Spectrum Analyzer Left-Side Bias - Analysis Report

**Task ID:** `spectrum-analyzer-balance`
**Issue:** Too much bias to the left side of spectrum analyzer
**Status:** 🔍 Analysis Complete - Solution Identified
**Date:** 2025-10-24

---

## Problem Statement

**User Observation:**
"The spectrum analyzer has too much bias to the left side - more bars active on left (bass frequencies dominating)"

**Test Conditions:**
- Music types: Bass-heavy (EDM, hip-hop, dubstep) AND Balanced (rock, pop, classical)
- Both types show left-side dominance
- No comparison with original Winamp yet

---

## Root Cause Analysis (Gemini + Code Review)

### Issue: Logarithmic Frequency Distribution

The current implementation dedicates **half of the visualizer bars (0-9) to frequencies below 1 kHz**, while compressing the entire **1 kHz - 16 kHz range into the right half**.

### Current Frequency Distribution (MacAmp)

**Formula:** `centerFrequency = 50 * (16000/50)^(bar_index/19)`

| Bar Index | Center Frequency | Frequency Range | Notes |
|-----------|------------------|-----------------|-------|
| 0 | 50 Hz | Sub-bass | Very low, felt more than heard |
| 1 | 68 Hz | Bass | Kick drum fundamental |
| 2 | 92 Hz | Bass | Bass guitar low notes |
| 3 | 124 Hz | Bass | Male voice fundamental |
| 4 | 168 Hz | Bass/Low-mid | Snare drum body |
| 5 | 227 Hz | Low-mid | Female voice fundamental |
| 6 | 307 Hz | Low-mid | Guitar low strings |
| 7 | 415 Hz | Mid | Vocals, instruments |
| 8 | 561 Hz | Mid | Vocals, horns |
| 9 | 758 Hz | Mid | **← Midpoint at only 758 Hz!** |
| 10 | 1025 Hz | Mid-high | Presence range |
| 11 | 1386 Hz | Mid-high | Clarity |
| 12 | 1874 Hz | High | Sibilance |
| 13 | 2534 Hz | High | Brightness |
| 14 | 3426 Hz | High | Sparkle |
| 15 | 4632 Hz | Very High | Cymbals |
| 16 | 6263 Hz | Very High | Air |
| 17 | 8468 Hz | Very High | Ultra-high shimmer |
| 18 | 11449 Hz | Ultra-high | Near ultrasonic |
| 19 | 16000 Hz | Ultra-high | Extreme treble |

**Problem:** Bars 0-9 (10 bars = 53%) cover only 50-758 Hz (low frequencies)
**Result:** Bass dominates visually even in balanced music

---

## Comparison: MacAmp vs Webamp

### MacAmp (Current)
- **Algorithm:** Goertzel (20 bands → 19 bars)
- **Range:** 50 - 16,000 Hz
- **Scaling:** Pure logarithmic
- **Midpoint:** ~758 Hz (Bar 9)
- **Bass representation:** 10/19 bars (53%)
- **Treble representation:** 9/19 bars (47%)

### Webamp (Reference)
- **Algorithm:** FFT (512 bins → 75 bars)
- **Range:** 0 - 11,025 Hz (Nyquist at 22.05 kHz)
- **Scaling:** Hybrid (91% log + 9% linear)
- **Midpoint:** ~1,800 Hz (Bar 37)
- **Bass representation:** Better distributed
- **Treble representation:** More visual space

**Key Difference:** Webamp's midpoint is **2.4x higher** (1,800 Hz vs 758 Hz), creating more balanced visual distribution.

---

## Technical Details

### Current Goertzel Implementation

**File:** `MacAmpApp/Audio/AudioPlayer.swift` (Lines 838-870)

```swift
let minimumFrequency: Float = 50
let maximumFrequency: Float = min(16000, sampleRate * 0.45)

for b in 0..<bars {
    let normalized = Float(b) / Float(max(1, bars - 1))
    let centerFrequency = minimumFrequency * pow(maximumFrequency / minimumFrequency, normalized)
    // ... Goertzel coefficient calculation ...
}
```

**Mathematical Analysis:**
- Base: 50 Hz
- Ratio: 16000/50 = 320
- Exponent: bar_index / 19
- Result: centerFreq = 50 × 320^(bar/19)

**Problem:** This creates extreme clustering at low frequencies

### Current Frequency Boost

**File:** `MacAmpApp/Views/VisualizerView.swift` (Lines 88-93)

```swift
// Higher frequencies need more boost to be visible
let frequencyBoost: CGFloat = 1.0 + (CGFloat(i) / CGFloat(barCount)) * 0.5

var targetHeight = CGFloat(frequencyData[i]) * maxHeight * amplificationFactor * frequencyBoost
```

**Analysis:**
- Bar 0 (50 Hz): boost = 1.0 (no boost)
- Bar 9 (758 Hz): boost = 1.24 (24% boost)
- Bar 18 (16 kHz): boost = 1.5 (50% boost)

**Issue:** This compensates somewhat but doesn't fix the underlying frequency distribution problem.

---

## Why This Matters

### Musical Frequency Distribution

**Typical Music Energy Distribution:**
- **Sub-bass (20-60 Hz):** 5-10% (felt more than heard)
- **Bass (60-250 Hz):** 15-25% (kick, bass)
- **Low-mid (250-500 Hz):** 15-20% (snare, guitar)
- **Mid (500-2000 Hz):** 30-40% (vocals, most instruments) **← MOST IMPORTANT**
- **High-mid (2000-4000 Hz):** 15-20% (clarity, presence)
- **High (4000-8000 Hz):** 5-10% (cymbals, air)
- **Very high (8000+ Hz):** 1-5% (shimmer)

**Current MacAmp Allocation:**
- Sub-bass to bass (50-250 Hz): **5 bars** (26%)
- Low-mid to mid (250-2000 Hz): **8 bars** (42%)
- High-mid to very high (2000-16000 Hz): **6 bars** (32%)

**Problem:** The most musically important range (500-2000 Hz) is under-represented compared to the bass range.

---

## Solution Options

### Option 1: Adjust Logarithmic Curve (Recommended)

Modify the exponent to create a less steep curve:

```swift
// Current (too steep):
let centerFrequency = minimumFrequency * pow(maximumFrequency / minimumFrequency, normalized)

// Proposed (gentler curve):
let centerFrequency = minimumFrequency * pow(maximumFrequency / minimumFrequency, pow(normalized, 0.7))
```

**Effect:** Pushes midpoint from 758 Hz to ~1,200 Hz

### Option 2: Hybrid Linear/Logarithmic (Webamp Style)

```swift
let logScale = minimumFrequency * pow(maximumFrequency / minimumFrequency, normalized)
let linScale = minimumFrequency + normalized * (maximumFrequency - minimumFrequency)
let centerFrequency = 0.91 * logScale + 0.09 * linScale
```

**Effect:** More balanced distribution, similar to Webamp

### Option 3: Adjust Frequency Range

```swift
let minimumFrequency: Float = 80  // Raise from 50 Hz
let maximumFrequency: Float = 12000  // Lower from 16000 Hz
```

**Effect:** Focus on musically relevant range, reduce extreme bass

### Option 4: Perceptual Weighting (Most Sophisticated)

Use **mel scale** or **bark scale** (matches human hearing):

```swift
// Mel scale approximation
let melMin = 2595 * log10(1 + minimumFrequency/700)
let melMax = 2595 * log10(1 + maximumFrequency/700)
let melFreq = melMin + normalized * (melMax - melMin)
let centerFrequency = 700 * (pow(10, melFreq/2595) - 1)
```

**Effect:** Matches how humans perceive frequency differences

---

## Recommendations

### Immediate Fix (Quickest)

**Option 1: Adjust logarithmic exponent**

**File:** `MacAmpApp/Audio/AudioPlayer.swift` (Line 846)

**Change:**
```swift
// FROM:
let centerFrequency = minimumFrequency * pow(maximumFrequency / minimumFrequency, normalized)

// TO:
let centerFrequency = minimumFrequency * pow(maximumFrequency / minimumFrequency, pow(normalized, 0.7))
```

**Result:**
- Midpoint moves from 758 Hz to ~1,200 Hz
- Better mid-range representation
- Less bass dominance
- **Estimated impact:** Moderate improvement

### Better Fix (Webamp-Style)

**Option 2: Hybrid scaling**

Matches webamp_clone's proven approach:

```swift
let logScale = minimumFrequency * pow(maximumFrequency / minimumFrequency, normalized)
let linScale = minimumFrequency + normalized * (maximumFrequency - minimumFrequency)
let centerFrequency = 0.91 * logScale + 0.09 * linScale
```

**Result:**
- More balanced across all ranges
- Similar feel to original Winamp
- **Estimated impact:** Significant improvement

### Best Fix (Perceptual)

**Option 4: Mel scale**

Most accurate to human hearing:

```swift
func frequencyFromMel(_ mel: Float) -> Float {
    return 700 * (pow(10, mel / 2595) - 1)
}

func melFromFrequency(_ freq: Float) -> Float {
    return 2595 * log10(1 + freq / 700)
}

let melMin = melFromFrequency(minimumFrequency)
let melMax = melFromFrequency(maximumFrequency)
let melFreq = melMin + normalized * (melMax - melMin)
let centerFrequency = frequencyFromMel(melFreq)
```

**Result:**
- Perceptually uniform distribution
- Matches how we hear music
- **Estimated impact:** Best long-term solution

---

## Additional Factors

### Amplification

**Current:** Uniform 4x gain (`value = min(1.0, value * 4.0)`)

**Could improve with frequency-dependent gain:**
```swift
// Lower bass gain, maintain mid/high gain
let frequencyGain = b < 5 ? 3.0 : 4.0  // Reduce bass boost
value = min(1.0, value * frequencyGain)
```

### Visual Compensation

**Current:** `frequencyBoost` increases with bar index (1.0 → 1.5)

**Already helps, but limited by underlying frequency distribution**

---

## Testing Strategy

1. **Baseline:** Screenshot current spectrum with test music
2. **Test Option 1:** Adjust exponent to 0.7, observe
3. **Test Option 2:** Implement hybrid scaling, compare
4. **Test Option 4:** Implement mel scale, validate
5. **A/B Test:** Compare all three side-by-side

**Test Music:**
- Bass-heavy: EDM track with strong sub-bass
- Balanced: Rock/pop with vocals and drums
- Treble-heavy: Acoustic guitar or strings

**Success Criteria:**
- Mid-range (500-2000 Hz) gets more visual representation
- Bass (50-250 Hz) less dominant
- High frequencies (4000+ Hz) still responsive
- Feels balanced with various music genres

---

## Files to Modify

**Primary:**
- `MacAmpApp/Audio/AudioPlayer.swift` (Line 846) - Frequency calculation

**Secondary (if needed):**
- `MacAmpApp/Audio/AudioPlayer.swift` (Line 862) - Gain adjustment
- `MacAmpApp/Views/VisualizerView.swift` (Lines 88-93) - Visual boost

**Testing:**
- `MacAmpApp/Views/VisualizerOptions.swift` - Runtime controls

---

## References

**Gemini Analysis:** Complete frequency-to-bar mapping comparison
**Webamp Implementation:** `/webamp_clone/packages/webamp/js/components/VisPainter.ts`
**MacAmp Implementation:** Lines documented above

---

## Next Steps

1. **Clarify with user:** Which solution approach to test first?
2. **Implement fix:** Modify frequency calculation
3. **Visual test:** Compare before/after with same music
4. **Fine-tune:** Adjust exponent or hybrid ratio as needed
5. **Validate:** Test with multiple genres

---

**Status:** ✅ Root cause identified - Ready for implementation
**Recommendation:** Start with Option 1 (quickest), then try Option 2 (webamp-style)
