#!/bin/bash

# Build script for Human Typer Mac App

set -e

APP_NAME="TypeCraft"
BUNDLE_ID="com.typecraft.app"
BUILD_DIR=".build"
OUTPUT_DIR="dist"
APP_DIR="${OUTPUT_DIR}/${APP_NAME}.app"
ICON_SOURCE="assets/icon.png"

echo "🔨 Building Human Typer..."

# Build the Swift package
swift build -c release

# Create output directory and clean old app
mkdir -p "${OUTPUT_DIR}"
rm -rf "${APP_DIR}" 2>/dev/null || true

# Create app bundle structure
echo "📦 Creating app bundle..."
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/release/HumanTyper" "${APP_DIR}/Contents/MacOS/"

# Copy Info.plist
cp Info.plist "${APP_DIR}/Contents/"

# Create PkgInfo
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# Create icon if source exists
if [ -f "${ICON_SOURCE}" ]; then
    echo "🎨 Creating app icon..."
    ICONSET_DIR="${OUTPUT_DIR}/AppIcon.iconset"
    mkdir -p "${ICONSET_DIR}"
    
    # Generate all required icon sizes
    sips -z 16 16     "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null 2>&1
    sips -z 32 32     "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null 2>&1
    sips -z 32 32     "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null 2>&1
    sips -z 64 64     "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null 2>&1
    sips -z 128 128   "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null 2>&1
    sips -z 256 256   "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256 256   "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null 2>&1
    sips -z 512 512   "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512 512   "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null 2>&1
    sips -z 1024 1024 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null 2>&1
    
    # Convert to icns for app icon
    iconutil -c icns "${ICONSET_DIR}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns" 2>/dev/null || {
        echo "⚠️  Could not create icns, copying PNG as fallback"
        cp "${ICON_SOURCE}" "${APP_DIR}/Contents/Resources/AppIcon.png"
    }
    
    # Also copy a small PNG for menu bar icon
    sips -z 36 36 "${ICON_SOURCE}" --out "${APP_DIR}/Contents/Resources/MenuBarIcon.png" >/dev/null 2>&1
    
    # Cleanup
    rm -rf "${ICONSET_DIR}"
fi

# Sign the app (ad-hoc)
codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || true

echo "✅ Build complete!"
echo "📍 App location: ${APP_DIR}"
echo ""
echo "To run the app:"
echo "  open \"${APP_DIR}\""
echo ""
echo "⚠️  IMPORTANT: First run will prompt for Accessibility permissions."
echo "   Go to System Settings > Privacy & Security > Accessibility"
echo "   and enable \"Human Typer\""
