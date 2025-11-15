# Window Focus State Architecture

**Version:** 1.0.0
**Date:** 2025-11-14
**Component:** WindowFocusState System
**Status:** ✅ PRODUCTION

---

## Executive Summary

The WindowFocusState system provides centralized tracking of window focus states across all MacAmp windows (Main, Equalizer, Playlist, Video, Milkdrop). This enables proper active/inactive titlebar sprite rendering, following the Winamp convention where focused windows display active titlebars and unfocused windows display inactive variants.

### Architecture Position

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  VideoWindowChromeView, MilkdropWindowChromeView            │
│  (Reads focus state for titlebar sprite selection)          │
├─────────────────────────────────────────────────────────────┤
│                      BRIDGE LAYER                            │
│  WindowFocusState (Observable state container)              │
│  WindowFocusDelegate (NSWindowDelegate adapter)             │
│  WindowCoordinator (Wiring and lifecycle)                   │
├─────────────────────────────────────────────────────────────┤
│                     MECHANISM LAYER                          │
│  NSWindow.didBecomeKey/didResignKey notifications           │
│  WindowDelegateMultiplexer (Delegate aggregation)           │
└─────────────────────────────────────────────────────────────┘
```

---

## Component Architecture

### WindowFocusState Model

**Location:** `MacAmpApp/Models/WindowFocusState.swift`
**Layer:** Bridge Layer
**Pattern:** @Observable @MainActor singleton state

```swift
@Observable
@MainActor
final class WindowFocusState {
    // Individual window focus states
    var isMainKey: Bool = true       // Main window starts focused
    var isEqualizerKey: Bool = false
    var isPlaylistKey: Bool = false
    var isVideoKey: Bool = false
    var isMilkdropKey: Bool = false

    // Computed property for any-window-focused
    var hasAnyFocus: Bool {
        isMainKey || isEqualizerKey || isPlaylistKey ||
        isVideoKey || isMilkdropKey
    }
}
```

**Design Decisions:**
- **@Observable**: Enables fine-grained SwiftUI updates when focus changes
- **@MainActor**: Ensures thread safety for UI state
- **Boolean properties**: Simple, explicit state for each window
- **No UserDefaults**: Focus state is transient, not persisted

### WindowFocusDelegate

**Location:** `MacAmpApp/Utilities/WindowFocusDelegate.swift`
**Layer:** Bridge Layer
**Pattern:** NSWindowDelegate adapter pattern

```swift
@MainActor
final class WindowFocusDelegate: NSObject, NSWindowDelegate {
    private let kind: WindowKind
    private let focusState: WindowFocusState

    init(kind: WindowKind, focusState: WindowFocusState) {
        self.kind = kind
        self.focusState = focusState
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // Reset all states, then set this window as focused
        // This ensures only one window is marked as key
        focusState.isMainKey = (kind == .main)
        focusState.isEqualizerKey = (kind == .equalizer)
        focusState.isPlaylistKey = (kind == .playlist)
        focusState.isVideoKey = (kind == .video)
        focusState.isMilkdropKey = (kind == .milkdrop)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Clear focus for this specific window
        switch kind {
        case .main: focusState.isMainKey = false
        case .equalizer: focusState.isEqualizerKey = false
        case .playlist: focusState.isPlaylistKey = false
        case .video: focusState.isVideoKey = false
        case .milkdrop: focusState.isMilkdropKey = false
        }
    }
}
```

**Design Decisions:**
- **WindowKind enum**: Type-safe window identification
- **Mutual exclusivity**: Only one window can be key (focused) at a time
- **Bridge pattern**: Converts AppKit notifications to @Observable state changes

---

## Integration Pattern

### 1. App-Level Initialization

**File:** `MacAmpApp/MacAmpApp.swift`

```swift
@main
struct MacAmpApp: App {
    @State private var windowFocusState: WindowFocusState

    init() {
        let windowFocusState = WindowFocusState()
        _windowFocusState = State(initialValue: windowFocusState)

        // Pass to WindowCoordinator
        let coordinator = WindowCoordinator(
            // ... other dependencies
            windowFocusState: windowFocusState
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(windowFocusState)  // Inject for SwiftUI views
        }
    }
}
```

### 2. WindowCoordinator Wiring

**File:** `MacAmpApp/ViewModels/WindowCoordinator.swift`

```swift
@MainActor
@Observable
final class WindowCoordinator {
    private let windowFocusState: WindowFocusState

    // Focus delegates for each window
    private var mainFocusDelegate: WindowFocusDelegate?
    private var eqFocusDelegate: WindowFocusDelegate?
    private var playlistFocusDelegate: WindowFocusDelegate?
    private var videoFocusDelegate: WindowFocusDelegate?
    private var milkdropFocusDelegate: WindowFocusDelegate?

    init(..., windowFocusState: WindowFocusState) {
        self.windowFocusState = windowFocusState
        setupFocusDelegates()
    }

    private func setupFocusDelegates() {
        // Create delegates for each window type
        mainFocusDelegate = WindowFocusDelegate(kind: .main, focusState: windowFocusState)
        eqFocusDelegate = WindowFocusDelegate(kind: .equalizer, focusState: windowFocusState)
        playlistFocusDelegate = WindowFocusDelegate(kind: .playlist, focusState: windowFocusState)

        // Add to multiplexers (preserves existing delegates)
        mainDelegateMultiplexer?.add(delegate: mainFocusDelegate!)
        equalizerDelegateMultiplexer?.add(delegate: eqFocusDelegate!)
        playlistDelegateMultiplexer?.add(delegate: playlistFocusDelegate!)
    }

    // When creating video window
    func showVideoWindow() {
        videoFocusDelegate = WindowFocusDelegate(kind: .video, focusState: windowFocusState)
        let controller = WinampVideoWindowController(
            // ... other params
            windowFocusState: windowFocusState
        )
        videoDelegateMultiplexer?.add(delegate: videoFocusDelegate!)
    }
}
```

### 3. Window Controller Pattern

**File:** `MacAmpApp/Windows/WinampVideoWindowController.swift`

```swift
class WinampVideoWindowController: NSWindowController {
    convenience init(..., windowFocusState: WindowFocusState) {
        // Create window
        let window = NSWindow(...)
        self.init(window: window)

        // Create SwiftUI view with environment
        let contentView = VideoWindowView()
            .environment(windowFocusState)  // Pass to SwiftUI

        window.contentViewController = NSHostingController(rootView: contentView)
    }
}
```

### 4. View Layer Usage

**File:** `MacAmpApp/Views/Windows/VideoWindowChromeView.swift`

```swift
struct VideoWindowChromeView: View {
    @Environment(WindowFocusState.self) private var windowFocusState
    @Environment(SkinManager.self) private var skinManager

    // Computed property for focus state
    private var isWindowActive: Bool {
        windowFocusState.isVideoKey
    }

    var body: some View {
        ZStack {
            // Background - uses active/inactive state
            SimpleSpriteImage(
                sprite: skinManager.sprite(
                    for: .videoTitleBar,
                    state: isWindowActive ? .active : .inactive
                )
            )
            .at(x: 0, y: 0)

            // Close button - also focus-aware
            SimpleSpriteImage(
                sprite: skinManager.sprite(
                    for: .videoCloseButton,
                    state: determineButtonState()
                )
            )
            .at(x: 244, y: 3)
        }
    }

    private func determineButtonState() -> SpriteState {
        if !isWindowActive {
            return .inactive
        }
        // Additional logic for pressed/hover states
        return .normal
    }
}
```

---

## WindowDelegateMultiplexer Integration

The WindowFocusDelegate integrates seamlessly with the existing WindowDelegateMultiplexer pattern:

```swift
// WindowDelegateMultiplexer allows multiple delegates per window
class WindowDelegateMultiplexer: NSObject, NSWindowDelegate {
    private var delegates: [NSWindowDelegate] = []

    func add(delegate: NSWindowDelegate) {
        delegates.append(delegate)
    }

    // Forwards to all delegates
    func windowDidBecomeKey(_ notification: Notification) {
        delegates.forEach { $0.windowDidBecomeKey?(notification) }
    }

    func windowDidResignKey(_ notification: Notification) {
        delegates.forEach { $0.windowDidResignKey?(notification) }
    }
}
```

This allows WindowFocusDelegate to coexist with:
- `WindowPersistenceDelegate` (saves window positions)
- `WindowSnapDelegate` (magnetic window snapping)
- `ClusterDelegate` (window clustering behavior)

---

## State Flow Diagram

```
User clicks on Video window
            │
            ▼
NSWindow.makeKey() called
            │
            ▼
NSWindow posts didBecomeKeyNotification
            │
            ▼
WindowDelegateMultiplexer receives notification
            │
            ├──► WindowFocusDelegate.windowDidBecomeKey()
            │         │
            │         ▼
            │    Updates WindowFocusState:
            │    - isVideoKey = true
            │    - isMainKey = false
            │    - isEqualizerKey = false
            │    - etc.
            │
            ├──► WindowPersistenceDelegate (saves position)
            │
            └──► WindowSnapDelegate (updates snap zones)
                      │
                      ▼
              WindowFocusState @Observable
              triggers SwiftUI updates
                      │
                      ▼
              VideoWindowChromeView re-renders
              with active titlebar sprite
```

---

## Testing Considerations

### Unit Testing WindowFocusState

```swift
@MainActor
class WindowFocusStateTests: XCTestCase {
    func testMutualExclusivity() {
        let focusState = WindowFocusState()
        let mainDelegate = WindowFocusDelegate(kind: .main, focusState: focusState)
        let videoDelegate = WindowFocusDelegate(kind: .video, focusState: focusState)

        // Simulate main window becoming key
        mainDelegate.windowDidBecomeKey(mockNotification())
        XCTAssertTrue(focusState.isMainKey)
        XCTAssertFalse(focusState.isVideoKey)

        // Simulate video window becoming key
        videoDelegate.windowDidBecomeKey(mockNotification())
        XCTAssertFalse(focusState.isMainKey)
        XCTAssertTrue(focusState.isVideoKey)
    }

    func testResignKey() {
        let focusState = WindowFocusState()
        focusState.isMainKey = true

        let delegate = WindowFocusDelegate(kind: .main, focusState: focusState)
        delegate.windowDidResignKey(mockNotification())

        XCTAssertFalse(focusState.isMainKey)
        XCTAssertFalse(focusState.hasAnyFocus)
    }
}
```

### Integration Testing

```swift
func testTitleBarSpriteChanges() {
    // Launch app
    let app = XCUIApplication()
    app.launch()

    // Open video window
    app.menuItems["Video"].click()

    // Click on main window
    app.windows["MacAmp"].click()

    // Verify video window shows inactive titlebar
    let videoWindow = app.windows["Video"]
    XCTAssertTrue(videoWindow.images["inactive-titlebar"].exists)

    // Click on video window
    videoWindow.click()

    // Verify video window shows active titlebar
    XCTAssertTrue(videoWindow.images["active-titlebar"].exists)
}
```

---

## Common Patterns & Best Practices

### 1. Always Use Environment Injection

```swift
// ✅ CORRECT: Use environment for focus state
struct MyWindowView: View {
    @Environment(WindowFocusState.self) private var windowFocusState
}

// ❌ WRONG: Don't create local instances
struct MyWindowView: View {
    @State private var windowFocusState = WindowFocusState()  // Wrong!
}
```

### 2. Computed Properties for Derived State

```swift
// ✅ CORRECT: Computed property for sprite state
private var titleBarSprite: Sprite {
    skinManager.sprite(
        for: .titleBar,
        state: windowFocusState.isMainKey ? .active : .inactive
    )
}

// ❌ WRONG: Don't cache in @State
@State private var isActive: Bool  // Unnecessary duplication
```

### 3. Handle All Window Types

When adding a new window type:

1. Add to WindowKind enum
2. Add property to WindowFocusState
3. Update WindowFocusDelegate switch statements
4. Create and wire delegate in WindowCoordinator
5. Pass environment to window's SwiftUI view

### 4. Thread Safety

```swift
// ✅ CORRECT: All updates on main thread
@MainActor
final class WindowFocusState { ... }

// ✅ CORRECT: Delegate also marked @MainActor
@MainActor
final class WindowFocusDelegate { ... }
```

---

## Migration Guide

### Adding Focus Tracking to Existing Windows

1. **Update WindowCoordinator.init():**
```swift
init(..., windowFocusState: WindowFocusState) {
    self.windowFocusState = windowFocusState
}
```

2. **Create focus delegate:**
```swift
private var myWindowFocusDelegate: WindowFocusDelegate?

// In setup
myWindowFocusDelegate = WindowFocusDelegate(kind: .myWindow, focusState: windowFocusState)
myWindowDelegateMultiplexer?.add(delegate: myWindowFocusDelegate!)
```

3. **Pass to window controller:**
```swift
let controller = MyWindowController(
    windowFocusState: windowFocusState,
    // ... other params
)
```

4. **Use in SwiftUI views:**
```swift
@Environment(WindowFocusState.self) private var windowFocusState
private var isActive: Bool { windowFocusState.isMyWindowKey }
```

---

## Performance Considerations

### SwiftUI Update Optimization

The @Observable macro provides fine-grained updates:

```swift
// Only views that read specific properties update
struct MainWindowView: View {
    @Environment(WindowFocusState.self) var focus

    var body: some View {
        // This view only re-renders when isMainKey changes
        if focus.isMainKey {
            ActiveTitleBar()
        } else {
            InactiveTitleBar()
        }
    }
}
```

### Delegate Multiplexer Efficiency

```swift
// Multiplexer uses array iteration - O(n) where n = delegate count
// Typically 3-4 delegates per window (focus, persistence, snap, cluster)
// Performance impact: negligible (<1ms per notification)
```

---

## Troubleshooting

### Issue: Window doesn't update focus state

**Symptom:** Clicking window doesn't change titlebar appearance

**Diagnosis:**
1. Check delegate is added to multiplexer
2. Verify WindowKind matches in delegate init
3. Ensure environment is passed to SwiftUI view
4. Check window.delegate is set to multiplexer

**Solution:**
```swift
// Verify in WindowCoordinator
print("Multiplexer delegates: \(multiplexer.delegates)")
print("Focus delegate created: \(focusDelegate != nil)")

// Check in view
print("Current focus: \(windowFocusState.isVideoKey)")
```

### Issue: Multiple windows show as active

**Symptom:** More than one window displays active titlebar

**Diagnosis:**
- windowDidBecomeKey not resetting other states
- Multiple WindowFocusState instances

**Solution:**
- Ensure single WindowFocusState instance app-wide
- Verify mutual exclusivity logic in WindowFocusDelegate

---

## Future Enhancements

### Potential Improvements

1. **Focus History:** Track last focused window for restore
2. **Focus Cycling:** Keyboard shortcuts to cycle through windows
3. **Focus Groups:** Related windows (e.g., Milkdrop + Visualization settings)
4. **Focus Animation:** Smooth transitions between active/inactive states
5. **Multi-Monitor Support:** Track focus per screen

### Considered Alternatives

**Alternative 1: NotificationCenter**
- Pros: Decoupled, no delegate needed
- Cons: String-based, harder to test
- Decision: Delegates provide better type safety

**Alternative 2: Combine Publishers**
- Pros: Reactive, composable
- Cons: More complex, overkill for simple state
- Decision: @Observable is simpler and sufficient

**Alternative 3: AppKit-only (NSApp.keyWindow)**
- Pros: Built-in, no custom code
- Cons: Can't track in SwiftUI, timing issues
- Decision: Custom state provides better control

---

## Related Components

- **WindowCoordinator:** Manages window lifecycle and wiring
- **WindowDelegateMultiplexer:** Aggregates multiple delegates
- **WindowPersistenceDelegate:** Saves/restores window positions
- **WindowSnapDelegate:** Handles magnetic window snapping
- **SkinManager:** Provides active/inactive sprite variants

---

## References

- **Architecture Guide:** `docs/MACAMP_ARCHITECTURE_GUIDE.md` §3 (Three-Layer Architecture)
- **Implementation Patterns:** `docs/IMPLEMENTATION_PATTERNS.md` §2 (State Management)
- **Window Management:** `MacAmpApp/ViewModels/WindowCoordinator.swift`
- **Multiplexer Pattern:** `MacAmpApp/Utilities/WindowDelegateMultiplexer.swift`

---

**WindowFocusState Architecture v1.0.0 | Component Documentation | Status: Production**