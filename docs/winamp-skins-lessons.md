# Winamp Skins: Lessons Learned & Critical Knowledge

**Date:** 2025-10-12
**Project:** MacAmp
**Purpose:** Preserve critical knowledge about Winamp skin format variations and implementation pitfalls

---

## Executive Summary

Winamp skins are **NOT standardized**. Different skins from different eras use different sprite sheets, different naming conventions, and different optional features. This document captures hard-won knowledge to prevent future bugs and confusion.

---

## The NUMBERS.bmp vs NUMS_EX.bmp Discovery

### The Problem That Started It All

**Error Messages:**
```
❌ MISSING SPRITE: 'DIGIT_0' not found in skin
❌ MISSING SPRITE: 'MAIN_VOLUME_THUMB' not found in skin
❌ MISSING SPRITE: 'EQ_GRAPH_BACKGROUND' not found in skin
```

**Initial Assumption (WRONG):**
"The Internet Archive skin is broken and missing sprites"

**Reality (CORRECT):**
"Different skins use different sprite sheets - Internet Archive uses NUMS_EX.bmp instead of NUMBERS.bmp"

### Two Parallel Number Systems

#### System 1: NUMBERS.bmp (Classic Era, ~1998-2003)

**File:** `NUMBERS.bmp`
**Size:** 99×13 pixels
**Sprite Count:** 11 sprites

```
Layout:
┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐
│  0  │  1  │  2  │  3  │  4  │  5  │  6  │  7  │  8  │  9  │ +/- │
│ 9×13│ 9×13│ 9×13│ 9×13│ 9×13│ 9×13│ 9×13│ 9×13│ 9×13│ 9×13│ 5×1 │
└─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘
```

**Sprite Names:**
- `DIGIT_0` through `DIGIT_9`
- `NO_MINUS_SIGN`, `MINUS_SIGN`

**Used By:** Classic Winamp, base-2.91, TopazAmp, most early skins

#### System 2: NUMS_EX.bmp (Extended Era, ~2003-2013)

**File:** `NUMS_EX.bmp`
**Size:** 108×13 pixels
**Sprite Count:** 12 sprites

```
Layout:
┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐
│  0  │  1  │  2  │  3  │  4  │  5  │  6  │  7  │  8  │  9  │ -   │  ⌀  │
│ 9×13│ 9×13│ 9×13│ 9×13│ 9×13│ 9×13│ 9×13│ 9×13│ 9×13│ 9×13│ 9×13│ 9×13│
└─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘
```

**Sprite Names:**
- `DIGIT_0_EX` through `DIGIT_9_EX`
- `NO_MINUS_SIGN_EX`, `MINUS_SIGN_EX`

**Difference:** Wider minus signs (9 pixels vs 5 pixels) for better visual balance

**Used By:** Internet Archive, modern skins, Winamp 5+ era skins

### Visual Evidence

**Screenshot Comparison:**

**Classic Winamp skin (NUMBERS.bmp):**
```
Time: [0][0][:][0][5]  ← Green digits, 9×13 each
                          Uses NUMBERS.bmp
```

**Internet Archive skin (NUMS_EX.bmp):**
```
Time: [0][0][:][0][0]  ← White/light digits, 9×13 each
                          Uses NUMS_EX.bmp
```

**Proof:** Screenshot `2025-10-12 at 3.20.00 PM.png` shows Internet Archive rendering perfectly with white digits.

---

## Critical Lesson: Skin Completeness is a Myth

### What We Thought

"All Winamp skins contain the same 15-20 BMP files with standardized layouts"

### What We Learned

**Skins vary dramatically:**

#### Minimal Skin (Classic Winamp)
```
Required Files (11):
✅ MAIN.bmp
✅ CBUTTONS.bmp
✅ NUMBERS.bmp
✅ TEXT.bmp
✅ TITLEBAR.bmp
✅ POSBAR.bmp
✅ SHUFREP.bmp
✅ MONOSTER.bmp
✅ PLAYPAUS.bmp
✅ PLEDIT.bmp
✅ EQMAIN.bmp

Optional Files (0):
❌ NUMS_EX.bmp
❌ EQ_EX.bmp
❌ VIDEO.bmp
❌ GENEX.bmp
```

#### Extended Skin (Internet Archive)
```
Required Files (15):
✅ MAIN.bmp
✅ CBUTTONS.bmp
✅ NUMS_EX.bmp  ← Uses extended numbers!
✅ TEXT.bmp
✅ TITLEBAR.bmp
✅ POSBAR.bmp
✅ SHUFREP.bmp
✅ MONOSTER.bmp
✅ PLAYPAUS.bmp
✅ PLEDIT.bmp
✅ EQMAIN.bmp
✅ EQ_EX.bmp    ← Extended EQ graphics
✅ VIDEO.bmp    ← Video display support
✅ GENEX.bmp    ← Generic window extensions
✅ VOLUME.bmp
✅ BALANCE.bmp

Missing Files:
❌ NUMBERS.bmp  ← Doesn't need it, has NUMS_EX!
```

#### Complete Skin (Winamp3 Classified)
```
Has BOTH number systems:
✅ NUMBERS.bmp  ← Classic compatibility
✅ NUMS_EX.bmp  ← Extended features

Plus additional files:
✅ GENEX.bmp
✅ VIDEO.bmp
✅ Various optional enhancements
```

---

## Bundle Discovery: SPM vs Xcode

### The Root Cause of "Skins Not Found"

**Problem:** Xcode and SPM builds have completely different bundle structures.

#### SPM Build Structure
```
.build/arm64-apple-macosx/debug/
├── MacAmpApp                     ← Executable
└── MacAmp_MacAmpApp.bundle/      ← Resource bundle
    ├── Internet-Archive.wsz  ✅
    └── Winamp.wsz           ✅
```

**Discovery Path:**
```swift
#if SWIFT_PACKAGE
bundleURL = Bundle.module.bundleURL
// Returns: .../MacAmp_MacAmpApp.bundle/
#endif
```

**Result:** Direct `.wsz` files at bundle root

#### Xcode Build Structure
```
MacAmpApp.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/
    │   └── MacAmpApp             ← Executable
    └── Resources/                ← Resource directory
        ├── Internet-Archive.wsz  ✅
        └── Winamp.wsz           ✅
```

**Discovery Path (WRONG):**
```swift
#else
bundleURL = Bundle.main.bundleURL
// Returns: .../MacAmpApp.app  ❌ (not Resources/)
#endif
```

**Discovery Path (CORRECT):**
```swift
#else
bundleURL = Bundle.main.resourceURL ?? Bundle.main.bundleURL
// Returns: .../MacAmpApp.app/Contents/Resources/  ✅
#endif
```

### The Fix (Critical Code)

**File:** `MacAmpApp/Models/Skin.swift` (lines 70-84)

```swift
// Determine the correct bundle URL based on build type
let bundleURL: URL
#if SWIFT_PACKAGE
// For SPM command-line builds: Use Bundle.module which points to the resource bundle
bundleURL = Bundle.module.bundleURL
#else
// For Xcode app builds: Use Bundle.main.resourceURL which points to Contents/Resources/
// Fall back to bundleURL if resourceURL is nil (shouldn't happen in practice)
bundleURL = Bundle.main.resourceURL ?? Bundle.main.bundleURL
#endif

NSLog("🔍 Bundle path: \(bundleURL.path)")
NSLog("🔍 Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
NSLog("🔍 Resource URL: \(Bundle.main.resourceURL?.path ?? "nil")")
```

**Key Insight:** `Bundle.main.bundleURL` returns the `.app` wrapper, not the `Resources/` directory!

---

## Sprite Fallback System Architecture

### Why Fallbacks Are Essential

**Real-World Scenario:**
1. User downloads "CoolSkin.wsz" from Internet
2. Skin uses NUMS_EX.bmp for digits
3. MacAmp's default sprite definitions expect NUMBERS.bmp
4. Without fallbacks → Crash or broken UI
5. With fallbacks → App works, missing elements are invisible

### Three-Tier Fallback Strategy

#### Tier 1: Missing Sprite Sheet
```swift
guard let entry = findSheetEntry(in: archive, baseName: sheetName) else {
    NSLog("⚠️ MISSING SHEET: \(sheetName).bmp/.png not found")

    // Generate fallback sprites for entire sheet
    let fallbackSprites = createFallbackSprites(forSheet: sheetName, sprites: sprites)
    for (name, image) in fallbackSprites {
        extractedImages[name] = image
    }
    continue
}
```

**Example:** Internet Archive missing NUMBERS.bmp → 11 transparent fallbacks created

#### Tier 2: Corrupted Sprite Sheet
```swift
guard let sheetImage = NSImage(data: data) else {
    NSLog("❌ FAILED to create image for sheet: \(sheetName)")

    // Generate fallbacks for corrupted sheet
    let fallbackSprites = createFallbackSprites(forSheet: sheetName, sprites: sprites)
    for (name, image) in fallbackSprites {
        extractedImages[name] = image
    }
    continue
}
```

**Example:** Corrupted BMP file → Fallbacks prevent crash

#### Tier 3: Individual Sprite Crop Failure
```swift
if let croppedImage = sheetImage.cropped(to: r) {
    extractedImages[sprite.name] = croppedImage
} else {
    NSLog("⚠️ FAILED to crop \(sprite.name)")

    // Generate single fallback sprite
    let fallbackImage = createFallbackSprite(named: sprite.name)
    extractedImages[sprite.name] = fallbackImage
}
```

**Example:** Sprite rect out of bounds → Single transparent fallback

### Fallback Implementation

**File:** `MacAmpApp/ViewModels/SkinManager.swift` (lines 162-208)

```swift
private func createFallbackSprite(named spriteName: String) -> NSImage {
    // Step 1: Look up correct dimensions from sprite definitions
    let size: CGSize
    if let definedSize = SkinSprites.defaultSprites.dimensions(forSprite: spriteName) {
        size = definedSize  // e.g., 9×13 for DIGIT_0
    } else {
        size = CGSize(width: 16, height: 16)  // Generic default
    }

    // Step 2: Create truly transparent image
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()
    image.unlockFocus()

    return image
}
```

**Benefits:**
- ✅ Correct dimensions maintain UI layout
- ✅ Transparent (invisible) doesn't break visual design
- ✅ No crashes from nil image references
- ✅ UI components can safely access all sprite keys

---

## Menu Architecture: SwiftUI Commands Best Practices

### The Duplicate Menu Bug

**Symptoms:**
- Two "Skins" menus in menu bar
- One "Debug" menu (obsolete)

**Root Cause:**
```swift
// ❌ WRONG: Commands defined in each WindowGroup
WindowGroup { MainView() }
    .commands { SkinsCommands() }  // First instance

WindowGroup("Preferences") { PrefsView() }
    .commands { SkinsCommands() }  // Second instance (DUPLICATE!)
```

**Fix:**
```swift
// ✅ CORRECT: Commands defined once for entire app
WindowGroup { MainView() }

WindowGroup("Preferences") { PrefsView() }

// Commands apply to ALL window groups
.commands {
    AppCommands()
    SkinsCommands()  // Single instance
}
```

**SwiftUI Scene Modifier Order:**
```swift
Scene
  .windowStyle()
  .windowResizability()
  .defaultPosition()
  .commands()  ← Only on LAST scene in hierarchy
```

---

## Digit Rendering: Sprites NOT Fonts

### Confirmed Through Visual Inspection

**BMP File Evidence:**

**NUMBERS.bmp (Winamp3 Classified):**
- Visual inspection shows 10 distinct digit bitmaps
- Each digit is pre-rendered at 9×13 pixels
- Plus/minus signs at 5×1 pixels
- Fixed width monospaced digits

**NUMS_EX.bmp (Internet Archive):**
- Same layout but different style
- Different colors (white vs green)
- Same dimensions (9×13)
- Enhanced minus sign (9×13 vs 5×1)

### Not Like TEXT.bmp Font System

**TEXT.bmp (Variable Width):**
Webamp dynamically measures character widths:
```javascript
const getLetters = (y, prefix) => {
  const backgroundColor = getColorAt(0);

  return LETTERS.map((letter) => {
    // Find where letter ends by detecting background
    while (getColorAt(nextBackground) !== backgroundColor) {
      nextBackground++;
    }
    const width = nextBackground - x;  // Variable width!
    return { letter, x, y, width, height };
  });
};
```

**NUMBERS.bmp (Fixed Width):**
All digits are **exactly 9×13 pixels** - no dynamic detection needed.

---

## Skin Discovery Implementation

### Correct Bundle Path Resolution

**Critical Code:** `MacAmpApp/Models/Skin.swift` (lines 70-84)

```swift
let bundleURL: URL
#if SWIFT_PACKAGE
// SPM: Resource bundle at .build/.../MacAmp_MacAmpApp.bundle/
bundleURL = Bundle.module.bundleURL
#else
// Xcode: Resources folder at MacAmpApp.app/Contents/Resources/
bundleURL = Bundle.main.resourceURL ?? Bundle.main.bundleURL
#endif
```

**Why This Matters:**

| Build Type | bundleURL | resourceURL | Correct Choice |
|------------|-----------|-------------|----------------|
| SPM | `.../MacAmp_MacAmpApp.bundle/` | `nil` | bundleURL ✅ |
| Xcode | `.../MacAmpApp.app` | `.../Resources/` | resourceURL ✅ |

**Debugging Tip:** Always log both paths:
```swift
NSLog("🔍 Bundle path: \(bundleURL.path)")
NSLog("🔍 Resource URL: \(Bundle.main.resourceURL?.path ?? "nil")")
```

### Path Fallback Strategy

```swift
func findSkin(named name: String) -> URL? {
    // Try 1: Direct bundle root (SPM, Xcode Resources/)
    let direct = bundleURL.appendingPathComponent("\(name).wsz")
    if fileManager.fileExists(atPath: direct.path) {
        return direct  ✅
    }

    // Try 2: Skins subdirectory (nested resources)
    let nested = bundleURL.appendingPathComponent("Skins/\(name).wsz")
    if fileManager.fileExists(atPath: nested.path) {
        return nested  ✅
    }

    return nil  ❌
}
```

**Result:** Works for both flat and nested resource structures

---

## Optional vs Required Sprites

### Core Required Sheets (99% of skins)

1. **MAIN.bmp** - Main window background (275×116)
2. **TITLEBAR.bmp** - Title bar graphics
3. **CBUTTONS.bmp** - Control buttons (play, pause, stop, etc.)
4. **TEXT.bmp** - Font characters for song titles
5. **NUMBERS or NUMS_EX** - Digit sprites (ONE OR THE OTHER)
6. **POSBAR.bmp** - Position slider
7. **PLAYPAUS.bmp** - Play/pause indicator
8. **SHUFREP.bmp** - Shuffle/repeat buttons
9. **MONOSTER.bmp** - Mono/stereo indicators
10. **PLEDIT.bmp** - Playlist window graphics
11. **EQMAIN.bmp** - Equalizer window background

### Optional Enhancement Sheets

12. **EQ_EX.bmp** - Extended equalizer graphics (shaded mode)
13. **NUMS_EX.bmp** - Extended number sprites
14. **VIDEO.bmp** - Video window placeholder
15. **GENEX.bmp** - Generic window extensions
16. **VOLUME.bmp** - Volume slider (some skins)
17. **BALANCE.bmp** - Balance slider (some skins)
18. **GEN.bmp** - Generic window graphics

### How to Handle Missing Optional Sheets

**Webamp's Approach:**
```javascript
if (img == null) {
    return {};  // Empty object, no sprites from this sheet
}
```

**MacAmp's Approach:**
```swift
guard let entry = findSheetEntry(...) else {
    createFallbackSprites(...)  // Transparent placeholders
    continue
}
```

**Both approaches work!** Key principle: **Never crash on missing optionals**

---

## Testing Matrix: What Actually Works

### Tested Skin Configurations

| Skin | NUMBERS | NUMS_EX | VOLUME | EQ_EX | Result |
|------|---------|---------|--------|-------|--------|
| Classic Winamp | ✅ | ❌ | ❌ | ❌ | ✅ Works perfectly |
| Internet Archive | ❌ | ✅ | ✅ | ✅ | ✅ Works perfectly |
| Winamp3 Classified | ✅ | ✅ | ✅ | ✅ | ✅ Works perfectly |

**Conclusion:** MacAmp handles all three configurations correctly!

### Visual Verification

**Test Procedure:**
1. Launch MacAmpApp
2. Switch to Classic Winamp (⌘⇧1)
3. Observe: Green digits, classic appearance
4. Switch to Internet Archive (⌘⇧2)
5. Observe: White digits, modern appearance
6. Check: All windows update simultaneously

**Expected Results:**
- ✅ Digits change color between skins
- ✅ All UI elements render correctly
- ✅ No crashes or visual artifacts
- ✅ Smooth instant transition

**Screenshot Evidence:**
- `Screenshot 2025-10-12 at 3.20.00 PM.png` - Internet Archive perfect render
- `Screenshot 2025-10-12 at 3.16.39 PM.png` - MacAmp matches reference

---

## Debugging Guide: Understanding Log Messages

### Normal/Expected Warnings

#### Scenario 1: Skin Uses NUMS_EX Instead of NUMBERS

```
⚠️ MISSING SHEET: NUMBERS.bmp/.png not found in archive
   Expected 11 sprites from this sheet
   - Missing sprite: DIGIT_0
   - Missing sprite: DIGIT_1
   ...
⚠️ Sheet 'NUMBERS' is missing - generating 11 fallback sprites
✅ OPTIONAL: Found NUMS_EX.BMP - adding extended digit sprites
```

**Interpretation:** ✅ NORMAL - Skin uses extended numbers
**Action:** None needed, fallbacks are unused
**Result:** Digits render from NUMS_EX perfectly

#### Scenario 2: Skin Uses NUMBERS Instead of NUMS_EX

```
✅ FOUND SHEET: NUMBERS -> NUMBERS.BMP (2378 bytes)
   Sheet size: 99.0×13.0
   Extracting 11 sprites
ℹ️ INFO: NUMS_EX.BMP not found (normal for many skins)
```

**Interpretation:** ✅ NORMAL - Classic skin format
**Action:** None needed
**Result:** Digits render from NUMBERS perfectly

### Actual Problems (Require Attention)

#### Scenario 3: Missing BOTH Number Systems

```
⚠️ MISSING SHEET: NUMBERS.bmp/.png not found in archive
⚠️ Sheet 'NUMBERS' is missing - generating 11 fallback sprites
ℹ️ INFO: NUMS_EX.BMP not found (normal for many skins)
⚠️ Note: Some sprites are using transparent fallbacks
```

**Interpretation:** ⚠️ PROBLEM - Skin is incomplete/broken
**Action:** Skin still loads but digits will be invisible
**Result:** App doesn't crash but UX is degraded

#### Scenario 4: Corrupted BMP File

```
✅ FOUND SHEET: NUMBERS -> NUMBERS.BMP (corrupt)
❌ FAILED to create image for sheet: NUMBERS
⚠️ Sheet 'NUMBERS' corrupted - generating fallbacks
```

**Interpretation:** ❌ ERROR - File is damaged
**Action:** Consider re-downloading skin
**Result:** Fallbacks allow app to continue

---

## Project Organization

### Before: Confusing Assets Folder

```
MacAmpApp/
├── Assets/
│   ├── Winamp.wsz         ← Mixed with other assets
│   └── AppIcon.icns       ← Not clear what's a skin
```

**Problems:**
- Unclear what files are skins
- Hard to find skin files
- Package.swift processes all Assets/

### After: Dedicated Skins Folder

```
MacAmpApp/
├── Skins/                 ← Clear purpose!
│   ├── Internet-Archive.wsz
│   └── Winamp.wsz
```

**Benefits:**
- ✅ Clear separation of concerns
- ✅ Easy to add new bundled skins
- ✅ Package.swift only processes `.wsz` files
- ✅ Future: Can add skin metadata files here

**User Skins Location:**
```
~/Library/Application Support/MacAmp/Skins/
├── CustomSkin1.wsz
├── CustomSkin2.wsz
└── ...
```

---

## API Modernization: macOS 26.x (Tahoe)

### Deprecated API Removed

#### Before: Old NSUserNotificationCenter (Deprecated in macOS 11)
```swift
let notification = NSUserNotification()
notification.title = title
notification.informativeText = message
NSUserNotificationCenter.default.deliver(notification)  ❌
```

#### After: Modern UserNotifications Framework
```swift
import UserNotifications

let content = UNMutableNotificationContent()
content.title = title
content.body = message
content.sound = .default

let request = UNNotificationRequest(
    identifier: UUID().uuidString,
    content: content,
    trigger: nil
)

UNUserNotificationCenter.current().add(request)  ✅
```

**Benefits:**
- ✅ No deprecation warnings
- ✅ Modern macOS 26.x compatible
- ✅ Better notification management
- ✅ Supports rich notifications (future enhancement)

---

## Skin Import Flow

### Complete User Journey

```
1. User: Skins menu → Import Skin File... (⌘⇧O)
         ↓
2. System: NSOpenPanel opens with .wsz filter
         ↓
3. User: Selects /Downloads/MyCoolSkin.wsz
         ↓
4. MacAmp: Check if exists in user directory
         ↓
5a. If exists → Alert: "Replace or Cancel?"
    User cancels → End
         ↓
5b. User confirms or file is new
         ↓
6. MacAmp: Copy to ~/Library/.../MacAmp/Skins/
         ↓
7. MacAmp: scanAvailableSkins() discovers new skin
         ↓
8. MacAmp: switchToSkin("user:MyCoolSkin")
         ↓
9. MacAmp: Show notification "MyCoolSkin imported successfully"
         ↓
10. UI: All windows instantly update with new skin
```

**File:** `MacAmpApp/ViewModels/SkinManager.swift` (lines 85-148)

---

## Webamp vs MacAmp: Architecture Comparison

### Webamp (JavaScript/Canvas)

**Approach:**
- JavaScript + JSZip library
- Canvas API for sprite extraction
- Data URLs for sprite storage
- Redux for state management
- CSS injection for dynamic styling

**Sprite Processing:**
```javascript
sprites.forEach((sprite) => {
    canvas.height = sprite.height;
    canvas.width = sprite.width;
    context.drawImage(img, -sprite.x, -sprite.y);
    const dataURL = canvas.toDataURL();
    images[sprite.name] = dataURL;
});
```

### MacAmp (Swift/NSImage)

**Approach:**
- Swift + ZIPFoundation library
- NSImage/CoreGraphics for sprite extraction
- NSImage objects for sprite storage
- SwiftUI @Published for state management
- SwiftUI views for dynamic rendering

**Sprite Processing:**
```swift
for sprite in sprites {
    let r = sprite.rect
    if let croppedImage = sheetImage.cropped(to: r) {
        extractedImages[sprite.name] = croppedImage
    }
}
```

**Equivalent Functionality, Native Implementation**

---

## Critical Files Reference

### Skin Loading & Discovery

**MacAmpApp/Models/Skin.swift**
- Lines 65-135: `SkinMetadata.bundledSkins` (discovery logic)
- Lines 70-84: Bundle URL conditional compilation (SPM vs Xcode)
- Lines 87-111: `findSkin(named:)` with fallback paths

### Skin Management & Fallbacks

**MacAmpApp/ViewModels/SkinManager.swift**
- Lines 26-56: `scanAvailableSkins()` (bundled + user directory)
- Lines 61-73: `switchToSkin(identifier:)` (hot-reload)
- Lines 76-83: `loadInitialSkin()` (app launch)
- Lines 87-148: `importSkin(from:)` (file picker import)
- Lines 162-208: Fallback sprite generation system
- Lines 241-258: Sheet processing with fallback integration

### Sprite Definitions

**MacAmpApp/Models/SkinSprites.swift**
- Contains all sprite coordinates for all sheets
- Added `dimensions(forSprite:)` for fallback sizing
- Defines both NUMBERS and NUMS_EX layouts

### UI Integration

**MacAmpApp/SkinsCommands.swift**
- Production Skins menu
- Keyboard shortcuts (⌘⇧1-9)
- File picker integration
- User skins folder access

---

## Common Pitfalls & Solutions

### Pitfall 1: Assuming All Skins Are Identical

**Wrong:** "All skins have NUMBERS.bmp"
**Right:** "Skins have NUMBERS.bmp OR NUMS_EX.bmp OR BOTH"

**Solution:** Conditional discovery + fallback generation

### Pitfall 2: Using bundleURL Instead of resourceURL

**Wrong:** `Bundle.main.bundleURL` for Xcode builds
**Right:** `Bundle.main.resourceURL` for Xcode builds

**Why:** bundleURL points to `.app`, resourceURL points to `Resources/`

### Pitfall 3: Crashing on Missing Sprites

**Wrong:** `let digit = images["DIGIT_0"]!` (force unwrap)
**Right:** `let digit = images["DIGIT_0"] ?? fallbackSprite`

**Solution:** Fallback system ensures all keys exist

### Pitfall 4: Duplicate Menu Commands

**Wrong:** Define .commands on each WindowGroup
**Right:** Define .commands once on last scene

**Why:** SwiftUI applies commands globally across all windows

---

## Testing Checklist

### Build Verification

- [ ] SPM build: `swift build` completes with 0 errors, 0 warnings
- [ ] Xcode build: Succeeds via Xcode or MCP tools
- [ ] Both skins present in build outputs
- [ ] No deprecation warnings (macOS 26.x compatibility)

### Menu Verification

- [ ] Single "Skins" menu in menu bar (not duplicated)
- [ ] No "Debug" menu present
- [ ] "View" menu with window toggles
- [ ] "Appearance" menu with Liquid Glass options

### Skin Switching (Classic Winamp)

- [ ] Press ⌘⇧1
- [ ] Observe: Green digits
- [ ] Observe: Classic Winamp colors/style
- [ ] Check: All 3 windows update simultaneously
- [ ] Verify: No console errors

### Skin Switching (Internet Archive)

- [ ] Press ⌘⇧2
- [ ] Observe: White/light digits (NOT green)
- [ ] Observe: Modern silver/chrome style
- [ ] Check: Digits display "00:00" correctly
- [ ] Verify: Console shows "⚠️ MISSING SHEET: NUMBERS" (normal!)
- [ ] Verify: Console shows "✅ OPTIONAL: Found NUMS_EX.BMP"

### Skin Import

- [ ] Skins → Import Skin File... (⌘⇧O)
- [ ] Select a .wsz file
- [ ] Verify: File copied to ~/Library/.../MacAmp/Skins/
- [ ] Verify: Skin appears in "My Skins" section
- [ ] Verify: App switches to imported skin automatically
- [ ] Verify: Notification shown on success

### Persistence

- [ ] Switch to Internet Archive skin
- [ ] Quit app (⌘Q)
- [ ] Relaunch app
- [ ] Verify: Internet Archive loads (not Classic Winamp)
- [ ] Check: Console shows "Loading initial skin: bundled:Internet-Archive"

---

## Future Enhancements

### 1. Skin Metadata Display

**Show users what's in their skins:**
```swift
struct SkinInfoPanel: View {
    let skin: Skin

    var body: some View {
        List {
            Section("Sprite Sheets Found") {
                ForEach(availableSheets) { sheet in
                    HStack {
                        Text(sheet.name)
                        Spacer()
                        Text("\(sheet.spriteCount) sprites")
                    }
                }
            }

            Section("Missing/Using Fallbacks") {
                ForEach(missingSheets) { sheet in
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text(sheet.name)
                    }
                }
            }
        }
    }
}
```

### 2. Smart Number Sprite Selection

**Prioritize NUMS_EX when both exist:**
```swift
// In UI code that renders digits
let digitSprite: NSImage? = {
    if let extended = images["DIGIT_0_EX"] {
        return extended  // Prefer extended
    }
    return images["DIGIT_0"]  // Fallback to classic
}()
```

### 3. Online Skin Browser

**Internet Archive Integration:**
- Browse https://skins.webamp.org from within app
- Preview thumbnails
- One-click download and install
- Automatic import to user directory

### 4. Skin Compatibility Score

**Rate skins on completeness:**
```swift
struct SkinCompatibility {
    let hasAllRequired: Bool      // 11 core sheets present
    let hasExtendedFeatures: Bool // NUMS_EX, EQ_EX, etc.
    let corruptedSheets: Int      // Failed to decode
    let fallbackCount: Int        // Using placeholders

    var score: Float {
        // 100% = all required + all optional
        // 90% = all required, some optional
        // 50% = all required, using fallbacks
        // <50% = missing required sheets
    }
}
```

---

## Documentation Files Map

### Primary Documentation

1. **`docs/winamp-skins-lessons.md`** - THIS FILE
   - Complete knowledge base
   - Lessons learned
   - Architecture decisions
   - Testing procedures

2. **`SESSION_STATE.md`** - Session-specific state
   - Current status
   - Recent changes
   - Build commands
   - Temporary working notes

### Supporting Documentation

3. **`tasks/winamp-skin-research-2025.md`** - Original research
   - Webamp clone analysis (8,300+ words)
   - Initial implementation planning

4. **`tasks/sprite-fallback-system/README.md`** - Fallback system
   - Implementation details
   - Testing guide
   - Technical deep-dive

### External References

5. **Webamp Clone:** `/Users/hank/dev/src/MacAmp/webamp_clone`
   - Reference implementation (JavaScript)
   - Sprite definitions (skinSprites.ts)
   - Parser logic (skinParser.js, skinParserUtils.ts)

6. **Re-Amp (macOS Winamp):** https://re-amp.ru/skins/
   - Native macOS implementation
   - Skin compatibility examples

7. **Internet Archive:** https://skins.webamp.org
   - ~70,000 classic Winamp skins
   - Testing resource

---

## Quick Reference Commands

### Build & Run
```bash
# SPM build
swift build && .build/debug/MacAmpApp

# Xcode build (via MCP)
# (use Xcode MCP build_macos tool)

# Clean build
swift clean && swift build
```

### Skin Verification
```bash
# Check bundled skins (SPM)
ls -la .build/arm64-apple-macosx/debug/MacAmp_MacAmpApp.bundle/*.wsz

# Check bundled skins (Xcode)
ls -la ~/Library/Developer/Xcode/DerivedData/MacAmpApp-*/Build/Products/Debug/MacAmpApp.app/Contents/Resources/*.wsz

# Check user skins
ls -la ~/Library/Application\ Support/MacAmp/Skins/
```

### Extract Skin for Inspection
```bash
# Create temp directory
mkdir -p tmp/SkinName

# Extract .wsz (it's just a ZIP)
unzip MacAmpApp/Skins/Internet-Archive.wsz -d tmp/Internet-Archive

# List BMP files
ls -la tmp/Internet-Archive/*.bmp

# View a BMP file
open tmp/Internet-Archive/NUMS_EX.bmp
```

---

## Conclusion

### What We Know For Certain

1. ✅ **Digits are sprites**, not dynamically rendered fonts
2. ✅ **Two number systems exist** (NUMBERS and NUMS_EX), rarely both
3. ✅ **Skins vary dramatically** in completeness and feature support
4. ✅ **Fallback system is essential** for robust skin support
5. ✅ **Bundle discovery differs** between SPM and Xcode builds
6. ✅ **Warning logs are often normal**, not errors

### What's Working Perfectly

- ✅ Both build systems (SPM and Xcode) discover skins correctly
- ✅ Both bundled skins load and render accurately
- ✅ Fallback system handles incomplete skins gracefully
- ✅ Skins menu provides production-ready UI
- ✅ Import functionality works as designed
- ✅ No deprecated APIs (macOS 26.x ready)

### What's Ready for User Testing

- **Skin switching** via keyboard shortcuts
- **Skin import** via file picker
- **Persistence** across app restarts
- **Visual verification** that digits change with skins

---

**Document Status:** Production Ready
**Maintenance:** Update when new skin format variations discovered
**Owner:** MacAmp Development Team
**Last Updated:** 2025-10-12
