#!/bin/bash

# Exit on error
set -e

echo "=== Building HP-35 Desktop Calculator Executables & macOS .app Bundles ==="

# 1. Build production React web bundle
echo "1. Building frontend production bundle..."
cd ..
npm run build
cd desktop-app

# 2. Sync dist folder into desktop-app/dist
echo "2. Syncing dist assets into desktop-app..."
rm -rf dist
cp -r ../dist .

# 3. Compile Standalone Mach-O Executables for macOS
echo "3. Compiling standalone Mach-O executables..."
GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o HP35_mac_arm64 main.go
GOOS=darwin GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w" -o HP35_mac_amd64 main.go
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o HP35_linux_arm64 main.go

# 4. Package macOS .app Bundles
echo "4. Packaging macOS .app Bundle..."

create_app_bundle() {
    local APP_NAME="$1"
    local BINARY_SRC="$2"
    local BUNDLE_DIR="${APP_NAME}.app"
    
    rm -rf "${BUNDLE_DIR}"
    mkdir -p "${BUNDLE_DIR}/Contents/MacOS" "${BUNDLE_DIR}/Contents/Resources"
    
    cp "${BINARY_SRC}" "${BUNDLE_DIR}/Contents/MacOS/HP35"
    chmod +x "${BUNDLE_DIR}/Contents/MacOS/HP35"
    
    cat <<EOF > "${BUNDLE_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>HP35</string>
    <key>CFBundleIdentifier</key>
    <string>com.hewlettpackard.hp35desktop</string>
    <key>CFBundleName</key>
    <string>HP-35 Calculator</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
    echo "Created bundle: ${BUNDLE_DIR}"
}

create_app_bundle "HP35_AppleSilicon" "HP35_mac_arm64"
create_app_bundle "HP35_Intel" "HP35_mac_amd64"

echo "=== Build Complete! Executable Sizes ==="
ls -lh HP35_mac_arm64 HP35_mac_amd64 HP35_linux_arm64
