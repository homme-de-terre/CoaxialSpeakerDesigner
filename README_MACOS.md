# Coaxial Speaker Crossover & Sealed Cabinet Designer (Native macOS App)

A native macOS application built with Swift 5.10 and SwiftUI to design crossover networks and closed (sealed) cabinet enclosures for coaxial loudspeaker drivers.

---

## Features

* **Datasheet Ingestion Engine:**
  * Downloads driver specification datasheets directly from a URL.
  * Regex and pattern matching parser to extract Thiele-Small parameters ($F_s, Q_{es}, Q_{ms}, Q_{ts}, V_{as}, R_e, L_e, S_d, X_{max}$, Sensitivity).
  * Multi-format support: Import FRD/ZMA text files, minimum phase synthesis via Hilbert Transform, and interactive curve editing.

* **Closed (Sealed) Cabinet Designer:**
  * Input target lower -3 dB cut-off frequency ($f_3$ in Hz), enclosure loss Q ($Q_b$), and target system Q ($Q_{tc}$ presets: Butterworth B2 $0.707$, Bessel $0.577$, Critically Damped $0.500$, or Custom).
  * Calculates compliance ratio $\alpha$, required net internal cabinet volume $V_b$ (Liters), system resonance $F_c$, actual cutoff $f_3$, and high-pass acoustic transfer function $H_{cab}(s)$.

* **Coaxial Crossover Network Designer:**
  * Filter topologies for Woofer Low-Pass and Tweeter High-Pass: 1st order (6 dB/oct), 2nd order (12 dB/oct Linkwitz-Riley / Butterworth), 3rd order (18 dB/oct BW), and 4th order (24 dB/oct Linkwitz-Riley).
  * Zobel voice-coil inductance compensation ($R_z, C_z$) and Tweeter L-Pad attenuator ($R_1, R_2$).
  * Coaxial acoustic center delay offset ($\Delta d$ in mm) and tweeter polarity inversion switch.
  * Commercial E12 standard component value snapping toggle.

* **Native Logarithmic Bode Plots & Diagrams:**
  * Amplitude Frequency Response Graph (20 Hz - 20 kHz Log Hz, dB SPL).
  * Phase Frequency Response & Inter-driver Delay Alignment Plot ($\Delta \Phi$).
  * Electrical Load Impedance Magnitude & Phase Plot ($|Z|$ in $\Omega$).
  * Interactive Circuit Schematic & complete Bill of Materials (BOM) export.

---

## How to Build and Run on macOS

### Method 1: Open in Xcode
1. Double click `Package.swift` in Finder or open Xcode and select **File > Open** and select `/path/to/CoaxialSpeakerDesigner/Package.swift`.
2. Select target `CoaxialSpeakerDesigner` and destination `My Mac`.
3. Press **⌘R** (Command + R) to build and launch the native macOS application.

### Method 2: Build via Terminal (Swift Package Manager)
```bash
cd CoaxialSpeakerDesigner
swift build -c release
.build/release/CoaxialSpeakerDesigner
```

---

## Project Architecture

```
CoaxialSpeakerDesigner/
├── Package.swift
├── Sources/
│   └── CoaxialSpeakerDesigner/
│       ├── Models/
│       │   ├── ComplexNumber.swift
│       │   ├── DriverParameters.swift
│       │   ├── SealedCabinet.swift
│       │   ├── CrossoverNetwork.swift
│       │   ├── HilbertTransform.swift
│       │   └── SimulationPoint.swift
│       ├── Services/
│       │   ├── DatasheetParser.swift
│       │   └── SimulationEngine.swift
│       ├── ViewModels/
│       │   └── MainDesignerViewModel.swift
│       └── Views/
│           ├── CoaxialSpeakerDesignerApp.swift
│           ├── MainSplitView.swift
│           ├── SidebarView.swift
│           ├── CabinetInspectorView.swift
│           ├── CrossoverInspectorView.swift
│           ├── AmplitudeBodeChartView.swift
│           ├── PhaseBodeChartView.swift
│           ├── ImpedanceChartView.swift
│           ├── SchematicView.swift
│           └── CurveDigitizerEditorView.swift
└── Tests/
    └── CoaxialSpeakerDesignerTests/
        └── CoaxialSpeakerDesignerTests.swift
```
