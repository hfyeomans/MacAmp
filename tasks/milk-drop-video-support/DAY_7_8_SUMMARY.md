# Day 7-8: Milkdrop Window Foundation - Session Summary

**Date:** 2025-11-14
**Session Duration:** ~8 hours
**Status:** Day 7 COMPLETE ✅, Day 8 PARTIAL (Butterchurn blocked)

---

## Completed Features ✅

### 1. GEN.bmp Chrome Rendering (Day 7)
- ✅ 22 GEN sprite definitions in SkinSprites.swift
- ✅ 6-section titlebar (symmetric left/right layout)
- ✅ Two-piece GEN_BOTTOM_FILL (13px + 1px, no cyan line)
- ✅ Side borders (11px left, 8px right) tiled vertically
- ✅ Bottom bar (left corner + center tile + right corner with resizer)
- ✅ Close button in titlebar
- ✅ Active/inactive titlebar states

**Key Learning:** GEN sprites have TWO-PIECE structure (main + 1px bottom) separated by cyan delimiters, same as letters.

### 2. Window Integration (Day 7)
- ✅ WinampMilkdropWindowController created (matches TASK 1 pattern)
- ✅ WindowCoordinator integration (5-window architecture)
- ✅ AppSettings.showMilkdropWindow with persistence
- ✅ Keyboard shortcut: Ctrl+K (changed from Ctrl+Shift+K)
- ✅ Window persistence (position saves/restores correctly)
- ✅ Default vertical stacking (below Video window)
- ✅ WindowSnapManager registration (magnetic snapping works)

**Critical Fix:** NSWindowController contentViewController lifecycle - removed contentView overwrite that was breaking SwiftUI lifecycle.

### 3. Letter Sprite Definitions (Day 7-8)
- ✅ 32 GEN letter sprites added to SkinSprites.swift
- ✅ M, I, L, K, D, R, O, P (top + bottom pieces)
- ✅ Selected and normal states
- ✅ Coordinates verified: Y=88/95 (selected), Y=96/108 (normal)

**Deferred:** MILKDROP text rendering (GEN letter X positions vary by skin, needs dynamic extraction like webamp)

### 4. Butterchurn Integration Attempt (Day 8)
- ✅ HTML bundle created (index.html, test.html)
- ✅ Butterchurn libraries downloaded (butterchurn.min.js, butterchurnPresets.min.js)
- ✅ bridge.js communication layer created
- ✅ ButterchurnWebView.swift wrapper created
- ✅ WKWebView lifecycle fixed (green debug box shows)
- ✅ JIT entitlements enabled
- ❌ **BLOCKED:** External JavaScript files don't load in WKWebView

---

## Files Created/Modified

**Created:**
- `MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift` (140 lines)
- `MacAmpApp/Resources/Butterchurn/index.html`
- `MacAmpApp/Resources/Butterchurn/test.html`
- `MacAmpApp/Resources/Butterchurn/bridge.js`
- `MacAmpApp/Views/Windows/ButterchurnWebView.swift`
- `tasks/milk-drop-video-support/BUTTERCHURN_BLOCKERS.md`

**Modified:**
- `MacAmpApp/Models/SkinSprites.swift` (+54 GEN letter sprites, +2 BOTTOM_FILL pieces)
- `MacAmpApp/Views/WinampMilkdropWindow.swift` (integrated chrome + WebView)
- `MacAmpApp/Windows/WinampMilkdropWindowController.swift` (fixed lifecycle)
- `MacAmpApp/Windows/WinampVideoWindowController.swift` (fixed lifecycle)
- `MacAmpApp/ViewModels/WindowCoordinator.swift` (added Milkdrop observer, default positioning)
- `MacAmpApp/Models/AppSettings.swift` (added showMilkdropWindow)
- `MacAmpApp/AppCommands.swift` (added Ctrl+K shortcut)
- `MacAmpApp/MacAmp.entitlements` (enabled JIT for WKWebView)

---

## Key Discoveries

### 1. GEN.bmp Structure Insights
- **Letters have variable X positions** across skins (not hardcodable)
- **Webamp dynamically scans** pixels to detect letter boundaries per-skin
- **Two-piece sprites** (main + 1px bottom) separated by cyan delimiters
- **CENTER_FILL is also two-piece** (13px + 1px at Y=87)

### 2. Coordinate System
- **NO flipY needed** for GEN.bmp (unlike VIDEO.bmp research suggested)
- **Top-down coordinates** work as-is in SkinSprites.swift
- All current sprites render correctly

### 3. Titlebar Layout Algorithm
- **Webamp uses CSS flexbox** with `flex-grow: 1` on gold bars
- **MacAmp constraint:** Fixed 25px tiles (can't do fractional sizing)
- **Current solution:** 2 gold + 3 grey + 2 gold tiles (symmetric, 75px grey for 49px text)
- **Future:** Dynamic tile counts based on window width (for resizing)

### 4. WKWebView Challenges
- Local file:// URLs have strict security
- External .js files don't load even with entitlements
- Inline JavaScript works fine
- **Alternative:** Inject JS as strings or use native Metal

---

## Deferred Items

**High Priority (Next Session):**
1. **Butterchurn JS loading** - Try Bundle injection approach (30min)
2. **GEN dynamic letter extraction** - Implement webamp pixel-scanning (2-3 hours)

**Medium Priority:**
3. **Audio FFT tap** for visualization (Day 9)
4. **Preset selection** system (Day 10)

**Future:**
5. **Window resizing** (TASK 3 - dedicated task)
6. **Native Metal renderer** (if Butterchurn unfixable)

---

## What Works Now

**Milkdrop Window (Functional):**
- Opens/closes with Ctrl+K ✅
- GEN.bmp chrome renders pixel-perfect ✅
- Position persists across app restarts ✅
- Magnetic snapping to other windows ✅
- Drags by titlebar ✅
- Close button works ✅
- 275×232 window size matches Video/Playlist ✅

**What's Missing:**
- "MILKDROP" titlebar text (needs dynamic extraction)
- Butterchurn visualization content (WebView blocked)

**The window IS functional** - it's a working GEN window, just needs visualization content!

---

## Recommended Next Actions

**Option 1: Quick Win - Placeholder Content**
- Add simple "Milkdrop Visualization - Coming Soon" text
- Consider it "done" for now, circle back later
- Move to other features

**Option 2: Debug Butterchurn (30-60min)**
- Try Bundle JS injection approach
- If works: Continue with FFT integration
- If fails: Defer to TASK 3 or future

**Option 3: Skip Visualization Entirely**
- Milkdrop window works as a "generic window" demo
- Focus on Video window polish
- Come back to visualization later

**What would you like to tackle next?**
- Video window refinement?
- Another feature from the backlog?
- Create a release/demo with current state?

---

**Session End:** 2025-11-14
**Total Implementation Time (Days 7-8):** ~8 hours
**Lines Added:** ~400 lines
**Build Status:** ✅ Clean, Thread Sanitizer passed
