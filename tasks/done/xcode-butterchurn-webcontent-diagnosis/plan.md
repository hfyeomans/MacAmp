# Plan

## Objective

Fix the Xcode-only Butterchurn / Milkdrop failure without regressing the packaged app and without tangling the work with the in-flight Swift 6.2 cleanup.

## Execution Strategy

1. Create a dedicated worktree from `main`.
   Reason: the Swift 6.2 cleanup work is complete and merged, so the Butterchurn fix no longer needs to stack on that branch.

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
   - Use a focused task branch from `main`
   - Open a dedicated PR for the Butterchurn fix
   - Keep feature-consolidation moves out of this PR unless directly required by the runtime fix

## Architecture Alignment Note

- This task should use the approved structure policy as guidance, not as a second objective.
- Fix signing/runtime/WebKit behavior first.
- Only begin `Features/Milkdrop` consolidation inside this task if a file move is directly required anyway.
- Otherwise, defer the actual consolidation work to `milkdrop-feature-consolidation`.

## Success Criteria

- Butterchurn renders when the app is run from Xcode.
- Butterchurn still renders outside Xcode.
- The signed app no longer reports an invalid entitlements blob.
- No unnecessary always-on WebKit inspection settings remain in the normal runtime path.
- Butterchurn assets remain bundled in the production app.
