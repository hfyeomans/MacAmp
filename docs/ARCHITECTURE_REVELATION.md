# Architecture Revelation: Mechanism vs Presentation Layer

**Date:** 2025-10-12
**Critical Insight:** User feedback on why current approach fails

---

## The Core Problem

### User's Key Insight

> "We must build the mechanisms that do the work, but are allowed to be covered by skins as they change. The digits increment in some skins but not others. We must decouple the action and mechanisms from the skin that is put over the top of these elements and functions."

**Translation:** MacAmp is building STATIC UI with hardcoded sprite names instead of having a MECHANISM layer that renders functional elements, with a PRESENTATION layer (skin) that overlays visual styling.

---

## Evidence from Testing

### Working Behavior
- **Classic Winamp:** Digits increment ✅
- **Other skins:** Digits increment ✅

### Broken Behavior
- **Internet Archive:** Digits do NOT increment ❌

### Why the Difference?

Current code:
```swift
SimpleSpriteImage("DIGIT_\(digits[0])", width: 9, height: 13)
```

**With Classic Winamp:**
- Skin has `DIGIT_0` sprite ✅
- Code requests `"DIGIT_0"` ✅
- Match found → renders correctly ✅

**With Internet Archive:**
- Skin has `DIGIT_0_EX` sprite (from NUMS_EX.BMP)
- Code requests `"DIGIT_0"` (hardcoded!)
- Sprite aliasing creates `DIGIT_0` → `DIGIT_0_EX` mapping
- BUT view doesn't re-render when time changes because SwiftUI optimizes it away
- Result: Digits appear but don't update ❌

---

## The EQMAIN.bmp Revelation

### What the Screenshots Show

**Winamp3 Classified EQMAIN.bmp:**
- BLUE areas = Transparent/background = **App must render functional elements**
- Chrome/gray areas = Skin artwork = **Decorative overlay**

**Internet Archive EQMAIN.bmp:**
- Chrome vertical stripes = **Skin-provided slider channel backgrounds**
- These are what should appear instead of green/yellow gradients

### The Architecture Insight

**Current MacAmp (Wrong):**
```
UI Component → Hardcoded Sprite Name → Skin Lookup
     ↓              ↓                       ↓
  Volume        "DIGIT_0"            DIGIT_0 or fail
```

**Webamp (Correct):**
```
Mechanism → Semantic Element → CSS/Skin Resolution → Actual Sprite
    ↓            ↓                    ↓                    ↓
  Timer      .digit-0          skin.css maps         DIGIT_0 or DIGIT_0_EX
```

**MacAmp Should Be (Fixed):**
```
Mechanism → Semantic Request → Sprite Resolver → Actual Sprite
    ↓            ↓                  ↓                  ↓
  Timer      .digit(0)      Check what skin has   DIGIT_0_EX or DIGIT_0
```

---

## Webamp's Three Layers

### Layer 1: Mechanism (State Management)

**File:** Redux store, selectors

```javascript
// Pure data, no visuals
const currentTime = useTypedSelector(Selectors.getTimeElapsed);  // Seconds
const volume = useTypedSelector(Selectors.getVolume);            // 0-100
```

**Responsibility:** Track values, update via timers, respond to user input

### Layer 2: Bridge (Component Rendering)

**File:** Time.tsx (lines 17-38)

```javascript
const timeObj = Utils.getTimeObj(seconds);  // Convert to digits

return (
  <div id="time">
    <div className={`digit digit-${timeObj.minutesFirstDigit}`} />  // Semantic!
    <div className={`digit digit-${timeObj.secondsFirstDigit}`} />
  </div>
);
```

**Responsibility:**
- Convert state to semantic elements
- **NEVER mention actual sprite names**
- Provide stable IDs/classes for styling

### Layer 3: Presentation (Skin CSS)

**File:** Dynamically loaded skin CSS

```css
.digit {
  width: 9px;
  height: 13px;
  background-image: url('./sprites/NUMBERS.bmp');
}

.digit-0 { background-position: 0px 0px; }
.digit-1 { background-position: -9px 0px; }
/* ... */
```

**Responsibility:**
- Map semantic elements to actual sprites
- Handle skin-specific sprite names (NUMBERS vs NUMS_EX)
- **Different skins load different CSS files**

---

## MacAmp's Current Architecture (Broken)

### All Three Layers Collapsed Into One

**Current Code:**
```swift
// ❌ WRONG: Mechanism + Bridge + Presentation all mixed together
let digits = timeDigits(from: audioPlayer.currentTime)  // Mechanism
SimpleSpriteImage("DIGIT_\(digits[0])", width: 9, height: 13)  // Hardcoded presentation!
```

**Problems:**
1. View directly references sprite names → breaks with variant skins
2. No semantic layer → can't adapt to different skin conventions
3. Static sprite names → requires code changes for new skin formats

---

## MacAmp's Required Architecture (Fix)

### Layer 1: Mechanism

```swift
// AudioPlayer (already correct ✅)
@Published var currentTime: Double  // Updates every 0.1s via timer
```

### Layer 2: Bridge

```swift
// Component renders SEMANTIC sprites
let digits = timeDigits(from: audioPlayer.currentTime)

// ✅ CORRECT: Semantic request, not hardcoded name
SimpleSpriteImage(.digit(digits[0]), width: 9, height: 13)
```

### Layer 3: Presentation

```swift
// SpriteResolver (skin-specific mapping)
struct SpriteResolver {
    func resolve(_ semantic: SemanticSprite) -> String? {
        switch semantic {
        case .digit(let n):
            // Try extended first, fall back to standard
            if skin.images["DIGIT_\(n)_EX"] != nil {
                return "DIGIT_\(n)_EX"  // Internet Archive uses this
            }
            if skin.images["DIGIT_\(n)"] != nil {
                return "DIGIT_\(n)"      // Classic Winamp uses this
            }
            return nil  // Missing - show placeholder
        }
    }
}
```

---

## Why Current Fixes Don't Fully Work

### Issue: Sprite Aliasing Approach

**What I did:**
```swift
// In SkinManager: Create aliases after loading
if extractedImages["DIGIT_0"] == nil && extractedImages["DIGIT_0_EX"] != nil {
    extractedImages["DIGIT_0"] = extractedImages["DIGIT_0_EX"]  // Copy reference
}
```

**Why it's insufficient:**
1. Works ONE TIME when skin loads
2. Views still hardcode sprite names
3. Doesn't scale to hundreds of sprite variants
4. Band-aid solution, not architectural fix

### Issue: SwiftUI Re-rendering

**What I did:**
```swift
.onChange(of: audioPlayer.currentTime) { _, _ in
    // Force re-render
}
```

**Why it might not be enough:**
1. SwiftUI might still optimize away if view structure identical
2. Doesn't fix the semantic vs hardcoded sprite name issue
3. Treats symptom, not root cause

---

## The Complete Solution

### Step 1: Integrate SpriteResolver

**Add to Xcode project:**
- MacAmpApp/Models/SpriteResolver.swift ✅ (exists but not in Xcode)
- Fix compilation errors in TimeDisplayExample.swift

### Step 2: Update SimpleSpriteImage

**Add semantic sprite support:**
```swift
struct SimpleSpriteImage: View {
    private let spriteSource: SpriteSource

    enum SpriteSource {
        case legacy(String)             // Old: "DIGIT_0"
        case semantic(SemanticSprite)   // New: .digit(0)
    }

    // Legacy init (unchanged)
    init(_ key: String, width: CGFloat? = nil, height: CGFloat? = nil)

    // New init (semantic)
    init(_ semantic: SemanticSprite, width: CGFloat? = nil, height: CGFloat? = nil)

    var body: some View {
        @Environment(\.spriteResolver) var resolver
        @EnvironmentObject var skinManager: SkinManager

        let actualSpriteName: String? = {
            switch spriteSource {
            case .legacy(let name):
                return name  // Use directly
            case .semantic(let semantic):
                return resolver?.resolve(semantic) ?? skinManager.currentSkin?.resolveSprite(semantic)
            }
        }()

        // Render using actualSpriteName
    }
}
```

### Step 3: Migrate Components Incrementally

**Start with buildTimeDisplay():**
```swift
//Before:
SimpleSpriteImage("DIGIT_\(digits[0])", width: 9, height: 13)

// After:
SimpleSpriteImage(.digit(digits[0]), width: 9, height: 13)
```

**Result:**
- Works with DIGIT_0 skins ✅
- Works with DIGIT_0_EX skins ✅
- Works with both ✅
- Works with neither (shows placeholder) ✅

---

## Testing Your Observation

### Test Matrix

| Skin | Has DIGIT_0 | Has DIGIT_0_EX | Current Behavior | Expected |
|------|-------------|----------------|------------------|----------|
| Classic Winamp | ✅ | ❌ | Increments ✅ | Increments ✅ |
| Internet Archive | ❌ | ✅ | Static ❌ | Should increment ✅ |
| Winamp3 Classified | ✅ | ✅ | Increments ✅ | Increments ✅ |

**Diagnosis:** Aliasing + .onChange() didn't fully fix Internet Archive

---

## Root Cause Analysis

### Why Internet Archive Digits Don't Increment

**Hypothesis 1:** SwiftUI optimization
- Even with .onChange(), SwiftUI sees same view structure
- Sprite aliasing happens at load time, not render time
- View identity doesn't change

**Hypothesis 2:** Transparent fallback issue
- Fallback creates transparent DIGIT_0
- View finds it, uses it
- Alias exists but view already resolved to fallback
- Order of operations: fallback creation → aliasing

**Hypothesis 3:** View caching
- SimpleSpriteImage caches the resolved image
- When digit value changes from 0→1, it looks up "DIGIT_0" then "DIGIT_1"
- But both resolve to transparent fallbacks created BEFORE aliasing

---

## The Real Fix: Remove Sprite Name Hardcoding

### Current Problem Code Locations

**1. WinampMainWindow.swift (buildTimeDisplay):**
```swift
SimpleSpriteImage("DIGIT_\(digits[0])", width: 9, height: 13)  // ❌ Hardcoded
SimpleSpriteImage("CHARACTER_58", width: 5, height: 6)         // ❌ Hardcoded
```

**2. VolumeSliderView.swift:**
```swift
// Actually this is now OK - uses background: NSImage parameter ✅
```

**3. All button/indicator views:**
```swift
SimpleSpriteImage("MAIN_PLAY_BUTTON", width: 23, height: 18)  // ❌ Hardcoded
```

### Required Changes

**Add SpriteResolver to Xcode project**
**Update SimpleSpriteImage to resolve semantic sprites**
**Migrate time display** (prove it works)
**Then migrate everything else**

---

## Action Plan

### Immediate (This Session)

1. ✅ Understand the architecture (done via user feedback + webamp research)
2. ⏳ Fix TimeDisplayExample compilation errors
3. ⏳ Add SpriteResolver to Xcode project properly
4. ⏳ Update SimpleSpriteImage with semantic support
5. ⏳ Test with Internet Archive - verify digits increment

### Follow-up (Next Session)

6. Migrate all components to semantic sprites
7. Remove sprite aliasing system (no longer needed)
8. Clean up fallback generation (resolver handles it)
9. Document the new architecture

---

## Key Takeaways

### What We Learned

1. **Sprites are NOT standardized** - Different skins use different names
2. **Aliasing is a band-aid** - Doesn't solve architectural issue
3. **Webamp's success** comes from complete mechanism/presentation decoupling
4. **SwiftUI needs semantic layer** to replace webamp's CSS
5. **SpriteResolver IS the solution** - just needs proper integration

### What Needs to Change

**Stop doing:**
- ❌ Hardcoding sprite names in views
- ❌ Assuming all skins have same sprite names
- ❌ Using aliasing as primary solution

**Start doing:**
- ✅ Request sprites semantically (.digit(0))
- ✅ Let SpriteResolver map to actual sprite names
- ✅ Support any skin variant automatically

---

**Status:** Architecture understood, solution designed, integration needed
**Next:** Properly integrate SpriteResolver and test with Internet Archive
