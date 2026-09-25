# MacAmp Release Build & Distribution Guide

This guide covers building MacAmp for direct download distribution using Developer ID signing, notarization, and a DMG.

Key facts (from `project.yml`):

| Setting | Value |
|---------|-------|
| Scheme | `MacAmpApp` |
| Target / product | `MacAmp` → `MacAmp.app` (not `MacAmpApp.app`) |
| Bundle ID | `com.hankyeomans.MacAmp` |
| Team | `AC3LGVEJJ8` |
| Signing | `CODE_SIGN_STYLE: Automatic`; Debug `Apple Development`, Release `Developer ID Application` |
| Hardened runtime | `ENABLE_HARDENED_RUNTIME: true` (all configurations) |
| Entitlements | `MacAmpApp/MacAmp.entitlements` |
| Version | `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` (Info.plist reads both) |
| Release output | `CONFIGURATION_BUILD_DIR: $(PROJECT_DIR)/dist` (`dist/` is gitignored; don't delete it) |
| Notary profile | `notarytool-password` (Keychain) |

## Prerequisites

### 1. Apple Developer Account

An **Apple Developer Program** membership is required for Developer ID certificates, notarization, and distribution outside the Mac App Store: https://developer.apple.com/programs/

### 2. Build Toolchain

- **Swift 6.2** — `swift-tools-version: 6.2`; requires Xcode with Swift 6.2 support
- **XcodeGen** v2.38.0+ (`brew install xcodegen`). `MacAmpApp.xcodeproj` is generated from `project.yml` and gitignored; run `xcodegen generate` before any build.

### 3. Developer ID Certificates

1. https://developer.apple.com/account/resources/certificates/list → **+**
2. Select **Developer ID Application**
3. Generate a CSR from Keychain Access, then download and install the certificate

Check it is installed: `security find-identity -v -p codesigning`

## Xcode Configuration

Signing settings live in `project.yml` (see the table above). Change them there and re-run `xcodegen generate`; never edit the generated project. The Xcode **Signing & Capabilities** tab of the **MacAmp** target should show team `AC3LGVEJJ8` and the entitlements file.

## Building a Release Build

### Method 1: Archive in Xcode

1. `xcodegen generate`, open `MacAmpApp.xcodeproj`
2. **Product → Archive** (Archive uses the Release configuration)
3. In Organizer: **Distribute App → Developer ID → Export**, choose a folder

### Method 2: Command Line

Pre-flight:
```bash
grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION|PRODUCT_NAME|CONFIGURATION_BUILD_DIR" project.yml
ls -d build/ dist/ 2>/dev/null
```

```bash
xcodegen generate

# CONFIGURATION_BUILD_DIR override is required: project.yml's dist/ conflicts with archive intermediate paths
xcodebuild archive \
  -project MacAmpApp.xcodeproj \
  -scheme MacAmpApp \
  -configuration Release \
  -archivePath ./build/MacAmp.xcarchive \
  CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=Developer ID Application" \
  DEVELOPMENT_TEAM=AC3LGVEJJ8 \
  CONFIGURATION_BUILD_DIR='$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)'

# If SPM packages fail to resolve:
# xcodebuild -resolvePackageDependencies -project MacAmpApp.xcodeproj -scheme MacAmpApp

xcodebuild -exportArchive \
  -archivePath ./build/MacAmp.xcarchive \
  -exportPath ./build/Release \
  -exportOptionsPlist ExportOptions.plist
```

`ExportOptions.plist` (repo root) sets `method: developer-id`, `teamID: AC3LGVEJJ8`, `signingStyle: manual`, `signingCertificate: Developer ID Application`.

## Notarization

**Required** on every supported macOS (27+); users cannot run the app without it.

### Credentials

Credentials are stored in the Keychain under profile `notarytool-password` (Apple ID `hank.yeomans@me.com`, team `AC3LGVEJJ8`). To re-create it (new machine, Keychain reset, rotated password), generate an app-specific password at https://appleid.apple.com (Security → App-Specific Passwords), then:

```bash
xcrun notarytool store-credentials "notarytool-password" \
  --apple-id "hank.yeomans@me.com" \
  --team-id "AC3LGVEJJ8"
# prompts for the app-specific password (or pass --password)
```

### Submit, Check, Staple

```bash
cd build/Release
ditto -c -k --keepParent MacAmp.app MacAmp.zip

# --wait blocks until Apple returns a result (usually 2-5 minutes)
xcrun notarytool submit MacAmp.zip --keychain-profile "notarytool-password" --wait

# Without --wait, or to inspect a rejection:
xcrun notarytool info SUBMISSION_ID --keychain-profile "notarytool-password"
xcrun notarytool log  SUBMISSION_ID --keychain-profile "notarytool-password" notarization-log.json

xcrun stapler staple MacAmp.app
xcrun stapler validate MacAmp.app
```

## Creating a DMG for Distribution

### Option 1: Branded DMG (Recommended)

Uses `assets/dmg-background.png` (MacAmp screenshot with gradient overlay and install instructions).

```bash
brew install create-dmg  # if not installed

mkdir -p dist
cp -R build/Release/MacAmp.app dist/

create-dmg \
  --volname "MacAmp" \
  --volicon "MacAmpApp/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
  --background "assets/dmg-background.png" \
  --window-pos 200 120 \
  --window-size 800 530 \
  --icon-size 100 \
  --icon "MacAmp.app" 250 450 \
  --hide-extension "MacAmp.app" \
  --app-drop-link 550 450 \
  "dist/MacAmp-VERSION.dmg" \
  "dist/"

xcrun notarytool submit dist/MacAmp-VERSION.dmg --keychain-profile "notarytool-password" --wait
xcrun stapler staple dist/MacAmp-VERSION.dmg
```

**Background image regeneration** (if the source screenshot changes):
```bash
magick SOURCE_SCREENSHOT.png \
  -resize 800x \
  -background black -gravity north -extent 800x530 \
  \( -size 800x300 gradient:"rgba(0,0,0,0)"-"rgba(0,0,0,0.95)" \
     -gravity south -background none -extent 800x530 \) \
  -composite \
  -gravity south -font "/System/Library/Fonts/Avenir Next.ttc" -weight 500 -pointsize 22 \
  -fill "rgba(255,255,255,0.9)" -annotate +0+135 "Drag MacAmp to Applications" \
  assets/dmg-background.png
```

### Option 2: Quick DMG (No Branding)

```bash
hdiutil create -volname "MacAmp" -srcfolder build/Release/MacAmp.app -ov -format UDZO MacAmp-VERSION.dmg
xcrun notarytool submit MacAmp-VERSION.dmg --keychain-profile "notarytool-password" --wait
xcrun stapler staple MacAmp-VERSION.dmg
```

## Verification

```bash
codesign --verify --deep --strict --verbose=2 MacAmp.app
codesign -dv --verbose=4 MacAmp.app        # Authority: Developer ID Application: Hank Yeomans (AC3LGVEJJ8)
codesign -d --entitlements - MacAmp.app    # MacAmp.entitlements, and no get-task-allow
spctl --assess --verbose=4 --type execute MacAmp.app   # "MacAmp.app: accepted"
```

Expected signature: identifier `com.hankyeomans.MacAmp`, team `AC3LGVEJJ8`, authority chain Developer ID Application → Developer ID Certification Authority → Apple Root CA, `Sealed Resources version 2`. See the `get-task-allow` trap under [Testing a Release Build](#testing-a-release-build).

Finally, test the DMG on a Mac that has never run the app: drag to Applications, launch, confirm no "unidentified developer" warning.

## Distribution Checklist

- [ ] `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` bumped in `project.yml`
- [ ] Signed with Developer ID, hardened runtime, entitlements included, no `get-task-allow`
- [ ] App notarized and stapled
- [ ] DMG created, notarized, and stapled
- [ ] Tested on a clean macOS 27+ system
- [ ] Release notes written; README.md download link and version references updated

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "App is damaged and can't be opened" | Missing notarization or quarantine issue | `spctl --assess --verbose MacAmp.app`; for an unsigned test build, `xattr -cr MacAmp.app` |
| "Developer cannot be verified" | Not notarized or ticket not stapled | Re-notarize; confirm with `xcrun stapler validate` |
| Notarization rejected | Hardened runtime off, invalid entitlements, unsigned frameworks/plugins, or `get-task-allow` present | Read `notarytool log` JSON (above) |
| Certificate / `CODE_SIGN_IDENTITY` not found | Developer ID cert missing or expired | Check the **login** keychain / `security find-identity -v -p codesigning`; re-download from developer.apple.com |
| Signature verification fails | Expired/revoked cert, Team ID mismatch, entitlements mismatch, unsigned embedded framework, resource modified after signing | Check cert validity and that Team ID matches `project.yml` |

## Code Signing Troubleshooting

Release builds write straight to `dist/` via `CONFIGURATION_BUILD_DIR`, so `dist/MacAmp.app` is signed in place by Xcode's CodeSign step; there is no copy step. Don't add a Run Script that copies the app into `dist/`: Run Script phases can execute before CodeSign, which previously shipped an unsigned app. If a copy is ever needed, do it in a scheme post-action, which runs after all build phases.

Verify the Release product:
```bash
./scripts/verify-dist-signature.sh            # defaults to dist/MacAmp.app; accepts a path or DIST_APP
```
It checks `codesign --verify --deep --strict`, prints identifier/authority/team, and checks hardened runtime and sealed resources.

## Debug vs Release Configuration

| | Debug | Release |
|---|---|---|
| Signing identity | Apple Development | Developer ID Application |
| Output | DerivedData | `dist/` |
| Hardened runtime | Enabled | Enabled |
| Notarization-ready | No | Yes (with `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` for local builds) |

### Testing a Release Build

```bash
# CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO keeps get-task-allow out
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Release build \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO

codesign --verify --deep --strict --verbose=2 dist/MacAmp.app
codesign -dvvv dist/MacAmp.app
codesign -d --entitlements - dist/MacAmp.app | grep get-task-allow || echo "no get-task-allow"
./scripts/verify-dist-signature.sh
```

**`get-task-allow` trap:** a plain `xcodebuild build` injects the `com.apple.security.get-task-allow` (debugger-attach) entitlement even for the Release configuration, and an Xcode Run does the same. Notarization rejects apps carrying it. Pass `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` to any locally built Release app meant for distribution or release-equivalent testing; with it, `codesign -d --entitlements -` shows no `get-task-allow` and `codesign --verify --strict` passes with `Developer ID Application: Hank Yeomans (AC3LGVEJJ8)` (verified 2026-09-25).

## Resources

- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [TN3127: Inside Code Signing](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-provisioning-profiles)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)

**Never share** Developer ID certificates, app-specific passwords, or Keychain profiles; use secrets/environment variables in CI.
