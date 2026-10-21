#!/bin/bash

# Exit on error
set -e

echo "=========================================================="
echo "   Building HP-35 Pure Native Swift macOS Application     "
echo "=========================================================="

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${SCRIPT_DIR}"

APP_NAME="HP35Native"
BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Check for swift build / swiftc
if ! command -v swift &> /dev/null; then
    echo "Notice: Swift toolchain not found on this Linux system."
    echo "To build HP35Native.app on macOS (macOS 12 through macOS 27+):"
    echo "  1. cd macos-app"
    echo "  2. ./build_native_app.sh"
    echo "  Or double-click Package.swift to open in Xcode!"
    exit 0
fi

echo "1. Compiling release binary with Swift Package Manager..."
swift build -c release

echo "2. Creating standalone .app Bundle..."
rm -rf "${BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp .build/release/HP35Native "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.hewlettpackard.hp35native</string>
    <key>CFBundleName</key>
    <string>HP-35 Native Calculator</string>
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

echo "=========================================================="
echo "=== Success! Built ${BUNDLE} ==="
echo "Executable Size: $(du -sh "${MACOS_DIR}/${APP_NAME}" | cut -f1)"
echo "=========================================================="
