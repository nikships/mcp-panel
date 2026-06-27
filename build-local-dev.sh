#!/bin/bash
set -e

# ============================================
# Local Development Build Script
# ============================================
# Builds a signed .app bundle for local testing
# No notarization needed - just local signing

echo "🛑 Killing existing app..."
pkill -9 MCPServerManager 2>/dev/null || true

echo "🔨 Building Swift app..."
cd MCPServerManager
swift build -c release

echo "📦 Creating .app bundle..."
rm -rf build/MCP-Server-Manager.app
mkdir -p build/MCP-Server-Manager.app/Contents/MacOS
mkdir -p build/MCP-Server-Manager.app/Contents/Resources

# Copy binary
cp .build/release/MCPServerManager build/MCP-Server-Manager.app/Contents/MacOS/

# Bundle the agent CLI (mcp-panel) so the app can install it onto the user's PATH.
# The later `codesign --deep` covers this nested executable.
if [ -f .build/release/mcp-panel ]; then
    echo "🧰 Bundling mcp-panel CLI..."
    cp .build/release/mcp-panel build/MCP-Server-Manager.app/Contents/MacOS/mcp-panel
    chmod +x build/MCP-Server-Manager.app/Contents/MacOS/mcp-panel
else
    echo "⚠️ mcp-panel not found in .build/release; skipping CLI bundle"
fi

# Create Info.plist
cat > build/MCP-Server-Manager.app/Contents/Info.plist << 'EOF'
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
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.2-dev</string>
    <key>CFBundleVersion</key>
    <string>999</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# Copy app icon if it exists
if [ -f ../icons/AppIcon.icns ]; then
    echo "🎨 Adding app icon..."
    cp ../icons/AppIcon.icns build/MCP-Server-Manager.app/Contents/Resources/AppIcon.icns
fi

# Copy Swift Resource Bundle (Crucial for Fonts!)
echo "📂 Copying resource bundle..."
if [ -d ".build/release/MCPServerManager_MCPServerManager.bundle" ]; then
    cp -r .build/release/MCPServerManager_MCPServerManager.bundle build/MCP-Server-Manager.app/Contents/Resources/
    echo "✅ Copied resource bundle"
else
    echo "⚠️ Resource bundle not found! Fonts may be missing."
fi

# Embed Sparkle.framework (required at runtime, otherwise dyld crash on launch)
echo "📦 Embedding Sparkle.framework..."
mkdir -p build/MCP-Server-Manager.app/Contents/Frameworks
if [ -d ".build/release/Sparkle.framework" ]; then
    cp -R .build/release/Sparkle.framework build/MCP-Server-Manager.app/Contents/Frameworks/
    # Ensure the executable can locate embedded frameworks
    install_name_tool -add_rpath "@executable_path/../Frameworks" \
        build/MCP-Server-Manager.app/Contents/MacOS/MCPServerManager 2>/dev/null || true
    echo "✅ Embedded Sparkle.framework"
else
    echo "⚠️ Sparkle.framework not found! App will crash on launch."
fi

echo "✍️  Code signing..."
cd build

# Sign embedded Sparkle.framework first (nested code must be signed before the app)
if [ -d "MCP-Server-Manager.app/Contents/Frameworks/Sparkle.framework" ]; then
    codesign --force --options runtime \
      --sign "Developer ID Application: Nikhil Anand (NW6B3R27LQ)" \
      MCP-Server-Manager.app/Contents/Frameworks/Sparkle.framework
fi

# Sign the app with local dev entitlements (non-sandboxed)
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Nikhil Anand (NW6B3R27LQ)" \
  --options runtime \
  --entitlements ../../build/entitlements.mac.plist \
  MCP-Server-Manager.app

# Verify signature
echo "✅ Verifying signature..."
codesign --verify --deep --strict --verbose=2 MCP-Server-Manager.app

echo ""
echo "✅ Done! App built at: MCPServerManager/build/MCP-Server-Manager.app"
echo ""
echo "🚀 To run: open MCPServerManager/build/MCP-Server-Manager.app"
echo ""

# Auto-launch if requested
if [ "$1" == "--launch" ]; then
    echo "🚀 Launching app..."
    open MCP-Server-Manager.app
fi
