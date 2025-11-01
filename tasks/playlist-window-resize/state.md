# Playlist Window Resize - Current State

**Date:** 2025-10-23
**Status:** Research Complete, Implementation Deferred to P4
**Priority:** P4 (Low - Post 1.0 Release)

---

## Task Metadata

- **Task ID:** `playlist-window-resize`
- **Related Tasks:**
  - `playlist-state-sync` (completed - revealed the three-section issue)
- **Blocked By:** None
- **Blocking:** None (nice-to-have feature)
- **Estimated Effort:** 8-12 hours total implementation

---

## Current Status Summary

### ✅ Completed
- [x] Research phase complete
- [x] webamp_clone analysis done
- [x] Three-section layout structure documented
- [x] Connection to playlist-state-sync task documented
- [x] Gemini research prompts created for user

### ⏸️ Deferred
- [ ] Run Gemini research prompts (user will do this)
- [ ] Create detailed implementation plan
- [ ] Implement three-section layout
- [ ] Add window resize functionality
- [ ] Test with multiple skins
- [ ] Update documentation

---

## Problem Statement

**Current Situation:**
MacAmp's playlist window is **fixed size** and uses a **two-section bottom layout** (LEFT + RIGHT only), which is a workaround that prevents the window from being resizable.

**Desired Situation:**
Playlist window should be **resizable** like classic Winamp, using a **three-section layout** (LEFT + CENTER + RIGHT) where the center section expands/contracts based on window width.

**Impact:**
- **Low Priority:** Works fine at fixed size, just missing a nice-to-have feature
- **User Experience:** Users expect Winamp playlist to be resizable (classic behavior)
- **Technical Debt:** Current workaround disables PLAYLIST_BOTTOM_TILE sprite, preventing proper skin rendering

---

## Technical Details

### Current Architecture (MacAmp)

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

**Bottom Section Structure:**
```swift
// Current (2-section workaround):
HStack(spacing: 0) {
    // Left section (125px)
    SimpleSpriteImage("PLAYLIST_BOTTOM_LEFT_CORNER", ...)

    // Right section (154px) - DIRECTLY adjacent, no gap
    SimpleSpriteImage("PLAYLIST_BOTTOM_RIGHT_CORNER", ...)
}
```

**Issues:**
1. No center section means no room for expansion
2. PLAYLIST_BOTTOM_TILE sprite disabled to prevent overlap
3. Total width locked at ~279px (125 + 154)
4. Window cannot resize without layout breaking

### Reference Architecture (webamp_clone)

**Files:**
- `webamp_clone/packages/webamp/js/components/PlaylistWindow/index.tsx`
- `webamp_clone/packages/webamp/css/playlist-window.css`

**Bottom Section Structure:**
```tsx
<div className="playlist-bottom draggable">
  <div className="playlist-bottom-left draggable">       {/* 125px, absolute left */}
    <AddMenu />
    <RemoveMenu />
    {/* ... */}
  </div>

  <div className="playlist-bottom-center draggable" />  {/* EXPANDABLE CENTER */}

  <div className="playlist-bottom-right draggable">     {/* 150px, absolute right */}
    <PlaylistActionArea />
    <ListMenu />
    <PlaylistResizeTarget />
    {/* ... */}
  </div>
</div>
```

**CSS Layout Strategy:**
```css
.playlist-bottom {
  width: 100%;
  height: 38px;
  position: relative;  /* Container */
}

.playlist-bottom-left {
  width: 125px;
  position: absolute;  /* Fixed to left */
  left: 0;
}

.playlist-bottom-center {
  /* Implicitly fills gap between left and right */
  /* Background tiles here */
}

.playlist-bottom-right {
  width: 150px;
  position: absolute;  /* Fixed to right */
  right: 0;
}
```

**Key Insight:**
Left and right are **absolutely positioned**, leaving the center to **fill the remaining space** automatically. When window resizes, the gap between left and right grows/shrinks.

---

## Sprite Sheet Analysis

**File:** `tmp/Winamp/PLEDIT.BMP` (280×72 pixels)

### Bottom Section Sprites

**Current Definitions (SkinSprites.swift):**
```swift
Sprite(name: "PLAYLIST_BOTTOM_LEFT_CORNER", x: 0, y: 72, width: 125, height: 38)
Sprite(name: "PLAYLIST_BOTTOM_RIGHT_CORNER", x: 126, y: 72, width: 154, height: 38)
// Note: Width discrepancy - webamp uses 150px for right section
```

**Missing Definition:**
```swift
// Need to add:
Sprite(name: "PLAYLIST_BOTTOM_CENTER_TILE", x: ?, y: 72, width: ?, height: 38)
// Purpose: Tiles horizontally in the center expandable section
// Width: Likely 1-2px for seamless tiling
```

**Top Section Sprites:**
Similar pattern exists for the top bar:
- `PLAYLIST_TOP_LEFT_FILL` - Tiles in left expandable area
- `PLAYLIST_TOP_RIGHT_FILL` - Tiles in right expandable area
- `PLAYLIST_TOP_TITLE` - Center title (100px fixed)

---

## Implementation Requirements

### 1. Three-Section Layout

**Bottom Section Redesign:**
```swift
ZStack {
    // Background layer (center tiling)
    GeometryReader { geometry in
        SimpleSpriteImage("PLAYLIST_BOTTOM_CENTER_TILE", ...)
            .frame(width: geometry.size.width)  // Full width
            // Position under left/right sections
    }

    // Foreground layer (left/right absolute positioned)
    HStack(spacing: 0) {
        // Left section
        SimpleSpriteImage("PLAYLIST_BOTTOM_LEFT_CORNER", ...)
            .frame(width: 125, height: 38)

        Spacer()  // EXPANDABLE CENTER GAP

        // Right section
        SimpleSpriteImage("PLAYLIST_BOTTOM_RIGHT_CORNER", ...)
            .frame(width: 150, height: 38)  // Note: 150px not 154px
    }
}
.frame(height: 38)
```

### 2. Window Resize Support

**Window Configuration:**
```swift
WindowGroup {
    WinampPlaylistWindow()
        .frame(minWidth: 275, minHeight: 200)  // Minimum size (125 + 150)
        .frame(idealWidth: 275, idealHeight: 300)
        .frame(maxWidth: 1000, maxHeight: 1000)  // Reasonable maximum
}
.windowResizability(.contentSize)  // Allow resizing
```

**Resize Handle:**
- Add drag gesture to bottom-right corner (20×20px area)
- Update window frame on drag
- Constrain to min/max sizes
- Or use built-in macOS resize functionality

### 3. State Management

**Window Size Tracking:**
```swift
@State private var playlistWindowSize: CGSize = CGSize(width: 275, height: 300)

// Update when window resizes
.onChange(of: playlistWindowSize) { newSize in
    // Recalculate center section width
    let centerWidth = newSize.width - 125 - 150  // Left - Right
    // Update UI accordingly
}
```

### 4. Sprite Tiling

**Center Section Background:**
```swift
Image(nsImage: centerTileSprite)
    .resizable(resizingMode: .tile)  // Tile horizontally
    .frame(width: centerWidth, height: 38)
```

---

## Risks & Considerations

### Risk 1: Breaking Other Windows
**Mitigation:** Changes are isolated to WinampPlaylistWindow.swift, no impact on main/EQ windows

### Risk 2: Sprite Size Discrepancy
**Issue:** Current code uses 154px for right section, webamp uses 150px
**Impact:** May need to adjust sprite definitions
**Mitigation:** Test with actual skin files, measure exact pixels

### Risk 3: Performance During Resize
**Issue:** Frequent re-layout during drag could be laggy
**Mitigation:**
- Use `.drawingGroup()` for sprite rendering optimization
- Debounce resize events if needed
- Profile with Instruments

### Risk 4: Skin Compatibility
**Issue:** Different skins may have different PLEDIT.BMP layouts
**Mitigation:**
- Test with multiple skins (Classic Winamp, Internet Archive, etc.)
- Provide fallback if center tile sprite missing
- Document skin requirements

---

## Success Criteria

### Must Have
- [ ] Playlist window can be resized by dragging bottom-right corner
- [ ] Minimum size: 275×200 (center section hidden)
- [ ] Maximum size: Reasonable limit (~1000×1000)
- [ ] Three-section layout: LEFT (125px) + CENTER (expandable) + RIGHT (150px)
- [ ] Center section displays tiled background sprite
- [ ] Left/right sections remain fixed width during resize
- [ ] No visual artifacts or sprite overlap
- [ ] Works with Classic Winamp skin
- [ ] State persists between app launches (window size remembered)

### Should Have
- [ ] Smooth resize animation
- [ ] Resize handle visual feedback (cursor change on hover)
- [ ] Works with multiple skins (Internet Archive, etc.)
- [ ] Top section also expands properly (left-fill, right-fill)
- [ ] Keyboard shortcuts for resize (Cmd + Plus/Minus?)

### Nice to Have
- [ ] Snap to increments (resize in 10px chunks?)
- [ ] Double-click title bar to toggle size (min/max)
- [ ] Remember size per-skin (different skins, different sizes)
- [ ] Accessibility: VoiceOver announces window size changes

---

## Files to Modify (Preliminary List)

### 1. `MacAmpApp/Views/WinampPlaylistWindow.swift`
**Changes:**
- Redesign bottom section layout (2-section → 3-section)
- Add window size state management
- Implement resize handling
- Update sprite positioning

**Lines:** ~120-140 (bottom section), entire file may need refactor

### 2. `MacAmpApp/Parsers/SkinSprites.swift`
**Changes:**
- Add `PLAYLIST_BOTTOM_CENTER_TILE` sprite definition
- Verify `PLAYLIST_BOTTOM_RIGHT_CORNER` width (154px vs 150px)
- Add any missing top section sprites for expandable areas

**Lines:** ~230-235 (PLAYLIST sprites)

### 3. `MacAmpApp/MacAmpApp.swift` (or window group definition)
**Changes:**
- Add window resize configuration
- Set min/max size constraints
- Configure windowResizability

**Lines:** Wherever WindowGroup for playlist is defined

### 4. (Optional) New File: `MacAmpApp/Views/PlaylistResizeHandle.swift`
**Purpose:** Custom resize handle view
**Content:** Drag gesture implementation for bottom-right corner

---

## Dependencies

### Internal Dependencies
- Skin system must properly load PLEDIT.BMP sprites ✅ (already working)
- Sprite rendering must handle tiling ❓ (needs verification)
- Window management infrastructure ❓ (needs investigation)

### External Dependencies
- None (all SwiftUI/AppKit built-in functionality)

---

## Timeline (Deferred to P4)

**Phase 1: Sprite Definitions** (1 hour)
- Add PLAYLIST_BOTTOM_CENTER_TILE
- Verify sprite coordinates
- Test sprite loading

**Phase 2: Three-Section Layout** (2 hours)
- Refactor bottom section to ZStack + HStack + Spacer
- Position left/right absolutely
- Add center background tiling

**Phase 3: Window Resize** (2 hours)
- Add window size configuration
- Implement resize constraints
- Add resize handle (if custom)

**Phase 4: State Management** (1 hour)
- Track window size in AppSettings
- Persist size between launches
- Handle size change events

**Phase 5: Testing** (2 hours)
- Test min/max sizes
- Test with multiple skins
- Performance profiling
- Visual verification

**Phase 6: Polish** (2 hours)
- Smooth animations
- Hover effects
- Edge case handling
- Documentation

**Total Estimated Time:** 10 hours

---

## Next Actions

### For User (Now)
1. ✅ Review research.md and this state.md
2. ⏳ Run Gemini research prompts from `gemini-research-prompt.md`
3. ⏳ Save Gemini outputs to task folder
4. ⏳ Review findings and ask clarifying questions

### For Implementation (Future - P4)
1. ⏸️ Create detailed plan.md based on research
2. ⏸️ Create implementation branch
3. ⏸️ Implement phase-by-phase
4. ⏸️ Test and verify
5. ⏸️ Create PR when complete

---

## Questions for Further Research

1. **Sprite Coordinates:**
   - What is the exact X, Y, Width, Height for PLAYLIST_BOTTOM_CENTER_TILE?
   - Is it 1px wide for seamless tiling, or a repeating pattern?

2. **Window Sizing:**
   - Does SwiftUI's built-in resize handle work, or do we need custom?
   - How to constrain resize to horizontal-only or both dimensions?

3. **Performance:**
   - Is real-time sprite tiling during drag performant enough?
   - Should we use cached/pre-rendered background?

4. **Multi-Skin:**
   - Do all skins have the same PLEDIT.BMP structure?
   - How to handle skins missing center tile sprite?

**These questions should be answered by running the Gemini research prompts.**

---

## References

- **Research:** `research.md` (this folder)
- **Gemini Prompts:** `gemini-research-prompt.md` (this folder)
- **Related Task:** `tasks/playlist-state-sync/` (completed)
- **webamp_clone:** `webamp_clone/packages/webamp/js/components/PlaylistWindow/`
- **Sprites:** `tmp/Winamp/PLEDIT.BMP`

---

**Last Updated:** 2025-10-23
**Status:** Ready for user research via Gemini CLI
**Next Milestone:** P4 (Post 1.0 Release)
