#!/bin/bash

# Package script for TypeCraft Mac App
# Creates a .pkg installer that installs to /Applications

set -e

APP_NAME="TypeCraft"
BUNDLE_ID="com.typecraft.app"
VERSION="1.0.0"
BUILD_DIR=".build"
OUTPUT_DIR="dist"
APP_DIR="${OUTPUT_DIR}/${APP_NAME}.app"
FINAL_PKG="${OUTPUT_DIR}/TypeCraft-${VERSION}.pkg"
ICON_SOURCE="assets/icon.png"
SCRIPTS_DIR="${OUTPUT_DIR}/scripts"

echo "📦 Building TypeCraft Package Installer"
echo "========================================="

# Step 1: Build the app
echo ""
echo "🔨 Step 1: Building application..."
swift build -c release

# Step 2: Create app bundle
echo ""
echo "📁 Step 2: Creating app bundle..."

mkdir -p "${OUTPUT_DIR}"
rm -rf "${APP_DIR}" 2>/dev/null || true

mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# copy executable
cp "${BUILD_DIR}/release/TypeCraft" "${APP_DIR}/Contents/MacOS/"

# copy Info.plist
cp Info.plist "${APP_DIR}/Contents/"

# create PkgInfo
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# Step 3: Create icon
if [ -f "${ICON_SOURCE}" ]; then
    echo ""
    echo "🎨 Step 3: Creating app icon..."
    ICONSET_DIR="${OUTPUT_DIR}/AppIcon.iconset"
    mkdir -p "${ICONSET_DIR}"
    
    # generate all required icon sizes
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
    
    # convert to icns
    iconutil -c icns "${ICONSET_DIR}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns" 2>/dev/null || {
        echo "⚠️  Could not create icns, copying PNG as fallback"
        cp "${ICON_SOURCE}" "${APP_DIR}/Contents/Resources/AppIcon.png"
    }
    
    # also copy a small PNG for menu bar icon
    sips -z 36 36 "${ICON_SOURCE}" --out "${APP_DIR}/Contents/Resources/MenuBarIcon.png" >/dev/null 2>&1
    
    # cleanup
    rm -rf "${ICONSET_DIR}"
else
    echo ""
    echo "⚠️  Step 3: No icon found at ${ICON_SOURCE}, skipping..."
fi

# Step 4: Sign the app (ad-hoc signing)
echo ""
echo "🔏 Step 4: Signing application..."
codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || echo "⚠️  Ad-hoc signing (no developer certificate)"

# Step 5: Create postinstall script that resets TCC
echo ""
echo "📝 Step 5: Creating installer scripts..."
mkdir -p "${SCRIPTS_DIR}"

cat > "${SCRIPTS_DIR}/postinstall" << 'POSTINSTALL'
#!/bin/bash

# post-installation script for TypeCraft
# this script runs after the app is installed

BUNDLE_ID="com.typecraft.app"
APP_PATH="/Applications/TypeCraft.app"

# set proper permissions
chmod -R 755 "${APP_PATH}" 2>/dev/null || true

# remove quarantine attribute (allows app to run without Gatekeeper warning)
xattr -dr com.apple.quarantine "${APP_PATH}" 2>/dev/null || true

# reset TCC accessibility permissions for this app
# this clears any stale permissions from previous installs
tccutil reset Accessibility "${BUNDLE_ID}" 2>/dev/null || true

# log installation
logger -t "TypeCraft" "TypeCraft installed successfully. Accessibility permissions reset."

exit 0
POSTINSTALL

chmod +x "${SCRIPTS_DIR}/postinstall"

# Step 6: Create installer package
echo ""
echo "📦 Step 6: Creating installer package..."
echo "   Install location: /Applications"

# create temporary directory with Applications structure
TEMP_ROOT=$(mktemp -d)
mkdir -p "${TEMP_ROOT}/Applications"
cp -R "${APP_DIR}" "${TEMP_ROOT}/Applications/"

# remove old package if exists
rm -f "${FINAL_PKG}"

# build the package with scripts
pkgbuild \
    --root "${TEMP_ROOT}" \
    --identifier "${BUNDLE_ID}" \
    --version "${VERSION}" \
    --scripts "${SCRIPTS_DIR}" \
    --install-location "/" \
    "${FINAL_PKG}"

# cleanup temp files
rm -rf "${TEMP_ROOT}"
rm -rf "${SCRIPTS_DIR}"

# done
echo ""
echo "========================================="
echo "✅ Package created successfully!"
echo ""
echo "📍 Package location:"
echo "   ${FINAL_PKG}"
echo ""
echo "📏 Package size:"
ls -lh "${FINAL_PKG}" | awk '{print "   " $5}'
echo ""
echo "📂 Installs to: /Applications/${APP_NAME}.app"
echo ""
echo "🔄 The installer will automatically:"
echo "   - Reset accessibility permissions (TCC)"
echo "   - Remove quarantine attributes"
echo "   - Set proper file permissions"
echo ""
echo "To install:"
echo "   1. Double-click: ${FINAL_PKG}"
echo "   2. Or run: sudo installer -pkg \"${FINAL_PKG}\" -target /"
echo ""
echo "⚠️  After installation:"
echo "   1. Launch TypeCraft from Applications"
echo "   2. Grant Accessibility permission when prompted"
echo "   3. System Settings > Privacy & Security > Accessibility"
echo ""
