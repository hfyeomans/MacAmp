# Research: Double-Sized Button Implementation

## Date
2025-10-30

## Objective
Implement the "D" (Double-sized) button that toggles the main window's scale between 100% and 200%, following modern Swift 6 and SwiftUI patterns while referencing the working webamp implementation.

## Oracle Analysis Summary

### Current Architecture (from double-sized-plan.md)

**Core Pattern: @Observable State Model**
- Central `UIStateModel` marked `@Observable` owns shared UI state
- Stores `isDoublesize` boolean as single source of truth
- Maintains `NSWindow` reference for imperative operations
- Injected via `.environment` at app root
- Views bind directly to state model for reactive updates

**Window Management Strategy**
- AppKit bridge layer using `NSViewRepresentable` to capture window reference
- Reactive window operations triggered via `.task(id:)` modifier
- `NSAnimationContext.runAnimationGroup` for smooth window resizing
- `.windowResizeAnchor(.topLeading)` ensures consistent anchor point (macOS 15+)
- Target frame calculated based on 100% vs 200% scale

**Visual Styling**
- `SkinEngine` service provides skinned image slices
- Sources: `cbuttons.bmp`, `titlebar.bmp` for button states
- `SkinToggleButton` (custom `ButtonStyle`) encapsulates skin logic
- Keeps view code declarative while supporting dynamic skins
- Main skin image uses `.resizable()` for clean scaling

**Swift 6 Best Practices**
- Use `@Observable` macro instead of `@Published`
- Leverage `.task(id:)` for structured, async-aware reactions
- Adopt macOS 15 modifiers like `.windowResizeAnchor(.topLeading)`
- Flexible containers/`GeometryReader` for scalable layouts

### Webamp Reference Implementation

**State Management (Redux Pattern)**
- Location: `webamp/js/reducers/display.ts:62-112`
- Boolean flag: `display.doubled`
- Components subscribe via `useTypedSelector`
- Single action toggles state globally

**Button Implementation**
- Location: `webamp/js/components/MainWindow/ClutterBar.tsx:11-43`
- Pointer-down: Focus control only
- Pointer-up: Dispatch `toggleDoubleSizeMode()` + unfocus
- Immediate toggle on every release

**Action Flow**
- Location: `webamp/js/actionCreators/windows.ts:16-54`
- Routes through `withWindowGraphIntegrity()`
- Re-evaluates all window sizes
- Computes size deltas
- Calls `updateWindowPositions()` to maintain docked alignment

**Visual Scaling**
- Location: `webamp/css/webamp.css:101-119`
- CSS: `.window.doubled { transform: scale(2); transform-origin: top left; }`
- Selectors compute doubled dimensions: `webamp/js/selectors.ts:468-515`
- Only windows with `canDouble` capability get scaled
- Drag coordinates remain consistent despite visual transform

**Window Layout**
- Location: `webamp/js/components/WindowManager.tsx:174-198`
- Positions windows via `translate(x,y)`
- CSS transform handles visual resize
- Snapped positions stay synchronized

**Related Buttons (Scaffold Targets)**
- **button-o**: Opens options context menu (already functional)
  - Location: `webamp/js/components/MainWindow/ClutterBar.tsx:27-30`
  - Uses `ContextMenuTarget` wrapper
  - Exposes double-size command in menu

- **button-a**: Always-on-top (placeholder)
  - Location: `webamp/css/main-window.css:64-80`
  - Skin-only, no handler
  - Future: Window float behavior

- **button-i**: Info/About (placeholder)
  - Location: `webamp/css/main-window.css:64-80`
  - Skin-only, no handler
  - Future: Show file info dialog

- **button-v**: Visualizer/VU toggle (placeholder)
  - Location: `webamp/css/main-window.css:64-80`
  - Skin-only, no handler
  - Future: Toggle visualizer display mode

## Key Technical Decisions

### SwiftUI vs Webamp Approach

| Aspect | Webamp (React/CSS) | MacAmp (SwiftUI) |
|--------|-------------------|------------------|
| State | Redux `display.doubled` | `@Observable isDoublesize` |
| Scaling | CSS `transform: scale(2)` | Window frame resize via AppKit |
| Animation | CSS transitions | `NSAnimationContext` |
| Reactivity | `useTypedSelector` hooks | `.task(id:)` modifier |
| Button | Click handlers | `Toggle` with `ButtonStyle` |

**Why Different Scaling Approach?**
- Webamp uses CSS transform because DOM allows visual-only scaling
- SwiftUI requires actual window frame changes via AppKit
- Our approach provides true window resize, not just visual transform
- Better integration with macOS window management

### Prerequisites Identified

1. **macOS 15+ Required**
   - `.windowResizeAnchor(.topLeading)` API
   - Modern SwiftUI window coordination

2. **SkinEngine Must Be Functional**
   - Load `cbuttons.bmp` bitmap assets
   - Expose per-state images (on/off/pressed)
   - Support dynamic skin switching

3. **AppKit Bridge Layer**
   - `NSViewRepresentable` for window capture
   - Window reference available in `UIStateModel`
   - Proper lifecycle management

4. **Keyboard Shortcut Support**
   - `.keyboardShortcut("d", modifiers: .control)`
   - Matches classic Winamp Ctrl+D behavior

## Design Patterns to Follow

### 1. Single Source of Truth
```swift
@Observable
class UIStateModel {
    var isDoublesize: Bool = false
    var mainWindow: NSWindow?
}
```

### 2. Reactive Window Sizing
```swift
.task(id: uiState.isDoublesize) {
    guard let window = uiState.mainWindow else { return }
    let targetFrame = uiState.isDoublesize
        ? computeDoubledFrame(from: window.frame)
        : computeNormalFrame(from: window.frame)

    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.2
        window.setFrame(targetFrame, display: true)
    }
}
```

### 3. Skin-Driven Button Styling
```swift
Toggle(isOn: $uiState.isDoublesize) {
    // Button content
}
.buttonStyle(SkinToggleButton(
    normalImage: skinEngine.getImage(for: .doublesizeOff),
    activeImage: skinEngine.getImage(for: .doublesizeOn)
))
.keyboardShortcut("d", modifiers: .control)
```

## Frame Calculation Strategy

### Original Frame Storage
- Store original (100%) frame when window first appears
- Reference point for calculating 200% size
- Preserve position anchor (top-left)

### Doubling Logic
```swift
func computeDoubledFrame(from current: NSRect) -> NSRect {
    return NSRect(
        x: current.origin.x,
        y: current.origin.y - current.size.height, // Account for anchor
        width: current.size.width * 2,
        height: current.size.height * 2
    )
}
```

### Halving Logic
```swift
func computeNormalFrame(from current: NSRect) -> NSRect {
    return NSRect(
        x: current.origin.x,
        y: current.origin.y + current.size.height / 2, // Restore anchor
        width: current.size.width / 2,
        height: current.size.height / 2
    )
}
```

## Integration Points

### 1. UIStateModel Extension
- Add `isDoublesize: Bool` property
- Add `originalFrame: NSRect?` for reference
- Add `mainWindow: NSWindow?` if not present

### 2. Main Window View
- Apply `.task(id: isDoublesize)` modifier
- Implement frame calculation logic
- Add window reference capture

### 3. Clutter Bar (Button Strip)
- Add "D" button using `Toggle`
- Apply `SkinToggleButton` style
- Wire to `uiState.isDoublesize`
- Add keyboard shortcut

### 4. SkinEngine Extension
- Add image mappings for doublesize button states
- Parse `cbuttons.bmp` sprite positions
- Provide image accessor methods

## Testing Considerations

1. **Window Behavior**
   - Toggle between 100% and 200% maintains top-left anchor
   - Animation is smooth (0.2s duration)
   - Window content scales proportionally
   - No visual artifacts during transition

2. **State Persistence**
   - State survives window minimize/restore
   - Keyboard shortcut works in both states
   - Button visual matches actual state

3. **Edge Cases**
   - Screen edge constraints (prevent off-screen positioning)
   - Multiple displays handling
   - Window dragging during scale transition
   - Rapid toggling (debounce if needed)

## Scaffolding for O, A, I, V Buttons

### Immediate: Visual Presence Only
- Add buttons to clutter bar layout
- Wire to placeholder state variables
- Apply appropriate skin images
- No functional behavior yet

### Future Assignment Strategy
```swift
@Observable
class UIStateModel {
    var isDoublesize: Bool = false      // D - Implemented
    var showOptions: Bool = false       // O - Placeholder (menu trigger)
    var alwaysOnTop: Bool = false       // A - Placeholder (window level)
    var showInfo: Bool = false          // I - Placeholder (info dialog)
    var visualizerMode: Int = 0         // V - Placeholder (VU/analyzer mode)
}
```

## References

- Original plan: `tasks/double-sized-plan.md`
- Webamp implementation: `webamp_clone/js/components/MainWindow/ClutterBar.tsx`
- Webamp state: `webamp_clone/js/reducers/display.ts`
- Webamp window manager: `webamp_clone/js/components/WindowManager.tsx`
- Swift 6 Observation: Apple Documentation
- macOS 15 SwiftUI APIs: Xcode 16.0 Documentation

## Next Steps

See `plan.md` for detailed implementation strategy.

---

# Oracle Feedback & Critical Improvements

**Date:** 2025-10-30
**Source:** Oracle (Codex) review of initial planning documents

## Assessment Summary

**Overall Quality**: Thorough and well-structured, but needs refinement before implementation

**Key Strength**: Core architecture aligns well with modern Swift 6/SwiftUI patterns

**Critical Gap**: Plan assumes infrastructure exists without verification (now resolved via discovery)

## Critical Issues Identified & Resolutions

### 1. Missing @MainActor Annotation ⚠️ CRITICAL

**Problem**: `UIStateModel`/`AppSettings` stores `NSWindow` and drives AppKit mutations but wasn't marked `@MainActor`

**Risk**: Swift 6 strict concurrency warnings or crashes

**Resolution Applied**:
```swift
@MainActor  // ✅ CRITICAL: Required for Swift 6 concurrency safety
@Observable
final class AppSettings {
    weak var mainWindow: NSWindow?
    var isDoubleSizeMode: Bool = false
    // ...
}
```

**Impact**: Ensures all window operations stay on main thread

### 2. Frame Calculation Flaw ⚠️ HIGH

**Problem**: Initial approach used fixed `originalFrame`, causing snap-back:
- User doubles window → 200%
- User drags window to new position
- User toggles back to 100%
- **Window snaps to old location** (bad UX!)

**Original Flawed Approach**:
```swift
var originalFrame: NSRect?  // Set once, never updated

var targetWindowFrame: NSRect? {
    guard let original = originalFrame else { return nil }
    if isDoublesize {
        return computeDoubledFrame(from: original)  // Always from original!
    } else {
        return original  // Snaps back!
    }
}
```

**Resolution Applied - Dynamic Tracking**:
```swift
@MainActor
@Observable
final class AppSettings {
    weak var mainWindow: NSWindow?
    var baseWindowSize: NSSize = NSSize(width: 275, height: 116)
    var isDoubleSizeMode: Bool = false

    var targetWindowFrame: NSRect? {
        guard let window = mainWindow else { return nil }

        // Capture CURRENT top-left corner (no snap-back!)
        let currentTopLeft = NSPoint(
            x: window.frame.origin.x,
            y: window.frame.maxY  // macOS uses bottom-left origin
        )

        // Calculate target size
        let targetSize = isDoubleSizeMode
            ? NSSize(width: baseWindowSize.width * 2, height: baseWindowSize.height * 2)
            : baseWindowSize

        // Build frame from current position
        return NSRect(
            x: currentTopLeft.x,
            y: currentTopLeft.y - targetSize.height,
            width: targetSize.width,
            height: targetSize.height
        )
    }
}
```

**Key Improvement**: Uses live `window.frame` instead of stored position

### 3. Button Style Architecture ⚠️ MEDIUM

**Problem**: Custom `SkinToggleButtonStyle` took manual `isOn` parameter instead of using `ToggleStyle` protocol

**Original Suboptimal Approach**:
```swift
struct SkinToggleButtonStyle: ButtonStyle {
    let isOn: Bool  // Manually passed - redundant!
}

Toggle(isOn: $state) { }
    .buttonStyle(SkinToggleButtonStyle(isOn: state))  // State passed twice!
```

**Issues**:
- Pressed state may desync
- Accessibility semantics unclear
- Doesn't follow SwiftUI patterns

**Resolution Applied - Proper ToggleStyle**:
```swift
struct SkinToggleStyle: ToggleStyle {
    let normalImage: NSImage
    let activeImage: NSImage

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Image(nsImage: configuration.isOn ? activeImage : normalImage)
                .interpolation(.none)
                .frame(width: 9, height: 9)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

// Usage:
Toggle(isOn: $settings.isDoubleSizeMode) {
    EmptyView()
}
.toggleStyle(.skin(
    normal: skinManager.sprite(for: .doublesizeOff),
    active: skinManager.sprite(for: .doublesizeOn)
))
```

### 4. NSWindow Retention Cycle Risk ⚠️ MEDIUM

**Problem**: Strong reference to `NSWindow` in long-lived state model

**Risk**: Memory leaks if window references back to model

**Resolution Applied**:
```swift
@MainActor
@Observable
final class AppSettings {
    weak var mainWindow: NSWindow?  // ✅ Weak reference
    // ...
}
```

**Consideration**: Window stays alive while app is running (WindowGroup owns it)

### 5. Discovery Checklist Incomplete ⚠️ HIGH

**Problem**: Initial plan assumed components existed without verification

**Resolution**: ✅ Complete discovery conducted, all components located and documented in state.md

## Additional Improvements Applied

### State Persistence

**Decision**: Use `@AppStorage` for automatic UserDefaults integration

```swift
@ObservationIgnored
@AppStorage("isDoubleSizeMode") var isDoubleSizeMode: Bool = false
```

**Rationale**: Free persistence, integrates with @Observable, user preference remembered

### Disabled Button Accessibility

**Problem**: Scaffold buttons (O, A, I, V) would be `.disabled(true)` but still in accessibility tree

**Resolution Applied**:
```swift
// Scaffold buttons hidden from VoiceOver
Button {} label: {
    SimpleSpriteImage(sprite: .optionsOff)
}
.disabled(true)
.accessibilityHidden(true)  // ✅ Hide from screen readers
```

**Rationale**: Non-functional UI elements shouldn't be exposed to assistive technologies

## Oracle Recommendations Summary

> "Next steps I'd take: finish the discovery checklist, adjust the frame/state strategy, and revise the button styling approach before starting implementation."

**Status**: ✅ All recommendations addressed
- ✅ Discovery complete (all components found)
- ✅ Frame strategy revised (dynamic calculation)
- ✅ Button styling fixed (proper ToggleStyle)
- ✅ @MainActor added for concurrency safety
- ✅ Weak references for memory management
- ✅ Accessibility improvements applied

## Updated Success Criteria

In addition to original criteria:

- ✅ AppSettings marked `@MainActor`
- ✅ Window position preserved during toggle (dynamic frame calculation)
- ✅ No snap-back after dragging doubled window
- ✅ Proper ToggleStyle implementation
- ✅ No memory leaks (weak window reference)
- ✅ Scaffold buttons hidden from accessibility
- ✅ State persistence with @AppStorage
- ✅ All discovery items verified and documented
