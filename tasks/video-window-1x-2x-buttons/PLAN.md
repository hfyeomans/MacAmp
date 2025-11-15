# VIDEO Window 1x/2x Buttons Implementation Plan

**Status:** Ready to implement
**Estimated Time:** 30-45 minutes
**Prerequisites:** ✅ AppSettings.videoWindowSizeMode created and persisted

---

## Button Functionality (from Gemini research)

**1x Button:**
- Restore to native video resolution (275×232)
- Entire window including chrome
- Keyboard: Ctrl+1

**2x Button:**
- Double entire window size (550×464)
- Scales chrome proportionally
- Keyboard: Ctrl+2

**Deferred:**
- Fullscreen (4-arrow) - needs AVPlayer fullscreen integration
- TV button - plugin-dependent, not core feature

---

## Implementation Steps

### 1. Add Keyboard Shortcuts (AppCommands.swift)

```swift
Button(settings.videoWindowSizeMode == .oneX ? "Video: 2x" : "Video: 1x") {
    settings.videoWindowSizeMode = (settings.videoWindowSizeMode == .oneX) ? .twoX : .oneX
}
.keyboardShortcut("1", modifiers: [.control])

// Or separate commands:
Button("Video Window 1x") {
    settings.videoWindowSizeMode = .oneX
}
.keyboardShortcut("1", modifiers: [.control])

Button("Video Window 2x") {
    settings.videoWindowSizeMode = .twoX
}
.keyboardShortcut("2", modifiers: [.control])
```

### 2. Create VideoWindowSizeObserver (WindowCoordinator)

Follow same pattern as doubleSizeObserver:

```swift
private func setupVideoSizeObserver() {
    videoSizeTask?.cancel()

    videoSizeTask = Task { @MainActor [weak self] in
        guard let self else { return }

        withObservationTracking {
            _ = self.settings.videoWindowSizeMode
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.resizeVideoWindow(mode: self.settings.videoWindowSizeMode)
                self.setupVideoSizeObserver()
            }
        }
    }

    // Apply initial state
    resizeVideoWindow(mode: settings.videoWindowSizeMode)
}

private func resizeVideoWindow(mode: AppSettings.VideoWindowSizeMode) {
    guard let video = videoWindow else { return }

    let newSize: CGSize
    switch mode {
    case .oneX:
        newSize = CGSize(width: 275, height: 232)
    case .twoX:
        newSize = CGSize(width: 550, height: 464)  // Exactly 2x
    }

    var frame = video.frame
    // Keep origin, change size
    frame.size = newSize
    video.setFrame(frame, display: true, animate: true)

    // Trigger persistence
    schedulePersistenceFlush()
}
```

### 3. Add Clickable Button Overlays (VideoWindowChromeView)

**Button positions in VIDEO_BOTTOM_LEFT (125×38):**
- Fullscreen: x=9, y=51 (15×18)
- 1x: x=24, y=51 (15×18)
- 2x: x=39, y=51 (15×18)
- TV: x=69, y=51 (15×18)

**In chrome ZStack, add transparent Button overlays:**

```swift
@Environment(AppSettings.self) private var settings

// After VIDEO_BOTTOM_LEFT sprite, add:

// 1x button overlay
Button(action: {
    settings.videoWindowSizeMode = .oneX
}) {
    Color.clear
}
.buttonStyle(.plain)
.frame(width: 15, height: 18)
.position(x: 24 + 7.5, y: 213 + (51-42) + 9)  // Adjust Y for bottom bar position
.help("1x Size (Ctrl+1)")

// 2x button overlay
Button(action: {
    settings.videoWindowSizeMode = .twoX
}) {
    Color.clear
}
.buttonStyle(.plain)
.frame(width: 15, height: 18)
.position(x: 39 + 7.5, y: 213 + (51-42) + 9)
.help("2x Size (Ctrl+2)")
```

**Calculate exact Y position:**
- Bottom bar at y=213 (center)
- VIDEO_BOTTOM_LEFT height = 38
- Buttons start at y=51 within sprite (measured from sprite top at y=42 in VIDEO.bmp)
- Button offset from bottom bar top: 51-42 = 9px
- Center Y: 213 - (38/2) + 9 + (18/2) = 213 - 19 + 9 + 9 = 212

### 4. Visual Feedback (Optional enhancement)

Could swap sprites to show "pressed" state:
- VIDEO_1X_BUTTON (normal) at (24, 51)
- VIDEO_1X_BUTTON_PRESSED at (173, 42)

But for MVP, invisible buttons work fine.

---

## Testing Checklist

- [ ] Press Ctrl+1 → window resizes to 275×232
- [ ] Press Ctrl+2 → window resizes to 550×464
- [ ] Click 1x button in window → resizes to 1x
- [ ] Click 2x button in window → resizes to 2x
- [ ] Size persists across app restart
- [ ] Docking is preserved during resize (use cluster logic from double-size)
- [ ] Video playback continues smoothly during resize
- [ ] Window doesn't jump position during resize

---

## Future Enhancements

- **Fullscreen button:** AVPlayer fullscreen mode
- **Window resizing:** Arbitrary sizes (drag corner to resize)
- **Pressed button sprites:** Visual feedback
- **TV button:** Research plugin architecture

---

**Files to Modify:**
- `MacAmpApp/Models/AppSettings.swift` ✅ (videoWindowSizeMode added)
- `MacAmpApp/ViewModels/WindowCoordinator.swift` (add resize logic + observer)
- `MacAmpApp/Views/Windows/VideoWindowChromeView.swift` (add button overlays)
- `MacAmpApp/AppCommands.swift` (add Ctrl+1, Ctrl+2 shortcuts)

**Next Session:** Implement in ~30-45min following this plan!
