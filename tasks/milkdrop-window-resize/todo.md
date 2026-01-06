# MILKDROP Window Resize - TODO

**Last Updated**: 2026-01-05

## Commit History
- `655c5d3` - Phase 1: Foundation
- `39bc227` - Phase 2: Size state wiring (includes Phase 5 & 6)
- `104db69` - Phase 3: Dynamic chrome layout
- `34c9c87` - Phase 4: Resize gesture

**Note**: Phases 5 & 6 were implemented as part of Phase 2 for proper initialization.

---

## Phase 1: Foundation (Size2D + MilkdropWindowSizeState) ✅ COMPLETE

### 1.1 Size2D Presets
- [x] Add `milkdropMinimum` preset to Size2D.swift (0,0 = 275×116)
- [x] Add `milkdropDefault` preset to Size2D.swift (0,4 = 275×232)
- [x] Add `toMilkdropPixels()` method to Size2D.swift

### 1.2 MilkdropWindowSizeState.swift (NEW FILE)
- [x] Create `MacAmpApp/Models/MilkdropWindowSizeState.swift`
- [x] Add `@MainActor @Observable` class declaration
- [x] Implement `size: Size2D` property with `didSet { saveSize() }`
- [x] Implement `pixelSize` computed property
- [x] Implement `centerWidth` (window - 250)
- [x] Implement `centerTileCount` (centerWidth / 25)
- [x] Implement `contentHeight` (window - 34)
- [x] Implement `contentWidth` (window - 19)
- [x] Implement `verticalBorderTileCount` (ceil(contentHeight / 29))
- [x] Implement `contentSize` (CGSize)
- [x] Implement `goldFillerTilesPerSide` (titlebar gold tiles)
- [x] Implement `centerGreyTileCount` (fixed at 3)
- [x] Implement `centerSectionStartX` (after left gold + left end)
- [x] Implement `milkdropLettersCenterX` (centerSectionStartX + 37.5)
- [x] Implement `saveSize()` with UserDefaults key "milkdropWindowSize"
- [x] Implement `loadSize()` with default fallback
- [x] Implement `resetToDefault()` convenience method
- [x] Implement `setToMinimum()` convenience method
- [x] Add `init()` that calls `loadSize()`
- [x] **⚠️ ADD TO XCODE PROJECT** (added manually by user)

---

## Phase 2: Size State Wiring (WinampMilkdropWindow) ✅ COMPLETE

### 2.1 Add State Property
- [x] Add `@State private var sizeState = MilkdropWindowSizeState()`

### 2.2 Wire to Chrome View
- [x] Update `MilkdropWindowChromeView` call to pass `sizeState`
- [x] Add `.frame(width: sizeState.pixelSize.width, height: sizeState.pixelSize.height)`
- [x] Add `.fixedSize()`

### 2.3 Initial NSWindow Sync
- [x] In `.onAppear`, call `coordinator.updateMilkdropWindowSize(to: clampedSize)`
- [x] Use `round()` for integral coordinates

**Note**: Phase 5 (WindowCoordinator) and Phase 6 (Butterchurn) were also implemented here.

---

## Phase 3: Dynamic Chrome Layout (MilkdropWindowChromeView) ✅ COMPLETE

### 3.1 Update View Signature
- [x] Add `sizeState: MilkdropWindowSizeState` parameter
- [x] Add `@Environment(ButterchurnBridge.self) private var bridge`
- [x] Add computed `pixelSize` and `contentSize` properties

### 3.2 Remove Fixed Layout
- [x] Delete `MilkdropWindowLayout` enum entirely

### 3.3 Dynamic Titlebar (7 sections)
- [x] Extract to `buildDynamicTitlebar()` method
- [x] Section 1: Left cap at x: 12.5
- [x] Section 2: Left gold tiles (dynamic count)
- [x] Section 3: Left end at x: centerStart - 12.5
- [x] Section 4: Center grey tiles (fixed 3)
- [x] Section 5: Right end at x: centerStart + 75 + 12.5
- [x] Section 6: Right gold tiles (symmetric)
- [x] Section 7: Right cap at x: pixelSize.width - 12.5
- [x] Position milkdropLetters at sizeState.milkdropLettersCenterX

### 3.4 Dynamic Vertical Borders
- [x] Extract to `buildDynamicBorders()` method
- [x] Use `sizeState.verticalBorderTileCount` for loop
- [x] Position left border at x: 5.5
- [x] Position right border at x: pixelSize.width - 4

### 3.5 Dynamic Bottom Bar
- [x] Extract to `buildDynamicBottomBar()` method
- [x] Calculate bottomBarY = pixelSize.height - 7
- [x] LEFT section at x: 62.5
- [x] CENTER tiles using `sizeState.centerTileCount`
- [x] TWO-PIECE: GEN_BOTTOM_FILL_TOP (13px) + GEN_BOTTOM_FILL_BOTTOM (1px)
- [x] RIGHT section at x: pixelSize.width - 62.5

### 3.6 Dynamic Content Area
- [x] Update content frame to use `contentSize`
- [x] Update position to x: pixelSize.width / 2, y: 20 + contentSize.height / 2

### 3.7 Outer Frame
- [x] Update .frame to use `pixelSize`

---

## Phase 4: Resize Gesture ✅ COMPLETE

### 4.1 State Properties
- [x] Add `@State private var dragStartSize: Size2D?`
- [x] Add `@State private var isDragging: Bool = false`
- [x] Add `@State private var resizePreview = WindowResizePreviewOverlay()`

### 4.2 Resize Handle View
- [x] Create `buildResizeHandle()` method
- [x] Rectangle with clear fill, 20×20 frame
- [x] `contentShape(Rectangle())` for hit testing
- [x] Position at (pixelSize.width - 10, pixelSize.height - 10)

### 4.3 Drag Gesture - onChanged
- [x] Initialize `dragStartSize` on first tick
- [x] Set `isDragging = true`
- [x] Call `WindowSnapManager.shared.beginProgrammaticAdjustment()`
- [x] Calculate widthDelta = round(translation.width / 25)
- [x] Calculate heightDelta = round(translation.height / 29)
- [x] Create candidate Size2D with max(0, ...) clamping
- [x] Get window via `coordinator.milkdropWindow`
- [x] Call `resizePreview.show(in: window, previewSize:)` (CORRECT API)

### 4.4 Drag Gesture - onEnded
- [x] Calculate final Size2D from total translation
- [x] Set `sizeState.size = finalSize`
- [x] Call `coordinator.updateMilkdropWindowSize(to: sizeState.pixelSize)`
- [x] Call `resizePreview.hide()`
- [x] Call `bridge.setSize(width: contentSize.width, height: contentSize.height)`
- [x] Call `WindowSnapManager.shared.endProgrammaticAdjustment()`
- [x] Reset: `isDragging = false`, `dragStartSize = nil`

---

## Phase 5: WindowCoordinator Integration ✅ COMPLETE (bundled in Phase 2)

### 5.1 Add Resize Method
- [x] Add `updateMilkdropWindowSize(to size: CGSize)` to WindowCoordinator
- [x] Use `round()` for integer coordinates
- [x] Calculate top-left anchor point
- [x] Update frame.origin for top-left anchoring (y = topLeft.y - roundedSize.height)
- [x] Call `window.setFrame(frame, display: true)`

---

## Phase 6: Butterchurn Canvas Sync ✅ COMPLETE (bundled in Phase 2)

### 6.1 ButterchurnBridge
- [x] Check if `setSize(width:height:)` exists
- [x] If missing, add method calling `window.macampButterchurn?.setSize()`
- [x] Guard on `isReady` and `webView`

### 6.2 Wire Up
- [x] Call `setSize()` in resize gesture `.onEnded` (already in Phase 4.4)
- [x] Optionally call in WinampMilkdropWindow `.onAppear` for initial sync

---

## Phase 7: Testing & Polish

### 7.1 Build
- [ ] Build with Thread Sanitizer enabled
- [ ] Verify no data race warnings
- [ ] Verify no compiler warnings

### 7.2 Size Tests
- [ ] Test minimum size (275×116)
- [ ] Test default size (275×232)
- [ ] Test medium size (400×350)
- [ ] Test large size (600×500)
- [ ] Test extra large (800×700)

### 7.3 Visual Tests
- [ ] **Titlebar tiles correctly at wider widths**
- [ ] **MILKDROP HD letters stay centered at all widths**
- [ ] Bottom bar tiles correctly
- [ ] Side borders tile correctly
- [ ] No gaps or overlaps

### 7.4 Butterchurn Tests
- [ ] Canvas scales correctly at all sizes
- [ ] Visualization continues during/after resize
- [ ] No black bars or clipping

### 7.5 Resize Behavior
- [ ] Drag handle appears in correct position
- [ ] Resize snaps to 25×29 segments
- [ ] AppKit preview overlay shows during drag
- [ ] Preview hides after drag ends
- [ ] Window frame updates correctly
- [ ] Top-left corner stays anchored

### 7.6 Persistence
- [ ] Resize to custom size
- [ ] Quit app
- [ ] Relaunch app
- [ ] Window restores to saved size

### 7.7 Integration
- [ ] Test resize with magnetic docking enabled
- [ ] Test resize while audio is playing
- [ ] Test resize while visualization is paused
- [ ] Test rapid resize gestures

### 7.8 Code Review
- [ ] Oracle review of all changes
- [ ] Verify pattern compliance with VIDEO

---

## Quick Reference

### Dimensions
```
Base: 275×116 at Size2D[0,0]
Default: 275×232 at Size2D[0,4]
Segments: 25px width, 29px height
```

### Chrome Heights
```
Titlebar: 20px
Bottom bar: 14px
Total chrome: 34px
```

### Border Widths
```
Left border: 11px
Right border: 8px
Total borders: 19px
```

### Content Area
```
Width: pixelSize.width - 19
Height: pixelSize.height - 34
```

### Titlebar Layout (7 sections)
```
LEFT_CAP(25) + LEFT_GOLD(n×25) + LEFT_END(25) + CENTER(3×25=75) + RIGHT_END(25) + RIGHT_GOLD(n×25) + RIGHT_CAP(25)
Fixed: 100px (caps + ends)
Center: 75px (fixed 3 grey tiles)
Variable: LEFT_GOLD + RIGHT_GOLD (expand symmetrically)
```

### Bottom Bar Layout
```
LEFT: 125px (fixed)
CENTER: n × 25px tiles (two-piece: 13px + 1px)
RIGHT: 125px (fixed, contains resize corner)
```

### APIs
```
Overlay: resizePreview.show(in: window, previewSize: CGSize)
Bridge: bridge.setSize(width: CGFloat, height: CGFloat)
```
