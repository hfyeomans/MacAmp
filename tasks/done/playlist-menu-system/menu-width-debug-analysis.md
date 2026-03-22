# NSMenu Width Inconsistency - Debug Analysis

**Date**: 2025-10-26
**Screenshot**: `/Users/hank/dev/src/MacAmp/Screenshot 2025-10-26 at 6.23.27 PM.png`

## Visual Analysis of Screenshot

### Observed Issue
The SEL menu (middle menu) appears **visually wider on the right edge** compared to the REM and MISC menus. The gray background extends further to the right, creating a noticeable asymmetry.

### Menu Comparison
- **REM menu** (left): Normal width, background aligned with sprite edges
- **SEL menu** (middle): **WIDER background**, extends beyond sprite on right side
- **MISC menu** (right): Normal width, background aligned with sprite edges

### Visual Evidence
The SEL menu shows approximately **3-5 extra pixels of gray background** extending past the right edge of the menu items, while the other menus have tight alignment.

## Current Implementation Review

### SpriteMenuItem.swift - Lines 12-23

```swift
class HoverTrackingView: NSView {
    // Fixed menu item dimensions to ensure consistent menu width
    private let fixedWidth: CGFloat = 22
    private let fixedHeight: CGFloat = 18

    override var intrinsicContentSize: NSSize {
        // Force fixed size to prevent NSMenu from auto-sizing based on content
        return NSSize(width: fixedWidth, height: fixedHeight)
    }
}
```

**Status**: ✅ Correctly implemented - returns fixed 22×18 size

### SpriteMenuItem.swift - Lines 141-152

```swift
struct SpriteMenuItemView: View {
    var body: some View {
        if let image = skinManager.currentSkin?.images[isHovered ? selectedSprite : normalSprite] {
            Image(nsImage: image)
                .resizable()
                .frame(width: 22, height: 18)
                .fixedSize()  // Prevent flexible sizing
        } else {
            Color.gray
                .frame(width: 22, height: 18)
                .fixedSize()  // Prevent flexible sizing
        }
    }
}
```

**Status**: ✅ Correctly implemented - fixed frame with .fixedSize()

### SpriteMenuItem.swift - Lines 109-111

```swift
let hosting = NSHostingView(rootView: spriteView)
hosting.frame = container.bounds
hosting.autoresizingMask = [.width, .height]
```

**Status**: ⚠️ **POTENTIAL ISSUE** - `autoresizingMask` allows hosting view to resize!

### WinampPlaylistWindow.swift - showSelMenu()

```swift
private func showSelMenu() {
    let menu = NSMenu()
    menu.autoenablesItems = false

    // Add 3 sprite menu items...
    // No explicit width/size constraints on NSMenu itself

    menu.popUp(positioning: nil, at: location, in: contentView)
}
```

**Status**: ⚠️ No menu width constraints applied

## Root Cause Analysis

### Why intrinsicContentSize Alone Isn't Enough

NSMenu's width calculation involves multiple layers:

1. **NSMenuItem.view's intrinsicContentSize** - ✅ Fixed at 22×18
2. **NSHostingView's frame** - ⚠️ Can auto-resize due to autoresizingMask
3. **NSMenu's automatic sizing** - Measures total content including:
   - Menu item insets (left/right padding)
   - Text rendering bounds (even with custom views)
   - Maximum width of all items
4. **NSMenuItem internal margins** - Default system insets

### The NSHostingView Problem

The critical issue is on **line 111**:

```swift
hosting.autoresizingMask = [.width, .height]
```

This tells NSHostingView to **automatically resize** to fill its superview. Even though HoverTrackingView returns intrinsicContentSize of 22×18, the hosting view might be expanding beyond this during layout, especially if SwiftUI's layout engine is providing flexible sizing hints.

### NSMenu's Hidden Padding

NSMenu adds **default horizontal insets** to menu items. These insets are:
- Left margin: ~4-6px (for checkmark space)
- Right margin: ~8-10px (for submenu arrow space)

Even with a fixed content size, NSMenu adds these margins, which can vary based on:
- Menu item type (standard vs. custom view)
- macOS version
- System text size settings

## Proposed Solutions

### Solution 1: Remove autoresizingMask from NSHostingView ✅ RECOMMENDED

**Change line 111 in SpriteMenuItem.swift:**

```swift
// BEFORE:
hosting.autoresizingMask = [.width, .height]

// AFTER:
// Remove autoresizingMask entirely - let intrinsicContentSize control sizing
```

**Rationale**: Forces NSHostingView to respect the fixed frame without auto-resizing.

### Solution 2: Override frame in HoverTrackingView

**Add to HoverTrackingView class:**

```swift
override var frame: NSRect {
    get { super.frame }
    set {
        // Force frame to always be our fixed size
        super.frame = NSRect(origin: newValue.origin,
                           size: NSSize(width: fixedWidth, height: fixedHeight))
    }
}
```

**Rationale**: Prevents any external layout from changing the view's size.

### Solution 3: Set NSMenu.minimumWidth

**Add to showSelMenu() after menu creation:**

```swift
let menu = NSMenu()
menu.autoenablesItems = false
menu.minimumWidth = 22  // Force minimum width to match sprite width
```

**Rationale**: Provides explicit constraint on menu width calculation.

### Solution 4: Override NSMenuItem.view setter ⚠️ COMPLEX

**Add to SpriteMenuItem class:**

```swift
override var view: NSView? {
    get { super.view }
    set {
        super.view = newValue
        // Force menu item to use view's intrinsic size only
        if let view = newValue {
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.widthAnchor.constraint(equalToConstant: 22),
                view.heightAnchor.constraint(equalToConstant: 18)
            ])
        }
    }
}
```

**Rationale**: Uses Auto Layout constraints to enforce size (may conflict with NSMenu's internal layout).

### Solution 5: Investigate SEL Menu Sprite Names

**Check if specific sprites have different intrinsic sizes:**

```bash
# Check actual image dimensions loaded for SEL menu sprites
print("PLAYLIST_INVERT_SELECTION size:", image.size)
print("PLAYLIST_SELECT_ZERO size:", image.size)
print("PLAYLIST_SELECT_ALL size:", image.size)
```

**Rationale**: One of the SEL menu sprites might have incorrect dimensions in the skin file.

## Recommended Implementation Order

1. **First**: Remove `autoresizingMask` from NSHostingView (Solution 1)
2. **Second**: Add `menu.minimumWidth = 22` (Solution 3)
3. **Third**: Override `frame` setter in HoverTrackingView (Solution 2) - only if still needed
4. **Debug**: Add logging to verify sprite image dimensions (Solution 5)

## Testing Plan

After each solution:

1. Build and run app with Thread Sanitizer enabled
2. Open SEL menu multiple times
3. Take screenshots comparing REM, SEL, and MISC menus side-by-side
4. Measure background width in pixels using digital ruler/measurement tool
5. Verify all three menus have identical background width
6. Test with different skins to ensure consistency

## Additional Debugging Commands

```swift
// Add to SpriteMenuItem.setupView() for debugging:
print("Container intrinsicContentSize: \(container.intrinsicContentSize)")
print("Hosting frame: \(hosting.frame)")
print("Container frame: \(container.frame)")
print("Sprite name: \(normalSpriteName)")
if let image = skinManager.currentSkin?.images[normalSpriteName] {
    print("Image actual size: \(image.size)")
}
```

## References

- Apple NSMenu documentation: Default item insets
- Apple NSHostingView: autoresizingMask behavior with SwiftUI
- Apple Auto Layout: translatesAutoresizingMaskIntoConstraints
- SwiftUI .fixedSize() behavior within NSHostingView

## Next Steps

1. Implement Solution 1 (remove autoresizingMask)
2. Build with Thread Sanitizer
3. Test and take new screenshot
4. If still inconsistent, proceed to Solution 3 (minimumWidth)
5. Document final working solution
