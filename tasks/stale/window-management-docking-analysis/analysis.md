# Window Management and Docking Logic Analysis

## Executive Summary

This analysis identifies critical race conditions and logic problems in MacAmp's window management and docking systems. The issues span coordinate system conversions, screen boundary detection, window lifecycle management, and UI component state synchronization.

## Critical Issues Found

### 1. WindowSnapManager.swift - Race Conditions and Logic Problems

#### 1.1 Coordinate System Conversion Race Condition
**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Utilities/WindowSnapManager.swift`  
**Lines:** 41-48, 57-69

**Issue:** Virtual screen coordinate calculation is not atomic and can be corrupted during multi-monitor configuration changes.

```swift
// Lines 41-48 - Non-atomic coordinate system calculation
let virtualTop: CGFloat = allScreens.map { $0.frame.maxY }.max() ?? 0
let virtualLeft: CGFloat = allScreens.map { $0.frame.minX }.min() ?? 0
let virtualRight: CGFloat = allScreens.map { $0.frame.maxX }.max() ?? 0
let virtualBottom: CGFloat = allScreens.map { $0.frame.minY }.min() ?? 0
```

**Race Condition:** If `NSScreen.screens` changes between these calculations (e.g., monitor disconnect/connect), the coordinate system becomes inconsistent, causing windows to snap to incorrect positions or disappear off-screen.

**Impact:** Windows may snap to non-existent screen boundaries, become inaccessible, or jump to incorrect positions during monitor configuration changes.

**Trigger Scenarios:**
- Connecting/disconnecting external monitors
- Changing display resolution
- Docking/undocking laptop
- Screen arrangement changes in System Preferences

**Recommended Fix:**
```swift
// Atomic coordinate system calculation
private func calculateVirtualScreenBounds() -> (top: CGFloat, left: CGFloat, right: CGFloat, bottom: CGFloat) {
    let screens = NSScreen.screens
    guard !screens.isEmpty else { return (0, 0, 0, 0) }
    
    let top = screens.map { $0.frame.maxY }.max() ?? 0
    let left = screens.map { $0.frame.minX }.min() ?? 0
    let right = screens.map { $0.frame.maxX }.max() ?? 0
    let bottom = screens.map { $0.frame.minY }.min() ?? 0
    
    return (top, left, right, bottom)
}
```

#### 1.2 Window Reference Lifecycle Issue
**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Utilities/WindowSnapManager.swift`  
**Lines:** 14-17, 82-88

**Issue:** Weak window references can become nil during iteration without proper handling.

```swift
// Lines 82-88 - Unsafe iteration over weak references
for (_, tracked) in windows {
    if let w = tracked.window {  // Window could deallocate between check and use
        let id = ObjectIdentifier(w)
        idToWindow[id] = w
        idToBox[id] = box(for: w)
    }
}
```

**Race Condition:** Window can be deallocated between the nil check and usage, causing crashes or inconsistent state.

**Impact:** App crashes during window operations, orphaned window references, memory leaks.

**Trigger Scenarios:**
- Rapid window open/close operations
- System memory pressure causing window cleanup
- Multiple simultaneous window operations

**Recommended Fix:**
```swift
// Safe iteration with strong reference capture
for (_, tracked) in windows {
    guard let w = tracked.window else { continue }
    let id = ObjectIdentifier(w)
    idToWindow[id] = w
    idToBox[id] = box(for: w)
}
```

#### 1.3 Feedback Loop Prevention Race Condition
**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Utilities/WindowSnapManager.swift`  
**Lines:** 21, 34, 64-68, 95-102, 119-128

**Issue:** Multiple `isAdjusting` flags create race conditions in concurrent window operations.

```swift
// Lines 64-68 - Non-atomic adjustment flag
if abs(currentOrigin.x - newOrigin.x) >= 1 || abs(currentOrigin.y - newOrigin.y) >= 1 {
    isAdjusting = true
    window.setFrameOrigin(newOrigin)
    isAdjusting = false  // Race: Another thread could check flag here
}
```

**Race Condition:** Multiple window move operations can interleave, causing infinite feedback loops or missed updates.

**Impact:** Windows oscillate between positions, snap operations fail, visual glitches during window movement.

**Trigger Scenarios:**
- Rapid window dragging
- Multiple windows moving simultaneously
- System-initiated window position changes

**Recommended Fix:**
```swift
// Use atomic counter or reentrant lock
private let adjustmentLock = NSLock()
private var adjustmentDepth = 0

private func withAdjustment<T>(_ operation: () -> T) -> T {
    adjustmentLock.lock()
    defer { adjustmentLock.unlock() }
    
    adjustmentDepth += 1
    defer { adjustmentDepth -= 1 }
    
    return operation()
}
```

### 2. DockingController.swift - State Synchronization Issues

#### 2.1 Dock State Persistence Race Condition
**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/ViewModels/DockingController.swift`  
**Lines:** 53-61

**Issue:** Concurrent state changes can overwrite each other in UserDefaults.

```swift
// Lines 53-61 - Non-atomic persistence
$panes
    .dropFirst()
    .sink { [weak self] panes in
        guard let self else { return }
        if let data = try? JSONEncoder().encode(panes) {
            UserDefaults.standard.set(data, forKey: self.persistKey)  // Race condition
        }
    }
    .store(in: &cancellables)
```

**Race Condition:** Multiple rapid state changes can result in lost updates or corrupted persistence data.

**Impact:** Dock layout not properly saved, inconsistent state restoration, lost window configurations.

**Trigger Scenarios:**
- Rapid toggling of window visibility
- Multiple dock operations in quick succession
- App termination during state changes

**Recommended Fix:**
```swift
// Debounced persistence with atomic operations
private var persistenceWorkItem: DispatchWorkItem?

private func schedulePersistence() {
    persistenceWorkItem?.cancel()
    persistenceWorkItem = DispatchWorkItem { [weak self] in
        self?.persistState()
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: persistenceWorkItem!)
}

private func persistState() {
    guard let data = try? JSONEncoder().encode(panes) else { return }
    UserDefaults.standard.set(data, forKey: persistKey)
}
```

#### 2.2 Window Ordering Logic Problem
**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/ViewModels/DockingController.swift`  
**Lines:** 20-26, 81-85

**Issue:** Fixed position calculation doesn't account for dynamic visibility changes.

```swift
// Lines 20-26 - Hardcoded positions ignore dynamic state
var position: Int {
    switch type {
    case .main: return 0      // Always top
    case .equalizer: return 1 // Always second when visible
    case .playlist: return 2  // Always third when visible
    }
}
```

**Logic Problem:** When windows toggle visibility, the position calculation creates gaps or incorrect ordering.

**Impact:** Windows appear in wrong order, gaps in dock layout, inconsistent visual stacking.

**Trigger Scenarios:**
- Toggling equalizer visibility when playlist is hidden
- Multiple visibility changes in sequence
- Partial dock configurations

**Recommended Fix:**
```swift
// Dynamic position calculation based on visible windows
var position: Int {
    let visibleTypes = DockPaneType.allCases.filter { type in
        panes.first(where: { $0.type == type })?.visible ?? false
    }
    return visibleTypes.firstIndex(of: type) ?? 0
}
```

### 3. UI Component Issues

#### 3.1 Slider Input Validation Race Condition
**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/BalanceSliderView.swift`  
**Lines:** 44-51

**Issue:** Drag gesture updates can exceed bounds without proper clamping.

```swift
// Lines 44-51 - Insufficient bounds checking
.onChanged { gesture in
    let newX = gesture.location.x
    let normalizedX = (newX / sliderWidth)
    self.value = Float(max(-1.0, min(1.0, (normalizedX * 2.0) - 1.0)))  // Race condition possible
}
```

**Race Condition:** Rapid drag updates can cause value to exceed bounds before clamping is applied.

**Impact:** Slider values exceed expected range, audio balance issues, visual position desynchronization.

**Trigger Scenarios:**
- Rapid slider movements
- System performance issues causing delayed UI updates
- Multiple simultaneous gesture inputs

**Recommended Fix:**
```swift
// Atomic value updates with proper bounds checking
@State private var isUpdating = false

.onChanged { gesture in
    guard !isUpdating else { return }
    isUpdating = true
    
    let newX = max(0, min(sliderWidth, gesture.location.x))
    let normalizedX = newX / sliderWidth
    let newValue = Float((normalizedX * 2.0) - 1.0)
    
    DispatchQueue.main.async {
        self.value = max(-1.0, min(1.0, newValue))
        self.isUpdating = false
    }
}
```

#### 3.2 Animation State Corruption
**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/UnifiedDockView.swift`  
**Lines:** 108-126

**Issue:** Animation state can become inconsistent during rapid mode changes.

```swift
// Lines 108-126 - Non-atomic animation state management
private func startDockAnimations() {
    if settings.materialIntegration == .modern {
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            dockGlow = 1.005
        }
    } else {
        dockGlow = 1.0
    }
    
    if settings.enableLiquidGlass && (settings.materialIntegration == .hybrid || settings.materialIntegration == .modern) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            materialShimmer = true  // Race condition with rapid changes
        }
    } else {
        materialShimmer = false
    }
}
```

**Race Condition:** Rapid setting changes can leave animations in inconsistent states.

**Impact:** Visual glitches, stuck animations, performance degradation.

**Trigger Scenarios:**
- Rapidly switching between appearance modes
- Toggling liquid glass setting repeatedly
- System performance issues affecting animation timing

**Recommended Fix:**
```swift
// Atomic animation state management
private let animationLock = NSLock()

private func startDockAnimations() {
    animationLock.lock()
    defer { animationLock.unlock() }
    
    // Cancel existing animations
    withAnimation(.easeOut(duration: 0.1)) {
        dockGlow = 1.0
        materialShimmer = false
    }
    
    // Start new animations based on current settings
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        self.applyNewAnimations()
    }
}
```

### 4. Window Lifecycle and Memory Management

#### 4.1 NSWindow Delegate Memory Leak
**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Utilities/WindowSnapManager.swift`  
**Lines:** 28-29

**Issue:** Strong reference cycle between WindowSnapManager and NSWindow delegates.

```swift
// Lines 28-29 - Potential retain cycle
windows[kind] = TrackedWindow(window: window, kind: kind)
window.delegate = self  // Strong reference to manager
```

**Memory Leak:** WindowSnapManager holds strong references to windows, and windows hold strong references to the manager via delegates.

**Impact:** Memory leaks, windows not deallocated properly, degraded performance over time.

**Trigger Scenarios:**
- Repeated window creation/destruction
- Long-running app sessions
- Multiple window configurations

**Recommended Fix:**
```swift
// Use weak delegate pattern or cleanup on window close
func register(window: NSWindow, kind: WindowKind) {
    window.tabbingMode = .disallowed
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    windows[kind] = TrackedWindow(window: window, kind: kind)
    window.delegate = self
    
    // Setup cleanup notification
    NotificationCenter.default.addObserver(
        forName: NSWindow.willCloseNotification,
        object: window,
        queue: .main
    ) { [weak self] _ in
        self?.unregister(window: window)
    }
}

private func unregister(window: NSWindow) {
    window.delegate = nil
    windows = windows.filter { $0.value.window !== window }
    lastOrigins.removeValue(forKey: ObjectIdentifier(window))
}
```

#### 4.2 Screen Configuration Change Handling
**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Utilities/WindowSnapManager.swift`

**Issue:** No handling for screen configuration change notifications.

**Missing Logic:** The code doesn't listen for `NSApplication.didChangeScreenParametersNotification`.

**Impact:** Windows remain in invalid positions after screen changes, snapping to non-existent boundaries.

**Trigger Scenarios:**
- Monitor resolution changes
- Display arrangement changes
- Dock/undock operations

**Recommended Fix:**
```swift
init() {
    super.init()
    
    // Listen for screen configuration changes
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(screenConfigurationChanged),
        name: NSApplication.didChangeScreenParametersNotification,
        object: nil
    )
}

@objc private func screenConfigurationChanged() {
    // Recalculate virtual screen bounds
    // Validate window positions are within new screen bounds
    // Adjust windows that are now off-screen
}
```

## Priority Recommendations

### High Priority (Critical Stability Issues)
1. **Fix coordinate system atomicity** - Prevents windows from disappearing
2. **Implement proper window lifecycle management** - Prevents memory leaks
3. **Add screen configuration change handling** - Ensures windows remain accessible

### Medium Priority (User Experience Issues)
4. **Fix dock state persistence race conditions** - Prevents lost configurations
5. **Improve slider input validation** - Prevents control issues
6. **Fix animation state management** - Prevents visual glitches

### Low Priority (Code Quality Issues)
7. **Improve window ordering logic** - Better dock layout consistency
8. **Add comprehensive error handling** - Better resilience
9. **Implement proper logging** - Better debugging capabilities

## Testing Scenarios

To validate these fixes, test the following scenarios:

1. **Multi-monitor stress test:** Rapidly connect/disconnect monitors while dragging windows
2. **Rapid window operations:** Quick succession of open/close, show/hide operations
3. **Memory pressure test:** Run app for extended periods with frequent window operations
4. **Slider stress test:** Rapid slider movements during system load
5. **Configuration change test:** Change display settings while app is running
6. **Dock state test:** Rapid toggling of dock panes with app restart

## Conclusion

The window management and docking systems in MacAmp have several critical race conditions and logic problems that can cause crashes, data loss, and poor user experience. The most severe issues involve coordinate system calculations, window lifecycle management, and state persistence. Implementing the recommended fixes will significantly improve app stability and user experience.