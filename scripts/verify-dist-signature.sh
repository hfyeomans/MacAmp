#!/bin/bash

# Verification script for dist/MacAmp.app code signature
# This ensures the distributed app is properly signed for notarization

set -e

# Get the repository root (parent of scripts directory)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Allow override via command-line argument or environment variable
DIST_APP="${1:-${DIST_APP:-$REPO_ROOT/dist/MacAmp.app}}"

echo "=================================================="
echo "MacAmp Distribution Signature Verification"
echo "=================================================="
echo ""

if [ ! -d "$DIST_APP" ]; then
    echo "ERROR: $DIST_APP does not exist"
    echo ""
    echo "Usage: $0 [path-to-MacAmp.app]"
    echo ""
    echo "If no path is provided, defaults to: \$REPO_ROOT/dist/MacAmp.app"
    echo "You can also set DIST_APP environment variable"
    echo ""
    echo "To build the distribution app, run:"
    echo "  xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Release build"
    exit 1
fi

echo "1. Checking if app bundle exists..."
ls -lh "$DIST_APP"
echo ""

echo "2. Verifying code signature (deep, strict)..."
codesign --verify --deep --strict --verbose=2 "$DIST_APP" 2>&1
VERIFY_RESULT=$?
echo ""

if [ $VERIFY_RESULT -ne 0 ]; then
    echo "ERROR: Code signature verification failed!"
    exit 1
fi

echo "3. Displaying signature details..."
codesign -dvvv "$DIST_APP" 2>&1 | grep -E "(Identifier|Authority|TeamIdentifier|Format|Signed Time)"
echo ""

echo "4. Checking for hardened runtime..."
codesign -dvvv "$DIST_APP" 2>&1 | grep -i runtime || echo "Note: Hardened runtime not enabled (optional)"
echo ""

echo "5. Verifying all embedded frameworks and resources..."
codesign -dvvv --deep "$DIST_APP" 2>&1 | grep -E "(Sealed Resources|rules|files)"
echo ""

echo "=================================================="
echo "SUCCESS: dist/MacAmp.app is properly signed!"
echo "=================================================="
echo ""
echo "Next steps for distribution:"
echo "  1. Notarize: xcrun notarytool submit dist/MacAmp.app.zip ..."
echo "  2. Staple: xcrun stapler staple dist/MacAmp.app"
echo "  3. Distribute: Upload to website or App Store"
echo ""
