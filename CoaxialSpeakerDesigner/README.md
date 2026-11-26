# CoaxialSpeakerDesigner (Native macOS Edition)

A high-performance, native macOS application built with **Swift 5.10**, **SwiftUI**, and **AppKit** for designing passive crossover networks, Nelder-Mead phase-alignment all-pass filters, and closed (sealed) or 4th-order vented (bass-reflex) cabinet enclosures for coaxial loudspeaker drivers.

See the root **[README.md](../README.md)** for full project overview and **[HELP.md](../HELP.md)** for the user guide.

---

## Key Capabilities

* **Datasheet & Curve Ingestion:** Local PDF and web URL Thiele-Small parameter extraction, dynamic PDF frequency response curve digitization, built-in **Altec Lansing 604-8K** CLIO preset, and 3-column FRD import/export.
* **Sealed & Vented Enclosure Designer:** 2nd-order sealed alignments (Target $f_3$, Butterworth B2, Bessel, Critically Damped, Custom $Q_{tc}$) and 4th-order bass-reflex alignments (QB3, B4, SC4, Custom $F_b$) with Helmholtz port duct length and anti-chuffing calculator.
* **Crossover & Nelder-Mead All-Pass Phase Optimizer:** Independent or unified woofer/tweeter cut-off frequencies, 1st–4th order topologies, Zobel network, L-Pad attenuator, E12 ($\pm 10\%$) & E24 ($\pm 5\%$) component value snapping, and 3-tier Green/Yellow/Red RMS phase alignment diagnostics.
* **Detachable Live Curve Windows & Auto-Scaling Plots:** Detach **Amplitude Response**, **Phase & Delay**, **Group Delay**, **Step Response**, and **System Impedance** into floating live `NSWindow` monitors (or a 2×2 Live Monitor Grid) that update in real time while tuning the crossover. Group Delay and System Impedance feature automatic Y-axis resolution scaling.
* **Vector 2-Page CAD PDF Exporter & JSON Project Files:** Full circuit schematic (Page 1) and BOM + technical spec cards with color-coded phase alignment status (Page 2), plus unified `.json` project save/load (`⌘S` / `⌘O`).

---

## Build & Test on macOS

```bash
cd CoaxialSpeakerDesigner
swift build -c release
.build/release/CoaxialSpeakerDesigner
```

Run unit tests:
```bash
swift test
```
