# Phase 3: Base Mechanism Layer - Implementation Plan

**Branch:** phase3-base-mechanism-layer
**Goal:** Separate slider functionality from skin presentation
**Status:** Planning

---

## 🎯 Objective

Create a **BaseSliderControl** that provides full slider functionality WITHOUT requiring any skin sprites, following the research guidance:

> "Skin rendering should be a separate dependent module that consumes state via accessor functions"

---

## 📊 Current Analysis

### WinampVolumeSlider (Current Implementation)

**What it does RIGHT ✅:**
- Color gradient channel (green→yellow→red) - FUNCTIONAL
- DragGesture interaction - FUNCTIONAL
- Value binding - FUNCTIONAL
- Center notch on balance - FUNCTIONAL

**What couples it to skins ❌:**
- REQUIRES `background: NSImage` parameter (VolumeSliderView.swift:5)
- REQUIRES `thumb: NSImage` parameter (VolumeSliderView.swift:6)
- Crashes if skin not loaded (no fallback)

### What Your Screenshots Reveal

**Comparing Classic vs Internet Archive:**
- ✅ Center channel gradient is IDENTICAL (green→yellow→red)
- ✅ Balance center notch is IDENTICAL
- ❌ Only the BACKGROUND texture changes (green bars vs chrome)
- ❌ Only the THUMB sprite changes

**Key Insight:** The functional indicators (gradient, center line) are NOT skin-dependent!

---

## 🏗️ Proposed Architecture

### Layer 1: BaseSliderControl (Pure Mechanism)

```swift
struct BaseSliderControl: View {
    @Binding var value: Float  // 0.0 to 1.0
    let width: CGFloat
    let height: CGFloat
    let centerValue: Float? = nil  // For balance: 0.0 is center

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let x = drag.location.x
                            value = Float(max(0, min(1, x / geo.size.width)))
                        }
                )
        }
        .frame(width: width, height: height)
    }
}
```

### Layer 2: FunctionalIndicators (Always Present)

```swift
struct SliderIndicators: View {
    let value: Float
    let width: CGFloat
    let height: CGFloat
    let mode: IndicatorMode

    enum IndicatorMode {
        case volume    // Green→red gradient
        case balance   // Green at center, red at edges
    }

    var body: some View {
        ZStack {
            // Dark groove
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.3))
                .frame(width: width, height: 7)

            // Colored channel (gradient based on value)
            RoundedRectangle(cornerRadius: 2.5)
                .fill(channelGradient)
                .frame(width: width - 2, height: 5)

            // Center notch (if balance mode)
            if case .balance = mode {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 1, height: 7)
                    .offset(x: width / 2)
            }
        }
    }

    var channelGradient: Color {
        // Same gradient logic as current WinampVolumeSlider
        // This is FUNCTIONAL, not decorative!
    }
}
```

### Layer 3: SkinOverlay (Optional)

```swift
struct SkinnedSlider: View {
    @Binding var value: Float
    let width: CGFloat
    let height: CGFloat
    @EnvironmentObject var skinManager: SkinManager

    var body: some View {
        ZStack {
            // BASE: Always works
            BaseSliderControl(value: $value, width: width, height: height)

            // INDICATORS: Always visible
            SliderIndicators(value: value, width: width, height: height, mode: .volume)

            // SKIN: Optional enhancement
            if let skin = skinManager.currentSkin {
                if let bg = skin.images["MAIN_VOLUME_BACKGROUND"] {
                    // Frame-based background positioning
                    Image(nsImage: bg)
                        .resizable()
                        .frame(height: 420)
                        .offset(y: calculateFrameOffset(value))
                        .frame(height: height)
                        .clipped()
                }

                if let thumb = skin.images["MAIN_VOLUME_THUMB"] {
                    // Thumb sprite
                    Image(nsImage: thumb)
                        .offset(x: calculateThumbPosition(value))
                }
            } else {
                // NO SKIN: Plain thumb (simple rectangle)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 14, height: 11)
                    .offset(x: calculateThumbPosition(value))
            }
        }
    }
}
```

---

## 📝 Implementation Steps

### Step 1: Create BaseSliderControl.swift

**File:** `MacAmpApp/Views/Components/BaseSliderControl.swift` (NEW)

**Contents:**
- BaseSliderControl struct (pure drag interaction)
- SliderIndicators struct (gradient + center notch)
- Helper functions for gradient calculation

**Tests:**
- Works with @State binding
- Returns proper 0.0-1.0 values
- Renders without any skin

### Step 2: Refactor WinampVolumeSlider

**Current pattern:**
```swift
WinampVolumeSlider(volume: $audioPlayer.volume)
    @EnvironmentObject var skinManager: SkinManager
    // Uses SimpleSpriteImage for thumb
```

**New pattern:**
```swift
struct WinampVolumeSlider: View {
    @Binding var volume: Float
    @EnvironmentObject var skinManager: SkinManager

    var body: some View {
        ZStack {
            // Layer 1: Base (always works)
            BaseSliderControl(value: $volume, width: 68, height: 13)

            // Layer 2: Indicators (always visible)
            SliderIndicators(value: volume, mode: .volume)

            // Layer 3: Skin (optional)
            if let skin = skinManager.currentSkin {
                SkinVolumeOverlay(value: volume, skin: skin)
            }
        }
    }
}
```

### Step 3: Test Skinless Mode

**Test procedure:**
1. Comment out skin loading in SkinManager
2. Launch app
3. **Expected:** Sliders show gradient channels, work perfectly
4. **Verify:** Can control volume/balance without sprites

### Step 4: Apply to All Sliders

- WinampVolumeSlider ✅
- WinampBalanceSlider
- EQSliderView (10 sliders)
- Preamp slider

---

## 🎯 Success Criteria

### Must Achieve:
- ✅ Sliders work WITHOUT any skin loaded
- ✅ Functional indicators always visible
- ✅ Skin backgrounds are OPTIONAL enhancements
- ✅ All existing skins still work perfectly
- ✅ Code is cleaner (separation of concerns)

### Verification Tests:
1. **No skin loaded:** Sliders functional with plain visuals
2. **Classic Winamp:** Green volume background visible
3. **Internet Archive:** Chrome volume background visible
4. **Skinless vs Skinned:** Both work, skinned looks better

---

## 🚨 Potential Issues

### Issue 1: Frame-Based Background Positioning
Current implementation offsets entire 420px image. Without skin, this logic is unused.

**Solution:** Extract to SkinOverlay component only.

### Issue 2: Thumb Sprites
Current thumb is SimpleSpriteImage. Without skin, needs fallback.

**Solution:** Plain Rectangle() as fallback thumb.

### Issue 3: EQ Sliders Are Vertical
Volume/Balance are horizontal (x-axis drag). EQ/Preamp are vertical (y-axis drag).

**Solution:** BaseSliderControl should support both orientations.

---

## 📚 Research References

### From WinampandWebampFunctionalityResearch.md:

**Section 1.4:**
> "State Management and Playback Control primitives form the foundational core.
> Skin rendering should be developed as separate, dependent modules that consume
> state via accessor functions."

**Table 6.1 - Priority 1 Functions:**
- PC-06: setVolume(level: 0-100)
- PC-07: setBalance(level: -100 to 100)
- SM-04: getVolume() → number
- SM-05: getBalance() → number

**Key principle:** Volume/Balance are STATE, not VISUALS. The mechanism should work independently of presentation.

---

## 🔄 Rollback Plan

If this approach doesn't work or causes regressions:

```bash
git checkout feature/sprite-resolver-architecture
git branch -D phase3-base-mechanism-layer
git checkout -b phase3-semantic-migration  # Try Option B instead
```

Phase 1 & 2 work is safe! ✅

---

**Status:** Ready to implement
**Estimated Time:** 2-3 hours
**Risk:** Low (can easily rollback)
**Benefit:** True separation of mechanism from presentation
