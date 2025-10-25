#!/bin/bash
#
# Quick Install Script for MacAmp Development
# Builds, signs (Debug), and installs to /Applications for fast testing
#
# Usage: ./scripts/quick-install.sh [Debug|Release]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration can be overridden via argument (default: Debug)
CONFIGURATION="${1:-Debug}"
SCHEME="MacAmpApp"
PROJECT_PATH="$REPO_ROOT/MacAmpApp.xcodeproj"
INSTALL_PATH="/Applications/MacAmp.app"

echo "=================================================="
echo "MacAmp Quick Install"
echo "=================================================="
echo "Configuration: $CONFIGURATION"
echo "Install Path: $INSTALL_PATH"
echo ""

# Step 1: Kill any running MacAmp instance
echo "1. Checking for running MacAmp instances..."
if pgrep -x "MacAmp" > /dev/null; then
    echo "   Found running MacAmp, terminating..."
    killall "MacAmp" || true
    sleep 1
else
    echo "   No running instances found"
fi

# Step 2: Build the app
echo ""
echo "2. Building MacAmp ($CONFIGURATION configuration)..."
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$REPO_ROOT/build" \
    build

BUILD_STATUS=$?
if [ $BUILD_STATUS -ne 0 ]; then
    echo "ERROR: Build failed with status $BUILD_STATUS"
    exit 1
fi

# Step 3: Locate the built app
echo ""
echo "3. Locating built app..."
BUILT_APP="$REPO_ROOT/build/Build/Products/$CONFIGURATION/MacAmp.app"

if [ ! -d "$BUILT_APP" ]; then
    echo "ERROR: Built app not found at: $BUILT_APP"
    exit 1
fi

echo "   Found: $BUILT_APP"

# Step 4: Verify code signature (if signed)
echo ""
echo "4. Verifying code signature..."
if codesign --verify --verbose "$BUILT_APP" 2>&1; then
    echo "   ✓ Code signature valid"
    codesign -dvvv "$BUILT_APP" 2>&1 | grep -E "(Identifier|Authority|Format)" | head -3
else
    echo "   ⚠ Warning: No code signature (okay for Debug builds)"
fi

# Step 5: Remove old installation
echo ""
echo "5. Removing old installation..."
if [ -d "$INSTALL_PATH" ]; then
    echo "   Removing: $INSTALL_PATH"
    sudo rm -rf "$INSTALL_PATH"
else
    echo "   No previous installation found"
fi

# Step 6: Copy new build to /Applications
echo ""
echo "6. Installing to /Applications..."
sudo ditto "$BUILT_APP" "$INSTALL_PATH"

if [ -d "$INSTALL_PATH" ]; then
    echo "   ✓ Installed: $INSTALL_PATH"
    ls -lh /Applications | grep MacAmp
else
    echo "ERROR: Installation failed"
    exit 1
fi

# Step 7: Fix permissions
echo ""
echo "7. Fixing permissions..."
sudo chown -R $(whoami):staff "$INSTALL_PATH"
sudo chmod -R u+w "$INSTALL_PATH"

# Step 8: Launch the app
echo ""
echo "8. Launching MacAmp..."
open "$INSTALL_PATH"

echo ""
echo "=================================================="
echo "✓ MacAmp Quick Install Complete!"
echo "=================================================="
echo ""
echo "App installed at: $INSTALL_PATH"
echo "Build configuration: $CONFIGURATION"
echo ""
echo "To rebuild and reinstall:"
echo "  ./scripts/quick-install.sh"
echo ""
echo "To build Release version:"
echo "  ./scripts/quick-install.sh Release"
echo ""
