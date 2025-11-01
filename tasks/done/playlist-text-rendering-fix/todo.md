# Playlist Text Rendering Fix - TODO

**Branch:** `fix/playlist-text-rendering`
**Status:** ✅ COMPLETE
**Time:** 45 minutes actual

---

## ✅ Implementation Checklist - ALL COMPLETE

### **Step 1: Replace Bitmap Fonts with Real Text** ✅

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift` (trackRow function)

- [x] Replace track number PlaylistBitmapText with Text
  - Used `.font(.system(size: 9, design: .monospaced))`
  - Kept `.frame(width: 18, alignment: .trailing)`

- [x] Replace track title/artist PlaylistBitmapText with Text
  - Used `.font(.system(size: 9))`
  - Added `.lineLimit(1)` and `.truncationMode(.tail)`
  - Kept `.frame(maxWidth: .infinity, alignment: .leading)`

- [x] Replace duration PlaylistBitmapText with Text
  - Used `.font(.system(size: 9, design: .monospaced))`
  - Kept `.frame(width: 38, alignment: .trailing)`

### **Step 2: Fix Background Highlight** ✅

- [x] Removed duplicate highlight for current track
  - Current track now only uses text color (white), no background
  - Selected tracks use background color (blue)
  - Fixed trackBackground() to only check selectedIndices

### **Step 3: Fix Keyboard Monitor** ✅

- [x] Store keyboard monitor reference in @State
- [x] Add .onDisappear cleanup
- [x] Use [self] capture to maintain reference
- [x] Verified shortcuts persist through all interactions

### **Step 4: Build and Test** ✅

- [x] Build with xcodebuildMCP and Thread Sanitizer
- [x] Verify track text renders (not bitmap sprites)
- [x] Verify current track shows in white with NO background
- [x] Verify normal tracks show in green
- [x] Verify selected tracks show blue background
- [x] Test long titles truncate with "..."
- [x] Test keyboard shortcuts persist (Cmd+A, Escape, Cmd+D)
- [x] Test after CROP operation
- [x] Test after track selection changes

### **Step 5: Advanced Testing** ✅

- [x] Tested with different skins (colors change correctly)
- [x] Tested Command+A works continuously
- [x] Tested Escape/Cmd+D work continuously
- [x] Verified performance is good

---

## Success Criteria - ALL MET ✅

- [x] Track text uses native SwiftUI Text
- [x] PLEDIT.txt colors applied (green normal, white current, blue selected)
- [x] Unicode support enabled (native Text handles it)
- [x] Long titles truncate properly
- [x] Matches Winamp visual appearance
- [x] Faster rendering than bitmap fonts
- [x] Current track doesn't have duplicate highlight
- [x] Keyboard shortcuts work persistently

---

## Bugs Fixed

1. **Duplicate Highlight:** Current track had blue background + white text (incorrect)
   - **Fixed:** Current track now has white text, NO background (correct)

2. **Keyboard Shortcuts Stop Working:** Cmd+A/Escape/Cmd+D stopped after track interactions
   - **Fixed:** Store monitor reference, add cleanup, persist through interactions

---

**Status:** ✅ COMPLETE - Ready for PR
**Total Time:** 45 minutes
**Files Modified:** 1 file (WinampPlaylistWindow.swift)
