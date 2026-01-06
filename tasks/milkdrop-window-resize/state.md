# MILKDROP Window Resize - State

## Current Status

**Phase**: Plan Oracle-Reviewed and Corrected, Ready for Implementation
**Branch**: `feature/milkdrop-window-resize`
**Last Updated**: 2026-01-05

---

## Oracle Review Summary

**Initial Review**: Needs Changes
**Issues Identified**: 5 (2 High, 3 Medium)
**Status**: All issues addressed in updated plan

### Issues Fixed:
1. ✅ **[High] Size-state wiring** - Added Phase 2 for WinampMilkdropWindow wiring + initial NSWindow sync
2. ✅ **[High] Titlebar math** - Created MILKDROP-specific formula with goldFillerTilesPerSide computed property
3. ✅ **[Medium] WindowCoordinator anchoring** - Changed to proper top-left anchoring pattern
4. ✅ **[Medium] Overlay API** - Corrected to `show(in:previewSize:)` instead of `show(for:targetSize:)`
5. ✅ **[Medium] Bridge access** - Added `@Environment(ButterchurnBridge.self)` to MilkdropWindowChromeView

### Titlebar Strategy Decision:
**Expand gold fillers symmetrically, keep center grey at 3 tiles (75px fixed)**

---

## Implementation Approach

Following the **exact same pattern** as VIDEO and Playlist window resize:

1. **Size2D Model** - Add MILKDROP presets (same 25×29 segment quantization)
2. **MilkdropWindowSizeState** - Copy VideoWindowSizeState pattern + titlebar computed properties
3. **Size State Wiring** - Add to WinampMilkdropWindow with initial NSWindow sync
4. **Dynamic Chrome** - Tile sprites based on sizeState computed properties
5. **Resize Gesture** - DragGesture with quantized delta, AppKit preview overlay
6. **WindowCoordinator** - Add updateMilkdropWindowSize with top-left anchoring
7. **Butterchurn Sync** - Call setSize() on canvas when resize completes

---

## Files to Change

| File | Action | Status |
|------|--------|--------|
| `Size2D.swift` | MODIFY | Pending |
| `MilkdropWindowSizeState.swift` | CREATE | Pending |
| `WinampMilkdropWindow.swift` | MODIFY | Pending |
| `MilkdropWindowChromeView.swift` | MODIFY | Pending |
| `WindowCoordinator.swift` | MODIFY | Pending |
| `ButterchurnBridge.swift` | VERIFY/MODIFY | Pending |

---

## Progress Tracking

### Phase 1: Foundation
- [ ] Size2D presets (milkdropMinimum, milkdropDefault, toMilkdropPixels)
- [ ] MilkdropWindowSizeState class with titlebar computed properties

### Phase 2: Size State Wiring
- [ ] Add sizeState to WinampMilkdropWindow
- [ ] Pass to MilkdropWindowChromeView
- [ ] Initial NSWindow sync in onAppear

### Phase 3: Dynamic Chrome
- [ ] Remove fixed layout enum
- [ ] Dynamic titlebar (7 sections, gold expansion)
- [ ] Dynamic borders
- [ ] Dynamic bottom bar (two-piece tiles)
- [ ] Dynamic content area

### Phase 4: Resize Gesture
- [ ] Drag state properties
- [ ] Resize handle view builder
- [ ] onChanged handler with preview
- [ ] onEnded handler with commit

### Phase 5: WindowCoordinator
- [ ] updateMilkdropWindowSize() with top-left anchoring

### Phase 6: Butterchurn
- [ ] Verify/add setSize() method
- [ ] Wire up on resize end

### Phase 7: Testing
- [ ] Build with sanitizer
- [ ] Size tests (min/default/large)
- [ ] Visual tests (titlebar, letters, bottom bar)
- [ ] Butterchurn scaling tests
- [ ] Persistence test
- [ ] Integration tests
- [ ] Final Oracle review

---

## Blocking Issues

None currently.

---

## Key Technical Details

### Titlebar Layout (7 sections, expansion via gold fillers)
```
LEFT_CAP(25) + LEFT_GOLD(n×25) + LEFT_END(25) + CENTER(3×25=75) + RIGHT_END(25) + RIGHT_GOLD(n×25) + RIGHT_CAP(25)
```

- Fixed: 100px (caps + ends)
- Center: 75px (fixed 3 grey tiles)
- Variable: LEFT_GOLD + RIGHT_GOLD expand symmetrically

### Computed Properties for Titlebar
- `goldFillerTilesPerSide = (width - 100 - 75) / 2 / 25`
- `centerSectionStartX = 25 + goldFillerTilesPerSide * 25 + 25`
- `milkdropLettersCenterX = centerSectionStartX + 37.5`

### Content Area
- Width: pixelSize.width - 19 (11 left + 8 right borders)
- Height: pixelSize.height - 34 (20 titlebar + 14 bottom bar)

### APIs
- Overlay: `resizePreview.show(in: window, previewSize: CGSize)`
- Bridge: `bridge.setSize(width: CGFloat, height: CGFloat)`
