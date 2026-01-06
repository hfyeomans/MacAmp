# MILKDROP Window Resize - State

## Current Status

**Phase**: Phase 7 - Testing (blocked on Xcode project file)
**Branch**: `feature/milkdrop-window-resize`
**Last Updated**: 2026-01-05

---

## Commit History

| Commit | Phase | Description |
|--------|-------|-------------|
| `655c5d3` | Phase 1 | Foundation: Size2D presets + MilkdropWindowSizeState |
| `39bc227` | Phase 2 | Size state wiring + WindowCoordinator + ButterchurnBridge |
| `104db69` | Phase 3 | Dynamic chrome layout |
| `34c9c87` | Phase 4 | Resize gesture with AppKit preview overlay |

**Note**: Phases 5 (WindowCoordinator integration) and 6 (Butterchurn canvas sync) were implemented as part of Phase 2 commit to ensure proper initial NSWindow sync.

---

## Implementation Progress

### Phase 1: Foundation ✅ COMPLETE
- [x] Size2D presets (milkdropMinimum, milkdropDefault, toMilkdropPixels)
- [x] MilkdropWindowSizeState class with titlebar computed properties

### Phase 2: Size State Wiring ✅ COMPLETE
- [x] Add sizeState to WinampMilkdropWindow
- [x] Pass to MilkdropWindowChromeView
- [x] Initial NSWindow sync in onAppear
- [x] WindowCoordinator.updateMilkdropWindowSize() (Phase 5 bundled here)
- [x] ButterchurnBridge.setSize() initial sync (Phase 6 bundled here)

### Phase 3: Dynamic Chrome ✅ COMPLETE
- [x] Remove fixed layout enum
- [x] Dynamic titlebar (7 sections, gold expansion)
- [x] Dynamic borders
- [x] Dynamic bottom bar (two-piece tiles)
- [x] Dynamic content area

### Phase 4: Resize Gesture ✅ COMPLETE
- [x] Drag state properties
- [x] Resize handle view builder
- [x] onChanged handler with preview
- [x] onEnded handler with commit

### Phase 5: WindowCoordinator ✅ COMPLETE (bundled in Phase 2)
- [x] updateMilkdropWindowSize() with top-left anchoring

### Phase 6: Butterchurn ✅ COMPLETE (bundled in Phase 2)
- [x] Verify/add setSize() method
- [x] Wire up on resize end

### Phase 7: Testing ⏳ IN PROGRESS
- [ ] Add MilkdropWindowSizeState.swift to Xcode project (BLOCKING)
- [ ] Build with sanitizer
- [ ] Size tests (min/default/large)
- [ ] Visual tests (titlebar, letters, bottom bar)
- [ ] Butterchurn scaling tests
- [ ] Persistence test
- [ ] Integration tests
- [ ] Final Oracle review

---

## Blocking Issues

**BLOCKING**: MilkdropWindowSizeState.swift exists in git but not in Xcode project.
User needs to add the file via Xcode:
1. Right-click `Models` group in Project Navigator
2. "Add Files to MacAmpApp..."
3. Select `MilkdropWindowSizeState.swift`
4. Ensure "MacAmp" target is checked

---

## Files Changed

| File | Action | Status |
|------|--------|--------|
| `Size2D.swift` | MODIFY | ✅ Complete |
| `MilkdropWindowSizeState.swift` | CREATE | ✅ Created, ⚠️ Not in Xcode |
| `WinampMilkdropWindow.swift` | MODIFY | ✅ Complete |
| `MilkdropWindowChromeView.swift` | MODIFY | ✅ Complete |
| `WindowCoordinator.swift` | MODIFY | ✅ Complete |
| `ButterchurnBridge.swift` | VERIFY/MODIFY | ✅ Complete (setSize exists) |

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
