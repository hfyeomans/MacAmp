# State

## Status

Diagnosis complete. Ready for implementation in a separate worktree.

**Sprint:** S1 (HIGH)
**Last Updated:** 2026-03-14

## Current Position

- Butterchurn resources are present in the Xcode Debug app bundle.
- Butterchurn also remains present in the packaged / `dist` app bundle.
- The current diagnosis is centered on signing/entitlements and Xcode-only `WKWebView` process behavior.
- The strongest concrete signal is the invalid entitlements warning on the signed app.
- Xcode build settings do not show the expected runtime JIT exceptions as active.
- Always-on WebKit inspection flags remain a secondary likely contributor.

## Decisions

- Do not treat asset bundling as the primary issue.
- Do not manually edit `.pbxproj`; if build-setting changes are needed, make them in `project.yml` and regenerate.
- Use a separate worktree for implementation.
- Branch that worktree from `main` because the Swift 6.2 cleanup work is complete and merged.
- Keep this task focused on the runtime fix; defer broad Milkdrop file moves to the dedicated post-S1 consolidation task.

## Next

- Create the implementation worktree from `main`.
- Fix the signing / entitlements path and verify the signed app no longer carries an invalid entitlements blob.
- Then isolate any Xcode-only WebKit inspection behavior if the signing fix alone is insufficient.
- Verify in both Xcode-run and standalone launch modes.

## Handoff Note

The likely merge-conflict surface is `project.yml`, not the Butterchurn asset files themselves. Use a focused branch from `main` and keep any broader `Features/Milkdrop` consolidation for the dedicated follow-on task.
