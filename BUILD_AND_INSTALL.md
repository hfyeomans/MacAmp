# MacAmp - Build and Install Guide

Quick guide for building MacAmp and installing it to /Applications for testing.

---

## Quick Start (Testing Build)

### Option 1: Debug Build (Fastest)
```bash
# Build Debug configuration
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Debug build

# Copy to /Applications
cp -R ~/Library/Developer/Xcode/DerivedData/MacAmpApp-*/Build/Products/Debug/MacAmp.app /Applications/

# Launch
open /Applications/MacAmp.app
```

### Option 2: Release Build (Recommended for Testing)
```bash
# Build Release configuration (creates dist/MacAmp.app automatically)
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Release build

# Copy to /Applications
cp -R dist/MacAmp.app /Applications/

# Launch
open /Applications/MacAmp.app
```

---

## Release Build Details

**Signing:** Developer ID Application (Hank Yeomans)
**Output:** `/Users/hank/dev/src/MacAmp/dist/MacAmp.app`
**Features:**
- ✅ Optimized build (-O)
- ✅ Signed with Developer ID
- ✅ ZIPFoundation properly embedded
- ✅ All resources included
- ⏸️ Not notarized (required for public distribution)

**Build Time:** ~30-60 seconds (clean build)

---

## Using XcodeBuildMCP Tools (Recommended)

```bash
# Build Release
mcp__XcodeBuildMCP__build_macos({
  projectPath: "/Users/hank/dev/src/MacAmp/MacAmpApp.xcodeproj",
  scheme: "MacAmpApp",
  configuration: "Release"
})

# Get app path
mcp__XcodeBuildMCP__get_mac_app_path({
  projectPath: "/Users/hank/dev/src/MacAmp/MacAmpApp.xcodeproj",
  scheme: "MacAmpApp",
  configuration: "Release"
})

# Launch from /Applications
mcp__XcodeBuildMCP__launch_mac_app({
  appPath: "/Applications/MacAmp.app"
})
```

---

## Notarization (For Public Distribution)

### Prerequisites
1. **App-Specific Password:**
   - Go to appleid.apple.com
   - Generate app-specific password
   - Save securely

2. **Store Credentials** (one-time):
```bash
xcrun notarytool store-credentials "MacAmp-Notary" \
  --apple-id "your@email.com" \
  --team-id AC3LGVEJJ8 \
  --password "your-app-specific-password"
```

### Notarize Build

```bash
# 1. Create ZIP
cd dist
ditto -c -k --keepParent MacAmp.app MacAmp.zip

# 2. Submit for notarization
xcrun notarytool submit MacAmp.zip \
  --keychain-profile "MacAmp-Notary" \
  --wait

# 3. Staple ticket to app
xcrun stapler staple MacAmp.app

# 4. Verify
spctl -a -vv -t install MacAmp.app
```

**Expected output:**
```
MacAmp.app: accepted
source=Notarized Developer ID
```

---

## Verification Steps

### Check Code Signature
```bash
codesign -dvv /Applications/MacAmp.app
```

Should show:
- ✅ Authority: Developer ID Application: Hank Yeomans (AC3LGVEJJ8)
- ✅ TeamIdentifier: AC3LGVEJJ8
- ✅ Signature: valid

### Check Gatekeeper Status
```bash
spctl -a -vv /Applications/MacAmp.app
```

**Before notarization:**
```
MacAmp.app: rejected
source=Developer ID Application: Hank Yeomans (AC3LGVEJJ8)
```

**After notarization + stapling:**
```
MacAmp.app: accepted
source=Notarized Developer ID
```

### Check App Bundle
```bash
ls -lh /Applications/MacAmp.app/Contents/MacOS/MacAmp        # Executable
ls -la /Applications/MacAmp.app/Contents/Resources/          # Resources
ls -la /Applications/MacAmp.app/Contents/Info.plist         # Info.plist
```

---

## Troubleshooting

### "MacAmp is damaged and can't be opened"
**Cause:** Gatekeeper blocking unsigned or improperly signed app

**Fix:**
```bash
# Check quarantine flag
xattr -l /Applications/MacAmp.app

# Remove quarantine (testing only!)
xattr -dr com.apple.quarantine /Applications/MacAmp.app
```

### "Developer cannot be verified"
**Cause:** App not notarized

**Fix:** Follow notarization steps above

### App won't launch
```bash
# Check system logs
log show --predicate 'process == "MacAmp"' --info --debug --last 5m

# Verify signature
codesign --verify --deep --strict /Applications/MacAmp.app

# Check for errors
echo $?  # Should be 0 if signature valid
```

### Missing ZIPFoundation
**Cause:** Release build failed to embed SPM resources

**Fix:**
```bash
# Clean and rebuild
xcodebuild clean -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Release
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Release build

# Verify bundle exists
ls -la dist/MacAmp.app/Contents/Resources/ZIPFoundation_ZIPFoundation.bundle
```

---

## Distribution Checklist

**For Local Testing:**
- [x] Build Release configuration
- [x] Verify code signature
- [x] Copy to /Applications
- [x] Launch and test

**For Public Distribution:**
- [ ] Build Release
- [ ] Create ZIP
- [ ] Submit for notarization
- [ ] Wait for approval
- [ ] Staple ticket
- [ ] Verify with spctl
- [ ] Create DMG (optional)
- [ ] Upload to GitHub Releases / website

---

## Build Configurations

**Debug:**
- Optimization: None (-Onone)
- Code signing: Apple Development
- Output: DerivedData/Build/Products/Debug/
- Purpose: Xcode development and debugging

**Release:**
- Optimization: Whole Module (-O)
- Code signing: Developer ID Application
- Output: dist/MacAmp.app (auto-copied)
- Purpose: Distribution and /Applications testing

---

## Quick Commands Reference

```bash
# Build Release
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Release build

# Install to /Applications
cp -R dist/MacAmp.app /Applications/

# Launch
open /Applications/MacAmp.app

# Check signature
codesign -dvv /Applications/MacAmp.app

# Check size
du -sh /Applications/MacAmp.app

# View logs
log show --predicate 'process == "MacAmp"' --info --debug --last 1m
```

---

**Last Updated:** 2025-10-24
**macOS Target:** 15.0+ (Sequoia)
**Architecture:** arm64 (Apple Silicon)
