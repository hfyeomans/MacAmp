# EQ Slider Implementation Plan

**Status:** Planning systematic approach
**Based on:** Volume/Balance slider success

---

## 📊 Current State Analysis

### EQSliderView.swift - What's Wrong:
```swift
Image(nsImage: background)
    .resizable()  // ❌ WRONG - distorts sprite grid!
    .frame(width: 14, height: 129)
    .offset(y: calculateBackgroundOffset())
```

**Issues:**
1. Uses `.resizable()` (we know this breaks sprites!)
2. Wrong modifier order (offset before final frame)
3. Doesn't handle 2D grid positioning (x AND y)

---

## 🎯 The Correct Approach (from webamp)

### Webamp's Band.tsx Formula:

```javascript
// Line 19-22: Calculate sprite number (0-27) from value
const spriteNumber = (value: number): number => {
  const percent = value / 100;  // 0-100 → 0.0-1.0
  return Math.round(percent * 27);  // 0 to 27
};

// Line 25-28: Convert sprite to 2D grid position
const spriteOffsets = (number: number) => {
  const x = number % 14;        // Column: 0-13
  const y = Math.floor(number / 14);  // Row: 0 or 1
  return { x, y };
};

// Line 46-48: Calculate pixel offsets
const xOffset = x * 15;  // Each sprite 15px wide
const yOffset = y * 65;  // Each row 65px tall
backgroundPosition: `-${xOffset}px -${yOffset}px`
```

### What This Means:

**For sprite 0 (lowest value):**
- Grid: x=0, y=0 (top-left)
- Offset: -0px, -0px
- Shows: Top-left sprite

**For sprite 14 (middle value):**
- Grid: x=0, y=1 (bottom-left)
- Offset: -0px, -65px
- Shows: Bottom-left sprite

**For sprite 27 (highest value):**
- Grid: x=13, y=1 (bottom-right)
- Offset: -195px, -65px
- Shows: Bottom-right sprite

---

## ✅ The Swift Solution

### Step-by-Step Fix:

**1. Remove .resizable()** (just like Volume)

**2. Apply correct modifier order:**
```swift
.frame(width: 14, height: 63, alignment: .topLeading)  // Frame first!
.offset(x: xOffset, y: yOffset)  // BOTH x and y offset
.clipped()  // Clip last
```

**3. Calculate 2D sprite position:**
```swift
private func calculateEQSpriteOffset() -> (x: CGFloat, y: CGFloat) {
    // Map value (-12 to +12 dB) to 0-1
    let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    let percent = min(max(CGFloat(normalized), 0), 1)

    // Calculate sprite (0-27)
    let sprite = Int(round(percent * 27.0))

    // 2D grid position
    let gridX = sprite % 14  // Column
    let gridY = sprite / 14  // Row (0 or 1)

    // Pixel offsets
    let xOffset = -CGFloat(gridX) * 15.0  // Negative shifts left
    let yOffset = -CGFloat(gridY) * 65.0  // Negative shifts up

    return (xOffset, yOffset)
}
```

**4. Update Image rendering:**
```swift
let (xOff, yOff) = calculateEQSpriteOffset()

Image(nsImage: background)
    .interpolation(.none)
    .frame(width: 14, height: 63, alignment: .topLeading)
    .offset(x: xOff, y: yOff)  // 2D positioning!
    .clipped()
    .allowsHitTesting(false)
```

---

## 🧪 Testing Plan

### Verification:
1. **At -12dB (bottom):** Should show sprite 0 (low/green tones)
2. **At 0dB (center):** Should show sprite 14 (middle sprite)
3. **At +12dB (top):** Should show sprite 27 (high/red tones)

### Test Skins:
- Classic Winamp (yellow/green EQ gradients)
- Internet Archive (different color scheme)

---

## 🎓 Applying Volume Lessons

✅ **Don't use .resizable()**
✅ **Modifier order: frame → offset → clip**
✅ **Use exact pixel values (15px, 65px)**
✅ **Test incrementally**
✅ **Add logging to verify calculations**

---

**Ready to implement:** Apply this exact pattern to EQSliderView.swift
