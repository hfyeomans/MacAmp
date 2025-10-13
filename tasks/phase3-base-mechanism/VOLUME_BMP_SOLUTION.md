# VOLUME.BMP Frame Rendering - SOLVED ✅

**Date:** 2025-10-12, 10:07 PM
**Issue:** Volume slider gradient showed red at 50%, blank after
**Solution:** SwiftUI modifier order is critical!

---

## 🎯 The Working Formula

### Correct SwiftUI Modifier Chain:

```swift
Image(nsImage: volumeBg)
    .interpolation(.none)
    .frame(width: 68, height: 13, alignment: .top)  // 1. FRAME FIRST!
    .offset(y: calculateVolumeFrameOffset())        // 2. THEN OFFSET
    .clipped()                                       // 3. THEN CLIP
    .allowsHitTesting(false)
```

### Frame Offset Calculation:

```swift
private func calculateVolumeFrameOffset() -> CGFloat {
    let percent = min(max(CGFloat(volume), 0), 1)  // Clamp 0-1
    let sprite = Int(round(percent * 28.0))         // 0 to 28
    let frameIndex = min(27, max(0, sprite - 1))    // Clamp to 0-27
    let offset = CGFloat(frameIndex) * 15.0         // Each frame 15px
    return -offset  // Negative shifts image UP, revealing lower frames
}
```

---

## 🔑 Key Insights

### 1. Modifier Order Matters!

**WRONG (broken):**
```swift
.offset(y: offset) → .frame() → .clipped()  // ❌ Clips before framing
```

**RIGHT (works):**
```swift
.frame(alignment: .top) → .offset(y: offset) → .clipped()  // ✅ Frame, shift, clip
```

### 2. VOLUME.BMP Structure

- **Total size:** 68×433px
- **Usable frames:** First 420px (28 frames × 15px)
- **Unused footer:** Last 13px (y:420-433) contains thumb sprites
- **Frame order:** Green at TOP (y:0), Red at BOTTOM (y:405)

### 3. Frame Mapping

```
Volume 0%   → Sprite 0  → Frame 0  → Offset 0    → y:0-13   (GREEN)
Volume 50%  → Sprite 14 → Frame 13 → Offset -195 → y:195-208 (YELLOW)
Volume 100% → Sprite 28 → Frame 27 → Offset -405 → y:405-418 (RED)
```

### 4. Webamp's Approach (Reference)

From MainVolume.tsx:
```javascript
const sprite = Math.round(percent * 28);
const offset = (sprite - 1) * 15;
style = { backgroundPosition: `0 -${offset}px` };
```

CSS `background-position: 0 -${offset}px` shifts background UP.
SwiftUI `.offset(y: -offset)` shifts image UP.
**Same direction!**

---

## 📋 Apply This Pattern To:

### Balance Slider (BALANCE.BMP)
- **Size:** 38×433px (webamp uses 38×420)
- **Frames:** 28 frames × 15px
- **Range:** -1.0 (left) to 1.0 (right)
- **Mapping:** Convert balance to 0-1 range, then use same formula

```swift
let percent = (balance + 1.0) / 2.0  // -1..1 → 0..1
let sprite = Int(round(percent * 28.0))
let frameIndex = min(27, max(0, sprite - 1))
return -CGFloat(frameIndex) * 15.0
```

### EQ Sliders (Vertical - different!)
- **Size:** Varies, typically tall and thin
- **Orientation:** VERTICAL (not horizontal)
- **Direction:** Likely INVERTED (top = high, bottom = low)
- Need separate analysis

### Preamp Slider
- Same as EQ sliders (vertical)

---

## ⚠️ Common Mistakes to Avoid

1. **Don't use `.resizable()`** - Image is already correct size!
2. **Don't calculate fractional frame heights** - Use exactly 15px
3. **Don't put offset before frame** - Modifier order is critical
4. **Don't forget alignment: .top** - Centers by default otherwise
5. **Don't use 433px height** - Only first 420px are frames

---

## 🧪 Verification Checklist

After implementing:
- [ ] Green at 0% (far left)
- [ ] Yellow/orange at 50% (center)
- [ ] Red at 100% (far right)
- [ ] No blank areas anywhere
- [ ] Smooth gradient progression
- [ ] Slider functional throughout range
- [ ] Works in Classic, Internet Archive, all skins

---

**Status:** ✅ SOLVED for Volume
**Next:** Apply to Balance, then EQ/Preamp
