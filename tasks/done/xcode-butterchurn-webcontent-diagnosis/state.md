# State

## Status

✅ COMPLETE — PR #63 merged (2026-03-22).

**Sprint:** S1 (HIGH)
**Last Updated:** 2026-03-22
**Branch:** `fix/xcode-butterchurn-webcontent` (merged)

## Root Cause

The Butterchurn/MilkDrop failure was **not** an entitlements, signing, sandbox, or concurrency issue. It was a **missing resource bundle** from the XcodeGen migration.

When the project migrated from a manually-managed `.xcodeproj` to XcodeGen (`project.yml`), the `Butterchurn/` folder was never added to the resources list. The old `.xcodeproj` had it as a folder reference in "Copy Bundle Resources", but `project.yml` only listed `MacAmpApp/Skins` and `MacAmpApp/Assets.xcassets`.

Result: `Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Butterchurn")` returned `nil` — the files weren't in the app bundle. ButterchurnWebView fell through to the inline fallback HTML which has no JavaScript, showing "loading" indefinitely.

## Fix

**project.yml** — 3 lines added:
```yaml
sources:
  - path: MacAmpApp
    ...
  - path: Butterchurn
    type: folder
    buildPhase: resources
```

**EqualizerController.swift** — EQ on/off state persistence (pre-existing bug found during testing):
- `isEqOn` didSet now saves to UserDefaults
- init restores from UserDefaults

## What Was NOT the Cause (investigated and ruled out)

| Investigated | Result |
|-------------|--------|
| Entitlements (false-valued keys) | Identical to working PR #32. False keys cause codesign warning but are non-functional. |
| Hardened Runtime | Disabling for Debug did not fix. Not the cause. |
| App Sandbox | Enabling did not fix. Not needed. |
| Swift 6.2 concurrency | No `@preconcurrency` needed. WKWebView works fine with Swift 6.2. |
| macOS 26 Tahoe WebContent sandbox | Console errors are non-fatal noise (WebKit bug 302212). Butterchurn renders despite errors. |
| `developerExtrasEnabled` / `isInspectable` | Not the cause. Left unchanged. |
| Shared WKProcessPool | Gemini suggestion — did not fix. Not needed. |
| Deferred WebView load | Gemini suggestion — did not fix. Not needed. |

## Decisions

- Entitlements left unchanged from main (identical to PR #32)
- ButterchurnWebView.swift left unchanged from main (no `#if DEBUG` gates needed)
- project.yml hardened runtime left as-is (global, not per-config)
- WebContent console errors documented as macOS 26 Tahoe noise — not actionable
- Butterchurn file moves deferred to `milkdrop-feature-consolidation` (D-STRUCTURE decision)

## Lessons Learned

1. **XcodeGen migration must audit all "Copy Bundle Resources" entries.** When migrating from manual `.xcodeproj` to XcodeGen, every folder reference in the old build phases must be explicitly added to `project.yml`. XcodeGen only auto-discovers Swift sources under the `sources:` path — non-code resources outside that path are silently dropped.

2. **`swift build` / `swift test` hide resource issues.** SwiftPM discovers sources automatically and has its own resource handling (`Package.swift`). Resources that are in `Package.swift` but not in `project.yml` will work via CLI but fail in Xcode. Always verify with XcodeBuildMCP build + manual app launch.

3. **Don't chase console errors before verifying resources.** Hours were spent investigating entitlements, sandbox, concurrency, and macOS 26 behavior changes. The WebContent errors were a red herring — the actual issue was the most basic thing: files not in the bundle.

4. **macOS 26 Tahoe WebContent sandbox errors are noisy but non-fatal.** WKWebView apps will see pasteboard, launchservicesd, RunningBoard, and Metal shader warnings in the console. These are Apple-side issues (WebKit bug 302212) and do not prevent WKWebView/WebGL from functioning.

## Docs That Need Updating

| Doc File | Section | What to Update |
|----------|---------|----------------|
| `docs/MACAMP_ARCHITECTURE_GUIDE.md` | §7 Build configuration or resources section | Document that Butterchurn is a folder resource in project.yml, not under MacAmpApp/ |
| `docs/MILKDROP_WINDOW.md` | Resource bundling section | Note XcodeGen resource path and macOS 26 WebContent console noise |

## Architecture Notes

### Resource Bundle Layout (after fix)

```
MacAmp.app/Contents/Resources/
├── Assets.car                    (compiled from MacAmpApp/Assets.xcassets)
├── Butterchurn/                  (folder reference from project root)
│   ├── index.html                (canvas host page)
│   ├── bridge.js                 (Swift ↔ JS bridge)
│   ├── butterchurn.min.js        (WebGL visualizer engine)
│   ├── butterchurnPresets.min.js (base presets, ~100)
│   └── butterchurnPresetsExtra.min.js (extra presets, ~146)
├── *.wsz                         (Winamp skins from MacAmpApp/Skins)
└── ZIPFoundation_ZIPFoundation.bundle
```

### XcodeGen Resource Config

```yaml
# project.yml — resources must be explicitly listed
sources:
  - path: MacAmpApp        # Swift sources (auto-discovered)
  - path: Butterchurn       # Non-code resources (folder reference)
    type: folder
    buildPhase: resources
resources:
  - path: MacAmpApp/Skins          # Skin files
  - path: MacAmpApp/Assets.xcassets # App icons, images
```
