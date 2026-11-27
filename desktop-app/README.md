# Standalone Desktop App & macOS .dmg Package

A high-performance standalone desktop application for **Coaxial Speaker Designer** and the embedded **HP-35 RPN Scientific Calculator**.

Embedded inside self-contained executables and a mountable macOS disk image (`CoaxialSpeakerDesigner.dmg`), providing passive crossover synthesis, Constant Directivity (CD) horn EQ, acoustic delay alignment, and vector PDF exports.

---

## Pre-Compiled Standalone Binaries & Bundles

Located in `desktop-app/`:

| Target Platform | Package / Binary / Bundle | Description |
|---|---|---|
| **macOS Universal Installer (All Macs)** | `CoaxialSpeakerDesigner.dmg` | Mountable Apple Disk Image with drag-and-drop installer |
| **macOS Universal Application** | `CoaxialSpeakerDesigner_universal` | Fat Mach-O executable (Apple Silicon arm64 + Intel x86_64) |
| **macOS Apple Silicon (M1/M2/M3/M4)** | `HP35_mac_arm64` or `HP35_AppleSilicon.app` | Standalone native arm64 desktop bundle |
| **macOS Intel Macs** | `HP35_mac_amd64` or `HP35_Intel.app` | Standalone native x86_64 desktop bundle |
| **Linux (ARM64)** | `HP35_linux_arm64` | Linux ARM64 standalone executable |

---

## How to Install on macOS

### Option 1: Install via `.dmg` Disk Image (Recommended)
Double-click `CoaxialSpeakerDesigner.dmg` (or run `open CoaxialSpeakerDesigner.dmg`), then drag `CoaxialSpeakerDesigner.app` into `/Applications`.

### Option 2: Launch `.app` Bundle directly
Double-click `HP35_AppleSilicon.app` or `HP35_Intel.app`, or from Terminal:

```bash
open HP35_AppleSilicon.app
```

### Option 3: Run Standalone Executable
Make the binary executable and run directly:

```bash
chmod +x HP35_mac_arm64
./HP35_mac_arm64
```

The app will start a local loopback server and automatically launch the application UI in your browser or webview window.

---

## How to Rebuild Binaries & .dmg

Run the automated build script:

```bash
cd desktop-app
./build_desktop_apps.sh
# or build just the DMG package:
./build_dmg.sh
```

This builds the production React application, embeds the assets into Go source, cross-compiles native Mach-O executables for Apple Silicon and Intel Macs, and packages `CoaxialSpeakerDesigner.dmg`.
