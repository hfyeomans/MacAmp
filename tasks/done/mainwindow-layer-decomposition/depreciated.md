# Deprecated: WinampMainWindow Layer Decomposition

> **Purpose:** Code patterns and files that will be removed or replaced during this task.
> Per project conventions, deprecated patterns are documented here instead of marked with
> inline `// Deprecated` comments in source code.

## Files to Delete

### `MacAmpApp/Views/WinampMainWindow+Helpers.swift`

**Current:** 508 lines, cross-file extension on `WinampMainWindow` struct.
**Reason for removal:** Entire file is absorbed into proper child view structs and supporting classes.
**Replacement:**
| Code Section | Migrates To |
|-------------|-------------|
| `startScrolling()` | `WinampMainWindowInteractionState.startScrolling()` |
| `resetScrolling()` | `WinampMainWindowInteractionState.resetScrolling()` |
| `timeDigits(from:)` | `WinampMainWindowInteractionState.timeDigits(from:)` or standalone |
| `handlePositionDrag()` | `WinampMainWindowInteractionState.handlePositionDrag()` |
| `handlePositionDragEnd()` | `WinampMainWindowInteractionState.handlePositionDragEnd()` |
| `buildTransportPlaybackButtons()` | `MainWindowTransportLayer.body` |
| `buildTransportNavButtons()` | `MainWindowTransportLayer.body` |
| `buildShuffleRepeatButtons()` | `MainWindowFullLayer` (private builder) |
| `buildPositionSlider()` | `MainWindowSlidersLayer.body` |
| `buildVolumeSlider()` | `MainWindowSlidersLayer.body` |
| `buildBalanceSlider()` | `MainWindowSlidersLayer.body` |
| `buildWindowToggleButtons()` | `MainWindowFullLayer` (private builder) |
| `buildClutterBarOAI()` | `MainWindowFullLayer` (private builder) |
| `buildClutterBarDV()` | `MainWindowFullLayer` (private builder) |
| `buildTrackInfoDisplay()` | `MainWindowTrackInfoLayer.body` |
| `buildTextSprites(for:)` | `MainWindowTrackInfoLayer` (private helper) |
| `buildMonoStereoIndicator()` | `MainWindowIndicatorsLayer.body` |
| `buildBitrateDisplay()` | `MainWindowIndicatorsLayer.body` |
| `buildSampleRateDisplay()` | `MainWindowIndicatorsLayer.body` |
| `buildSpectrumAnalyzer()` | `MainWindowFullLayer` (private builder) |
| `showOptionsMenu(from:)` | `MainWindowOptionsMenuPresenter.showOptionsMenu()` |
| `buildOptionsMenuItems(menu:)` | `MainWindowOptionsMenuPresenter` (private) |
| `buildRepeatShuffleMenuItems(menu:)` | `MainWindowOptionsMenuPresenter` (private) |
| `createMenuItem(...)` | `MainWindowOptionsMenuPresenter` (private) |
| `MenuItemTarget` class | `MainWindowOptionsMenuPresenter` (nested private class) |

## Patterns Being Deprecated

### 1. Cross-File Extension Pattern for SwiftUI Views

**Current pattern:**
```swift
// File 1: WinampMainWindow.swift
struct WinampMainWindow: View {
    @State var isScrubbing: Bool = false  // forced internal access
    var body: some View { ... buildFullWindow() ... }
}

// File 2: WinampMainWindow+Helpers.swift
extension WinampMainWindow {
    func buildTransportPlaybackButtons() -> some View { ... }
    // Can access isScrubbing because it's internal
}
```

**Why deprecated:** Forces `@State` to be `internal` instead of `private`. No recomposition
boundary between extension methods. Lint-driven split, not architecture-driven.

**Replacement pattern:** Separate `View` struct types in their own files:
```swift
struct MainWindowTransportLayer: View {
    @Environment(PlaybackCoordinator.self) var playbackCoordinator
    var body: some View { ... }
}
```

### 2. Internal @State Access

**Current pattern:**
```swift
@State var isScrubbing: Bool = false       // no private, accessible from extension file
@State var wasPlayingPreScrub: Bool = false
@State var scrubbingProgress: Double = 0.0
@State var scrollOffset: CGFloat = 0
@State var scrollTimer: Timer?
@State var pauseBlinkVisible: Bool = true
@State var isViewVisible: Bool = false
```

**Why deprecated:** SwiftUI @State should always be private. Internal access was forced by the
cross-file extension pattern, creating a leaky abstraction.

**Replacement pattern:**
```swift
@State private var interactionState = WinampMainWindowInteractionState()
```

All 7 properties move to the `@Observable` class. The root view holds the class as `@State private`.
Child views receive it as an init parameter.

### 3. Nested Coords Struct

**Current pattern:**
```swift
struct WinampMainWindow: View {
    struct Coords {
        static let prevButton = CGPoint(x: 16, y: 88)
        // ... 30+ constants
    }
}
```

**Why deprecated:** Child view structs cannot access `WinampMainWindow.Coords` without coupling
to the parent type. Constants are layout data, not view behavior.

**Replacement pattern:**
```swift
// WinampMainWindowLayout.swift
enum WinampMainWindowLayout {
    static let prevButton = CGPoint(x: 16, y: 88)
    // ... all constants
}
```

### 4. Manual Timer @State Management

**Current pattern:**
```swift
@State var scrollTimer: Timer?

// In extension:
func startScrolling() {
    guard scrollTimer == nil else { return }
    scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { ... }
}

// In onDisappear:
scrollTimer?.invalidate()
scrollTimer = nil
```

**Why deprecated:** Timer as @State is fragile. `onDisappear` may not fire reliably in all cases.
@Observable class with explicit lifecycle methods is more robust.

**Replacement pattern:**
```swift
@Observable @MainActor
final class WinampMainWindowInteractionState {
    var scrollTimer: Timer?

    func startScrolling(...) { ... }
    func cleanup() { scrollTimer?.invalidate(); scrollTimer = nil }
}
```
