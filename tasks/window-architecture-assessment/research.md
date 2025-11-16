# Research Notes: Window Architecture Assessment

## Key Sources
- `MacAmpApp/MacAmpApp.swift`: SwiftUI `App` entry point using placeholder `WindowGroup` plus manual NSWindow coordination.
- `MacAmpApp/ViewModels/WindowCoordinator.swift`: @Observable singleton that instantiates and manages five NSWindowControllers plus docking/focus persistence.
- `docs/MACAMP_ARCHITECTURE_GUIDE.md`: Narrative describing five-window system, @Observable migration, docking, layering philosophy.

## Observations
1. **SwiftUI Scene Usage**
   - App defines suppressed placeholder `WindowGroup` (`id: main-placeholder`) and hidden `Settings` plus `Preferences` groups to satisfy SwiftUI requirements (MacAmpApp.swift:38-67).
   - Commands are attached to suppressed `WindowGroup`, but real UI lives in NSWindows created manually in `WindowCoordinator.init()`.

2. **WindowCoordinator Responsibilities**
   - Singleton `WindowCoordinator.shared` created inside `MacAmpApp.init()` with dependencies injected (MacAmpApp.swift:13-34, 45-57).
   - Coordinator instantiates five specialized NSWindowControllers (main, EQ, playlist, video, milkdrop), configures docking, window levels, persistence, focus delegates, and observes settings changes (WindowCoordinator.swift entire file).
   - Maintains custom `WindowFocusState`, `WindowFrameStore`, docking snapshots, Winamp-specific layouts, and uses `WindowDelegateMultiplexer` to handle window events.

3. **State & Dependency Flow**
   - SwiftUI App holds `@State` references to models (SkinManager, AudioPlayer, etc.) and passes into `WindowCoordinator`. No SwiftUI windows show actual content.
   - Coordinator is @Observable but not injected through SwiftUI environment; instead exposes `shared` static var for use by commands/views.

4. **Architecture Rationale from Guide**
   - docs guide states system now production-ready for macOS 15+/26+, emphasizes three-layer pattern, five-window expansion (docs/MACAMP_ARCHITECTURE_GUIDE.md sections 1-3, 7+).
   - Highlights magnetic docking cluster detection, window focus management, pixel-perfect reproduction, bridging layer bridging AppKit windows and SwiftUI views.
   - Reinforces dependency on AppKit windows for authenticity and docking behavior.

5. **SwiftUI Capabilities Mentioned**
   - Document references SwiftUI rendering for controls but no evidence of SwiftUI-native `WindowGroup` usage beyond placeholders.

6. **Technical Debt Points**
   - Singleton `WindowCoordinator.shared` is globally mutated.
   - Manual window lifecycle, persistence, and docking logic duplicates features now available in macOS 15+ SwiftUI windows (e.g., `.windowToolbarStyle`, `.windowLevel`, `.windowResizability`).
   - Hidden placeholder scenes risk App Store rejection / unusual behavior if SwiftUI expects visible content.

7. **Platform Context**
   - macOS 15+ (Sequoia/Tahoe) extends SwiftUI scenes: `.defaultLaunchBehavior`, `.restorationBehavior`, `.focusedSceneValue`, new `Window` scene APIs, `WindowAccessor`, improved `WindowDragGesture`, `metal` for window effects.
   - App currently still depends on AppKit's NSWindow for window-level manipulations and docking via `DockingController`.

These observations will feed into planning the assessment deliverable covering migration feasibility, singleton usage, technical debt, and recommendations.
