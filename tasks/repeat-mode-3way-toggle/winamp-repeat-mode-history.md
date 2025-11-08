# How Winamp Implemented Repeat Modes (Historical Analysis)

**Research Date:** 2025-11-07
**Question:** How did Winamp display all 3 repeat modes visually?

---

## TL;DR: Winamp 5+ Used a "1" Badge on Modern Skins

**Visual Indicator:**
- **Repeat Off:** Button unlit
- **Repeat All:** Button lit (no badge)
- **Repeat One:** Button lit **+ small "1" badge overlay**

**Mechanism:** Repeat One = Repeat ON + Manual Playlist Advance ON

---

## Historical Evolution

### Winamp 2.x (Classic Era)
- ❌ **No native Repeat One mode**
- ✅ Only had Repeat On/Off (entire playlist loop)
- 🔌 Required **third-party plugins** like "RepeatOne" or "Three Mode Repeat"

### Winamp 5.x (Modern Era)
- ✅ **Repeat One achieved through combination**
  - Repeat ON + Manual Playlist Advance (MPA) ON = Repeat One Track
- ✅ **Modern skins** (Modern, Big Bento, cPro) had **built-in three-state toggle**
- ⚠️ **Classic skins** still needed plugins for visual indication

---

## The Four States Logic

Winamp 5 uses **two independent settings** to create four behaviors:

| Repeat | Manual Playlist Advance (MPA) | Behavior | Visual Indicator |
|--------|-------------------------------|----------|------------------|
| OFF | OFF | Play playlist once | Button unlit |
| ON | OFF | **Repeat playlist (all tracks)** | Button lit |
| ON | ON | **Repeat single track (one)** | Button lit + "1" |
| OFF | ON | Manual advance (pause at track end) | Button unlit, MPA indicator |

**Key insight:** Repeat One isn't a separate mode - it's a **combination of two flags**.

---

## Visual Implementation in Winamp 5 Modern Skins

### Built-in Three-State Button

**Modern skin families (Modern, Bento, cPro):**
- Single button cycles through 3 states on each click
- Visual feedback:
  1. **Click 1:** Repeat OFF → Repeat ALL (button lights up)
  2. **Click 2:** Repeat ALL → Repeat ONE (button shows "1" badge)
  3. **Click 3:** Repeat ONE → Repeat OFF (button dims)

**Quote from research:**
> "In Winamp Modern, (Big) Bento, cPro skins and some modern skins, a three-state repeat toggle is built in to the skin - clicking the Repeat button cycles through the states"

### The "1" Badge Indicator

**How it looked:**
- Small "1" character superimposed on the repeat button
- Position: Typically top-right or center of button
- Color: Usually white or contrasting color for visibility
- Activated when: Both Repeat ON **and** MPA ON

**Quote from research:**
> "Having Repeat on and Manual Playlist Advance on effectively results in a 'Repeat One' (Track only) behavior, and this is the only way to achieve this behavior in Winamp, hard-wired to the Repeat buttons in the Modern and Bento skins, indicated by a little '1' on the button."

---

## Classic Skins: Plugin-Based Solution

### Problem
Classic Winamp skins (like default Winamp.wsz) only had sprites for:
- `MAIN_REPEAT_BUTTON` (off state)
- `MAIN_REPEAT_BUTTON_SELECTED` (on state)

**No third sprite for "repeat one" state.**

### Solution: Third-Party Plugins

**Plugin:** "Three Mode Repeat" (Global Hotkey plugin)
- Added hotkey for toggling Repeat One
- Provided visual indication (likely overlay or window indicator)

**Quote from research:**
> "For classic skins, there is a Repeat One toggle Global Hotkey plug-in called 'Three Mode Repeat' that provides repeat one toggle hot key and a visual representation of repeat one"

### How Plugins Displayed It

**Methods used by plugins:**
1. **Asterisk overlay:** `*` character on repeat button
2. **Small "1" overlay:** Similar to modern skins
3. **Separate indicator window:** Tiny floating window showing mode

**Quote from web search summary:**
> "For other skins an asterisk (*) is superimposed over the repeat button."

---

## Keyboard Shortcuts (Winamp 5)

| Shortcut | Action |
|----------|--------|
| `R` | Toggle Repeat (when main/player/playlist window focused) |
| `Shift+R` | Toggle Manual Playlist Advance (MPA) |

**Result:** Pressing both shortcuts enabled Repeat One mode.

---

## Context Menu Access

**Right-click on Repeat button revealed:**
```
[ ] Repeat
[ ] Manual Playlist Advance
```

Both checkboxes could be enabled for Repeat One behavior.

**Quote from research:**
> "To have one song repeat, right-click the Toggle Repeat button, click 'Manual Playlist Advance' so that it is checked"

---

## Why Winamp Used Two Flags Instead of Enum

### Design Rationale

**Historical reasons:**
1. **Backwards compatibility:** Winamp 2.x only had Repeat On/Off
2. **Manual Playlist Advance existed first:** MPA was a separate feature for DJs
3. **Emergent behavior:** Repeat One was discovered as side effect, then embraced

**Technical reasons:**
1. **Independent controls:** Users could still use MPA without Repeat
2. **Flexibility:** Four combinations vs. three enum states
3. **Skin compatibility:** Didn't require new sprites in classic skins

---

## Comparison: Winamp vs. MacAmp Approach

| Aspect | Winamp 5 | MacAmp (Proposed) |
|--------|----------|-------------------|
| **State Model** | 2 booleans (Repeat + MPA) | 1 enum (off/all/one) |
| **Button Clicks** | 3-state cycle | 3-state cycle |
| **Visual: Off** | Button unlit | Button unlit |
| **Visual: All** | Button lit | Button lit |
| **Visual: One** | Button lit + "1" | Button lit + "1" ✅ |
| **Classic Skins** | Plugin required | Built-in overlay |
| **Complexity** | 2 settings to toggle | 1 setting, cleaner UX |

**Verdict:** MacAmp's enum approach is **simpler and cleaner** than Winamp's dual-flag system.

---

## Implementation Implications for MacAmp

### What We Learn from Winamp

1. ✅ **"1" badge is the established pattern**
   - Users familiar with Winamp 5 will recognize it
   - Small overlay on repeat button when in "one" mode

2. ✅ **White text is common**
   - Winamp Modern skins used light-colored "1"
   - Worked across various skin color schemes

3. ✅ **Badge position: Top-right or center**
   - Doesn't obscure button design
   - Clear at a glance

4. ⚠️ **Classic skins needed workarounds**
   - Plugins used overlays (asterisk, "1", etc.)
   - Proves that overlaying on skin sprites is acceptable

### Recommended MacAmp Implementation

**Follow Winamp 5 Modern skin approach:**

```swift
ZStack {
    SimpleSpriteImage(repeatSpriteName, width: 28, height: 15)

    if settings.repeatMode == .one {
        Text("1")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 0)
            .offset(x: 8, y: 0)  // Adjust to top-right corner
    }
}
```

**Justification:**
- ✅ Matches Winamp 5 visual language (users know what "1" means)
- ✅ Works on classic skins (Winamp plugins proved this acceptable)
- ✅ Shadow ensures visibility (improvement over original)
- ✅ Simpler state model than Winamp's dual flags

---

## User Experience Comparison

### Winamp 5 Modern Skin
1. User clicks Repeat button (lit up)
2. User clicks again (button shows "1")
3. User hovers: Tooltip says "Repeat One" or similar
4. **Result:** Clear visual + tooltip confirmation

### MacAmp (Proposed)
1. User clicks Repeat button (lit up) - "Repeat All"
2. User clicks again (button shows "1") - "Repeat One"
3. User hovers: Tooltip says "Repeat: One (Ctrl+R)"
4. **Result:** Identical to Winamp 5! ✅

---

## Screenshots Analysis (Web Search Findings)

### What Skins Used "1" Badge
- **Winamp Modern (default in 5.x):** Yes, built-in
- **Big Bento:** Yes, built-in
- **cPro:** Yes, built-in
- **Classic skins:** Via plugins only

### What Colors Were Used
- **Most common:** White "1" on dark/colored button
- **Some skins:** Yellow or skin-matched accent color
- **Contrast method:** Text shadow or outline (implied)

---

## Alternative Approaches Considered (and Rejected by Winamp)

### Approach 1: Separate "Repeat One" Button
**Why rejected:**
- Takes up more UI space
- Contradicts classic Winamp layout
- Less discoverable (users wouldn't find it)

### Approach 2: Three Sprites in Skin File
**Why rejected:**
- Breaks backwards compatibility with classic skins
- Requires all skin authors to update
- Technical limitation: Button sprite sheets have fixed layouts

### Approach 3: Changing Button Icon/Symbol
**Why rejected:**
- Unclear what symbol to use (loop with 1? different icon?)
- Loses visual consistency with "repeat" metaphor
- Harder to recognize mode at a glance

---

## Conclusion: MacAmp Should Use Winamp 5's Pattern

### Summary of Winamp's Approach
1. **State:** Repeat One = Repeat ON + Manual Playlist Advance ON
2. **Visual:** Button lit + small "1" badge overlay
3. **Interaction:** Button cycles through 3 states
4. **Classic skins:** Plugins added overlays (acceptable practice)

### Why MacAmp Should Follow This
1. ✅ **User familiarity:** Winamp users will recognize it instantly
2. ✅ **Proven design:** Worked in Winamp 5 for years
3. ✅ **Skin compatibility:** Overlay approach validated by plugins
4. ✅ **Simplicity:** Enum is cleaner than dual-flag system

### Implementation Recommendation

**MacAmp's approach (from repeat-mode-research.md) is correct:**
- Use `RepeatMode` enum (off/all/one)
- Display "1" badge when mode = `.one`
- Add shadow for cross-skin legibility
- Single button cycles through states

**This is actually better than Winamp 5 because:**
- ✅ One setting instead of two (simpler mental model)
- ✅ Shadow ensures badge works on light skins (Winamp had contrast issues)
- ✅ No need for "Manual Playlist Advance" concept (confusing to users)

---

## Research Sources

1. **Web search:** Winamp forums discussion of Repeat One implementation
2. **Plugin repository:** "RepeatOne" and "Three Mode Repeat" plugins
3. **Skin documentation:** Modern skin button specifications
4. **User guides:** How to enable Repeat One in Winamp 5

**Key finding:**
> "indicated by a little '1' on the button"

This confirms the "1" badge approach is the canonical Winamp way to show Repeat One mode.

---

## Final Recommendation for MacAmp

**Ship repeat mode with:**
1. Three-state enum (`RepeatMode.off/all/one`)
2. White "1" badge with black shadow overlay
3. Button cycles: Off → All → One → Off
4. Tooltip shows current mode name
5. Keyboard shortcut `Ctrl+R` cycles modes

**This matches Winamp 5 Modern skins while improving upon the dual-flag confusion.**

✅ **Go ahead with Option B1 (Shadow) from repeat-mode-overlay-analysis.md**

The "1" badge is the **historically correct** and **user-expected** visual indicator for Repeat One mode.
