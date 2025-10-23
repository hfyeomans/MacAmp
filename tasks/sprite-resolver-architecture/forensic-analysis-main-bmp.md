# Forensic Analysis: MAIN.BMP Time Display Investigation

## Objective
Determine if the double digit rendering issue is caused by pre-rendered time displays ("00:00" or "88:88") baked into the MAIN.BMP background images.

## Methodology
1. Extracted MAIN.BMP files from three Winamp skins:
   - Classic Winamp (Winamp.wsz)
   - Internet Archive skin (Internet-Archive.wsz)
   - Winamp3 Classified v5.5

2. Analyzed time display region at coordinates:
   - X: 39-87 (48 pixels wide)
   - Y: 26-39 (13 pixels tall)
   - This matches the documented time display position in Winamp skins

3. Visual inspection of cropped regions and full background images

## Findings

### 1. Classic Winamp Skin (Winamp.wsz)
**File**: MAIN.BMP
- **Dimensions**: 275 x 116 pixels
- **Format**: 8-bit indexed color (256 colors)
- **File size**: 26,680 bytes

**Time Region Analysis**:
- The time display area shows **NO pre-rendered digits**
- Region appears as solid background color (dark blue/grey)
- Only visible element is a small white/bright pixel on the right edge (likely a UI indicator, not digits)

**Verdict**: ✅ **CLEAN - No baked-in time display**

### 2. Internet Archive Skin (Internet-Archive.wsz)
**File**: MAIN.bmp
- **Dimensions**: 275 x 116 pixels
- **Format**: 8-bit indexed color (256 colors)
- **File size**: 26,680 bytes

**Time Region Analysis**:
- The time display area shows **NO pre-rendered digits**
- Identical to classic skin - solid background color
- Same small white/bright pixel on right edge

**Verdict**: ✅ **CLEAN - No baked-in time display**

**Note**: These two skins appear to use identical MAIN.BMP files (same dimensions, same file size, visually identical).

### 3. Winamp3 Classified v5.5 Skin
**File**: main.bmp
- **Dimensions**: 275 x 116 pixels
- **Format**: 24-bit RGB (true color)
- **File size**: 96,102 bytes

**Time Region Analysis**:
- The time display area shows **PARTIAL CONTENT**
- Contains what appears to be a colon (":") character in the middle
- This is visible in the full background image as well

**Verdict**: ⚠️ **CONTAINS SEPARATOR - Has pre-rendered colon character**

## Conclusion

### Primary Finding
**The double digit rendering issue is NOT caused by MAIN.BMP containing pre-rendered time displays.**

The two skins currently used in MacAmp (Classic Winamp and Internet Archive) have completely clean background images in the time display region. There are no "00:00" or "88:88" digits baked into the MAIN.BMP files.

### Secondary Finding
The Winamp3 skin does contain a pre-rendered colon separator, but not the full time digits. This suggests that some skin designers intentionally placed static UI elements in the time display area, but full digit rendering was not a standard practice.

### Implication
Since MAIN.BMP backgrounds do not contain pre-rendered digits, the double rendering issue must be occurring in the **SwiftUI rendering pipeline itself**. The problem is likely:

1. **Multiple draw calls** rendering the same NUMBERS.BMP sprites twice
2. **Layer stacking issue** where time digits are rendered on multiple layers
3. **State management bug** causing duplicate render commands

### Next Investigation Steps
1. Review `TimeDisplayView.swift` rendering logic
2. Check if digits are being drawn in both:
   - The background layer (via SkinRenderer)
   - A foreground overlay layer (via SwiftUI views)
3. Examine `PlayerView.swift` layer composition
4. Look for duplicate `.onAppear` or `.onChange` handlers that trigger digit rendering

## Visual Evidence
Cropped time regions saved to:
- `/Users/hank/dev/src/MacAmp/tmp/sprite-analysis/time-region-classic.png`
- `/Users/hank/dev/src/MacAmp/tmp/sprite-analysis/time-region-internet-archive.png`
- `/Users/hank/dev/src/MacAmp/tmp/sprite-analysis/time-region-winamp3.png`

Full backgrounds saved to:
- `/Users/hank/dev/src/MacAmp/tmp/sprite-analysis/MAIN-classic.png`
- `/Users/hank/dev/src/MacAmp/tmp/sprite-analysis/MAIN-internet-archive.png`
- `/Users/hank/dev/src/MacAmp/tmp/sprite-analysis/MAIN-winamp3.png`

## Technical Details

### Image Properties Comparison

| Property | Classic/Internet Archive | Winamp3 |
|----------|-------------------------|---------|
| Width | 275 px | 275 px |
| Height | 116 px | 116 px |
| Color Depth | 8-bit indexed | 24-bit RGB |
| File Size | 26,680 bytes | 96,102 bytes |
| Compression | RLE | None |

### Time Display Region Coordinates
Based on Winamp skin specification:
- **Position**: (39, 26)
- **Digit Size**: 9x13 pixels
- **Character Spacing**: ~1-2 pixels
- **Full Time Width**: ~48 pixels for "00:00"

## Recommendation
Focus investigation on SwiftUI view hierarchy and rendering pipeline. The background images are clean, so the double rendering is happening at the application layer.
