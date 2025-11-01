# Code Signing Fix: Release Build Distribution

## Problem Summary

**Critical P0 Bug (Commit: 6a80a97)**

The Release build script was copying `MacAmp.app` to `dist/` BEFORE Xcode's code signing phase completed, resulting in an unsigned app bundle in the distribution directory. This prevented proper notarization and distribution.

### Root Cause

Xcode build phase execution order:
1. Compile Sources
2. Copy Resources
3. Link Binary
4. Embed Frameworks
5. **Run Script Phases** ← Old script ran here (BEFORE signing)
6. **CodeSign** ← Signing happens here
7. Done

The shell script build phase "Copy to dist" was copying the app before step 6 completed.

## Solution Implemented

**Option 1: Scheme Post-Action (BEST for macOS 15+/Xcode 26)**

Moved the distribution copy logic from a Build Phase Script to a Scheme Post-Action, which runs AFTER all build phases including CodeSign.

### Changes Made

#### 1. Added Scheme Post-Action
**File:** `MacAmpApp.xcodeproj/xcshareddata/xcschemes/MacAmpApp.xcscheme`

Added `<PostActions>` section to the `<BuildAction>` that:
- Runs ONLY for Release builds
- Copies the signed app to `dist/`
- Verifies the code signature with `codesign --verify --deep --strict`
- Displays signature authority chain
- Fails the build if signature verification fails

#### 2. Removed Old Build Phase Script
**File:** `MacAmpApp.xcodeproj/project.pbxproj`

Removed:
- Build phase reference: `A1B2C3D4E5F6789012345678 /* Copy to dist */`
- Entire `PBXShellScriptBuildPhase` section for "Copy to dist"

### Verification

The post-action script automatically verifies the signature during every Release build:

```bash
[Post-Action] Copying signed app to dist/
[Post-Action] Verifying code signature...
/Users/hank/dev/src/MacAmp/dist/MacAmp.app: valid on disk
/Users/hank/dev/src/MacAmp/dist/MacAmp.app: satisfies its Designated Requirement
[Post-Action] ✓ Code signature verified successfully
Authority=Developer ID Application: Hank Yeomans (AC3LGVEJJ8)
Authority=Developer ID Certification Authority
Authority=Apple Root CA
[Post-Action] Copy completed successfully
```

## Testing

### Manual Verification

Run the verification script:

```bash
./scripts/verify-dist-signature.sh
```

Expected output:
```
==================================================
SUCCESS: dist/MacAmp.app is properly signed!
==================================================
```

### Command Line Verification

```bash
# Build Release
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Release build

# Verify signature
codesign --verify --deep --strict --verbose=2 dist/MacAmp.app

# Display signature details
codesign -dvvv dist/MacAmp.app
```

## Why This Solution is Best

### Advantages of Scheme Post-Action

1. **Guaranteed Execution Order**: Post-actions run AFTER all build phases including CodeSign
2. **Clean Separation**: Keeps distribution logic separate from build phases
3. **Predictable**: Xcode guarantees post-actions run after build completion
4. **Maintainable**: Easy to understand and modify in Xcode UI (Edit Scheme → Build → Post-actions)
5. **Self-Verifying**: Includes automatic signature verification
6. **Fail-Fast**: Build fails immediately if signature is invalid

### Alternatives Considered (Why Not Used)

#### Option 2: Move Script to End of Build Phases
- **Problem**: Xcode controls build phase order; scripts may still run before CodeSign
- **Risk**: Not guaranteed to work across Xcode versions

#### Option 3: Manual Re-Sign in Script
- **Problem**: Redundant signing, increases build time
- **Risk**: Script signature may differ from Xcode's signature

#### Option 4: Use xcodebuild archive
- **Problem**: Requires workflow changes, more complex for quick builds
- **Benefit**: Good for production but overkill for development builds

## Code Signing Configuration

Current Release configuration (`project.pbxproj`):

```
CODE_SIGN_IDENTITY = "Apple Development"
CODE_SIGN_IDENTITY[sdk=macosx*] = "Developer ID Application"
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM[sdk=macosx*] = AC3LGVEJJ8
```

- **Debug builds**: Use "Apple Development" with automatic signing
- **Release builds**: Use "Developer ID Application" for distribution outside Mac App Store
- **Team**: AC3LGVEJJ8 (Hank Yeomans)

## Distribution Workflow

### For Public Distribution

1. **Build Release**
   ```bash
   xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Release build
   ```

2. **Verify Signature** (automatic in post-action, but double-check)
   ```bash
   ./scripts/verify-dist-signature.sh
   ```

3. **Notarize** (required for macOS 15+)
   ```bash
   # Create distributable archive
   ditto -c -k --keepParent dist/MacAmp.app dist/MacAmp.app.zip

   # Submit for notarization
   xcrun notarytool submit dist/MacAmp.app.zip \
     --keychain-profile "AC3LGVEJJ8" \
     --wait

   # Staple notarization ticket
   xcrun stapler staple dist/MacAmp.app
   ```

4. **Verify Notarization**
   ```bash
   spctl -a -vv dist/MacAmp.app
   ```

5. **Distribute**
   - Create final ZIP: `ditto -c -k --keepParent dist/MacAmp.app MacAmp-0.8.zip`
   - Upload to website or distribution platform

## Troubleshooting

### Issue: "CODE_SIGN_IDENTITY not found"
**Solution**: Ensure Developer ID certificate is installed in Keychain Access

### Issue: Post-action not running
**Solution**:
1. Open Xcode
2. Product → Scheme → Edit Scheme...
3. Build → Post-actions → Verify script is present
4. Ensure "Provide build settings from: MacAmp" is selected

### Issue: Signature verification fails
**Solution**:
1. Check certificate validity: `security find-identity -v -p codesigning`
2. Ensure certificate is not expired
3. Verify Team ID matches: `AC3LGVEJJ8`

## References

- [Apple Code Signing Guide](https://developer.apple.com/documentation/xcode/code-signing-guide)
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Xcode Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference)

## Commit Information

- **Fix Commit**: [To be added]
- **Bug Introduced**: 6a80a97
- **Affected File**: `MacAmpApp.xcodeproj/project.pbxproj` (lines 353-359)
- **Fix Date**: October 24, 2025
- **Tested On**: macOS 15.0, Xcode 26.0
