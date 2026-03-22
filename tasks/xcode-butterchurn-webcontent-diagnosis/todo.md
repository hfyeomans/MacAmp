# Todo

## Investigation (COMPLETE)
- [x] Create implementation branch `fix/xcode-butterchurn-webcontent`
- [x] Inspect `MacAmpApp/MacAmp.entitlements` for invalid or ineffective keys — entitlements identical to working PR #32
- [x] Inspect `project.yml` signing/runtime settings — hardened runtime correct, signing correct
- [x] Verify `codesign -dvvv --entitlements :-` — false-valued keys cause "invalid blob" warning but NOT the root cause
- [x] Review `ButterchurnWebView.swift` — `developerExtrasEnabled` and `isInspectable` not the cause
- [x] Investigate macOS 26 Tahoe WebContent sandbox errors — non-fatal console noise (WebKit bug 302212)
- [x] Test with hardened runtime disabled for Debug — did not fix
- [x] Test with App Sandbox enabled — did not fix
- [x] Test with shared WKProcessPool + deferred load (Gemini suggestions) — did not fix

## Root Cause Found (COMPLETE)
- [x] Discovered Butterchurn resources NOT in app bundle — `Bundle.main.url(forResource:subdirectory:)` returns nil
- [x] Root cause: XcodeGen migration (`project.yml`) never included `Butterchurn/` folder as a resource
- [x] Old manual `.xcodeproj` had it as folder reference in "Copy Bundle Resources" — lost during migration
- [x] Fix: Add `Butterchurn` to `project.yml` sources with `type: folder` and `buildPhase: resources`
- [x] Verified Butterchurn resources present in Debug and Release bundles

## Fix Applied (COMPLETE)
- [x] Add Butterchurn folder resource to `project.yml` — 3 lines added
- [x] Persist EQ on/off state via UserDefaults (pre-existing bug found during testing)
- [x] Entitlements unchanged from main (no modifications needed)
- [x] ButterchurnWebView.swift unchanged from main (no modifications needed)
- [x] Do not move Butterchurn files — defer to `milkdrop-feature-consolidation`

## Verification (COMPLETE)
- [x] XcodeBuildMCP build — PASSES
- [x] XcodeBuildMCP test — 53/53 PASS
- [x] Standalone Debug binary — Butterchurn renders, 245 presets loaded
- [x] `Contents/Resources/Butterchurn/` present with all files (index.html, JS, presets)
- [x] Skins and Assets.xcassets still bundled (not dropped by project.yml change)
- [x] Open PR #63 against `main`
