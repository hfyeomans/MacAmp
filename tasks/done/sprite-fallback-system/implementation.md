# Sprite Fallback System Implementation

## Problem Statement
The Internet-Archive.wsz skin is missing several sprites that are expected by the application:
- **Missing sheet**: NUMBERS.bmp (contains DIGIT_0-9, MINUS_SIGN, NO_MINUS_SIGN)
- **Available alternative**: NUMS_EX.bmp (contains extended digit sprites)
- **Impact**: App logs "❌ MISSING SPRITE" errors but needs to continue functioning

## Solution Design

### Architecture
Implemented a comprehensive fallback sprite generation system in `SkinManager.swift` that:

1. **Detects missing sprites** at three levels:
   - Missing entire sprite sheets (e.g., NUMBERS.bmp not in archive)
   - Corrupted sprite sheets (image data can't be decoded)
   - Individual sprite cropping failures (rect out of bounds)

2. **Generates transparent fallback sprites** with appropriate dimensions:
   - Uses sprite definitions from `SkinSprites.defaultSprites` to get correct sizes
   - Falls back to 16x16 for undefined sprites
   - Creates transparent NSImage placeholders

3. **Maintains app stability**:
   - Never fails skin loading due to missing sprites
   - Logs warnings instead of errors
   - Provides helpful debug information

### Implementation Details

#### 1. Added Dimension Lookup in SkinSprites.swift
```swift
/// Get the dimensions for a sprite by name
func dimensions(forSprite name: String) -> CGSize? {
    guard let sprite = sprite(named: name) else { return nil }
    return CGSize(width: sprite.width, height: sprite.height)
}
```

#### 2. Created Fallback Generation Methods in SkinManager.swift

**Single sprite fallback:**
```swift
private func createFallbackSprite(named spriteName: String) -> NSImage {
    // Try to get dimensions from sprite definitions
    let size: CGSize
    if let definedSize = SkinSprites.defaultSprites.dimensions(forSprite: spriteName) {
        size = definedSize
        NSLog("⚠️ Creating fallback for '\(spriteName)' with defined size: \(definedSize.width)x\(definedSize.height)")
    } else {
        // Use a reasonable default size for unknown sprites
        size = CGSize(width: 16, height: 16)
        NSLog("⚠️ Creating fallback for '\(spriteName)' with default size: 16x16 (no definition found)")
    }

    // Create a transparent image
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()
    image.unlockFocus()

    return image
}
```

**Bulk sheet fallback:**
```swift
private func createFallbackSprites(forSheet sheetName: String, sprites: [Sprite]) -> [String: NSImage] {
    var fallbacks: [String: NSImage] = [:]

    NSLog("⚠️ Sheet '\(sheetName)' is missing - generating \(sprites.count) fallback sprites")

    for sprite in sprites {
        let fallbackImage = createFallbackSprite(named: sprite.name)
        fallbacks[sprite.name] = fallbackImage
    }

    return fallbacks
}
```

#### 3. Updated Sprite Loading Logic

**Missing sheet handling:**
```swift
guard let entry = findSheetEntry(in: archive, baseName: sheetName) else {
    NSLog("⚠️ MISSING SHEET: \(sheetName).bmp/.png not found in archive")
    NSLog("   Expected \(sprites.count) sprites from this sheet")
    // List the missing sprite names for debugging
    for sprite in sprites.prefix(5) {
        NSLog("   - Missing sprite: \(sprite.name)")
    }

    // Generate fallback sprites for this missing sheet
    let fallbackSprites = createFallbackSprites(forSheet: sheetName, sprites: sprites)
    for (name, image) in fallbackSprites {
        extractedImages[name] = image
    }

    continue
}
```

**Corrupted sheet handling:**
```swift
guard let sheetImage = NSImage(data: data) else {
    NSLog("❌ FAILED to create image for sheet: \(sheetName)")
    // Generate fallbacks for this corrupted sheet
    let fallbackSprites = createFallbackSprites(forSheet: sheetName, sprites: sprites)
    for (name, image) in fallbackSprites {
        extractedImages[name] = image
    }
    continue
}
```

**Individual sprite cropping failure:**
```swift
if let croppedImage = sheetImage.cropped(to: r) {
    extractedImages[sprite.name] = croppedImage
    print("     ✅ \(sprite.name) at \(sprite.rect)")
} else {
    NSLog("     ⚠️ FAILED to crop \(sprite.name) from \(sheetName) at \(sprite.rect)")
    NSLog("       Sheet size: \(sheetImage.size)")
    NSLog("       Requested rect: \(r)")
    NSLog("       Rect within bounds: \(r.maxX <= sheetImage.size.width && r.maxY <= sheetImage.size.height)")

    // Generate a fallback sprite for this failed crop
    let fallbackImage = createFallbackSprite(named: sprite.name)
    extractedImages[sprite.name] = fallbackImage
    NSLog("       Generated fallback sprite for '\(sprite.name)'")
}
```

#### 4. Improved Summary Logging
```swift
let expectedCount = sheetsToProcess.values.flatMap{$0}.count
let extractedCount = extractedImages.count
NSLog("=== SPRITE EXTRACTION SUMMARY ===")
NSLog("Total sprites available: \(extractedCount)")
NSLog("Expected sprites: \(expectedCount)")
if extractedCount < expectedCount {
    NSLog("⚠️ Note: Some sprites are using transparent fallbacks due to missing/corrupted sheets")
} else {
    NSLog("✅ All sprites loaded successfully!")
}
```

## Testing

### Test Case: Internet-Archive.wsz
- **Missing**: NUMBERS.bmp sheet (11 sprites)
- **Expected Behavior**:
  - App detects missing sheet
  - Generates 11 transparent fallback sprites (DIGIT_0 through DIGIT_9, MINUS_SIGN, NO_MINUS_SIGN)
  - Each fallback uses correct dimensions from sprite definitions
  - App continues to function normally
  - UI elements using these sprites are invisible (transparent) but don't crash

### Test Case: Winamp.wsz (Control)
- **Has**: All required sheets including NUMBERS.bmp
- **Expected Behavior**:
  - All sprites load successfully
  - No fallbacks generated
  - Full visual fidelity

## Benefits

1. **Robust Error Handling**: App never crashes due to missing sprites
2. **Graceful Degradation**: Missing sprites are transparent, not purple placeholders
3. **Helpful Debugging**: Clear logging shows exactly what's missing
4. **Maintains Layout**: Correct sprite dimensions preserve UI layout
5. **Future-Proof**: Works with any incomplete skin

## Files Modified

1. `/Users/hank/dev/src/MacAmp/MacAmpApp/Models/SkinSprites.swift`
   - Added `dimensions(forSprite:)` method

2. `/Users/hank/dev/src/MacAmp/MacAmpApp/ViewModels/SkinManager.swift`
   - Added `createFallbackSprite(named:)` method
   - Added `createFallbackSprites(forSheet:sprites:)` method
   - Updated sprite loading logic to use fallbacks
   - Improved logging and error messages

## Notes

- SimpleSpriteImage.swift already has fallback visualization (purple "?" rectangle) for development
- This implementation provides production-ready transparent fallbacks
- The purple placeholder in SimpleSpriteImage is still useful for debugging when a skin has NO images loaded
- Transparent fallbacks ensure incomplete skins look clean, just with missing visual elements

## Compatibility

- Swift 6.2
- macOS 26.x APIs
- @MainActor isolation maintained
- No breaking changes to existing skin loading
