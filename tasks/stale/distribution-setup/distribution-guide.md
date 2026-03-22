# MacAmp Distribution Setup Guide

## Current Status ✅

- **Paid Apple Developer Account**: Active (Team ID: AC3LGVEJJ8)
- **Automatic Signing**: Enabled in Xcode
- **Entitlements**: Configured with required permissions
- **Current Certificate**: Apple Development (testing only)

## Distribution Strategy

### Phase 1: Independent Distribution (Now → First Public Release)
Use **Developer ID Application** certificate for distribution outside Mac App Store.

### Phase 2: Mac App Store (Future)
Submit to App Store using **Apple Distribution** certificate.

---

## Phase 1: Independent Distribution Setup

### Step 1: Get Developer ID Application Certificate

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/certificates/list)
2. Click **+** to create a new certificate
3. Select **Developer ID Application** (under "Distribution")
4. Follow the prompts to generate a Certificate Signing Request (CSR)
5. Download and double-click the certificate to install in Keychain

**Verify Installation:**
```bash
security find-identity -v -p codesigning
```

You should see:
- "Apple Development: ..." (current)
- "Developer ID Application: ..." (new - for distribution)

### Step 2: Configure Xcode for Distribution

You have two options:

#### Option A: Manual Signing for Release Builds
1. Open Xcode project settings
2. Select **MacAmpApp** target
3. Go to **Signing & Capabilities** tab
4. For **Release** configuration:
   - Uncheck "Automatically manage signing"
   - Select "Developer ID Application" certificate
   - Keep provisioning profile as "None" (not needed for macOS)

#### Option B: Dual Configuration (Recommended)
Keep automatic signing for Debug, use Developer ID for Release.

Current entitlements include:
- ✅ Audio output access
- ✅ Network client (streaming, downloads)
- ✅ User-selected file access (music files)
- ✅ Downloads folder access (skin downloads)
- ✅ Hardened Runtime enabled

### Step 3: Build for Distribution

```bash
# Archive the app
xcodebuild archive \
  -project MacAmpApp.xcodeproj \
  -scheme MacAmpApp \
  -configuration Release \
  -archivePath ~/Desktop/MacAmp.xcarchive

# Export the app
xcodebuild -exportArchive \
  -archivePath ~/Desktop/MacAmp.xcarchive \
  -exportPath ~/Desktop/MacAmp-Export \
  -exportOptionsPlist ExportOptions.plist
```

You'll need to create `ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>AC3LGVEJJ8</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

### Step 4: Notarization (REQUIRED for macOS 10.15+)

Without notarization, users will see: *"MacAmp.app cannot be opened because the developer cannot be verified"*

#### Notarize the App:

```bash
# 1. Create a ZIP of your app
cd ~/Desktop/MacAmp-Export
ditto -c -k --keepParent MacAmp.app MacAmp.zip

# 2. Upload to Apple for notarization
xcrun notarytool submit MacAmp.zip \
  --apple-id "your-apple-id@email.com" \
  --team-id AC3LGVEJJ8 \
  --password "app-specific-password" \
  --wait

# 3. Staple the notarization ticket to your app
xcrun stapler staple MacAmp.app

# 4. Verify it worked
spctl -a -vv -t install MacAmp.app
```

**App-Specific Password Setup:**
1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in
3. Security → App-Specific Passwords
4. Generate a new password for "notarytool"
5. Save it securely (you'll use it in the command above)

**Pro Tip:** Store credentials in Keychain:
```bash
xcrun notarytool store-credentials "MacAmp-Notary" \
  --apple-id "your-apple-id@email.com" \
  --team-id AC3LGVEJJ8 \
  --password "app-specific-password"

# Then use:
xcrun notarytool submit MacAmp.zip --keychain-profile "MacAmp-Notary" --wait
```

### Step 5: Create DMG for Distribution

```bash
# Install create-dmg (if not already installed)
brew install create-dmg

# Create a nice DMG
create-dmg \
  --volname "MacAmp Installer" \
  --volicon "MacAmpApp/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "MacAmp.app" 200 190 \
  --hide-extension "MacAmp.app" \
  --app-drop-link 600 185 \
  "MacAmp-v1.0.0.dmg" \
  "MacAmp.app"
```

### Step 6: Distribute!

Now you can distribute `MacAmp-v1.0.0.dmg` via:
- Your website
- GitHub Releases
- Direct download links

Users can drag MacAmp.app to Applications and run it without security warnings! 🎉

---

## Phase 2: Mac App Store Preparation

When you're ready for the App Store:

### Additional Requirements:

1. **App Store Certificate**
   - Get "Apple Distribution" certificate (different from Developer ID)
   - Use in App Store builds

2. **App Sandbox** (REQUIRED for App Store)
   - Add to entitlements:
     ```xml
     <key>com.apple.security.app-sandbox</key>
     <true/>
     ```
   - Remove `com.apple.security.files.downloads.read-write` (sandbox restricts this)
   - Use File Bookmarks for persistent access

3. **App Store Connect Setup**
   - Create App ID
   - Create App Store listing
   - Add screenshots, description, keywords
   - Set pricing (Free or Paid)

4. **Export for App Store**
   ```xml
   <!-- In ExportOptions.plist -->
   <key>method</key>
   <string>app-store</string>
   ```

5. **Upload to App Store Connect**
   ```bash
   xcrun altool --upload-app \
     -f MacAmp.pkg \
     -u your-apple-id@email.com \
     -p app-specific-password
   ```

6. **App Review**
   - Expect 1-3 business days for review
   - Be ready to respond to reviewer questions
   - May need to demonstrate features

---

## Troubleshooting

**"The application is not signed correctly"**
- Check certificate is valid: `security find-identity -v -p codesigning`
- Verify hardened runtime: `codesign --display --verbose MacAmp.app`

**"Unable to notarize"**
- Check notarization log: `xcrun notarytool log <submission-id> --keychain-profile MacAmp-Notary`
- Common issues: Missing entitlements, unsigned frameworks

**Users still see warning**
- Did you staple? `xcrun stapler staple MacAmp.app`
- Verify: `spctl -a -vv -t install MacAmp.app`

**App crashes on other Macs**
- Check architecture: `lipo -info MacAmp.app/Contents/MacOS/MacAmp`
- Should show: `arm64 x86_64` (universal binary)

---

## Resources

- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
