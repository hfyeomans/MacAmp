# UnifiedDockView Migration Analysis

**Date**: 2025-11-08  
**Source**: UnifiedDockView.swift (354 lines, from git history)  
**Purpose**: Identify critical logic to migrate to WindowCoordinator

---

## Critical Features to Migrate

### 1. Skin Loading (ensureSkin) - IMMEDIATE

**UnifiedDockView Lines 92-96**:
```swift
private func ensureSkin() {
    if skinManager.currentSkin == nil {
        skinManager.loadInitialSkin()
    }
}
```

**Issue**: Skins don't auto-load on launch  
**Fix Location**: WindowCoordinator.init() or configureWindows()  
**Priority**: HIGH (user must manually refresh)

**Migration**:
```swift
// In WindowCoordinator.init(), after showAllWindows():
private func ensureSkinsLoaded(skinManager: SkinManager) {
    if skinManager.currentSkin == nil {
        skinManager.loadInitialSkin()
    }
}
```

---

### 2. Always-On-Top (window.level) - IMMEDIATE

**UnifiedDockView Lines 65-68**:
```swift
.onChange(of: settings.isAlwaysOnTop) { _, isOn in
    // Toggle THIS window's level
    dockWindow?.level = isOn ? .floating : .normal
}
```

**And Lines 80**:
```swift
// Set initial window level based on persisted state
window.level = settings.isAlwaysOnTop ? .floating : .normal
```

**Issue**: Always-on-top (Ctrl+A / A button) broken  
**Fix Location**: WindowCoordinator needs to observe AppSettings.isAlwaysOnTop  
**Priority**: HIGH (common feature)

**Migration**:
```swift
// In WindowCoordinator, observe AppSettings
func observeAlwaysOnTop(settings: AppSettings) {
    // Watch settings.isAlwaysOnTop
    // When changed, update all 3 window levels
}

func updateWindowLevels(alwaysOnTop: Bool) {
    let level: NSWindow.Level = alwaysOnTop ? .floating : .normal
    mainWindow?.level = level
    eqWindow?.level = level
    playlistWindow?.level = level
}
```

---

### 3. Window Configuration (configureWindow) - PARTIALLY DONE

**UnifiedDockView Lines 99-126**:
```swift
private func configureWindow(_ window: NSWindow) {
    window.styleMask.insert(.borderless)
    window.styleMask.remove(.titled)
    window.isMovableByWindowBackground = false
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.toolbar = nil
    window.level = .normal
    window.isMovable = true
}
```

**Status**: Mostly migrated to NSWindowController init  
**Missing**: window.isMovable = true (allow dragging)  
**Fix**: Add to NSWindowController convenience init

---

### 4. WindowAccessor Pattern - ALREADY EXISTS

**UnifiedDockView Lines 70-82**:
- WindowAccessor exists in codebase
- Used to capture NSWindow reference
- Store in @State variable for later manipulation

**Migration**: Already have WindowAccessor available for Phase 1B (drag regions)

---

### 5. Double-Size Scaling - PLANNED FOR PHASE 4

**UnifiedDockView Lines 35-53** (scaling logic):
```swift
let scale: CGFloat = settings.isDoubleSizeMode ? 2.0 : 1.0
windowContent(for: pane.type)
    .scaleEffect(scale, anchor: .topLeading)
    .frame(width: baseSize.width * scale,
           height: pane.isShaded ? 14 * scale : baseSize.height * scale)
```

**Status**: Deferred to Phase 4 (Days 13-15)  
**Note**: Each window view will handle its own scaling  
**Already Planned**: Yes (in original plan)

---

### 6. Shade Mode - DEFERRED

**UnifiedDockView Line 41**:
```swift
height: pane.isShaded ? 14 * scale : baseSize.height * scale
```

**Status**: Not in foundation scope  
**Note**: Docking controller has isShaded property  
**Fix**: Deferred to post-foundation polish

---

### 7. Animation & Liquid Glass - NOT CRITICAL

**Lines 129-236** - Background animations and materials

**Status**: Visual polish only  
**Priority**: LOW (nice-to-have)  
**Note**: Can be added per-window later if desired

---

## Immediate Day 2 Fixes Required

### Fix #1: Skin Auto-Loading
**Priority**: HIGH  
**Code**: Add ensureSkin call to WindowCoordinator  
**Time**: 10 minutes

### Fix #2: Always-On-Top
**Priority**: HIGH  
**Code**: Observe AppSettings.isAlwaysOnTop, update window levels  
**Time**: 30 minutes

### Fix #3: Window.isMovable
**Priority**: MEDIUM  
**Code**: Add window.isMovable = true to configureWindows()  
**Time**: 5 minutes

---

## What Can Wait

- ⏳ Double-size scaling (Phase 4, planned)
- ⏳ Shade mode (post-foundation)
- ⏳ Liquid Glass animations (visual polish)
- ⏳ Material backgrounds (visual polish)

---

**Immediate Action**: Fix #1, #2, #3 in Day 2  
**Analysis Complete**: All critical features identified  
**Next**: Implement fixes, test, continue Phase 1A
