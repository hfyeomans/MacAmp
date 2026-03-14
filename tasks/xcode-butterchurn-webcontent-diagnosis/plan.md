# Plan

## Objective

Fix the Xcode-only Butterchurn / Milkdrop failure without regressing the packaged app and without tangling the work with the in-flight Swift 6.2 cleanup.

## Execution Strategy

1. Create a dedicated worktree from `feature/swift-concurrency-62-cleanup`, not from `main`.
   Reason: the concurrency plan already expects `project.yml` edits, so this avoids an avoidable conflict if the Butterchurn fix also touches signing/build settings.

2. Validate the signing and entitlements path first.
   - Inspect `MacAmpApp/MacAmp.entitlements`
   - Inspect relevant signing/runtime settings in `project.yml`
   - If `project.yml` changes are needed, regenerate via XcodeGen
   - Rebuild and verify that `codesign -dvvv --entitlements :-` no longer reports an invalid entitlements blob
   - Confirm the built app reflects the intended runtime exceptions only if they are actually required

3. Isolate the Xcode-only WebKit path second.
   - Review `ButterchurnWebView.swift`
   - Gate `developerExtrasEnabled` and `isInspectable` behind an explicit debug-only or opt-in condition
   - Keep the production path as plain as possible unless inspection is deliberately enabled

4. Verify runtime behavior in both launch modes.
   - Run from Xcode in Debug and confirm Butterchurn renders
   - Launch the packaged / standalone app and confirm Butterchurn still renders
   - Confirm the Butterchurn assets remain in the app bundle

5. Land the work with a low-conflict merge pattern.
   - Open the Butterchurn PR against the concurrency branch first
   - After the concurrency PR merges, rebase the Butterchurn branch onto `main`
   - Retarget the PR to `main`

## Success Criteria

- Butterchurn renders when the app is run from Xcode.
- Butterchurn still renders outside Xcode.
- The signed app no longer reports an invalid entitlements blob.
- No unnecessary always-on WebKit inspection settings remain in the normal runtime path.
- Butterchurn assets remain bundled in the production app.
