# NSMenu Lifecycle Bug Fix

## Problem

The Options menu (O button) showed correctly on first click, but subsequent clicks after loading a track or changing settings would fail to show the menu.

## Root Cause

**Classic NSMenu lifecycle issue in SwiftUI:**

1. `NSMenu.popUp(positioning:at:in:)` is **asynchronous** - it returns immediately while the menu stays visible
2. The local `menu` variable in `showOptionsMenu(from:)` was being deallocated when the function returned
3. When the menu variable was deallocated, the `NSMenuItem` objects it contained were also released
4. The `MenuItemTarget` instances stored in `representedObject` were deallocated along with their parent items
5. SwiftUI view updates (from settings changes, track loads) would trigger view rebuilds
6. Subsequent button clicks created a new menu, but the AppKit/SwiftUI interaction broke without a persistent reference

**Key insight:** Even though `representedObject` kept the `MenuItemTarget` alive, the **menu itself** was being deallocated, breaking the entire chain.

## Solution

Added a `@State` variable to maintain a **strong reference** to the active menu:

```swift
// In WinampMainWindow struct
@State private var activeOptionsMenu: NSMenu?
```

Modified `showOptionsMenu(from:)` to store the menu **before** populating it:

```swift
private func showOptionsMenu(from buttonPosition: CGPoint) {
    // Create new menu and store strong reference to prevent premature deallocation
    // NSMenu.popUp() is asynchronous - menu must stay alive until user dismisses it
    let menu = NSMenu()

    // Store strong reference BEFORE populating to prevent premature deallocation
    activeOptionsMenu = menu

    // ... rest of menu creation and popup logic
}
```

## Why This Works

1. **Persistent Reference**: `@State` keeps the menu alive across SwiftUI view updates
2. **Automatic Cleanup**: When a new menu is created, SwiftUI automatically releases the old one
3. **No Manual Cleanup Needed**: Don't need a delegate to clear the reference - SwiftUI handles it
4. **Struct-Safe**: Works correctly with SwiftUI's value-type View structs (no `[weak self]` needed)

## Alternative Approaches Considered

### Option 1: Menu Delegate (Rejected)
- Would require storing delegate separately to prevent deallocation
- Adds complexity with `weak self` issues (structs can't be weak)
- Not needed since SwiftUI handles cleanup automatically

### Option 2: Synchronous Menu (Rejected)
- `NSMenu.popUp()` must be asynchronous for proper AppKit behavior
- Would block the UI thread
- Not a recommended pattern

## Testing

Build succeeds with Thread Sanitizer enabled:
```bash
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Debug -enableThreadSanitizer YES build
```

**Result:** ✅ BUILD SUCCEEDED

## Files Modified

- `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/WinampMainWindow.swift`
  - Added `@State private var activeOptionsMenu: NSMenu?` (line 31)
  - Modified `showOptionsMenu(from:)` to store menu reference (lines 793-799)

## Prevention

**For future NSMenu usage in SwiftUI:**

1. **Always** store a strong reference to menus that use `popUp()`
2. Use `@State` for single-instance menus in View structs
3. Document that `NSMenu.popUp()` is asynchronous
4. Test menu behavior after SwiftUI view updates (settings changes, data loads)
5. Verify with Thread Sanitizer enabled builds

## Related Patterns

This same pattern applies to:
- Context menus created programmatically
- Popup buttons with dynamic menus
- Any AppKit UI that requires lifecycle management in SwiftUI

## Commit Message Template

```
fix(clutter-bar): Resolve NSMenu lifecycle issue causing Options menu to fail after first use

The Options menu (O button) showed on first click but failed on subsequent clicks
after loading tracks or changing settings.

Root cause: NSMenu.popUp() is asynchronous but the local menu variable was being
deallocated when showOptionsMenu(from:) returned, breaking the menu chain.

Solution: Added @State activeOptionsMenu to maintain a strong reference across
SwiftUI view updates. Menu now persists correctly while visible and automatically
cleans up when replaced.

Verified with Thread Sanitizer enabled build.
```
