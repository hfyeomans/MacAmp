# Video Window Startup Bug — Research

## Goal
Explain why the VIDEO window becomes visible before the Main/EQ/Playlist windows during app launch even though it should stay hidden until explicitly opened.

## Key Observations

1. **Primary windows wait for skin load**  
   `WindowCoordinator.presentWindowsWhenReady()` (MacAmpApp/ViewModels/WindowCoordinator.swift:844-879) blocks `presentInitialWindows()` until `skinManager` finishes loading. Only then does `showAllWindows()` execute, which orders just `mainWindow`, `eqWindow`, and `playlistWindow` to the front (lines 1124-1132). VIDEO/Milkdrop are intentionally excluded from this default stack.

2. **Video window visibility is fully driven by AppSettings**  
   `setupVideoWindowObserver()` (lines 365-397) runs inside `WindowCoordinator.init`. It watches `settings.showVideoWindow` using `withObservationTracking` and *immediately* calls `showVideo()` if that flag is `true`, before any `skinManager` readiness checks run.

3. **Observer fires before the rest of the windows are presented**  
   `setupVideoWindowObserver()` is invoked before `presentWindowsWhenReady()` (init order around lines 170-210). Therefore, when `settings.showVideoWindow` is `true` (persisted from the last run or defaulted during testing), `showVideo()` executes as soon as the coordinator is constructed. This happens while `skinManager.isLoading` is still `true`, so the video window appears with no chrome until sprites finish loading.

4. **`showVideo()` does not guard on `hasPresentedInitialWindows`**  
   `showVideo()` (lines 1134-1144) simply calls `videoWindow?.makeKeyAndOrderFront(nil)` without checking whether the initial window presentation finished. By contrast, the main trio do not expose observers that raise their windows ahead of `presentInitialWindows()`.

5. **Video controller mirrors other controllers otherwise**  
   `WinampVideoWindowController` (MacAmpApp/Windows/WinampVideoWindowController.swift) only builds the NSWindow/SwiftUI host; it does not explicitly show the window. This matches the pattern from the Main/EQ/Playlist controllers, confirming that the premature ordering happens higher up in `WindowCoordinator`.

6. **Settings default is false but persisted values override**  
   `AppSettings` loads `showVideoWindow` from `UserDefaults` (MacAmpApp/Models/AppSettings.swift:61-74, 235-239). The default is `false`, but any previous `true` persists across launches, so QA devices that ever opened VIDEO will re-open it immediately through the observer.

## Interim Conclusion

The VIDEO window surfaces early because `setupVideoWindowObserver()` is eager: it runs before the main presentation pipeline and unconditionally orders the window the moment `settings.showVideoWindow` is `true`. Since the observer is not gated on `hasPresentedInitialWindows` or `skinManager` readiness, VIDEO becomes the first visible window (and renders blank until the skin finishes loading). Main/EQ/Playlist avoid this because they are only shown inside `presentInitialWindows()` after `skinManager` reports ready.

To match the expected sequence, the VIDEO observer needs to be deferred (or it should check `hasPresentedInitialWindows`) so that no `makeKeyAndOrderFront` call runs before the coordinated startup completes, and it should respect the user preference to stay hidden unless explicitly opened.
