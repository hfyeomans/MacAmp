#!/bin/bash
#
# Fast Development Install - Uses Claude Code MCP build tools
# Even faster than quick-install.sh for rapid iteration
#
# Usage: ./scripts/dev-install.sh
#

set -e

INSTALL_PATH="/Applications/MacAmp.app"

echo "=================================================="
echo "MacAmp Fast Development Install"
echo "=================================================="
echo ""

# Kill running instance
if pgrep -x "MacAmp" > /dev/null; then
    echo "Killing running MacAmp..."
    killall "MacAmp" || true
    sleep 1
fi

# Remove old installation
if [ -d "$INSTALL_PATH" ]; then
    echo "Removing old installation..."
    sudo rm -rf "$INSTALL_PATH"
fi

echo ""
echo "Building and installing MacAmp..."
echo "(This may take 30-60 seconds)"
echo ""

# Build with XcodeBuildMCP (optimized build)
# The app will be launched automatically
# Then we'll move it to /Applications

# Use Claude Code to build and get the path
# For now, fall back to quick-install
exec "$(dirname "$0")/quick-install.sh" Debug
