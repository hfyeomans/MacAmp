# Unified Dock Migration Regressions Research

## Skin loading lifecycle
- `MacAmpApp/MacAmpApp.swift:23-44` calls `skinManager.loadInitialSkin()` before instantiating `WindowCoordinator`, but `WindowCoordinator` immediately calls `showAllWindows()` (`MacAmpApp/ViewModels/WindowCoordinator.swift:57-71`). Because `SkinManager.loadSkin` performs async decompression and flips `isLoading` until sprites are parsed (`MacAmpApp/ViewModels/SkinManager.swift:468-505`), the NSWindows render while `skinManager.currentSkin` is still `nil`, causing the no-skin flash noted in UnifiedDockView migration notes.
- The previous SwiftUI container deferred rendering until a skin existed. In `/tmp/UnifiedDockView.swift:18-45` the body displays a `ProgressView` while `skinManager.isLoading` and only builds the window stack when `currentSkin != nil`, which prevented blank chrome from appearing.

## Window configuration timing & input focus
- Buttons/sliders inside the new NSWindows are unresponsive because the borderless windows never become active on first click. The custom `BorderlessWindow` only overrides `canBecomeKey`/`canBecomeMain` (`MacAmpApp/Windows/BorderlessWindow.swift:4-7`) so the first click on an inactive app merely activates the process without forwarding the original event. UnifiedDockView’s `WindowAccessor` configured an already-presented SwiftUI window, so activation happened automatically.
- The migration task log (`tasks/magnetic-docking-foundation/state.md:820-836`) even called out adding `acceptsFirstMouse` as the follow-up to avoid the “click once to focus, click again to act” behavior. Without that override—and without re-activating the app before ordering windows front—controls feel non-clickable.

## Summary of gaps to fix
1. Gate `WindowCoordinator.showAllWindows()` behind `skinManager` readiness (mirror UnifiedDockView’s loading guard) so the first visible frame already has a skin applied.
2. Ensure manual NSWindows activate properly by both overriding `acceptsFirstMouse` in `BorderlessWindow` and explicitly activating/order-fronting once just before presentation so pointer events aren’t swallowed.
