# VISCOLOR Spectrum Analyzer - Research

**Date:** 2025-10-23
**Task:** Apply VISCOLOR.TXT colors to spectrum analyzer
**Status:** Research in progress

---

## 🔍 Current State Analysis

### ✅ Infrastructure Already Exists!

**1. Parser:** `MacAmpApp/Models/VisColorParser.swift`
- Parses VISCOLOR.TXT from skin archive
- Converts RGB triplets to SwiftUI Color array
- Returns 24 colors (indices 0-23)

**2. Storage:** `MacAmpApp/Models/Skin.swift`
- `Skin.visualizerColors: [Color]` property exists
- Populated during skin load

**3. Loading:** `MacAmpApp/ViewModels/SkinManager.swift:505-513`
- Extracts VISCOLOR.TXT from .wsz archive
- Calls `VisColorParser.parse()`
- Stores in `Skin.visualizerColors`

### ❌ Missing: Color Application

**File:** `MacAmpApp/Views/VisualizerView.swift:150-184`

**Current:** Hardcoded green/yellow/red gradients
```swift
if normalizedHeight < greenThreshold {
    return LinearGradient(colors: [
        Color(red: 0, green: 0.6, blue: 0),  // HARDCODED!
        Color(red: 0, green: 1, blue: 0)
    ], ...)
}
```

**Problem:** Ignores `skinManager.currentSkin?.visualizerColors`

---

## 📋 VISCOLOR.TXT Color Map (24 Colors)

From Classic Winamp skin:

```
Color Index | RGB           | Usage
------------|---------------|----------------------------------
0           | 0,0,0         | Black (background)
1           | 24,33,41      | Grey for dots
2-17        | (gradient)    | Spectrum analyzer (16 colors)
  2         | 239,49,16     | Top of spectrum (RED)
  3-9       | (transition)  | Red → Yellow gradient
  10-17     | (transition)  | Yellow → Green gradient
  17        | 24,132,8      | Bottom of spectrum (GREEN)
18-22       | (whites)      | Oscilloscope (5 shades)
  18        | 255,255,255   | OSC brightest
  19-22     | (dimming)     | OSC fade levels
23          | 150,150,150   | Analyzer peak dots
```

---

## 🎨 Spectrum Analyzer Color Usage

### Winamp Convention

**16-Level Gradient** (Colors 2-17):
- **Bottom bars** (low amplitude) → Color 17 (green)
- **Middle bars** (medium) → Colors 10-16 (yellow)
- **Top bars** (high) → Colors 2-9 (red)

**Peak Dots:** Color 23 (gray)

### Rendering Strategy

Map bar height (0-16px) to color index (2-17):
```swift
let colorIndex = 2 + Int((height / maxHeight) * 15)  // Maps 0-16px to colors 2-17
let barColor = visualizerColors[colorIndex]
```

---

## 🔍 Webamp Implementation (Pending Gemini Analysis)

Researching via Gemini:
- How colors are applied to spectrum bars
- Canvas rendering vs gradient approach
- Color interpolation strategy
- Skin switching behavior

---

**Research Status:** ⏳ IN PROGRESS
**Next:** Analyze webamp, design implementation
