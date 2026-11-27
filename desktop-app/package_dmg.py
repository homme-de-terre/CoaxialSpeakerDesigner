#!/usr/bin/env python3
"""
macOS .dmg Packaging Script for Coaxial Speaker Designer.
Builds:
1. Apple Silicon (arm64) native Mach-O executable
2. Standalone CoaxialSpeakerDesigner_AppleSilicon.app bundle
3. Genuine Apple UDIF (UDZO zlib-compressed) CoaxialSpeakerDesigner.dmg with
   Apple HFS Plus (Mac OS Extended) filesystem and drag-and-drop /Applications symlink.
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

def run(cmd, cwd=None, env=None):
    print(f"--> Running: {' '.join(cmd)}")
    subprocess.run(cmd, cwd=cwd, env=env, check=True)

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
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
"""
    with open(os.path.join(bundle_dir, "Contents", "Info.plist"), "w", encoding="utf-8") as f:
        f.write(plist_content)

    with open(os.path.join(bundle_dir, "Contents", "PkgInfo"), "w", encoding="utf-8") as f:
        f.write("APPL????")

def convert_hfsplus_to_udzo(raw_path, out_dmg_path, vol_name="CoaxialSpeakerDesigner"):
    """
    Wraps an Apple Partition Map + HFS+ raw disk image into a genuine Apple UDIF (UDZO)
    zlib-compressed disk image with embedded XML plist and 512-byte 'koly' trailer.
    """
    print("--> Converting raw HFS+ image into Apple UDIF (UDZO zlib-compressed) disk image...")
    with open(raw_path, "rb") as f:
        raw_data = f.read()

    # Align raw data to 512-byte sectors
    if len(raw_data) % 512 != 0:
        raw_data += b"\x00" * (512 - (len(raw_data) % 512))

    total_sectors = len(raw_data) // 512
    chunk_sectors = 2048  # 1 MB uncompressed per chunk
    data_fork = bytearray()
    runs = []

    cur_sector = 0
    while cur_sector < total_sectors:
        count = min(chunk_sectors, total_sectors - cur_sector)
        chunk = raw_data[cur_sector * 512 : (cur_sector + count) * 512]

        if chunk == b"\x00" * len(chunk):
            # Zero-fill run
            run = struct.pack(">IIQQQQ", 0x00000000, 0, cur_sector, count, len(data_fork), 0)
            runs.append(run)
        else:
            compressed = zlib.compress(chunk, 9)
            if len(compressed) < len(chunk):
                offset = len(data_fork)
                data_fork.extend(compressed)
                # zlib compressed run
                run = struct.pack(">IIQQQQ", 0x80000005, 0, cur_sector, count, offset, len(compressed))
                runs.append(run)
            else:
                # Uncompressed raw run
                offset = len(data_fork)
                data_fork.extend(chunk)
                run = struct.pack(">IIQQQQ", 0x00000001, 0, cur_sector, count, offset, len(chunk))
                runs.append(run)

        cur_sector += count

    # Terminator run
    term_run = struct.pack(">IIQQQQ", 0xFFFFFFFF, 0, total_sectors, 0, len(data_fork), 0)
    runs.append(term_run)

    block_descriptors = len(runs)
    raw_crc = zlib.crc32(raw_data)

    mish_header = struct.pack(
        ">4sIQQQII24sII32s",
        b"mish",
        1,
        0,
        total_sectors,
        0,
        2048,
        block_descriptors,
        b"\x00" * 24,
        2, 32, struct.pack(">I28s", raw_crc, b"\x00" * 28)
    )
    mish_data = mish_header + b"".join(runs)
    mish_b64 = base64.b64encode(mish_data).decode("ascii")

    plist_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>resource-fork</key>
\t<dict>
\t\t<key>blkx</key>
\t\t<array>
\t\t\t<dict>
\t\t\t\t<key>Attributes</key>
\t\t\t\t<string>0x0050</string>
\t\t\t\t<key>CFName</key>
\t\t\t\t<string>Apple_HFS</string>
\t\t\t\t<key>Data</key>
\t\t\t\t<data>
{mish_b64}
\t\t\t\t</data>
\t\t\t\t<key>ID</key>
\t\t\t\t<string>0</string>
\t\t\t\t<key>Name</key>
\t\t\t\t<string>{vol_name}</string>
\t\t\t</dict>
\t\t</array>
\t</dict>
</dict>
</plist>""".encode("utf-8")

    data_fork_len = len(data_fork)
    data_fork_crc = zlib.crc32(data_fork)
    xml_offset = data_fork_len
    xml_len = len(plist_xml)

    # 512-byte Apple UDIF 'koly' trailer
    koly_fmt = ">4sIIIQQQQQII16sII32sQQ120sII32sIQ204s"
    seg_uuid = uuid.uuid4().bytes

    koly = struct.pack(
        koly_fmt,
        b"koly",
        4,
        512,
        1,
        0,
        0,
        data_fork_len,
        0,
        0,
        1,
        1,
        seg_uuid,
        2, 32, struct.pack(">I28s", data_fork_crc, b"\x00" * 28),
        xml_offset,
        xml_len,
        b"\x00" * 120,
        2, 32, struct.pack(">I28s", raw_crc, b"\x00" * 28),
        1,
        total_sectors,
        b"\x00" * 204
    )

    with open(out_dmg_path, "wb") as f:
        f.write(data_fork)
        f.write(plist_xml)
        f.write(koly)

def build_dmg(stage_dir, output_dmg_path, vol_name="CoaxialSpeakerDesigner"):
    print(f"--> Building DMG package: {output_dmg_path}...")
    if os.path.exists(output_dmg_path):
        os.remove(output_dmg_path)

    # If native macOS hdiutil is present, use it directly
    if shutil.which("hdiutil"):
        print("--> Using native macOS hdiutil...")
        run([
            "hdiutil", "create",
            "-volname", vol_name,
            "-srcfolder", stage_dir,
            "-ov",
            "-format", "UDZO",
            output_dmg_path
        ])
        return

    # On Linux, use xorriso to generate Apple Partition Map + HFS+ (Mac OS Extended)
    if shutil.which("xorriso"):
        print("--> Using xorriso to generate Apple Partition Map + HFS+ (Mac OS Extended)...")
        with tempfile.NamedTemporaryFile(suffix=".raw") as tmp_raw:
            run([
                "xorriso",
                "-as", "mkisofs",
                "-hfsplus",
                "-V", vol_name,
                "-r",
                "-o", tmp_raw.name,
                stage_dir
            ])
            # Wrap raw HFS+ image into Apple UDIF (UDZO zlib-compressed) disk image
            convert_hfsplus_to_udzo(tmp_raw.name, output_dmg_path, vol_name=vol_name)
            return

    # Fallback to genisoimage UDF 1.50
    if shutil.which("genisoimage"):
        print("--> Falling back to genisoimage with UDF filesystem...")
        run([
            "genisoimage",
            "-V", vol_name,
            "-udf",
            "-r",
            "-o", output_dmg_path,
            stage_dir
        ])
        return

    raise RuntimeError("Neither hdiutil, xorriso, nor genisoimage found to build DMG.")

def main():
    print("==================================================")
    print("   Building Coaxial Speaker Designer Apple Silicon")
    print("   Desktop Applications and .dmg Disk Image       ")
    print("==================================================")

    # 1. Build frontend bundle
    print("1. Building frontend production bundle...")
    run(["npm", "run", "build"], cwd=ROOT_DIR)

    # 2. Sync dist to desktop-app/dist
    desktop_dist = os.path.join(DESKTOP_DIR, "dist")
    if os.path.exists(desktop_dist):
        shutil.rmtree(desktop_dist)
    shutil.copytree(os.path.join(ROOT_DIR, "dist"), desktop_dist)

    # 3. Clean up legacy HP-35 and universal binaries
    print("2. Removing legacy HP-35 and universal binary artifacts...")
    legacy_files = [
        "HP35_AppleSilicon.app",
        "HP35_Intel.app",
        "HP35_mac_amd64",
        "HP35_mac_arm64",
        "HP35_linux_arm64",
        "CoaxialSpeakerDesigner_universal",
        "CoaxialSpeakerDesigner_mac_amd64"
    ]
    for lf in legacy_files:
        p = os.path.join(DESKTOP_DIR, lf)
        if os.path.isdir(p):
            shutil.rmtree(p)
        elif os.path.exists(p):
            os.remove(p)

    # 4. Compile Apple Silicon (arm64) and Linux ARM64 executables
    print("3. Compiling Apple Silicon (arm64) Mach-O executable...")
    env_mac = os.environ.copy()
    env_mac["GOOS"] = "darwin"
    env_mac["GOARCH"] = "arm64"
    env_mac["CGO_ENABLED"] = "0"
    mac_arm64_bin = os.path.join(DESKTOP_DIR, "CoaxialSpeakerDesigner_mac_arm64")
    run(["go", "build", "-ldflags=-s -w", "-o", mac_arm64_bin, "main.go"], cwd=DESKTOP_DIR, env=env_mac)

    print("4. Compiling Linux ARM64 executable...")
    env_linux = os.environ.copy()
    env_linux["GOOS"] = "linux"
    env_linux["GOARCH"] = "arm64"
    env_linux["CGO_ENABLED"] = "0"
    linux_arm64_bin = os.path.join(DESKTOP_DIR, "CoaxialSpeakerDesigner_linux_arm64")
    run(["go", "build", "-ldflags=-s -w", "-o", linux_arm64_bin, "main.go"], cwd=DESKTOP_DIR, env=env_linux)

    # 5. Build CoaxialSpeakerDesigner_AppleSilicon.app bundle in desktop-app/
    app_bundle_dir = os.path.join(DESKTOP_DIR, "CoaxialSpeakerDesigner_AppleSilicon.app")
    if os.path.exists(app_bundle_dir):
        shutil.rmtree(app_bundle_dir)
    build_app_bundle(app_bundle_dir, mac_arm64_bin)

    # 6. Stage DMG Content in a temporary directory
    print("5. Packaging mountable macOS .dmg Disk Image...")
    with tempfile.TemporaryDirectory() as tmp_stage:
        dmg_stage = os.path.join(tmp_stage, "dmg_content")
        os.makedirs(dmg_stage, exist_ok=True)

        # App bundle inside DMG
        app_in_dmg = os.path.join(dmg_stage, "CoaxialSpeakerDesigner.app")
        build_app_bundle(app_in_dmg, mac_arm64_bin)

        # Applications symlink for drag-and-drop installation
        app_link = os.path.join(dmg_stage, "Applications")
        try:
            os.symlink("/Applications", app_link)
        except OSError:
            pass

        # Quick guide README inside DMG
        readme_txt = """Coaxial Speaker Designer for macOS (Apple Silicon)
===================================================

Installation:
Drag and drop "CoaxialSpeakerDesigner.app" into your "Applications" folder.

Requirements:
- Apple Silicon Mac (M1 / M2 / M3 / M4 / M5 or later)
- macOS 11.0 (Big Sur) through macOS 15+ (Sequoia)

Features:
- Passive Crossover Network Synthesis (1st to 4th Order Linkwitz-Riley & Butterworth)
- Constant Directivity (CD) Horn Mass Roll-Off Compensation (+6 dB/oct HF Boost)
- Nelder-Mead Phase Alignment Optimizer with Woofer All-Pass Delay Filter
- 2nd-Order Closed (Sealed) & 4th-Order Bass-Reflex (Vented) Enclosure Simulation
- Interactive Vector Circuit Schematic & Comprehensive Bill of Materials (BOM)
- 2-Page Vector PDF Schematic & Report Exporter (Page 1 Schematic, Page 2 BOM)
- 3-Column FRD Curve Import / Export with Discrete Hilbert Transform Minimum Phase
- Altec Lansing 604-8K Studio Monitor Factory Preset & CLIO MLS Response Curves
"""
        with open(os.path.join(dmg_stage, "README.txt"), "w", encoding="utf-8") as f:
            f.write(readme_txt)

        # Output DMG paths
        desktop_dmg = os.path.join(DESKTOP_DIR, "CoaxialSpeakerDesigner.dmg")
        root_dmg = os.path.join(ROOT_DIR, "CoaxialSpeakerDesigner.dmg")

        build_dmg(dmg_stage, desktop_dmg, vol_name="CoaxialSpeakerDesigner")

        # Copy to root
        if os.path.islink(root_dmg) or os.path.exists(root_dmg):
            os.remove(root_dmg)
        shutil.copy2(desktop_dmg, root_dmg)

    print("==================================================")
    print("=== Build Complete! DMG Package Created ===")
    print(f"Root DMG:        {root_dmg} ({os.path.getsize(root_dmg):,} bytes)")
    print(f"Desktop App DMG: {desktop_dmg} ({os.path.getsize(desktop_dmg):,} bytes)")
    print("==================================================")

if __name__ == "__main__":
    main()
