# Plan

1. **Bundle the HTML entry point**
   - Add `MacAmpApp/Resources/Butterchurn/test.html` to the Xcode project's resources so it is copied into the app bundle alongside the JS files already referenced in `project.pbxproj`.
2. **Harden `ButterchurnWebView` loading logic**
   - Update `makeNSView` to attempt `test.html` first, then fall back to `index.html` (the file that already ships) and log the path that is actually loaded.
   - Keep the existing diagnostic log in the failure branch so missing assets continue to surface during development.
3. **Verification**
   - Re-run `xcodebuild -showBuildSettings`? (skip) Instead, rely on file inspection to confirm that `test.html` now appears in the `PBXResourcesBuildPhase` and that the loader gracefully handles either file.
   - Document the new behavior in `state.md`.
