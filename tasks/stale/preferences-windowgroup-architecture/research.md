# Research

## Follow-up questions
- The product request already specifies the root issue (Preferences `WindowGroup` auto-opening) and highlights the `.defaultLaunchBehavior(.suppressed)` mitigation, so no additional clarifications were required before inspecting the code.

## Codebase observations
1. `MacAmpApp` builds all shared singletons in its `init` and immediately constructs a global `WindowCoordinator.shared`, which owns every NSWindowController for the main UI (`MacAmpApp/MacAmpApp.swift:14-51`). The SwiftUI scene graph is only used for the Settings scene and a `WindowGroup` dedicated to `PreferencesView`.
2. The Preferences `WindowGroup` is configured with custom style/resizability defaults and now opts out of automatic launch through `.defaultLaunchBehavior(.suppressed)` (`MacAmpApp/MacAmpApp.swift:62-75`). This is the only SwiftUI `WindowGroup`, so without suppression SwiftUI tries to create that scene on app launch.
3. `WindowCoordinator` (an `@Observable @MainActor` type) manually creates and shows five `NSWindowController` instances—main, EQ, playlist, video, and Milkdrop—inside its initializer (`MacAmpApp/ViewModels/WindowCoordinator.swift:108-217`). The coordinator also applies layout, hooks up focus/persistence delegates, and exposes window references via computed properties (`MacAmpApp/ViewModels/WindowCoordinator.swift:100-205`).
4. Window presentation waits until the initial skin finishes loading through `presentWindowsWhenReady`, which polls `skinManager` and eventually calls `presentInitialWindows` to `showAllWindows` (`MacAmpApp/ViewModels/WindowCoordinator.swift:921-956`). This bypasses SwiftUI’s scene lifecycle entirely.
5. Layout persistence/state restoration is implemented manually via `WindowFrameStore`, which serializes `NSRect`s into `UserDefaults` for each `WindowKind` (`MacAmpApp/ViewModels/WindowCoordinator.swift:1058-1142` and `1280-1351`). The coordinator also manages window levels, double-size toggles, docking offsets, and focus by combining delegates and timers.
6. Because the main UI windows are AppKit-native and never registered as SwiftUI scenes, SwiftUI's automatic scene/resume behavior (state restoration, command routing, ScenePhase notifications) only applies to the Settings/Preferences scenes. Everything else depends on `WindowCoordinator` and the custom `DockingController`/`WindowSnapManager` stack for lifecycle.

## Oracle (Codex) Architectural Review - November 2025

**Date:** 2025-11-16
**Context:** During v0.8.9 release build, the Preferences WindowGroup auto-opened on launch because SwiftUI sees no SwiftUI Windows (all main windows are NSWindows).

### Fix Applied
```swift
// MacAmpApp.swift:62-69
WindowGroup("Preferences", id: "preferences") {
    PreferencesView()
        .environment(settings)
}
.windowStyle(.hiddenTitleBar)
.windowResizability(.contentSize)
.defaultPosition(.center)
.defaultLaunchBehavior(.suppressed)  // FIX APPLIED
```

### Oracle's Architectural Assessment

**Rating: 3/5** - Architecture works but fights SwiftUI patterns

**Immediate Safety:**
- `.defaultLaunchBehavior(.suppressed)` is safe and acceptable
- No immediate issues with state restoration, memory, or lifecycle
- Menu commands will still present Preferences scene when invoked

**Issues Identified:**

1. **State Restoration** - macOS/SwiftUI cannot restore main UI because it never knew about those windows. Relies entirely on bespoke `WindowFrameStore` that writes/reads rects from UserDefaults (WindowCoordinator.swift:1058-1142, 1280-1351), which only preserves position/size.

2. **Window Management** - Since `presentInitialWindows` runs outside the scene system and calls `NSApp.activate` directly (WindowCoordinator.swift:931-956), must maintain focus order, "Window" menu listings, Stage Manager behavior, and responder chain integration manually.

3. **App Lifecycle** - `@Environment(\.scenePhase)` and other scene-aware APIs only observe the dormant Settings/Preferences scenes, so most of the app has no view of backgrounding, multi-scene activity, or automatic resource teardown.

4. **Memory Management** - `WindowCoordinator.shared` retains every controller/task for the app's lifetime (WindowCoordinator.swift:54-89). The observers initialized at lines 189-217 never get a natural teardown point because SwiftUI never destroys the "scene," so leaks or stale observers become your responsibility.

### Oracle's Recommendations for Resolution

**Option 1: SwiftUI Window Wrapper (Recommended)**
Add a lightweight SwiftUI `Window("Main", id: "main")` that hosts a `CoordinatorHostedView` (e.g., via `NSViewControllerRepresentable`) and uses that hook to access the underlying NSWindow for magnetic docking. SwiftUI regains lifecycle awareness while you keep AppKit-level control.

**Option 2: Individual Window Scenes**
Split each Winamp-style window into its own SwiftUI `Window` scene that wraps the existing AppKit view/controller; use `.windowStyle(.hiddenTitleBar)` and `.windowResizability` for styling, and apply docking logic by reading the NSWindow through a view modifier.

**Option 3: NSApplicationDelegate Pattern**
If the singleton is mandatory, expose it through an `NSApplicationDelegate` (`@NSApplicationDelegateAdaptor`) and let the SwiftUI App still declare the windows it wants. That keeps the framework's understanding of your scenes in sync with reality.

### Implementation Priorities

1. **Immediate (Done):** Keep `.defaultLaunchBehavior(.suppressed)` as stop-gap
2. **Short-term:** Document why it exists so future work can remove it once a main scene exists
3. **Medium-term:** Prototype SwiftUI `Window` wrapper for main Winamp stack
4. **Long-term:** Migrate manual frame persistence to SwiftUI/macOS state restoration once windows become scenes, reducing custom UserDefaults plumbing

### Files to Modify for Full Resolution

- `MacAmpApp.swift` - Add at least one SwiftUI-managed Window scene
- `WindowCoordinator.swift` - Scope observation tasks per window or per scene so they cancel when windows close
- Consider `NSViewControllerRepresentable` wrappers for existing NSWindowControllers
- Review observers at lines 189-217 that never get natural teardown points
