# Research

## Goal

Explain why Butterchurn/Milkdrop works when launching the built app outside Xcode but fails when launching from Xcode, and recommend likely fixes without changing code.

## Findings

- The Butterchurn assets are present in the built app bundles, including the Xcode Debug build:
  - `build/DerivedDataDev/Build/Products/Debug/MacAmp.app/Contents/Resources/Butterchurn/index.html`
  - `build/DerivedDataDev/Build/Products/Debug/MacAmp.app/Contents/Resources/Butterchurn/bridge.js`
  - `build/DerivedDataDev/Build/Products/Debug/MacAmp.app/Contents/Resources/Butterchurn/butterchurn.min.js`
  - preset files are also present
- `project.yml` sets `CODE_SIGN_ENTITLEMENTS` to `MacAmpApp/MacAmp.entitlements` and enables hardened runtime.
- `project.yml` does not explicitly list `Butterchurn/` under `resources`, but that is not currently blocking runtime because the built bundles already contain the Butterchurn payload.
- `MacAmp.entitlements` contains:
  - `com.apple.security.cs.allow-jit`
  - `com.apple.security.cs.allow-unsigned-executable-memory`
  - `com.apple.security.cs.allow-dyld-environment-variables = false`
  - `com.apple.security.cs.disable-library-validation = false`
  - `com.apple.security.cs.disable-executable-page-protection = false`
  - `com.apple.security.device.audio-output`
  - `com.apple.security.network.client`
  - user-selected file access entitlements
- `MacAmp.entitlements` does not contain `com.apple.security.app-sandbox`.
- `ButterchurnWebView.swift` unconditionally enables:
  - `developerExtrasEnabled` via KVC on `WKPreferences`
  - `isInspectable = true` on macOS 13.3+
- `ButterchurnWebView.swift` loads `Butterchurn/index.html` from the main bundle with `loadFileURL`.
- `codesign -dvvv --entitlements :-` reports the same warning for both the Debug app bundle and the `dist` app bundle:
  - `warning: binary contains an invalid entitlements blob. The OS will ignore these entitlements.`
- `show_build_settings` for the Xcode target reports:
  - `ENABLE_APP_SANDBOX = NO`
  - `ENABLE_HARDENED_RUNTIME = YES`
  - `RUNTIME_EXCEPTION_ALLOW_JIT = NO`
  - `RUNTIME_EXCEPTION_ALLOW_UNSIGNED_EXECUTABLE_MEMORY = NO`
- The Xcode-only failure mode is a `WKWebView` / `WebContent` helper-process failure with logs mentioning:
  - pasteboard and launch services lookup restrictions
  - RunningBoard denial
  - `AudioComponentRegistrar` lookup failure
  - helper-process crashes / invalidation
  - a Metal shader archive failure in `IconRendering.framework`
- The user has an active parallel effort in `tasks/swift-concurrency-62-cleanup/plan.md`.
- That concurrency plan explicitly expects PR 1 to modify `project.yml`, which makes `project.yml` the most likely merge-conflict surface between the two efforts.

## Interpretation

- Missing bundle resources is unlikely to be the cause because the Xcode Debug app already contains the Butterchurn assets.
- The strongest concrete signal is the invalid entitlements warning. If the OS ignores those entitlements, any intended JIT or executable-memory allowances for the app or helper process are unreliable.
- The `show_build_settings` output strengthens that diagnosis: the built target is not showing the expected runtime JIT exceptions as enabled, even though the entitlements file contains those keys.
- The `WebContent[...]` XPC and sandbox logs are consistent with a `WKWebView` helper process taking a restricted path during Xcode launch. They look more like process-launch/sandbox symptoms than a missing-file problem.
- Always-on inspection/devtools flags in `ButterchurnWebView.swift` are a plausible differentiator between normal app launch and Xcode-run behavior.
- Because the app works outside Xcode, the likely problem is not Butterchurn JavaScript itself. The higher-probability failure area is launch-time signing/runtime configuration or Xcode-only WebKit inspection behavior.

## Recommendations

- Treat asset bundling as already satisfied. Do not center the fix on adding Butterchurn files to the Xcode project unless verification later proves those files disappear from the app bundle.
- Fix the signing / entitlements path first:
  - determine why the built app carries an invalid entitlements blob
  - make sure hardened-runtime exceptions, if truly needed, are valid and actually applied to the signed app
  - verify with `codesign` after the fix instead of assuming `project.yml` is enough
- Isolate the Xcode-only `WKWebView` debug path second:
  - gate `developerExtrasEnabled`
  - gate `isInspectable`
  - avoid always-on WebKit inspection features in production and in ordinary app runs unless explicitly desired
- Preserve production bundling of Butterchurn assets while fixing the launch/runtime issue.

## Worktree / PR Strategy

- Do this fix in a separate worktree.
- Because `tasks/swift-concurrency-62-cleanup/plan.md` already plans edits to `project.yml`, the safest default is to branch this work from the concurrency PR 1 branch first instead of from `main`.
- Recommended branch flow:
  - create a worktree from `feature/swift-concurrency-62-cleanup`
  - implement the Butterchurn fix there
  - open the Butterchurn PR against the concurrency branch first
  - after the concurrency PR merges to `main`, rebase the Butterchurn branch onto `main` and retarget that PR
- If the final fix turns out not to touch `project.yml` or any concurrency-touched files, it can later be cherry-picked or rebased into an independent `main`-based PR.

## Open Questions

- Whether the invalid entitlements blob is caused by a malformed entitlements file, a signing mismatch, or a generated-project/build-setting issue.
- Whether WebKit inspection flags are the trigger or merely an amplifier of an already-invalid signing/runtime setup.
- Whether the Metal / `IconRendering.framework` crash line is a downstream symptom of the `WebContent` helper failure rather than a separate root cause.
