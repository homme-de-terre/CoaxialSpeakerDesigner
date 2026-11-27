# Coaxial Speaker Designer

A professional loudspeaker engineering and simulation system for designing passive crossover networks, acoustic phase-alignment filters, and sealed or vented enclosures for **coaxial loudspeaker drivers**.

Includes both a **native macOS application** (**Swift 5.10 / SwiftUI / AppKit**) and a **cross-platform Web / Desktop application** (**React / Vite / Go Desktop Bundle**).

---

## Key Features

### 1. Datasheet Ingestion & Dynamic PDF Curve Digitizer
* **Local PDF & URL Datasheet Parsing:** Extracts Thiele-Small (T/S) parameters ($F_s, Q_{es}, Q_{ms}, Q_{ts}, V_{as}, R_e, L_e, S_d, X_{\max}$, Woofer & Tweeter Sensitivity $\text{SPL}$, and recommended crossover frequency $f_x$) directly from manufacturer PDF datasheets (e.g., Altec Lansing, B&C Speakers, Beyma, FaitalPRO, P.Audio, Celestion, SB Acoustics, SEAS).
* **Dynamic Frequency Response Curve Digitizer:** Automatically detects and digitizes woofer and tweeter SPL frequency response graphs from vector/raster PDF datasheets.
* **Altec Lansing 604-8K Factory Preset:** One-click preset with factory T/S specifications and 100-point digitized CLIO MLS acoustic response curves.
* **3-Column FRD Import & Export:** Import custom measured woofer/tweeter FRD data (`Frequency  SPL  Phase`) with Hilbert-transform minimum-phase synthesis, and export the combined system response to standard `.frd` format for CAD tools (VituixCAD, BoxSim, LOUDSOFT).

### 2. Acoustic Enclosure Physics Designer (Sealed 2nd-Order & Vented 4th-Order)
* **2nd-Order Sealed (Closed) Box Mode ($12\text{ dB/oct}$):**
  * Small-Margolis analytical solver for physical internal box volume ($V_b$ in Liters and $\text{ft}^3$), system resonance ($F_c$), total system $Q_{tc}$, compliance ratio ($\alpha$), and $-3\text{ dB}$ cutoff ($f_3$).
  * Alignments: Target Cut-off Frequency ($f_3$), Butterworth B2 ($Q_{tc} = 0.7071$), Bessel ($Q_{tc} = 0.5774$), Critically Damped ($Q_{tc} = 0.5000$), Custom $Q_{tc}$, and Manual $V_b$ override.
* **4th-Order Vented (Bass-Reflex) Mode ($24\text{ dB/oct}$):**
  * Full 4th-order Helmholtz resonator transfer function and twin-peak motional impedance solver.
  * Presets for low-$Q_{ts}$ pro-audio coaxial drivers: **QB3** (Quasi-Butterworth 3rd), **B4** (Butterworth 4th), **SC4** (Sub-Chebyshev 4th), and Custom $F_b / V_b$.
  * **Port Duct & Anti-Chuffing Calculator:** Computes required port length ($L_v$) with end-correction for 1–3 cylindrical port tubes and minimum recommended diameter ($D_{\min}$) to prevent air turbulence.
* **Polyfill Stuffing Absorption Model:** Models isothermal volume expansion ($0\%$ unfilled to $+25\%$ heavy fill) and enclosure absorption quality factor ($Q_b$).

### 3. Coaxial Passive Crossover Network & Nelder-Mead Phase Optimizer
* **Filter Topologies:** 1st Order ($6\text{ dB/oct}$), 2nd Order Linkwitz-Riley ($12\text{ dB/oct}$), 2nd Order Butterworth ($12\text{ dB/oct}$), 3rd Order Butterworth ($18\text{ dB/oct}$), and 4th Order Linkwitz-Riley ($24\text{ dB/oct}$).
* **Independent Woofer & Tweeter Cut-Off Frequencies:** Supports synchronous ($f_{x,\text{woofer}} = f_{x,\text{tweeter}}$) or split crossover frequencies (underlap/overlap tuning).
* **Nelder-Mead 2D Simplex All-Pass Filter (APF) Optimizer:**
  * Optimizes a 2nd-order all-pass delay network ($F_0, Q$) on the woofer branch to align acoustic phase with the physically recessed coaxial tweeter ($\Delta d$ in mm) across the 2-octave crossover handover zone $[f_x/2, 2f_x]$.
  * **3-Tier RMS Phase Alignment Warning Logic:**
    * **Green ($\le 10.0^\circ$ RMS):** `"Phase Aligned (Optimal)"`
    * **Yellow ($10.0^\circ - 20.0^\circ$ RMS):** `"Acceptable Alignment - Minor Phase Offset"`
    * **Red ($> 20.0^\circ$ RMS):** `"Large Phase Offset - Try Inverting Tweeter Polarity or Adjusting Fx"`
* **Compensation & Commercial Series Snapping:**
  * Woofer Zobel impedance compensation network ($R_{\text{zobel}}, C_{\text{zobel}}$).
  * Tweeter L-Pad sensitivity attenuator ($R_1$ series, $R_2$ shunt).
  * **E12 ($\pm 10\%$) & E24 ($\pm 5\%$) Value Snapping:** Snap ideal component values to standard commercial E12 or E24 electronic series.

### 4. Detachable Live Curve Windows, Auto-Scaling Plots & Vector PDF Report
* **5 Interactive Engineering Plots:**
  1. **Amplitude Response ($\text{dB SPL}$ vs $\log\text{Hz}$)**
  2. **Phase & Delay ($\text{Degrees}$ vs $\log\text{Hz}$)** with 1D phase unwrapping, $\Delta\Phi$ difference trace, and tweeter delay compensation
  3. **Group Delay ($\text{ms}$ vs $\log\text{Hz}$)** with automatic Y-axis resolution scaling
  4. **Step Response ($\text{Normalized Amplitude}$ vs $\text{Time in ms}$)** via 1024-point complex IFFT
  5. **System Impedance ($|Z|$ in $\Omega$ vs $\log\text{Hz}$)** with automatic Y-axis resolution scaling
* **Detachable Live Curve Windows & 2×2 Live Monitor Grid:** Detach any plot into a floating live window (or open a 2×2 multi-plot monitor grid) so every slider adjustment in the **Crossover Network** dialog reflects immediately in the curves.
* **2-Page Vector CAD PDF Report:** Exports a 2-page A4 landscape vector PDF with full electrical schematic diagram (Page 1) and Bill of Materials (BOM), enclosure specs, and color-coded Green/Yellow/Red APF phase alignment status (Page 2).
* **Unified JSON Design Project Files:** Save (`⌘S`) and load (`⌘O`) complete loudspeaker project files (`.json`) compatible across both the macOS native app and web/desktop app.

---

## Repository Structure

```
.
├── README.md
├── HELP.md                                 # Quick-Start & Engineering User Guide
├── CoaxialSpeakerDesigner/                 # Native macOS App (Swift 5.10 / SwiftUI / AppKit)
│   ├── Package.swift
│   ├── Sources/CoaxialSpeakerDesigner/
│   │   ├── Models/                         # ComplexNumber, DriverParameters, SealedCabinet, CrossoverNetwork, SpeakerDesignDocument
│   │   ├── Services/                       # SimulationEngine, AllpassFilterOptimizer, DatasheetParser, PDFExporter
│   │   ├── ViewModels/                     # MainDesignerViewModel (Simulation + Detached Window Manager)
│   │   └── Views/                          # MainSplitView, SidebarView, CabinetInspectorView, CrossoverInspectorView, 5 Chart Views
│   └── Tests/CoaxialSpeakerDesignerTests/  # XCTest Physics, Parser, Optimizer, and Serialization Suite
├── src/                                    # Cross-Platform React Web/Desktop UI
│   ├── App.jsx
│   └── utils/                              # datasheetParser.js, altec604Data.js
├── desktop-app/                            # Standalone Go Desktop App Wrapper & macOS .app Bundles
└── tests/                                  # Node.js Test Suite (designProjectFile.test.js)
```

---

## Building & Running

### 1. Native macOS App (Swift Package Manager / Xcode)
```bash
cd CoaxialSpeakerDesigner
swift build -c release
.build/release/CoaxialSpeakerDesigner
```
To run the Swift test suite:
```bash
cd CoaxialSpeakerDesigner
swift test
```

### 2. Web & Desktop Application (Node.js / Vite)
```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Run unit tests & linter
npm test
npm run lint

# Build production web & desktop bundles
npm run build
```

### 3. macOS .dmg Disk Image & Desktop App Distribution
Two mountable Apple Silicon HFS+ UDIF `.dmg` packages are provided at the project root:
* **`CoaxialSpeakerDesigner_Native.dmg`** (also in `CoaxialSpeakerDesigner/CoaxialSpeakerDesigner_Native.dmg`): **Pure Native SwiftUI + AppKit + Swift Charts macOS app** (`macOS 13.0+`).
* **`CoaxialSpeakerDesigner.dmg`** (also in `desktop-app/CoaxialSpeakerDesigner.dmg`): **Standalone Cross-Platform Web/Desktop app** (`macOS 11.0+`).

To rebuild the `.dmg` packages:
```bash
# Build Pure Native SwiftUI macOS .dmg (CoaxialSpeakerDesigner_Native.dmg)
cd CoaxialSpeakerDesigner
./build_native_dmg.sh

# Build Web/Desktop .dmg (CoaxialSpeakerDesigner.dmg) or both packages
cd ../desktop-app
./build_dmg.sh
# or run ./build_desktop_apps.sh to build everything
```
Drag `CoaxialSpeakerDesigner.app` into your macOS `/Applications` folder.

---

## Quick User Help
See **[HELP.md](./HELP.md)** (or click the **Help** button in the application toolbar) for a concise workflow guide on driver ingestion, enclosure tuning, crossover phase alignment, and live curve monitoring.
