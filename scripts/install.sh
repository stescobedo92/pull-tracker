#!/bin/bash
# PRTracker Automatic Installation Script
# Downloads the latest version and installs it removing quarantine restrictions

set -e

echo "🚀 PR Tracker - Automatic Installation Script"
echo "=============================================="
echo ""

# Verify we're running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: This script only works on macOS"
    exit 1
fi

# Get the latest version from GitHub
echo "📥 Fetching latest version..."
LATEST_URL=$(curl -s https://api.github.com/repos/stescobedo92/pull-tracker/releases/latest | grep "browser_download_url.*dmg" | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
    echo "❌ Error: Could not retrieve download URL"
    exit 1
fi

# Download the DMG
DMG_FILE="/tmp/PRTracker.dmg"
echo "⬇️  Downloading from: $LATEST_URL"
curl -L -o "$DMG_FILE" "$LATEST_URL"

# Mount the DMG
echo "💿 Mounting DMG..."
VOLUME=$(hdiutil attach "$DMG_FILE" 2>&1 | grep -o '/Volumes/.*' | head -n 1)

if [ -z "$VOLUME" ]; then
    echo "❌ Error: Could not mount DMG"
    exit 1
fi

echo "📂 Mounted at: $VOLUME"

# Find the app in the mounted volume
echo "🔍 Locating PRTracker.app in mounted volume..."
APP_PATH=$(find "$VOLUME" -name "PRTracker.app" -maxdepth 2 2>/dev/null | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Could not find PRTracker.app in DMG"
    echo "📋 DMG contents:"
    ls -la "$VOLUME"
    hdiutil detach "$VOLUME" -quiet 2>/dev/null
    exit 1
fi

echo "✅ Found app at: $APP_PATH"

# Copy the application
echo "📋 Copying PRTracker to /Applications..."
if [ -d "/Applications/PRTracker.app" ]; then
    echo "⚠️  PRTracker already exists, replacing..."
    rm -rf "/Applications/PRTracker.app"
fi

cp -R "$APP_PATH" /Applications/

# Unmount the DMG
echo "💽 Unmounting DMG..."
hdiutil detach "$VOLUME" -quiet

# Remove quarantine attribute
echo "🔓 Removing security restrictions..."
xattr -rd com.apple.quarantine /Applications/PRTracker.app 2>/dev/null || true

# Clean up
rm -f "$DMG_FILE"

echo ""
echo "✅ Installation completed successfully!"
echo ""
echo "🎉 You can open PRTracker from:"
echo "   • Spotlight: Press Cmd+Space and type 'PRTracker'"
echo "   • Applications: Finder > Applications > PRTracker"
echo "   • Terminal: open /Applications/PRTracker.app"
echo ""
echo "📝 Note: First launch may take a few seconds"
