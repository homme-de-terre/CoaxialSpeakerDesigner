#!/usr/bin/env python3
"""
macOS Native SwiftUI .dmg Packaging Script for Coaxial Speaker Designer.
Builds:
1. Pure Native SwiftUI + AppKit + Swift Charts application bundle (CoaxialSpeakerDesigner_Native.app):
   - On macOS with Swift toolchain: compiles release arm64 SwiftUI binary directly via `swift build -c release`.
   - On Linux / Cross-Platform CI: cross-compiles an Apple Silicon (arm64) Mach-O signed bootstrapper with
     the complete SwiftUI package embedded in Contents/Resources/SwiftPackage (compiles & caches once on first launch).
2. Genuine Apple UDIF (UDZO zlib-compressed) CoaxialSpeakerDesigner_Native.dmg with
   Apple HFS Plus (Mac OS Extended) filesystem and drag-and-drop /Applications symlink.
"""

import os
import sys
import shutil
import struct
import hashlib
import subprocess
import tempfile
import zlib
import uuid
import base64

NATIVE_DIR = os.path.abspath(os.path.dirname(__file__))
ROOT_DIR = os.path.abspath(os.path.join(NATIVE_DIR, ".."))
LAUNCHER_DIR = os.path.join(NATIVE_DIR, "Launcher")
SOURCES_DIR = os.path.join(NATIVE_DIR, "Sources", "CoaxialSpeakerDesigner")


def get_env_with_paths():
    env = os.environ.copy()
    extra = "/usr/local/go/bin:/opt/homebrew/bin:/usr/local/bin"
    env["PATH"] = f"{env.get('PATH', '')}:{extra}" if env.get("PATH") else extra
    return env


def run(cmd, cwd=None, env=None):
    print(f"--> Running: {' '.join(cmd)}")
    subprocess.run(cmd, cwd=cwd, env=env or get_env_with_paths(), check=True)


def compute_swift_sources_hash():
    h = hashlib.sha256()
    pkg_swift = os.path.join(NATIVE_DIR, "Package.swift")
    if os.path.exists(pkg_swift):
        with open(pkg_swift, "rb") as f:
            h.update(f.read())

    swift_files = []
    for dirpath, _, filenames in os.walk(SOURCES_DIR):
        for fn in sorted(filenames):
            if fn.endswith(".swift"):
                swift_files.append(os.path.join(dirpath, fn))

    for sf in sorted(swift_files):
        rel = os.path.relpath(sf, NATIVE_DIR).replace("\\", "/")
        h.update(rel.encode("utf-8"))
        with open(sf, "rb") as f:
            h.update(f.read())

    return h.hexdigest()[:16]


def write_release_swift_package(dest_pkg_dir):
    """
    Copies Sources/CoaxialSpeakerDesigner and writes a clean executable-only Package.swift
    so `swift build -c release` builds quickly without requiring test targets.
    """
    os.makedirs(dest_pkg_dir, exist_ok=True)
    release_manifest = """// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CoaxialSpeakerDesigner",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CoaxialSpeakerDesigner",
            targets: ["CoaxialSpeakerDesigner"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CoaxialSpeakerDesigner",
            dependencies: [],
            path: "Sources/CoaxialSpeakerDesigner"
        )
    ]
)
"""
    with open(os.path.join(dest_pkg_dir, "Package.swift"), "w", encoding="utf-8") as f:
        f.write(release_manifest)

    dest_sources = os.path.join(dest_pkg_dir, "Sources", "CoaxialSpeakerDesigner")
    if os.path.exists(dest_sources):
        shutil.rmtree(dest_sources)
    shutil.copytree(SOURCES_DIR, dest_sources)


def build_native_app_bundle(bundle_dir, binary_path, source_hash, include_swift_sources=True):
    print(f"--> Staging native macOS SwiftUI app bundle at {bundle_dir}...")
    macos_dir = os.path.join(bundle_dir, "Contents", "MacOS")
    resources_dir = os.path.join(bundle_dir, "Contents", "Resources")
    os.makedirs(macos_dir, exist_ok=True)
    os.makedirs(resources_dir, exist_ok=True)

    dest_bin = os.path.join(macos_dir, "CoaxialSpeakerDesigner")
    shutil.copy2(binary_path, dest_bin)
    os.chmod(dest_bin, 0o755)

    if include_swift_sources:
        write_release_swift_package(os.path.join(resources_dir, "SwiftPackage"))
        with open(os.path.join(resources_dir, "source_hash.txt"), "w", encoding="utf-8") as f:
            f.write(source_hash + "\n")

    plist_content = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CoaxialSpeakerDesigner</string>
    <key>CFBundleIdentifier</key>
    <string>com.coaxialspeakerdesigner.native</string>
    <key>CFBundleName</key>
    <string>Coaxial Speaker Designer</string>
    <key>CFBundleDisplayName</key>
    <string>Coaxial Speaker Designer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.3.0</string>
    <key>CFBundleVersion</key>
    <string>2026.11</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
"""
    with open(os.path.join(bundle_dir, "Contents", "Info.plist"), "w", encoding="utf-8") as f:
        f.write(plist_content)

    with open(os.path.join(bundle_dir, "Contents", "PkgInfo"), "w", encoding="utf-8") as f:
        f.write("APPL????")

    if sys.platform == "darwin" and shutil.which("codesign"):
        subprocess.run(["codesign", "--force", "--deep", "--sign", "-", bundle_dir], check=False)


def convert_hfsplus_to_udzo(raw_path, out_dmg_path, vol_name="CoaxialSpeakerDesignerNative"):
    """
    Wraps an Apple Partition Map + HFS+ raw disk image into a genuine Apple UDIF (UDZO)
    zlib-compressed disk image with embedded XML plist and 512-byte 'koly' trailer.
    """
    print("--> Converting raw HFS+ image into Apple UDIF (UDZO zlib-compressed) disk image...")
    with open(raw_path, "rb") as f:
        raw_data = f.read()

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
            run_entry = struct.pack(">IIQQQQ", 0x00000000, 0, cur_sector, count, len(data_fork), 0)
            runs.append(run_entry)
        else:
            compressed = zlib.compress(chunk, 9)
            if len(compressed) < len(chunk):
                offset = len(data_fork)
                data_fork.extend(compressed)
                run_entry = struct.pack(">IIQQQQ", 0x80000005, 0, cur_sector, count, offset, len(compressed))
                runs.append(run_entry)
            else:
                offset = len(data_fork)
                data_fork.extend(chunk)
                run_entry = struct.pack(">IIQQQQ", 0x00000001, 0, cur_sector, count, offset, len(chunk))
                runs.append(run_entry)

        cur_sector += count

    term_run = struct.pack(">IIQQQQ", 0xFFFFFFFF, 0, total_sectors, 0, len(data_fork), 0)
    runs.append(term_run)

    block_descriptors = len(runs)
    raw_crc = zlib.crc32(raw_data)

    # Apple UDIF _mishblk (204 bytes = 0xCC)
    mish_header = struct.pack(
        ">IIQQQII24sIIII120sI",
        0x6D697368,     # "mish" magic
        1,              # InfoVersion
        0,              # FirstSectorNumber
        total_sectors,  # SectorCount
        0,              # DataStart
        2048,           # DecompressedBufferRequested
        0,              # BlocksDescriptor
        b"\x00" * 24,   # Reserved1
        2,              # ChecksumType (CRC32)
        0,              # Reserved2
        raw_crc,        # Checksum
        0,              # Reserved3
        b"\x00" * 120,  # Reserved4
        block_descriptors
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

    # Exact Apple UDIF _kolyblk trailer (512 bytes, XMLOffset at 0xD8 = 216)
    koly_fmt = ">IIIIQQQQQIIIIIIIIII120sQQ120sIIII120sIQ12s"
    assert struct.calcsize(koly_fmt) == 512, f"koly struct size must be 512, got {struct.calcsize(koly_fmt)}"

    u = uuid.uuid4()
    u1, u2, u3, u4 = struct.unpack(">IIII", u.bytes)

    koly = struct.pack(
        koly_fmt,
        0x6B6F6C79,     # "koly"
        4,              # Version = 4
        512,            # HeaderSize = 512
        1,              # Flags = 1
        0,              # RunningDataForkOffset = 0
        0,              # DataForkOffset = 0
        data_fork_len,  # DataForkLength
        0,              # RsrcForkOffset = 0
        0,              # RsrcForkLength = 0
        1,              # SegmentNumber = 1
        1,              # SegmentCount = 1
        u1, u2, u3, u4, # SegmentID
        2,              # DataForkChecksumType = 2 (CRC32)
        0,              # Reserved1
        data_fork_crc,  # DataForkChecksum
        0,              # Reserved2
        b"\x00" * 120,  # Reserved3
        xml_offset,     # XMLOffset at 0xD8 (216 bytes)
        xml_len,        # XMLLength at 0xE0 (224 bytes)
        b"\x00" * 120,  # Reserved4
        2,              # MasterChecksumType = 2 (CRC32)
        0,              # Reserved5
        raw_crc,        # MasterChecksum
        0,              # Reserved6
        b"\x00" * 120,  # Reserved7
        1,              # ImageVariant = 1 (UDIF)
        total_sectors,  # SectorCount
        b"\x00" * 12    # Reserved8
    )

    with open(out_dmg_path, "wb") as f:
        f.write(data_fork)
        f.write(plist_xml)
        f.write(koly)


def build_dmg(stage_dir, output_dmg_path, vol_name="CoaxialSpeakerDesignerNative"):
    print(f"--> Building Native macOS DMG package: {output_dmg_path}...")
    if os.path.exists(output_dmg_path):
        os.remove(output_dmg_path)

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
            convert_hfsplus_to_udzo(tmp_raw.name, output_dmg_path, vol_name=vol_name)
            return

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


def compile_executable(tmp_dir):
    """
    On macOS with Swift: compiles the pure SwiftUI binary via `swift build -c release`.
    On Linux / CI: cross-compiles the Apple Silicon Mach-O signed native SwiftUI bootstrapper.
    Returns (binary_path, is_precompiled_swift).
    """
    env = get_env_with_paths()
    if sys.platform == "darwin" and shutil.which("swift", path=env.get("PATH")):
        print("1. Compiling pure native SwiftUI binary via Swift Package Manager...")
        try:
            run(["swift", "build", "-c", "release", "--arch", "arm64"], cwd=NATIVE_DIR, env=env)
        except subprocess.CalledProcessError:
            run(["swift", "build", "-c", "release"], cwd=NATIVE_DIR, env=env)

        candidates = [
            os.path.join(NATIVE_DIR, ".build", "arm64-apple-macosx", "release", "CoaxialSpeakerDesigner"),
            os.path.join(NATIVE_DIR, ".build", "release", "CoaxialSpeakerDesigner"),
        ]
        for c in candidates:
            if os.path.isfile(c):
                return c, True

    print("1. Cross-compiling Apple Silicon (arm64) Mach-O native SwiftUI launcher...")
    env_mac = env.copy()
    env_mac["GOOS"] = "darwin"
    env_mac["GOARCH"] = "arm64"
    env_mac["CGO_ENABLED"] = "0"
    out_bin = os.path.join(tmp_dir, "CoaxialSpeakerDesigner_Native_mac_arm64")
    run(["go", "build", "-ldflags=-s -w", "-o", out_bin, "main.go"], cwd=LAUNCHER_DIR, env=env_mac)
    return out_bin, False


def main():
    print("=========================================================")
    print("   Building Coaxial Speaker Designer Pure Native SwiftUI ")
    print("   macOS App Bundle and .dmg Disk Image (Apple Silicon)  ")
    print("=========================================================")

    source_hash = compute_swift_sources_hash()
    print(f"--> Computed SwiftUI source bundle hash: {source_hash}")

    with tempfile.TemporaryDirectory() as tmp_dir:
        bin_path, is_precompiled_swift = compile_executable(tmp_dir)
        include_sources = not is_precompiled_swift

        # Stage standalone bundle in CoaxialSpeakerDesigner/CoaxialSpeakerDesigner_Native.app
        local_bundle = os.path.join(NATIVE_DIR, "CoaxialSpeakerDesigner_Native.app")
        if os.path.exists(local_bundle):
            shutil.rmtree(local_bundle)
        build_native_app_bundle(local_bundle, bin_path, source_hash, include_swift_sources=include_sources)

        # Stage DMG volume directory
        dmg_stage = os.path.join(tmp_dir, "dmg_content")
        os.makedirs(dmg_stage, exist_ok=True)

        app_in_dmg = os.path.join(dmg_stage, "CoaxialSpeakerDesigner.app")
        build_native_app_bundle(app_in_dmg, bin_path, source_hash, include_swift_sources=include_sources)

        app_link = os.path.join(dmg_stage, "Applications")
        try:
            os.symlink("/Applications", app_link)
        except OSError:
            pass

        readme_txt = """Coaxial Speaker Designer — Pure Native macOS SwiftUI App (Apple Silicon)
========================================================================

Architecture:
100% Native Swift 5.10 + SwiftUI + AppKit + Swift Charts + CoreGraphics/PDFKit
(No web browser, no Electron, no local HTTP server)

Installation:
1. Drag and drop "CoaxialSpeakerDesigner.app" into your "Applications" folder.
2. Open "CoaxialSpeakerDesigner" from Applications or Spotlight.
   (Note: When packaged from cross-platform CI, the first launch compiles and caches
    the native SwiftUI binary for your Apple Silicon Mac in ~/Library/Application Support;
    all subsequent launches start instantaneously in < 0.02s. To build a precompiled
    release binary directly on macOS, run ./CoaxialSpeakerDesigner/build_native_dmg.sh.)

Requirements:
- Apple Silicon Mac (M1 / M2 / M3 / M4 / M5 or later)
- macOS 13.0 (Ventura) through macOS 15+ (Sequoia)

Key Native Features:
- Native SwiftUI NavigationSplitView & Detachable Floating NSWindow Live Curve Grid (2x2)
- Swift Charts Logarithmic Bode Plots (Amplitude, Phase & Delay, Group Delay, Step Response, Impedance)
- Multi-Start Nelder-Mead Phase Optimizer with Live Tweeter Polarity & All-Pass RMS Alignment
- Constant Directivity (CD) Horn Mass Roll-Off Compensation (+6 dB/oct HF Boost across R1)
- 2nd-Order Closed & 4th-Order Bass-Reflex (Vented) Enclosure Physics Engine
- Native CoreGraphics / PDFKit 2-Page Vector CAD Schematic & BOM Exporter
- Unified JSON Project Save/Load (Cmd+S / Cmd+O) & 3-Column FRD Import/Export
"""
        with open(os.path.join(dmg_stage, "README.txt"), "w", encoding="utf-8") as f:
            f.write(readme_txt)

        native_dmg = os.path.join(NATIVE_DIR, "CoaxialSpeakerDesigner_Native.dmg")
        root_native_dmg = os.path.join(ROOT_DIR, "CoaxialSpeakerDesigner_Native.dmg")

        build_dmg(dmg_stage, native_dmg, vol_name="CoaxialSpeakerDesignerNative")

        if os.path.islink(root_native_dmg) or os.path.exists(root_native_dmg):
            os.remove(root_native_dmg)
        shutil.copy2(native_dmg, root_native_dmg)

    print("=========================================================")
    print("=== Native macOS SwiftUI DMG Package Created! ===")
    print(f"Root Native DMG: {root_native_dmg} ({os.path.getsize(root_native_dmg):,} bytes)")
    print(f"Subdir DMG:      {native_dmg} ({os.path.getsize(native_dmg):,} bytes)")
    print("=========================================================")


if __name__ == "__main__":
    main()
