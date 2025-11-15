# Research: Milkdrop window renders black

## Window bootstrapping
- `WindowCoordinator` instantiates `WinampMilkdropWindowController` inside its initializer (MacAmpApp/ViewModels/WindowCoordinator.swift:146-152). That means the SwiftUI tree for Milkdrop is mounted the moment the app boots, *before* the user toggles the window. `onAppear` handlers for `WinampMilkdropWindow` and its children therefore fire once during startup and produce no additional logs when you later call `showMilkdrop()`.
- `WinampMilkdropWindowController` wires an `NSHostingController` whose `rootView` is `WinampMilkdropWindow` directly into the `BorderlessWindow` (MacAmpApp/Windows/WinampMilkdropWindowController.swift:27-48). The chrome you see on screen comes from this SwiftUI hierarchy, so the lack of later logs is not evidence that the view failed to render.

## Butterchurn content loading
- `ButterchurnWebView.makeNSView` attempts to load `test.html` from `Resources/Butterchurn` in the application bundle (MacAmpApp/Views/Windows/ButterchurnWebView.swift:22-40). If the file cannot be found, it prints a failure message and leaves the WKWebView empty.
- The project file only copies `bridge.js`, `butterchurn.min.js`, `butterchurnPresets.min.js`, and `index.html` for that directory. There is **no** `test.html` entry in the `PBXResourcesBuildPhase` (MacAmpApp.xcodeproj/project.pbxproj:421-435). Because `test.html` is excluded from the bundle, the WKWebView never finds its HTML entry point and the content region stays black.

## Summary
The SwiftUI tree is mounted correctly at launch, which is why the GEN chrome renders even when you do not see fresh logs. The blank content area comes from the WKWebView failing to load any HTML because the referenced `test.html` is missing from the bundle.
