## Sources Reviewed

- `/tmp/UnifiedDockView.swift`: legacy dock view that hosted all Winamp panes in a single SwiftUI view.
- `MacAmpApp/ViewModels/WindowCoordinator.swift`: new coordinator that spawns three standalone `NSWindowController`s.
- `MacAmpApp/Windows/Winamp{Main|Equalizer|Playlist}WindowController.swift`: controllers responsible for instantiating `BorderlessWindow` wrappers around SwiftUI content.
- `MacAmpApp/Windows/BorderlessWindow.swift`: minimal subclass overriding `canBecomeKey`/`canBecomeMain`.
- `MacAmpApp/MacAmpApp.swift`: entry point that bootstraps singletons and initializes `WindowCoordinator`.

## Findings

1. **Skin loading guard (`ensureSkin`)**  
   - Legacy view lazily called `skinManager.loadInitialSkin()` from `.onAppear` when `currentSkin` was nil.  
   - New architecture constructs windows in `WindowCoordinator.init` without forcing an initial skin load, so windows can appear with empty chrome the first time the app runs.

2. **Always-on-top propagation**  
   - Legacy view toggled the hosting window’s `level` via `dockWindow?.level = isOn ? .floating : .normal` inside an `onChange(of: settings.isAlwaysOnTop)` handler and also initialized the level inside `WindowAccessor`.  
   - None of the new controllers observe `AppSettings.isAlwaysOnTop`, so `.floating` mode is lost.

3. **Window accessor pattern**  
   - `WindowAccessor` stored the SwiftUI host window reference as soon as it existed and ran `configureWindow` immediately afterward.  
   - In the new setup we create `BorderlessWindow` manually, so we must replicate any config that used to live in `configureWindow` (style mask, title bar tweaks, `toolbar = nil`, etc.). Current controllers set only a subset (e.g., they don’t disable the toolbar explicitly).

4. **`configureWindow` details**  
   - Ensured `.borderless`, removed `.titled`, hid title visibility, nulled toolbars on macOS 11+, disabled background dragging, forced `.normal` level, and optionally disabled shadows.  
   - Acts as canonical baseline for all Winamp windows.

5. **Double-size scaling**  
   - Dock view scaled each pane by `settings.isDoubleSizeMode ? 2.0 : 1.0`.  
   - New independent windows hard-code 1x window sizes, so the double-size preference no longer affects anything.

6. **Animations/background materials**  
   - Complex background view and glow/shimmer states depended on `settings.materialIntegration`, `settings.enableLiquidGlass`, and `audioPlayer.isPlaying`.  
   - New windows don’t surface this styling yet; Winamp chrome probably renders the original bitmaps so this is less critical for functionality.

7. **Dependency flow & observation gaps**  
   - Window controllers receive `settings`, `skinManager`, etc. but don’t subscribe to changes.  
   - `WindowCoordinator` has references to each controller but doesn’t retain reactive cancellables, so global settings can’t fan out to the three windows yet.

8. **Borderless window activation**  
   - Legacy relied on `WindowAccessor` touching `window.level` and `isMovable` to keep interactions alive.  
   - Current `BorderlessWindow` subclass is minimal; window controllers rely on it for focus but don’t adjust responder chain nor dragging surfaces.
