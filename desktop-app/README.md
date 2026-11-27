# Standalone Desktop App & macOS .dmg Package (Apple Silicon)

A high-performance standalone desktop application and mountable macOS disk image (`CoaxialSpeakerDesigner.dmg`) for **Coaxial Speaker Designer**.

Embedded inside self-contained executables and an Apple UDIF disk image formatted with Apple HFS Plus (Mac OS Extended), providing passive crossover synthesis, Constant Directivity (CD) horn mass roll-off compensation, acoustic delay alignment, and vector PDF exports.

---

## Pre-Compiled Standalone Binaries & Bundles

Located in `desktop-app/`:

| Target Platform | Package / Binary / Bundle | Description |
|---|---|---|
| **macOS Apple Silicon (M1/M2/M3/M4/M5)** | `CoaxialSpeakerDesigner.dmg` | Mountable Apple UDIF Disk Image with Apple HFS+ and `/Applications` installer |
| **macOS Apple Silicon (arm64)** | `CoaxialSpeakerDesigner_AppleSilicon.app` | Standalone native arm64 desktop application bundle |
| **macOS Apple Silicon (arm64)** | `CoaxialSpeakerDesigner_mac_arm64` | Standalone Mach-O 64-bit arm64 binary |
| **Linux (ARM64)** | `CoaxialSpeakerDesigner_linux_arm64` | Linux ARM64 standalone binary |

---

## How to Install on macOS

### Option 1: Install via `.dmg` Disk Image (Recommended)
Double-click `CoaxialSpeakerDesigner.dmg` (or run `open CoaxialSpeakerDesigner.dmg`), then drag `CoaxialSpeakerDesigner.app` into `/Applications`.

### Option 2: Launch `.app` Bundle directly
Double-click `CoaxialSpeakerDesigner_AppleSilicon.app`, or from Terminal:

```bash
open CoaxialSpeakerDesigner_AppleSilicon.app
```

### Option 3: Run Standalone Executable
Make the binary executable and run directly:

```bash
chmod +x CoaxialSpeakerDesigner_mac_arm64
./CoaxialSpeakerDesigner_mac_arm64
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

This builds the production React application, embeds the assets into Go source, cross-compiles native Mach-O executables for Apple Silicon, and packages `CoaxialSpeakerDesigner.dmg`.
