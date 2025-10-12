# Base Player + Skin Overlay Architecture

**Critical Understanding:** 2025-10-12

---

## The Fundamental Principle

> "When the functionalities of the underlying player don't have a skin they are plain, the skins change the elements of the underlying functionalities."

### What This Means

**Base Player** (No Skin):
- Timer counts seconds → Shows as plain text "00:01"
- Volume control → Native SwiftUI Slider (0-100%)
- Play button → Plain button with "▶" text
- EQ sliders → Basic vertical sliders
- **ALL FUNCTIONAL, just plain/ugly**

**Skin Overlay** (Visual Enhancement):
- Replaces plain "00:01" with sprite digits
- Replaces native slider with VOLUME.BMP + thumb sprite
- Replaces "▶" text with MAIN_PLAY_BUTTON sprite
- Replaces plain EQ sliders with skin graphics
- **VISUAL ONLY, doesn't change functionality**

---

## Webamp's Implementation

### Volume Slider Example

**Mechanism (Always Works):**
```javascript
// Volume.tsx (lines 18-34)
return (
  <input
    type="range"
    min="0"
    max="100"
    value={volume}
    onChange={(e) => setVolume(Number(e.target.value))}
  />
);
```

**This is a NATIVE HTML range slider!**
- Works WITHOUT any styling
- Fully functional (drag, click, keyboard)
- Ugly but works

**Presentation (Skin Layer):**
```javascript
// MainVolume.tsx (lines 13-19)
const offset = (sprite - 1) * 15;
const style = {
  backgroundPosition: `0 -${offset}px`,
};

return (
  <div id="volume" style={style}>
    <Volume />  {/* The functional input inside */}
  </div>
);
```

**CSS (Skin-Specific):**
```css
#webamp #volume {
  background-image: url('./VOLUME.BMP');  /* Skin provides this */
  background-position: 0 0;               /* JS updates this */
}

#webamp #volume input {
  opacity: 0;  /* Hide native slider appearance */
}

#webamp #volume input::-webkit-slider-thumb {
  background-image: url('./MAIN_VOLUME_THUMB.png');  /* Skin provides */
  opacity: 1;  /* Show custom thumb */
}
```

**Result:**
- Input works (mechanism)
- Skin overlays visual appearance
- Without skin CSS, input still works (just plain HTML slider)

---

## MacAmp's Current Implementation (Broken)

### Volume Slider Example

**Current Code (VolumeSliderView.swift):**
```swift
var body: some View {
    ZStack(alignment: .leading) {
        // Skin background (REQUIRED!)
        Image(nsImage: background)
            .resizable()
            // ... positioning code ...

        // Skin thumb (REQUIRED!)
        Image(nsImage: thumb)
            .resizable()
            // ... positioning code ...

        // Gesture (mechanism)
        Color.clear
            .gesture(DragGesture()...)
    }
}
```

**Problems:**
1. ❌ REQUIRES `background` parameter (crashes if nil)
2. ❌ REQUIRES `thumb` parameter (crashes if nil)
3. ❌ NO fallback to plain slider
4. ❌ Mechanism and presentation tightly coupled

**If skin doesn't have MAIN_VOLUME_BACKGROUND:**
- View can't render
- Transparent fallback created but looks broken
- Not functional without skin

---

## MacAmp's Required Architecture (Fix)

### Layered Approach

**Layer 1: Base Mechanism (Always Present)**
```swift
struct VolumeControl: View {
    @Binding var volume: Float

    var body: some View {
        // NATIVE SwiftUI Slider (or custom gesture)
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            let normalized = gesture.location.x / geo.size.width
                            volume = Float(max(0, min(1, normalized)))
                        }
                )
        }
        .frame(width: 68, height: 13)
    }
}
```

**This ALWAYS works, even with NO skin!**

**Layer 2: Skin Overlay (Optional Enhancement)**
```swift
struct SkinnedVolumeControl: View {
    @EnvironmentObject var skinManager: SkinManager
    @Binding var volume: Float

    var body: some View {
        ZStack {
            // Base mechanism (always present)
            VolumeControl(volume: $volume)

            // Skin overlay (if available)
            if let skin = skinManager.currentSkin {
                // Background from skin
                if let background = skin.images["MAIN_VOLUME_BACKGROUND"] {
                    Image(nsImage: background)
                        // ... frame positioning ...
                }

                // Thumb from skin
                if let thumb = skin.images["MAIN_VOLUME_THUMB"] {
                    Image(nsImage: thumb)
                        // ... positioning based on volume ...
                }
            } else {
                // No skin: Show plain visual feedback
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: 68 * CGFloat(volume), height: 13)
            }
        }
    }
}
```

---

## Time Display Example

### Webamp (Decoupled)

**Mechanism:**
```javascript
// Time.tsx
const seconds = timeElapsed;  // Just a number
const timeObj = getTimeObj(seconds);  // Convert to digits

return (
  <div className="digit digit-{timeObj.minutesFirstDigit}" />
);
```

**Native behavior:** Without CSS, shows as empty `<div>` (useless visually but structurally present)

**Skin CSS:**
```css
.digit {
  background-image: url(NUMBERS.BMP);
  width: 9px; height: 13px;
}
.digit-0 { background-position: 0px 0px; }
```

### MacAmp Current (Coupled)

```swift
SimpleSpriteImage("DIGIT_\(digits[0])", width: 9, height: 13)
```

**Problems:**
- Assumes sprite exists
- Hardcodes sprite name
- No fallback to plain rendering

### MacAmp Required (Decoupled)

```swift
// Mechanism: Convert time to digits
let digits = timeDigits(from: audioPlayer.currentTime)

// Presentation: Render with skin or plain
if let skin = skinManager.currentSkin {
    // Try semantic resolution
    if let digitSprite = skin.images[resolver.resolve(.digit(digits[0]))] {
        Image(nsImage: digitSprite)
    } else {
        // Fallback: Plain text
        Text("\(digits[0])")
            .font(.system(size: 13, design: .monospaced))
    }
} else {
    // No skin: Plain text
    Text("\(digits[0])")
}
```

---

## The Complete Picture

### Webamp's Stack

```
┌─────────────────────────────────┐
│   SKIN CSS (Presentation)       │ ← Swappable
│   - Maps .digit-0 to sprite     │
│   - Provides background images  │
├─────────────────────────────────┤
│   COMPONENTS (Bridge)            │ ← Stable
│   - Renders semantic HTML       │
│   - <div class="digit digit-0"> │
├─────────────────────────────────┤
│   STATE (Mechanism)              │ ← Stable
│   - Timer updates currentTime   │
│   - Volume tracks 0-100          │
│   - Redux store                  │
└─────────────────────────────────┘
```

**Key:** Bottom two layers NEVER change. Only top layer (CSS) changes per skin.

### MacAmp's Current Stack (Wrong)

```
┌─────────────────────────────────┐
│   ALL LAYERS MIXED              │
│   - Hardcoded sprite names      │
│   - Requires skin to function   │
│   - No separation of concerns   │
└─────────────────────────────────┘
```

### MacAmp's Required Stack (Correct)

```
┌─────────────────────────────────┐
│   SPRITE RESOLVER (Presentation)│ ← Swappable per skin
│   - Maps .digit(0) to "DIGIT_0" │
│   - Or to "DIGIT_0_EX"          │
│   - Falls back to plain if nil  │
├─────────────────────────────────┤
│   VIEWS (Bridge)                 │ ← Stable
│   - Semantic sprite requests    │
│   - SimpleSpriteImage(.digit(0))│
├─────────────────────────────────┤
│   STATE (Mechanism)              │ ← Stable
│   - Timer updates currentTime   │
│   - AudioPlayer tracks values   │
│   - @Published properties       │
└─────────────────────────────────┘
```

---

## Why Current Fixes Don't Fully Work

### My Slider Fixes (Partial Success)

**What I did:**
- Changed VolumeSliderView to use `background: NSImage`
- Removed programmatic gradients
- Added frame-based positioning

**Why it's incomplete:**
- Still REQUIRES background parameter
- No fallback if sprite missing
- Assumes skin provides multi-frame VOLUME.BMP
- Crashes if called with nil background

### My Digit Fixes (Partial Success)

**What I did:**
- Added .onChange(of: audioPlayer.currentTime)
- Created sprite aliases (DIGIT_0_EX → DIGIT_0)

**Why it's incomplete:**
- Still hardcodes sprite names
- Aliasing is band-aid, not architectural fix
- Doesn't work if skin truly missing digits
- No plain text fallback

---

## The Real Solution

### Phase 1: Add Base Mechanisms (Fallback Layer)

**For sliders:**
```swift
// Base mechanism that ALWAYS works
private var baseMechanism: some View {
    GeometryReader { geo in
        Color.clear
            .gesture(DragGesture()...)  // Mechanism
    }
}

// Skin overlay (optional)
private var skinOverlay: some View {
    if let skin = skinManager.currentSkin {
        // Try to get background
        if let bg = skin.images["MAIN_VOLUME_BACKGROUND"] {
            // Render with skin
        } else {
            // Fallback: Plain rectangle showing volume level
            Rectangle()
                .fill(Color.green.opacity(0.5))
                .frame(width: 68 * CGFloat(volume), height: 13)
        }
    }
}

var body: some View {
    ZStack {
        baseMechanism  // Always present
        skinOverlay     // Optional prettification
    }
}
```

**For digits:**
```swift
private func digitView(_ digit: Int) -> some View {
    if let skin = skinManager.currentSkin,
       let sprite = skin.images[resolver.resolve(.digit(digit))] {
        // Skin-based digit
        Image(nsImage: sprite)
    } else {
        // Plain text fallback
        Text("\(digit)")
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundColor(.green)
    }
}
```

### Phase 2: Integrate SpriteResolver

**Update SimpleSpriteImage:**
```swift
init(_ semantic: SemanticSprite)  // New
init(_ hardcoded: String)         // Legacy (keep for backward compat)
```

### Phase 3: Migrate Components

**Priority order:**
1. Time display (most critical - proves architecture)
2. Volume/balance sliders
3. Transport buttons
4. EQ sliders
5. Everything else

---

## Testing Evidence

### Your Observations

| Component | Classic Winamp | Internet Archive | Winamp3 Classified |
|-----------|----------------|------------------|--------------------|
| Digits increment | ✅ Works | ❌ Broken | ✅ Works |
| Volume slider | ✅ Green gradient | ❌ Still green | ✅ Works |
| EQ sliders | ✅ Green | ❌ Still green | ✅ Works |

**Pattern:** Internet Archive breaks because code assumes specific sprite names

**Why Winamp3 Classified works:** Has BOTH variants (DIGIT_0 AND DIGIT_0_EX)

**Why Classic works:** Code hardcoded for its sprite names

**Why Internet Archive fails:** Uses different sprite conventions

---

## Immediate Next Steps

### Option A: Quick Fix (Session Scope)
1. Focus ONLY on time display
2. Add proper .onChange() and .id() modifiers
3. Verify digits increment
4. Document architectural debt
5. Plan full refactor for next session

### Option B: Proper Fix (Multi-Session)
1. Design base mechanism layer
2. Integrate SpriteResolver fully
3. Update all views with fallback rendering
4. Test exhaustively with multiple skins
5. Remove all hardcoded sprite assumptions

### Option C: Hybrid (Recommended)
1. **This session:** Fix time display properly with SpriteResolver
2. Document current architecture issues
3. **Next session:** Systematic refactor of all components
4. Implement base mechanism layer
5. Full testing across many skins

---

## Current Session Status

**Token Usage:** ~367k / 1M (63% remaining)
**Time Invested:** Significant research and fixes
**Code Quality:** Better than before but not architecturally sound
**Recommendation:** Document findings, fix time display as proof-of-concept, plan full refactor

---

**What should we prioritize for THIS session?**

A. Quick fix time display + document debt
B. Start full refactor (risky, large scope)
C. Just document and plan for next session
