#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"
DMG_CONTENT="$DIST_DIR/dmg-content"

# Get version from project
VERSION=$(grep "MARKETING_VERSION" "$PROJECT_DIR/hello-wallpaper.xcodeproj/project.pbxproj" | head -1 | sed 's/.*= \(.*\);/\1/' | tr -d ' ')
APP_NAME="hello-wallpaper"
DMG_NAME="Hello-Wallpaper-${VERSION}.dmg"

echo -e "${YELLOW}Building Hello Wallpaper v${VERSION}${NC}"
echo "========================================"

# Clean
echo -e "\n${YELLOW}[1/4] Cleaning...${NC}"
rm -rf "$DIST_DIR"
mkdir -p "$DMG_CONTENT"

# Build
echo -e "${YELLOW}[2/4] Building Release...${NC}"
cd "$PROJECT_DIR"
xcodebuild -scheme "$APP_NAME" -configuration Release build -quiet

# Find built app
BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData -name "${APP_NAME}.app" -path "*/Release/*" -type d 2>/dev/null | head -1)

if [ -z "$BUILT_APP" ]; then
    echo -e "${RED}Error: Could not find built app${NC}"
    exit 1
fi

echo -e "${GREEN}Found: $BUILT_APP${NC}"

# Prepare DMG content
echo -e "${YELLOW}[3/4] Preparing DMG content...${NC}"
cp -R "$BUILT_APP" "$DMG_CONTENT/"
ln -s /Applications "$DMG_CONTENT/Applications"

# Create DMG
echo -e "${YELLOW}[4/4] Creating DMG...${NC}"
hdiutil create -volname "Hello Wallpaper" \
    -srcfolder "$DMG_CONTENT" \
    -ov -format UDZO \
    "$DIST_DIR/$DMG_NAME"

# Cleanup
rm -rf "$DMG_CONTENT"

# Done
echo -e "\n${GREEN}========================================"
echo -e "Build complete!"
echo -e "DMG: $DIST_DIR/$DMG_NAME"
echo -e "Size: $(du -h "$DIST_DIR/$DMG_NAME" | cut -f1)"
echo -e "========================================${NC}"
