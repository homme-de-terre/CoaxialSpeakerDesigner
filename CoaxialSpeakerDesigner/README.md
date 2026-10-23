# CoaxialSpeakerDesigner

A high-performance, native macOS application built with **Swift 5.10**, **SwiftUI**, and **AppKit** for designing passive crossover networks and closed (sealed) cabinet enclosures for coaxial loudspeaker drivers.

---

## Key Features

### 1. Datasheet Ingestion Engine
* **URL & PDF Spec Ingestion:** Asynchronously downloads and parses Thiele-Small (T/S) parameters directly from driver manufacturer datasheet URLs (e.g. P.Audio, B&C, Beyma, Celestion, SB Acoustics, SEAS).
* **Regex Parameter Extractor:** Automatically parses $F_s, Q_{es}, Q_{ms}, Q_{ts}, V_{as}, R_e, L_e, S_d, X_{max}$, and Nominal Sensitivity (SPL).
* **Multi-Format Response Data Import:** Ingests standard 3-column FRD/ZMA text files (`Frequency  SPL/Mag  Phase`).
* **Hilbert Transform Minimum Phase Synthesis:** Synthesizes acoustic and electrical phase when datasheets only provide magnitude curves.

### 2. Sealed Cabinet Acoustic Physics Designer
* **Small-Margolis Enclosure Model:** Calculates physical internal box volume ($V_b$ in Liters and $\text{ft}^3$), system resonance frequency ($F_c$), actual total system $Q_{tc}$, compliance ratio ($\alpha$), and lower $-3\text{ dB}$ cutoff frequency ($f_3$).
* **Acoustic Polyfill Stuffing Compliance Gain:** Incorporates absorption filling levels ($0\%$ unfilled, $+10\%$ light, $+18\%$ medium polyfill, $+25\%$ heavy stuffing) to determine physical vs acoustic enclosure volume.
* **Multiple Alignment Design Modes:**
  * Target Cut-off Frequency ($f_3$) Mode (solves quadratic Small-Margolis equations for exact cutoff targets).
  * Butterworth B2 ($Q_{tc} = 0.7071$ - Maximally Flat).
  * Bessel Alignment ($Q_{tc} = 0.5774$ - Best Transient Response).
  * Critically Damped ($Q_{tc} = 0.5000$ - No Overshoot).
  * Custom $Q_{tc}$ & Manual Enclosure Volume Override ($V_b$).
* **Live Sizing Matrix:** Interactive comparison grid displaying required box volumes and resulting cutoff frequencies across different $Q_{tc}$ targets for your specific woofer.

### 3. Coaxial Passive Crossover Network Designer
* **Filter Topologies:** 1st Order ($6\text{ dB/oct}$), 2nd Order ($12\text{ dB/oct}$ Linkwitz-Riley / Butterworth), 3rd Order ($18\text{ dB/oct}$ BW), and 4th Order ($24\text{ dB/oct}$ Linkwitz-Riley) for Woofer Low-Pass and Tweeter High-Pass branches.
* **Zobel Inductance Compensation:** Parallel $R_z + C_z$ network to flatten voice coil inductance rise ($L_e$).
* **Tweeter L-Pad Attenuator:** Matches tweeter sensitivity to woofer output ($R_1$ series, $R_2$ parallel).
* **Coaxial Acoustic Alignment:** Physical depth delay offset ($\Delta d$ in mm) and tweeter polarity inversion switch ($+ / -$).
* **E12 Commercial Value Snapping:** Snapping ideal calculated components to standard commercial E12 series values.

### 4. Vector Logarithmic Bode Plots & CAD PDF Exporter
* **Logarithmic Bode Amplitude Plot ($20\text{ Hz} - 20\text{ kHz}$, dB SPL):** Individual woofer, tweeter, and complex vector-summed system acoustic response.
* **Phase Alignment Plot (Degrees vs Log Hz):** Woofer phase, tweeter phase (with acoustic center delay), inter-driver phase difference ($\Delta \Phi$), and combined system phase.
* **System Electrical Load Impedance Plot ($|Z|$ in $\Omega$):** Displays raw woofer sealed-box motional impedance peak at $F_c$, raw tweeter impedance, and total amplifier input load impedance through the crossover network.
* **CAD Vector PDF Exporter:** Generates vector PDF documents containing project metadata, circuit schematic diagrams with IEEE component symbols, and a complete Bill of Materials (BOM) table.

---

## Screenshots & Architecture

```
CoaxialSpeakerDesigner/
├── Package.swift
├── README.md
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
│       │   ├── SimulationEngine.swift
│       │   └── PDFExporter.swift
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

---

## How to Build and Run on macOS

### Prerequisites
* **macOS 13.0** (Ventura) or newer
* **Xcode 14.0+** or **Swift 5.9+** Command Line Tools

### Building via Xcode
1. Open `Package.swift` in Xcode:
   ```bash
   open Package.swift
   ```
2. Select target **CoaxialSpeakerDesigner** and destination **My Mac**.
3. Press **⌘R** (Command + R) to build and run.

### Building via Terminal (Swift Package Manager)
```bash
cd CoaxialSpeakerDesigner
swift build -c release
.build/release/CoaxialSpeakerDesigner
```

---

## License

This project is open source and available under the [MIT License](LICENSE).
