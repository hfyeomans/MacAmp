# MILKDROP Window Resize - TODO

## Phase 1: Foundation (Size2D + MilkdropWindowSizeState)

### 1.1 Size2D Presets
- [ ] Add `milkdropMinimum` preset to Size2D.swift (0,0 = 275×116)
- [ ] Add `milkdropDefault` preset to Size2D.swift (0,4 = 275×232)
- [ ] Add `toMilkdropPixels()` method to Size2D.swift

### 1.2 MilkdropWindowSizeState.swift (NEW FILE)
- [ ] Create `MacAmpApp/Models/MilkdropWindowSizeState.swift`
- [ ] Add `@MainActor @Observable` class declaration
- [ ] Implement `size: Size2D` property with `didSet { saveSize() }`
- [ ] Implement `pixelSize` computed property
- [ ] Implement `centerWidth` (window - 250)
- [ ] Implement `centerTileCount` (centerWidth / 25)
- [ ] Implement `contentHeight` (window - 34)
- [ ] Implement `contentWidth` (window - 19)
- [ ] Implement `verticalBorderTileCount` (ceil(contentHeight / 29))
- [ ] Implement `contentSize` (CGSize)
- [ ] Implement `goldFillerTilesPerSide` (titlebar gold tiles)
- [ ] Implement `centerGreyTileCount` (fixed at 3)
- [ ] Implement `centerSectionStartX` (after left gold + left end)
- [ ] Implement `milkdropLettersCenterX` (centerSectionStartX + 37.5)
- [ ] Implement `saveSize()` with UserDefaults key "milkdropWindowSize"
- [ ] Implement `loadSize()` with default fallback
- [ ] Implement `resetToDefault()` convenience method
- [ ] Implement `setToMinimum()` convenience method
- [ ] Add `init()` that calls `loadSize()`

---

## Phase 2: Size State Wiring (WinampMilkdropWindow)

### 2.1 Add State Property
- [ ] Add `@State private var sizeState = MilkdropWindowSizeState()`

### 2.2 Wire to Chrome View
- [ ] Update `MilkdropWindowChromeView` call to pass `sizeState`
- [ ] Add `.frame(width: sizeState.pixelSize.width, height: sizeState.pixelSize.height)`
- [ ] Add `.fixedSize()`

### 2.3 Initial NSWindow Sync
- [ ] In `.onAppear`, call `coordinator.updateMilkdropWindowSize(to: clampedSize)`
- [ ] Use `round()` for integral coordinates

---

## Phase 3: Dynamic Chrome Layout (MilkdropWindowChromeView)

### 3.1 Update View Signature
- [ ] Add `sizeState: MilkdropWindowSizeState` parameter
- [ ] Add `@Environment(ButterchurnBridge.self) private var bridge`
- [ ] Add computed `pixelSize` and `contentSize` properties

### 3.2 Remove Fixed Layout
- [ ] Delete `MilkdropWindowLayout` enum entirely

### 3.3 Dynamic Titlebar (7 sections)
- [ ] Extract to `buildDynamicTitlebar()` method
- [ ] Section 1: Left cap at x: 12.5
- [ ] Section 2: Left gold tiles (dynamic count)
- [ ] Section 3: Left end at x: centerStart - 12.5
- [ ] Section 4: Center grey tiles (fixed 3)
- [ ] Section 5: Right end at x: centerStart + 75 + 12.5
- [ ] Section 6: Right gold tiles (symmetric)
- [ ] Section 7: Right cap at x: pixelSize.width - 12.5
- [ ] Position milkdropLetters at sizeState.milkdropLettersCenterX

### 3.4 Dynamic Vertical Borders
- [ ] Extract to `buildDynamicBorders()` method
- [ ] Use `sizeState.verticalBorderTileCount` for loop
- [ ] Position left border at x: 5.5
- [ ] Position right border at x: pixelSize.width - 4

### 3.5 Dynamic Bottom Bar
- [ ] Extract to `buildDynamicBottomBar()` method
- [ ] Calculate bottomBarY = pixelSize.height - 7
- [ ] LEFT section at x: 62.5
- [ ] CENTER tiles using `sizeState.centerTileCount`
- [ ] TWO-PIECE: GEN_BOTTOM_FILL_TOP (13px) + GEN_BOTTOM_FILL_BOTTOM (1px)
- [ ] RIGHT section at x: pixelSize.width - 62.5

### 3.6 Dynamic Content Area
- [ ] Update content frame to use `contentSize`
- [ ] Update position to x: pixelSize.width / 2, y: 20 + contentSize.height / 2

### 3.7 Outer Frame
- [ ] Update .frame to use `pixelSize`

---

## Phase 4: Resize Gesture

### 4.1 State Properties
- [ ] Add `@State private var dragStartSize: Size2D?`
- [ ] Add `@State private var isDragging: Bool = false`
- [ ] Add `@State private var resizePreview = WindowResizePreviewOverlay()`

### 4.2 Resize Handle View
- [ ] Create `buildResizeHandle()` method
- [ ] Rectangle with clear fill, 20×20 frame
- [ ] `contentShape(Rectangle())` for hit testing
- [ ] Position at (pixelSize.width - 10, pixelSize.height - 10)

### 4.3 Drag Gesture - onChanged
- [ ] Initialize `dragStartSize` on first tick
- [ ] Set `isDragging = true`
- [ ] Call `WindowSnapManager.shared.beginProgrammaticAdjustment()`
- [ ] Calculate widthDelta = round(translation.width / 25)
- [ ] Calculate heightDelta = round(translation.height / 29)
- [ ] Create candidate Size2D with max(0, ...) clamping
- [ ] Get window via `coordinator.milkdropWindow`
- [ ] Call `resizePreview.show(in: window, previewSize:)` (CORRECT API)

### 4.4 Drag Gesture - onEnded
- [ ] Calculate final Size2D from total translation
- [ ] Set `sizeState.size = finalSize`
- [ ] Call `coordinator.updateMilkdropWindowSize(to: sizeState.pixelSize)`
- [ ] Call `resizePreview.hide()`
- [ ] Call `bridge.setSize(width: contentSize.width, height: contentSize.height)`
- [ ] Call `WindowSnapManager.shared.endProgrammaticAdjustment()`
- [ ] Reset: `isDragging = false`, `dragStartSize = nil`

---

## Phase 5: WindowCoordinator Integration

### 5.1 Add Resize Method
- [ ] Add `updateMilkdropWindowSize(to size: CGSize)` to WindowCoordinator
- [ ] Use `round()` for integer coordinates
- [ ] Calculate top-left anchor point
- [ ] Update frame.origin for top-left anchoring (y = topLeft.y - roundedSize.height)
- [ ] Call `window.setFrame(frame, display: true)`

---

## Phase 6: Butterchurn Canvas Sync

### 6.1 ButterchurnBridge
- [ ] Check if `setSize(width:height:)` exists
- [ ] If missing, add method calling `window.macampButterchurn?.setSize()`
- [ ] Guard on `isReady` and `webView`

### 6.2 Wire Up
- [ ] Call `setSize()` in resize gesture `.onEnded` (already in Phase 4.4)
- [ ] Optionally call in WinampMilkdropWindow `.onAppear` for initial sync

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
