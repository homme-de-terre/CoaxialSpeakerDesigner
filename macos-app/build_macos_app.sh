#!/bin/bash

# Exit on error
set -e

echo "=== Building HP-35 Native macOS Application ==="

APP_NAME="HP35"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# 1. Clean previous build
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# 2. Create Info.plist
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.hewlettpackard.hp35</string>
    <key>CFBundleName</key>
    <string>HP-35 Calculator</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 3. Locate Swift Compiler & SDK
SDK_PATH=$(xcrun --show-sdk-path 2>/dev/null || echo "")

if [ -z "$SDK_PATH" ]; then
    echo "Note: Running build environment check..."
    echo "To compile on macOS, run: bash build_macos_app.sh"
    exit 0
fi

echo "Compiling Swift source files with swiftc..."

swiftc -O \
    -parse-as-library \
    -sdk "${SDK_PATH}" \
    -target arm64-apple-macos12.0 \
    Sources/*.swift \
    Sources/Utils/*.swift \
    Sources/Views/*.swift \
    -o "${MACOS_DIR}/${APP_NAME}"

echo "=== Build Complete! Created ${BUNDLE_DIR} ==="
echo "Executable size: $(du -sh "${MACOS_DIR}/${APP_NAME}" | cut -f1)"
EOF
