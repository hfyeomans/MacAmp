# Deprecated Code: AirPlay Integration

> **Purpose:** Documents deprecated or legacy code findings related to the AirPlay integration. Per project conventions, we report deprecated code here instead of adding `// Deprecated` or `// Legacy` comments in code. Code identified here should be removed, not preserved.

**Date:** 2026-02-07, **Updated:** 2026-03-23
**Status:** Phase 0 — black masks removed, digit positions adjusted

---

## Deprecated Patterns Found

### Prior Task Artifacts (Superseded)

The following task folders contain research and plans that are now superseded by this consolidated task:

1. **`tasks/airplay/`** - Original AirPlay research (2025-10-30)
   - Contains Gemini research with known inaccuracies (60% accurate)
   - Oracle corrections applied but scattered across multiple files
   - Plan includes impossible Phase 3 (custom device menu)
   - **Status:** Superseded by this task's research.md

2. **`tasks/winamp-airplay-overlay/`** - Overlay research (2025-10-30)
   - Focused solely on AVRoutePickerView overlay pattern
   - Research valid but incomplete (no engine restart logic)
   - **Status:** Superseded by this task's research.md

### Code Patterns to Avoid

| Pattern | Why Deprecated | Use Instead |
|---|---|---|
| `import AVFoundation` for AVRoutePickerView | Wrong framework | `import AVKit` |
| `outputNode.setDeviceID()` | API doesn't exist | AVRoutePickerView (system UI) |
| `NSLocalNetworkUsageDescription` in Info.plist | iOS-only, ignored on macOS | Don't add |
| Custom device enumeration via AVAudioDevice | Only shows local devices, not AirPlay | System picker handles discovery |
| `picker.isRouteDetectionEnabled` | Property doesn't exist on macOS | Use minimal AVRoutePickerView |
| `picker.routePickerButtonStyle` | Property doesn't exist on macOS | Use minimal AVRoutePickerView |

---

## Removed Code (Phase 0) — May Need Restoration

### Color.black Masks (Time Display)

Removed from both `MainWindowFullLayer.buildTimeDisplay()` and `MainWindowShadeLayer.buildShadeTimeDisplay()`. These were black rectangles behind each digit pair to mask the skin background.

**Full mode (MainWindowFullLayer.swift, was lines 92-100):**
```swift
// Minutes mask
Color.black
    .frame(width: 21, height: 13)
    .offset(x: 6, y: 0)

// Seconds mask
Color.black
    .frame(width: 21, height: 13)
    .offset(x: 34, y: 0)
```

**Shade mode (MainWindowShadeLayer.swift, was lines 68-74):**
```swift
Color.black
    .frame(width: 21, height: 13)
    .offset(x: 6, y: 0)

Color.black
    .frame(width: 21, height: 13)
    .offset(x: 34, y: 0)
```

**Why removed:** The masks covered the skin's native colon and digit area. Without them, the skin background shows through correctly. **May need restoration** if some skins have artifacts in the digit area without masking — test with multiple skins.

### Digit Position Changes (Full Mode)

Original → Current positions:
| Digit | Original x | Current x | Change |
|-------|-----------|-----------|--------|
| digits[0] (min tens) | 6 | 8 | +2px |
| digits[1] (min ones) | 17 | 19 | +2px |
| digits[2] (sec tens) | 35 | 39 | +4px |
| digits[3] (sec ones) | 46 | 50 | +4px |

---

## Rules

1. Instead of marking code as deprecated or legacy in-source, document it here
2. Code identified here should be REMOVED, not preserved with comments
3. Review this file during implementation to ensure deprecated patterns are avoided
