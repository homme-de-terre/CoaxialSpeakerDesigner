# HP-35 Standalone Desktop App for macOS & Linux

A high-performance, ultra-lightweight standalone desktop application for the **HP-35 RPN Scientific Calculator**.

Embedded inside a single compact executable (**~5.8 MB**), containing the complete self-contained HP-35 calculator app, RPN stack inspector, calculation history, audio synthesizer, and European dead key (`^°`) support.

---

## Pre-Compiled Standalone Binaries & Bundles

Located in `desktop-app/`:

| Target Platform | Binary / Bundle | Executable Size |
|---|---|---|
| **macOS Apple Silicon (M1/M2/M3/M4)** | `HP35_mac_arm64` or `HP35_AppleSilicon.app` | **5.8 MB** |
| **macOS Intel Macs** | `HP35_mac_amd64` or `HP35_Intel.app` | **6.2 MB** |
| **Linux (ARM64)** | `HP35_linux_arm64` | **5.7 MB** |

---

## How to Launch on macOS

### Option 1: Launch `.app` Bundle
Double-click `HP35_AppleSilicon.app` or `HP35_Intel.app`, or from Terminal:

```bash
open HP35_AppleSilicon.app
```

### Option 2: Run Standalone Executable
Make the binary executable and run directly:

```bash
chmod +x HP35_mac_arm64
./HP35_mac_arm64
```

The app will start a local loopback server and automatically launch the calculator UI in your browser or webview window.

---

## How to Rebuild Binaries

Run the automated build script:

```bash
cd desktop-app
./build_desktop_apps.sh
```

This builds the production React application, embeds the assets into Go source, and cross-compiles native Mach-O executables for Apple Silicon and Intel Macs.
