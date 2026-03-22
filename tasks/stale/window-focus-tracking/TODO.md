# Window Focus Tracking - TODO

**Status:** VIDEO window complete ✅, Other windows deferred ⏸️

---

## Completed ✅

**Video Window (TASK 2):**
- ✅ WindowFocusState @Observable model created
- ✅ WindowFocusDelegate created (follows WindowPersistenceDelegate pattern)
- ✅ Wired through WindowCoordinator + DelegateMultiplexer
- ✅ VideoWindowChromeView reads focusState.isVideoKey
- ✅ Titlebar switches between ACTIVE/INACTIVE sprites on focus change
- ✅ Architecture: Proper three-layer (Mechanism → Bridge → Presentation)
- ✅ Swift 6 compliant (@Observable, @MainActor)

---

## Deferred to Future ⏸️

**Main Window:**
- Has SELECTED/normal titlebar sprites in TITLEBAR.bmp
- Needs: Read focusState.isMainKey
- Needs: Update WinampMainWindow titlebar rendering

**Equalizer Window:**
- Has SELECTED/normal titlebar sprites in EQMAIN.bmp
- Needs: Read focusState.isEqualizerKey
- Needs: Update equalizer chrome rendering

**Playlist Window:**
- Has SELECTED/normal titlebar sprites in PLEDIT.bmp
- Needs: Read focusState.isPlaylistKey
- Needs: Update playlist titlebar rendering

**Milkdrop Window:**
- Has SELECTED/normal titlebar sprites in GEN.bmp
- Needs: Read focusState.isMilkdropKey
- Needs: Update MilkdropWindowChromeView (change `_SELECTED` suffix logic)

---

## Implementation Pattern (For Future Windows)

**In window chrome view:**
```swift
@Environment(WindowFocusState.self) private var windowFocusState

private var isWindowActive: Bool {
    windowFocusState.is[Window]Key  // Replace [Window] with: Main, Equalizer, Playlist, Video, Milkdrop
}

// Use in sprite selection:
let suffix = isWindowActive ? "ACTIVE" : "INACTIVE"  // or "_SELECTED" : "" for GEN
SimpleSpriteImage("SPRITE_NAME_\(suffix)", ...)
```

**Already wired in Bridge layer:**
- WindowFocusDelegate for each window
- Added to DelegateMultiplexer
- Updates WindowFocusState on didBecomeKey/didResignKey
- All windows ready - just need Presentation layer updates

---

## Files

**Created:**
- `MacAmpApp/Models/WindowFocusState.swift`
- `MacAmpApp/Utilities/WindowFocusDelegate.swift`

**Modified:**
- `MacAmpApp/ViewModels/WindowCoordinator.swift` (added focus delegates, wired to multiplexers)
- `MacAmpApp/Windows/WinampVideoWindowController.swift` (inject windowFocusState)
- `MacAmpApp/Views/Windows/VideoWindowChromeView.swift` (read from environment)
- `MacAmpApp/MacAmpApp.swift` (create and inject windowFocusState)

**Lines Added:** ~80 lines
**Architecture:** Clean, reusable, Swift 6 compliant

---

**Next Session:** Apply same pattern to Main/EQ/Playlist/Milkdrop windows (~15min each)
