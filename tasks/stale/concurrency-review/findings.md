# Swift 6 Concurrency Compliance Review

## Project Configuration
- **Swift Version:** 6.0
- **Strict Concurrency:** `complete`
- **Build Target:** macOS 15.0+

## Executive Summary

The MacAmp codebase demonstrates **strong concurrency compliance** overall. All `@Observable` classes are properly annotated with `@MainActor`, and window/UI-related code consistently uses proper actor isolation. There are a few minor issues identified, primarily around explicit `Sendable` conformance for value types and one WKNavigationDelegate that could benefit from `@MainActor`.

---

## Findings by Priority

### HIGH Priority (Potential Data Races)

**None found.** All UI-bound types are properly isolated.

---

### MEDIUM Priority (Code Quality / Best Practices)

#### 1. ButterchurnWebView.Coordinator Missing @MainActor
**File:** `MacAmpApp/Views/Windows/ButterchurnWebView.swift:23`

```swift
// CURRENT (problematic)
class Coordinator: NSObject, WKNavigationDelegate {
    weak var bridge: ButterchurnBridge?

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            bridge?.markLoadFailed("...")  // Accesses @MainActor bridge
        }
    }
}
```

**Issue:** WKNavigationDelegate methods can be called by WebKit on any queue. While the code correctly hops to `@MainActor` via `Task`, the entire class should be `@MainActor` isolated for consistency.

**Fix:**
```swift
@MainActor
class Coordinator: NSObject, WKNavigationDelegate {
    weak var bridge: ButterchurnBridge?

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        bridge?.markLoadFailed("...")  // Now safe, entire class is @MainActor
    }
}
```

---

### LOW Priority (Explicit Conformance / Documentation)

#### 2. Skin struct - @unchecked Sendable with NSImage
**File:** `MacAmpApp/Models/Skin.swift:10`

```swift
struct Skin: @unchecked Sendable {
    let images: [String: NSImage]  // NSImage is mutable
    // ...
}
```

**Issue:** `NSImage` is not inherently `Sendable`. The struct is marked `@unchecked Sendable` but relies on the fact that it's only accessed via `@MainActor SkinManager`.

**Risk:** Low - The comment documents this assumption, and current usage is safe.

**Recommendation:** Keep current implementation but ensure documentation is maintained. Alternative: use `@MainActor` for Skin if needed in future.

---

#### 3. Track struct - Missing explicit Sendable
**File:** `MacAmpApp/Audio/AudioPlayer.swift:188`

```swift
struct Track: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var title: String
    var artist: String
    var duration: Double
}
```

**Issue:** Track is a value type with all `Sendable` fields but doesn't explicitly conform.

**Fix:**
```swift
struct Track: Identifiable, Equatable, Sendable {
    // ... unchanged
}
```

---

#### 4. ButterchurnFrame struct - Missing explicit Sendable
**File:** `MacAmpApp/Audio/AudioPlayer.swift:180`

```swift
struct ButterchurnFrame {
    let spectrum: [Float]
    let waveform: [Float]
    let timestamp: TimeInterval
}
```

**Issue:** Pure value type with `Sendable` fields should explicitly conform.

**Fix:**
```swift
struct ButterchurnFrame: Sendable {
    // ... unchanged
}
```

---

#### 5. VisualizerScratchBuffers - @unchecked Sendable (Intentional)
**File:** `MacAmpApp/Audio/AudioPlayer.swift:22`

```swift
// Scratch buffers are confined to the audio tap queue, so @unchecked Sendable is safe.
private final class VisualizerScratchBuffers: @unchecked Sendable {
    private(set) var mono: [Float] = []
    // ...
}
```

**Status:** ✅ Correctly documented and intentional for audio processing performance.

---

#### 6. VisualizerTapContext - @unchecked Sendable (Intentional)
**File:** `MacAmpApp/Audio/AudioPlayer.swift:166`

```swift
private struct VisualizerTapContext: @unchecked Sendable {
    let playerPointer: UnsafeMutableRawPointer
}
```

**Status:** ✅ Required for C audio tap callback pattern. The raw pointer is used only in the confined audio queue context.

---

## Positive Findings (No Issues)

### All @Observable Classes Have @MainActor ✅

| Class | File | Status |
|-------|------|--------|
| AppSettings | Models/AppSettings.swift:29 | ✅ @MainActor |
| AudioPlayer | Audio/AudioPlayer.swift:221 | ✅ @MainActor |
| DockingController | ViewModels/DockingController.swift:31 | ✅ @MainActor |
| PlaybackCoordinator | Audio/PlaybackCoordinator.swift:33 | ✅ @MainActor |
| StreamPlayer | Audio/StreamPlayer.swift:28 | ✅ @MainActor |
| SkinManager | ViewModels/SkinManager.swift:102 | ✅ @MainActor |
| WindowCoordinator | ViewModels/WindowCoordinator.swift:54 | ✅ @MainActor |
| WindowFocusState | Models/WindowFocusState.swift:7 | ✅ @MainActor |
| RadioStationLibrary | Models/RadioStationLibrary.swift:4 | ✅ @MainActor |
| ButterchurnBridge | ViewModels/ButterchurnBridge.swift:13 | ✅ @MainActor |
| ButterchurnPresetManager | ViewModels/ButterchurnPresetManager.swift:12 | ✅ @MainActor |
| VideoWindowSizeState | Models/VideoWindowSizeState.swift:6 | ✅ @MainActor |
| PlaylistWindowSizeState | Models/PlaylistWindowSizeState.swift:16 | ✅ @MainActor |
| MilkdropWindowSizeState | Models/MilkdropWindowSizeState.swift:15 | ✅ @MainActor |

### All NSWindowDelegate Implementations Have @MainActor ✅

| Class | File | Status |
|-------|------|--------|
| WindowFocusDelegate | Utilities/WindowFocusDelegate.swift:7 | ✅ @MainActor |
| WindowSnapManager | Utilities/WindowSnapManager.swift:12 | ✅ @MainActor |
| WindowDelegateMultiplexer | Utilities/WindowDelegateMultiplexer.swift:13 | ✅ @MainActor |
| WindowPersistenceDelegate | ViewModels/WindowCoordinator.swift:1329 | ✅ @MainActor |

### All Window Controllers Have @MainActor ✅

| Class | File | Status |
|-------|------|--------|
| WinampMainWindowController | Windows/WinampMainWindowController.swift:4 | ✅ @MainActor |
| WinampEqualizerWindowController | Windows/WinampEqualizerWindowController.swift:4 | ✅ @MainActor |

### Proper Task Usage Patterns ✅

- All `Task { @MainActor [weak self] in ... }` patterns are correctly used
- All Timer callbacks properly hop to `@MainActor` via Task
- All `withObservationTracking` closures use proper actor isolation

### @preconcurrency Usage ✅

**StreamPlayer.swift:1** - Correctly uses `@preconcurrency import AVFoundation` for AVPlayerItemMetadataOutputPushDelegate protocol conformance.

---

## Recommended Actions

### Immediate (Before Next Release)
1. Add `@MainActor` to `ButterchurnWebView.Coordinator`
2. Add explicit `Sendable` conformance to `Track` and `ButterchurnFrame` structs

### Future (Code Quality)
1. Consider adding `Sendable` conformance documentation to any new value types
2. Keep `@unchecked Sendable` documentation current for audio-related types

---

## Testing Recommendations

1. **Thread Sanitizer:** Continue using `-enableThreadSanitizer YES` in all builds
2. **Verify delegate callbacks:** Test WKNavigationDelegate error paths to confirm MainActor safety
3. **Audio visualization:** Stress test Butterchurn with rapid preset changes during playback

---

*Review completed: 2026-01-11*
*Swift Concurrency Expert Agent*
