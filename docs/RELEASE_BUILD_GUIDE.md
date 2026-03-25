# MacAmp Release Build & Distribution Guide

> **Consolidated:** Merged content from `CODE_SIGNING_FIX.md`, `CODE_SIGNING_FIX_DIAGRAM.md`, and `RELEASE_BUILD_COMPARISON.md` (2026-03-25).

This guide covers building MacAmp for direct download distribution using Developer ID signing.

## Prerequisites

### 1. Apple Developer Account

You need an **Apple Developer Program** membership ($99/year) to:
- Obtain Developer ID certificates
- Notarize your app with Apple
- Distribute outside the Mac App Store

Sign up at: https://developer.apple.com/programs/

### 2. Build Toolchain

- **Swift 6.2** — the project uses `swift-tools-version: 6.2` and requires Xcode with Swift 6.2 support
- **XcodeGen** — the Xcode project (`MacAmpApp.xcodeproj`) is generated from `project.yml` and is gitignored. Install with `brew install xcodegen` (v2.38.0+). Run `xcodegen generate` before any build.

### 3. Developer ID Certificates

After enrolling, create your certificates:

1. Go to https://developer.apple.com/account/resources/certificates/list
2. Click the "+" button to create a new certificate
3. Select **Developer ID Application** (for signing apps)
4. Follow the wizard to generate a Certificate Signing Request (CSR) from Keychain Access
5. Download and install the certificate in your Keychain

### 3. Xcode Configuration

In Xcode, configure your project:

1. Run `xcodegen generate` (generates xcodeproj from `project.yml`)
2. Open `MacAmpApp.xcodeproj`
3. Select the **MacAmp** target
3. Go to **Signing & Capabilities** tab
4. Set **Team** to your Apple Developer Team
5. Set **Signing Certificate** to "Developer ID Application"
6. Add the **MacAmp.entitlements** file (already created in `MacAmpApp/MacAmp.entitlements`)

#### Manual Project Settings (if needed)

If Xcode doesn't auto-configure, set these build settings manually:

**For Release configuration:**
```
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = "Developer ID Application: Your Name (TEAM_ID)"
DEVELOPMENT_TEAM = YOUR_TEAM_ID
CODE_SIGN_ENTITLEMENTS = MacAmpApp/MacAmp.entitlements
ENABLE_HARDENED_RUNTIME = YES
```

## Building a Release Build

### Method 1: Archive in Xcode (Recommended)

1. **Select Release Scheme:**
   - Product → Scheme → Edit Scheme
   - Set "Run" to use "Release" configuration

2. **Archive the App:**
   - Product → Archive (Cmd+Shift+B)
   - Wait for build to complete
   - Organizer window will open

3. **Export the App:**
   - Click **Distribute App**
   - Choose **Developer ID**
   - Select **Export** (not Upload)
   - Choose destination folder
   - Click **Export**

This creates a signed, notarization-ready `.app` bundle.

### Method 2: Command Line Build

```bash
# Generate Xcode project (required — xcodeproj is gitignored)
xcodegen generate

# Clean previous builds
xcodebuild clean -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Release

# Build for release
xcodebuild archive \
  -project MacAmpApp.xcodeproj \
  -scheme MacAmpApp \
  -configuration Release \
  -archivePath ./build/MacAmp.xcarchive

# Export the archive
xcodebuild -exportArchive \
  -archivePath ./build/MacAmp.xcarchive \
  -exportPath ./build/Release \
  -exportOptionsPlist ExportOptions.plist
```

Create `ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
```

## Notarization

**Required for macOS 15+**. Users cannot run your app without notarization.

### Step 1: Create App-Specific Password

1. Go to https://appleid.apple.com
2. Sign in with your Apple ID
3. Go to **Security** → **App-Specific Passwords**
4. Click **Generate Password**
5. Name it "MacAmp Notarization"
6. Save the generated password

### Step 2: Store Credentials

```bash
# Store your credentials in Keychain (one-time setup)
xcrun notarytool store-credentials "MacAmp-Notary" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

Replace:
- `your-apple-id@example.com` with your Apple ID
- `YOUR_TEAM_ID` with your 10-character Team ID
- `xxxx-xxxx-xxxx-xxxx` with the app-specific password

### Step 3: Submit for Notarization

```bash
# Create a ZIP of your app
cd build/Release
ditto -c -k --keepParent MacAmpApp.app MacAmpApp.zip

# Submit to Apple
xcrun notarytool submit MacAmpApp.zip \
  --keychain-profile "MacAmp-Notary" \
  --wait

# This will return a submission ID like:
# Successfully received submission info
#   id: 12345678-1234-1234-1234-123456789012
#   status: Accepted
```

The `--wait` flag makes it wait for results (usually 2-5 minutes).

### Step 4: Check Status (if not using --wait)

```bash
# Check notarization status
xcrun notarytool info SUBMISSION_ID \
  --keychain-profile "MacAmp-Notary"

# View logs if rejected
xcrun notarytool log SUBMISSION_ID \
  --keychain-profile "MacAmp-Notary"
```

### Step 5: Staple the Ticket

Once accepted, staple the notarization ticket to your app:

```bash
# Staple to the app bundle
xcrun stapler staple MacAmpApp.app

# Verify stapling
xcrun stapler validate MacAmpApp.app
```

## Creating a DMG for Distribution

Users expect a `.dmg` file for macOS apps. Here's how to create one:

### Option 1: Quick DMG

```bash
# Create a simple DMG
hdiutil create -volname "MacAmp" \
  -srcfolder build/Release/MacAmpApp.app \
  -ov -format UDZO \
  MacAmp-0.1.0.dmg

# Notarize the DMG too
xcrun notarytool submit MacAmp-0.1.0.dmg \
  --keychain-profile "MacAmp-Notary" \
  --wait

# Staple to DMG
xcrun stapler staple MacAmp-0.1.0.dmg
```

### Option 2: Custom DMG with Background

For a professional installer with custom background:

1. Create a folder with your app and an Applications symlink
2. Add a custom background image
3. Use tools like:
   - [create-dmg](https://github.com/create-dmg/create-dmg)
   - [node-appdmg](https://github.com/LinusU/node-appdmg)

Example with `create-dmg`:
```bash
brew install create-dmg

create-dmg \
  --volname "MacAmp Installer" \
  --volicon "MacAmpApp/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "MacAmpApp.app" 200 190 \
  --hide-extension "MacAmpApp.app" \
  --app-drop-link 600 185 \
  "MacAmp-0.1.0.dmg" \
  "build/Release/"
```

Then notarize and staple the DMG as shown above.

## Verification

Before distributing, verify your app works:

### 1. Check Code Signature

```bash
codesign --verify --deep --strict --verbose=2 MacAmpApp.app
codesign -dv --verbose=4 MacAmpApp.app
```

Should show:
- `Developer ID Application: Your Name (TEAM_ID)`
- `Sealed Resources version 2 rules`
- `signed app bundle with Mach-O universal (x86_64 arm64)`

### 2. Check Hardened Runtime

```bash
codesign -d --entitlements - MacAmpApp.app
```

Should show your entitlements from `MacAmp.entitlements`.

### 3. Check Notarization

```bash
spctl --assess --verbose=4 --type execute MacAmpApp.app
```

Should show: `MacAmpApp.app: accepted`

### 4. Test on Clean Mac

Best practice:
1. Copy the DMG to a USB drive
2. Test on a Mac that has **never** run this app
3. Double-click the DMG and drag to Applications
4. Launch from Applications folder
5. Verify no "unidentified developer" warnings

## Distribution Checklist

Before releasing:

- [ ] Bundle ID set to `com.hankyeomans.MacAmp`
- [ ] Version number updated in Info.plist
- [ ] Build number incremented
- [ ] App signed with Developer ID certificate
- [ ] Hardened Runtime enabled
- [ ] Entitlements file included
- [ ] App notarized with Apple
- [ ] Notarization ticket stapled
- [ ] DMG created and notarized
- [ ] DMG stapled
- [ ] Tested on clean macOS 15+ system
- [ ] Release notes written
- [ ] README.md updated with download link

## Troubleshooting

### "App is damaged and can't be opened"

**Cause:** Missing notarization or quarantine attribute issues.

**Fix:**
```bash
# Check notarization
spctl --assess --verbose MacAmpApp.app

# If testing unsigned build, remove quarantine
xattr -cr MacAmpApp.app
```

### "Developer cannot be verified"

**Cause:** App not notarized or notarization ticket not stapled.

**Fix:**
- Re-run notarization process
- Ensure stapling succeeded
- Check with `stapler validate`

### Notarization Rejected

**Cause:** Common issues include:
- Hardened Runtime not enabled
- Invalid entitlements
- Unsigned frameworks or plugins

**Fix:**
```bash
# Get detailed logs
xcrun notarytool log SUBMISSION_ID \
  --keychain-profile "MacAmp-Notary" \
  notarization-log.json

# Review the JSON for specific issues
cat notarization-log.json
```

### Certificate Not Found

**Cause:** Developer ID certificate not installed.

**Fix:**
1. Open **Keychain Access**
2. Check **login** keychain for "Developer ID Application"
3. If missing, re-download from developer.apple.com
4. Ensure certificate is valid and not expired

## Automated Release Script

Create `scripts/release.sh`:

```bash
#!/bin/bash
set -e

VERSION="0.1.0"
APP_NAME="MacAmpApp"
BUNDLE_ID="com.hankyeomans.MacAmp"
TEAM_ID="YOUR_TEAM_ID"
NOTARY_PROFILE="MacAmp-Notary"

echo "Building MacAmp v${VERSION}..."

# Clean and build
xcodebuild clean -project MacAmpApp.xcodeproj -scheme ${APP_NAME}
xcodebuild archive \
  -project MacAmpApp.xcodeproj \
  -scheme ${APP_NAME} \
  -configuration Release \
  -archivePath ./build/${APP_NAME}.xcarchive

# Export
xcodebuild -exportArchive \
  -archivePath ./build/${APP_NAME}.xcarchive \
  -exportPath ./build/Release \
  -exportOptionsPlist ExportOptions.plist

# Verify signature
codesign --verify --deep --strict ./build/Release/${APP_NAME}.app
echo "✅ Code signature verified"

# Notarize
echo "Submitting for notarization..."
cd build/Release
ditto -c -k --keepParent ${APP_NAME}.app ${APP_NAME}.zip

xcrun notarytool submit ${APP_NAME}.zip \
  --keychain-profile "${NOTARY_PROFILE}" \
  --wait

# Staple
xcrun stapler staple ${APP_NAME}.app
echo "✅ Notarization ticket stapled"

# Create DMG
cd ../..
hdiutil create -volname "MacAmp" \
  -srcfolder build/Release/${APP_NAME}.app \
  -ov -format UDZO \
  MacAmp-${VERSION}.dmg

# Notarize DMG
xcrun notarytool submit MacAmp-${VERSION}.dmg \
  --keychain-profile "${NOTARY_PROFILE}" \
  --wait

# Staple DMG
xcrun stapler staple MacAmp-${VERSION}.dmg
echo "✅ DMG notarized and stapled"

echo "🎉 Release build complete: MacAmp-${VERSION}.dmg"
```

Make executable and run:
```bash
chmod +x scripts/release.sh
./scripts/release.sh
```

## Updating Versions

Before each release, update:

1. **Info.plist** - `CFBundleShortVersionString` (e.g., "0.2.0")
2. **Info.plist** - `CFBundleVersion` (e.g., "2")
3. **README.md** - Version references
4. **Release notes** - Document changes

## Resources

- [Apple Developer Documentation - Notarization](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Apple Developer - Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [TN3127: Inside Code Signing](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-provisioning-profiles)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)

## Next Steps

1. **Set up CI/CD** - Automate builds with GitHub Actions
2. **Update mechanisms** - Implement Sparkle framework for auto-updates
3. **Crash reporting** - Add Sentry or similar for production monitoring
4. **Analytics** - Track usage patterns (respecting privacy)

---

## Code Signing Troubleshooting

### P0 Bug: Unsigned App in dist/ (Commit 6a80a97)

The Release build script was copying `MacAmp.app` to `dist/` BEFORE Xcode's code signing phase completed, resulting in an unsigned app in the distribution directory.

**Root Cause:** Xcode build phase execution order places `CodeSign` AFTER custom Run Script phases. The "Copy to dist" script was running before signing.

**Fix:** Moved distribution copy from a Build Phase Script to a **Scheme Post-Action**, which runs AFTER all build phases including CodeSign.

```
Before (BROKEN):  Build → Copy → Sign   (dist/ gets unsigned app)
After  (WORKING): Build → Sign → Copy → Verify  (dist/ gets signed app)
```

The post-action script automatically verifies the signature and fails the build if invalid.

### Alternatives Considered

| Option | Why Not Used |
|--------|-------------|
| Move script to end of Build Phases | Xcode controls order; scripts may still run before CodeSign |
| Manual re-sign in script | Redundant signing; script signature may differ from Xcode's |
| Use xcodebuild archive | Good for production but overkill for quick development builds |

### Debug vs Release Signing Configuration

```
CODE_SIGN_IDENTITY = "Apple Development"
CODE_SIGN_IDENTITY[sdk=macosx*] = "Developer ID Application"
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM[sdk=macosx*] = AC3LGVEJJ8
```

- **Debug builds**: "Apple Development" with automatic signing
- **Release builds**: "Developer ID Application" for distribution outside Mac App Store

### Additional Troubleshooting

#### "CODE_SIGN_IDENTITY not found"
Ensure Developer ID certificate is installed in Keychain Access:
```bash
security find-identity -v -p codesigning
```

#### Post-action not running
1. Product -> Scheme -> Edit Scheme...
2. Build -> Post-actions -> Verify script is present
3. Ensure "Provide build settings from: MacAmp" is selected

#### Signature verification fails
1. Check certificate validity: `security find-identity -v -p codesigning`
2. Ensure certificate is not expired
3. Verify Team ID matches in project settings

#### Verification script
```bash
./scripts/verify-dist-signature.sh
```

---

## Code Signing Flow Diagram

### Build Phase Execution Order (After Fix)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Xcode Build Process (Release)                 │
└─────────────────────────────────────────────────────────────────┘

Step 1: Compile Sources
┌─────────────────┐
│  Swift Files    │  →  Compile  →  Object Files
└─────────────────┘

Step 2: Copy Resources
┌─────────────────┐
│  Assets, WSZ    │  →  Copy  →  Build Directory
└─────────────────┘

Step 3: Link & Embed Frameworks
┌─────────────────┐
│  ZIPFoundation  │  →  Link  →  MacAmp.app (unsigned)
└─────────────────┘

Step 4: CodeSign
┌─────────────────────────────────────────────────────────────┐
│  codesign -s "Developer ID Application" MacAmp.app          │
└─────────────────────────────────────────────────────────────┘
         │
         v
Step 5: POST-ACTION "Copy signed app to dist"
┌─────────────────────────────────────────────────────────────┐
│  Copy signed app → Verify signature → Fail if invalid       │
└─────────────────────────────────────────────────────────────┘
```

### Signature Verification Flow

```
codesign --verify --deep --strict dist/MacAmp.app
    │
    ├─ Exit code 0 → Signature valid → Display authority chain → Build succeeds
    │
    └─ Exit code 1+ → Signature INVALID → Display error → Fail build (exit 1)
        Possible causes: expired cert, revoked cert, entitlements mismatch,
        unsigned embedded framework, resource modified after signing
```

### Certificate Chain

```
dist/MacAmp.app
    └── Code Signature
            ├── Identifier: com.hankyeomans.MacAmp
            ├── Format: Mach-O thin (arm64)
            ├── Authority Chain:
            │       ├── Developer ID Application: Hank Yeomans (AC3LGVEJJ8)
            │       ├── Developer ID Certification Authority
            │       └── Apple Root CA
            ├── Team Identifier: AC3LGVEJJ8
            └── Entitlements: MacAmp.entitlements
```

### Summary Comparison

| Aspect | Before Fix | After Fix |
|--------|-----------|-----------|
| **Copy Timing** | Before CodeSign | After CodeSign |
| **Signature Status** | Unsigned | Signed |
| **Verification** | None | Automatic |
| **Error Detection** | Silent failure | Build fails |
| **Notarization** | Impossible | Ready |
| **Build Time** | ~15s | ~16s (+1s) |

---

## Debug vs Release Configuration

> **Note (2026-03-25):** This section consolidated from `RELEASE_BUILD_COMPARISON.md`. The Swift 6 migration is complete (Swift 6.2 with strict concurrency). Verify build settings match current `project.yml` if discrepancies arise.

### Build Phase Order Comparison

**Release Build (current):**
```
1. Sources          ← Compile Swift files
2. Resources        ← Copy resources
3. Frameworks       ← Embed frameworks
4. CodeSign         ← Sign app in DerivedData
5. Post-Action      ← Copy SIGNED app to dist/ + verify
```

### Testing a Release Build

```bash
# Build Release
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Release build

# Verify signature
codesign --verify --deep --strict --verbose=2 dist/MacAmp.app

# Display signature details
codesign -dvvv dist/MacAmp.app

# Run standalone verification
./scripts/verify-dist-signature.sh
```

### Performance Impact

| Metric | Debug | Release | Notes |
|--------|-------|---------|-------|
| Build Time | ~10s | ~16s | +signing +verification |
| Code Signing | Apple Development | Developer ID Application | Manual for Release |
| Signature Verification | None | Automatic (post-action) | +1s overhead |
| Notarization Ready | No | Yes | Required for distribution |
| Hardened Runtime | Optional | Required | Enabled in Release config |

### Distribution Checklist (Post-Fix)

- [x] Build Release (automatic signing + verification)
- [x] App in dist/ is SIGNED and VERIFIED
- [ ] Notarize (standard workflow, see Notarization section above)
- [ ] Staple notarization ticket
- [ ] Create DMG (see DMG section above)
- [ ] Distribute

---

**Important:** Never share your:
- Developer ID certificates
- App-specific passwords
- Team ID (unless publicly distributing)
- Keychain profiles

Store these securely and use environment variables in CI/CD pipelines.
