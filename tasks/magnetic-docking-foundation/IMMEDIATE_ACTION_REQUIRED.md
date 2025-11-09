# IMMEDIATE ACTION REQUIRED - Add BorderlessWindow.swift

**Created File**: `MacAmpApp/Windows/BorderlessWindow.swift`  
**Status**: On disk but NOT in Xcode project  
**Build**: Failing (cannot find 'BorderlessWindow')

---

## User Action Needed (2 minutes)

### In Xcode IDE:

1. **Find the file**:
   - File exists at: `MacAmpApp/Windows/BorderlessWindow.swift`

2. **Add to project**:
   - Right-click "Windows" group in Project Navigator
   - Choose "Add Files to 'MacAmp'..."
   - Navigate to MacAmpApp/Windows/
   - Select: BorderlessWindow.swift
   - Ensure "MacAmp" target is checked
   - Click "Add"

3. **Build** (⌘B):
   - Should succeed now
   - BorderlessWindow will be in scope

4. **Test** (⌘R):
   - Click buttons/sliders in windows
   - Windows should stay in front now (not fall behind)

---

## Why This File Is Critical

**BorderlessWindow.swift** (9 lines):
```swift
import AppKit

class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
```

**Purpose**: Allows borderless windows to accept clicks and become active

**Without it**: Windows fall behind when clicking buttons (UNUSABLE)

---

**After adding**: Windows will respond to clicks properly ✅
