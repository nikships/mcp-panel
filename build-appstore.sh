#!/bin/bash
set -e

# ============================================
# Mac App Store Build Script
# ============================================
# Creates a signed PKG ready for Transporter submission
#
# Prerequisites:
# 1. "3rd Party Mac Developer Application" certificate in keychain
# 2. "3rd Party Mac Developer Installer" certificate in keychain
# 3. embedded.provisionprofile in project root
# 4. Xcode command line tools installed
#
# Usage: ./build-appstore.sh

echo "🍎 Building for Mac App Store..."
echo ""

# Configuration
APP_NAME="MCP Server Manager"
BUNDLE_ID="com.mcpmanager.app"
VERSION="3.3"
BUILD_NUMBER="140"

# Build directory
BUILD_DIR="MCPServerManager/build-appstore"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
PKG_PATH="$BUILD_DIR/MCPServerManager-v${VERSION}.pkg"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 1: Build the Swift binary (App Store version - no Sparkle)
echo "🔨 Building Swift binary for App Store..."
cd MCPServerManager

# Backup original Package.swift and use App Store version (no Sparkle dependency)
cp Package.swift Package.swift.backup
cp Package.swift.appstore Package.swift

# Build for release
swift build -c release

# Restore original Package.swift
mv Package.swift.backup Package.swift

# Verify Sparkle is NOT linked in the binary
echo "🔍 Verifying no Sparkle dependency..."
if otool -L .build/release/MCPServerManager | grep -i Sparkle; then
  echo "❌ ERROR: Sparkle.framework should not be linked in App Store build!"
  exit 1
else
  echo "✅ Confirmed: No Sparkle dependency in binary"
fi

cd ..

# Step 2: Create .app bundle structure
echo "📦 Creating .app bundle..."
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Copy binary
cp MCPServerManager/.build/release/MCPServerManager "$APP_PATH/Contents/MacOS/"

# Copy Swift Resource Bundle (Crucial for Fonts!)
echo "📂 Copying resource bundle..."
cp -r MCPServerManager/.build/release/MCPServerManager_MCPServerManager.bundle "$APP_PATH/Contents/Resources/"

# Also copy fonts to Contents/Resources/Fonts so ATSApplicationFontsPath="Fonts"
# auto-registers them, matching the GitHub Actions build layout. FontManager
# scans recursively too, so this is belt-and-suspenders.
echo "🔤 Embedding custom fonts..."
mkdir -p "$APP_PATH/Contents/Resources/Fonts"
cp MCPServerManager/MCPServerManager/Resources/Fonts/*.ttf "$APP_PATH/Contents/Resources/Fonts/"

# Copy app icon
echo "🎨 Adding app icon..."
cp MCPServerManager/icons/AppIcon.icns "$APP_PATH/Contents/Resources/AppIcon.icns"

# Copy provisioning profile
echo "📄 Embedding provisioning profile..."
cp embedded.provisionprofile "$APP_PATH/Contents/embedded.provisionprofile"

# Remove quarantine attributes from all files
echo "🧹 Removing quarantine attributes..."
xattr -cr "$APP_PATH"

# Create Info.plist
cat > "$APP_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MCPServerManager</string>
    <key>CFBundleIdentifier</key>
    <string>com.mcpmanager.app</string>
    <key>CFBundleName</key>
    <string>MCP Server Manager</string>
    <key>CFBundleDisplayName</key>
    <string>MCP Server Manager</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 Nikhil Anand. All rights reserved.</string>
</dict>
</plist>
EOF

# Step 3: Code sign the app with App Store certificate
echo "✍️  Signing with App Store certificate..."

# Find the signing identities
APP_SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "3rd Party Mac Developer Application" | head -1 | awk -F'"' '{print $2}')
INSTALLER_IDENTITY=$(security find-identity -v | grep "3rd Party Mac Developer Installer" | head -1 | awk -F'"' '{print $2}')

if [ -z "$APP_SIGNING_IDENTITY" ]; then
    echo "❌ Error: 3rd Party Mac Developer Application certificate not found in keychain"
    echo "   Install your App Store certificates from Xcode or Developer Portal"
    exit 1
fi

if [ -z "$INSTALLER_IDENTITY" ]; then
    echo "❌ Error: 3rd Party Mac Developer Installer certificate not found in keychain"
    echo "   Install your App Store certificates from Xcode or Developer Portal"
    exit 1
fi

echo "   Using app signing identity: $APP_SIGNING_IDENTITY"
echo "   Using installer identity: $INSTALLER_IDENTITY"

# Sign the app
codesign --deep --force --sign "$APP_SIGNING_IDENTITY" \
    --entitlements appstore.entitlements \
    --options runtime \
    --timestamp \
    "$APP_PATH"

# Verify signature
echo "✅ Verifying app signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

# Step 4: Create PKG with productbuild
echo "📦 Creating PKG installer..."

productbuild --component "$APP_PATH" /Applications \
    --sign "$INSTALLER_IDENTITY" \
    "$PKG_PATH"

# Verify PKG signature
echo "✅ Verifying PKG signature..."
pkgutil --check-signature "$PKG_PATH"

echo ""
echo "✅ SUCCESS! App Store PKG created:"
echo "   $PKG_PATH"
echo ""
echo "📤 Next steps:"
echo "   1. Open Transporter.app"
echo "   2. Drag and drop the PKG file"
echo "   3. Wait for validation and upload"
echo ""
echo "💡 Or use command line:"
echo "   xcrun altool --upload-app -f \"$PKG_PATH\" -t macos -u YOUR_APPLE_ID -p @keychain:AC_PASSWORD"
