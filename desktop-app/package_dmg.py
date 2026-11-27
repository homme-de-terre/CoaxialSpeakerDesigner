#!/usr/bin/env python3
"""
macOS .dmg Packaging Script for Coaxial Speaker Designer.
Builds:
1. Universal Mach-O Fat Binary (arm64 Apple Silicon + x86_64 Intel)
2. Standalone CoaxialSpeakerDesigner.app bundle
3. CoaxialSpeakerDesigner.dmg disk image with drag-and-drop Applications symlink
Compatible with both macOS (native hdiutil) and Linux (genisoimage HFS hybrid).
"""

import os
import sys
import shutil
import struct
import subprocess
import tempfile
import zlib
import uuid
import base64

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DESKTOP_DIR = os.path.join(ROOT_DIR, "desktop-app")

def run(cmd, cwd=None):
    print(f"--> Running: {' '.join(cmd)}")
    subprocess.run(cmd, cwd=cwd, check=True)

def create_universal_binary(x86_path, arm64_path, out_path):
    print("--> Creating Mach-O Universal Fat Binary (x86_64 + arm64)...")
    with open(x86_path, "rb") as f:
        x86_data = f.read()
    with open(arm64_path, "rb") as f:
        arm64_data = f.read()

    align = 14  # 2^14 = 16384 bytes alignment (standard for Apple Mach-O)
    align_bytes = 1 << align

    offset1 = align_bytes
    size1 = len(x86_data)

    offset2 = (offset1 + size1 + align_bytes - 1) & ~(align_bytes - 1)
    size2 = len(arm64_data)

    header = struct.pack(">II", 0xCAFEBABE, 2)
    # Arch 1: x86_64
    arch1 = struct.pack(">IIIII", 0x01000007, 0x00000003, offset1, size1, align)
    # Arch 2: arm64
    arch2 = struct.pack(">IIIII", 0x0100000C, 0x00000000, offset2, size2, align)

    with open(out_path, "wb") as f:
        f.write(header + arch1 + arch2)
        f.write(b"\x00" * (offset1 - f.tell()))
        f.write(x86_data)
        f.write(b"\x00" * (offset2 - f.tell()))
        f.write(arm64_data)

    os.chmod(out_path, 0o755)

def build_app_bundle(bundle_dir, binary_path):
    print(f"--> Staging app bundle at {bundle_dir}...")
    macos_dir = os.path.join(bundle_dir, "Contents", "MacOS")
    resources_dir = os.path.join(bundle_dir, "Contents", "Resources")
    os.makedirs(macos_dir, exist_ok=True)
    os.makedirs(resources_dir, exist_ok=True)

    dest_bin = os.path.join(macos_dir, "CoaxialSpeakerDesigner")
    shutil.copy2(binary_path, dest_bin)
    os.chmod(dest_bin, 0o755)

    plist_content = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CoaxialSpeakerDesigner</string>
    <key>CFBundleIdentifier</key>
    <string>com.coaxialspeakerdesigner.desktop</string>
    <key>CFBundleName</key>
    <string>Coaxial Speaker Designer</string>
    <key>CFBundleDisplayName</key>
    <string>Coaxial Speaker Designer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
"""
    with open(os.path.join(bundle_dir, "Contents", "Info.plist"), "w", encoding="utf-8") as f:
        f.write(plist_content)

    with open(os.path.join(bundle_dir, "Contents", "PkgInfo"), "w", encoding="utf-8") as f:
        f.write("APPL????")

def build_dmg(stage_dir, output_dmg_path, vol_name="Coaxial Speaker Designer"):
    print(f"--> Building DMG package: {output_dmg_path}...")
    # Check if native hdiutil is present (macOS)
    if shutil.which("hdiutil"):
        print("--> Using native macOS hdiutil...")
        if os.path.exists(output_dmg_path):
            os.remove(output_dmg_path)
        run([
            "hdiutil", "create",
            "-volname", vol_name,
            "-srcfolder", stage_dir,
            "-ov",
            "-format", "UDZO",
            output_dmg_path
        ])
    elif shutil.which("genisoimage"):
        print("--> Using genisoimage with Apple HFS hybrid partition map...")
        if os.path.exists(output_dmg_path):
            os.remove(output_dmg_path)
        run([
            "genisoimage",
            "-V", vol_name,
            "-hfs",
            "-hfs-volid", vol_name,
            "-part",
            "-r", "-J",
            "-o", output_dmg_path,
            stage_dir
        ])
    else:
        raise RuntimeError("Neither hdiutil nor genisoimage found to build DMG.")

def main():
    print("==================================================")
    print("   Building Coaxial Speaker Designer .dmg Package  ")
    print("==================================================")

    # 1. Build frontend bundle
    print("1. Building frontend production bundle...")
    run(["npm", "run", "build"], cwd=ROOT_DIR)

    # 2. Sync dist to desktop-app/dist
    desktop_dist = os.path.join(DESKTOP_DIR, "dist")
    if os.path.exists(desktop_dist):
        shutil.rmtree(desktop_dist)
    shutil.copytree(os.path.join(ROOT_DIR, "dist"), desktop_dist)

    # 3. Compile Mach-O Binaries using Go
    print("2. Compiling standalone Mach-O executables...")
    env_arm = os.environ.copy()
    env_arm["GOOS"] = "darwin"
    env_arm["GOARCH"] = "arm64"
    env_arm["CGO_ENABLED"] = "0"
    arm_bin = os.path.join(DESKTOP_DIR, "HP35_mac_arm64")
    run(["go", "build", "-ldflags=-s -w", "-o", arm_bin, "main.go"], cwd=DESKTOP_DIR)

    env_amd = os.environ.copy()
    env_amd["GOOS"] = "darwin"
    env_amd["GOARCH"] = "amd64"
    env_amd["CGO_ENABLED"] = "0"
    amd_bin = os.path.join(DESKTOP_DIR, "HP35_mac_amd64")
    run(["go", "build", "-ldflags=-s -w", "-o", amd_bin, "main.go"], cwd=DESKTOP_DIR)

    # 4. Create Universal Binary
    universal_bin = os.path.join(DESKTOP_DIR, "CoaxialSpeakerDesigner_universal")
    create_universal_binary(amd_bin, arm_bin, universal_bin)

    # 5. Stage DMG Content in a temporary directory
    with tempfile.TemporaryDirectory() as tmp_stage:
        dmg_stage = os.path.join(tmp_stage, "CoaxialSpeakerDesigner")
        os.makedirs(dmg_stage, exist_ok=True)

        # App bundle
        app_bundle_path = os.path.join(dmg_stage, "CoaxialSpeakerDesigner.app")
        build_app_bundle(app_bundle_path, universal_bin)

        # Applications symlink for drag-and-drop installation
        app_link = os.path.join(dmg_stage, "Applications")
        try:
            os.symlink("/Applications", app_link)
        except OSError:
            pass

        # README / Quick Guide inside DMG
        readme_txt = """Coaxial Speaker Designer for macOS
====================================

Installation:
Drag and drop "CoaxialSpeakerDesigner.app" into your "Applications" folder.

Features:
- Passive Crossover Network Synthesis (1st to 4th Order Linkwitz-Riley & Butterworth)
- Constant Directivity (CD) Horn Mass Roll-Off Compensation (+6 dB/oct HF Boost)
- Nelder-Mead Phase Alignment Optimizer with Woofer All-Pass Delay Filter
- 2nd-Order Closed (Sealed) & 4th-Order Bass-Reflex (Vented) Enclosure Simulation
- Interactive Vector Circuit Schematic & Comprehensive Bill of Materials (BOM)
- 2-Page Vector PDF Schematic & Report Exporter
- 3-Column FRD Curve Import / Export with Discrete Hilbert Transform Minimum Phase
- Altec Lansing 604-8K Studio Monitor Factory Preset & CLIO MLS Response Curves
"""
        with open(os.path.join(dmg_stage, "README.txt"), "w", encoding="utf-8") as f:
            f.write(readme_txt)

        # Output DMG paths
        desktop_dmg = os.path.join(DESKTOP_DIR, "CoaxialSpeakerDesigner.dmg")
        root_dmg = os.path.join(ROOT_DIR, "CoaxialSpeakerDesigner.dmg")

        build_dmg(dmg_stage, desktop_dmg, vol_name="Coaxial Speaker Designer")
        shutil.copy2(desktop_dmg, root_dmg)

    print("==================================================")
    print("=== Build Complete! DMG Package Created ===")
    print(f"Root DMG:        {root_dmg} ({os.path.getsize(root_dmg):,} bytes)")
    print(f"Desktop App DMG: {desktop_dmg} ({os.path.getsize(desktop_dmg):,} bytes)")
    print("==================================================")

if __name__ == "__main__":
    main()
