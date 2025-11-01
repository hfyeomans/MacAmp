# Research: MacAmp Distributable Build for /Applications Testing

**Date:** 2025-10-24
**Objective:** Create a distributable macOS application build that can be installed in /Applications folder for testing outside Xcode environment.

## Current State Analysis

### Project Configuration
- **App Name:** MacAmp (Winamp clone for macOS)
- **Bundle ID:** com.hankyeomans.MacAmp
- **Version:** 0.8 (Marketing) / 1 (Build)
- **Min macOS:** 15.0 (Sequoia)
- **Target macOS:** 26.0 (Tahoe)
- **Architecture:** arm64 (Apple Silicon primary)
- **Build System:** Xcode 26.0 + Swift Package Manager

### Current Build Locations

**Debug Build (Default):**
```
/Users/hank/Library/Developer/Xcode/DerivedData/MacAmpApp-bkmcccatuvhsmhbgrftfacnjoxld/Build/Products/Debug/MacAmp.app
```

**Local Build Directory:**
```
/Users/hank/dev/src/MacAmp/build/Debug/MacAmp.app
```
Note: This appears to be incomplete/unsigned based on codesign validation failure.

### Code Signing Status

**Available Certificates:**
1. Apple Development: Hank Yeomans (A5V7U473GS) - 3 instances
2. **Developer ID Application: Hank Yeomans (AC3LGVEJJ8)** ⭐

**Current Configuration:**
- Code Sign Style: Automatic
- Code Sign Identity: Apple Development
- Development Team: AC3LGVEJJ8
- Entitlements: MacAmpApp/MacAmp.entitlements

**Important Finding:** You have a **Developer ID Application** certificate, which is the gold standard for distribution outside the Mac App Store. This changes our strategy significantly.

### Dependencies

**Swift Package Manager:**
- ZIPFoundation 0.9.19 (for .wsz skin file handling)
- Embedded as framework/resources in app bundle

**Entitlements Required:**
- Audio output device access
- User-selected file access (read/write)
- Network client (streaming, downloads)
- Downloads folder access (read/write)

### Build Configurations

**Debug Build Settings:**
- Optimization: None (-Onone)
- Debug Symbols: Yes (DWARF)
- Strip Symbols: No
- Testability: Enabled
- Code Coverage: Yes
- Deployment Target: 15.0 (fallback)

**Release Build Settings:**
- Optimization: Aggressive (-O)
- Debug Symbols: No (production)
- Strip Symbols: Yes
- Testability: Disabled
- Code Coverage: No
- Deployment Target: 15.0

**Issue Discovered:** Release build currently fails with ZIPFoundation dependency resolution error:
```
error: Unable to find module dependency: 'ZIPFoundation'
error: lstat(/Users/hank/dev/src/MacAmp/dist/ZIPFoundation_ZIPFoundation.bundle): No such file or directory
```

## Distribution Methods Comparison

### Option 1: Direct Debug Build Copy (Simplest - Recommended for Testing)

**What it is:**
Copy the Debug build from DerivedData directly to /Applications.

**Pros:**
- ✅ Simplest approach - one command
- ✅ Preserves debugging symbols for crash analysis
- ✅ Already signed with Apple Development certificate
- ✅ Works immediately without additional configuration
- ✅ Fast iteration (build → copy → test)

**Cons:**
- ⚠️ Larger file size due to debug symbols
- ⚠️ Not optimized (slower performance)
- ⚠️ Cannot share with other testers (tied to your dev cert)
- ⚠️ Gatekeeper may complain on first launch (Control+Click to open)

**Use Case:** Local testing, quick iterations, debugging

**Implementation:**
```bash
# Build and copy in one step
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Debug
cp -R "/Users/hank/Library/Developer/Xcode/DerivedData/MacAmpApp-*/Build/Products/Debug/MacAmp.app" /Applications/
```

### Option 2: Release Build + Developer ID Signing (Recommended for Distribution)

**What it is:**
Build with Release configuration and sign with Developer ID Application certificate. Optionally notarize.

**Pros:**
- ✅ Optimized performance
- ✅ Smaller file size (stripped symbols)
- ✅ Signed with Developer ID - can share with testers
- ✅ No Gatekeeper warnings after notarization
- ✅ Professional distribution approach
- ✅ Resembles final App Store or direct distribution

**Cons:**
- ⚠️ Requires fixing Release build configuration first
- ⚠️ Notarization takes 5-15 minutes (optional for local testing)
- ⚠️ More complex build process
- ⚠️ Harder to debug crashes without symbols

**Use Case:** Beta testing, sharing with others, pre-release validation

**Implementation:**
```bash
# Fix Release build first, then:
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Release \
  CODE_SIGN_IDENTITY="Developer ID Application: Hank Yeomans (AC3LGVEJJ8)"

# Optional: Notarize
xcrun notarytool submit MacAmp.app --apple-id your@email.com --team-id AC3LGVEJJ8 --wait
xcrun stapler staple MacAmp.app

# Install
cp -R "path/to/MacAmp.app" /Applications/
```

### Option 3: Archive + Export (Over-engineered for Local Testing)

**What it is:**
Create an Xcode archive and export as Mac App or Developer ID package.

**Pros:**
- ✅ Most "proper" Xcode workflow
- ✅ Generates .xcarchive for version tracking
- ✅ Can create .pkg installer
- ✅ Integrated notarization workflow

**Cons:**
- ❌ Overkill for local testing
- ❌ Requires ExportOptions.plist configuration
- ❌ Slower workflow
- ❌ Two-step process (archive, then export)

**Use Case:** Final releases, App Store submission, enterprise deployment

**Implementation:**
```bash
# Archive
xcodebuild archive -project MacAmpApp.xcodeproj -scheme MacAmpApp \
  -archivePath ./archives/MacAmp.xcarchive

# Export
xcodebuild -exportArchive -archivePath ./archives/MacAmp.xcarchive \
  -exportPath ./dist -exportOptionsPlist ExportOptions.plist
```

### Option 4: Simple Install Script (Recommended Hybrid)

**What it is:**
A simple shell script that builds and copies to /Applications in one command.

**Pros:**
- ✅ One-command solution
- ✅ Can switch between Debug/Release easily
- ✅ Handles cleanup and validation
- ✅ Easy to share with team
- ✅ Can include pre-flight checks

**Cons:**
- ⚠️ Requires fixing Release build first (for Release mode)

**Use Case:** Regular testing workflow, team sharing

**Implementation:** See plan.md for full script

## Code Signing Requirements for /Applications Installation

### Gatekeeper Behavior

**macOS Security Model:**
1. **Unsigned Apps:** Gatekeeper blocks, requires right-click → Open
2. **Apple Development Signed:** Gatekeeper allows from terminal/script, may warn on first GUI launch
3. **Developer ID Signed:** Gatekeeper allows, no warnings
4. **Developer ID + Notarized:** Full trust, treated like App Store apps

### What You Need for Testing

**Minimum (Works Today):**
- Apple Development certificate ✅ (Already configured)
- App signed during Xcode build ✅ (Automatic)
- User must right-click → Open on first launch

**Recommended (Better UX):**
- Developer ID Application certificate ✅ (You have this!)
- Update CODE_SIGN_IDENTITY in project settings
- No right-click needed

**Optional (Best Experience):**
- Notarization via Apple notary service
- Requires Apple ID, app-specific password
- Eliminates all Gatekeeper warnings
- Takes 5-15 minutes per submission

### Entitlements Validation

Your current entitlements are **correct** for local testing:
- ✅ Audio output device access
- ✅ User-selected file access
- ✅ Network client access
- ✅ Downloads folder access
- ✅ Hardened Runtime disabled (good for development)

For production distribution, you would need:
- Enable Hardened Runtime
- Keep same entitlements
- Sign with Developer ID
- Notarize

## macOS App Bundle Structure Analysis

### Current Bundle Structure (Debug)

```
MacAmp.app/
├── Contents/
│   ├── Info.plist                    # Bundle metadata ✅
│   ├── PkgInfo                       # Creator code ✅
│   ├── MacOS/
│   │   └── MacAmp                    # Main executable ✅
│   ├── Resources/
│   │   ├── Assets.car                # Compiled asset catalog ✅
│   │   ├── ZIPFoundation_ZIPFoundation.bundle  # SPM dependency ✅
│   │   └── [Skin files]              # Bundled .wsz skins ✅
│   └── _CodeSignature/
│       └── CodeResources             # Signature manifest ✅
```

**Validation:** All required components present in Debug build.

### Potential Issues

1. **Frameworks Folder Missing:** ZIPFoundation is embedded as bundle, not framework
   - This is fine for SPM packages
   - No action needed

2. **Resource Embedding:** Skins and assets properly included
   - Verified in Package.swift resources section
   - ✅ Working correctly

3. **Code Signature:** Valid in Debug build
   - Authority: Apple Development
   - Team: AC3LGVEJJ8
   - Sealed Resources: 8 files
   - ✅ Properly signed

## Release Build Issue Investigation

### Problem

Release build fails with:
```
error: Unable to find module dependency: 'ZIPFoundation'
error: lstat(/Users/hank/dev/src/MacAmp/dist/ZIPFoundation_ZIPFoundation.bundle):
  No such file or directory
```

### Root Cause Analysis

The error references `/Users/hank/dev/src/MacAmp/dist/` which is NOT a standard Xcode build location. This suggests:

1. **Custom Build Path Override:** Project may have CONFIGURATION_BUILD_DIR set to `dist/` for Release
2. **Missing Directory:** The `dist/` folder doesn't exist or isn't properly configured
3. **SPM Integration Issue:** Release configuration may have different SPM settings

### Investigation Required

Check project.pbxproj for:
```bash
grep -A 5 "CONFIGURATION_BUILD_DIR" MacAmpApp.xcodeproj/project.pbxproj
grep -A 5 "Release" MacAmpApp.xcodeproj/project.pbxproj | grep -i build
```

### Potential Fixes

**Option A: Remove Custom Build Path**
- Remove CONFIGURATION_BUILD_DIR override for Release
- Let Xcode use standard DerivedData location

**Option B: Create Missing Directory**
```bash
mkdir -p /Users/hank/dev/src/MacAmp/dist
```

**Option C: Update Build Settings**
- Align Release configuration with Debug
- Ensure SPM dependencies resolve correctly

## Performance Considerations

### Debug vs. Release Build Sizes

**Estimated (based on typical SwiftUI apps):**
- Debug Build: ~20-30 MB (with symbols, unoptimized)
- Release Build: ~10-15 MB (stripped, optimized)

**MacAmp Specifics:**
- Bundled skins: ~2-3 MB (4 .wsz files)
- ZIPFoundation: ~500 KB
- SwiftUI frameworks: System-provided (not bundled)

### Build Time Comparison

**Debug:**
- Clean build: 15-30 seconds
- Incremental: 3-5 seconds

**Release:**
- Clean build: 30-60 seconds (optimizations)
- Incremental: 5-10 seconds

## Recommended Approach: Two-Track Strategy

### Track 1: Quick Testing (Immediate Use)

**Use Debug builds for rapid iteration:**

1. Build Debug configuration (already working)
2. Copy to /Applications
3. Launch and test
4. Accept larger file size and debug symbols

**Workflow:**
```bash
./install-debug.sh  # One command does everything
```

**Pros:** Available immediately, no configuration changes needed

### Track 2: Distribution Ready (Future Use)

**Fix Release build for beta testing:**

1. Investigate and fix Release build configuration
2. Update to use Developer ID certificate
3. Optional: Set up notarization
4. Create release script

**Workflow:**
```bash
./install-release.sh  # Builds, signs, and installs
```

**Pros:** Production-ready, shareable with testers

## Notarization Deep Dive (Optional)

### What is Notarization?

Apple's malware scanning service that:
- Scans your app for malicious code
- Validates code signature
- Issues a "ticket" that Gatekeeper trusts
- Required for distribution outside App Store (since macOS 10.15)

### Do You Need It for Testing?

**No, if:**
- ✅ Testing only on your Mac
- ✅ OK with right-click → Open first launch
- ✅ Using Debug builds with Apple Development certificate

**Yes, if:**
- Sharing with beta testers
- Want seamless UX (no warnings)
- Testing final distribution workflow
- Building Release versions for others

### Notarization Process

**Requirements:**
1. Developer ID Application certificate ✅ (You have this)
2. Apple ID with app-specific password
3. Hardened Runtime enabled
4. Secure timestamp enabled

**Steps:**
```bash
# 1. Build and sign with Developer ID
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp \
  -configuration Release \
  CODE_SIGN_IDENTITY="Developer ID Application: Hank Yeomans (AC3LGVEJJ8)"

# 2. Create a ZIP for notarization
ditto -c -k --keepParent MacAmp.app MacAmp.zip

# 3. Submit to Apple
xcrun notarytool submit MacAmp.zip \
  --apple-id your@email.com \
  --team-id AC3LGVEJJ8 \
  --password "app-specific-password" \
  --wait

# 4. Staple the ticket to the app
xcrun stapler staple MacAmp.app

# 5. Verify
spctl -a -vv MacAmp.app
```

**Time:** 5-15 minutes for Apple to scan and approve

### Setting Up Notarization

**One-time setup:**
```bash
# Store credentials in keychain
xcrun notarytool store-credentials "MacAmp-Notary" \
  --apple-id your@email.com \
  --team-id AC3LGVEJJ8
```

Then use:
```bash
xcrun notarytool submit MacAmp.zip --keychain-profile "MacAmp-Notary" --wait
```

## Best Practices Summary

### For Local Testing (Recommended Now)

1. **Use Debug builds** - already working, properly signed
2. **Simple copy to /Applications** - no complex workflows
3. **Accept first-launch warning** - one-time inconvenience
4. **Fast iteration** - build → copy → test in seconds

### For Beta Distribution (Future)

1. **Fix Release build** - investigate and resolve SPM issue
2. **Use Developer ID certificate** - you already have it
3. **Enable Hardened Runtime** - required for notarization
4. **Notarize** - eliminate all warnings for testers

### For Production (Final Release)

1. **Archive workflow** - proper version tracking
2. **Notarization** - required for distribution
3. **Create .dmg or .pkg** - professional installer
4. **Document update process** - Sparkle framework integration

## Technical Findings

### Code Signing Verification

**Current Debug Build:**
```
Authority=Apple Development: Hank Yeomans (A5V7U473GS)
Authority=Apple Worldwide Developer Relations Certification Authority
Authority=Apple Root CA
TeamIdentifier=AC3LGVEJJ8
Sealed Resources version=2 rules=13 files=8
```

**Status:** ✅ Valid for local use and testing

### Dependency Handling

**ZIPFoundation Integration:**
- Resolved via SPM
- Embedded as resource bundle (not framework)
- Works correctly in Debug builds
- Issue in Release builds needs investigation

### Framework Search Paths

**Debug Configuration:**
```
FRAMEWORK_SEARCH_PATHS = /Users/hank/Library/Developer/Xcode/DerivedData/MacAmpApp-*/Build/Products/Debug
LD_RUNPATH_SEARCH_PATHS = @executable_path/../Frameworks
```

**Working correctly** for Debug builds

## Next Steps (See plan.md)

1. Create simple install script for Debug builds (immediate use)
2. Investigate and fix Release build configuration
3. Update code signing to use Developer ID (optional)
4. Set up notarization workflow (optional)
5. Create comprehensive build documentation

## References

- [Apple Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Notarization Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Xcode Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [Swift Package Manager Integration](https://developer.apple.com/documentation/swift_packages)
