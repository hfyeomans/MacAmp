# Phase 4 - Known Issues & Warnings

**Date:** 2025-10-13
**Branch:** `feature/phase4-polish-bugfixes`

---

## 🟡 Non-Critical Warnings

### Xcode Menu Warning (didChangeImage)

**Severity:** Low - Does not affect functionality
**Frequency:** Multiple times when showing/hiding EQ window

**Console Output:**
```
didChangeImage: rep returned item view with wrong item:
  index=0
  expected item = <SwiftUI.SwiftUIMenuItem: 0x70ff2a940 Minimize, ke='Command-M', action: performMiniaturize:, action image: minus.rectangle>
  actual item = <SwiftUI.SwiftUIMenuItem: 0x70fcaa640 Minimize, ke='Command-M', action: performMiniaturize:, action image: minus.rectangle>
```

**Analysis:**
- Internal SwiftUI/AppKit menu system warning
- Appears related to menu item image representation
- Two different memory addresses for functionally identical items
- Happens when EQ window visibility changes
- Does NOT impact user functionality

**Possible Causes:**
1. SwiftUI menu system recreating menu items
2. Window show/hide triggering menu reconstruction
3. Multiple window groups with same menu commands
4. AppKit/SwiftUI menu bridge issue

**Impact:**
- ⚠️ Console noise only
- ✅ Minimize menu item works correctly
- ✅ No visual glitches
- ✅ No crashes or errors

**Action:**
- 🔍 **Monitor** - Note if issue worsens or affects functionality
- ⏸️ **Defer** - Low priority, cosmetic warning only
- 📝 **Document** - Keep record for future investigation

**Potential Fix (If Needed):**
- Review AppCommands.swift menu definitions
- Check if menu items are being duplicated
- Consider using explicit menu item IDs
- May be fixed in future macOS/Xcode updates

---

## ✅ Expected Limitations (Not Bugs)

### EQ Preset Persistence Not Implemented

**Status:** By design - TODO for future implementation

**Current Behavior:**
- "Save" button opens dialog ✅
- User can enter preset name ✅
- Dialog dismisses ✅
- Preset is NOT saved to disk ⚠️ (as expected)

**Code Location:**
`MacAmpApp/Views/WinampEqualizerWindow.swift:237`

```swift
if alert.runModal() == .alertFirstButtonReturn {
    let presetName = textField.stringValue
    if !presetName.isEmpty {
        let _ = audioPlayer.getCurrentEQPreset(preset)
        // TODO (P1): Implement EQ preset persistence
        // Should: Save user presets to disk (JSON or .eqf format)
        // Storage: ~/Library/Application Support/MacAmp/EQPresets/
        print("Saved preset: \(presetName)")
    }
}
```

**Why This is OK:**
- Built-in presets (17) all work perfectly ✅
- Save UI/UX works ✅
- Just missing persistence layer
- Documented TODO with priority
- Not blocking release

**Future Implementation:**
- Save to `~/Library/Application Support/MacAmp/EQPresets/`
- Format: JSON or .eqf (classic format)
- Load saved presets in popover
- Add "Custom" section in popover

---

## 📊 Issue Summary

| Issue | Severity | Status | Impact | Action |
|-------|----------|--------|--------|--------|
| EQ Menu Glitching | 🔴 Critical | ✅ FIXED | High - UX | Replaced with popover |
| Xcode Menu Warning | 🟡 Low | 📝 NOTED | None | Monitor |
| Preset Persistence | 🟢 Enhancement | ⏸️ TODO | Low | Future feature |

---

**Last Updated:** 2025-10-13
**Overall Status:** 🟢 All critical issues resolved
